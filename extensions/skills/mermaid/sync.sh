#!/usr/bin/env bash
# Sync mermaid syntax/config docs from upstream mermaid-js/mermaid into ./references/.
# Run when you want fresh refs. Requires git + network.

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REFS_DIR="$SKILL_DIR/references"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

git clone --depth 1 --filter=blob:none --sparse \
  https://github.com/mermaid-js/mermaid.git "$TMP/mermaid" >/dev/null 2>&1
git -C "$TMP/mermaid" sparse-checkout set docs/syntax docs/config >/dev/null

mkdir -p "$REFS_DIR"
rm -f "$REFS_DIR"/*.md

find "$TMP/mermaid/docs/syntax" -maxdepth 1 -name '*.md' -exec cp {} "$REFS_DIR/" \;

for f in configuration.md directives.md layouts.md math.md theming.md tidy-tree.md; do
  src="$TMP/mermaid/docs/config/$f"
  [[ -f "$src" ]] && cp "$src" "$REFS_DIR/config-$f"
done

count="$(find "$REFS_DIR" -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')"
echo "synced $count reference files into $REFS_DIR"
