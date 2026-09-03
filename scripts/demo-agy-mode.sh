#!/usr/bin/env bash
# Demonstrates that an agy resume does not inherit the original session's mode.
#
#   1. session with --mode accept-edits   -> write succeeds
#   2. resume WITHOUT --mode              -> identical write is auto-denied
#   3. resume WITH --mode accept-edits    -> write succeeds again
#
# Usage: bash scripts/demo-agy-mode.sh
set -uo pipefail

MODEL=gemini-3.8-flash-low
T="$(mktemp -d /tmp/agy-mode-demo-XXXXXX)"
trap 'rm -rf "$T"' EXIT

command -v agy >/dev/null || { echo "agy not found"; exit 1; }

# Run from the directory being written to. agy denies writes outside its
# workspace whatever the mode, so a demo launched from elsewhere fails at every
# step and proves nothing about --mode.
cd "$T" || exit 1

run() {  # run <label> <file> [extra agy flags...]
  label=$1; target=$2; shift 2
  out=$(agy --print "Use your file-writing tool (NOT a shell command) to create \
$T/$target containing exactly OK. Then say DONE." \
    --model "$MODEL" --output-format json --print-timeout 5m "$@" 2>"$T/$target.err")
  cid=$(printf '%s' "$out" | python3 -c 'import json,sys; print(json.load(sys.stdin)["conversation_id"])')
  if [ -f "$T/$target" ]; then
    printf '  %-34s wrote %s\n' "$label" "$target" >&2
  else
    printf '  %-34s DENIED: %s permission\n' "$label" \
      "$(sed -n 's/.*required the "\([a-z_]*\)" permission.*/\1/p' "$T/$target.err" | head -1)" >&2
  fi
  printf '%s' "$cid"
}

echo "agy resume: does it inherit --mode?"
echo

cid=$(run "1. --mode accept-edits" file1.txt --mode accept-edits)
run "2. resume, no --mode" file2.txt --conversation "$cid" >/dev/null
run "3. resume, --mode accept-edits" file3.txt --conversation "$cid" --mode accept-edits >/dev/null

echo
echo "Conversation $cid was identical in all three. Only the flag differed."
