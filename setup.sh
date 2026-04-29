#!/usr/bin/env bash
# setup.sh — wire up AI agent dotfiles via symlinks
# Safe to run multiple times (idempotent).
# Usage: bash setup.sh [--force]

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_TS="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="$HOME/.ai-dotfiles-backup-$BACKUP_TS"
BACKUP_USED=false

# Counters for summary
COPIED=()
SYMLINKED=()
BACKED_UP=()
SKIPPED=()
INSTALLED_PLUGINS=()

# ── helpers ──────────────────────────────────────────────────────────────────

info()    { printf '  \033[34m•\033[0m %s\n' "$*"; }
success() { printf '  \033[32m✔\033[0m %s\n' "$*"; }
warn()    { printf '  \033[33m!\033[0m %s\n' "$*"; }
error()   { printf '  \033[31m✖\033[0m %s\n' "$*" >&2; }

backup_if_needed() {
  local target="$1"
  # Nothing to back up if target doesn't exist
  [[ -e "$target" || -L "$target" ]] || return 0
  # Already a symlink into our dotfiles — skip
  if [[ -L "$target" ]]; then
    local link_dest
    link_dest="$(readlink "$target")"
    if [[ "$link_dest" == "$DOTFILES_DIR"* ]]; then
      return 0
    fi
  fi
  # Back up
  mkdir -p "$BACKUP_DIR"
  mv "$target" "$BACKUP_DIR/"
  BACKUP_USED=true
  BACKED_UP+=("$(basename "$target")")
}

make_symlink() {
  local src="$1"
  local dest="$2"
  # Source must exist in the repo
  if [[ ! -e "$src" ]]; then
    SKIPPED+=("$(basename "$src") (not in repo yet)")
    return 0
  fi
  # Already correctly symlinked — skip (and avoid ln creating inside a dir symlink)
  if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
    SKIPPED+=("$(basename "$dest") (already symlinked)")
    return 0
  fi
  backup_if_needed "$dest"
  # Remove existing symlink before recreating — on macOS, ln -sf on a dir symlink
  # creates a new symlink *inside* the target dir instead of replacing it.
  [[ -L "$dest" ]] && rm -f "$dest"
  ln -s "$src" "$dest"
  SYMLINKED+=("$(basename "$dest")")
}

# ── guards ────────────────────────────────────────────────────────────────────

if [[ "${EUID:-$(id -u)}" -eq 0 ]] && [[ "${1:-}" != "--force" ]]; then
  error "Running as root. Use --force to override (not recommended)."
  exit 1
fi

# ── OS detection ──────────────────────────────────────────────────────────────

OS="$(uname -s)"
case "$OS" in
  Darwin) SED_INPLACE=(-i '') ;;
  Linux)  SED_INPLACE=(-i)    ;;
  *)
    warn "Unknown OS '$OS' — defaulting to GNU sed behavior."
    SED_INPLACE=(-i)
    ;;
esac

# ── agents ────────────────────────────────────────────────────────────────────

# Define agents and their home directories
CLAUDE_DIR="$HOME/.claude"
OPENCODE_DIR="$HOME/.config/opencode"
GEMINI_DIR="$HOME/.gemini"

printf '\n\033[1mAI agent dotfiles setup\033[0m\n'
printf 'Dotfiles: %s\n' "$DOTFILES_DIR"
printf 'Claude:   %s\n' "$CLAUDE_DIR"
printf 'OpenCode: %s\n' "$OPENCODE_DIR"
printf 'Gemini:   %s\n\n' "$GEMINI_DIR"

mkdir -p "$OPENCODE_DIR"
mkdir -p "$CLAUDE_DIR"
mkdir -p "$GEMINI_DIR"

# ── Universal Instructions (AI.md) ────────────────────────────────────────────

# Map agent instruction files to their homes
declare -A INSTRUCTION_MAP=(
  ["CLAUDE.md"]="$CLAUDE_DIR/CLAUDE.md"
  ["OPENCODE.md"]="$OPENCODE_DIR/OPENCODE.md"
  ["GEMINI.md"]="$GEMINI_DIR/GEMINI.md"
)

for item in "${!INSTRUCTION_MAP[@]}"; do
  make_symlink "$DOTFILES_DIR/instructions/$item" "${INSTRUCTION_MAP[$item]}"
done

# ── Shared statusline ─────────────────────────────────────────────────────────

for dir in "$CLAUDE_DIR" "$OPENCODE_DIR"; do
  make_symlink "$DOTFILES_DIR/scripts/statusline-command.sh" "$dir/statusline-command.sh"
done

# ── Claude specific ──────────────────────────────────────────────────────────

# Memory dir — path is derived from parent of this repo (the "projects" dir)
PROJECTS_DIR="$(dirname "$DOTFILES_DIR")"
ENCODED_PROJECTS="$(printf '%s' "$PROJECTS_DIR" | tr '/' '-')"
MEMORY_PARENT="$CLAUDE_DIR/projects/${ENCODED_PROJECTS}"
MEMORY_DEST="$MEMORY_PARENT/memory"
MEMORY_SRC="$DOTFILES_DIR/extensions/memory"

if [[ -d "$MEMORY_SRC" ]]; then
  mkdir -p "$MEMORY_PARENT"
  make_symlink "$MEMORY_SRC" "$MEMORY_DEST"
fi

# Directories (symlink the whole dir so new files appear automatically)
for dir in commands skills hooks; do
  make_symlink "$DOTFILES_DIR/extensions/$dir" "$CLAUDE_DIR/$dir"
done

# ── OpenCode specific ────────────────────────────────────────────────────────

for dir in commands skills; do
  make_symlink "$DOTFILES_DIR/extensions/$dir" "$OPENCODE_DIR/$dir"
done

# ── settings.json (copy logic for Claude/OpenCode) ───────────────────────────

# We still copy because symlinks are reported buggy in these agents.
# However, we use absolute paths in the final file.

sync_settings() {
  local tpl="$1"
  local dest="$2"
  local placeholder="$3"
  local replacement="$4"

  [[ -f "$tpl" ]] || return 0

  local expected
  expected="$(sed "s|${placeholder}|${replacement}|g" "$tpl")"
  local actual
  actual="$(cat "$dest" 2>/dev/null || true)"

  if [[ "$expected" == "$actual" ]]; then
    SKIPPED+=("$(basename "$dest") (already up to date)")
  else
    if [[ -e "$dest" && "$actual" != "$expected" ]]; then
      backup_if_needed "$dest"
    fi
    printf '%s\n' "$expected" > "$dest"
    COPIED+=("$(basename "$dest")")
  fi
}

sync_settings "$DOTFILES_DIR/config/settings.json.tpl" "$CLAUDE_DIR/settings.json" "@@CLAUDE_DIR@@" "$CLAUDE_DIR"
sync_settings "$DOTFILES_DIR/config/opencode.json.tpl" "$OPENCODE_DIR/opencode.json" "@@OPENCODE_DIR@@" "$OPENCODE_DIR"

# ── plugins ───────────────────────────────────────────────────────────────────

PLUGINS_FILE="$DOTFILES_DIR/config/plugins.txt"
if [[ -f "$PLUGINS_FILE" ]] && command -v claude &>/dev/null; then
  installed_list=$(claude plugin list 2>/dev/null | grep '❯' | awk '{print $2}' || true)
  while IFS= read -r line; do
    [[ "$line" =~ ^# ]] && continue
    [[ -z "$line" ]]    && continue
    plugin_id="$line"
    if echo "$installed_list" | grep -qF "$plugin_id"; then
      SKIPPED+=("$plugin_id (plugin already installed)")
    else
      if claude plugin install "$plugin_id" &>/dev/null; then
        INSTALLED_PLUGINS+=("$plugin_id")
      else
        warn "Plugin install failed: $plugin_id"
      fi
    fi
  done < "$PLUGINS_FILE"
fi

# ── summary ───────────────────────────────────────────────────────────────────

printf '\n\033[1mSummary\033[0m\n'

for f in "${COPIED[@]}"; do success "Copied:    $f"; done
for f in "${SYMLINKED[@]}"; do success "Symlinked: $f"; done
for f in "${BACKED_UP[@]}"; do warn "Backed up: $f  →  $BACKUP_DIR/"; done
for f in "${SKIPPED[@]}"; do info "Skipped:   $f"; done
for f in "${INSTALLED_PLUGINS[@]}"; do success "Plugin:    $f"; done

if [[ ${#COPIED[@]} -eq 0 && ${#SYMLINKED[@]} -eq 0 ]]; then
  printf '\nNothing to do — already up to date.\n'
else
  printf '\nDone. AI agent settings are live.\n'
fi
