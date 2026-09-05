#!/usr/bin/env bash
#
# Unit tests for scripts/codex-models.py - the supervised codex app-server
# adapter. Per the design review these drive an INTERACTIVE fake server that
# inspects each request before replying (a canned stdout fixture cannot catch a
# missing handshake, an unflushed reply, wrong pagination, or a stderr-flood
# deadlock). The fake's behaviour is chosen by $FAKE_MODE. No real codex runs.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODELS="$REPO_ROOT/scripts/codex-models.py"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/codex-models-test-XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# Fake `codex`: only implements `app-server`, speaking newline-delimited
# JSON-RPC and correlating responses by id. $FAKE_MODE injects each failure.
FAKE="$WORK/codex"
cat > "$FAKE" <<'PY'
#!/usr/bin/env python3
import json, os, sys, time

if len(sys.argv) < 2 or sys.argv[1] != "app-server":
    sys.exit("fake codex: expected 'app-server'")

mode = os.environ.get("FAKE_MODE", "ok")

def out(o):
    sys.stdout.write(json.dumps(o) + "\n"); sys.stdout.flush()

PAGE1 = [
    {"id": "gpt-6-astra", "model": "gpt-6-astra", "displayName": "GPT-6-Astra",
     "isDefault": True, "hidden": False, "defaultReasoningEffort": "low",
     "supportedReasoningEfforts": [{"reasoningEffort": "low"}, {"reasoningEffort": "high"}]},
    {"id": "gpt-reserve", "model": "gpt-reserve", "displayName": "GPT-Reserve",
     "isDefault": False, "hidden": True, "defaultReasoningEffort": "medium",
     "supportedReasoningEfforts": []},
    {"id": "gpt-5.5", "model": "gpt-5.5", "displayName": "GPT-5.5",
     "isDefault": False, "hidden": False, "defaultReasoningEffort": "medium",
     "supportedReasoningEfforts": [],
     "upgradeInfo": {"model": "gpt-5.6-terra", "retirementAt": 1790000000}},
]
PAGE2 = [
    {"id": "gpt-5.4-mini", "model": "gpt-5.4-mini", "displayName": "GPT-5.4-Mini",
     "isDefault": False, "hidden": False, "defaultReasoningEffort": "medium",
     "supportedReasoningEfforts": []},
]

for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    msg = json.loads(line)
    method, mid = msg.get("method"), msg.get("id")
    if method == "initialize":
        if mode == "noinit":
            time.sleep(30)   # never acks -> client hits its deadline
            continue
        out({"jsonrpc": "2.0", "id": mid, "result": {"capabilities": {}}})
    elif method == "initialized":
        continue
    elif method == "model/list":
        if mode == "flood":
            sys.stderr.write("x" * 200000); sys.stderr.flush()
        if mode == "rpcerror":
            out({"jsonrpc": "2.0", "id": mid, "error": {"code": -32000, "message": "nope"}}); continue
        if mode == "badjson":
            sys.stdout.write("THIS IS NOT JSON\n"); sys.stdout.flush(); continue
        cursor = (msg.get("params") or {}).get("cursor")
        if cursor is None:
            out({"jsonrpc": "2.0", "id": mid, "result": {"data": PAGE1, "nextCursor": "c1"}})
        elif mode == "repeatcursor":
            out({"jsonrpc": "2.0", "id": mid, "result": {"data": PAGE2, "nextCursor": "c1"}})
        else:
            out({"jsonrpc": "2.0", "id": mid, "result": {"data": PAGE2, "nextCursor": None}})
    else:
        if mid is not None:
            out({"jsonrpc": "2.0", "id": mid, "result": {}})
PY
chmod +x "$FAKE"
export CODEX_BIN="$FAKE"

run() { FAKE_MODE="$1" python3 "$MODELS" "${@:2}"; }

# Assert a run exits with a specific code (captured correctly - a branchless
# `if cmd; then fail; fi` would read `$?` as 0, not the command's code).
expect_exit() { local want="$1"; shift; local rc=0; "$@" >/dev/null 2>&1 || rc=$?
  [[ "$rc" -eq "$want" ]]; }

# 1. ok: handshake + two pages merge; hidden included only with the flag.
out="$(run ok --include-hidden 2>/dev/null)" || fail "1: exit $?"
[[ "$(printf '%s' "$out" | jq -r '.count')" == "4" ]] || fail "1 count: $out"
[[ "$(printf '%s' "$out" | jq -r '.models[] | select(.id=="gpt-5.4-mini") | .id')" == "gpt-5.4-mini" ]] \
  || fail "1 page2 merge missing: $out"

# 2. retirement metadata (retirementAt + successor) is preserved.
out="$(run ok 2>/dev/null)" || fail "2: exit $?"
succ="$(printf '%s' "$out" | jq -r '.models[] | select(.id=="gpt-5.5") | .upgradeInfo.successor')"
ret="$(printf '%s' "$out" | jq -r '.models[] | select(.id=="gpt-5.5") | .upgradeInfo.retirementAt')"
[[ "$succ" == "gpt-5.6-terra" ]] || fail "2 successor: $out"
[[ "$ret" == "1790000000" ]]     || fail "2 retirementAt: $out"

# 3. stderr flood does not deadlock; the catalog still returns.
out="$(run flood --include-hidden 2>/dev/null)" || fail "3: exit $?"
[[ "$(printf '%s' "$out" | jq -r '.count')" == "4" ]] || fail "3 flood count: $out"

# 4. no-init handshake -> discovery timeout, exit 4, no stdout catalog.
expect_exit 4 run noinit --timeout 2 || fail "4: noinit should time out with exit 4"

# 5. rpc error on model/list -> protocol, exit 5.
expect_exit 5 run rpcerror || fail "5: rpcerror should fail with exit 5"

# 6. malformed (non-JSON) response line -> protocol, exit 5.
expect_exit 5 run badjson || fail "6: badjson should fail with exit 5"

# 7. repeated pagination cursor -> guarded, exit 5 (no infinite loop).
expect_exit 5 run repeatcursor --include-hidden || fail "7: repeatcursor should fail with exit 5"

# 8. tsv display mode emits one row per model.
rows="$(run ok --tsv --include-hidden 2>/dev/null | wc -l | tr -d ' ')"
[[ "$rows" == "4" ]] || fail "8 tsv rows: $rows"

printf 'PASS: codex-models.sh\n'
