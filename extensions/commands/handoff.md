---
description: Seal the current session into .ai/journal.md and auto-promote Decided items to AI.md ## Decisions
---

You are sealing the current session for the next agent (which may be a different CLI: Claude Code, Codex, OpenCode, or Gemini). The goal is a high-signal handoff, not a transcript.

## Steps

1. **Summarize the session** into four buckets. Be concrete - name files, decisions, and unresolved questions:
   - **Done**: what changed this session (changes that exist on disk, commits made, tests passing).
   - **Decided**: choices made and why. One line each. Skip if nothing material was decided.
   - **Open**: unresolved questions, blockers, things the user hasn't answered yet.
   - **Next**: what the next agent should pick up first. Be specific: file, function, line if possible.

   Skip empty buckets - don't pad.

2. **Resolve the durable instructions file**:
   - Prefer `AI.md` at the repo root.
   - If root `AI.md` is absent and `instructions/AI.md` exists, use `instructions/AI.md` instead. This is the `ai-dotfiles` repo layout.

3. **Show the summary to the user.** No confirmation prompt - proceed directly to writes.

4. **Append every Decided item to `## Decisions`** in the durable instructions file from step 2 (create the heading if missing - place it just above the `## Cross-agent config` section if that section exists, otherwise at the end). Format:

   ```
   - YYYY-MM-DD: <decision in one line, present tense>
   ```

   If the Decided bucket is empty, skip this step.

5. **Append the session entry to `.ai/journal.md`** in the repo root (create the directory and file if missing). Do NOT write Decided into the journal - Decided lives in `## Decisions` only. The journal holds Done / Open / Next:

   ```
   ## YYYY-MM-DD HH:MM - <agent-name>

   **Done**
   - …

   **Open**
   - …

   **Next**
   - …
   ```

   - Use ISO date and 24h time in the local timezone.
   - `<agent-name>` is the CLI you are running in (`claude-code`, `codex`, `opencode`, or `gemini-cli`). Infer from your runtime.
   - Append at the bottom of the file. Do not rewrite previous entries.
   - Skip empty buckets.

6. **Confirm** in one line: "Sealed. Journal: `<N>` entries. Decisions: `<+M>` added." Nothing more.

## Rules

- Do not invent activity. If a bucket would be empty, omit it.
- Do not include code diffs. The journal is a memory aid, not a log.
- Decided items always go to `## Decisions`, never to the journal. The journal is for in-flight state (Done / Open / Next); the durable instructions file is the single source of truth for decisions.
- If `.ai/journal.md` exists but is malformed, do not "fix" it - just append cleanly below.
