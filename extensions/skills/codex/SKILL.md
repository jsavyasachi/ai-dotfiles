---
name: codex
description: 'Delegate scoped coding work to Codex with safe isolation, resumable JSONL sessions, independent verification, and bounded review. Use when asked to delegate, offload, implement, test, refactor, investigate, or review through Codex, including parallel Codex work that needs worktrees and file ownership.'
---

# Delegate to Codex

Act as the orchestrator. Scope the task, preserve user work, dispatch Codex in its native harness,
monitor the result, verify it independently, and continue until the requested outcome is complete or
genuinely blocked.

## Default loop

1. Read applicable `AGENTS.md`/`AI.md`, the relevant code and tests, and the current plan.
2. Capture the baseline before dispatch: repository root, branch, `HEAD`, and `git status --short`.
3. Choose execution mode:
   - Read-only investigation or review: current worktree with `-s read-only`.
   - Trivial isolated write with a clean, uncontested tree: current worktree is acceptable.
   - Non-trivial write, dirty tree, concurrent session, or multi-step task: use a dedicated worktree.
4. Define one bounded task with goal, non-goals, allowed files, constraints, acceptance criteria,
   verification commands, approval boundaries, and a stop condition.
5. Save the prompt and capture `codex exec --json` output. Record the emitted thread id.
6. Monitor completion, failure, approval waits, and stalls. Treat silence as unknown, not success.
7. Inspect the actual diff and independently run the required verification.
8. If a concrete defect remains, use `codex exec resume <thread-id>` with the finding and evidence.
   Allow one bounded repair/review loop, then resolve locally or ask the user if authority is missing.
9. Report outcome, files changed, verification, unresolved risks, and any user action required.

Read [references/execution.md](references/execution.md) before launching or resuming Codex. Read
[references/review.md](references/review.md) before accepting any write task. Read
[references/parallelism.md](references/parallelism.md) before launching more than one Codex session.

## Prompt contract

Use [templates/task-prompt.md](templates/task-prompt.md). Include only task-relevant context, but make
the prompt self-contained. Never refer to "our conversation" or "the plan above".

Require Codex to return a final JSON object containing:

```json
{
  "summary": "string",
  "files_changed": ["string"],
  "tests_run": [{"command": "string", "exit_code": 0, "result": "string"}],
  "unresolved_blockers": ["string"]
}
```

Treat this object as a claim. Compare it with the diff, logs, and independently rerun commands.

## Safety rules

- Preserve all pre-existing changes. Never use `git checkout -- .`, `git reset --hard`, or broad
  cleanup as rollback. Remove an isolated worktree or restore only proven task-owned files.
- Do not delegate credentials, deployments, publishing, pushes, external messages, destructive git,
  network access, Docker socket access, or out-of-workspace writes unless explicitly authorized.
- Keep Codex in `read-only` or `workspace-write`. Broad host access requires explicit authorization
  and a hardened environment.
- Do not let Codex commit unless the task explicitly requires a commit.
- Do not accept weakened tests, deleted coverage, narrowed inputs, skipped checks, or unrelated edits.
- Do not dump a large diff by default. Summarize it and provide the path or command to inspect it.

## Review modes

Use an explicit target:

```bash
codex exec review --uncommitted
codex exec review --base <branch>
codex exec review --commit <sha>
```

For risky or substantial diffs, use a fresh read-only Codex session for independent final review.
Do not require a second model pass for trivial mechanical changes.
