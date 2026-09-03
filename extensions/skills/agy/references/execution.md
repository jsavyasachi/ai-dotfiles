# Execution and monitoring

## Preflight

Run before dispatch:

```bash
command -v agy
git rev-parse --show-toplevel
git rev-parse HEAD
git branch --show-current
git status --short
```

Detect an existing worktree by comparing `git rev-parse --git-dir` with
`git rev-parse --git-common-dir`. Reuse it instead of nesting another worktree. For a non-trivial
write from the primary checkout, create `.worktrees/<task>` on a dedicated branch, install required
dependencies, and run the baseline tests before editing.

`agy` has no working-directory flag. The workspace root is the process working directory, so launch
the command from the intended worktree and use `--add-dir <path>` (repeatable) only to extend the
workspace beyond it.

## Model selection

Read the live catalog before choosing. Slugs change between releases, so never carry a remembered one
forward:

```bash
agy models
```

The catalog spans vendors, not just Gemini. Map the task shape to a tier, then resolve a current slug:

| Task shape | Tier | Effort |
|---|---|---|
| Mechanical write: rename, codemod, formatting, dependency bump | fastest flash-class model | `low` |
| Standard scoped implementation or test-writing | flash-class model | `medium` |
| Multi-step refactor, ambiguous investigation, independent review | pro- or opus-class model | `high` |

For Gemini slugs the effort tier is baked into the name (`gemini-3.1-pro-high` versus
`gemini-3.1-pro-low`). When the slug already carries a tier, do not also pass `--effort`; use
`--effort low|medium|high` only for models whose slug has no tier suffix. State the resolved slug and
effort when reporting the run.

## Prompt and log storage

For a task that needs resume, monitoring, or audit, use:

```text
.agy-runs/<run-id>/
  state.json
  prompts/<task>.md
  schema/result.schema.json
  logs/<task>.json
```

Keep runtime files untracked. Store the baseline commit, branch, worktree, task name, prompt path,
log path, conversation id, resolved model slug, effort, allowed files, and status in `state.json`.

Render the prompt to a file with the agent's normal file-editing tool. Do not interpolate arbitrary
prompt text into a shell command. Launch from the intended worktree:

```bash
cd <worktree> && agy --print "$(cat <prompt-file>)" \
  --mode plan \
  --model <slug> \
  --output-format json \
  --json-schema <schema-file> \
  --disable-slash-commands \
  --print-timeout 30m \
  > <log-file>
```

Use `--mode plan` for investigation and review. A write task needs `--mode accept-edits`, and any
tool outside the auto-approved set still requires either a `permissions.allow` rule in agy's
`settings.json` or explicitly authorized `--dangerously-skip-permissions`. Do not add permissive
approval or sandbox bypasses without explicit user authorization.

`--print-timeout` defaults to 5m. A longer task that exceeds it is cut off, so set it deliberately
from the expected task length rather than accepting the default.

## Result shape

Print mode with `--output-format json` emits one object:

```json
{"conversation_id":"<uuid>","status":"SUCCESS","response":"...","duration_seconds":2.26,
 "num_turns":1,"usage":{"input_tokens":0,"output_tokens":0,"total_tokens":0}}
```

`status` reports that the process finished, not that the work happened. Treat a run as failed, not
successful, when any of these hold:

- `response` is empty or whitespace.
- stderr carries the auto-denial notice: a tool required a permission that headless mode cannot
  prompt for, so it was auto-denied. The run still reports `"status": "SUCCESS"` with an empty
  response and no files changed.
- `num_turns` is 1 on a task that necessarily required tool use.
- The parsed `--json-schema` result is absent or fails validation.
- `git status --short` is unchanged on a task that was supposed to write.

Always capture stderr alongside stdout. The auto-denial notice appears only on stderr, and losing it
turns a silent no-op into an apparent success.

## Session lifecycle

Resume with the conversation id from the result object:

```bash
agy --print "<specific follow-up>" --conversation <conversation_id> \
  --output-format json --disable-slash-commands
```

Resume when context remains relevant and the previous turn is complete. Start a new session for
unrelated work, required isolation, corrupted or unknown state after bounded inspection, or an
explicit request for a fresh reviewer.

Do not use `-c`/`--continue`. It resumes whichever conversation was most recent, which is ambiguous
the moment more than one session exists. Always address a session by its id.

For incremental progress on a long task, use `--output-format stream-json`, which emits NDJSON as the
turn proceeds. `--input-format stream-json` reads one NDJSON message per line from stdin and requires
`--output-format stream-json`. Track the last byte offset and last activity time rather than
rereading the whole log. Never infer completion from silence.

## Repair and rollback

Send a targeted resume prompt containing the exact finding, evidence, expected correction, allowed
files, and verification command. Avoid broad repeated rereviews. After one unsuccessful bounded
repair loop, diagnose locally or request user input when product intent or authority is missing.

Rollback by deleting the isolated worktree/branch after preserving any needed artifacts, reverting a
task-specific commit, or restoring only files proven clean at baseline and owned by the task. Never
use repository-wide destructive restoration.
