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
  HOME="$home_dir" PATH="$BASE_PATH" "$BASH_BIN" "$REPO_ROOT/setup.sh"
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
  assert_file_contains "$home_dir/.claude/settings.json" '"Stop"'
  assert_file_contains "$home_dir/.claude/settings.json" "bash $home_dir/.claude/dirty-tree-check.sh"
  assert_symlink_target "$home_dir/.claude/dirty-tree-check.sh" "$REPO_ROOT/scripts/dirty-tree-check.sh"
  assert_file_contains "$home_dir/.config/opencode/opencode.json" '"instructions": ["'"$home_dir"'/.config/opencode/OPENCODE.md"]'
  assert_file_contains "$home_dir/.codex/config.toml" 'project_doc_fallback_filenames = ["AI.md"]'
  assert_file_contains "$home_dir/.codex/config.toml" 'codex_hooks = true'
  assert_file_contains "$home_dir/.codex/config.toml" '[[hooks.Stop]]'
  assert_file_contains "$home_dir/.codex/config.toml" "bash $REPO_ROOT/scripts/dirty-tree-check.sh"
  assert_eq "$(printf '%s' "$output" | tail -n 1)" 'Done. AI agent settings are live.' "fresh install summary mismatch"
}

test_idempotent_rerun() {
  local home_dir
  home_dir="$(mktemp -d /tmp/ai-dotfiles-test-rerun.XXXXXX)"

  run_setup "$home_dir" >/dev/null

  local output
  output="$(run_setup "$home_dir")"

  assert_file_contains "$home_dir/.codex/config.toml" '# >>> ai-dotfiles managed: codex config'
  assert_eq "$(grep -c '^# >>> ai-dotfiles managed: codex config$' "$home_dir/.codex/config.toml")" "1" "managed codex block duplicated"
  assert_eq "$(printf '%s' "$output" | tail -n 1)" 'Nothing to do — already up to date.' "rerun summary mismatch"
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

test_cross_agent_commands() {
  local home_dir
  home_dir="$(mktemp -d /tmp/ai-dotfiles-test-cmds.XXXXXX)"

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
  assert_file_contains "$home_dir/.codex/skills/checkpoint/SKILL.md" 'Commit the current logical unit'
  assert_file_contains "$home_dir/.codex/skills/ship/SKILL.md" 'Push the current branch'

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
  assert_eq "$dirty_output" "[ai-dotfiles] working tree dirty at session end - consider /checkpoint" "dirty repo warning mismatch"
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
  test_idempotent_rerun
  test_codex_merge_preserves_local_state
  test_cross_agent_commands
  test_dirty_tree_check
  test_backup_of_conflicting_files
  printf 'PASS: setup.sh\n'
}

main "$@"
