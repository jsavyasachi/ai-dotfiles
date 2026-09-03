# Verification and review

Treat agent narration as a claim. Code, diffs, tests, logs, manifests, screenshots, and generated
artifacts are evidence. With `agy` this is not a stylistic preference: a run whose every tool call was
auto-denied still reports `"status": "SUCCESS"`, so the result object alone can never establish that
work happened.

## Acceptance review

1. Confirm the run actually did something: non-empty `response`, no auto-denial notice on stderr, and
   a `git status --short` that changed when the task was a write.
2. Compare `git diff --name-only` with the allowed files and the reported `files_changed`.
3. Inspect the full diff for correctness, scope, error paths, dependency changes, generated files,
   and preservation of pre-existing work.
4. For behavior changes, confirm TDD evidence: the new or regression test failed for the intended
   reason before implementation and passes afterward.
5. Independently rerun the required tests, lint, typecheck, build, benchmark, or visual verification.
6. Audit tests for deleted assertions, narrowed cases, new skips, excessive mocking, or special cases
   that hide the original failure.
7. Audit README and agent instructions when behavior, setup, commands, layout, workflows, or
   capabilities changed.
8. Record remaining risks and blockers. Do not translate an unverified claim into a pass.

A failed runnable check clears only when the same relevant command passes after the repair. For a
stochastic check, require the task's defined reproducibility threshold rather than accepting one
lucky pass.

## Independent review

`agy` has no review subcommand. Run the reviewer as a fresh `--mode plan` session against an explicit
target: the uncommitted diff, a diff against a base branch, or a commit range. Write the diff to a
file and reference it in the prompt rather than pasting it inline. Save the review prompt and output
beside the implementation log when durable run state is in use.

Run the reviewer at a stronger tier than the implementation session and do not reuse its slug and
effort. A rereview by the same model at the same depth tends to reproduce the original blind spot
rather than expose it. The catalog spans vendors, so a genuinely independent reviewer is available:
prefer a different model family from the implementer.

If the orchestrator finds a defect, send the exact finding and evidence to the implementation
session before accepting a repair. Resolve disagreement as one of:

- `consensus`: evidence resolves the issue and both analyses converge.
- `orchestrator_decision`: proceed with recorded rationale, risk, and verification.
- `user_action_required`: product intent, authority, or acceptable risk requires the user.

Agreement between models is not evidence. End open-ended review loops after one scoped repair and
rereview unless new evidence justifies another pass.
