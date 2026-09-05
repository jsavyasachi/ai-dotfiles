#!/usr/bin/env bash
#
# Unit tests for scripts/band-resolve.sh - the offline, deterministic band ->
# model resolver. It is pure configuration lookup: no network, no catalog
# discovery, no dispatch. These tests assert the resolution contract the review
# hardened - JSON out (never eval-able), fail-closed on invalid policy,
# per-cell balanced fallback that never crosses bands, and a self-path lookup
# that survives being invoked through an installed symlink from an unrelated
# directory.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESOLVE="$REPO_ROOT/scripts/band-resolve.sh"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/band-resolve-test-XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# A self-contained fixture: balanced is the canonical band set; cost_first is a
# sparse override (staff present, senior omitted, engineer malformed).
FIX="$WORK/bands.json"
cat > "$FIX" <<'JSON'
{
  "schema_version": 1,
  "defaults": { "stance": "balanced" },
  "routes": {
    "balanced": {
      "codex": {
        "staff":    { "model": "gpt-5.6-sol",   "effort": "high"   },
        "senior":   { "model": "gpt-5.6-terra", "effort": "medium" },
        "engineer": { "model": "gpt-5.6-luna",  "effort": "low"    }
      },
      "agy": {
        "senior": { "model": "gemini-3.1-pro-high" }
      }
    },
    "cost_first": {
      "codex": {
        "staff":    { "model": "gpt-5.6-sol", "effort": "medium" },
        "engineer": { "note": "malformed - no model" }
      }
    }
  }
}
JSON

j() { printf '%s' "$1" | jq -r "$2"; }

# 1. Plain resolve: codex/balanced/staff -> sol/high, not fell back.
out="$("$RESOLVE" --backend codex --band staff --stance balanced --bands-file "$FIX")" \
  || fail "1: exit $?"
[[ "$(j "$out" .model)"    == "gpt-5.6-sol" ]] || fail "1 model: $out"
[[ "$(j "$out" .effort)"   == "high"        ]] || fail "1 effort: $out"
[[ "$(j "$out" .fell_back)" == "false"      ]] || fail "1 fell_back: $out"

# 2. Default stance is balanced when --stance omitted.
out="$("$RESOLVE" --backend codex --band senior --bands-file "$FIX")" || fail "2: exit $?"
[[ "$(j "$out" .model)"  == "gpt-5.6-terra" ]] || fail "2 model: $out"
[[ "$(j "$out" .stance)" == "balanced"      ]] || fail "2 stance: $out"

# 3. Stance override present: cost_first/staff -> sol/medium (still meets bar).
out="$("$RESOLVE" --backend codex --band staff --stance cost_first --bands-file "$FIX")" \
  || fail "3: exit $?"
[[ "$(j "$out" .effort)"    == "medium" ]] || fail "3 effort: $out"
[[ "$(j "$out" .fell_back)" == "false"  ]] || fail "3 fell_back: $out"

# 4. Omitted override cell falls back to balanced for THAT cell, and says so.
out="$("$RESOLVE" --backend codex --band senior --stance cost_first --bands-file "$FIX")" \
  || fail "4: exit $?"
[[ "$(j "$out" .model)"     == "gpt-5.6-terra" ]] || fail "4 model (should be balanced): $out"
[[ "$(j "$out" .fell_back)" == "true"          ]] || fail "4 fell_back: $out"

# 5. agy cell has no effort key at all (effort is baked into the slug).
out="$("$RESOLVE" --backend agy --band senior --bands-file "$FIX")" || fail "5: exit $?"
[[ "$(j "$out" .model)"          == "gemini-3.1-pro-high" ]] || fail "5 model: $out"
[[ "$(j "$out" 'has("effort")')" == "false"              ]] || fail "5 effort absent: $out"

# 6. Unknown band -> fail closed (not a silent balanced pick).
if "$RESOLVE" --backend codex --band nope --bands-file "$FIX" >/dev/null 2>&1; then
  fail "6: unknown band should have failed"
fi

# 7. Unknown stance -> fail closed (a typo must NOT resolve to balanced).
if "$RESOLVE" --backend codex --band staff --stance blanaced --bands-file "$FIX" >/dev/null 2>&1; then
  fail "7: unknown stance should have failed"
fi

# 8. Unknown backend -> fail closed.
if "$RESOLVE" --backend nope --band staff --bands-file "$FIX" >/dev/null 2>&1; then
  fail "8: unknown backend should have failed"
fi

# 9. Malformed cell (present but no model) -> fail, never concealed by fallback.
if "$RESOLVE" --backend codex --band engineer --stance cost_first --bands-file "$FIX" >/dev/null 2>&1; then
  fail "9: malformed cell should have failed, not fallen back"
fi

# 10. Missing --band value (arity guard) must not hang or misparse; exit non-zero.
if "$RESOLVE" --backend codex --band >/dev/null 2>&1; then
  fail "10: dangling --band should fail"
fi

# 11. Output is pure JSON - no shell-eval-able assignment lines leak.
out="$("$RESOLVE" --backend codex --band staff --bands-file "$FIX")" || fail "11: exit $?"
printf '%s' "$out" | jq -e . >/dev/null 2>&1 || fail "11: output not valid JSON: $out"

# 12. Installed-symlink case: invoked through a symlink from an unrelated cwd
#     with NO --bands-file, it must resolve its own real path and find the
#     repo's real config/bands.json (a real band from it).
ln -s "$RESOLVE" "$WORK/band-resolve"
out="$(cd / && "$WORK/band-resolve" --backend codex --band staff)" \
  || fail "12: symlinked invocation failed: exit $?"
[[ "$(j "$out" .model)" == "gpt-5.6-sol" ]] || fail "12 model from real config: $out"

# 13. Path with spaces in the bands-file location.
SP="$WORK/dir with spaces"
mkdir -p "$SP"; cp "$FIX" "$SP/bands.json"
out="$("$RESOLVE" --backend codex --band staff --bands-file "$SP/bands.json")" \
  || fail "13: spaces in path failed"
[[ "$(j "$out" .model)" == "gpt-5.6-sol" ]] || fail "13 model: $out"

printf 'PASS: band-resolve.sh\n'
