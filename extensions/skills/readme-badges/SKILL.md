---
name: readme-badges
description: Generate or update the README "Stack" section using the AI.md shields.io badge convention. Triggers on "add stack badges", "update the README stack", "make this AI-native" when README work is in scope, on a new repo init where README is being written, and when a README is missing a ## Stack section or has stale badges. Produces anchor-wrapped shields.io badges (one per primary tech, brand hex color, correct logoColor for background, style=flat lowercase, contiguous lines so they render as a single row), in the AI.md ordering: foundation framework -> language -> libraries -> infra/deploy.
allowed-tools: Read Write Edit Glob Grep
---

# readme-badges

Generate the `## Stack` block per the canonical `AI.md` convention. Get it right once, never debug it again.

The rules live in `instructions/AI.md` under `## READMEs`. This skill restates them with enough specifics that an agent doesn't need to re-derive the format every time.

## Workflow

1. **Read the existing README.** Find the `## Stack` section. If missing, insert directly after the H1 + tagline (one-line description below the title). If present, replace its body.

2. **Detect the stack.** Read project manifests:

   | Signal | Tech inferred |
   |---|---|
   | `package.json` `dependencies` / `devDependencies` | JS/TS libs |
   | `package.json` `engines.node` or `.nvmrc` | Node version |
   | `tsconfig.json` | TypeScript |
   | `pyproject.toml` / `requirements.txt` | Python + libs |
   | `Cargo.toml` | Rust + crates |
   | `go.mod` | Go + modules |
   | `Gemfile` | Ruby + gems |
   | `vercel.json` / `.vercel/` | Vercel deploy |
   | `netlify.toml` | Netlify deploy |
   | `Dockerfile` / `compose.yaml` | Docker |
   | `prisma/schema.prisma` | Prisma + DB driver |
   | `next.config.*` | Next.js |
   | `astro.config.*` | Astro |
   | `vite.config.*` | Vite |
   | `tailwind.config.*` / `@tailwindcss/postcss` | Tailwind |
   | `playwright.config.*` | Playwright |
   | `vitest.config.*` / `jest.config.*` | Test runner |

   Skip transitive deps. One badge per primary tech.

3. **Pick the order.** From `AI.md`:

   1. Foundation framework (Next.js, Astro, Rails, Phoenix, Django, etc.)
   2. Language (TypeScript, Python, Rust, Go, Ruby, Elixir)
   3. Libraries (React, Tailwind, Prisma, etc.)
   4. Infra / deploy (Vercel, Netlify, Cloudflare, Docker, etc.) last

4. **Generate each badge.** Exact format:

   ```html
   <a href="<canonical-homepage-url>"><img src="https://img.shields.io/badge/<Label>-<HEX>?style=flat&logo=<slug>&logoColor=<white|000>" alt="<Label>" /></a>
   ```

   - `<HEX>`: brand hex without `#`. Use the official brand color.
   - `<slug>`: simpleicons.org slug, lowercase, no spaces. Matches the brand.
   - `<logoColor>`: `white` on dark brand backgrounds, `000` on light brand backgrounds.
   - `style=flat`, lowercase.
   - `<Label>`: display name. Hyphens in the label must be doubled (`--`) in the URL.

5. **Write the block.** Each `<a>...</a>` on its own line, **no blank lines between them** - blank lines break the single-row rendering on GitHub. Blank line before the block and after.

   ```markdown
   ## Stack

   <a href="https://nextjs.org"><img src="https://img.shields.io/badge/Next.js-000000?style=flat&logo=nextdotjs&logoColor=white" alt="Next.js" /></a>
   <a href="https://www.typescriptlang.org"><img src="https://img.shields.io/badge/TypeScript-3178C6?style=flat&logo=typescript&logoColor=white" alt="TypeScript" /></a>
   <a href="https://react.dev"><img src="https://img.shields.io/badge/React-61DAFB?style=flat&logo=react&logoColor=000" alt="React" /></a>
   <a href="https://tailwindcss.com"><img src="https://img.shields.io/badge/Tailwind-06B6D4?style=flat&logo=tailwindcss&logoColor=white" alt="Tailwind" /></a>
   <a href="https://vercel.com"><img src="https://img.shields.io/badge/Vercel-000000?style=flat&logo=vercel&logoColor=white" alt="Vercel" /></a>
   ```

6. **Report.** What was detected, what badges were emitted, anything skipped (transitive deps, dev-only tooling).

## Brand reference (common picks)

| Tech | HEX | logo slug | logoColor |
|---|---|---|---|
| Next.js | `000000` | `nextdotjs` | `white` |
| Astro | `FF5D01` | `astro` | `white` |
| Nuxt | `00DC82` | `nuxt` | `white` |
| Remix | `000000` | `remix` | `white` |
| SvelteKit | `FF3E00` | `svelte` | `white` |
| Vite | `646CFF` | `vite` | `white` |
| TypeScript | `3178C6` | `typescript` | `white` |
| JavaScript | `F7DF1E` | `javascript` | `000` |
| Python | `3776AB` | `python` | `white` |
| Rust | `000000` | `rust` | `white` |
| Go | `00ADD8` | `go` | `white` |
| Ruby | `CC342D` | `ruby` | `white` |
| Elixir | `4B275F` | `elixir` | `white` |
| Bun | `000000` | `bun` | `white` |
| Node.js | `5FA04E` | `nodedotjs` | `white` |
| React | `61DAFB` | `react` | `000` |
| Vue | `4FC08D` | `vuedotjs` | `white` |
| Svelte | `FF3E00` | `svelte` | `white` |
| Tailwind | `06B6D4` | `tailwindcss` | `white` |
| Prisma | `2D3748` | `prisma` | `white` |
| tRPC | `2596BE` | `trpc` | `white` |
| Drizzle | `C5F74F` | `drizzle` | `000` |
| Playwright | `2EAD33` | `playwright` | `white` |
| Vitest | `6E9F18` | `vitest` | `white` |
| Jest | `C21325` | `jest` | `white` |
| Vercel | `000000` | `vercel` | `white` |
| Netlify | `00C7B7` | `netlify` | `white` |
| Cloudflare | `F38020` | `cloudflare` | `white` |
| Docker | `2496ED` | `docker` | `white` |
| PostgreSQL | `4169E1` | `postgresql` | `white` |
| MySQL | `4479A1` | `mysql` | `white` |
| Redis | `DC382D` | `redis` | `white` |
| SQLite | `003B57` | `sqlite` | `white` |
| MongoDB | `47A248` | `mongodb` | `white` |

When the tech isn't on this list, look up the brand color and the simpleicons.org slug. Don't guess - a wrong color or missing logo silently degrades to a plain badge.

## Anti-patterns

- **The old `![](shields.io)` form.** Use `<a><img></a>` so the badge links out.
- **Blank lines between badges.** They render as separate rows on GitHub. Keep contiguous.
- **Multiple primary frameworks.** Pick the foundation. Don't badge both Next.js and React separately unless React-the-library is genuinely standalone (e.g. a component lib).
- **Transitive deps.** No badges for individual Tailwind plugins, ESLint configs, Prettier, etc.
- **Style variants.** `style=flat` only. No `for-the-badge`, no `plastic`.
- **Uppercase `style=`.** Lowercase the query value.
- **Wrong `logoColor`.** Black-on-black or white-on-white badges look broken. Light brand bg -> `000`, dark brand bg -> `white`.

## Hard rules

- One badge per primary tech.
- Anchor-wrapped `<img>`, never the bare image form.
- `style=flat`, lowercase, every time.
- Contiguous lines (no blank lines between badges).
- Order: framework -> language -> libraries -> infra/deploy.
- Skip if README has no H1 / no tagline yet - ask the user to write those first rather than guess.
