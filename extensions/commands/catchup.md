---
description: Re-orient on this repo by replaying the last N session-handoff entries plus durable AI.md decisions
---

You are catching the user up on a repo they (or a different agent) worked on previously. Goal: a tight briefing that ends with the user knowing where to pick up.

## Argument

The user may pass an argument after `/catchup` - interpret it as how many recent journal entries to replay.
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

3. **Reality-check Open and Next items** from the last N entries before showing them. For each bullet, extract the named artifacts (file paths, command names, skill names, commit refs, PR numbers, flag keys) and verify against the current repo:
   - File path mentioned → does the file exist? (Read / `ls`)
   - Command, skill, or flag named → does it exist now? (grep the relevant config or commands dir)
   - Commit ref or PR named → has it landed? (`git log`, `gh pr view`)
   - Renaming evident (journal says `/foo`, repo has `/bar` doing the same job) → flag as stale.

   Tag each item:
   - `[resolved]` - artifact exists / commit landed / question answered by `## Decisions`
   - `[stale: <reason>]` - renamed, superseded, or no longer matches reality
   - `[still open]` - matches reality, unresolved

   Drop `[resolved]` items unless they're load-bearing context for a still-open item.

4. **Synthesize a recap** from the surviving items:
   - Lead with the most recent timestamp and agent: "Last touched <date> by <agent>."
   - Merge bullets across entries - collapse duplicates.
   - Surface `[still open]` and `[stale]` items. Stale items are useful because they show drift the user may not know about.
   - Highlight the most recent **Next** that is still open - that's the resume point.
   - If `## Decisions` in AI.md contains anything from the journal window, mention it as "(durable)".

5. **Format** as four short sections, in this order (skip any that are empty):

   ```
   **Last session(s)**
   <one-line context: date, agent, headline>

   **Decided (durable)**
   - …

   **Still open**
   - … [still open]
   - … [stale: <reason>]

   **Pick up at**
   - …
   ```

   Stop after the last section. Do not append a closing question or prompt.

## Rules

- Be terse. The user is re-entering, not reading a postmortem.
- If the latest journal entry is older than 14 days, prefix the recap with: "Last entry is <X> days old - context may be stale."
- The reality-check in step 3 is required, not optional. Replaying stale Open/Next items as-if-still-true is the failure mode this command exists to prevent.
- Beyond the reality-check probes in step 3, do not read other files in the repo. The journal and durable instructions file are the contract. If the user wants deeper grounding, they'll ask.
- Do not run `/handoff` automatically afterwards.
