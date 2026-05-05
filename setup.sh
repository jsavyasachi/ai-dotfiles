#!/usr/bin/env bash
# setup.sh: wire up AI agent dotfiles via symlinks
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
MERGED=()
REMOVED=()
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
  # Already a symlink into our dotfiles - skip
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
  # Already correctly symlinked - skip (and avoid ln creating inside a dir symlink)
  if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
    SKIPPED+=("$(basename "$dest") (already symlinked)")
    return 0
  fi
  backup_if_needed "$dest"
  # Remove existing symlink before recreating - on macOS, ln -sf on a dir symlink
  # creates a new symlink *inside* the target dir instead of replacing it.
  [[ -L "$dest" ]] && rm -f "$dest"
  ln -s "$src" "$dest"
  SYMLINKED+=("$(basename "$dest")")
}

merge_managed_block() {
  local src="$1"
  local dest="$2"
  local label="$3"
  local placeholder="${4:-}"
  local replacement="${5:-}"
  local start_marker="# >>> ai-dotfiles managed: ${label}"
  local end_marker="# <<< ai-dotfiles managed: ${label}"
  local tmp_block
  local tmp_out
  local actual
  local expected

  [[ -f "$src" ]] || return 0

  tmp_block="$(mktemp)"
  tmp_out="$(mktemp)"

  {
    printf '%s\n' "$start_marker"
    if [[ -n "$placeholder" ]]; then
      sed "s|${placeholder}|${replacement}|g" "$src"
    else
      cat "$src"
    fi
    printf '%s\n' "$end_marker"
  } > "$tmp_block"

  if [[ -f "$dest" ]]; then
    awk -v start="$start_marker" -v end="$end_marker" -v repl="$tmp_block" '
      function emit_replacement(    line) {
        while ((getline line < repl) > 0) print line
        close(repl)
      }
      $0 == start {
        if (!done) {
          emit_replacement()
          done = 1
        }
        in_block = 1
        next
      }
      $0 == end {
        in_block = 0
        next
      }
      !in_block { print }
      END {
        if (!done) {
          if (NR > 0) print ""
          emit_replacement()
        }
      }
    ' "$dest" > "$tmp_out"
  else
    cp "$tmp_block" "$tmp_out"
  fi

  actual="$(cat "$dest" 2>/dev/null || true)"
  expected="$(cat "$tmp_out")"

  if [[ "$actual" == "$expected" ]]; then
    SKIPPED+=("$(basename "$dest") (already up to date)")
  else
    mkdir -p "$(dirname "$dest")"
    mv "$tmp_out" "$dest"
    MERGED+=("$(basename "$dest")")
  fi

  rm -f "$tmp_block" "$tmp_out"
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
    warn "Unknown OS '$OS' - defaulting to GNU sed behavior."
    SED_INPLACE=(-i)
    ;;
esac

# ── agents ────────────────────────────────────────────────────────────────────

# Define agents and their home directories
CLAUDE_DIR="$HOME/.claude"
OPENCODE_DIR="$HOME/.config/opencode"
GEMINI_DIR="$HOME/.gemini"
CODEX_DIR="$HOME/.codex"

printf '\n\033[1mAI agent dotfiles setup\033[0m\n'
printf 'Dotfiles: %s\n' "$DOTFILES_DIR"
printf 'Claude:   %s\n' "$CLAUDE_DIR"
printf 'OpenCode: %s\n' "$OPENCODE_DIR"
printf 'Gemini:   %s\n\n' "$GEMINI_DIR"
printf 'Codex:    %s\n\n' "$CODEX_DIR"

mkdir -p "$OPENCODE_DIR"
mkdir -p "$CLAUDE_DIR"
mkdir -p "$GEMINI_DIR"
mkdir -p "$CODEX_DIR"

# Clean up legacy ~/.agents/skills symlink (Codex reads ~/.codex/skills/, not ~/.agents/skills/).
LEGACY_AGENTS_SKILLS="$HOME/.agents/skills"
if [[ -L "$LEGACY_AGENTS_SKILLS" ]]; then
  legacy_dest="$(readlink "$LEGACY_AGENTS_SKILLS")"
  if [[ "$legacy_dest" == "$DOTFILES_DIR"* ]]; then
    rm -f "$LEGACY_AGENTS_SKILLS"
    rmdir "$HOME/.agents" 2>/dev/null || true
    SYMLINKED+=("removed legacy ~/.agents/skills (Codex doesn't read this path)")
  fi
fi

# ── Universal Instructions (AI.md) ────────────────────────────────────────────

# Map agent instruction files to their homes
declare -A INSTRUCTION_MAP=(
  ["CLAUDE.md"]="$CLAUDE_DIR/CLAUDE.md"
  ["OPENCODE.md"]="$OPENCODE_DIR/OPENCODE.md"
  ["GEMINI.md"]="$GEMINI_DIR/GEMINI.md"
  ["AGENTS.md"]="$CODEX_DIR/AGENTS.md"
)

for item in "${!INSTRUCTION_MAP[@]}"; do
  make_symlink "$DOTFILES_DIR/instructions/$item" "${INSTRUCTION_MAP[$item]}"
done

# ── Shared statusline ─────────────────────────────────────────────────────────

for dir in "$CLAUDE_DIR" "$OPENCODE_DIR"; do
  make_symlink "$DOTFILES_DIR/scripts/statusline-command.sh" "$dir/statusline-command.sh"
done

make_symlink "$DOTFILES_DIR/scripts/dirty-tree-check.sh" "$CLAUDE_DIR/dirty-tree-check.sh"

# ── Claude specific ──────────────────────────────────────────────────────────

# Memory dir: path is derived from parent of this repo (the "projects" dir)
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

make_symlink "$DOTFILES_DIR/extensions/commands" "$OPENCODE_DIR/commands"

# OpenCode scans skills/**/SKILL.md - needs real files, not a dir symlink.
# Remove the old empty symlink and create an actual skills dir.
if [[ -L "$OPENCODE_DIR/skills" ]]; then
  rm -f "$OPENCODE_DIR/skills"
fi
mkdir -p "$OPENCODE_DIR/skills"

# ── Cross-agent commands: transform extensions/commands/*.md ─────────────────
#
# Single canonical source: extensions/commands/<name>.md (Markdown + YAML
# frontmatter). Distributed to each agent in its native format:
#   - Claude / OpenCode: covered by whole-dir symlink above (.md as-is).
#   - Gemini CLI:        generate ~/.gemini/commands/<name>.toml.
#   - Codex:             generate ~/.codex/skills/<name>/SKILL.md.

OPENCODE_NATIVE_SKILLS_DIR="$OPENCODE_DIR/skills"
CODEX_NATIVE_SKILLS_DIR="$CODEX_DIR/skills"
GEMINI_COMMANDS_DIR="$GEMINI_DIR/commands"
mkdir -p "$OPENCODE_NATIVE_SKILLS_DIR" "$CODEX_NATIVE_SKILLS_DIR" "$GEMINI_COMMANDS_DIR"

for old_name in checkpoint ship; do
  old_gemini="$GEMINI_COMMANDS_DIR/$old_name.toml"
  old_codex="$CODEX_NATIVE_SKILLS_DIR/$old_name"
  if [[ -f "$old_gemini" ]]; then
    rm -f "$old_gemini"
    REMOVED+=("$old_name.toml (Gemini)")
  fi
  if [[ -d "$old_codex" ]]; then
    rm -rf "$old_codex"
    REMOVED+=("$old_name/SKILL.md (Codex)")
  fi
done

write_if_changed() {
  local dest="$1" expected="$2" label="$3"
  local tmp
  tmp="$(mktemp)"
  printf '%s' "$expected" > "$tmp"
  if [[ -f "$dest" ]] && cmp -s "$dest" "$tmp"; then
    SKIPPED+=("$label (already up to date)")
    rm -f "$tmp"
  else
    mkdir -p "$(dirname "$dest")"
    mv "$tmp" "$dest"
    COPIED+=("$label")
  fi
}

for src in "$DOTFILES_DIR"/extensions/commands/*.md; do
  [[ -e "$src" ]] || continue
  name="$(basename "$src" .md)"

  description="$(awk '/^---$/{n++; next} n==1 && /^description: /{sub(/^description: /, ""); print; exit}' "$src")"
  body="$(awk '/^---$/{n++; next} n>=2' "$src")"

  # Strip a single leading blank line from body if present.
  body="${body#$'\n'}"

  # Gemini TOML: description + triple-quoted prompt.
  gemini_out=$'description = "'"${description//\"/\\\"}"$'"\nprompt = """\n'"$body"$'\n"""\n'
  write_if_changed "$GEMINI_COMMANDS_DIR/$name.toml" "$gemini_out" "$name.toml (Gemini)"

  # OpenCode SKILL.md: same YAML frontmatter format as Codex.
  opencode_out=$'---\nname: '"$name"$'\ndescription: '"$description"$'\n---\n\n'"$body"$'\n'
  write_if_changed "$OPENCODE_NATIVE_SKILLS_DIR/$name/SKILL.md" "$opencode_out" "$name/SKILL.md (OpenCode)"

  # Codex SKILL.md: YAML frontmatter (name + description) + body.
  codex_out=$'---\nname: '"$name"$'\ndescription: '"$description"$'\n---\n\n'"$body"$'\n'
  write_if_changed "$CODEX_NATIVE_SKILLS_DIR/$name/SKILL.md" "$codex_out" "$name/SKILL.md (Codex)"
done

# ── Global gitignore: ensure '.ai/' is ignored everywhere ────────────────────

GLOBAL_IGNORE="${XDG_CONFIG_HOME:-$HOME/.config}/git/ignore"
mkdir -p "$(dirname "$GLOBAL_IGNORE")"
touch "$GLOBAL_IGNORE"
if ! grep -qxF '.ai/' "$GLOBAL_IGNORE"; then
  printf '\n# ai-dotfiles: per-repo session journal\n.ai/\n' >> "$GLOBAL_IGNORE"
  COPIED+=("global gitignore (.ai/ added)")
else
  SKIPPED+=("global gitignore (.ai/ already present)")
fi

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
merge_managed_block "$DOTFILES_DIR/config/codex.toml.tpl" "$CODEX_DIR/config.toml" "codex config" "@@DOTFILES_DIR@@" "$DOTFILES_DIR"

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
for f in "${MERGED[@]}"; do success "Merged:    $f"; done
for f in "${REMOVED[@]}"; do success "Removed:   $f"; done
for f in "${BACKED_UP[@]}"; do warn "Backed up: $f  →  $BACKUP_DIR/"; done
for f in "${SKIPPED[@]}"; do info "Skipped:   $f"; done
for f in "${INSTALLED_PLUGINS[@]}"; do success "Plugin:    $f"; done

if [[ ${#COPIED[@]} -eq 0 && ${#SYMLINKED[@]} -eq 0 && ${#MERGED[@]} -eq 0 && ${#REMOVED[@]} -eq 0 && ${#INSTALLED_PLUGINS[@]} -eq 0 ]]; then
  printf '\nNothing to do - already up to date.\n'
else
  printf '\nDone. AI agent settings are live.\n'
fi
