#!/usr/bin/env bash
# Demo for scripts/agent-watch.py: dispatches a short real agy run in the
# background and watches it live. Usage: bash scripts/demo-agent-watch.sh
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="$(mktemp /tmp/agent-watch-demo-XXXXXX)"

command -v agy >/dev/null || { echo "agy not found"; exit 1; }

cd "$REPO_ROOT"

# Several small allowed commands, so the activity line visibly advances.
agy --print "Do these one at a time, using a separate shell command for each:
1. wc -l README.md
2. wc -l setup.sh
3. ls scripts
4. grep -c agy README.md
Then reply DONE." \
  --model gemini-3.8-flash-low \
  --output-format stream-json \
  --print-timeout 5m \
  > "$LOG" 2>/dev/null &
dispatch=$!

python3 "$REPO_ROOT/scripts/agent-watch.py" "$LOG" --tool agy --model gemini-3.8-flash-low
wait "$dispatch" 2>/dev/null

echo
echo "log: $LOG"
