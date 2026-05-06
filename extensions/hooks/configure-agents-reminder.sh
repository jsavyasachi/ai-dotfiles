#!/usr/bin/env bash
# PreToolUse hook: nudge the model to invoke /configure-agents before editing
# cross-agent infra in the ai-dotfiles repo. Non-blocking - prints a reminder
# via systemMessage (user-visible) and additionalContext (model-visible),
# then exits 0 so the tool call proceeds.
set -euo pipefail

input="$(cat)"
file_path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')"
[[ -z "$file_path" ]] && exit 0

case "$file_path" in
  */ai-dotfiles/extensions/*|\
  */ai-dotfiles/config/*|\
  */ai-dotfiles/setup.sh|\
  */ai-dotfiles/instructions/AI.md)
    msg="Editing cross-agent infra (\`$file_path\`). Have you invoked /configure-agents to validate the change against current Claude/OpenCode/Gemini/Codex docs? If not, do that first."
    jq -n --arg m "$msg" '{
      systemMessage: $m,
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        additionalContext: $m
      }
    }'
    ;;
esac
