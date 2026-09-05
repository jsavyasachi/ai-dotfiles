# Universal AI Instructions

Tone, conciseness, and vocabulary rules live in `instructions/OUTPUT-STYLE.md`,
not here - see `Cross-agent config` > `Output style` below for why and how
each agent loads it.

## Questions

Ask one question at a time. Never bundle multiple questions in a single message.

When the answer space is discrete/enumerable, use the agent's structured question tool instead of plain text:
- Claude Code: `AskUserQuestion`
- Antigravity CLI (`agy`): no confirmed structured tool - ask in plain text with 2-4 numbered options
- OpenCode: `question` tool
- Codex: `request_user_input` - Plan Mode only; falls back to plain text with enumerated options elsewhere
- Cursor: no confirmed structured tool - ask in plain text with 2-4 enumerated options

Open-ended questions (no enumerable options) stay plain text on every agent.

## Response format

End every response with a confidence score:

**Confidence: XX%** | sources: [required when referencing code or docs: `file:line` or URLs; omit for general knowledge]

## Commits

Follow Conventional Commits for every commit message, no exceptions.

Format: `type(scope): subject` (scope optional). Subject in imperative mood, lowercase, no trailing period, ≤72 chars.

Types:
- `feat`: user-visible new functionality
- `fix`: bug fix
- `docs`: documentation only
- `refactor`: code change that neither fixes a bug nor adds a feature
- `perf`: performance improvement
- `test`: adding/updating tests
- `chore`: maintenance, deps, tooling, untracking files, rename-only changes
- `build`: build system / package config
- `ci`: CI config
- `style`: formatting only (whitespace, semicolons)
- `revert`: reverts a prior commit

Body (optional, after a blank line): wrap at 72, explain *why* not *what*. Use bullets for multiple points. Reference issue IDs at the end (`Closes #123`).

Breaking changes: append `!` after type/scope (`feat(api)!: drop /v1`) AND include a `BREAKING CHANGE:` footer explaining the migration.

Don't mix unrelated changes in one commit - split. If a single logical change touches multiple types, pick the dominant one (usually `feat` or `fix`).

## Commit cadence

Commit at every logical stage. A logical stage is one discrete task on the agent's todo list reaching `completed` (TodoWrite for Claude, equivalent task tracker elsewhere). One completed task means one Conventional Commit.

Do not accumulate uncommitted work across tasks. If task N+1 starts while task N's changes are still unstaged or uncommitted, commit task N first.

Push at natural boundaries and when done:
- The user signals end-of-session, done, or asks to push.
- A coherent feature is complete and tests pass.
- `/push` is invoked.

Before pushing, run the docs/instructions audit in `## Repo Changes`. If tests or typecheck fail before pushing, surface the failure and ask before pushing.

Never use `--no-verify`, force-push to `main`, or amend pushed commits without explicit user approval.

## Testing

Test-driven development applies to all code - new features, bug fixes, refactors, ports, rewrites. No exceptions for "this is just a small change."

For each unit of behavior:

1. Write the test first - it should fail (compile error, assertion failure, or runtime error).
2. Implement the minimum code to make it pass.
3. Refactor if needed, with the test as the safety net.

Bug fixes: write a regression test that reproduces the bug *before* fixing it. The test must fail on the buggy code and pass on the fix.

Refactors: the existing test suite is the spec. If coverage is thin in the area being refactored, add tests first, then refactor. Never refactor without test coverage.

Ports/rewrites: port the test suite first, port implementation to pass it. The test suite is the spec.

Work module-by-module, not all-tests-then-all-impl. Red/green cycles stay short, you catch design problems before they compound, and tests stay honest (written against intended behavior, not retrofitted to existing code).

Skip TDD only for: pure mechanical edits (renames, formatting, dependency bumps), throwaway exploration spikes, and code that is inherently hard to test in isolation (UI animation, interactive prompts, shell glue). When skipping, prefer adding a test after rather than no test at all.

## READMEs

Every project README must include a `## Stack` section. Preserve the established
header convention for the repository. For Clojure projects, use this order:

1. H1.
2. Existing Clojars, cljdoc, and CI status badges.
3. Tagline or short introductory copy.
4. `## Stack`.

For new repositories without status badges, put `## Stack` directly after the
H1 + tagline. Format stack badges as shields.io badges, anchor-wrapped, one per
technology, on contiguous lines (no blank lines between: they render as a
single row).

```markdown
## Stack

<a href="https://astro.build"><img src="https://img.shields.io/badge/Astro-FF5D01?style=flat&logo=astro&logoColor=white" alt="Astro" /></a>
<a href="https://react.dev"><img src="https://img.shields.io/badge/React-61DAFB?style=flat&logo=react&logoColor=000" alt="React" /></a>
```

Rules:
- One badge per primary tech: framework, language, runtime, key libraries, deploy target, test runner, DB. Skip transitive deps.
- Color is the brand hex (Astro `#FF5D01`, React `#61DAFB`, Tailwind `#06B6D4`, TypeScript `#3178C6`, Vercel `#000000`, etc.). Use `logoColor=000` on light brand backgrounds. For Clojure repositories, use the established `logoColor=fff` convention on dark backgrounds; otherwise use `logoColor=white`.
- `style=flat`, always lowercase the `?style` query.
- Each badge wrapped in `<a href="…">` to the canonical homepage.
- Order: foundation framework first, then language, then libraries, then infra/deploy last.
- Do not use the older `![](shields.io)` form - anchor-wrapped `<img>` lets the badges link out.

## Repo Changes

Any meaningful repo change must include a docs/instructions audit before push.

Minimum check:
- Update `README.md` if setup, behavior, commands, stack, layout, or user-facing capabilities changed.
- Update `AI.md` when project-specific AI instructions, workflows, paths, conventions, or available capabilities changed.
- Keep agent-doc parity: if the repo uses symlinked agent docs (`CLAUDE.md`, `OPENCODE.md`, `GEMINI.md`, `AGENTS.md`), make sure they still point at the right source and that the source text is current.
- Do this before every push, not as optional cleanup later.

## Tools available

- **1Password CLI (`op`)**: installed, authed via desktop app integration (Touch ID). Use `op item get "<name>" --fields <field> --reveal` to fetch secrets. Prefer `--fields` over full-item dumps to keep responses small.
- **Google Workspace CLI (`gws`)**: installed globally. Canonical tool for interacting with Gmail, Calendar, Drive, etc. Use `gws <service> <resource> <method> --params '...'` (e.g., `gws gmail users messages list --params '{"userId": "me"}'`). Outputs structured JSON. Use `gws schema <service.resource.method>` to introspect required parameters.
- **Hugging Face CLI (`hf`)**: installed, authed (`hf auth login`). Canonical tool for Hub repos, Spaces, and Jobs (on-demand GPU compute billed per-minute). Use `hf jobs run --flavor <tier> --expose <port> ...` for ad-hoc GPU workloads; `hf jobs hardware` lists tiers/pricing. `setup.sh` keeps its `hf-cli` agent skill current on every run - see "Cross-agent config" below.

## Decisions

The durable decision log lives in `instructions/DECISIONS.md`. Read it when you need the
rationale behind a convention - it is history rather than active guidance, so it is not
loaded into every session.

## Cross-agent config

This repo powers Claude Code, OpenCode, Antigravity CLI (`agy`), Codex, and Cursor. When updating settings, update analogues too:

| Capability | Claude Code | OpenCode | Antigravity CLI (`agy`) | Codex | Cursor |
|---|---|---|---|---|---|
| Settings | `settings.json` | `opencode.json` | not managed - agy owns `~/.gemini/antigravity-cli/settings.json` | `config.toml` | Cursor Settings UI (no file) |
| Instructions | `CLAUDE.md` | `OPENCODE.md` | `GEMINI.md` or `AGENTS.md` (per-repo) | `AGENTS.md` | `AGENTS.md` (per-repo); User Rules via Settings (global) |
| Slash commands | `commands/` (.md) | `commands/` (.md) | - (use skills) | - (use skills) | `.cursor/commands/` (.md, per-repo) |
| Skills | `skills/` | `skills/` | `~/.gemini/config/skills/` | `~/.codex/skills/` | - |
| Hooks | `settings.json` | `hooks.yaml` (plugin) | `~/.gemini/config/hooks.json` | `config.toml` `[hooks]` (unmanaged - own it directly) | `.cursor/hooks/` (per-repo, beta) |
| Subagents | `agents/` (.md) | `agents/` (.md, different schema - not wired) | `--agent` (no documented definition path) | - (no subagent primitive) | - |

Cursor reads `AGENTS.md` from the project root, so the same per-repo `AGENTS.md` symlink that Codex consumes also covers Cursor. Cursor's global "User Rules" live in the Cursor Settings UI, not a file we can symlink: paste `instructions/AI.md` into Settings > Rules once per machine.

### Output style

`instructions/OUTPUT-STYLE.md` (Tone, Conciseness, ASD-STE100) is a separate
canonical file from `AI.md`. It is wired into each supported agent's native
"system prompt" or "additional instructions" slot instead of its plain
instructions file, so it applies as strongly as each agent allows rather than
competing with ordinary CLAUDE.md/AGENTS.md text for the model's attention:

- **Claude Code**: `setup.sh` generates `~/.claude/output-styles/ai-dotfiles.md` (frontmatter + the file's body, `keep-coding-instructions: true`) from it every run. `config/settings.json.tpl` sets `"outputStyle": "ai-dotfiles"` as the default. Native output styles apply to the main conversation and forks only - subagents run their own system prompt and do not inherit it.
- **OpenCode**: `config/opencode.json.tpl`'s `instructions` array lists `OUTPUT-STYLE.md` alongside `OPENCODE.md` - OpenCode concatenates every listed file.
- **Antigravity CLI (`agy`)**: no automated global output-style path. It discovers project `GEMINI.md` and `AGENTS.md` files while walking to the repository root; the AI Nativity symlinks provide those project rules.
- **Codex**: no automated path. Codex reads one `AGENTS.md` with no multi-file or import syntax, and `~/.codex/config.toml` is intentionally unmanaged (see `Decisions`), so a managed `developer_instructions` key can't be templated in safely. To opt in manually, add `developer_instructions = "instructions/OUTPUT-STYLE.md"` (absolute path) to your own `~/.codex/config.toml`.
- **Cursor**: no automated path. Paste `instructions/OUTPUT-STYLE.md` into Settings > Rules alongside `AI.md`, same manual, once-per-machine step as the rest of Cursor's global rules.

Cross-agent slash commands (`/commit`, `/push`, `/configure-agents`) live as canonical Markdown in `extensions/commands/`. `setup.sh` symlinks them to Claude/OpenCode and transforms them into skills (`name`+`description` frontmatter) for OpenCode and Codex. `agy` has no TOML slash-command format, so commands are not translated for it; reusable agy commands must be authored as skills. Cursor's `.cursor/commands/` is per-project, not global, so commands are not propagated to Cursor today.

Cross-agent skills (third-party or local) live in `extensions/skills/<name>/`. The directory is ignored by default so third-party installs (`npx skills add`, which land here via Claude's `~/.claude/skills` symlink) stay untracked; every first-party skill authored in this repo is explicitly un-ignored by name in `.gitignore`, so adding one means adding its `!extensions/skills/<name>/` line too. `setup.sh` distributes them: symlink the whole dir to Claude (`~/.claude/skills/`), then create per-skill symlinks for OpenCode (`~/.config/opencode/skills/`), Codex (`~/.codex/skills/`), and `agy` (`~/.gemini/config/skills/`). Cursor has no global skills/commands path, so skills are not propagated to Cursor today.

The `hf-cli` skill is the one exception to that model: `hf skills add` generates it live from the installed `hf` CLI version rather than reading a vendored file, and it writes its own real content straight to `~/.agents/skills/hf-cli` (read directly by Codex/Cursor/OpenCode). `hf` sometimes auto-symlinks that content into `extensions/skills/hf-cli` via its own project-detection heuristic - not tied to shell cwd, so `cd`-ing elsewhere first does not prevent it - which would collide with the shadow-cleanup loop above (it would `rm -rf` the real content next run, mistaking it for a stray duplicate). `setup.sh` runs `hf skills add -g --claude --force` whenever `hf` is installed and then removes any such symlink defensively afterward, rather than trying to avoid triggering it (see DECISIONS.md 2026-08-10). This keeps Claude's `~/.claude/skills/hf-cli` symlink and the `~/.agents/skills/hf-cli` content current. agy is not covered - it reads its skills from `~/.gemini/config/skills`, and `hf` declares no support for that path.

## Delegation to Codex and agy

Delegation is orchestrated from Claude and always runs through two layers: a deterministic dispatch **wrapper** owns the CLI invocation, and a thin Claude **subagent** owns the surrounding judgment. This replaced the earlier `codex`/`agy` cross-agent skills (see DECISIONS.md 2026-09-05): a cheap subagent driving a dense prose workflow hallucinated a non-existent `agy exec` command, and when the dispatch failed it reviewed the code itself and reported the result as a genuine Gemini cross-model review. Prose prohibitions could not hold against a model's instinct to be helpful, so the mechanism moved into code.

`scripts/agy-dispatch.sh` and `scripts/codex-dispatch.sh` are the wrappers; `setup.sh` symlinks them onto `PATH` as `agy-dispatch`/`codex-dispatch` (in `~/.local/bin`, beside the `agy`/`codex` binaries) so they are callable by bare name from any repo. Each owns the one correct invocation and collapses "did the delegated run actually happen" into an exit code, so nothing that can hallucinate a command or mistake a silent no-op for success is ever in the loop. `agy-dispatch` validates the slug against the live `agy models` catalog, captures agy's own exit status, and hard-fails on the silent no-op (a headless run whose tools were auto-denied returns `"status": "SUCCESS"` with an empty response), naming the denied permission family from stderr. `codex-dispatch` captures codex's exit status directly (no trailing command to mask a failed launch) and requires a real `thread.started` id before reporting success; codex's deliverable under `workspace-write` is the diff, so an empty final message is not itself a failure. Both take an injectable CLI (`$AGY_BIN`/`$CODEX_BIN`) so `tests/dispatch.sh` stubs the model call. The wrappers stay cross-agent - any of the five agents can call them - even though only Claude orchestrates today. agy deliberately does not use the `gemini` CLI, which a personal Google account cannot authenticate against (`IneligibleTierError`/`UNSUPPORTED_CLIENT`); that path needs enterprise or API-key auth.

Claude subagents live in `extensions/agents/<name>.md` and are symlinked by `setup.sh` into `~/.claude/agents/`. The `codex` and `agy` subagents are thin dispatchers: each calls its wrapper (never the raw CLI), then collects the evidence a caller needs to judge the run - baseline, real diff wherever it landed, independent verification, and the wrapper's `thread_id`/`conversation_id` as proof a run happened. They run on `haiku` at `effort: low` with `tools: Bash, Read, Grep, Glob` - no Write or Edit - because their job is to gather evidence, not to judge or fix the work. A report carrying no id from this run's wrapper output is not a real dispatch and must be reported as `DISPATCH FAILED`, never dressed up as a result. That split keeps the JSONL, diffs and test output in the subagent's context instead of the orchestrator's, and lets several dispatches run at once (parallel agy writers still need separate worktrees, and agy does not confine writes to its launch directory, so check every checkout afterward).

Distribution is Claude-only, and deliberately so. OpenCode reads markdown agents from `~/.config/opencode/agents/` but its schema differs (a `prompt` field and provider-prefixed model names such as `ollama/qwen2.5-coder:14b`, against Claude's body and `haiku` alias), so one shared file would be broken for one of them. `agy` exposes `--agent` and `agy agent` but ships no documented definition path. Codex has no subagent primitive at all. The wrapper scripts, being plain shell on `PATH`, remain usable by all of them regardless.

Two more Claude subagents, `advisor-quick` and `advisor-deep`, sit above the `codex`/`agy` dispatchers. Both are Opus-class and read-only (`Read, Grep, Glob, Bash`, no Write/Edit): they give a go/no-go opinion on a plan before it is dispatched, they never implement anything. `effort` is static frontmatter, not something one agent can flex per call, so complexity is handled by picking which file to invoke: `advisor-quick` (`effort: low`) for a plan that is already fairly clear and just needs a second opinion; `advisor-deep` (`effort: high`) when the decision itself is the hard part - ambiguous scope, multiple viable approaches, or real risk if the wrong call is made.

Consulting an advisor is the orchestrator's discretion, not a rule that fires on every dispatch: reach for one before a non-trivial codex/agy dispatch (new worktree, multi-file, ambiguous scope, or anything the orchestrator is unsure about), and skip it for routine or mechanical dispatches. Skip it entirely, regardless of task shape, when the orchestrating session's own model is already Opus-class or above - consulting an equal-or-weaker advisor is pointless. When it is genuinely unclear whether the advisor call is worth the tokens, ask the user rather than guessing.

The reviewer tier needs no new subagent file - it is the `codex`/`agy` dispatcher pointed at a stronger model/effort than the implementer used, so the same evidence-gathering shape applies to review as to implementation. Pick per task: `gpt-5.6-sol`/`medium` or `gpt-5.6-terra`/`high` via the `codex` subagent for a Codex-side second look; an Opus-class Claude review (a plain `Task`/general-purpose dispatch, or `advisor-deep` when the question is "should this be accepted" rather than "is this correct") when the review needs Claude's judgment specifically; or the `agy` subagent with whichever catalog model is strong enough - agy is fine for review as long as the model backing it is, not by default. A reviewer must differ in model or effort from whichever run produced the work.

### Capability bands: model routing that survives churn

New models arrive across codex/agy every month or two, so model slugs live in exactly one place - `config/bands.json` - and nothing else hard-codes them. A **band** is a capability requirement with a fixed acceptance bar (codex: `distinguished`/`staff`/`senior`/`engineer`; the agy pod is separate, with `senior`/`engineer`/`mid`/`intern`/`layman` - never equate the two). A **stance** picks a concrete `(model, effort)` that still meets that bar: `balanced` (default), `cost_first` (cheaper/less effort but never below the bar), `capability_first` (headroom above it). `cost_first` is v1 initial-selection only - it does not yet auto-escalate on failure; an unresolved failure returns to the orchestrator.

`scripts/band-resolve.sh` (on PATH as `band-resolve`) turns `--backend <codex|agy> --band <name> [--stance <name>]` into one JSON object (`{"model":...,"effort":...}`). It is pure offline lookup: callers parse it with `jq`, never `eval` it. It fails closed on invalid policy (unknown backend/band/stance, malformed cell) and falls back per-cell to `balanced` (reported), never across bands; a present cell is authoritative. The codex/agy subagents call it instead of hand-picking a slug. **claude is deliberately not routed through it** - Claude subagent effort is static frontmatter with no per-call adapter, so a claude cell would be decorative; claude routing is this orchestrator convention (band -> `opus`/`sonnet` alias by judgment), not resolver-enforced. Selecting the reviewer's family for vendor diversity is likewise the orchestrator's call - `band-resolve` only sees `--backend` after that choice is made.

Discovery is machine-enumerable on all three backends, so churn is a one-file edit to `config/bands.json`: agy via `agy models`; codex via `scripts/codex-models.py` (on PATH as `codex-models`), a supervised adapter over the `codex app-server` `model/list` JSON-RPC (codex ships no `codex models` command - openai/codex#23279) that also carries `upgradeInfo.retirementAt` and the successor slug; claude by alias. `scripts/bands-drift.sh` (`bands-drift`) reports drift read-only - `RETIRING` (scheduled) vs `ABSENT` (gone) vs `UNASSIGNED` (maybe new) vs `UNAVAILABLE` (discovery failed, treated as unknown not retired). `setup.sh` validates `config/bands.json` (`scripts/bands-validate.py`) before exposing anything and aborts on a broken map. The human-gated refresh *write*, a candidate inventory, snapshot caching, deterministic task-sizing (what chooses the band), and the escalation loop are deferred (see DECISIONS.md 2026-09-05).

### SKILL.md / command frontmatter: always single-quote `description:`

YAML `description:` values in `SKILL.md` and `extensions/commands/*.md` break on two unquoted special-char footguns: `: ` (colon-space, e.g. "Idempotent: re-running") makes strict parsers hard-fail with "mapping values are not allowed in this context" and **skip the skill at load**; ` #` (space-hash) is read as a comment and **silently truncates** the value. Claude Code's parser is lenient and hides both - but Codex's is strict, so a skill that works in Claude can be broken for Codex. Always wrap the whole `description` value in single quotes (escape any literal `'` as `''`).

This is enforced mechanically, not by convention:
- **`extensions/hooks/validate-skill-frontmatter.sh`** - canonical, tool-agnostic validator (bash + `/usr/bin/ruby` YAML). Catches both footguns.
- **Git pre-commit hook** (`extensions/hooks/pre-commit-skill-frontmatter.sh`, symlinked into `.git/hooks/pre-commit` by `setup.sh`) - blocks committing any staged `SKILL.md` / command `.md` with broken frontmatter. Cross-agent by construction: fires on `git commit` regardless of which agent staged the edit, unlike a Claude-only PreToolUse hook.
- **`setup.sh` self-check** - validates all sources before distributing and aborts on failure; the command->skill generator re-quotes every `description` as a YAML single-quoted scalar for Codex/OpenCode so it can never emit a broken file.

When planning any change to AI agent settings, configuration, hooks, slash commands, skills, `setup.sh` propagation logic, or anything under `extensions/`, `config/`, or `instructions/AI.md`: invoke `/configure-agents` first. It checks the relevant documentation for all five provisioned tools and ensures the change is expressed correctly in every format before any file is touched. A PreToolUse hook (`extensions/hooks/configure-agents-reminder.sh`) nudges this on every Edit/Write/MultiEdit into those paths, but the rule applies whether or not the hook fires.

## Terminal integration

Ghostty is the shared transport for terminal-based agents:

- Canonical common Ghostty settings live in `config/ghostty.conf.tpl`; macOS-only settings live in `config/ghostty-macos.conf.tpl`.
- `setup.sh` merges each template into a labeled managed block. Never replace the surrounding user-owned terminal config.
- Claude Code explicitly enables `terminalProgressBarEnabled` and selects the `ghostty` notification channel in `config/settings.json.tpl`.
- Do not set Ghostty's global `title`: a fixed value blocks dynamic AI session names and application titles.
- tmux transport is intentionally not managed by this repo (removed 2026-07-23). If a downstream workflow needs tmux, own the config yourself outside `ai-dotfiles`.

## Parallel sessions / worktrees

This repo and downstream projects support multiple AI agents working in parallel on the same repo. To avoid branch / working-tree conflicts, isolate each non-trivial task in its own git worktree.

When to create a worktree:
- Starting a feature, bug fix, refactor, or any multi-step change.
- Executing a written implementation plan.
- Any time another AI session may already be working in the repo.

When to skip:
- Read-only inspection, trivial typo edits, single-file config tweaks.
- The user explicitly says "work in place" or "don't worktree this."

How to create one, per agent:

| Agent | Mechanism |
|---|---|
| Claude Code | Use the native `EnterWorktree` tool. If the `superpowers` plugin is enabled, follow `superpowers:using-git-worktrees`. |
| OpenCode / agy / Codex / Cursor | Manual fallback: `git worktree add .worktrees/<branch> -b <branch>` then `cd` in. |

Directory: `.worktrees/` at the repo root. Ignored globally by `setup.sh`, so no per-repo `.gitignore` change is needed.

Before creating one, run the Step 0 detection: if `git rev-parse --git-dir` differs from `git rev-parse --git-common-dir` (and you are not in a submodule), you are already in a worktree - reuse it instead of nesting.

After creating: install deps for the stack (`npm install` / `cargo build` / `pip install -r requirements.txt` / `go mod download`) and run the baseline test suite before touching code.

## AI Nativity (New Repositories)

When initializing a new repository or starting a new project, your FIRST action must be to make the project "AI Native" by ensuring cross-agent parity. You must do this autonomously:
1. Initialize the git repository with `main` as the default branch, NEVER `master`.
2. Create an `AI.md` file in the root of the new repository to store project-specific AI instructions (e.g., directory layout, run commands, tech stack).
3. Create four symlinks pointing to it:
   - `ln -s AI.md CLAUDE.md`
   - `ln -s AI.md OPENCODE.md`
   - `ln -s AI.md GEMINI.md`
   - `ln -s AI.md AGENTS.md`

The `AGENTS.md` symlink is dual-purpose: Codex and Cursor both read it from the project root, so no fifth symlink is needed for Cursor.

This guarantees that Claude, OpenCode, agy, Codex, and Cursor all share the exact same operational context from day one without any configuration drift. `agy` discovers the project-level `GEMINI.md` or `AGENTS.md` symlink while walking up from its working directory.
