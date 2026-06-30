---
name: clojure-lib-revival
description: 'Revive, modernize, and publish an abandoned Clojure/Leiningen library to Clojars. Triggers on "revive this Clojure lib", "modernize this leiningen project", "adopt/fork an abandoned Clojure library", "publish this to Clojars", "get this old clj lib building on a modern JDK". Loads the phased process (recon, modernize with TDD, CI matrix, self-publish), the per-release polish checklist, the Clojars deploy runbook, and the known gotchas (toArray on JDK11+, Set hashCode, ragel codegen, javac target, sun.misc warnings).'
allowed-tools: Read Write Edit Bash Glob Grep
---

# clojure-lib-revival

A repeatable process for adopting an abandoned Clojure library: prove it builds on
the current toolchain, modernize it, get CI green, and publish to Clojars. Distilled
from reviving `hier-set`, `lein-shell`, `beckon` (+ `beckon-ffm`), and `inet.data`.
Replace `<lib>`, `<you>` (GitHub handle), `<u>` (Clojars username), `<upstream>`.

Good candidates: small (<= a few hundred LOC), clean, clearly-owned, last release
years ago. Most "stale" libs are actually **broken** on modern Java, not merely old.

## Workflow

### Phase 0 - Recon (read-only, before touching anything)

```bash
gh repo fork <upstream>/<lib> --clone=true   # fork + clone + sets upstream remote
java -version; lein --version
cat project.clj                              # version, deps, profiles, :url, :deploy-*
git tag; git log --oneline -5 upstream/master
```

**Most important step: build it as-is.** A failure here is your headline (keystone) bug.
```bash
lein check    # AOT-compiles every ns; surfaces compile errors + reflection warnings
lein test     # may not even compile
```
Map Clojars (`https://clojars.org/<lib>`): who owns the group, last version/date.

**Audit the upstream backlog NOW, not after shipping.** The open issues + PRs are the
spec for what the revival should fix and what features it should carry - skipping this
ships a bare modernization that misses years of asked-for work.
```bash
gh issue list -R <upstream>/<lib> --state open -L 50
gh pr list    -R <upstream>/<lib> --state open -L 50
gh pr view <n> -R <upstream>/<lib> --json title,body,files,additions,deletions  # mine substance
```
Triage each into: (a) **incidentally closed** by your modernization (note it in the PR/CHANGES),
(b) **real un-addressed asks** worth building (features, the most-recent PR's net-new code), or
(c) **out of scope / deferred**. The most recent PR often holds the best ideas (a half-finished
feature, a modular split, a dep family nobody merged). This audit can turn a rename into a
feature-bearing major version - that is the point of a revival vs a fork. (psql-clj: a 7-issue/2-PR
sweep produced a modular 2.0.0 with enum/geography/RDS-IAM that a bare rename would have missed.)

### Phase 1 - Modernize (TDD, one concern per Conventional Commit)

Rename the fork to `main` first (user preference: always `main`, never `master`):
```bash
git branch -m master main && git push -u origin main
gh repo edit <you>/<lib> --default-branch main
git push origin --delete master
```

Then, each step its own commit, **tests before behavior changes**:

1. **Keystone fix** - whatever blocks compiling/running on the current JDK+Clojure
   (see Gotchas).
2. **Characterization + coverage tests** - pin current behavior before changing
   anything, especially code you plan to remove. `lein test` green.
3. **`build:` bump `project.clj`** - latest Clojure default; modern profile matrix
   (`1.10.3 / 1.11.4 / 1.12.x`); point `:url` at the fork; keep
   `:global-vars {*warn-on-reflection* true}`.
4. **`refactor:`** remove dead imports/requires surfaced in recon.
5. **`docs:`** README compatibility line.

Gate per profile: `lein check` shows **0** reflection warnings; `lein all test`
(`:aliases {"all" ["with-profile" "+clojure-1-10:+clojure-1-11:+clojure-1-12"]}`)
is green in every profile.

### Phase 2 - CI (the strongest "maintained again" signal)

Add `.github/workflows/test.yml` - a JDK x Clojure matrix, `fail-fast: false`,
`~/.m2` cached. Replace any dead `.travis.yml`.
```yaml
strategy:
  fail-fast: false
  matrix: {jdk: ['8','11','17','21'], clojure: ['clojure-1-10','clojure-1-11','clojure-1-12']}
steps:
  - uses: actions/checkout@v4
  - uses: actions/setup-java@v4    # {distribution: temurin, java-version}
  - uses: DeLaGuardo/setup-clojure@13.4   # {lein: 2.12.0}
  - uses: actions/cache@v4          # ~/.m2/repository keyed on project.clj
  - run: lein with-profile +${{ matrix.clojure }} test
```
Confirm every cell green:
`gh run view <id> -R <you>/<lib> --json jobs -q '.jobs[]|"\(.name): \(.conclusion)"'`

### Phase 2b - Repo hygiene (do this on EVERY revived repo, not just greenfield)

A fork is still a new repo of yours - it needs the same bootstrap as a fresh one.
Easy to skip because it "already exists"; don't.

- **Community-health files, per-repo (not a shared `.github` defaults repo):**
  `CODE_OF_CONDUCT.md`, `CONTRIBUTING.md`, `SECURITY.md`,
  `.github/ISSUE_TEMPLATE/{bug_report,feature_request}.md`,
  `.github/PULL_REQUEST_TEMPLATE.md`. Copy the canonical set verbatim from a recent
  lib (e.g. `~/projects/stdnum-clj`); only `CONTRIBUTING.md` needs tailoring (lib name,
  build/test commands, module layout). Stay generic - no AI footprint. (Memory:
  `feedback_community-health-files`.)
- **GitHub "About" for discoverability:** description + homepage (cljdoc
  `https://cljdoc.org/d/<group>/<lib>/CURRENT`) + topics.
  `gh repo edit <you>/<lib> --description "..." --homepage "..." --add-topic clojure,clojure-library,<domain-tags>`
  Topic convention: lowercase, always `clojure clojure-library` + 6-8 domain tags.
- **Dependency automation = antq, NOT Renovate** (Renovate has no Leiningen manager;
  Dependabot has no Clojure). Copy `.github/workflows/deps.yml` from a recent lib
  (weekly antq → `peter-evans/create-pull-request`). Mandatory antq flags:
  `--skip=github-action` (token can't push workflow pins) and
  `--exclude org.clojure/clojure` (else it collapses the `:clojure-1-1x` matrix).
  Monorepo: add `--directory <each>` for every `project.clj` and
  `--exclude <your-own-intermodule-coordinate>`. One-time setting:
  `gh api -X PUT repos/<you>/<lib>/actions/permissions/workflow -f default_workflow_permissions=write -F can_approve_pull_request_reviews=true`.
  **Gotcha:** PRs opened by the default `GITHUB_TOKEN` do NOT trigger the test
  workflow (GitHub anti-recursion) - antq dep PRs land with no CI; validate locally
  or push an empty commit before merging. (Memory: `feedback_clojure-dep-automation`.)
- Verify: `gh api repos/<you>/<lib>/contents/CODE_OF_CONDUCT.md` and
  `gh repo view <you>/<lib> --json repositoryTopics`.

### Phase 3 - Publish to Clojars (self-publish fast path = realistic default)

Clojars stopped issuing new vanity group names on 2021-04-18, so the bare `<lib>`
group is gated. Two endgames:

| | A: succession | B: self-publish (default) |
|---|---|---|
| Coordinate | `[<lib> "x"]` (drop-in) | `[net.clojars.<u>/<lib> "x"]` |
| Needs | upstream adds you to the group | nothing (auto-verified) |
| Cost | maintainer cooperation, slow | consumers use the longer coordinate |

**Default to self-publish.** The `net.clojars.<u>` group is **auto-verified, zero
steps** - prefer it. Do NOT use `io.github.<user>` (it needs a `clojars-<username>`
GitHub repo for verification and is fiddly). Set the coordinate to
`net.clojars.<u>/<lib>`, keep the original EPL, credit the original author.

Versioning: a continuation - **minor** bump over the last release (modern-platform
support is a backward-compatible gain). For a library the author started toward
(e.g. `1.0.0-SNAPSHOT`), ship that target version.

Then run the **per-release polish checklist** below, deploy (see
[references/clojars-publish.md](references/clojars-publish.md)), tag, and verify
the POM returns 200.

## Per-release polish checklist

Each of these burned a real release at least once:

- **README badges**: Clojars version badge **and** CI badge.
  `[![Clojars](https://img.shields.io/clojars/v/net.clojars.<u>/<lib>.svg)](https://clojars.org/net.clojars.<u>/<lib>)`
- **Install coordinate in BOTH forms**: Leiningen `[net.clojars.<u>/<lib> "x"]`
  and deps.edn `net.clojars.<u>/<lib> {:mvn/version "x"}`. (The deps.edn form uses
  different syntax - a blind find/replace on the lein form misses it.)
- **Fork attribution** in the license section (preserve the original copyright; add
  a "Maintenance fork (year) by <you>, original: <upstream-url>" line).
- **Run the README example** - upstream examples are often broken (unbalanced parens,
  stale ns forms). Fix and verify.
- **Propagate coordinate/version into LINKED docs** (`doc/DOCUMENTATION.md`, etc.),
  not just the README. A README edit does not reach the file it links to.
- **The Java package name** (e.g. `com.<upstream>.<lib>`) is internal plumbing - it
  does not affect the Clojure namespace consumers `require`, and renaming it is
  invasive churn that strips author attribution. Leave it.
- **Companion packages**: if the repo ships more than one artifact, show **all**
  coordinates and add a badge per package.

## Separate-artifact pattern (newer-JDK features)

When a capability needs a newer JDK than the core's floor - e.g. the Foreign
Function and Memory API (JDK 22) in a library whose core targets JDK 8 - it
**cannot live in the core jar** (a JDK-8 jar can neither compile nor load JDK-22
bytecode). Ship it as a **companion artifact** (`<lib>-ffm`) that depends on core:

- Keep the OS/JDK-specific code in a separate source path, excluded from the core
  build, so the core jar stays on its low JDK floor.
- Core must **release the enabling change** (e.g. an OS-aware reflective selector)
  before the companion can use it - publish core first, then the companion.
- Build/deploy the companion with **JDK 22+** (see the publishing reference for the
  local JDK path).
- A dependent's CI fails "Could not find artifact ... :jar:" until its dependency is
  on Clojars - publish the dependency, then re-run the dependent's CI.

## Gotchas worth grepping for

- **`toArray` won't compile on JDK 11+.** JDK 11 added `Collection.toArray(IntFunction)`,
  making a deftype's single-arg `toArray` ambiguous. Hint both param and return:
  `(^objects toArray [this ^objects a] (.toArray contents a))`.
- **`hashCode` violating the `java.util.Set` contract.** `(hash coll)` != sum of
  element `.hashCode`s. Delegate to the backing collection: `(.hashCode coll)`.
- **ragel codegen.** If the build runs `ragel` to generate parsers, run `ragel -J -o
  <out>.java <grammar>.java.rl` once, **commit the generated Java**, and drop the
  build-time ragel dependency + the `:ragel-source-paths`/`:prep-tasks` entries.
- **EOL `javac -target`.** `1.6`/`1.7` are rejected by modern javac; bump to `8`
  (add `-Xlint:-options` to silence the "obsolete" notice).
- **`sun.misc.*` "internal proprietary API" warnings.** Unavoidable when wrapping
  e.g. `sun.misc.Signal`; silence with `-XDignore.symbol.file` in `:javac-options`.
- **Dead imports/requires**, **phantom `:deploy-branches`** (points at a `stable`
  branch that may exist but be diverged - reconcile or drop before deploy).

## Hard rules

- **No AI footprint in the revival forks**: no `CLAUDE.md`/`AI.md`/`.ai/`, no
  `Co-Authored-By` trailers. Plain Conventional Commits.
- **Commit at every logical stage**; never accumulate uncommitted work across steps.
- **Outward-facing text** (PRs, issues, READMEs) stays terse and human - lead with
  substance, cut praise and parenthetical asides.
- **Never deploy a red build.** Tests green + 0 reflection warnings before publish.
- After publishing, record the lib in the `clojure-libs-revived` memory registry.
