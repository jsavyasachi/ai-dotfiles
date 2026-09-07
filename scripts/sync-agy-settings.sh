#!/usr/bin/env bash
#
# Scoped deep-merge of the repo's managed subset of agy settings
# (permissions.allow, enableTelemetry) into agy's live settings.json, without
# touching keys agy owns and rewrites at runtime (model, trustedWorkspaces,
# anything else). `template * dest`-style keys in the template fully replace
# the same key in dest; every key the template does not define passes through
# untouched. A missing or malformed dest is treated as {} - never a crash,
# never a half-written file.
#
# Usage: sync-agy-settings.sh <template.json> <dest.json>

set -euo pipefail

die() { printf 'sync-agy-settings: %s\n' "$1" >&2; exit "${2:-1}"; }

[[ $# -eq 2 ]] || die "usage: sync-agy-settings.sh <template.json> <dest.json>" 2

TEMPLATE="$1"
DEST="$2"

[[ -f "$TEMPLATE" ]] || die "template not found: $TEMPLATE" 2
jq -e . "$TEMPLATE" >/dev/null 2>&1 || die "template is not valid JSON: $TEMPLATE" 2

dest_json='{}'
if [[ -f "$DEST" ]]; then
  if jq -e . "$DEST" >/dev/null 2>&1; then
    dest_json="$(cat "$DEST")"
  else
    printf 'sync-agy-settings: %s is not valid JSON; treating as empty\n' "$DEST" >&2
  fi
fi

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

printf '%s' "$dest_json" | jq -s '.[0] * .[1]' - "$TEMPLATE" > "$tmp"

mkdir -p "$(dirname "$DEST")"
mv "$tmp" "$DEST"
trap - EXIT
