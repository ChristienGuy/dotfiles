#!/usr/bin/env bash
# Claude Code status line — complements Starship prompt
input=$(cat)

# Directory (basename of cwd)
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
dir=$(basename "$cwd")

# Git branch (skip optional locks)
branch=""
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
  branch=$(git -C "$cwd" -c core.useBuiltinFSMonitor=false symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
fi

# Model display name
model=$(echo "$input" | jq -r '.model.display_name // ""')

# Context remaining percentage
remaining=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')

# Rate limits (5-hour and 7-day)
five_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
week_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

# Session cost (USD)
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')

# Build output parts
parts=()

# Directory segment (cyan)
if [ -n "$dir" ]; then
  parts+=("$(printf '\033[0;36m%s\033[0m' "$dir")")
fi

# Git branch segment (magenta)
if [ -n "$branch" ]; then
  parts+=("$(printf '\033[0;35m\xef\x90\x98 %s\033[0m' "$branch")")
fi

# Model segment (blue)
if [ -n "$model" ]; then
  parts+=("$(printf '\033[0;34m%s\033[0m' "$model")")
fi

# Context remaining
if [ -n "$remaining" ]; then
  remaining_int=$(printf '%.0f' "$remaining")
  if [ "$remaining_int" -le 20 ]; then
    color='\033[0;31m'  # red when low
  elif [ "$remaining_int" -le 40 ]; then
    color='\033[0;33m'  # yellow when moderate
  else
    color='\033[0;32m'  # green when healthy
  fi
  parts+=("$(printf "${color}ctx:%d%%\033[0m" "$remaining_int")")
fi

# Session cost
if [ -n "$cost" ]; then
  parts+=("$(printf '\033[1;32m$%.2f\033[0m' "$cost")")
fi

# Rate limits
rate_parts=()
[ -n "$five_pct" ] && rate_parts+=("$(printf '5h:%.0f%%' "$five_pct")")
[ -n "$week_pct" ] && rate_parts+=("$(printf '7d:%.0f%%' "$week_pct")")
if [ ${#rate_parts[@]} -gt 0 ]; then
  rate_str=$(IFS=' '; echo "${rate_parts[*]}")
  parts+=("$(printf '\033[0;33m%s\033[0m' "$rate_str")")
fi

# Join with separator
if [ ${#parts[@]} -gt 0 ]; then
  result=""
  for i in "${!parts[@]}"; do
    if [ $i -eq 0 ]; then
      result="${parts[$i]}"
    else
      result="$result $(printf '\033[0;90m|\033[0m') ${parts[$i]}"
    fi
  done
  printf '%s' "$result"
fi
