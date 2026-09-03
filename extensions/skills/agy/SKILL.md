---
name: agy
description: 'Delegate scoped coding work to the Antigravity CLI (agy) with safe isolation, resumable conversations, schema-enforced results, independent verification, and bounded review. Use when asked to delegate, offload, implement, test, refactor, investigate, or review through agy, Antigravity, or Gemini models, including parallel agy work that needs worktrees and file ownership.'
---

# Delegate to agy (Antigravity CLI)

Act as the orchestrator. Scope the task, preserve user work, dispatch `agy` in print mode, monitor
the result, verify it independently, and continue until the requested outcome is complete or
genuinely blocked.

This wraps the `agy` binary. It does not use the `gemini` CLI: on a personal (non-enterprise) Google
account that client is rejected server-side with `IneligibleTierError`/`UNSUPPORTED_CLIENT`. Never
substitute `gemini` for `agy` here.

## Default loop

1. Read applicable `AGENTS.md`/`AI.md`, the relevant code and tests, and the current plan.
2. Capture the baseline before dispatch: repository root, branch, `HEAD`, and `git status --short`.
3. Choose execution mode:
   - Read-only investigation or review: `--mode plan`.
   - Trivial isolated write with a clean, uncontested tree: current worktree is acceptable.
   - Non-trivial write, dirty tree, concurrent session, or multi-step task: use a dedicated worktree.
4. Define one bounded task with goal, non-goals, allowed files, constraints, acceptance criteria,
   verification commands, approval boundaries, and a stop condition.
5. Dispatch from the target directory and capture the JSON result. Record the emitted
   `conversation_id`.
6. Monitor completion, failure, permission auto-denial, timeout, and stalls. Treat `"status":
   "SUCCESS"` as unverified, not as success.
7. Inspect the actual diff and independently run the required verification.
8. If a concrete defect remains, resume with `--conversation <id>` carrying the finding and evidence.
   Allow one bounded repair/review loop, then resolve locally or ask the user if authority is missing.
9. Report outcome, model and effort used, files changed, verification, unresolved risks, and any user
   action required.

Read [references/execution.md](references/execution.md) before launching or resuming agy. Read
[references/review.md](references/review.md) before accepting any write task. Read
[references/parallelism.md](references/parallelism.md) before launching more than one agy session.

## Prompt contract

Use [templates/task-prompt.md](templates/task-prompt.md). Include only task-relevant context, but make
the prompt self-contained. Never refer to "our conversation" or "the plan above".

Require a final JSON object, and enforce it with `--json-schema` rather than trusting the prose:

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
- Prefer `--mode plan` for anything that does not need to write. `--dangerously-skip-permissions`
  requires explicit user authorization and an isolated worktree; pair it with `--sandbox`.
- Always pass `--disable-slash-commands` in print mode. A templated prompt containing `/text` would
  otherwise expand as a slash command or skill.
- Do not let agy commit unless the task explicitly requires a commit.
- Do not accept weakened tests, deleted coverage, narrowed inputs, skipped checks, or unrelated edits.
- Do not dump a large diff by default. Summarize it and provide the path or command to inspect it.

## Review modes

`agy` has no built-in review subcommand. Run review as a fresh read-only session scoped to an
explicit target:

```bash
git diff > /tmp/review.diff     # or --base <branch>, or a commit range
agy --print "$(cat review-prompt.md)" --mode plan --output-format json \
  --model <slug> --disable-slash-commands
```

For risky or substantial diffs, use a fresh `--mode plan` session for independent final review. Do
not require a second model pass for trivial mechanical changes.
