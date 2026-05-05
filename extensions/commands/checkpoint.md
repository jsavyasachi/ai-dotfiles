---
description: Commit the current logical unit of work using Conventional Commits
---

Commit the current logical unit of work.

Steps:
1. Run `git status --short`, inspect staged changes with `git diff --staged`, and inspect unstaged changes with `git diff`.
2. If the tree is clean, report `Nothing to commit.` and stop.
3. Identify the logical unit represented by the changes. If the tree contains unrelated logical units or multiple dominant Conventional Commit types, split them into separate commits.
4. Stage only the relevant files explicitly. Do not use blanket `git add -A` unless the whole tree is one logical unit.
5. Run the relevant local checks when they are present and reasonably scoped. Do not bypass hooks.
6. Commit with the Conventional Commits format from `AI.md` (`type(scope): subject`, optional body explaining why).
7. Report each commit as `<sha> <subject>`.

Safety:
- Do not amend pushed commits without explicit user approval.
- Do not use `--no-verify` without explicit user approval.
- Do not revert unrelated user changes.
