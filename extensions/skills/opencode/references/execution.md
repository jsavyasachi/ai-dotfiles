# Execution and monitoring

## Preflight

Run before dispatch:

```bash
command -v opencode
opencode --version
command -v curl
curl -sf http://localhost:11434/api/version
git rev-parse --show-toplevel
git rev-parse --git-dir
git rev-parse --git-common-dir
git rev-parse HEAD
git branch --show-current
git status --short
```

If `git rev-parse --git-dir` differs from `git rev-parse --git-common-dir`, you are already in a
worktree. Reuse it instead of nesting another one. For a non-trivial write from the primary
checkout, create `.worktrees/<task>` on a dedicated branch, install required dependencies, and run
the baseline tests before editing.

## Prompt and log storage

For a task that needs resume, monitoring, or audit, use the untracked directory:

```text
.opencode-runs/<run-id>/
  state.json
  prompts/<task>.md
  logs/<task>.jsonl
```

Store the baseline commit, branch, worktree, task name, prompt path, log path, session id, allowed
files, and status in `state.json`. Render the prompt with the agent's normal file-editing tool.
Launch from the intended worktree:

```bash
opencode run --format json < <prompt-file> > <log-file>
```

Use the configured local model by default. Pass `--model provider/model` only for an explicitly
authorized override.

## Session lifecycle

Parse the JSON event stream incrementally for the session id, completion, failure, errors, recent
activity, and approval waits. Preserve the session id and use:

```bash
opencode run --format json --continue "<specific follow-up>"
opencode run --format json --session <id> "<specific follow-up>"
opencode run --format json --session <id> --fork "<branching follow-up>"
```

Distinguish:

- Complete: terminal success event and successful process exit.
- Failed: terminal failure event, nonzero exit, malformed or empty terminal stream, or lost process.
- Waiting: narration or state indicates approval or input is required.
- Stalled: no activity past a task-appropriate threshold while the process remains active.
- Unknown: incomplete or low-confidence parser state. Inspect a bounded raw tail before deciding.

Never infer completion from silence or model narration.

## Repair and rollback

Send a targeted resume prompt containing the exact finding, evidence, expected correction, allowed
files, and verification command. Use one bounded repair loop. If it fails, diagnose locally or ask
the user rather than repeatedly spending local-model context.

Rollback only task-owned changes after inspecting the baseline and current diff. Never use repository-
wide destructive restoration. Preserve any needed artifacts and leave unrelated user changes intact.
