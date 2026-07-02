---
name: delegate
description: 'Delegate a well-defined coding task to Codex as a non-interactive subagent. Claude crafts a self-contained prompt from the current plan or context, runs `codex exec` in workspace-write mode, then diffs and reviews the result. Triggers on: "delegate to codex", "have codex implement this", "offload to codex", "let codex do this", "use codex for [task]", "now have codex implement the plan", "have codex review this", "let codex write tests".'
allowed-tools: Bash Read
---

# delegate

Hand off a well-defined task to Codex (`codex exec`), then diff or display and review the result.

## When to trigger

- **Implement**: "delegate to codex", "have codex implement this", "offload to codex", "now have codex implement the plan"
- **Review**: "have codex review this", "let codex review the diff", "codex review"
- **Tests**: "have codex write tests for X", "let codex add tests"
- **Refactor/docs/migrations**: any mechanical task where the approach is already settled

## Steps

### 1. Synthesize the Codex prompt

Distill everything Codex needs into one self-contained instruction block. Codex starts
cold - no memory of this conversation, no access to your plan context.

Include:
- **What to do** - the specific task (implement X, write tests for Y, refactor Z)
- **Which files are in scope** - list them explicitly or describe how to find them
- **Constraints** - naming conventions, test runner, framework version, style rules
- **Definition of done** - what passing looks like (tests green, no type errors, etc.)

Do NOT reference "our conversation", "as discussed", or "the plan above".

### 2. Run Codex

**Write tasks** (implement, refactor, tests, docs, migrations):

```bash
codex exec -s workspace-write "PROMPT"
```

For large prompts (> ~300 words), pipe via stdin:

```bash
cat > /tmp/codex-task.txt << 'EOF'
PROMPT
EOF
codex exec -s workspace-write < /tmp/codex-task.txt
```

- `-s workspace-write` - Codex writes files without per-step approval; shell commands still sandboxed
- Run from the project root
- Codex may take several minutes; use a 10-min timeout (600000ms)
- Output streams in real-time through the Bash tool as Codex works
- Codex runs in a separate process: its internal tool calls, file reads, and reasoning do NOT land in Claude's context window - only the final stdout (diff or review) does
- Add `--json` for a JSONL event stream instead of formatted output (useful for programmatic parsing)

**Code review** (dedicated subcommand, reviews current repo diff):

```bash
codex exec review
```

Or with a focused prompt for a specific concern:

```bash
codex exec -s read-only "Review the changes in git diff HEAD. Focus on: SPECIFIC_CONCERN"
```

### 3. Show results

For write tasks, show the diff after Codex completes:

```bash
git diff
```

If empty, check:

```bash
git diff --cached    # staged but not committed
git status           # untracked files Codex may have created
```

Print the full diff output to the user - do not abbreviate it.

For review tasks, print Codex's review output in full.

### 4. Review and report

- Compare result to what was requested: did Codex do the right thing?
- Flag anything missing, incorrect, or unexpected
- For write tasks, ask: commit as-is, iterate with another `codex exec`, or revert (`git checkout -- .`)
