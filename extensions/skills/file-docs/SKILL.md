---
name: file-docs
description: Generate concise sibling .md summary files for source code so future AI sessions can pull context without reading full files. Triggers on "document each file", "add per-file docs", "write file-level summaries", "generate AI context docs", "make AI-friendly docs for this dir", and on any explicit request for sibling-md context files. Walks a target directory, writes <file>.md next to each source file (skipping generated / vendored / lockfile / build-output paths), keeps each summary tight enough that an AI can Read the .md instead of the source. Idempotent: re-running on a clean tree is a no-op.
allowed-tools: Read Write Edit Glob Grep Bash
---

# file-docs

Per-file `.md` summaries built for AI consumption. The point is *not* end-user documentation: the point is letting a future agent Read a 15-line markdown sibling instead of a 400-line source file when it just needs to know what the file does.

This is operationalizing a verbatim user directive: "write up short mds for each file when relevant. concise. so that its easy for ai to pull context without having to process the file each time".

## Workflow

1. **Resolve the target directory.** Default: current working directory. If the user passed `$ARGUMENTS`, use that. If the path is a file, document its parent dir. Reject paths outside the repo unless explicitly approved.

2. **Walk the tree.** Use Glob to enumerate source files. Apply the skip rules below ruthlessly.

3. **For each source file:** check for a sibling `<file>.md`. Skip if it exists and is newer than the source (`stat -f %m` on macOS, `stat -c %Y` on Linux). Otherwise generate it.

4. **Read the source.** Read tool, no offset/limit unless the file is over ~1000 lines.

5. **Write the summary** to `<file>.md` (e.g. `auth.ts` -> `auth.ts.md`, `pricing.py` -> `pricing.py.md`). Use the template below.

6. **Report** count: generated N, refreshed M, skipped K (with one-line reason for each skip class).

## Summary template

Aim for 5-15 lines. Hard cap at 25.

```markdown
# <basename>

**Purpose.** One sentence on what this file does in the system.

**Exports.** Bullet list of public functions/classes/types. Skip private/internal symbols.

**Depends on.** Non-obvious imports - other modules in this repo, external services, env vars, side effects. Skip stdlib and trivial deps.

**Gotchas.** Anything a reader would miss: hidden invariants, ordering requirements, performance traps, "this looks like X but actually does Y" surprises. Skip section if none.
```

Tone: same as the project's other docs. Concise. No filler. No "this file contains..." restating the obvious - lead with what the code *does*.

## Skip rules

Never document:
- Generated files: anything under `dist/`, `build/`, `out/`, `.next/`, `coverage/`, `target/`, `node_modules/`, `__pycache__/`, `.venv/`, `venv/`, `vendor/`.
- Lockfiles: `package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`, `bun.lockb`, `Cargo.lock`, `poetry.lock`, `Gemfile.lock`, `go.sum`.
- Minified/compiled: `*.min.js`, `*.map`, `*.pyc`, `*.class`, `*.o`, `*.a`, `*.so`.
- Binary/media: images, fonts, videos, audio, PDFs.
- Config that is self-documenting: `.gitignore`, `.editorconfig`, `LICENSE`, `tsconfig.json` *unless* it has comments worth surfacing.
- Existing `.md` files (don't document docs).
- Anything under `.git/`, `.ai/`, `.claude/`, `.codex/`, `.gemini/`.

When uncertain, skip and report it in the "skipped" summary rather than generating a hollow doc.

## Per-language guidance

| Language | What to surface in Exports/Depends |
|---|---|
| TypeScript / JavaScript | `export` symbols, default export, re-exports. React components: props shape. |
| Python | `def`/`class` at module level (not nested). `__all__` if defined. Decorators that affect behavior. |
| Go | Capitalized top-level identifiers. Init funcs. Build tags. |
| Rust | `pub` items. `lib.rs` / `mod.rs` module declarations. |
| Ruby | Top-level `class`/`module`/`def`. Concerns. |
| Shell | Functions, `set -e` / `set -u` flags, required env vars. |
| SQL / migrations | What it adds/drops, irreversibility notes, ordering vs other migrations. |

## Idempotency

- A summary is considered current if it exists and its mtime is >= source mtime.
- Use `find <dir> -newer <md>` style checks when batch-detecting stale summaries.
- Re-running with no changes produces zero writes and reports "all current".

## Index file (optional)

When the target dir has more than ~10 documented files, also write a `<dir>/_index.md` listing each file with its purpose line. This lets an agent glance at one file instead of `ls`-ing the dir. Only generate `_index.md` if the user asks for "add an index" or "generate index", to keep the default invocation cheap.

## Anti-patterns

- **Don't paraphrase the code.** If the summary reads like "this function takes X and returns Y" for every export, you're producing noise.
- **Don't include line numbers.** They rot fast and the agent can grep.
- **Don't include the full signature** of every function. Names + one-line purpose is enough.
- **Don't write summaries longer than the source file.** If the file is 8 lines, skip it.
- **Don't quote the source.** No code fences in summaries unless a single ~3-line pattern is genuinely the clearest explanation.

## Hard rules

- One summary file per source file. No combined summaries.
- No-op when nothing is stale. Report and exit.
- Never overwrite a `.md` that wasn't generated by this skill (heuristic: if the file lacks the `<basename>` H1 + structure, ask before overwriting).
- Default scope is the target dir, non-recursive, unless the user says "recursively" or "the whole tree".
