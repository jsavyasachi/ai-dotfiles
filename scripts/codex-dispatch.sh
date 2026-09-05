#!/usr/bin/env bash
#
# codex-dispatch.sh - the one correct way to dispatch a headless codex run.
#
# A language model must never hand-assemble the codex invocation. The two
# footguns this removes: chaining a command after `codex exec` on one line lets
# the trailing command's exit 0 mask a failed launch; and reading the JSONL
# stream by eye invites reporting a run that never started. This script owns the
# invocation, captures codex's own exit status directly, and requires a real
# `thread.started` id before it will report success.
#
# Usage:
#   codex-dispatch.sh --prompt-file <f> --model <slug> \
#     [--sandbox read-only|workspace-write] [--effort low|medium|high] \
#     [--cwd <dir>] [--out-dir <dir>]
#
# On success: prints a KEY=value block (thread_id, model, message_chars, log,
# err) to stdout and exits 0. On failure: prints "DISPATCH FAILED: <reason>"
# and exits non-zero.
#
# codex's deliverable in workspace-write is the diff, not the final message, so
# an empty agent_message is not itself a failure; the caller verifies the diff.
# The hard failure signals are a non-zero codex exit and a missing thread id.
#
# The codex binary is $CODEX_BIN (default `codex`), injectable for tests.

set -uo pipefail

CODEX_BIN="${CODEX_BIN:-codex}"

sandbox="read-only"
effort="medium"
cwd="."
prompt_file=""
model=""
out_dir=""

die() { printf 'DISPATCH FAILED: %s\n' "$1" >&2; exit "${2:-1}"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prompt-file) prompt_file="${2:-}"; shift 2 ;;
    --model)       model="${2:-}"; shift 2 ;;
    --sandbox)     sandbox="${2:-}"; shift 2 ;;
    --effort)      effort="${2:-}"; shift 2 ;;
    --cwd)         cwd="${2:-}"; shift 2 ;;
    --out-dir)     out_dir="${2:-}"; shift 2 ;;
    *) die "unknown argument: $1" 2 ;;
  esac
done

[[ -n "$prompt_file" ]] || die "--prompt-file is required" 2
[[ -n "$model" ]]       || die "--model is required" 2
[[ -f "$prompt_file" ]] || die "prompt file not found: $prompt_file" 2
[[ -d "$cwd" ]]         || die "--cwd not a directory: $cwd" 2

if [[ -z "$out_dir" ]]; then
  out_dir="$(mktemp -d "${TMPDIR:-/tmp}/codex-dispatch-XXXXXX")"
else
  mkdir -p "$out_dir"
fi
log="$out_dir/codex.jsonl"
err="$out_dir/codex.err"

# Redirect stdin from /dev/null: codex reads additional input from stdin and
# would otherwise block on an empty or interactive stream.
( cd "$cwd" && "$CODEX_BIN" exec --json \
    -s "$sandbox" \
    -m "$model" \
    -c model_reasoning_effort="$effort" \
    "$(cat "$prompt_file")" ) >"$log" 2>"$err" </dev/null
codex_rc=$?

if [[ "$codex_rc" -ne 0 ]]; then
  die "codex exited $codex_rc (see $err)" 4
fi

read -r thread_id message_chars < <(
  python3 - "$log" <<'PY'
import json, sys
thread_id = "NONE"
message = []
try:
    with open(sys.argv[1]) as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                ev = json.loads(line)
            except Exception:
                continue
            if ev.get("type") == "thread.started" and ev.get("thread_id"):
                thread_id = ev["thread_id"]
            item = ev.get("item") or {}
            if item.get("type") == "agent_message" and item.get("text"):
                message.append(item["text"])
except Exception:
    pass
print(thread_id, len("".join(message).strip()))
PY
)

[[ "$thread_id" == "NONE" ]] && die "no thread id in codex output - run never started (see $log)" 5

printf 'DISPATCH_OK\n'
printf 'thread_id=%s\n' "$thread_id"
printf 'model=%s\n' "$model"
printf 'message_chars=%s\n' "$message_chars"
printf 'log=%s\n' "$log"
printf 'err=%s\n' "$err"
