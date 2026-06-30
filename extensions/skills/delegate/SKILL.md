---
name: delegate
description: 'Delegate a well-defined coding task to Codex as a non-interactive subagent. Claude crafts a self-contained prompt from the current plan or context, runs `codex exec` in workspace-write mode, then diffs and reviews the result. Triggers on: "delegate to codex", "have codex implement this", "offload to codex", "let codex do this", "use codex for [task]", "now have codex implement the plan".'
allowed-tools: Bash Read
---

# delegate

Hand off a well-defined task to Codex (`codex exec`), then diff and review the result.

## When to trigger

- "delegate to codex", "have codex implement this", "offload to codex", "let codex do this"
- After producing a plan: "now have codex implement it"
- Any time the task is mechanical and the strategy is already settled

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

For most tasks (write/edit code, write tests, refactor):

```bash
codex exec -s workspace-write "PROMPT"
```

For large prompts (> ~300 words), write to a temp file and pipe:

```bash
cat > /tmp/codex-task.txt << 'EOF'
PROMPT
EOF
codex exec -s workspace-write < /tmp/codex-task.txt
```

Flags:
- `-s workspace-write` - Codex can write files in the project without per-step approval; shell commands still get sandboxed
- Run from the project root (Codex uses cwd as workspace root)
- Codex may take several minutes; use a generous timeout (600000ms / 10 min)

For read-only tasks (review, analysis):

```bash
codex exec -s read-only "PROMPT"
```

### 3. Show the diff

After Codex completes, run:

```bash
git diff
```

If empty, check:

```bash
git diff --cached    # staged but not committed
git status           # untracked files Codex may have created
```

Print the full diff output to the user - do not abbreviate it.

### 4. Review and report

- Compare the diff to what was requested: did Codex do the right thing?
- Flag anything missing, incorrect, or unexpected
- Ask the user: commit as-is, iterate with another `codex exec`, or revert (`git checkout -- .`)
