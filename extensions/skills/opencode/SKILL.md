---
name: opencode
description: 'Delegate scoped coding work to OpenCode with a local model, safe isolation, JSON event streams, independent verification, and bounded repair. Use when asked to delegate, offload, implement, test, refactor, investigate, or review through OpenCode, including work that should run on the configured Ollama model.'
---

# Delegate to OpenCode

Act as the orchestrator. Scope the task, preserve user work, dispatch OpenCode from the intended
worktree, monitor the result, verify it independently, and continue until the requested outcome is
complete or genuinely blocked.

The configured default is `ollama/qwen2.5-coder:14b`, a 14B local model. It is materially weaker
than cloud coding models, so use smaller task scope, mandatory diff verification, and one bounded
repair loop. Read [references/execution.md](references/execution.md) before launching or resuming
OpenCode.

## Default loop

1. Read applicable `AGENTS.md`/`AI.md`, the relevant code and tests, and the current plan.
2. Capture the baseline before dispatch: repository root, branch, `HEAD`, and `git status --short`.
3. Choose execution mode:
   - Read-only investigation or review: current worktree with a read-only prompt contract.
   - Trivial isolated write with a clean, uncontested tree: current worktree is acceptable.
   - Non-trivial write, dirty tree, concurrent session, or multi-step task: use a dedicated worktree.
4. Define one bounded task with goal, non-goals, allowed files, constraints, acceptance criteria,
   verification commands, approval boundaries, and a stop condition. Prefer one file or one
   function-level change per dispatch.
5. Confirm Ollama is available with `curl -sf http://localhost:11434/api/version`. If it is down,
   surface that and fall back only as the user instructed.
6. Save the prompt, launch `opencode run` from the target worktree, and capture its `--format json`
   event stream.
7. Monitor completion, failure, approval waits, and stalls. Treat silence as unknown, not success.
8. Inspect the full actual diff and independently run the required verification. Never accept the
   model's self-report without checking the worktree.
9. If a concrete defect remains, resume with `--continue` or `--session <id>` and the finding and
   evidence. Allow one bounded repair loop, then resolve locally or ask the user.
10. Summarize diffs instead of dumping them and report outcome, files changed, verification,
    unresolved risks, and any user action required.

## OpenCode mechanics

- Non-interactive launch: `opencode run "<prompt>"` or `opencode run < prompt-file`.
- Machine-readable events: add `--format json`.
- Resume the last session with `--continue` or `-c`; resume a specific session with
  `--session <id>` or `-s`; use `--fork` to branch a session.
- Override the model with `--model provider/model` or `-m`, for example
  `-m anthropic/claude-sonnet-5`, only when the user authorizes cloud escalation.
- OpenCode has no sandbox flags. Rely on the prompt contract, worktree isolation, and full diff
  review instead.

## Prompt contract

Use [templates/task-prompt.md](templates/task-prompt.md). Include only task-relevant context, but
make the prompt self-contained. Never refer to "our conversation" or "the plan above".

Require OpenCode to return a final JSON object containing:

```json
{
  "summary": "string",
  "files_changed": ["string"],
  "tests_run": [{"command": "string", "exit_code": 0, "result": "string"}],
  "unresolved_blockers": ["string"]
}
```

Treat this object as a claim. Compare it with the full diff, JSON logs, and independently rerun
commands.

## Safety rules

- Preserve all pre-existing changes. Never use `git checkout -- .`, `git reset --hard`, or broad
  cleanup as rollback. Restore only proven task-owned files.
- Do not delegate credentials, deployments, publishing, pushes, external messages, destructive git,
  network access, Docker socket access, or out-of-workspace writes unless explicitly authorized.
- Do not let OpenCode commit unless the task explicitly requires a commit.
- Do not accept weakened tests, deleted coverage, narrowed inputs, skipped checks, or unrelated edits.
- Do not loop indefinitely: one bounded repair loop is the default for the local model.
