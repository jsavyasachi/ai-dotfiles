model = "gpt-5.4"
model_reasoning_effort = "medium"

[features]
codex_hooks = true

[tui]
status_line = ["model-with-reasoning", "current-dir", "run-state", "context-used", "five-hour-limit", "weekly-limit", "context-window-size", "task-progress"]

# Let Codex treat AI-native repos as instruction-bearing repos without
# forcing an AGENTS.md file in every project.
project_doc_fallback_filenames = ["AI.md"]

[[hooks.Stop]]
[[hooks.Stop.hooks]]
type = "command"
command = "bash @@DOTFILES_DIR@@/scripts/dirty-tree-check.sh"
timeout = 10
