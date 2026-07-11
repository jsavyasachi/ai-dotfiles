# Parallel Codex sessions

Parallelize only independent tasks. Prefer parallel read-only investigations. For write tasks,
require separate worktrees and explicit file claims.

Before dispatch:

1. Give each task a unique id, branch, worktree, goal, allowed files, and verification command.
2. Reject overlapping file claims, shared lockfiles, shared generated artifacts, or mutable shared
   state unless execution is serialized.
3. Check relevant scarce resources: ports, dev servers, databases, Docker containers, disk, build
   directories, and GPU/CPU capacity when applicable.
4. Define integration order and the final repository-level verification.

Do not run concurrent writers against the same worktree. Do not let the orchestrator edit files an
active Codex task owns. Wait for completion or record a serialized handoff first.

After each task completes, review and verify it independently before integration. Integrate in the
defined order, resolve conflicts deliberately, then run the combined test suite. If tasks share a
contract or repeatedly conflict, stop parallel execution and continue sequentially.
