#!/usr/bin/env python3
"""codex-models.py - enumerate the Codex model catalog.

Codex ships no `codex models` command (openai/codex#23279), but its app-server
exposes a `model/list` JSON-RPC method. This is the supervised adapter over that
method: it owns a `codex app-server` stdio child, performs the handshake, pages
the catalog, and prints it as structured JSON - the churn/retirement source that
`refresh-bands` and humans read, mirroring what `agy models` is for agy.

Hardened per the gpt-6-astra design review:
  * Owns the stdio child (start_new_session so the whole tree can be reaped);
    never assumes an already-running server.
  * Waits for the `initialize` RESULT (matched by id) before sending
    `initialized`, then `model/list`. Responses are correlated by id - it never
    assumes "the next line is the catalog".
  * Drains stderr on a thread so a chatty server cannot fill the pipe and
    deadlock the reader.
  * ONE overall wall-clock deadline covering startup, handshake, every page and
    shutdown - not a per-message timeout that a notification stream could reset
    forever.
  * Pages via nextCursor with a repeated-cursor guard and a page cap.
  * Preserves the fields churn handling needs (id, model, defaultReasoningEffort,
    supportedReasoningEfforts, hidden, upgradeInfo{retirementAt, successor}),
    ignores additive fields, and rejects missing/mistyped required fields.
  * NO partial-success catalog: any page failure aborts with no output.

Exit codes: 0 ok | 2 usage | 4 discovery (spawn/handshake/timeout/transport)
            | 5 protocol (malformed or non-conforming response).

The codex binary is $CODEX_BIN (default `codex`), injectable for tests.
"""
import argparse
import json
import os
import select
import signal
import subprocess
import sys
import threading
import time

CODEX_BIN = os.environ.get("CODEX_BIN", "codex")
MAX_PAGES = 50
STDERR_CAP = 64 * 1024


class DiscoveryError(Exception):
    code = 4


class ProtocolError(Exception):
    code = 5


class Deadline:
    def __init__(self, seconds):
        self.end = time.monotonic() + seconds

    def remaining(self):
        return self.end - time.monotonic()


class LineReader:
    """Deadline-bounded newline-delimited reader over a raw fd."""

    def __init__(self, fd, deadline):
        self.fd = fd
        self.deadline = deadline
        self.buf = b""

    def readline(self):
        while b"\n" not in self.buf:
            rem = self.deadline.remaining()
            if rem <= 0:
                raise DiscoveryError("timed out waiting for app-server output")
            r, _, _ = select.select([self.fd], [], [], rem)
            if not r:
                raise DiscoveryError("timed out waiting for app-server output")
            chunk = os.read(self.fd, 65536)
            if not chunk:
                if self.buf:
                    line, self.buf = self.buf, b""
                    return line
                raise DiscoveryError("app-server closed the stream early (EOF)")
            self.buf += chunk
        line, self.buf = self.buf.split(b"\n", 1)
        return line


def drain(stream, sink):
    try:
        while True:
            chunk = stream.read(4096)
            if not chunk:
                break
            if len(sink[0]) < STDERR_CAP:
                sink[0] += chunk
    except Exception:
        pass


def read_result(reader, want_id):
    """Read lines until a JSON-RPC response with id==want_id; return its result.

    Non-matching messages (notifications, other ids) are ignored, so the server
    may interleave freely. A response carrying an `error` for our id raises.
    """
    while True:
        raw = reader.readline()
        text = raw.decode("utf-8", "replace").strip()
        if not text:
            continue
        try:
            msg = json.loads(text)
        except json.JSONDecodeError:
            raise ProtocolError("app-server sent a non-JSON line: %r" % text[:200])
        if not isinstance(msg, dict):
            continue
        if msg.get("id") != want_id:
            continue  # notification or a different request's response
        if "error" in msg:
            raise ProtocolError("app-server returned an error: %r" % msg["error"])
        if "result" not in msg:
            raise ProtocolError("response for id %s had no result" % want_id)
        return msg["result"]


def require(cond, msg):
    if not cond:
        raise ProtocolError(msg)


def normalize(m):
    require(isinstance(m, dict), "model entry is not an object")
    mid = m.get("id")
    slug = m.get("model")
    require(isinstance(mid, str) and mid, "model entry missing string 'id'")
    require(isinstance(slug, str) and slug, "model %r missing string 'model'" % mid)
    up = m.get("upgradeInfo")
    upgrade = None
    if isinstance(up, dict):
        upgrade = {
            "successor": up.get("model"),
            "retirementAt": up.get("retirementAt"),
        }
    return {
        "id": mid,             # the value passed to `codex exec -m`
        "model": slug,
        "displayName": m.get("displayName"),
        "isDefault": bool(m.get("isDefault", False)),
        "hidden": bool(m.get("hidden", False)),
        "defaultReasoningEffort": m.get("defaultReasoningEffort"),
        "supportedReasoningEfforts": [
            o.get("reasoningEffort") if isinstance(o, dict) else o
            for o in (m.get("supportedReasoningEfforts") or [])
        ],
        "upgradeInfo": upgrade,
    }


def fetch(include_hidden, timeout):
    deadline = Deadline(timeout)
    try:
        proc = subprocess.Popen(
            [CODEX_BIN, "app-server"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            start_new_session=True,  # own the tree so we can reap it
        )
    except FileNotFoundError:
        raise DiscoveryError("codex binary not found: %s" % CODEX_BIN)

    errbuf = [b""]
    errthread = threading.Thread(target=drain, args=(proc.stderr, errbuf), daemon=True)
    errthread.start()
    reader = LineReader(proc.stdout.fileno(), deadline)

    def send(obj):
        proc.stdin.write((json.dumps(obj) + "\n").encode("utf-8"))
        proc.stdin.flush()

    try:
        send({"jsonrpc": "2.0", "id": 1, "method": "initialize",
              "params": {"clientInfo": {"name": "codex-models", "version": "1", "title": "codex-models"},
                         "capabilities": {"experimentalApi": True}}})
        read_result(reader, 1)
        send({"jsonrpc": "2.0", "method": "initialized", "params": {}})

        models = []
        cursor = None
        seen = set()
        for page in range(MAX_PAGES):
            params = {"includeHidden": bool(include_hidden)}
            if cursor is not None:
                params["cursor"] = cursor
            req_id = 100 + page
            send({"jsonrpc": "2.0", "id": req_id, "method": "model/list", "params": params})
            result = read_result(reader, req_id)
            require(isinstance(result, dict) and isinstance(result.get("data"), list),
                    "model/list result missing 'data' array")
            for entry in result["data"]:
                models.append(normalize(entry))
            cursor = result.get("nextCursor")
            if not cursor:
                break
            if cursor in seen:
                raise ProtocolError("app-server repeated pagination cursor %r" % cursor)
            seen.add(cursor)
        else:
            raise ProtocolError("model/list exceeded %d pages" % MAX_PAGES)
        return models
    finally:
        try:
            proc.stdin.close()
        except Exception:
            pass
        try:
            os.killpg(os.getpgid(proc.pid), signal.SIGTERM)
        except Exception:
            try:
                proc.terminate()
            except Exception:
                pass
        try:
            proc.wait(timeout=3)
        except Exception:
            try:
                os.killpg(os.getpgid(proc.pid), signal.SIGKILL)
            except Exception:
                pass


def main():
    ap = argparse.ArgumentParser(description="Enumerate the Codex model catalog via the app-server.")
    ap.add_argument("--tsv", action="store_true", help="tab-separated display instead of JSON")
    ap.add_argument("--include-hidden", action="store_true", help="include picker-hidden models")
    ap.add_argument("--timeout", type=float, default=20.0, help="overall deadline in seconds")
    args = ap.parse_args()

    try:
        models = fetch(args.include_hidden, args.timeout)
    except (DiscoveryError, ProtocolError) as e:
        sys.stderr.write("CODEX-MODELS FAILED: %s\n" % e)
        sys.exit(e.code)

    if args.tsv:
        for m in models:
            ret = (m["upgradeInfo"] or {}).get("retirementAt") if m["upgradeInfo"] else None
            sys.stdout.write("\t".join([
                m["id"],
                str(m["defaultReasoningEffort"] or ""),
                "hidden" if m["hidden"] else "visible",
                str(ret or ""),
                str(m["displayName"] or ""),
            ]) + "\n")
    else:
        json.dump({"models": models, "count": len(models)}, sys.stdout, indent=2)
        sys.stdout.write("\n")


if __name__ == "__main__":
    main()
