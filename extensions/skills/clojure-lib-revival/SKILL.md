---
name: clojure-lib-revival
description: 'Revive, modernize, and publish an abandoned Clojure library to Clojars as deps.edn-native (deps.edn + tools.build the source of truth; Leiningen kept as a bonus via lein-tools-deps). Triggers on "revive this Clojure lib", "modernize this leiningen project", "make this clj lib deps-native", "convert project.clj to deps.edn", "adopt/fork an abandoned Clojure library", "publish this to Clojars", "get this old clj lib building on a modern JDK". Loads the phased process (recon, modernize with TDD, deps-native build emit, CI matrix, self-publish), the per-release polish checklist, the Clojars deploy runbook, and the known gotchas (toArray on JDK11+, Set hashCode, ragel codegen, javac target, sun.misc warnings).'
allowed-tools: Read Write Edit Bash Glob Grep
---

# clojure-lib-revival

A repeatable process for adopting an abandoned Clojure library: prove it builds on
the current toolchain, modernize it, ship it **deps.edn-native** (`deps.edn` +
`build.clj`/tools.build the source of truth, Leiningen kept as a bonus via a
`lein-tools-deps` shim), get CI green, and publish to Clojars. Distilled from
reviving `hier-set`, `lein-shell`, `beckon` (+ `beckon-ffm`), and `inet.data`.
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
Abandoned libs arrive as Leiningen projects, so recon uses lein (you migrate to
deps-native in Phase 1):
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
3. **`build:` go deps-native** - emit `deps.edn` + `build.clj` + `tests.edn` and demote
   `project.clj` to a `lein-tools-deps` shim (see **Deps-native build** below for exact
   shapes). `deps.edn` becomes the source of truth; Leiningen keeps working as a bonus.
   Set `*warn-on-reflection*` per-file (`(set! *warn-on-reflection* true)`) - deps.edn
   has no `:global-vars`.
4. **`refactor:`** remove dead imports/requires surfaced in recon.
5. **`docs:`** README compatibility line.

Gate: `clojure -M:test` is green with **0** reflection warnings, and the CI-matrix
aliases `clojure -M:1.11:test` / `clojure -M:1.12:test` both resolve and pass. Prove
the bonus path too: `lein test` (via the shim, reading `deps.edn`) is green.

### Deps-native build (the standard output)

Every revived lib ships **`deps.edn` + `build.clj` + `tests.edn`**, with `project.clj`
demoted to a `lein-tools-deps` shim. Golden references in `~/projects`: `jose-clj` /
`openai-clj` (plain), any Java lib (`inet.data`, `clj-xchart`) for the `javac` variant.

1. **`deps.edn`** - `:paths ["src" "resources"]`; `:deps` = the old `:dependencies`;
   `:aliases`:
   - `:test` - `:extra-paths ["test"]`, `lambdaisland/kaocha` + `org.slf4j/slf4j-nop`
     + any test-only deps, `:main-opts ["-m" "kaocha.runner"]`.
   - `:1.11` / `:1.12` - `{:override-deps {org.clojure/clojure {:mvn/version "..."}}}`
     for the CI matrix (`clojure -M:1.11:test`). Keep a `:1.10` too if the lib still
     supports it.
   - `:build` - `{:deps {io.github.clojure/tools.build {...} slipset/deps-deploy {...}}
     :ns-default build}`.
2. **`build.clj`** - `(def lib 'net.clojars.<u>/<lib>)`, `version` (continuation minor
   bump), `clean`/`jar`/`deploy`. `b/write-pom` carries `:pom-data` with **description +
   url + the repo's actual license** (forks preserve the *upstream* license, not EPL)
   and `:scm` (`github.com/<you>/<lib>`, `:tag (str "v" version)`). **Java/AOT libs add
   `b/javac`** (and `b/compile-clj` for `:aot`) before `b/jar` - the plain template does
   NOT compile Java, so its jar would ship without the `.class` files.
3. **`tests.edn`** - `#kaocha/v1`. Replace lein `:test-selectors` with kaocha meta:
   an integration-gated suite becomes `{:tests [{:id :unit :skip-meta [:integration]}]}`
   so `clojure -M:test` runs unit-only and `^:integration` tests run on demand.
4. **`project.clj` shim (lein-as-a-bonus)** - deps resolve from `deps.edn`, zero drift:
   ```clojure
   (defproject net.clojars.<u>/<lib> "<version>"
     :plugins [[lein-tools-deps "0.4.5"]]
     :middleware [lein-tools-deps.plugin/resolve-dependencies-with-deps-edn]
     :lein-tools-deps/config {:config-files [:install :user :project]})
   ```
   **Exception - Leiningen plugins** (e.g. `lein-shell`): a plugin's runtime *is*
   Leiningen (`:eval-in-leiningen true`), so it **stays lein-first** - `project.clj`
   remains the real build; a `deps.edn` there would only serve REPL/test, not publish.

### Phase 2 - CI (the strongest "maintained again" signal)

Three clojure-native workflows (golden copies in `~/projects/openai-clj/.github/workflows/`):

- **`test.yml`** - JDK x Clojure matrix, `fail-fast: false`, `~/.m2` cached on `deps.edn`.
  Replace any dead `.travis.yml`.
  ```yaml
  strategy:
    fail-fast: false
    matrix: {jdk: ['17','21'], clojure: ['1.11','1.12']}
  steps:
    - uses: actions/checkout@v4
    - uses: actions/setup-java@v4    # {distribution: temurin, java-version}
    - uses: DeLaGuardo/setup-clojure@13.4   # {cli: latest}
    - uses: actions/cache@v4          # ~/.m2/repository keyed on deps.edn
    - run: clojure -M:${{ matrix.clojure }}:test
  ```
- **`release.yml`** - on tag `v*`: verify the tag matches `build.clj` version, run
  `clojure -M:test`, then `clojure -T:build deploy` (Clojars creds from secrets), then a
  GitHub Release.
- **`deps.yml`** - antq weekly (reads `deps.edn` natively; see Phase 2b).

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
  Monorepo: add `--directory <each>` for every module's `deps.edn` and
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

Then run the **per-release polish checklist** below, deploy with
`clojure -T:build deploy` (or push a `v*` tag to let `release.yml` do it; see
[references/clojars-publish.md](references/clojars-publish.md)), tag, and verify
the POM returns 200.

## Per-release polish checklist

Each of these burned a real release at least once:

- **README badges**: Clojars version badge **and** CI badge.
  `[![Clojars](https://img.shields.io/clojars/v/net.clojars.<u>/<lib>.svg)](https://clojars.org/net.clojars.<u>/<lib>)`
- **Install coordinate in BOTH forms, deps.edn first**: deps.edn
  `net.clojars.<u>/<lib> {:mvn/version "x"}` (primary) and Leiningen
  `[net.clojars.<u>/<lib> "x"]` (the shim keeps this working). The deps.edn form uses
  different syntax - a blind find/replace on the lein form misses it.
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
  (add `-Xlint:-options` to silence the "obsolete" notice). In deps-native builds these
  flags go in `build.clj` via `b/javac`'s `:javac-opts`, not project.clj `:javac-options`.
- **`sun.misc.*` "internal proprietary API" warnings.** Unavoidable when wrapping
  e.g. `sun.misc.Signal`; silence with `-XDignore.symbol.file` in `b/javac`'s
  `:javac-opts` (build.clj).
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
