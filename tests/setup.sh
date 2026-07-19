#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASH_BIN="$(command -v bash)"
BASE_PATH="/usr/bin:/bin:/usr/sbin:/sbin"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_exists() {
  local path="$1"
  [[ -e "$path" || -L "$path" ]] || fail "expected path to exist: $path"
}

assert_file_contains() {
  local path="$1"
  local pattern="$2"
  grep -Fq "$pattern" "$path" || fail "expected '$pattern' in $path"
}

assert_symlink_target() {
  local path="$1"
  local expected="$2"
  [[ -L "$path" ]] || fail "expected symlink: $path"
  local actual
  actual="$(readlink "$path")"
  [[ "$actual" == "$expected" ]] || fail "expected $path -> $expected, got $actual"
}

assert_eq() {
  local actual="$1"
  local expected="$2"
  local message="$3"
  [[ "$actual" == "$expected" ]] || fail "$message (expected '$expected', got '$actual')"
}

run_setup() {
  local home_dir="$1"
  HOME="$home_dir" XDG_CONFIG_HOME="$home_dir/.config" PATH="$BASE_PATH" "$BASH_BIN" "$REPO_ROOT/setup.sh"
}

ghostty_config_path() {
  local home_dir="$1"
  if [[ "$(uname -s)" == "Darwin" ]]; then
    printf '%s' "$home_dir/Library/Application Support/com.mitchellh.ghostty/config.ghostty"
  else
    printf '%s' "$home_dir/.config/ghostty/config.ghostty"
  fi
}

test_fresh_install() {
  local home_dir
  home_dir="$(mktemp -d /tmp/ai-dotfiles-test-fresh.XXXXXX)"

  local output
  output="$(run_setup "$home_dir")"

  assert_symlink_target "$home_dir/.claude/CLAUDE.md" "$REPO_ROOT/instructions/CLAUDE.md"
  assert_symlink_target "$home_dir/.config/opencode/OPENCODE.md" "$REPO_ROOT/instructions/OPENCODE.md"
  assert_symlink_target "$home_dir/.gemini/GEMINI.md" "$REPO_ROOT/instructions/GEMINI.md"
  assert_symlink_target "$home_dir/.codex/AGENTS.md" "$REPO_ROOT/instructions/AGENTS.md"
  [[ ! -e "$home_dir/.agents/skills" ]] || fail "legacy ~/.agents/skills should not be created"

  assert_file_contains "$home_dir/.claude/settings.json" '"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"'
  assert_file_contains "$home_dir/.claude/settings.json" '"terminalProgressBarEnabled": true'
  assert_file_contains "$home_dir/.claude/settings.json" '"preferredNotifChannel": "ghostty"'
  assert_file_contains "$home_dir/.claude/settings.json" '"Stop"'
  assert_file_contains "$home_dir/.claude/settings.json" "bash $home_dir/.claude/dirty-tree-check.sh"
  assert_symlink_target "$home_dir/.claude/dirty-tree-check.sh" "$REPO_ROOT/scripts/dirty-tree-check.sh"
  assert_file_contains "$home_dir/.config/opencode/opencode.json" '"instructions": ["'"$home_dir"'/.config/opencode/OPENCODE.md"]'
  assert_file_contains "$home_dir/.config/opencode/opencode.json" '"model": "ollama/qwen2.5-coder:14b"'
  assert_file_contains "$home_dir/.config/opencode/opencode.json" '"baseURL": "http://localhost:11434/v1"'
  assert_file_contains "$home_dir/.codex/config.toml" 'project_doc_fallback_filenames = ["AI.md"]'
  assert_file_contains "$home_dir/.codex/config.toml" 'hooks = true'
  assert_file_contains "$home_dir/.codex/config.toml" '[[hooks.Stop]]'
  assert_file_contains "$home_dir/.codex/config.toml" "bash $REPO_ROOT/scripts/dirty-tree-check.sh"
  assert_file_contains "$home_dir/.tmux.conf" '# >>> ai-dotfiles managed: tmux AI transport'
  assert_file_contains "$home_dir/.tmux.conf" 'set -g allow-passthrough on'
  assert_file_contains "$(ghostty_config_path "$home_dir")" '# >>> ai-dotfiles managed: ghostty AI sessions'
  assert_file_contains "$(ghostty_config_path "$home_dir")" 'progress-style = true'
  assert_file_contains "$(ghostty_config_path "$home_dir")" 'desktop-notifications = true'
  assert_eq "$(printf '%s' "$output" | tail -n 1)" 'Done. AI agent settings are live.' "fresh install summary mismatch"
}

test_local_models() {
  local home_dir
  home_dir="$(mktemp -d /tmp/ai-dotfiles-test-local-models.XXXXXX)"

  local output
  output="$(run_setup "$home_dir")"

  assert_file_contains <(printf '%s\n' "$output") 'Ollama unavailable; install it from https://ollama.com/download'
  assert_eq "$(printf '%s' "$output" | tail -n 1)" 'Done. AI agent settings are live.' "local models summary mismatch"
}

test_idempotent_rerun() {
  local home_dir
  home_dir="$(mktemp -d /tmp/ai-dotfiles-test-rerun.XXXXXX)"

  run_setup "$home_dir" >/dev/null

  local output
  output="$(run_setup "$home_dir")"

  assert_file_contains "$home_dir/.codex/config.toml" '# >>> ai-dotfiles managed: codex config'
  assert_eq "$(grep -c '^# >>> ai-dotfiles managed: codex config$' "$home_dir/.codex/config.toml")" "1" "managed codex block duplicated"
  assert_eq "$(printf '%s' "$output" | tail -n 1)" 'Nothing to do - already up to date.' "rerun summary mismatch"
}

test_codex_merge_preserves_local_state() {
  local home_dir
  home_dir="$(mktemp -d /tmp/ai-dotfiles-test-merge.XXXXXX)"

  mkdir -p "$home_dir/.codex"
  cat > "$home_dir/.codex/config.toml" <<'EOF'
model = "gpt-5.4"
model_reasoning_effort = "medium"
[projects."/tmp/example"]
trust_level = "trusted"
EOF

  run_setup "$home_dir" >/dev/null

  assert_file_contains "$home_dir/.codex/config.toml" 'model = "gpt-5.4"'
  assert_file_contains "$home_dir/.codex/config.toml" 'trust_level = "trusted"'
  assert_file_contains "$home_dir/.codex/config.toml" 'project_doc_fallback_filenames = ["AI.md"]'
  assert_eq "$(grep -c '^# >>> ai-dotfiles managed: codex config$' "$home_dir/.codex/config.toml")" "1" "managed codex block duplicated after merge"
}

test_terminal_merges_preserve_local_state() {
  local home_dir
  home_dir="$(mktemp -d /tmp/ai-dotfiles-test-terminal-merge.XXXXXX)"
  local ghostty_config
  ghostty_config="$(ghostty_config_path "$home_dir")"

  mkdir -p "$(dirname "$ghostty_config")"
  printf '%s\n' 'font-family = Existing Mono' > "$ghostty_config"
  printf '%s\n' 'set -g prefix C-a' > "$home_dir/.tmux.conf"

  run_setup "$home_dir" >/dev/null
  run_setup "$home_dir" >/dev/null

  assert_file_contains "$ghostty_config" 'font-family = Existing Mono'
  assert_file_contains "$ghostty_config" 'progress-style = true'
  assert_eq "$(grep -c '^# >>> ai-dotfiles managed: ghostty AI sessions$' "$ghostty_config")" "1" "managed Ghostty block duplicated"
  assert_file_contains "$home_dir/.tmux.conf" 'set -g prefix C-a'
  assert_file_contains "$home_dir/.tmux.conf" 'set -g allow-passthrough on'
  assert_eq "$(grep -c '^# >>> ai-dotfiles managed: tmux AI transport$' "$home_dir/.tmux.conf")" "1" "managed tmux block duplicated"
}

test_cross_agent_commands() {
  local home_dir
  home_dir="$(mktemp -d /tmp/ai-dotfiles-test-cmds.XXXXXX)"

  mkdir -p "$home_dir/.gemini/commands" "$home_dir/.codex/skills/checkpoint" "$home_dir/.codex/skills/ship"
  printf '%s\n' 'old checkpoint' > "$home_dir/.gemini/commands/checkpoint.toml"
  printf '%s\n' 'old ship' > "$home_dir/.gemini/commands/ship.toml"
  printf '%s\n' 'old checkpoint' > "$home_dir/.codex/skills/checkpoint/SKILL.md"
  printf '%s\n' 'old ship' > "$home_dir/.codex/skills/ship/SKILL.md"

  run_setup "$home_dir" >/dev/null

  # For every canonical command, expect derivatives in Gemini + Codex.
  for src in "$REPO_ROOT"/extensions/commands/*.md; do
    local name
    name="$(basename "$src" .md)"

    assert_exists "$home_dir/.gemini/commands/$name.toml"
    assert_file_contains "$home_dir/.gemini/commands/$name.toml" 'description = "'
    assert_file_contains "$home_dir/.gemini/commands/$name.toml" 'prompt = """'

    assert_exists "$home_dir/.codex/skills/$name/SKILL.md"
    assert_file_contains "$home_dir/.codex/skills/$name/SKILL.md" "name: $name"
    assert_file_contains "$home_dir/.codex/skills/$name/SKILL.md" 'description: '
  done

  assert_file_contains "$home_dir/.codex/skills/catchup/SKILL.md" 'instructions/AI.md'
  assert_file_contains "$home_dir/.codex/skills/handoff/SKILL.md" 'instructions/AI.md'
  assert_file_contains "$home_dir/.codex/skills/commit/SKILL.md" 'Commit the current logical unit'
  assert_file_contains "$home_dir/.codex/skills/push/SKILL.md" 'Push the current branch'
  [[ ! -e "$home_dir/.gemini/commands/checkpoint.toml" ]] || fail "old checkpoint Gemini command should not exist"
  [[ ! -e "$home_dir/.gemini/commands/ship.toml" ]] || fail "old ship Gemini command should not exist"
  [[ ! -e "$home_dir/.codex/skills/checkpoint" ]] || fail "old checkpoint Codex skill should not exist"
  [[ ! -e "$home_dir/.codex/skills/ship" ]] || fail "old ship Codex skill should not exist"

  # Global gitignore picked up '.ai/'.
  assert_exists "$home_dir/.config/git/ignore"
  assert_file_contains "$home_dir/.config/git/ignore" '.ai/'
}

test_dirty_tree_check() {
  local repo_dir
  repo_dir="$(mktemp -d /tmp/ai-dotfiles-test-dirty.XXXXXX)"

  git -C "$repo_dir" init -q
  local clean_output
  clean_output="$(cd "$repo_dir" && "$REPO_ROOT/scripts/dirty-tree-check.sh" 2>&1)"
  assert_eq "$clean_output" "" "clean repo should not warn"

  printf '%s\n' 'dirty' > "$repo_dir/file.txt"
  local dirty_output
  dirty_output="$(cd "$repo_dir" && "$REPO_ROOT/scripts/dirty-tree-check.sh" 2>&1)"
  assert_eq "$dirty_output" "[ai-dotfiles] working tree dirty at session end - consider /commit" "dirty repo warning mismatch"
}

test_codex_orchestration_skill() {
  local home_dir
  home_dir="$(mktemp -d /tmp/ai-dotfiles-test-codex-skill.XXXXXX)"

  run_setup "$home_dir" >/dev/null

  local skill_dir="$home_dir/.codex/skills/codex"
  assert_exists "$skill_dir/SKILL.md"
  assert_exists "$skill_dir/references/execution.md"
  assert_exists "$skill_dir/references/review.md"
  assert_exists "$skill_dir/references/parallelism.md"
  assert_exists "$skill_dir/templates/task-prompt.md"
  assert_file_contains "$skill_dir/SKILL.md" 'Capture the baseline before dispatch'
  assert_file_contains "$skill_dir/SKILL.md" 'codex exec resume'
  # shellcheck disable=SC2016 # Backticks are literal Markdown code delimiters.
  assert_file_contains "$skill_dir/SKILL.md" 'Never use `git checkout -- .`'
  assert_file_contains "$skill_dir/references/review.md" 'Treat agent narration as a claim'
}

test_backup_of_conflicting_files() {
  local home_dir
  home_dir="$(mktemp -d /tmp/ai-dotfiles-test-backup.XXXXXX)"

  mkdir -p "$home_dir/.claude"
  printf '%s\n' 'stale settings' > "$home_dir/.claude/settings.json"

  run_setup "$home_dir" >/dev/null

  local backup_dir
  backup_dir="$(find "$home_dir" -maxdepth 1 -type d -name '.ai-dotfiles-backup-*' | head -n 1)"

  [[ -n "$backup_dir" ]] || fail "expected backup directory for conflicting files"
  assert_exists "$backup_dir/settings.json"
  assert_file_contains "$backup_dir/settings.json" 'stale settings'
}

main() {
  test_fresh_install
  test_local_models
  test_idempotent_rerun
  test_codex_merge_preserves_local_state
  test_terminal_merges_preserve_local_state
  test_cross_agent_commands
  test_dirty_tree_check
  test_codex_orchestration_skill
  test_backup_of_conflicting_files
  printf 'PASS: setup.sh\n'
}

main "$@"
