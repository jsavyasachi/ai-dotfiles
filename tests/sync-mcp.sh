#!/usr/bin/env bash
#
# Unit tests for scripts/sync-mcp.sh - fans config/mcp-servers.json out to
# every agent. `merge` is a pure JSON filter for the file-managed agents
# (OpenCode, Cursor); `register` drives each CLI-managed agent's own
# `mcp add` (Claude, Codex, agy, Pi). CLIs are stubbed via *_BIN.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SYNC="$REPO_ROOT/scripts/sync-mcp.sh"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/sync-mcp-test-XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

MANIFEST="$WORK/mcp-servers.json"
cat > "$MANIFEST" <<'JSON'
{ "monarch": { "url": "https://api.monarch.com/mcp" } }
JSON

# Stub CLI: appends "<tool> <args>" to $STUB_LOG. `mcp get <name>` exits 0
# only when <name> is listed in $STUB_PRESENT.
make_stub() {
  local path="$1" tool="$2"
  cat > "$path" <<STUB
#!/usr/bin/env bash
printf '%s %s\n' "$tool" "\$*" >> "\$STUB_LOG"
if [[ "\${1:-}" == "mcp" && "\${2:-}" == "get" ]]; then
  [[ " \${STUB_PRESENT:-} " == *" \${3:-} "* ]] && exit 0
  exit 1
fi
exit 0
STUB
  chmod +x "$path"
}

for t in claude codex agy pi; do make_stub "$WORK/$t" "$t"; done
export CLAUDE_BIN="$WORK/claude" CODEX_BIN="$WORK/codex" AGY_BIN="$WORK/agy" PI_BIN="$WORK/pi"

# 1. merge opencode: adds flat mcp.<name> remote entry, keeps other keys.
out="$(printf '%s' '{"model":"x","mcp":{"keep":{"type":"local","command":["a"]}}}' \
  | "$SYNC" merge opencode "$MANIFEST")" || fail "1: exit $?"
[[ "$(jq -r '.model' <<<"$out")" == "x" ]] || fail "1 model lost: $out"
[[ "$(jq -c '.mcp.monarch' <<<"$out")" == '{"type":"remote","url":"https://api.monarch.com/mcp"}' ]] \
  || fail "1 monarch: $out"
[[ "$(jq -r '.mcp.keep.type' <<<"$out")" == "local" ]] || fail "1 keep lost: $out"

# 2. merge cursor: adds mcpServers.<name>.url, keeps existing servers.
out="$(printf '%s' '{"mcpServers":{"slack":{"url":"https://mcp.slack.com/mcp","auth":{"CLIENT_ID":"1"}}}}' \
  | "$SYNC" merge cursor "$MANIFEST")" || fail "2: exit $?"
[[ "$(jq -c '.mcpServers.monarch' <<<"$out")" == '{"url":"https://api.monarch.com/mcp"}' ]] \
  || fail "2 monarch: $out"
[[ "$(jq -r '.mcpServers.slack.auth.CLIENT_ID' <<<"$out")" == "1" ]] || fail "2 slack lost: $out"

# 3. merge with unknown target fails.
if printf '{}' | "$SYNC" merge bogus "$MANIFEST" >/dev/null 2>&1; then fail "3: bogus target accepted"; fi

# 4. register, nothing present: each CLI gets its own add invocation.
export STUB_LOG="$WORK/log4"; : > "$STUB_LOG"
STUB_PRESENT="" "$SYNC" register "$MANIFEST" >/dev/null || fail "4: exit $?"
grep -Fxq 'claude mcp add --scope user --transport http monarch https://api.monarch.com/mcp' "$STUB_LOG" \
  || fail "4 claude: $(cat "$STUB_LOG")"
grep -Fxq 'codex mcp add monarch --url https://api.monarch.com/mcp' "$STUB_LOG" \
  || fail "4 codex: $(cat "$STUB_LOG")"
grep -Fxq 'agy mcp add --type http monarch https://api.monarch.com/mcp' "$STUB_LOG" \
  || fail "4 agy: $(cat "$STUB_LOG")"
grep -Fxq 'pi mcp add monarch --url https://api.monarch.com/mcp' "$STUB_LOG" \
  || fail "4 pi: $(cat "$STUB_LOG")"

# 5. register, already present in claude+codex: no add for them (keeps OAuth
#    state and avoids rewriting codex's config.toml).
export STUB_LOG="$WORK/log5"; : > "$STUB_LOG"
STUB_PRESENT="monarch" "$SYNC" register "$MANIFEST" >/dev/null || fail "5: exit $?"
if grep -Eq '^(claude|codex) mcp add' "$STUB_LOG"; then fail "5 re-added: $(cat "$STUB_LOG")"; fi

# 6. register with a missing CLI: reports skip, still registers the rest.
export STUB_LOG="$WORK/log6"; : > "$STUB_LOG"
out="$(CODEX_BIN="$WORK/nope" STUB_PRESENT="" "$SYNC" register "$MANIFEST")" || fail "6: exit $?"
grep -Fq 'skip codex' <<<"$out" || fail "6 no skip line: $out"
grep -Fq 'pi mcp add' "$STUB_LOG" || fail "6 pi not registered: $(cat "$STUB_LOG")"

# 7. invalid manifest fails closed.
printf '{"bad":{}}' > "$WORK/bad.json"
if "$SYNC" register "$WORK/bad.json" >/dev/null 2>&1; then fail "7: entry without url accepted"; fi

echo "sync-mcp: all tests passed"
