---
description: Push the current branch to origin after a docs/instructions audit
---

Push the current branch as-is after a checkpoint audit.

Steps:
1. Check the working tree with `git status --short`.
2. If the tree is dirty, run the `/checkpoint` flow first. If the dirty work cannot be safely committed, stop and report what blocks it.
3. Run the docs/instructions audit from `AI.md` `## Repo Changes`: update `README.md` when setup, behavior, commands, stack, layout, or user-facing capabilities changed; update `AI.md` when workflows, paths, conventions, or capabilities changed; verify symlinked agent docs still point at the right source.
4. Run relevant tests/typecheck for the checkpoint. If they fail, surface the failure and ask before pushing.
5. Verify upstream tracking. If the branch has no upstream, run `git push -u origin HEAD`; otherwise run `git push`.
6. Report the pushed commit count and destination as `<remote>/<branch>`.

Non-goals:
- Do not create PRs.
- Do not switch branches.
- Do not force-push.
- Do not refuse `main` pushes solely because the branch is `main`.
