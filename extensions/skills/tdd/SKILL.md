---
name: tdd
description: Enforce test-driven development on any code change. Triggers on "implement X", "add feature Y", "fix the bug in Z", "write a function that...", "build the X endpoint", "port this from A to B", "refactor Z", and on any request that produces new behavior or modifies existing behavior. Loads the red/green/refactor loop, picks the right test runner from package.json / pyproject.toml / Cargo.toml / go.mod / Gemfile / mix.exs, recognizes the AI.md skip-list (renames, formatting, dep bumps, spikes, UI animation, shell glue), and reminds the agent to write the failing test first.
allowed-tools: Read Write Edit Bash Glob Grep
---

# tdd

Test-driven development as a procedure, not a vibe. This skill exists because `AI.md` mandates TDD with zero exceptions and that rule gets skipped under pressure. Restating it loads the procedure into the active context so the agent doesn't drift.

## Workflow

1. **Classify the change.** Pick the smallest matching category:

   | Category | TDD applies? | Pattern |
   |---|---|---|
   | New feature / new behavior | Yes | Red test -> implement -> refactor |
   | Bug fix | Yes | Regression test that reproduces the bug first |
   | Refactor with existing coverage | Yes (existing tests are the spec) | Tests stay green throughout |
   | Refactor with thin coverage | Yes | Backfill tests first, then refactor |
   | Port / rewrite | Yes | Port the test suite first, then make impl pass |
   | Rename / formatting / dep bump | No (skip) | Mechanical edit |
   | Throwaway exploration spike | No (skip) | Note it as a spike; add tests after if kept |
   | UI animation, interactive prompts, shell glue | No (skip) | Inherently hard to test; add coverage where possible |

   If category is ambiguous, default to "TDD applies". The cost of writing a test you didn't strictly need is small; the cost of an untested change is the bug it lets through.

2. **Detect the test runner.** Read the manifest, pick the canonical command:

   | Signal | Test command |
   |---|---|
   | `package.json` `scripts.test` | `npm test` (or `pnpm test` / `bun test` / `yarn test` by lockfile) |
   | `package.json` with `vitest` dep | `npx vitest run` |
   | `package.json` with `jest` dep | `npx jest` |
   | `pyproject.toml` with `[tool.pytest]` | `pytest` |
   | `pyproject.toml` with `[tool.poetry]` + pytest dev-dep | `poetry run pytest` |
   | `Cargo.toml` | `cargo test` |
   | `go.mod` | `go test ./...` |
   | `Gemfile` + `spec/` | `bundle exec rspec` |
   | `Gemfile` + `test/` | `rails test` or `rake test` |
   | `mix.exs` | `mix test` |
   | `deno.json` | `deno test` |

   If none match or the runner isn't configured, **ask the user** where tests live and how to run them. Do not invent a runner.

3. **Write the test first.** Pick the test file path that matches project conventions (mirror source dir, or `tests/`, or `__tests__/`, or alongside source - check existing tests). Write the smallest test that captures the intended behavior or reproduces the bug.

4. **Run the test. See it fail.** This is non-negotiable - a test that passes before implementation either tests nothing or you're testing existing behavior. Confirm the failure message matches the expected reason (assertion failure, not import error, unless that's the expected first step).

5. **Implement the minimum code** to make the test pass. Resist adding adjacent features.

6. **Run the test. See it pass.** Then run the broader suite to confirm no regressions.

7. **Refactor.** With the test as a safety net, clean up the implementation. Re-run after each meaningful change.

8. **Commit.** Per `AI.md` cadence, one Conventional Commit per logical task. The test and implementation can go in one commit (`feat(scope): add X with tests`) or two (`test(scope): cover X` + `feat(scope): implement X`) - prefer one unless the test alone is a meaningful artifact.

## Red-test discipline

A test that "fails" because of a typo, a missing import, or a missing file is not a red test - it's an error. A real red test:

- Compiles / parses cleanly.
- Asserts on the *intended* behavior.
- Fails with the assertion message you expected (`expected 7, got 0`), not `ModuleNotFoundError` or `SyntaxError`.

If you can't get to a clean assertion failure, fix the test setup before treating the cycle as red.

## Bug-fix discipline

The regression test must:

1. Exist *before* the fix.
2. Reproduce the bug exactly - same inputs, same observed wrong behavior.
3. Fail on the buggy code with the assertion describing the bug.
4. Pass on the fix.

If the test passes on buggy code, you haven't reproduced the bug - keep refining until it fails. A green test on buggy code means future regressions of this exact bug will still slip through.

## Port / rewrite discipline

Port the test suite *first*. The tests are the spec - they define what the new implementation must do. Work module-by-module:

1. Port one module's tests.
2. Stub the impl until tests compile.
3. Implement until tests pass.
4. Move to the next module.

Do not port all tests first then all impl - red/green cycles get too long and design mistakes compound.

## Skip-list (verbatim from `AI.md`)

Skip TDD only for:
- Pure mechanical edits: renames, formatting, dependency bumps.
- Throwaway exploration spikes (note as a spike; add tests after if kept).
- Code inherently hard to test in isolation: UI animation, interactive prompts, shell glue.

When skipping, prefer adding a test after rather than no test at all. Document the skip reason in the commit body.

## Anti-patterns

- **Writing tests after the implementation.** Defeats the design feedback loop and tends to retrofit assertions to existing behavior rather than intended behavior.
- **Tests that mock everything.** A test that mocks the SUT's dependencies and asserts the mocks were called is testing the mock framework, not the code.
- **Tests that mock the database in integration tests** (per the user's standing feedback: mock/prod divergence has burned them before; integration tests hit a real DB).
- **One mega-test per feature.** Split by behavior - each test names one assertion.
- **Skipping the failure check.** "I'm sure it would have failed" - run it. Cheap insurance.
- **Coupling tests to implementation details.** Test behavior, not internals. Refactors should change impl without touching tests.

## Hard rules

- No code without a test that exercises it (modulo the skip-list).
- No "I'll add tests later." Later is now.
- No merging a red suite. If a test breaks during your work, fix it before moving on.
- No `--no-verify`, no `xfail`-ing your own new tests to ship faster.
- Bug fixes get a regression test or the bug is not fixed.
