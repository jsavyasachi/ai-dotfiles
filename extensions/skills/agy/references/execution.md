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

`agy` has no working-directory flag, and launching it from a directory does NOT confine it there.
Observed: a run launched with the working directory set to `.worktrees/<task>` wrote its entire diff
into the main checkout instead, while reporting the relative paths from the prompt as though they
were the worktree's. agy resolves its own project root; the process working directory is at most a
hint.

Treat worktree isolation as unverified for every agy run:

- Record `git status --short` for the main checkout AND every worktree before dispatch, not just the
  target.
- After the run, check all of them. A clean target worktree plus a claimed diff means the write
  landed somewhere else; find it before doing anything else.
- Never dispatch agy while the main checkout holds uncommitted work you cannot afford to have
  touched. Commit or branch it first.

`--add-dir <path>` extends the workspace; it does not restrict it.

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

Tier on what remains uncertain, not on the size of the original task. A repair prompt that already
carries the finding, the required correction, and a reference implementation is mechanical work
however large the underlying feature was: send it to the cheap tier.

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
  --print-timeout 30m \
  > <log-file> 2> <err-file>
```

Use `--mode plan` for investigation and review, `--mode accept-edits` for a write task.

Never pass `--disable-slash-commands` together with `--mode`. The flag silently voids the mode:
agy warns `--mode plan has no effect while slash command expansion is disabled` on stderr and then
runs without the mode's restriction. Read-only enforcement and that flag are mutually exclusive, so
prefer the mode and neutralise slash-like text in the prompt instead.

Redirect stderr to its own file on every dispatch. Permission denials and the mode warning appear
only there.

`--print-timeout` defaults to 5m. A longer task that exceeds it is cut off, so set it deliberately
from the expected task length rather than accepting the default.

## Permissions are mandatory, and independent of mode

Headless agy cannot prompt, so any tool needing permission is auto-denied and the run ends having
done nothing. `--mode` does not grant anything: `accept-edits` covers edit tools only, and a plain
investigation still needs shell commands. Without a grant, even a read-only task returns an empty
response.

Grants live in `permissions.allow` in `~/.gemini/antigravity-cli/settings.json`. A rule targets the
literal command agy invokes, not the shell it might have used:

```json
{"permissions": {"allow": [
  "command(grep)",
  "command(git)",
  "command(bash -n setup.sh)"
]}}
```

`command(bash)` does NOT cover `command(wc)`: agy invokes commands directly, so a rule naming the
shell matches nothing. Full invocations are valid targets, so prefer the narrowest form that covers
the task. `command(*)` allows every command and is a blanket grant: treat it as equivalent to
`--dangerously-skip-permissions` for shell access and require explicit user authorization plus an
isolated worktree.

Enumerated grants work only when you know the command set in advance. For open-ended delegation you
do not: agy chooses its own commands, and its logs record the denial without recording the command
it wanted, so there is nothing to enumerate from. A run denied this way costs a full model call and
produces nothing.

So there are two honest modes of operation:

- **Known command set** (a specific verification, a scripted check): enumerate literal targets. This
  is the preferred form and needs no special authorization.
- **Open-ended delegation** (implement, refactor, investigate): requires `command(*)`. Get explicit
  user authorization, dispatch into a disposable worktree, and treat the worktree as the containment
  boundary, because the grant is not one.

Never leave `command(*)` installed after the run. Restore the previous `permissions.allow` when the
task completes.

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
  response and no files changed. This is the most common failure; check it first.
- `num_turns` is 1 on a task that necessarily required tool use.
- The parsed `--json-schema` result is absent or fails validation.
- `git status --short` is unchanged on a task that was supposed to write.

Always capture stderr alongside stdout. The auto-denial notice appears only on stderr, and losing it
turns a silent no-op into an apparent success.

## Session lifecycle

Resume with the conversation id from the result object:

```bash
agy --print "<specific follow-up>" --conversation <conversation_id> \
  --mode <mode> --output-format json > <log-file> 2> <err-file>
```

Pass `--mode` explicitly on a resume rather than assuming the original session's
mode carries over; that inheritance has not been verified.

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
