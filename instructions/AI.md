# Universal AI Instructions

Tone, conciseness, and vocabulary rules live in `instructions/OUTPUT-STYLE.md`,
not here - see `Cross-agent config` > `Output style` below for why and how
each agent loads it.

## Questions

Ask one question at a time. Never bundle multiple questions in a single message.

When the answer space is discrete/enumerable, use the agent's structured question tool instead of plain text:
- Claude Code: `AskUserQuestion`
- Gemini CLI: `ask_user` (`choice` type)
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

This repo powers Claude Code, OpenCode, Gemini CLI, Codex, and Cursor. When updating settings, update analogues too:

| Capability | Claude Code | OpenCode | Gemini CLI | Codex | Cursor |
|---|---|---|---|---|---|
| Settings | `settings.json` | `opencode.json` | `settings.json` | `config.toml` | Cursor Settings UI (no file) |
| Instructions | `CLAUDE.md` | `OPENCODE.md` | `GEMINI.md` | `AGENTS.md` | `AGENTS.md` (per-repo); User Rules via Settings (global) |
| Slash commands | `commands/` (.md) | `commands/` (.md) | `commands/` (.toml) | - (use skills) | `.cursor/commands/` (.md, per-repo) |
| Skills | `skills/` | `skills/` | `skills/` (v0.41+) | `~/.codex/skills/` | - |
| Hooks | `settings.json` | `hooks.yaml` (plugin) | hooks (v0.26+) | `config.toml` `[hooks]` (unmanaged - own it directly) | `.cursor/hooks/` (per-repo, beta) |

Cursor reads `AGENTS.md` from the project root, so the same per-repo `AGENTS.md` symlink that Codex consumes also covers Cursor. Cursor's global "User Rules" live in the Cursor Settings UI, not a file we can symlink: paste `instructions/AI.md` into Settings > Rules once per machine.

### Output style

`instructions/OUTPUT-STYLE.md` (Tone, Conciseness, ASD-STE100) is a separate
canonical file from `AI.md`, wired into each agent's native "system prompt" or
"additional instructions" slot instead of its plain instructions file, so it
applies as strongly as each agent allows rather than competing with ordinary
CLAUDE.md/AGENTS.md text for the model's attention:

- **Claude Code**: `setup.sh` generates `~/.claude/output-styles/ai-dotfiles.md` (frontmatter + the file's body, `keep-coding-instructions: true`) from it every run. `config/settings.json.tpl` sets `"outputStyle": "ai-dotfiles"` as the default. Native output styles apply to the main conversation and forks only - subagents run their own system prompt and do not inherit it.
- **OpenCode**: `config/opencode.json.tpl`'s `instructions` array lists `OUTPUT-STYLE.md` alongside `OPENCODE.md` - OpenCode concatenates every listed file.
- **Gemini CLI**: `config/gemini-settings.json.tpl` sets `context.fileName` to `["GEMINI.md", "OUTPUT-STYLE.md"]` - Gemini CLI concatenates every named context file it finds per directory.
- **Codex**: no automated path. Codex reads one `AGENTS.md` with no multi-file or import syntax, and `~/.codex/config.toml` is intentionally unmanaged (see `Decisions`), so a managed `developer_instructions` key can't be templated in safely. To opt in manually, add `developer_instructions = "instructions/OUTPUT-STYLE.md"` (absolute path) to your own `~/.codex/config.toml`.
- **Cursor**: no automated path. Paste `instructions/OUTPUT-STYLE.md` into Settings > Rules alongside `AI.md`, same manual, once-per-machine step as the rest of Cursor's global rules.

Cross-agent slash commands (`/commit`, `/push`, `/configure-agents`) live as canonical Markdown in `extensions/commands/`. `setup.sh` distributes them: symlink to Claude/OpenCode, transform to TOML for Gemini, transform to a Codex skill (`name`+`description` frontmatter) for Codex. Cursor's `.cursor/commands/` is per-project, not global, so commands are not propagated to Cursor today.

Cross-agent skills (third-party or local) live in `extensions/skills/<name>/` (gitignored). `setup.sh` distributes them: symlink the whole dir to Claude (`~/.claude/skills/`), per-skill symlink into OpenCode (`~/.config/opencode/skills/`), Codex (`~/.codex/skills/`), and Gemini (`~/.gemini/skills/`) - Gemini v0.41+ has native Agent Skills, auto-registered as `/<name>` slash commands. Cursor has no global skills/commands path, so skills are not propagated to Cursor today.

The `hf-cli` skill is the one exception to that model: `hf skills add` generates it live from the installed `hf` CLI version rather than reading a vendored file, and it writes its own real content straight to `~/.agents/skills/hf-cli` (read directly by Codex/Cursor/OpenCode). `hf` sometimes auto-symlinks that content into `extensions/skills/hf-cli` via its own project-detection heuristic - not tied to shell cwd, so `cd`-ing elsewhere first does not prevent it - which would collide with the shadow-cleanup loop above (it would `rm -rf` the real content next run, mistaking it for a stray duplicate). `setup.sh` runs `hf skills add -g --claude --force` whenever `hf` is installed and then removes any such symlink defensively afterward, rather than trying to avoid triggering it (see DECISIONS.md 2026-08-10). This keeps Claude's `~/.claude/skills/hf-cli` symlink and the `~/.agents/skills/hf-cli` content current. Gemini CLI is not covered - no upstream `~/.agents/skills` support declared for it.

The `codex` skill is the cross-agent delegation workflow. It captures the repository baseline, isolates non-trivial writes in worktrees, gives Codex explicit file ownership and authorization boundaries, persists resumable JSONL sessions when needed, independently verifies the result, and limits repair/review loops. Parallel Codex writers require separate worktrees and non-overlapping file claims. It also selects the Codex model and reasoning effort explicitly per task shape, resolved from `codex debug models` at dispatch, instead of inheriting whatever `~/.codex/config.toml` resolves from the session's working directory.

### SKILL.md / command frontmatter: always single-quote `description:`

YAML `description:` values in `SKILL.md` and `extensions/commands/*.md` break on two unquoted special-char footguns: `: ` (colon-space, e.g. "Idempotent: re-running") makes strict parsers hard-fail with "mapping values are not allowed in this context" and **skip the skill at load**; ` #` (space-hash) is read as a comment and **silently truncates** the value. Claude Code's parser is lenient and hides both - but Codex's is strict, so a skill that works in Claude can be broken for Codex. Always wrap the whole `description` value in single quotes (escape any literal `'` as `''`).

This is enforced mechanically, not by convention:
- **`extensions/hooks/validate-skill-frontmatter.sh`** - canonical, tool-agnostic validator (bash + `/usr/bin/ruby` YAML). Catches both footguns.
- **Git pre-commit hook** (`extensions/hooks/pre-commit-skill-frontmatter.sh`, symlinked into `.git/hooks/pre-commit` by `setup.sh`) - blocks committing any staged `SKILL.md` / command `.md` with broken frontmatter. Cross-agent by construction: fires on `git commit` regardless of which agent staged the edit, unlike a Claude-only PreToolUse hook.
- **`setup.sh` self-check** - validates all sources before distributing and aborts on failure; the command->skill generator re-quotes every `description` per target (YAML single-quote for Codex/OpenCode, TOML basic string for Gemini) so it can never emit a broken file.

When planning any change to AI agent settings, configuration, hooks, slash commands, skills, `setup.sh` propagation logic, or anything under `extensions/`, `config/`, or `instructions/AI.md`: invoke `/configure-agents` first. It fetches official docs for all 5 tools and ensures the change is expressed correctly in every format before any file is touched. A PreToolUse hook (`extensions/hooks/configure-agents-reminder.sh`) nudges this on every Edit/Write/MultiEdit into those paths, but the rule applies whether or not the hook fires.

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
| OpenCode / Gemini / Codex / Cursor | Manual fallback: `git worktree add .worktrees/<branch> -b <branch>` then `cd` in. |

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

This guarantees that Claude, OpenCode, Gemini, Codex, and Cursor all share the exact same operational context from day one without any configuration drift.
