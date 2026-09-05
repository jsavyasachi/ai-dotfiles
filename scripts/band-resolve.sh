#!/usr/bin/env bash
#
# band-resolve.sh - resolve a capability BAND + STANCE to a concrete (model,
# effort) for a delegated codex/agy run. This is the one place model strings
# live, so churn is a one-file edit to config/bands.json and no call site
# changes.
#
# CONTRACT (hardened by the gpt-6-astra design review):
#   * PURE OFFLINE LOOKUP. No network, no catalog discovery, no dispatch, no
#     validation against a live catalog. Discovery/validation is a separate
#     concern; agy-dispatch already fail-closed-validates its slug at dispatch,
#     which stays the single authority. Keeping those apart means a discovery
#     outage can never block a route this script can resolve from config alone.
#   * EMITS ONE JSON OBJECT on stdout, diagnostics on stderr. Callers MUST parse
#     it (e.g. `jq -r .model`), never `eval`/`source` it. Nothing is emitted
#     until the whole result is known valid.
#   * FAIL CLOSED on invalid policy: unknown backend / band / stance, or a cell
#     that is present but malformed (no model), exits non-zero and prints
#     nothing on stdout. A typo must never silently resolve to `balanced`.
#   * PER-CELL FALLBACK, NEVER CROSS-BAND. `balanced` is the canonical band set.
#     Another stance is a sparse set of overrides; when a stance OMITS a cell
#     (the whole cell is absent) the balanced cell for the SAME band is used and
#     `fell_back:true` is reported. A cell that is PRESENT is authoritative and
#     is never second-guessed; fallback never hops to a different band.
#
# Usage:
#   band-resolve.sh --backend <codex|agy> --band <name> [--stance <name>] \
#                   [--bands-file <path>]
#
# Output (stdout, single line JSON):
#   {"backend":"codex","band":"staff","stance":"balanced",
#    "model":"gpt-5.6-sol","effort":"high","fell_back":false}
#   (agy cells carry no "effort" key - effort is baked into the slug.)
#
# Exit codes: 0 ok | 2 usage (bad/missing args) | 3 resolution (invalid policy).

set -euo pipefail

die_usage() { printf 'RESOLVE FAILED: %s\n' "$1" >&2; exit 2; }
die_policy() { printf 'RESOLVE FAILED: %s\n' "$1" >&2; exit 3; }

backend=""
band=""
stance=""
bands_file=""

# Arity-guarded parse: every option needs a value, so a dangling flag (e.g. a
# trailing `--band`) must fail loudly rather than `shift 2` past the end of the
# argument list and loop.
while [[ $# -gt 0 ]]; do
  case "$1" in
    --backend|--band|--stance|--bands-file)
      [[ $# -ge 2 ]] || die_usage "missing value for $1"
      case "$1" in
        --backend)    backend="$2" ;;
        --band)       band="$2" ;;
        --stance)     stance="$2" ;;
        --bands-file) bands_file="$2" ;;
      esac
      shift 2
      ;;
    *) die_usage "unknown argument: $1" ;;
  esac
done

[[ -n "$backend" ]] || die_usage "--backend is required"
[[ -n "$band" ]]    || die_usage "--band is required"

# Locate config/bands.json relative to this script's REAL path (it is symlinked
# onto PATH as ~/.local/bin/band-resolve, so $0/BASH_SOURCE points at the
# symlink). Resolve the symlink with python3 (portable; no GNU `readlink -f`).
if [[ -z "$bands_file" ]]; then
  real_self="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")"
  bands_file="$(cd "$(dirname "$real_self")/.." && pwd)/config/bands.json"
fi
[[ -f "$bands_file" ]] || die_usage "bands file not found: $bands_file"

[[ -n "$stance" ]] || stance="$(jq -r '.defaults.stance // "balanced"' "$bands_file" 2>/dev/null || echo balanced)"

# All resolution logic is one jq program so the policy is evaluated atomically
# and either the full object is printed or jq errors (mapped to exit 3). jq
# `error(...)` messages carry the reason.
result="$(
  jq -c -e \
    --arg backend "$backend" \
    --arg band "$band" \
    --arg stance "$stance" '
    .routes as $routes
    | ($routes.balanced // error("no balanced routes in bands file")) as $bal
    | ($bal[$backend] // error("unknown backend: \($backend)")) as $balbackend
    | ($balbackend[$band] // error("unknown band: \($band) for backend \($backend)")) as $balcell
    | ($routes[$stance] // error("unknown stance: \($stance)")) as $sroute
    | (($sroute[$backend] // {})[$band]) as $override
    | (if $override == null
         then { cell: $balcell, fell_back: true }
         else { cell: $override, fell_back: false } end) as $r
    | (if ($r.cell | type) != "object" or ($r.cell.model // "") == ""
         then error("malformed cell for \($stance)/\($backend)/\($band): no model")
         else . end)
    | { backend: $backend, band: $band, stance: $stance,
        model: $r.cell.model, fell_back: $r.fell_back }
      + (if ($r.cell.effort // null) != null then { effort: $r.cell.effort } else {} end)
  ' "$bands_file" 2>&1
)" || die_policy "${result#jq: error*: }"

# Report a fallback on stderr so it is visible but does not pollute stdout JSON.
if [[ "$(printf '%s' "$result" | jq -r '.fell_back')" == "true" ]]; then
  printf 'note: %s/%s/%s not defined; used balanced\n' "$stance" "$backend" "$band" >&2
fi

printf '%s\n' "$result"
