#!/usr/bin/env bash
#
# Unit tests for scripts/bands-validate.py - the offline structural validator.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
V="$REPO_ROOT/scripts/bands-validate.py"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
WORK="$(mktemp -d "${TMPDIR:-/tmp}/bands-validate-test-XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

expect_exit() { local want="$1"; shift; local rc=0; python3 "$V" "$@" >/dev/null 2>&1 || rc=$?
  [[ "$rc" -eq "$want" ]]; }

# 1. The shipped config is valid.
expect_exit 0 "$REPO_ROOT/config/bands.json" || fail "1: shipped bands.json should validate"

good() { cat > "$1" <<'JSON'
{ "schema_version": 1, "defaults": { "stance": "balanced" },
  "routes": { "balanced": { "codex": { "staff": { "model": "m", "effort": "high" } } },
              "cost_first": { "codex": { "staff": { "model": "m", "effort": "low" } } } } }
JSON
}

# 2. A well-formed minimal fixture validates.
good "$WORK/ok.json"; expect_exit 0 "$WORK/ok.json" || fail "2: minimal good should validate"

# 3. Wrong schema version -> invalid.
good "$WORK/sv.json"; sed 's/"schema_version": 1/"schema_version": 9/' "$WORK/ok.json" > "$WORK/sv.json"
expect_exit 3 "$WORK/sv.json" || fail "3: bad schema_version should fail"

# 4. Duplicate JSON key -> invalid (not silently last-wins).
cat > "$WORK/dup.json" <<'JSON'
{ "schema_version": 1,
  "routes": { "balanced": { "codex": { "staff": { "model": "a" }, "staff": { "model": "b" } } } } }
JSON
expect_exit 3 "$WORK/dup.json" || fail "4: duplicate key should fail"

# 5. Cell without a model -> invalid.
cat > "$WORK/nomodel.json" <<'JSON'
{ "schema_version": 1, "routes": { "balanced": { "codex": { "staff": { "effort": "high" } } } } }
JSON
expect_exit 3 "$WORK/nomodel.json" || fail "5: missing model should fail"

# 6. Stance override for a band absent from balanced -> invalid.
cat > "$WORK/orphan.json" <<'JSON'
{ "schema_version": 1,
  "routes": { "balanced": { "codex": { "staff": { "model": "m" } } },
              "cost_first": { "codex": { "ghost": { "model": "m" } } } } }
JSON
expect_exit 3 "$WORK/orphan.json" || fail "6: orphan override band should fail"

# 7. Usage error (no arg) -> exit 2.
expect_exit 2 || fail "7: missing arg should exit 2"

printf 'PASS: bands-validate.sh\n'
