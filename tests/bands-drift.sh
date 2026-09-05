#!/usr/bin/env bash
#
# Unit tests for scripts/bands-drift.sh - the read-only churn reporter. Both
# catalogs are stubbed: codex via CODEX_BIN (a fake app-server that codex-models
# drives) and agy via AGY_BIN.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DRIFT="$REPO_ROOT/scripts/bands-drift.sh"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
WORK="$(mktemp -d "${TMPDIR:-/tmp}/bands-drift-test-XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# Fake codex app-server: catalog has gpt-6-astra, gpt-5.5 (retiring), gpt-5.4-mini.
cat > "$WORK/codex" <<'PY'
#!/usr/bin/env python3
import json, os, sys
if sys.argv[1:2] != ["app-server"]: sys.exit("bad")
def out(o): sys.stdout.write(json.dumps(o)+"\n"); sys.stdout.flush()
DATA=[
 {"id":"gpt-6-astra","model":"gpt-6-astra","isDefault":True,"hidden":False,"defaultReasoningEffort":"low","supportedReasoningEfforts":[]},
 {"id":"gpt-5.5","model":"gpt-5.5","hidden":False,"defaultReasoningEffort":"medium","supportedReasoningEfforts":[],"upgradeInfo":{"model":"gpt-5.6-terra","retirementAt":1790000000}},
 {"id":"gpt-5.4-mini","model":"gpt-5.4-mini","hidden":False,"defaultReasoningEffort":"medium","supportedReasoningEfforts":[]},
]
for line in sys.stdin:
    line=line.strip()
    if not line: continue
    m=json.loads(line); meth=m.get("method"); mid=m.get("id")
    if meth=="initialize": out({"jsonrpc":"2.0","id":mid,"result":{}})
    elif meth=="initialized": continue
    elif meth=="model/list": out({"jsonrpc":"2.0","id":mid,"result":{"data":DATA,"nextCursor":None}})
PY
chmod +x "$WORK/codex"

# Fake agy: catalog has pro-high and flash-high.
cat > "$WORK/agy" <<'SH'
#!/usr/bin/env bash
[[ "${1:-}" == "models" ]] || exit 1
printf 'gemini-3.1-pro-high\tGemini 3.1 Pro (High)\n'
printf 'gemini-3.8-flash-high\tGemini 3.8 Flash (High)\n'
SH
chmod +x "$WORK/agy"

# bands.json referencing a present codex slug, an ABSENT codex slug, a present
# agy slug and an ABSENT agy slug.
cat > "$WORK/bands.json" <<'JSON'
{ "schema_version": 1, "defaults": { "stance": "balanced" },
  "routes": { "balanced": {
    "codex": { "distinguished": { "model": "gpt-6-astra", "effort": "high" },
               "staff": { "model": "gpt-5.6-sol", "effort": "high" } },
    "agy": { "senior": { "model": "gemini-3.1-pro-high" },
             "mid": { "model": "gemini-9-ghost-medium" } } } } }
JSON

export CODEX_BIN="$WORK/codex" AGY_BIN="$WORK/agy"
out="$(bash "$DRIFT" --bands-file "$WORK/bands.json" --timeout 10 2>/dev/null)" || fail "drift exited $?"

grep -q 'CODEX RETIRING gpt-5.5 .* -> gpt-5.6-terra' <<<"$out" || fail "missing codex retiring: $out"
grep -q 'CODEX ABSENT gpt-5.6-sol'                   <<<"$out" || fail "missing codex absent: $out"
grep -q 'CODEX UNASSIGNED gpt-5.4-mini'              <<<"$out" || fail "missing codex unassigned: $out"
grep -q 'AGY ABSENT gemini-9-ghost-medium'           <<<"$out" || fail "missing agy absent: $out"
grep -q 'AGY UNASSIGNED gemini-3.8-flash-high'        <<<"$out" || fail "missing agy unassigned: $out"

# A present slug must NOT be reported absent.
grep -q 'CODEX ABSENT gpt-6-astra' <<<"$out" && fail "present codex slug wrongly reported absent"

# Discovery failure is UNAVAILABLE, not fatal and not ABSENT.
export CODEX_BIN="/nonexistent/codex-binary-xyz"
out2="$(bash "$DRIFT" --bands-file "$WORK/bands.json" --timeout 5 2>/dev/null)" || fail "drift should still exit 0 on codex-unavailable"
grep -q 'CODEX UNAVAILABLE' <<<"$out2" || fail "expected CODEX UNAVAILABLE: $out2"

printf 'PASS: bands-drift.sh\n'
