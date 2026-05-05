---
description: Fetch each AI tool's official docs and propose a cross-agent settings change across Claude Code, OpenCode, Gemini CLI, and Codex
---

You are helping the user make a configuration change that must work correctly across all four AI agents in this repo: Claude Code, OpenCode, Gemini CLI, and Codex. Your job is to fetch the relevant official docs, read the current local config state, propose the full cross-agent diff, and only touch files after explicit approval.

## Doc index

Use WebFetch on these pages when you need schema details for the relevant tool. Only fetch pages that apply to the change being requested - don't fetch all of them blindly.

**Claude Code**
- Settings reference: `https://docs.anthropic.com/en/docs/claude-code/settings`
- Hooks: `https://docs.anthropic.com/en/docs/claude-code/hooks`
- Slash commands: `https://docs.anthropic.com/en/docs/claude-code/slash-commands`
- Memory / CLAUDE.md: `https://docs.anthropic.com/en/docs/claude-code/memory`

**OpenCode**
- Configuration: `https://opencode.ai/docs/config`
- Commands: `https://opencode.ai/docs/commands`

**Gemini CLI**
- Overview & config: `https://geminicli.com`
- GitHub (settings.json schema): `https://github.com/google-gemini/gemini-cli/blob/main/docs/configuration.md`

**Codex**
- Config reference (config.toml): `https://github.com/openai/codex/blob/main/codex-cli/README.md`
- Skills: `https://github.com/openai/codex/blob/main/codex-cli/docs/skills.md`

## Steps

1. **Read local config state**: read all source files before proposing anything:
   - `config/settings.json.tpl` - Claude Code settings template
   - `config/opencode.json.tpl` - OpenCode settings template
   - `config/codex.toml.tpl` - Codex config template
   - `instructions/AI.md` - cross-agent policies and capability table
   - `extensions/commands/` - current cross-agent commands

2. **Fetch relevant doc pages**: WebFetch only the pages from the index above that apply to the type of change being requested (hooks, permissions, settings keys, commands, etc.).

3. **Propose the cross-agent implementation**: show exactly what changes in each file using the correct format for each tool:
   - Claude Code: JSON (settings.json.tpl)
   - OpenCode: JSON (opencode.json.tpl)
   - Gemini CLI: TOML (generated from extensions/commands/ .md files via setup.sh)
   - Codex: TOML (config.toml.tpl) or SKILL.md (extensions/commands/ → setup.sh)
   - If a change cannot be expressed equivalently in all 4 formats, flag the gap explicitly and propose the closest equivalent or "N/A - not supported".
   - If `instructions/AI.md` needs a new entry (new behavior, new capability, new convention), include that in the proposal too.

4. **Wait for user approval**: do not touch any file until the user explicitly says to proceed.

5. **Execute on approval**: edit only source files in this repo (never agent home dirs directly):
   - `config/settings.json.tpl` and/or `config/opencode.json.tpl` and/or `config/codex.toml.tpl`
   - `extensions/commands/<name>.md` (create or edit)
   - `instructions/AI.md` (if needed)
   - Then run `bash setup.sh` to distribute everything.

6. **Verify**: confirm `setup.sh` completed without errors. Report what changed: which files were edited, which were distributed, any Skipped entries.

## Rules

- Never edit agent home directories directly (`~/.claude/settings.json`, `~/.config/opencode/opencode.json`, `~/.codex/config.toml`, etc.). Always edit source templates in `config/` and run `setup.sh`.
- `instructions/AI.md` is the canonical file. `CLAUDE.md`, `OPENCODE.md`, `GEMINI.md`, `AGENTS.md` in the `instructions/` dir are all symlinks to it - edit only `AI.md`.
- Always check whether `instructions/AI.md` needs updating: any new behavior, capability, or convention belongs there.
- Cross-agent slash commands live in `extensions/commands/<name>.md`. `setup.sh` distributes them automatically - no manual copy needed.
- If a doc URL returns 404 or unexpected content, say so and ask the user for the correct URL rather than guessing.
