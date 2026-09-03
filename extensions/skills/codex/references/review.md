# Verification and review

Treat agent narration as a claim. Code, diffs, tests, logs, manifests, screenshots, and generated
artifacts are evidence.

## Acceptance review

1. Compare `git diff --name-only` with the allowed files and Codex's reported files.
2. Inspect the full diff for correctness, scope, error paths, dependency changes, generated files,
   and preservation of pre-existing work.
3. For behavior changes, confirm TDD evidence: the new or regression test failed for the intended
   reason before implementation and passes afterward.
4. Independently rerun the required tests, lint, typecheck, build, benchmark, or visual verification.
5. Audit tests for deleted assertions, narrowed cases, new skips, excessive mocking, or special cases
   that hide the original failure.
6. Audit README and agent instructions when behavior, setup, commands, layout, workflows, or
   capabilities changed.
7. Record remaining risks and blockers. Do not translate an unverified claim into a pass.

A failed runnable check clears only when the same relevant command passes after the repair. For a
stochastic check, require the task's defined reproducibility threshold rather than accepting one
lucky pass.

## Independent review

Use a fresh read-only Codex review for substantial, risky, security-sensitive, or cross-cutting
diffs. Review the actual target with `--uncommitted`, `--base`, or `--commit`. Save the review prompt
and output beside the implementation log when durable run state is in use.

Run the reviewer at the strongest listed tier and `high` effort or above, and do not reuse the
implementation session's slug and effort. A rereview by the same model at the same depth tends to
reproduce the original blind spot rather than expose it.

If the orchestrator finds a defect, send the exact finding and evidence to the implementation
session before accepting a repair. Resolve disagreement as one of:

- `consensus`: evidence resolves the issue and both analyses converge.
- `orchestrator_decision`: proceed with recorded rationale, risk, and verification.
- `user_action_required`: product intent, authority, or acceptable risk requires the user.

Agreement between models is not evidence. End open-ended review loops after one scoped repair and
rereview unless new evidence justifies another pass.
