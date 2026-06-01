#!/bin/sh
# Claude Code status line
# Format: repo@branch ✗ ↑↓ │ Model │ tokens ████░░ 26% │ 5h 99% · wk 100% │ +A/-D │ $0.012
# NOTE: "effort/thinking" not yet in statusline JSON - tracked at
#       github.com/anthropics/claude-code/issues/13158

input=$(cat)
ESC=$(printf '\033')
R="${ESC}[0m"
DIM="${ESC}[2m"
BOLD="${ESC}[1m"
GREEN="${ESC}[32m"
YELLOW="${ESC}[33m"
RED="${ESC}[31m"
SEP="${DIM} │ ${R}"

# ── parse ──────────────────────────────────────────────────────────────────
cwd=$(echo "$input"    | jq -r '.workspace.current_dir // .cwd // ""')
model=$(echo "$input"  | jq -r '.model.display_name // ""')
ctx_max=$(echo "$input" | jq -r '.context_window.context_window_size // empty')
ctx_pct=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
cost=$(echo "$input"   | jq -r '.cost.total_cost_usd // empty')
adds=$(echo "$input"   | jq -r '.cost.total_lines_added // 0')
dels=$(echo "$input"   | jq -r '.cost.total_lines_removed // 0')
# Rate-limit windows (Pro/Max only, present after first API response).
rl_5h=$(echo "$input"   | jq -r '.rate_limits.five_hour.used_percentage // empty' | cut -d. -f1)
rl_wk=$(echo "$input"   | jq -r '.rate_limits.seven_day.used_percentage // empty' | cut -d. -f1)

# ── helpers ─────────────────────────────────────────────────────────────────
fmt_k() {
  n=$1
  if   [ "$n" -ge 1000000 ] 2>/dev/null; then awk "BEGIN{printf \"%.1fm\",$n/1000000}"
  elif [ "$n" -ge 1000    ] 2>/dev/null; then awk "BEGIN{printf \"%dk\",int($n/1000)}"
  else printf '%s' "$n"
  fi
}

# ── 1. model ────────────────────────────────────────────────────────────────
model_part=""
if [ -n "$model" ]; then
  model_part="${BOLD}${model}${R}"
fi

# ── 2. repo@branch + git indicators ─────────────────────────────────────────
git_part=""
if git_branch=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null); then
  repo=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)
  repo=$(basename "${repo:-$cwd}")

  ind=""
  # dirty working tree
  if ! GIT_OPTIONAL_LOCKS=0 git -C "$cwd" diff --quiet 2>/dev/null || \
     ! GIT_OPTIONAL_LOCKS=0 git -C "$cwd" diff --cached --quiet 2>/dev/null; then
    ind="${ind} ${ESC}[33m✗${R}"
  fi
  # ahead / behind upstream
  ahead=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" rev-list --count "@{u}..HEAD" 2>/dev/null || true)
  behind=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" rev-list --count "HEAD..@{u}" 2>/dev/null || true)
  [ "${ahead:-0}" -gt 0 ]  2>/dev/null && ind="${ind} ${ESC}[32m↑${ahead}${R}"
  [ "${behind:-0}" -gt 0 ] 2>/dev/null && ind="${ind} ${ESC}[31m↓${behind}${R}"

  git_part="${ESC}[36m${repo}${R}${DIM}@${R}${ESC}[34m${git_branch}${R}${ind}"
fi

# ── 3. context bar (color-coded) ─────────────────────────────────────────────
ctx_part=""
if [ -n "$ctx_max" ]; then
  if   [ "$ctx_pct" -lt 50 ]; then bar_col="${ESC}[32m"   # green
  elif [ "$ctx_pct" -lt 75 ]; then bar_col="${ESC}[33m"   # yellow
  elif [ "$ctx_pct" -lt 90 ]; then bar_col="${ESC}[31m"   # red
  else                              bar_col="${ESC}[35m"   # magenta
  fi

  filled=$(( ctx_pct / 10 ))
  bar="" i=0
  while [ "$i" -lt "$filled" ]; do bar="${bar}█"; i=$(( i+1 )); done
  while [ "$i" -lt 10        ]; do bar="${bar}░"; i=$(( i+1 )); done

  used_tokens=$(awk "BEGIN{printf \"%d\", $ctx_pct/100 * $ctx_max}")
  ctx_part="${DIM}$(fmt_k "$used_tokens")/$(fmt_k "$ctx_max")${R}  ${bar_col}${bar}${R} ${DIM}${ctx_pct}%${R}"
fi

# ── 4. rate-limit windows (5h + weekly), showing % left ──────────────────────
# Color by how full the window is: <50% used green, <75% yellow, else red.
rl_col() {
  used=$1
  if   [ "$used" -lt 50 ]; then printf '%s' "$GREEN"
  elif [ "$used" -lt 75 ]; then printf '%s' "$YELLOW"
  else                          printf '%s' "$RED"
  fi
}
rl_part=""
rl_inner=""
if [ -n "$rl_5h" ]; then
  rl_inner="$(rl_col "$rl_5h")5h $(( 100 - rl_5h ))%${R}"
fi
if [ -n "$rl_wk" ]; then
  [ -n "$rl_inner" ] && rl_inner="${rl_inner}${DIM} · ${R}"
  rl_inner="${rl_inner}$(rl_col "$rl_wk")wk $(( 100 - rl_wk ))%${R}"
fi
[ -n "$rl_inner" ] && rl_part="$rl_inner"

# ── 5. lines changed this session ────────────────────────────────────────────
lines_part=""
if [ "${adds:-0}" -gt 0 ] 2>/dev/null || [ "${dels:-0}" -gt 0 ] 2>/dev/null; then
  lines_part="${GREEN}+${adds}${R}${DIM}/${R}${RED}-${dels}${R}"
fi

# ── 6. cost (placeholder for effort - see NOTE at top) ───────────────────────
cost_part=""
if [ -n "$cost" ]; then
  cost_fmt=$(awk "BEGIN{printf \"\$%.3f\",$cost}")
  cost_part="${DIM}${cost_fmt}${R}"
fi

# ── assemble ─────────────────────────────────────────────────────────────────
out=""
for part in "$git_part" "$lines_part" "$model_part" "$ctx_part" "$rl_part" "$cost_part"; do
  [ -z "$part" ] && continue
  [ -n "$out" ] && out="${out}${SEP}"
  out="${out}${part}"
done

printf '%s' "$out"
