# ai-dotfiles

Cross-machine AI agent configuration for Claude Code, OpenCode, Gemini CLI, Codex, and Cursor.

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

## What you get

**Universal instructions**: `instructions/AI.md` symlinked to every agent. One edit, all agents updated. Cursor consumes the same `AGENTS.md` symlink that Codex does (per-repo); for Cursor's global User Rules, paste `instructions/AI.md` into Cursor Settings > Rules once per machine (setup prints a one-time hint).

**Cross-agent commands**: canonical `.md` files in `extensions/commands/`, distributed by `setup.sh` in each agent's native format:

| Command | What it does |
|---|---|
| `/handoff` | Seal session → `.ai/journal.md`, optionally promote decisions to `AI.md` |
| `/catchup [N]` | Replay last N journal entries + durable decisions |
| `/commit` | Commit current logical unit (Conventional Commits) |
| `/push` | Docs/instructions audit then push |
| `/configure-agents` | Fetch official docs for all 5 tools, propose + apply a cross-agent settings change |

**Stop hook**: soft dirty-tree warning on session end (Claude Code, Codex).

**Status line**: repo@branch, git indicators, context usage bar (Claude Code).

## Repo layout: where to edit what

| You want to change... | Edit this | How it propagates |
|---|---|---|
| Universal AI instructions (tone, conventions, decisions) | `instructions/AI.md` | Symlinked as `CLAUDE.md`, `OPENCODE.md`, `GEMINI.md`, `AGENTS.md` (Codex + Cursor share `AGENTS.md`). Cursor's global User Rules need a one-time manual paste into Settings > Rules. |
| Cross-agent slash commands | `extensions/commands/<name>.md` (YAML frontmatter + Markdown body) | `setup.sh` symlinks to Claude Code/OpenCode, generates `.toml` for Gemini, generates `SKILL.md` for Codex/OpenCode. Cursor commands are per-repo only and not auto-propagated. |
| Hooks (Claude Code, e.g. Stop, PreToolUse) | `extensions/hooks/<name>.sh` + reference it in `config/settings.json.tpl` | The hooks dir is symlinked to `~/.claude/hooks/`; settings template is rendered to `~/.claude/settings.json` with absolute paths. |
| Hooks (Codex) | `config/codex.toml.tpl` `[hooks]` block | Merged into `~/.codex/config.toml` inside an `ai-dotfiles managed` block (preserves your other Codex config). |
| Memory (Claude Code) | `extensions/memory/MEMORY.md` and `extensions/memory/<topic>.md` | Symlinked into `~/.claude/projects/<encoded-projects-path>/memory/`. |
| Skills (Claude Code) | `extensions/skills/<name>/SKILL.md` | Symlinked to `~/.claude/skills/`. Codex skills are auto-generated from `extensions/commands/`; don't drop separate skills there unless you want Claude-only behavior. Third-party skills installed via `npx skills add ... --agent claude-code` land here too (gitignored): use absolute symlinks, since relative paths like `../../.agents/skills/<name>` resolve from the repo location and break. |
| Per-agent settings (Claude / OpenCode / Codex) | `config/settings.json.tpl`, `config/opencode.json.tpl`, `config/codex.toml.tpl` | `setup.sh` renders templates with absolute paths and writes them to each agent's home. Use `@@CLAUDE_DIR@@`, `@@OPENCODE_DIR@@`, `@@DOTFILES_DIR@@` placeholders. |
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
