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

# Context window
ctx_used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
ctx_window_size=$(echo "$input" | jq -r '.context_window.context_window_size // empty')

# Rate limits (5-hour and 7-day) — used percentages + reset times (epoch secs)
five_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
week_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
five_resets=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
week_resets=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')
now=$(date +%s)

# Session cost (USD)
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')

# Format token count: 1234 -> "1.2k", 1500000 -> "1.5M"
format_tokens() {
  awk -v n="$1" 'BEGIN {
    if (n >= 1000000) printf "%.1fM", n/1000000
    else if (n >= 1000)  printf "%.1fk", n/1000
    else                 printf "%d", n
  }'
}

# Render a 10-wide progress bar for a 0-100 percentage: [===.......]
# Optional args: fill_color (escape to restore after the marker) and target_pct.
# When target_pct is given, overlay a bright pace marker (|) at that position.
progress_bar() {
  local pct="$1" fill_color="$2" target="$3" width=10 filled tidx=-1 bar="" i
  local marker_color=$'\033[1;37m'
  filled=$(awk -v p="$pct" -v w="$width" 'BEGIN {
    f=int(p*w/100 + 0.5); if (f>w) f=w; if (f<0) f=0; print f
  }')
  if [ -n "$target" ]; then
    tidx=$(awk -v t="$target" -v w="$width" 'BEGIN {
      i=int(t*w/100 + 0.5); if (i>w-1) i=w-1; if (i<0) i=0; print i
    }')
  fi
  for ((i=0; i<width; i++)); do
    if   [ "$i" -eq "$tidx" ];   then bar+="${marker_color}|${fill_color}"
    elif [ "$i" -lt "$filled" ]; then bar+="="
    else                              bar+="."
    fi
  done
  printf '[%s]' "$bar"
}

# Optimal ("on-pace") used-% for a time-windowed limit: fraction of the window
# elapsed. window_start = resets_at - duration, so pace = 1 - (resets_at-now)/dur.
# At rollover resets_at is at/behind now (usage already reset, next window's later
# resets_at not yet reported) -> treat as a fresh window at 0% elapsed, not 100%.
optimal_pct() {
  awk -v r="$1" -v d="$2" -v n="$3" 'BEGIN {
    if (r - n <= 0) { print "0"; exit }
    p=(1 - (r - n)/d) * 100; if (p<0) p=0; if (p>100) p=100; printf "%.0f", p
  }'
}

# Signed pace delta " +N%"/" -N%": over pace (used>target) red, under/on pace green
pace_delta() {
  local delta="$(( $1 - $2 ))" dcolor sign
  if [ "$delta" -gt 0 ]; then
    dcolor='\033[0;31m'; sign='+'        # over pace -> red
  else
    dcolor='\033[0;32m'; sign=''         # under -> green (negative prints its own '-')
    [ "$delta" -eq 0 ] && sign='+'       # on pace -> "+0%" green
  fi
  printf ' %b%s%d%%\033[0m' "$dcolor" "$sign" "$delta"
}

# Color for a "used" metric (higher = worse)
used_color() {
  local pct_int="$1"
  if   [ "$pct_int" -ge 80 ]; then printf '\033[0;31m'   # red
  elif [ "$pct_int" -ge 60 ]; then printf '\033[0;33m'   # yellow
  else                             printf '\033[0;32m'   # green
  fi
}

# Join all positional args with a dim pipe separator
join_segments() {
  local sep result="" i first=1
  sep=$(printf '\033[0;90m|\033[0m')
  for seg in "$@"; do
    if [ $first -eq 1 ]; then
      result="$seg"
      first=0
    else
      result="$result $sep $seg"
    fi
  done
  printf '%s' "$result"
}

# Line 1: identity (dir, branch, model, cost)
line1=()

if [ -n "$dir" ]; then
  line1+=("$(printf '\033[0;36m%s\033[0m' "$dir")")
fi

if [ -n "$branch" ]; then
  line1+=("$(printf '\033[0;35m\xef\x90\x98 %s\033[0m' "$branch")")
fi

if [ -n "$model" ]; then
  line1+=("$(printf '\033[0;34m%s\033[0m' "$model")")
fi

if [ -n "$cost" ]; then
  line1+=("$(printf '\033[1;32m$%.2f\033[0m' "$cost")")
fi

# Line 2: usage bars (context, 5h rate, 7d rate)
line2=()

if [ -n "$ctx_used_pct" ] && [ -n "$ctx_window_size" ]; then
  tokens_used=$(awk -v p="$ctx_used_pct" -v s="$ctx_window_size" 'BEGIN { printf "%d", p*s/100 }')
  tokens_str=$(format_tokens "$tokens_used")
  bar=$(progress_bar "$ctx_used_pct")
  pct_int=$(printf '%.0f' "$ctx_used_pct")
  color=$(used_color "$pct_int")
  line2+=("$(printf "%b%s %s %d%%\033[0m" "$color" "$tokens_str" "$bar" "$pct_int")")
fi

if [ -n "$five_pct" ]; then
  pct_int=$(printf '%.0f' "$five_pct")
  color=$(used_color "$pct_int")
  target="" delta_str=""
  if [ -n "$five_resets" ]; then
    target=$(optimal_pct "$five_resets" 18000 "$now")   # 5h = 18000s
    delta_str=$(pace_delta "$pct_int" "$target")
  fi
  bar=$(progress_bar "$five_pct" "$color" "$target")
  line2+=("$(printf "%b5h %s %d%%\033[0m%s" "$color" "$bar" "$pct_int" "$delta_str")")
fi

if [ -n "$week_pct" ]; then
  pct_int=$(printf '%.0f' "$week_pct")
  color=$(used_color "$pct_int")
  target="" delta_str=""
  if [ -n "$week_resets" ]; then
    target=$(optimal_pct "$week_resets" 604800 "$now")  # 7d = 604800s
    delta_str=$(pace_delta "$pct_int" "$target")
  fi
  bar=$(progress_bar "$week_pct" "$color" "$target")
  line2+=("$(printf "%b7d %s %d%%\033[0m%s" "$color" "$bar" "$pct_int" "$delta_str")")
fi

# Emit both rows; only newline between them when both have content
if [ ${#line1[@]} -gt 0 ]; then
  join_segments "${line1[@]}"
fi
if [ ${#line1[@]} -gt 0 ] && [ ${#line2[@]} -gt 0 ]; then
  printf '\n'
fi
if [ ${#line2[@]} -gt 0 ]; then
  join_segments "${line2[@]}"
fi
