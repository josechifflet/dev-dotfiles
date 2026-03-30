#!/usr/bin/env bash
# Claude Code Status Line
# Format: dir | branch | model | used/total tokens | +lines/-lines

set -euo pipefail

input=$(cat)

# Extract values in one jq call. The statusline runs often, so avoid
# repeated parser startup for each field.
IFS=$'\t' read -r cwd model ctx_size ctx_used_pct lines_added lines_removed input_tokens cache_create cache_read < <(
  jq -r '
    [
      (.cwd // ""),
      (.model.display_name // .model.name // "claude"),
      (.context_window.context_window_size // 0),
      (.context_window.used_percentage // ""),
      (.cost.total_lines_added // 0),
      (.cost.total_lines_removed // 0),
      (.context_window.current_usage.input_tokens // 0),
      (.context_window.current_usage.cache_creation_input_tokens // 0),
      (.context_window.current_usage.cache_read_input_tokens // 0)
    ] | @tsv
  ' <<< "$input"
)

# Colors
RED='\033[31m'
YELLOW='\033[33m'
GREEN='\033[32m'
CYAN='\033[36m'
DIM='\033[2m'
RESET='\033[0m'

# Directory (basename, ~ for home)
dir=""
if [[ -n "$cwd" ]]; then
  dir="${cwd/#$HOME/\~}"
  dir=$(basename "$dir")
fi

# Git branch
branch=""
if [[ -n "$cwd" ]] && git -C "$cwd" rev-parse --git-dir &>/dev/null; then
  branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || echo "detached")
fi

# Model shortname
model_short=""
case "$model" in
  *[Oo]pus*) model_short="opus" ;;
  *[Ss]onnet*) model_short="sonnet" ;;
  *[Hh]aiku*) model_short="haiku" ;;
  *) model_short="${model:0:8}" ;;
esac

# Format token count as human-readable (e.g. 45.2k, 1.0M)
fmt_tokens() {
  local n=$1
  local whole tenths

  if (( n >= 1000000 )); then
    whole=$(( n / 1000000 ))
    tenths=$(( (n % 1000000) / 100000 ))
    printf "%d.%dM" "$whole" "$tenths"
  elif (( n >= 1000 )); then
    whole=$(( n / 1000 ))
    tenths=$(( (n % 1000) / 100 ))
    printf "%d.%dk" "$whole" "$tenths"
  else
    printf "%d" "$n"
  fi
}

# Context tokens — used_tokens is the input-only sum that matches used_percentage
used_tokens=$(( input_tokens + cache_create + cache_read ))
ctx_display=""
if [[ -n "$ctx_used_pct" && "$ctx_size" -gt 0 ]]; then
  pct_int=${ctx_used_pct%.*}
  # Color based on usage percentage
  if (( pct_int >= 80 )); then
    ctx_color="$RED"
  elif (( pct_int >= 50 )); then
    ctx_color="$YELLOW"
  else
    ctx_color="$GREEN"
  fi
  ctx_display="${ctx_color}$(fmt_tokens "$used_tokens")${RESET}${DIM}/${RESET}$(fmt_tokens "$ctx_size")"
fi

# Lines changed
lines_display=""
if [[ "$lines_added" != "0" || "$lines_removed" != "0" ]]; then
  lines_display="${GREEN}+${lines_added}${RESET}/${RED}-${lines_removed}${RESET}"
fi

# Build output
out=""
[[ -n "$dir" ]] && out="$dir"
[[ -n "$branch" ]] && out="$out ${DIM}|${RESET} $branch"
[[ -n "$model_short" ]] && out="$out ${DIM}|${RESET} ${CYAN}$model_short${RESET}"
[[ -n "$ctx_display" ]] && out="$out ${DIM}|${RESET} $ctx_display"
[[ -n "$lines_display" ]] && out="$out ${DIM}|${RESET} $lines_display"

printf "%b" "$out"
