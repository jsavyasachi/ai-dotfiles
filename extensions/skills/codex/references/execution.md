# Execution and monitoring

## Preflight

Run before dispatch:

```bash
command -v codex
codex --version
git rev-parse --show-toplevel
git rev-parse HEAD
git branch --show-current
git status --short
```

Detect an existing worktree by comparing `git rev-parse --git-dir` with
`git rev-parse --git-common-dir`. Reuse it instead of nesting another worktree. For a non-trivial
write from the primary checkout, create `.worktrees/<task>` on a dedicated branch, install required
dependencies, and run the baseline tests before editing.

## Model selection

Never rely on the ambient default. `~/.codex/config.toml` is unmanaged and resolves `model` from the
session's working directory, so a `[projects."<path>"]` block, or its absence in a scratch worktree,
silently changes which model runs the task. Select explicitly on every dispatch.

Read the live catalog first. Slugs and effort tiers change between CLI releases, so never carry a
remembered slug forward:

```bash
codex debug models | jq -r '.models[]
  | select(.visibility=="list")
  | "\(.slug)\t\(.default_reasoning_level)\t\([.supported_reasoning_levels[].effort]|join(","))"'
```

Skip any model with `"visibility": "hide"`. Those are internal, such as the approvals reviewer.
Take effort values from the catalog rather than the published config reference, which lags the CLI
and omits tiers the newest models accept.

Map the task shape to a tier, then resolve the tier to a current slug:

| Task shape | Tier | Effort |
|---|---|---|
| Mechanical write: rename, codemod, formatting, dependency bump | cheapest listed coding model | `low` |
| Standard scoped implementation or test-writing | balanced agentic coding model | `medium` |
| Multi-step refactor, ambiguous investigation, independent review | strongest agentic model | `high` or above |

Both `codex exec` and `codex exec review` accept `-m/--model`. Effort has no flag, so set it with
`-c model_reasoning_effort=<effort>`. State the resolved slug and effort when reporting the run.

## Prompt and log storage

For a task that needs resume, monitoring, or audit, use:

```text
.codex-runs/<run-id>/
  state.json
  prompts/<task>.md
  logs/<task>.jsonl
```

Keep runtime files untracked. Store the baseline commit, branch, worktree, task name, prompt path,
log path, thread id, resolved model slug, reasoning effort, allowed files, and status in
`state.json`.

Render the prompt to a file with the agent's normal file-editing tool. Do not interpolate arbitrary
prompt text into a shell command. Launch from the intended worktree:

```bash
codex exec --json -s workspace-write -C <worktree> \
  -m <slug> -c model_reasoning_effort=<effort> < <prompt-file> > <log-file>
```

Use `-s read-only` for investigation and review. Do not add permissive approval or sandbox bypasses
without explicit user authorization.

## Session lifecycle

Parse JSONL for the thread id, turn completion, turn failure, errors, and recent activity. Preserve
the thread id and use:

```bash
codex exec resume <thread-id> "<specific follow-up>"
```

Resume when context remains relevant and the previous turn is idle or complete. Start a new session
for unrelated work, required isolation, corrupted/unknown state after bounded inspection, or an
explicit request for a fresh reviewer.

Monitor incrementally rather than repeatedly reading the full log. Track the last byte offset and
last activity time. Distinguish:

- Complete: terminal success event and successful process exit.
- Failed: terminal failure event, nonzero exit, malformed/empty terminal stream, or lost process.
- Waiting: narration or state indicates approval/input is required.
- Stalled: no activity past a task-appropriate threshold while the turn remains active.
- Unknown: incomplete or low-confidence parser state. Inspect a bounded raw tail before deciding.

Report progress during long runs. Never infer completion from silence.

## Repair and rollback

Send a targeted resume prompt containing the exact finding, evidence, expected correction, allowed
files, and verification command. Avoid broad repeated rereviews. After one unsuccessful bounded
repair loop, diagnose locally or request user input when product intent or authority is missing.

Rollback by deleting the isolated worktree/branch after preserving any needed artifacts, reverting a
task-specific commit, or restoring only files proven clean at baseline and owned by the task. Never
use repository-wide destructive restoration.
