# ai-dotfiles

Cross-machine, cross-agent AI harness configuration for Claude Code, OpenCode, Gemini CLI, Codex, and Cursor.

## Stack

<a href="https://anthropic.com"><img src="https://img.shields.io/badge/Claude_Code-7C4DFF?style=flat&logo=anthropic&logoColor=white" alt="Claude Code" /></a>
<a href="https://opencode.ai"><img src="https://img.shields.io/badge/OpenCode-000000?style=flat&logo=openai&logoColor=white" alt="OpenCode" /></a>
<a href="https://google.com"><img src="https://img.shields.io/badge/Gemini_CLI-4285F4?style=flat&logo=google&logoColor=white" alt="Gemini CLI" /></a>
<a href="https://developers.openai.com/codex"><img src="https://img.shields.io/badge/Codex-000000?style=flat&logo=openai&logoColor=white" alt="Codex" /></a>
<a href="https://cursor.com"><img src="https://img.shields.io/badge/Cursor-000000?style=flat&logo=cursor&logoColor=white" alt="Cursor" /></a>
<a href="https://www.gnu.org/software/bash/"><img src="https://img.shields.io/badge/Bash-4EAA25?style=flat&logo=gnubash&logoColor=white" alt="Bash" /></a>

## Setup

```bash
git clone git@github.com:savyasachi16/ai-dotfiles.git ~/projects/ai-dotfiles
cd ~/projects/ai-dotfiles
bash setup.sh
```

Idempotent: safe to re-run after pulling updates.

## What You Get

**Universal instructions**: `instructions/AI.md` is the canonical source. `instructions/{CLAUDE,OPENCODE,GEMINI,AGENTS}.md` are symlinks to it, and `setup.sh` installs those into each agent's home. Cursor consumes `AGENTS.md` per repo; global Cursor User Rules still require a one-time paste into Settings > Rules.

**Cross-agent commands**: canonical `.md` files live in `extensions/commands/`. `setup.sh` installs them in each tool's native shape:

| Agent | Install format |
|---|---|
| Claude Code | `~/.claude/commands/<name>.md` symlink |
| OpenCode | `~/.config/opencode/commands/<name>.md` symlink + generated `skills/<name>/SKILL.md` |
| Gemini CLI | generated `~/.gemini/commands/<name>.toml` |
| Codex | generated `~/.codex/skills/<name>/SKILL.md` |
| Cursor | not global; per-project commands only |

| Command | What it does |
|---|---|
| `/handoff` | Seal session into `.ai/journal.md`; append decisions to `AI.md` / `instructions/AI.md` |
| `/catchup [N]` | Replay last N journal entries + durable decisions |
| `/commit` | Commit current logical unit (Conventional Commits) |
| `/push` | Docs/instructions audit then push |
| `/configure-agents` | Fetch official docs for all 5 tools, propose + apply a cross-agent settings change |

**Cross-agent skills**: first-party skills live in `extensions/skills/<name>/`. `setup.sh` symlinks them into Claude Code, OpenCode, Codex, and Gemini native skill dirs. Cursor has no global skills path.

**Hooks and guardrails**: Claude Code and Codex get a soft dirty-tree Stop hook. Claude Code also gets a PreToolUse reminder before edits to agent config surfaces. Git gets a repo-local pre-commit hook that validates command and skill frontmatter for every agent.

**Status line**: Claude Code and OpenCode get the shared `scripts/statusline-command.sh`; Codex uses the native TUI status-line config in `config/codex.toml.tpl`.

**Session continuity**: downstream repos use untracked `.ai/journal.md` for handoff/catchup state and tracked `AI.md` decisions for durable project policy.

## Repo layout: where to edit what

| You want to change... | Edit this | How it propagates |
|---|---|---|
| Universal AI instructions (tone, conventions, decisions) | `instructions/AI.md` | Symlinked as `CLAUDE.md`, `OPENCODE.md`, `GEMINI.md`, `AGENTS.md` (Codex + Cursor share `AGENTS.md`). Cursor's global User Rules need a one-time manual paste into Settings > Rules. |
| Cross-agent slash commands | `extensions/commands/<name>.md` (YAML frontmatter + Markdown body) | `setup.sh` symlinks to Claude Code/OpenCode, generates `.toml` for Gemini, generates `SKILL.md` for Codex/OpenCode. Cursor commands are per-repo only and not auto-propagated. |
| Hooks (Claude Code, e.g. Stop, PreToolUse) | `extensions/hooks/<name>.sh` + reference it in `config/settings.json.tpl` | The hooks dir is symlinked to `~/.claude/hooks/`; settings template is rendered to `~/.claude/settings.json` with absolute paths. |
| Hooks (Codex) | `config/codex.toml.tpl` `[hooks]` block | Merged into `~/.codex/config.toml` inside an `ai-dotfiles managed` block (preserves your other Codex config). |
| Memory (Claude Code) | `extensions/memory/MEMORY.md` and `extensions/memory/<topic>.md` | Symlinked into `~/.claude/projects/<encoded-projects-path>/memory/`. |
| Skills (cross-agent) | `extensions/skills/<name>/SKILL.md` | Whole-dir symlink to `~/.claude/skills/`; per-skill symlink into `~/.config/opencode/skills/`, `~/.codex/skills/`, and `~/.gemini/skills/`. Cursor has no global skills path. Third-party skills installed via `npx skills add` land here too (gitignored by default); first-party skills authored in this repo (e.g. `mermaid/`) are explicitly un-ignored in `.gitignore`. |
| Per-agent settings (Claude / OpenCode / Codex / Cursor MCP) | `config/settings.json.tpl`, `config/opencode.json.tpl`, `config/codex.toml.tpl`, `config/cursor-mcp.json` | `setup.sh` renders Claude/OpenCode templates with absolute paths, merges Codex config into an `ai-dotfiles managed` block, and copies Cursor MCP config. Use `@@CLAUDE_DIR@@`, `@@OPENCODE_DIR@@`, `@@DOTFILES_DIR@@` placeholders. |
| Claude plugins to auto-install | `config/plugins.txt` (one plugin id per line) | `setup.sh` calls `claude plugin install` for any plugin not already installed. |
| Status line | `scripts/statusline-command.sh` | Symlinked to Claude Code and OpenCode. |
| Stop-hook dirty-tree behavior | `scripts/dirty-tree-check.sh` | Symlinked to `~/.claude/`; Codex references it via absolute path in the merged config block. |

After editing any of the above, run `bash setup.sh`. It's idempotent and prints what changed.

## Adding a new agent

Cross-agent parity work goes through the `/configure-agents` command, which fetches official docs for all 5 tools before any file is touched. See `instructions/AI.md` `## Cross-agent config` for the canonical mapping.

## Testing

```bash
make test   # installer checks
make lint   # bash syntax
```
