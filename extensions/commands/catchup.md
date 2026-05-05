---
description: Re-orient on this repo by replaying the last N session-handoff entries plus durable AI.md decisions
---

You are catching the user up on a repo they (or a different agent) worked on previously. Goal: a tight briefing that ends with the user knowing where to pick up.

## Argument

The user may pass an argument after `/catchup` — interpret it as how many recent journal entries to replay.
- No argument: default to `1` (last entry only).
- An integer (e.g. `3`): last N entries.
- The literal string `all`: every entry.
- Anything else: default to `1` and note the fallback in your output.

## Steps

1. **Read `.ai/journal.md`** at the repo root. If it does not exist or is empty, say exactly:
   > No journal in this repo. Run `/handoff` at the end of a session to start one.
   Then stop. Do not fabricate a recap.

2. **Resolve the durable instructions file**, then read its `## Decisions` section if present:
   - Prefer `AI.md` at the repo root.
   - If root `AI.md` is absent and `instructions/AI.md` exists, use `instructions/AI.md` instead. This is the `ai-dotfiles` repo layout.
   - If neither exists, continue without durable decisions.

   Durable decisions supersede stale Open/Next items in the journal.

3. **Synthesize a recap** from the last N journal entries:
   - Lead with the most recent timestamp and agent: "Last touched <date> by <agent>."
   - Merge bullets across entries — collapse duplicates, drop Done items unless they're load-bearing for an Open or Next item.
   - Surface any Open items that are *still open* (not contradicted by a later Decided or by `## Decisions` in `AI.md`).
   - Highlight the most recent **Next** — that's the resume point.
   - If `## Decisions` in AI.md contains anything from the journal window, mention it as "(durable)".

4. **Format** as four short sections, in this order (skip any that are empty):

   ```
   **Last session(s)**
   <one-line context: date, agent, headline>

   **Decided (durable)**
   - …

   **Still open**
   - …

   **Pick up at**
   - …
   ```

5. **End with exactly one line:**
   > what's the move?

## Rules

- Be terse. The user is re-entering, not reading a postmortem.
- If the latest journal entry is older than 14 days, prefix the recap with: "⚠ Last entry is <X> days old — context may be stale." (No emoji elsewhere.)
- Do not read other files in the repo as part of /catchup. The journal and durable instructions file are the contract. If the user wants deeper grounding, they'll ask.
- Do not run `/handoff` automatically afterwards. Stop after the "what's the move?" line.
