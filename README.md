# ai-dotfiles

Cross-machine AI agent configuration for Mac and Linux.

## Stack

<a href="https://anthropic.com"><img src="https://img.shields.io/badge/Claude_Code-7C4DFF?style=flat&logo=anthropic&logoColor=white" alt="Claude Code" /></a>
<a href="https://google.com"><img src="https://img.shields.io/badge/Gemini_CLI-4285F4?style=flat&logo=google&logoColor=white" alt="Gemini CLI" /></a>
<a href="https://opencode.ai"><img src="https://img.shields.io/badge/OpenCode-000000?style=flat&logo=openai&logoColor=white" alt="OpenCode" /></a>
<a href="https://developers.openai.com/codex"><img src="https://img.shields.io/badge/Codex-000000?style=flat&logo=openai&logoColor=white" alt="Codex" /></a>
<a href="https://www.gnu.org/software/bash/"><img src="https://img.shields.io/badge/Bash-4EAA25?style=flat&logo=gnubash&logoColor=white" alt="Bash" /></a>

## Agents supported

| Agent | Config location | Instructions |
|-------|---------------|--------------|
| Claude Code | `~/.claude/` | `CLAUDE.md` |
| Gemini CLI | `~/.gemini/` | `GEMINI.md` |
| OpenCode | `~/.config/opencode/` | `OPENCODE.md` |
| Codex | `~/.codex/` | `AGENTS.md` |

## Universal Instructions

All agent instruction files (`CLAUDE.md`, `GEMINI.md`, `OPENCODE.md`, `AGENTS.md`) are symlinked to `AI.md` in this repo. This ensures that any behavioral update (tone, conciseness, tools) is instantly shared across all agents.

## Claude Code

| File/Dir | Method | Notes |
|---|---|---|
| `settings.json` | Copied from `.tpl` | Symlink causes Claude Code bug [#764](https://github.com/anthropics/claude-code/issues/764) |
| `statusline-command.sh` | Symlinked | oh-my-zsh-inspired statusbar |
| `CLAUDE.md` | Symlinked | Universal instructions (`AI.md`) |
| `commands/`, `skills/`, `hooks/` | Symlinked (whole dir) | Custom slash commands, skills, hooks |

## Gemini CLI

| File/Dir | Method | Notes |
|---|---|---|
| `GEMINI.md` | Symlinked | Universal instructions (`AI.md`) |
| `settings.json` | Copied | Auth and general settings |

## OpenCode

| File/Dir | Method | Notes |
|---|---|---|
| `opencode.json` | Copied from `.tpl` | Settings |
| `OPENCODE.md` | Symlinked | Universal instructions (`AI.md`) |
| `commands/`, `skills/` | Symlinked (whole dir) | Custom slash commands, skills |

## Codex

| File/Dir | Method | Notes |
|---|---|---|
| `config.toml` | Managed block merge from `.tpl` | Preserves local trust/project state while enforcing shared defaults |
| `AGENTS.md` | Symlinked | Universal instructions (`AI.md`) |
| `~/.agents/skills` | Symlinked (whole dir) | User-scoped Codex skills shared across repos |

## New machine setup

```bash
git clone git@github.com:savya/ai-dotfiles.git ~/projects/ai-dotfiles
cd ~/projects/ai-dotfiles
bash setup.sh
```

`setup.sh` is idempotent — safe to run again after pulling updates.

## Testing

Run the lightweight installer checks with:

```bash
make test
```

Syntax checks are available with:

```bash
make lint
```

## Adding new slash commands / skills

Files added inside `commands/` or `skills/` are live immediately on
the current machine (dirs are symlinked). Commit and push to sync to other machines.

## What's NOT tracked

Claude Code:

| Excluded | Reason |
|---|---|
| `history.jsonl`, `backups/`, `cache/`, `todos/` | Runtime/ephemeral state |
| `projects/`, `shell-snapshots/`, `statsig/` | Runtime/ephemeral state |
| `policy-limits.json` | Machine-specific security policy |
| `plugins/` | Marketplace downloads + personal blocklist entries |
| `settings.json` | Machine-specific copy generated from `settings.json.tpl` |

OpenCode:

| Excluded | Reason |
|---|---|
| `agents/`, `modes/`, `plugins/`, `tools/`, `themes/` | Runtime/ephemeral state |
| `file-history/`, `sessions/`, `tasks/`, `telemetry/` | Runtime/ephemeral state |

Codex:

| Excluded | Reason |
|---|---|
| `auth.json`, `history.jsonl`, `installation_id` | Auth/runtime state |
| `cache/`, `log/`, `tmp/`, `shell_snapshots/`, `sessions/` | Runtime/ephemeral state |
| `logs_*.sqlite*`, `state_*.sqlite*`, `models_cache.json`, `version.json` | Runtime/cache state |
| `~/.codex/skills/` | Bundled/system-managed skills, not user-authored repo config |

## Desktop app configs

Claude: `~/Library/Application Support/Claude/claude_desktop_config.json` (Mac) or
`~/.config/Claude/claude_desktop_config.json` (Linux) contains MCP server configs.

OpenCode: `~/Library/Application Support/opencode/` (Mac) or
`~/.config/opencode/` (Linux) contains MCP server configs.

Neither is tracked here because they often embed absolute paths to local binaries
and OAuth tokens.

## Templates

Templates use `@@DIR@@` placeholders for absolute home paths.
`setup.sh` substitutes the correct absolute path on each machine using `sed`.

For Codex, the repo ships a managed TOML fragment instead of a full `config.toml`.
`setup.sh` merges that block into `~/.codex/config.toml` so Codex trust metadata and
other local settings survive reruns.
