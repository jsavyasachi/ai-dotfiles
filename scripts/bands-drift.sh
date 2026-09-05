#!/usr/bin/env bash
#
# bands-drift.sh - report how config/bands.json has drifted from the live
# catalogs. Read-only: it never rewrites the map (the human-gated refresh WRITE
# is deferred v2 work - see instructions/AI.md). It is the churn-detection
# surface, and it keeps the review's distinctions honest:
#   * ABSENT (referenced slug gone from the catalog) is reported separately from
#     RETIRING (a catalog model with a scheduled future retirement + successor).
#   * A catalog model no band references is UNASSIGNED and flagged as "maybe
#     new" - never silently assigned a band (name-based band inference is not
#     reliable), and the note says it may just be intentionally unused.
#   * Discovery failure is UNAVAILABLE (unknown), not fatal and not "retired".
# Static Claude aliases are not catalog discovery, so claude is out of scope.
#
# Usage: bands-drift.sh [--bands-file <path>] [--timeout <seconds>]
# Catalog binaries are injectable: $CODEX_BIN (via codex-models.py) and $AGY_BIN.

set -euo pipefail

bands_file=""
timeout=20

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bands-file) [[ $# -ge 2 ]] || { echo "missing value for $1" >&2; exit 2; }; bands_file="$2"; shift 2 ;;
    --timeout)    [[ $# -ge 2 ]] || { echo "missing value for $1" >&2; exit 2; }; timeout="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

here="$(cd "$(dirname "$(python3 -c 'import os,sys;print(os.path.realpath(sys.argv[1]))' "${BASH_SOURCE[0]}")")" && pwd)"
[[ -n "$bands_file" ]] || bands_file="$(cd "$here/.." && pwd)/config/bands.json"
[[ -f "$bands_file" ]] || { echo "bands file not found: $bands_file" >&2; exit 2; }

referenced() { jq -r --arg b "$1" '[.routes[][$b]? // {} | .[].model] | unique[]' "$bands_file" 2>/dev/null; }

echo "== CODEX =="
if catalog="$(python3 "$here/codex-models.py" --include-hidden --timeout "$timeout" 2>/dev/null)"; then
  ids="$(printf '%s' "$catalog" | jq -r '.models[].id')"
  # RETIRING: catalog models carrying a scheduled retirement + successor.
  printf '%s' "$catalog" | jq -r '
    .models[] | select(.upgradeInfo != null and .upgradeInfo.retirementAt != null)
    | "CODEX RETIRING \(.id) at \(.upgradeInfo.retirementAt) -> \(.upgradeInfo.successor // "?")"'
  # ABSENT: a slug a band references that the live catalog no longer lists.
  while IFS= read -r slug; do
    [[ -n "$slug" ]] || continue
    grep -qxF "$slug" <<<"$ids" || echo "CODEX ABSENT $slug (referenced by a band, gone from catalog)"
  done < <(referenced codex)
  # UNASSIGNED: a catalog model no band references (maybe new, maybe intentional).
  while IFS= read -r id; do
    [[ -n "$id" ]] || continue
    grep -qxF "$id" <<<"$(referenced codex)" || echo "CODEX UNASSIGNED $id (in catalog, no band - maybe new)"
  done <<<"$ids"
else
  echo "CODEX UNAVAILABLE (discovery failed; catalog unknown, not treated as retired)"
fi

echo "== AGY =="
if agy_out="$("${AGY_BIN:-agy}" models 2>/dev/null)"; then
  ids="$(printf '%s\n' "$agy_out" | awk -F'\t' 'NF{print $1}')"
  while IFS= read -r slug; do
    [[ -n "$slug" ]] || continue
    grep -qxF "$slug" <<<"$ids" || echo "AGY ABSENT $slug (referenced by a band, gone from catalog)"
  done < <(referenced agy)
  while IFS= read -r id; do
    [[ -n "$id" ]] || continue
    grep -qxF "$id" <<<"$(referenced agy)" || echo "AGY UNASSIGNED $id (in catalog, no band - maybe new)"
  done <<<"$ids"
else
  echo "AGY UNAVAILABLE (discovery failed; catalog unknown, not treated as retired)"
fi
