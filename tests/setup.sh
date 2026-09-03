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
  assert_symlink_target "$home_dir/.codex/AGENTS.md" "$REPO_ROOT/instructions/AGENTS.md"
  assert_symlink_target "$home_dir/.config/opencode/OUTPUT-STYLE.md" "$REPO_ROOT/instructions/OUTPUT-STYLE.md"
  [[ ! -e "$home_dir/.gemini/GEMINI.md" ]] || fail "agy discovers project rules; setup should not create a global GEMINI.md"
  [[ ! -e "$home_dir/.gemini/OUTPUT-STYLE.md" ]] || fail "agy has no global OUTPUT-STYLE.md path"
  [[ ! -e "$home_dir/.agents/skills" ]] || fail "legacy ~/.agents/skills should not be created"

  assert_file_contains "$home_dir/.claude/settings.json" '"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"'
  assert_file_contains "$home_dir/.claude/settings.json" '"terminalProgressBarEnabled": true'
  assert_file_contains "$home_dir/.claude/settings.json" '"preferredNotifChannel": "ghostty"'
  assert_file_contains "$home_dir/.claude/settings.json" '"Stop"'
  assert_file_contains "$home_dir/.claude/settings.json" "bash $home_dir/.claude/dirty-tree-check.sh"
  assert_symlink_target "$home_dir/.claude/dirty-tree-check.sh" "$REPO_ROOT/scripts/dirty-tree-check.sh"
  assert_file_contains "$home_dir/.config/opencode/opencode.json" '"instructions": ["'"$home_dir"'/.config/opencode/OPENCODE.md", "'"$home_dir"'/.config/opencode/OUTPUT-STYLE.md"]'
  assert_file_contains "$home_dir/.config/opencode/opencode.json" '"model": "ollama/qwen2.5-coder:14b"'
  assert_file_contains "$home_dir/.config/opencode/opencode.json" '"baseURL": "http://localhost:11434/v1"'
  assert_file_contains "$home_dir/.claude/settings.json" '"outputStyle": "ai-dotfiles"'
  assert_file_contains "$home_dir/.claude/output-styles/ai-dotfiles.md" 'keep-coding-instructions: true'
  assert_file_contains "$home_dir/.claude/output-styles/ai-dotfiles.md" 'Write using ASD-STE100 Simplified Technical English.'
  [[ ! -e "$home_dir/.gemini/antigravity-cli/settings.json" ]] || fail "setup should not create agy settings"
  [[ ! -e "$home_dir/.gemini/settings.json" ]] || fail "setup should not create Gemini CLI settings"
  [[ ! -e "$home_dir/.gemini/commands" ]] || fail "setup should not create Gemini CLI commands"
  [[ ! -e "$home_dir/.gemini/skills" ]] || fail "setup should not create Gemini CLI skills"
  [[ ! -e "$home_dir/.codex/config.toml" ]] || fail "setup should not create ~/.codex/config.toml (codex config no longer managed)"
  [[ ! -e "$home_dir/.tmux.conf" ]] || fail "setup should not create ~/.tmux.conf (tmux transport removed)"
  assert_file_contains "$(ghostty_config_path "$home_dir")" '# >>> ai-dotfiles managed: ghostty AI sessions'
  assert_file_contains "$(ghostty_config_path "$home_dir")" 'progress-style = true'
  assert_file_contains "$(ghostty_config_path "$home_dir")" 'desktop-notifications = true'
  assert_file_contains "$(ghostty_config_path "$home_dir")" 'scrollback-limit = 100000'
  assert_file_contains "$(ghostty_config_path "$home_dir")" 'confirm-close-surface = true'
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

  assert_eq "$(printf '%s' "$output" | tail -n 1)" 'Nothing to do - already up to date.' "rerun summary mismatch"
}

# Codex config is deliberately NOT managed (removed 2026-08-03). Codex rewrites
# ~/.codex/config.toml itself and now persists model, [features], [tui], and the
# Stop hook on its own; a merged block re-declared those tables and TOML rejects
# a duplicate table, hard-failing Codex at startup with "duplicate key".
test_codex_config_left_alone() {
  local home_dir
  home_dir="$(mktemp -d /tmp/ai-dotfiles-test-codex.XXXXXX)"

  mkdir -p "$home_dir/.codex"
  cat > "$home_dir/.codex/config.toml" <<'EOF'
model = "gpt-5.4"
model_reasoning_effort = "medium"
[features]
hooks = true
[projects."/tmp/example"]
trust_level = "trusted"
EOF
  local before
  before="$(cat "$home_dir/.codex/config.toml")"

  run_setup "$home_dir" >/dev/null

  assert_eq "$(cat "$home_dir/.codex/config.toml")" "$before" "setup.sh must not modify ~/.codex/config.toml"
  assert_eq "$(grep -c 'ai-dotfiles managed: codex config' "$home_dir/.codex/config.toml" || true)" "0" "codex config must not be managed"
}

# agy owns and rewrites this file, including permissions, model selection, and
# trusted workspaces. setup.sh must leave existing agy state byte-identical.
test_agy_settings_left_alone() {
  local home_dir
  home_dir="$(mktemp -d /tmp/ai-dotfiles-test-agy-settings.XXXXXX)"

  mkdir -p "$home_dir/.gemini/antigravity-cli"
  cat > "$home_dir/.gemini/antigravity-cli/settings.json" <<'EOF'
{"enableTelemetry":false,"model":"Claude Opus 4.6 (Thinking)","trustedWorkspaces":["/Users/savya/projects"],"permissions":{"allow":["command(*)"]}}
EOF
  local before
  before="$(cat "$home_dir/.gemini/antigravity-cli/settings.json")"

  run_setup "$home_dir" >/dev/null

  assert_eq "$(cat "$home_dir/.gemini/antigravity-cli/settings.json")" "$before" "setup.sh must not modify agy settings"
}

test_terminal_merges_preserve_local_state() {
  local home_dir
  home_dir="$(mktemp -d /tmp/ai-dotfiles-test-terminal-merge.XXXXXX)"
  local ghostty_config
  ghostty_config="$(ghostty_config_path "$home_dir")"

  mkdir -p "$(dirname "$ghostty_config")"
  printf '%s\n' 'font-family = Existing Mono' > "$ghostty_config"

  run_setup "$home_dir" >/dev/null
  run_setup "$home_dir" >/dev/null

  assert_file_contains "$ghostty_config" 'font-family = Existing Mono'
  assert_file_contains "$ghostty_config" 'progress-style = true'
  assert_eq "$(grep -c '^# >>> ai-dotfiles managed: ghostty AI sessions$' "$ghostty_config")" "1" "managed Ghostty block duplicated"
}

test_cross_agent_commands() {
  local home_dir
  home_dir="$(mktemp -d /tmp/ai-dotfiles-test-cmds.XXXXXX)"

  mkdir -p "$home_dir/.gemini/commands" "$home_dir/.codex/skills/checkpoint" "$home_dir/.codex/skills/ship" \
    "$home_dir/.gemini/commands" "$home_dir/.codex/skills/handoff" "$home_dir/.codex/skills/catchup" \
    "$home_dir/.config/opencode/skills/handoff" "$home_dir/.config/opencode/skills/catchup"
  printf '%s\n' 'old checkpoint' > "$home_dir/.gemini/commands/checkpoint.toml"
  printf '%s\n' 'old ship' > "$home_dir/.gemini/commands/ship.toml"
  printf '%s\n' 'old checkpoint' > "$home_dir/.codex/skills/checkpoint/SKILL.md"
  printf '%s\n' 'old ship' > "$home_dir/.codex/skills/ship/SKILL.md"
  printf '%s\n' 'old handoff' > "$home_dir/.gemini/commands/handoff.toml"
  printf '%s\n' 'old catchup' > "$home_dir/.gemini/commands/catchup.toml"
  printf '%s\n' 'old handoff' > "$home_dir/.codex/skills/handoff/SKILL.md"
  printf '%s\n' 'old catchup' > "$home_dir/.codex/skills/catchup/SKILL.md"
  printf '%s\n' 'old handoff' > "$home_dir/.config/opencode/skills/handoff/SKILL.md"
  printf '%s\n' 'old catchup' > "$home_dir/.config/opencode/skills/catchup/SKILL.md"

  run_setup "$home_dir" >/dev/null

  # For every canonical command, expect a Codex derivative. agy has no TOML
  # command format, so commands are not translated for it.
  for src in "$REPO_ROOT"/extensions/commands/*.md; do
    local name
    name="$(basename "$src" .md)"

    [[ ! -e "$home_dir/.gemini/commands/$name.toml" ]] || fail "Gemini command should be removed: $name.toml"

    assert_exists "$home_dir/.codex/skills/$name/SKILL.md"
    assert_file_contains "$home_dir/.codex/skills/$name/SKILL.md" "name: $name"
    assert_file_contains "$home_dir/.codex/skills/$name/SKILL.md" 'description: '
  done

  assert_file_contains "$home_dir/.codex/skills/commit/SKILL.md" 'Commit the current logical unit'
  assert_file_contains "$home_dir/.codex/skills/push/SKILL.md" 'Push the current branch'
  [[ ! -e "$home_dir/.gemini/commands/checkpoint.toml" ]] || fail "old checkpoint Gemini command should not exist"
  [[ ! -e "$home_dir/.gemini/commands/ship.toml" ]] || fail "old ship Gemini command should not exist"
  [[ ! -e "$home_dir/.codex/skills/checkpoint" ]] || fail "old checkpoint Codex skill should not exist"
  [[ ! -e "$home_dir/.codex/skills/ship" ]] || fail "old ship Codex skill should not exist"
  [[ ! -e "$home_dir/.gemini/commands/handoff.toml" ]] || fail "removed handoff Gemini command should not exist"
  [[ ! -e "$home_dir/.gemini/commands/catchup.toml" ]] || fail "removed catchup Gemini command should not exist"
  [[ ! -e "$home_dir/.codex/skills/handoff" ]] || fail "removed handoff Codex skill should not exist"
  [[ ! -e "$home_dir/.codex/skills/catchup" ]] || fail "removed catchup Codex skill should not exist"
  [[ ! -e "$home_dir/.config/opencode/skills/handoff" ]] || fail "removed handoff OpenCode skill should not exist"
  [[ ! -e "$home_dir/.config/opencode/skills/catchup" ]] || fail "removed catchup OpenCode skill should not exist"

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

test_opencode_delegation_skill() {
  local home_dir
  home_dir="$(mktemp -d /tmp/ai-dotfiles-test-opencode-skill.XXXXXX)"

  run_setup "$home_dir" >/dev/null

  local skill_dir="$home_dir/.codex/skills/opencode"
  assert_exists "$skill_dir/SKILL.md"
  assert_exists "$skill_dir/references/execution.md"
  assert_exists "$skill_dir/templates/task-prompt.md"
  assert_file_contains "$skill_dir/SKILL.md" 'smaller task scope'
  grep -Fq -- '--format json' "$skill_dir/SKILL.md" || fail "expected '--format json' in $skill_dir/SKILL.md"
  assert_exists "$home_dir/.gemini/config/skills/opencode/SKILL.md"
  assert_exists "$home_dir/.gemini/config/skills/opencode/references/execution.md"
  assert_exists "$home_dir/.gemini/config/skills/opencode/templates/task-prompt.md"
}

test_gemini_artifact_cleanup_preserves_user_content() {
  local home_dir
  home_dir="$(mktemp -d /tmp/ai-dotfiles-test-gemini-cleanup.XXXXXX)"

  mkdir -p "$home_dir/.gemini/commands" "$home_dir/.gemini/skills"
  printf '%s\n' 'generated command' > "$home_dir/.gemini/commands/commit.toml"
  printf '%s\n' 'user command' > "$home_dir/.gemini/commands/user-command.toml"
  ln -s "$REPO_ROOT/extensions/skills/tdd" "$home_dir/.gemini/skills/tdd"
  ln -s "$REPO_ROOT/instructions" "$home_dir/.gemini/skills/user-skill"

  run_setup "$home_dir" >/dev/null

  [[ ! -e "$home_dir/.gemini/commands/commit.toml" ]] || fail "generated Gemini command should be removed"
  assert_file_contains "$home_dir/.gemini/commands/user-command.toml" 'user command'
  [[ ! -e "$home_dir/.gemini/skills/tdd" && ! -L "$home_dir/.gemini/skills/tdd" ]] || fail "generated Gemini skill symlink should be removed"
  assert_symlink_target "$home_dir/.gemini/skills/user-skill" "$REPO_ROOT/instructions"
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
  # Backups mirror the target's path under BACKUP_DIR rather than flattening to
  # basename: two agent roots can hold same-named entries (e.g. .codex/skills/foo
  # and .agents/skills/foo) and a flat dir made the second `mv` abort the run.
  assert_exists "$backup_dir/.claude/settings.json"
  assert_file_contains "$backup_dir/.claude/settings.json" 'stale settings'
}

test_backup_handles_same_named_targets() {
  local home_dir
  home_dir="$(mktemp -d /tmp/ai-dotfiles-test-backup-collide.XXXXXX)"

  # Same basename under two different agent roots - the flat-backup bug.
  mkdir -p "$home_dir/.codex/skills/tdd" "$home_dir/.gemini/config/skills/tdd"
  printf '%s\n' 'codex copy' > "$home_dir/.codex/skills/tdd/SKILL.md"
  printf '%s\n' 'agy copy' > "$home_dir/.gemini/config/skills/tdd/SKILL.md"

  run_setup "$home_dir" >/dev/null || fail "setup must not abort on same-named backup targets"

  local backup_dir
  backup_dir="$(find "$home_dir" -maxdepth 1 -type d -name '.ai-dotfiles-backup-*' | head -n 1)"
  [[ -n "$backup_dir" ]] || fail "expected backup directory"
  assert_file_contains "$backup_dir/.codex/skills/tdd/SKILL.md" 'codex copy'
  assert_file_contains "$backup_dir/.gemini/config/skills/tdd/SKILL.md" 'agy copy'
}

main() {
  test_fresh_install
  test_local_models
  test_idempotent_rerun
  test_codex_config_left_alone
  test_agy_settings_left_alone
  test_terminal_merges_preserve_local_state
  test_cross_agent_commands
  test_dirty_tree_check
  test_codex_orchestration_skill
  test_opencode_delegation_skill
  test_gemini_artifact_cleanup_preserves_user_content
  test_backup_of_conflicting_files
  test_backup_handles_same_named_targets
  printf 'PASS: setup.sh\n'
}

main "$@"
