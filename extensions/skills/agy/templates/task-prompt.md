# agy task: {{ task_id }} - {{ title }}

## Goal

{{ goal }}

## Non-goals

{{ non_goals }}

## Repository context

- Root/worktree: {{ worktree }}
- Branch: {{ branch }}
- Baseline commit: {{ baseline_commit }}
- Applicable instructions: {{ instructions }}
- Existing changes to preserve: {{ existing_changes }}

## Scope

- Allowed files: {{ files_allowed }}
- Forbidden files: {{ files_forbidden }}
- Constraints: {{ constraints }}

## Acceptance and verification

- Acceptance criteria: {{ acceptance }}
- Required red test or baseline evidence: {{ red_test }}
- Commands to run: {{ verification_required }}
- Stop condition: {{ stop_condition }}

## Authorization boundaries

{{ authorization }}

Do not commit, push, deploy, access credentials, use destructive git commands, write outside the
workspace, or use the network unless explicitly authorized above. Do not weaken tests or edit files
outside the allowed scope.

## Final response

End with only this JSON object. It is also enforced by `--json-schema`:

```json
{
  "summary": "string",
  "files_changed": ["string"],
  "tests_run": [
    {"command": "string", "exit_code": 0, "result": "string"}
  ],
  "unresolved_blockers": ["string"]
}
```
