#!/usr/bin/env bash
#
# agy-dispatch.sh - the one correct way to dispatch a headless agy run.
#
# A language model must never hand-assemble the agy invocation: it hallucinates
# subcommands (there is no `agy exec`; it is `agy --print`) and cannot reliably
# tell a real run from agy's silent no-op, where a tool auto-denied in headless
# mode still returns `"status": "SUCCESS"` with an empty response. This script
# owns the invocation and collapses "did the run actually happen" into an exit
# code, so callers check the exit code, never their own judgment.
#
# Usage:
#   agy-dispatch.sh --prompt-file <f> --model <slug> \
#     [--mode plan|accept-edits] [--schema <f>] [--timeout <dur>] \
#     [--cwd <dir>] [--out-dir <dir>]
#
# On success: prints a KEY=value block (conversation_id, model, status,
# response_chars, log, err) to stdout and exits 0.
# On failure: prints "DISPATCH FAILED: <reason>" plus log/err paths and exits
# non-zero. The stdout of a failed run is never a usable result.
#
# The agy binary is $AGY_BIN (default `agy`), injectable for tests.

set -uo pipefail

AGY_BIN="${AGY_BIN:-agy}"

mode="plan"
timeout="30m"
cwd="."
prompt_file=""
model=""
schema=""
out_dir=""

die() { printf 'DISPATCH FAILED: %s\n' "$*" >&2; exit "${2:-1}"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prompt-file) prompt_file="${2:-}"; shift 2 ;;
    --model)       model="${2:-}"; shift 2 ;;
    --mode)        mode="${2:-}"; shift 2 ;;
    --schema)      schema="${2:-}"; shift 2 ;;
    --timeout)     timeout="${2:-}"; shift 2 ;;
    --cwd)         cwd="${2:-}"; shift 2 ;;
    --out-dir)     out_dir="${2:-}"; shift 2 ;;
    *) die "unknown argument: $1" 2 ;;
  esac
done

[[ -n "$prompt_file" ]] || die "--prompt-file is required" 2
[[ -n "$model" ]]       || die "--model is required" 2
[[ -f "$prompt_file" ]] || die "prompt file not found: $prompt_file" 2
[[ -d "$cwd" ]]         || die "--cwd not a directory: $cwd" 2

# Validate the slug against the live catalog. agy's slugs change between
# releases; a stale one is the difference between a real run and a wasted call.
if ! catalog="$("$AGY_BIN" models 2>/dev/null)"; then
  die "could not read agy catalog ('$AGY_BIN models' failed)" 3
fi
if ! awk '{print $1}' <<<"$catalog" | grep -Fxq "$model"; then
  die "model '$model' not in agy catalog (run '$AGY_BIN models')" 3
fi

# Fresh output dir every dispatch. A pre-existing file at a fixed path is
# indistinguishable from this run's output and is the classic stale-replay bug,
# so never write to a predictable name.
if [[ -z "$out_dir" ]]; then
  out_dir="$(mktemp -d "${TMPDIR:-/tmp}/agy-dispatch-XXXXXX")"
else
  mkdir -p "$out_dir"
fi
log="$out_dir/agy.json"
err="$out_dir/agy.err"

set -- --print "$(cat "$prompt_file")" \
  --mode "$mode" \
  --model "$model" \
  --output-format json \
  --print-timeout "$timeout"
[[ -n "$schema" ]] && set -- "$@" --json-schema "$schema"

# Capture agy's own exit status directly. Never chain a command after the
# dispatch on one line: a trailing command's success masks a failed launch.
( cd "$cwd" && "$AGY_BIN" "$@" ) >"$log" 2>"$err" </dev/null
agy_rc=$?

if [[ "$agy_rc" -ne 0 ]]; then
  die "agy exited $agy_rc (see $err)" 4
fi

# Parse the single JSON result object.
read -r conversation_id status response_chars < <(
  python3 - "$log" <<'PY'
import json, sys
try:
    with open(sys.argv[1]) as fh:
        obj = json.load(fh)
except Exception:
    print("PARSE_ERROR NONE 0"); sys.exit(0)
cid = obj.get("conversation_id") or "NONE"
status = obj.get("status") or "NONE"
resp = obj.get("response") or ""
print(cid, status, len(resp.strip()))
PY
)

[[ "$conversation_id" == "PARSE_ERROR" ]] && die "agy output was not valid JSON (see $log)" 5
[[ "$conversation_id" == "NONE" ]] && die "no conversation_id in agy output (see $log)" 5

# The silent no-op: SUCCESS with an empty response means every tool call was
# auto-denied. Surface the permission family from stderr if agy named one.
if [[ "$response_chars" -eq 0 ]]; then
  denied="$(sed -n 's/.*required the "\([a-z_]*\)" permission.*/\1/p' "$err" | head -1)"
  if [[ -n "$denied" ]]; then
    die "empty response - '$denied' permission auto-denied in headless mode (see $err)" 6
  fi
  die "empty response - tool calls likely auto-denied (see $err)" 6
fi

printf 'DISPATCH_OK\n'
printf 'conversation_id=%s\n' "$conversation_id"
printf 'model=%s\n' "$model"
printf 'status=%s\n' "$status"
printf 'response_chars=%s\n' "$response_chars"
printf 'log=%s\n' "$log"
printf 'err=%s\n' "$err"
