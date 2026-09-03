#!/usr/bin/env python3
"""Live view for a delegated codex or agy run.

Renders one self-updating line while a dispatch is in flight:

    ✻ codex · gpt-5.6-terra · 4m12s · run: bash tests/setup.sh · 12 edits

Point it at the log the dispatch is writing. The format is detected from the
stream, so the same command works for both tools:

    codex exec --json ... > run.jsonl &
    scripts/agent-watch.py run.jsonl

    agy --print ... --output-format stream-json > run.ndjson &
    scripts/agent-watch.py run.ndjson

It reports only observable facts - the process, the bytes on disk, the events
the tool emitted. It never reports a tool's own claim of success, because a run
that did nothing still exits 0 and still says SUCCESS.
"""

import json
import os
import sys
import time

SPINNER = "✻✳✶✻✳✶"
DIM, BOLD, RED, GREEN, YELLOW, RESET = (
    "\033[2m", "\033[1m", "\033[31m", "\033[32m", "\033[33m", "\033[0m",
)
STALL_SECONDS = 120


def elapsed(seconds):
    m, s = divmod(int(seconds), 60)
    return f"{m}m{s:02d}s" if m else f"{s}s"


class State:
    def __init__(self):
        self.tool = None
        self.model = None
        self.activity = "starting"
        self.commands = 0
        self.edits = 0
        self.denials = 0
        self.done = False
        self.outcome = None
        self.last_event = time.time()

    def feed(self, event):
        self.last_event = time.time()

        # codex: {"type": "item.started", "item": {"type": ..., ...}}
        if "type" in event and "event" not in event:
            self.tool = self.tool or "codex"
            kind = event.get("type")
            item = event.get("item", {}) or {}
            itype = item.get("type")
            if itype == "command_execution":
                if kind == "item.started":
                    self.activity = "run: " + (item.get("command") or "")[:70]
                else:
                    self.commands += 1
            elif itype == "file_change":
                self.edits += 1
                self.activity = "editing"
            elif itype == "agent_message" and kind == "item.completed":
                self.activity = "writing result"
            if kind == "turn.completed":
                self.done, self.outcome = True, "turn completed"
            elif kind == "turn.failed":
                self.done, self.outcome = True, "turn FAILED"
            return

        # agy: {"event": "init" | "step_update" | "result", ...}
        name = event.get("event")
        self.tool = self.tool or "agy"
        if name == "init":
            self.model = (event.get("init") or {}).get("model")
            self.activity = "initialising"
        elif name == "step_update":
            step = event.get("step_update") or {}
            stype, tool_name = step.get("step_type"), step.get("tool_name")
            if step.get("state") == "ACTIVE":
                self.activity = f"step {step.get('step_index')}: {tool_name or stype}"
            elif stype == "tool":
                self.commands += 1
        elif name == "result":
            result = event.get("result") or {}
            body = result.get("response") or ""
            self.done = True
            # An empty response is the signature of a run whose tools were all
            # auto-denied. The status field says SUCCESS either way.
            self.outcome = "EMPTY RESPONSE - likely auto-denied" if not body.strip() \
                else f"responded ({len(body)} chars)"


def render(state, started, frame, stalled):
    spin = SPINNER[frame % len(SPINNER)]
    age = time.time() - started
    parts = [
        f"{BOLD}{spin} {state.tool or '?'}{RESET}",
        f"{DIM}{state.model or 'model?'}{RESET}",
        elapsed(age),
        state.activity,
    ]
    counts = []
    if state.commands:
        counts.append(f"{state.commands} cmd")
    if state.edits:
        counts.append(f"{state.edits} edits")
    if counts:
        parts.append(f"{GREEN}{' · '.join(counts)}{RESET}")
    if stalled:
        parts.append(f"{YELLOW}no output {elapsed(time.time() - state.last_event)}{RESET}")
    line = f"{DIM} · {RESET}".join(parts)
    sys.stderr.write("\r\033[2K" + line)
    sys.stderr.flush()


def main():
    if len(sys.argv) < 2:
        sys.exit("usage: agent-watch.py <logfile>")
    path = sys.argv[1]

    started = time.time()
    state = State()
    frame = 0
    pos = 0

    # The dispatch may not have created the file yet.
    while not os.path.exists(path):
        render(state, started, frame, False)
        frame += 1
        time.sleep(0.25)

    while True:
        with open(path, "r", errors="replace") as fh:
            fh.seek(pos)
            while True:
                # readline() keeps tell() usable; iterating the handle does not.
                line = fh.readline()
                if not line:
                    break
                if not line.endswith("\n"):      # partial write; retry next tick
                    break
                pos = fh.tell()
                line = line.strip()
                if not line:
                    continue
                try:
                    state.feed(json.loads(line))
                except (json.JSONDecodeError, AttributeError):
                    continue

        stalled = (time.time() - state.last_event) > STALL_SECONDS
        render(state, started, frame, stalled)
        frame += 1

        if state.done:
            colour = RED if "EMPTY" in (state.outcome or "") or "FAIL" in (state.outcome or "") else GREEN
            sys.stderr.write(
                f"\r\033[2K{colour}●{RESET} {state.tool} finished in {elapsed(time.time() - started)}"
                f" · {state.commands} cmd · {state.edits} edits · {state.outcome}\n"
            )
            sys.stderr.flush()
            return 0

        time.sleep(0.25)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.stderr.write("\n")
        sys.exit(130)
