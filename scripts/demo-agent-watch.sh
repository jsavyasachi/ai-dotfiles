#!/usr/bin/env bash
# Demo for scripts/agent-watch.py: dispatches a short real agy run in the
# background and watches it live. Usage: bash scripts/demo-agent-watch.sh
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="$(mktemp /tmp/agent-watch-demo-XXXXXX)"

command -v agy >/dev/null || { echo "agy not found"; exit 1; }

cd "$REPO_ROOT"

# Two separate allowed commands, so the activity line visibly advances. agy
# batches commands if invited to, and a batched line matches no command(<name>)
# allow-rule, so the prompt insists on separate invocations.
agy --print "Run wc -l README.md as one shell command. Then, as a separate
shell command, run wc -l setup.sh. Do not combine them. Then reply DONE." \
  --model gemini-3.8-flash-low \
  --output-format stream-json \
  --print-timeout 5m \
  > "$LOG" 2>/dev/null &
dispatch=$!

python3 "$REPO_ROOT/scripts/agent-watch.py" "$LOG" --tool agy --model gemini-3.8-flash-low
wait "$dispatch" 2>/dev/null

echo
echo "log: $LOG"
