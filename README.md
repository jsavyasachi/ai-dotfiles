# ai-dotfiles

Cross-machine, cross-agent AI harness configuration for Claude Code, OpenCode, Antigravity CLI (`agy`), Codex, and Cursor.

## Stack

<a href="https://anthropic.com"><img src="https://img.shields.io/badge/Claude_Code-7C4DFF?style=flat&logo=anthropic&logoColor=white" alt="Claude Code" /></a>
<a href="https://opencode.ai"><img src="https://img.shields.io/badge/OpenCode-000000?style=flat&logo=openai&logoColor=white" alt="OpenCode" /></a>
<a href="https://antigravity.google/"><img src="https://img.shields.io/badge/Antigravity_CLI-4285F4?style=flat&logo=google&logoColor=white" alt="Antigravity CLI" /></a>
<a href="https://developers.openai.com/codex"><img src="https://img.shields.io/badge/Codex-000000?style=flat&logo=openai&logoColor=white" alt="Codex" /></a>
<a href="https://cursor.com"><img src="https://img.shields.io/badge/Cursor-000000?style=flat&logo=cursor&logoColor=white" alt="Cursor" /></a>
<a href="https://www.gnu.org/software/bash/"><img src="https://img.shields.io/badge/Bash-4EAA25?style=flat&logo=gnubash&logoColor=white" alt="Bash" /></a>
<a href="https://ghostty.org"><img src="https://img.shields.io/badge/Ghostty-3551F3?style=flat&logo=ghostty&logoColor=white" alt="Ghostty" /></a>
<a href="https://ollama.com"><img src="https://img.shields.io/badge/Ollama-000000?style=flat&logo=ollama&logoColor=white" alt="Ollama" /></a>

## Setup

```bash
git clone git@github.com:savyasachi16/ai-dotfiles.git ~/projects/ai-dotfiles
cd ~/projects/ai-dotfiles
bash setup.sh
```

Idempotent: safe to re-run after pulling updates.

## What You Get

**Universal instructions**: `instructions/AI.md` is the canonical source. `instructions/{CLAUDE,OPENCODE,GEMINI,AGENTS}.md` are symlinks to it. Claude Code, OpenCode, and Codex receive global links. `agy` discovers project-level `GEMINI.md` or `AGENTS.md` while walking up to the repository root. Cursor consumes `AGENTS.md` per repo; global Cursor User Rules still require a one-time paste into Settings > Rules.

**Cross-agent commands**: canonical `.md` files live in `extensions/commands/`. `setup.sh` installs them in each tool's native shape:

| Agent | Install format |
|---|---|
| Claude Code | `~/.claude/commands/<name>.md` symlink |
| OpenCode | `~/.config/opencode/commands/<name>.md` symlink + generated `skills/<name>/SKILL.md` |
| Antigravity CLI (`agy`) | no command translation; use skills |
| Codex | generated `~/.codex/skills/<name>/SKILL.md` |
| Cursor | not global; per-project commands only |

| Command | What it does |
|---|---|
| `/commit` | Commit current logical unit (Conventional Commits) |
| `/push` | Docs/instructions audit then push |
| `/configure-agents` | Fetch official docs for all 5 tools, propose + apply a cross-agent settings change |

**Cross-agent skills**: first-party skills live in `extensions/skills/<name>/`. `setup.sh` symlinks them into Claude Code, OpenCode, Codex, and agy's `~/.gemini/config/skills/` directory. Cursor has no global skills path. The `opencode` skill delegates smaller scoped tasks to the local Ollama model. Delegation to Codex and agy is not a skill: it runs through the `codex`/`agy` Claude subagents and the `codex-dispatch`/`agy-dispatch` wrappers (see **Delegation** below).

**Local-model stack**: setup installs Ollama when available, starts its service, and pulls models listed in `config/local-models.txt` idempotently. OpenCode defaults to `ollama/qwen2.5-coder:14b`.

**Hooks and guardrails**: Claude Code gets a soft dirty-tree Stop hook and a PreToolUse reminder before edits to agent config surfaces. Git gets a repo-local pre-commit hook that validates command and skill frontmatter for every agent. Codex hooks are configured directly in `~/.codex/config.toml` (see below).

**Status line**: Claude Code and OpenCode get the shared `scripts/statusline-command.sh`; Codex's native TUI status line is configured in `~/.codex/config.toml` directly.

**Terminal activity**: Ghostty gets progress bars, notifications, shell awareness, readable split styling, 100k scrollback, safer close behavior, and macOS session tabs. Claude Code explicitly emits Ghostty progress and notifications. `setup.sh` merges labeled blocks into existing terminal configs instead of replacing user settings.

## Repo layout: where to edit what

| You want to change... | Edit this | How it propagates |
|---|---|---|
| Universal AI instructions (tone, conventions, decisions) | `instructions/AI.md` | Symlinked as `CLAUDE.md`, `OPENCODE.md`, `GEMINI.md`, `AGENTS.md` (Codex + Cursor share `AGENTS.md`). Cursor's global User Rules need a one-time manual paste into Settings > Rules. |
| Cross-agent slash commands | `extensions/commands/<name>.md` (YAML frontmatter + Markdown body) | `setup.sh` symlinks to Claude Code/OpenCode and generates `SKILL.md` for Codex/OpenCode. agy has no TOML command format; reusable agy commands are skills. Cursor commands are per-repo only and not auto-propagated. |
| Hooks (Claude Code, e.g. Stop, PreToolUse) | `extensions/hooks/<name>.sh` + reference it in `config/settings.json.tpl` | The hooks dir is symlinked to `~/.claude/hooks/`; settings template is rendered to `~/.claude/settings.json` with absolute paths. |
| Hooks (Codex) | not managed - edit `~/.codex/config.toml` directly | Codex rewrites that file itself and persists `model`, `[features]`, `[tui]`, and `[[hooks.Stop]]` on its own. A managed block re-declared those tables and TOML rejects a duplicate table, so Codex hard-failed at startup with `duplicate key`. Removed 2026-08-03. |
| Memory (Claude Code) | `extensions/memory/MEMORY.md` and `extensions/memory/<topic>.md` | Symlinked into `~/.claude/projects/<encoded-projects-path>/memory/`. |
| Skills (cross-agent) | `extensions/skills/<name>/SKILL.md` | Whole-dir symlink to `~/.claude/skills/`; per-skill symlink into `~/.config/opencode/skills/`, `~/.codex/skills/`, and agy's `~/.gemini/config/skills/`. Cursor has no global skills path. Third-party skills installed via `npx skills add` land here too (gitignored by default); first-party skills authored in this repo (e.g. `mermaid/`) are explicitly un-ignored in `.gitignore`. |
| Local Ollama models | `config/local-models.txt` | `setup.sh` installs Ollama if missing (macOS/brew), starts the service, and pulls each listed model idempotently. |
| Managed settings and MCP config | `config/settings.json.tpl`, `config/opencode.json.tpl`, `config/cursor-mcp.json` | `setup.sh` renders Claude/OpenCode templates with absolute paths and copies Cursor MCP config. agy owns `~/.gemini/antigravity-cli/settings.json`, and Codex owns `~/.codex/config.toml`; neither is managed. Use `@@CLAUDE_DIR@@`, `@@OPENCODE_DIR@@`, `@@DOTFILES_DIR@@` placeholders. |
| Ghostty settings | `config/ghostty.conf.tpl`, `config/ghostty-macos.conf.tpl` | Merged into the active Ghostty config as labeled managed blocks; existing settings remain untouched outside those blocks. |
| Claude plugins to auto-install | `config/plugins.txt` (one plugin id per line) | `setup.sh` calls `claude plugin install` for any plugin not already installed. |
| Status line | `scripts/statusline-command.sh` | Symlinked to Claude Code and OpenCode. |
| Stop-hook dirty-tree behavior | `scripts/dirty-tree-check.sh` | Symlinked to `~/.claude/`; Codex references it via absolute path in the merged config block. |
| Claude subagents | `extensions/agents/<name>.md` | Symlinked to `~/.claude/agents/`. `codex` and `agy` dispatch through the `codex-dispatch`/`agy-dispatch` wrappers, run on `haiku` with no write tools, and return verification evidence rather than a verdict. `advisor-quick`/`advisor-deep` are Opus-class, read-only, and give a go/no-go opinion on a plan before it is dispatched - picked by decision complexity since `effort` is static per file, and consulted at the orchestrator's discretion, skipped when the orchestrator itself is already Opus-class or above. Claude-only: OpenCode's agent schema differs, agy documents no definition path, Codex has no subagent primitive. |
| Delegation dispatch wrappers | `scripts/agy-dispatch.sh`, `scripts/codex-dispatch.sh` | Symlinked onto `PATH` as `agy-dispatch`/`codex-dispatch`. Own the one correct agy/codex invocation and turn "did the run actually happen" into an exit code (slug validation, silent-no-op detection for agy, real `thread_id`/`conversation_id` required). The `codex`/`agy` subagents call these instead of hand-writing CLI commands. Injectable CLI (`$AGY_BIN`/`$CODEX_BIN`) for the `tests/dispatch.sh` unit tests. |
| Delegated model tiers | `config/bands.json` | Capability **bands** x **stances** -> `(model, effort)` for codex and the separate agy pod; the one place model slugs live, so churn is a one-file edit. Resolved by `scripts/band-resolve.sh` (`band-resolve`), a pure offline JSON lookup that fails closed on invalid policy. The `codex`/`agy` subagents route through it instead of hand-picking slugs. claude is intentionally not routed here (static subagent effort); it stays an orchestrator convention. `scripts/bands-validate.py` checks the map at setup and aborts on a broken one. |
| Model-catalog discovery | `scripts/codex-models.py` (`codex-models`), `scripts/bands-drift.sh` (`bands-drift`) | `codex-models` enumerates the Codex catalog via the `codex app-server` `model/list` JSON-RPC (codex has no `codex models` command), preserving retirement metadata; agy uses `agy models`. `bands-drift` reports read-only how `config/bands.json` has drifted from the live catalogs (retiring / absent / unassigned / unavailable). The human-gated refresh *write* is deferred v2. |
| Live view of a delegated run | `scripts/agent-watch.py` | Tails a codex or agy dispatch log and reports the tool, model, elapsed time, current activity and command/edit counts. Animates in place on a terminal; prints one line per state change when the output is captured. Not installed anywhere - run it directly. |
| agy permission matrix | `scripts/probe-agy-permissions.sh` | Re-derives which `permissions.allow` rule forms agy actually accepts. Restores settings on exit. |

After editing any of the above, run `bash setup.sh`. It's idempotent and prints what changed.

## Adding a new agent

Cross-agent parity work goes through the `/configure-agents` command, which checks the relevant docs for all five provisioned tools before any file is touched. See `instructions/AI.md` `## Cross-agent config` for the canonical mapping.

## Testing

```bash
make test   # installer checks
make lint   # bash syntax
```

CI runs both targets on macOS and Linux for every PR and push to `main`.
