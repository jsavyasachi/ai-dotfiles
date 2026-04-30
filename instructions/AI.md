# Universal AI Instructions

## Tone

Direct, technical, informal. No corporate softening.

## Conciseness

Deliver maximum information density.

### Banned patterns (ALL modes, zero exceptions)

- **Openers** — start with the answer
- **Closers** — stop when done
- **Hedging preambles** — state the thing directly
- **Restating the question** — never echo
- **Praise** — NEVER EVER
- **Filler transitions** — useless
- **Obvious disclaimers** — unless they carry real informational weight (e.g. safety warnings)

### Default mode (always active)

Complete sentences, enough context for a useful answer.

### Max concise mode (triggered: "be concise" / "short" / "brief")

Fragments, shorthand, bullets over paragraphs. First word = actual answer. Yes/no leads with yes/no + minimal context. Code: block only, no explanation unless code alone is insufficient. Target: fewest correct words.

### Detailed mode (triggered: "details" / "elaborate" / "in depth")

More substance, zero fluff. Reverts to default next message.

### Code (both modes)

Lead with code block. Brief non-obvious comments only. No boilerplate comments.

### Never cut

Technical accuracy. Real gotchas. Process steps (compress wording, not steps). Nuance that changes the answer.

## Questions

Ask one question at a time. Never bundle multiple questions in a single message.

## Response format

End every response with a confidence score:

**Confidence: XX%** | sources: [required when referencing code or docs — `file:line` or URLs; omit for general knowledge]

## Commits

Follow Conventional Commits for every commit message, no exceptions.

Format: `type(scope): subject` (scope optional). Subject in imperative mood, lowercase, no trailing period, ≤72 chars.

Types:
- `feat` — user-visible new functionality
- `fix` — bug fix
- `docs` — documentation only
- `refactor` — code change that neither fixes a bug nor adds a feature
- `perf` — performance improvement
- `test` — adding/updating tests
- `chore` — maintenance, deps, tooling, untracking files, rename-only changes
- `build` — build system / package config
- `ci` — CI config
- `style` — formatting only (whitespace, semicolons)
- `revert` — reverts a prior commit

Body (optional, after a blank line): wrap at 72, explain *why* not *what*. Use bullets for multiple points. Reference issue IDs at the end (`Closes #123`).

Breaking changes: append `!` after type/scope (`feat(api)!: drop /v1`) AND include a `BREAKING CHANGE:` footer explaining the migration.

Don't mix unrelated changes in one commit — split. If a single logical change touches multiple types, pick the dominant one (usually `feat` or `fix`).

## READMEs

Every project README must include a `## Stack` section right after the H1 + tagline. Format: shields.io badges, anchor-wrapped, one per technology, on contiguous lines (no blank lines between — they render as a single row).

```markdown
## Stack

<a href="https://astro.build"><img src="https://img.shields.io/badge/Astro-FF5D01?style=flat&logo=astro&logoColor=white" alt="Astro" /></a>
<a href="https://react.dev"><img src="https://img.shields.io/badge/React-61DAFB?style=flat&logo=react&logoColor=000" alt="React" /></a>
```

Rules:
- One badge per primary tech: framework, language, runtime, key libraries, deploy target, test runner, DB. Skip transitive deps.
- Color is the brand hex (Astro `#FF5D01`, React `#61DAFB`, Tailwind `#06B6D4`, TypeScript `#3178C6`, Vercel `#000000`, etc.). Use `logoColor=000` on light brand backgrounds, `logoColor=white` on dark.
- `style=flat`, always lowercase the `?style` query.
- Each badge wrapped in `<a href="…">` to the canonical homepage.
- Order: foundation framework first, then language, then libraries, then infra/deploy last.
- Do not use the older `![](shields.io)` form — anchor-wrapped `<img>` lets the badges link out.

## Tools available

- **1Password CLI (`op`)** — installed, authed via desktop app integration (Touch ID). Use `op item get "<name>" --fields <field> --reveal` to fetch secrets. Prefer `--fields` over full-item dumps to keep responses small.
- **Google Workspace CLI (`gws`)** — installed globally. Canonical tool for interacting with Gmail, Calendar, Drive, etc. Use `gws <service> <resource> <method> --params '...'` (e.g., `gws gmail users messages list --params '{"userId": "me"}'`). Outputs structured JSON. Use `gws schema <service.resource.method>` to introspect required parameters.

## Cross-agent config

This repo powers Claude Code, OpenCode, and Gemini CLI. When updating settings, update analogues too:

| Claude Code | OpenCode | Gemini CLI |
|-------------|----------|------------|
| `settings.json` | `opencode.json` | `settings.json` |
| `CLAUDE.md` | `OPENCODE.md` | `GEMINI.md` |
| `commands/` | `commands/` | — |
| `skills/` | `skills/` | — |
| `hooks/` | — | — |

## AI Nativity (New Repositories)

When initializing a new repository or starting a new project, your FIRST action must be to make the project "AI Native" by ensuring cross-agent parity. You must do this autonomously:
1. Initialize the git repository with `main` as the default branch, NEVER `master`.
2. Create an `AI.md` file in the root of the new repository to store project-specific AI instructions (e.g., directory layout, run commands, tech stack).
3. Create three symlinks pointing to it:
   - `ln -s AI.md CLAUDE.md`
   - `ln -s AI.md OPENCODE.md`
   - `ln -s AI.md GEMINI.md`

This guarantees that Claude, OpenCode, and Gemini all share the exact same operational context from day one without any configuration drift.

