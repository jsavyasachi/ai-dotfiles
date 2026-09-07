#!/usr/bin/env bash
#
# Unit tests for scripts/sync-agy-settings.sh - the scoped deep-merge that
# manages agy's read-only permissions.allow allowlist and enableTelemetry
# flag, while leaving every other key (model, trustedWorkspaces, anything
# agy adds at runtime) byte-preserved.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SYNC="$REPO_ROOT/scripts/sync-agy-settings.sh"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/sync-agy-settings-test-XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

TPL="$WORK/tpl.json"
cat > "$TPL" <<'JSON'
{
  "enableTelemetry": false,
  "permissions": { "allow": ["command(cat)", "command(git)"] }
}
JSON

# 1. Missing dest: creates it from the template alone.
DEST="$WORK/missing.json"
"$SYNC" "$TPL" "$DEST" || fail "1: exit $?"
[[ "$(jq -r '.enableTelemetry' "$DEST")" == "false" ]] || fail "1 enableTelemetry: $(cat "$DEST")"
[[ "$(jq -c '.permissions.allow' "$DEST")" == '["command(cat)","command(git)"]' ]] \
  || fail "1 allow: $(cat "$DEST")"

# 2. Existing dest with model/trustedWorkspaces/stale allow: those keys are
#    preserved byte-for-byte in value; only the managed keys change.
DEST="$WORK/existing.json"
cat > "$DEST" <<'JSON'
{"model":"Claude Opus 4.6 (Thinking)","trustedWorkspaces":["/Users/savya/projects"],"permissions":{"allow":["command(*)"]}}
JSON
"$SYNC" "$TPL" "$DEST" || fail "2: exit $?"
[[ "$(jq -r '.model' "$DEST")" == "Claude Opus 4.6 (Thinking)" ]] || fail "2 model clobbered: $(cat "$DEST")"
[[ "$(jq -c '.trustedWorkspaces' "$DEST")" == '["/Users/savya/projects"]' ]] \
  || fail "2 trustedWorkspaces clobbered: $(cat "$DEST")"
[[ "$(jq -c '.permissions.allow' "$DEST")" == '["command(cat)","command(git)"]' ]] \
  || fail "2 allow not replaced: $(cat "$DEST")"
[[ "$(jq -r '.enableTelemetry' "$DEST")" == "false" ]] || fail "2 enableTelemetry: $(cat "$DEST")"

# 3. Malformed dest JSON: warns on stderr, treated as empty, still writes a
#    valid merged file (never crashes, never leaves a half-written dest).
DEST="$WORK/malformed.json"
printf 'not json at all' > "$DEST"
err="$("$SYNC" "$TPL" "$DEST" 2>&1 >/dev/null)" || fail "3: exit $?"
[[ -n "$err" ]] || fail "3: expected a warning on stderr for malformed dest"
jq -e . "$DEST" >/dev/null 2>&1 || fail "3: dest is not valid JSON after sync: $(cat "$DEST")"
[[ "$(jq -c '.permissions.allow' "$DEST")" == '["command(cat)","command(git)"]' ]] \
  || fail "3 allow: $(cat "$DEST")"

# 4. Idempotent rerun: second call with an already-merged dest changes nothing
#    and exits 0.
DEST="$WORK/idempotent.json"
cat > "$DEST" <<'JSON'
{"model":"x","permissions":{"allow":["command(cat)","command(git)"]},"enableTelemetry":false}
JSON
"$SYNC" "$TPL" "$DEST" || fail "4a: exit $?"
before="$(cat "$DEST")"
"$SYNC" "$TPL" "$DEST" || fail "4b: exit $?"
after="$(cat "$DEST")"
[[ "$before" == "$after" ]] || fail "4: rerun should not change an already-merged dest"

printf 'PASS: sync-agy-settings.sh\n'
