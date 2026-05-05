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
| `/configure-agents` | Fetch official docs for all 4 tools, propose + apply a cross-agent settings change |

**Stop hook**: soft dirty-tree warning on session end (Claude Code, Codex).

**Status line**: repo@branch, git indicators, context usage bar (Claude Code).

## Adding a command

Drop a `.md` file with `description` frontmatter into `extensions/commands/`, then run `bash setup.sh`. It auto-distributes: symlink for Claude Code/OpenCode commands, SKILL.md for OpenCode/Codex, TOML for Gemini CLI.

## Testing

```bash
make test   # installer checks
make lint   # bash syntax
```
