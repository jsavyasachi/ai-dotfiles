#!/usr/bin/env bash
# Brute-force the write_file(<target>) allow-rule syntax.
# For each candidate rule: install it as the ONLY write rule, ask agy to write a
# file at a fixed path, and report whether the write landed.
set -uo pipefail

S="$HOME/.gemini/antigravity-cli/settings.json"
BASE='["command(grep)","command(rg)","command(cat)","command(ls)","command(sed)","command(head)","command(tail)","command(wc)","command(find)","command(git)"]'
DIR=/tmp/agywf
TARGET="$DIR/f.txt"
MODEL=gemini-3.8-flash-low

mkdir -p "$DIR"
cp "$S" "$S.brutebak"
restore() { cp "$S.brutebak" "$S"; rm -f "$S.brutebak"; }
trap restore EXIT

try() {
  rule=$1
  rm -f "$TARGET"
  # install BASE + this one candidate rule
  jq --argjson base "$BASE" --arg r "$rule" \
     '.permissions.allow = ($base + [$r])' "$S" > "$S.tmp" && mv "$S.tmp" "$S"

  ( cd "$DIR" && agy --print "Use your file-writing tool (NOT a shell command, do not use sed or cat) \
to create $TARGET containing exactly OK. Then say DONE." \
      --mode accept-edits --model "$MODEL" --output-format json --print-timeout 3m \
      >/dev/null 2>"$DIR/err" )

  if [ -f "$TARGET" ]; then
    printf '  %-34s ALLOWED\n' "$rule"
  else
    perm=$(sed -n 's/.*required the "\([a-z_]*\)" permission.*/\1/p' "$DIR/err" | head -1)
    printf '  %-34s denied (%s)\n' "$rule" "${perm:-?}"
  fi
}

echo "brute-forcing write_file() target syntax against $TARGET"
echo
try "write_file($TARGET)"
try "write_file($DIR/*)"
try "write_file($DIR)"
try "write_file(f.txt)"
try "write_file"
try "write_file(*)"
echo
echo "settings restored"
