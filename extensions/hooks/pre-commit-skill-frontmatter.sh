#!/usr/bin/env bash
# pre-commit-skill-frontmatter.sh: git pre-commit gate (cross-agent).
#
# Installed into .git/hooks/pre-commit by setup.sh. Fires on `git commit` no
# matter which agent staged the change (Claude, Codex, OpenCode, Gemini,
# Cursor) - they all commit through git - so it is the one choke point that
# guards every tool at once.
#
# Blocks the commit if any staged SKILL.md or extensions/commands/*.md has
# broken YAML frontmatter (the ': ' / ' #' footguns). Validation logic lives
# in validate-skill-frontmatter.sh (single source of truth).
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
validator="$repo_root/extensions/hooks/validate-skill-frontmatter.sh"

[[ -x "$validator" ]] || exit 0  # validator absent -> nothing to enforce

# Staged, still-present files matching our gated patterns.
mapfile -t staged < <(
  git diff --cached --name-only --diff-filter=ACM \
    | grep -E '(^|/)SKILL\.md$|^extensions/commands/.*\.md$' || true
)

[[ ${#staged[@]} -gt 0 ]] || exit 0

abs=()
for f in "${staged[@]}"; do
  [[ -f "$repo_root/$f" ]] && abs+=("$repo_root/$f")
done
[[ ${#abs[@]} -gt 0 ]] || exit 0

if ! "$validator" "${abs[@]}"; then
  echo "" >&2
  echo "  Commit blocked: invalid SKILL.md / command frontmatter (see above)." >&2
  echo "  Single-quote the offending description, then re-stage and commit." >&2
  echo "  Override (not recommended): git commit --no-verify" >&2
  exit 1
fi
