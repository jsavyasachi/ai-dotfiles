---
description: 'Fetch each AI tool''s official docs and propose a cross-agent settings change across Claude Code, OpenCode, Antigravity CLI, Codex, Cursor, and Pi'
---

You are helping the user make a configuration change that must work correctly across all six AI agents in this repo: Claude Code, OpenCode, Antigravity CLI (`agy`), Codex, Cursor, and Pi. Your job is to fetch the relevant official docs, read the current local config state, propose the full cross-agent diff, and only touch files after explicit approval.

## Doc index

Use WebFetch on these pages when you need schema details for the relevant tool. Only fetch pages that apply to the change being requested - don't fetch all of them blindly.

**Claude Code**
- Settings reference: `https://code.claude.com/docs/en/settings`
- Hooks: `https://code.claude.com/docs/en/hooks`
- Slash commands: `https://code.claude.com/docs/en/slash-commands`
- Skills: `https://code.claude.com/docs/en/skills`
- Memory / CLAUDE.md: `https://code.claude.com/docs/en/memory`

**OpenCode**
- Configuration: `https://opencode.ai/docs/config`
- Commands: `https://opencode.ai/docs/commands`

**Antigravity CLI (`agy`)**
- Model catalog: use `agy models`
- Local settings: inspect `~/.gemini/antigravity-cli/settings.json` (scoped merge only)

**Pi**
- Documentation: `https://github.com/earendil-works/pi`
- Agent directory: `~/.pi/agent/` (`AGENTS.md`, `APPEND_SYSTEM.md`, `skills/`, `prompts/`)

**Codex**
- Config reference (config.toml): `https://developers.openai.com/codex/config-reference`
- Skills: `https://developers.openai.com/codex/skills`

**Cursor**
- Rules: `https://cursor.com/docs/context/rules`
- MCP: `https://cursor.com/docs/context/mcp`
- Hooks: `https://cursor.com/docs/agent/hooks`

## Steps

1. **Read local config state**: read all source files before proposing anything:
   - `config/settings.json.tpl` - Claude Code settings template
   - `config/opencode.json.tpl` - OpenCode settings template
   - `~/.codex/config.toml` - Codex config (NOT managed by this repo; Codex owns the file and rewrites it. Read it for context, never write a managed block into it - see `instructions/DECISIONS.md`, 2026-08-03)
   - `config/cursor-mcp.json` - Cursor MCP configuration
   - `config/agy-settings.json.tpl` - Antigravity CLI scoped settings
   - `instructions/AI.md` - cross-agent policies and capability table
   - `extensions/commands/` - current cross-agent commands

2. **Fetch relevant doc pages**: WebFetch only the pages from the index above that apply to the type of change being requested (hooks, permissions, settings keys, commands, etc.).

3. **Propose the cross-agent implementation**: show exactly what changes in each file using the correct format for each tool:
   - Claude Code: JSON (settings.json.tpl)
   - OpenCode: JSON (opencode.json.tpl)
   - Antigravity CLI (`agy`): scoped JSON settings or skills (it has no command translation)
   - Codex: SKILL.md (generated from `extensions/commands/` via setup.sh); `config.toml` is unmanaged
   - Cursor: MCP JSON, project `AGENTS.md`, project `.cursor/commands/`, project `.cursor/hooks/`, or Settings UI instructions as supported
   - Pi: `~/.pi/agent/` symlinks for instructions, output style, prompts, and skills; `settings.json` is unmanaged
   - If a change cannot be expressed equivalently in all 6 formats, flag the gap explicitly and propose the closest equivalent or "N/A - not supported".
   - If `instructions/AI.md` needs a new entry (new behavior, new capability, new convention), include that in the proposal too.

4. **Wait for user approval**: do not touch any file until the user explicitly says to proceed.

5. **Execute on approval**: edit only source files in this repo (never agent home dirs directly):
   - `config/settings.json.tpl`, `config/opencode.json.tpl`, `config/agy-settings.json.tpl`, and/or `config/cursor-mcp.json` (Codex and Pi settings are unmanaged)
   - `extensions/commands/<name>.md` (create or edit)
   - `instructions/AI.md` (if needed)
   - Then run `bash setup.sh` to distribute everything.

6. **Verify**: confirm `setup.sh` completed without errors. Report what changed: which files were edited, which were distributed, any Skipped entries.

## Rules

- Never edit agent home directories directly (`~/.claude/settings.json`, `~/.config/opencode/opencode.json`, `~/.codex/config.toml`, `~/.cursor/mcp.json`, etc.). Always edit source files in `config/` and run `setup.sh`.
- `instructions/AI.md` is the canonical file. `CLAUDE.md`, `OPENCODE.md`, `GEMINI.md`, `AGENTS.md` in the `instructions/` dir are all symlinks to it - edit only `AI.md`.
- Always check whether `instructions/AI.md` needs updating: any new behavior, capability, or convention belongs there.
- Cross-agent commands live in `extensions/commands/<name>.md`. `setup.sh` distributes them automatically to each agent's native format - no manual copy needed.
- If a doc URL returns 404 or unexpected content, say so and ask the user for the correct URL rather than guessing.
