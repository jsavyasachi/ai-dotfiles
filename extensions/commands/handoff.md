---
description: Seal the current session into .ai/journal.md and optionally promote durable items to AI.md
---

You are sealing the current session for the next agent (which may be a different CLI: Claude Code, Codex, OpenCode, or Gemini). The goal is a high-signal handoff, not a transcript.

## Steps

1. **Summarize the session** into four buckets. Be concrete — name files, decisions, and unresolved questions:
   - **Done** — what shipped this session (changes that exist on disk, commits made, tests passing).
   - **Decided** — choices made and why. One line each. Skip if nothing material was decided.
   - **Open** — unresolved questions, blockers, things the user hasn't answered yet.
   - **Next** — what the next agent should pick up first. Be specific: file, function, line if possible.

   Skip empty buckets — don't pad. If only Done has content, write only Done.

2. **Resolve the durable instructions file**:
   - Prefer `AI.md` at the repo root.
   - If root `AI.md` is absent and `instructions/AI.md` exists, use `instructions/AI.md` instead. This is the `ai-dotfiles` repo layout.

3. **Show the summary to the user**, then ask exactly:
   > Promote any item to `AI.md` `## Decisions`? (reply with item numbers, "all", or "n")

   Wait for the user's answer.

4. **Append to `.ai/journal.md`** in the repo root (create the directory and file if missing):

   ```
   ## YYYY-MM-DD HH:MM — <agent-name>

   **Done**
   - …

   **Decided**
   - …

   **Open**
   - …

   **Next**
   - …
   ```

   - Use ISO date and 24h time in the local timezone.
   - `<agent-name>` is the CLI you are running in (`claude-code`, `codex`, `opencode`, or `gemini-cli`). Infer from your runtime.
   - Append at the bottom of the file. Do not rewrite previous entries.

5. **If the user promoted items**, append them under a `## Decisions` heading in the durable instructions file from step 2 (create the heading if missing — place it just above the `## Cross-agent config` section if that section exists, otherwise at the end). Format:

   ```
   - YYYY-MM-DD: <decision in one line, present tense>
   ```

6. **Confirm** in one line: "Sealed. Journal: `<N>` entries. Decisions: `<+M>` added." — nothing more.

## Rules

- Do not invent activity. If a bucket would be empty, omit it.
- Do not include code diffs. The journal is a memory aid, not a log.
- Do not skip the user-confirmation step in (2). Even if you think a decision is obviously durable, the user picks.
- If `.ai/journal.md` exists but is malformed, do not "fix" it — just append cleanly below.
