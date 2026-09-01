#!/bin/bash
# Claude Code status line.
#
#   Opus 5 · high · thinking | ~/dev | main* | edited +214/-31 · $0.92
#
#   Session ██░░░░░░░░░░░░░░░░░░   9%  resets in 4h 31m · on pace for 41%
#
#   Week    ███░░░░░░░░░░░░░░░░░  16%  resets in 3d 15h
#
#   Context █████░┊░░░░░░░░░░░░░  26%  52k / 200k · compacts at 30%
#
# Every value comes from the JSON payload Claude Code pipes in on stdin.
# All tunables live in statusline.conf; this file holds only logic and the
# fallback defaults, so it still runs standalone with no config present.
#
# See README.md for the full option reference.

input=$(cat)

# ----------------------------------------------------------------- config ---
# First readable candidate wins. Set CLAUDE_STATUSLINE_CONF to point elsewhere.
_self_dir=$(dirname "${BASH_SOURCE[0]}")
for _conf in "$CLAUDE_STATUSLINE_CONF" "$HOME/.claude/statusline.conf" "$_self_dir/statusline.conf"; do
  if [ -n "$_conf" ] && [ -f "$_conf" ]; then
    # shellcheck disable=SC1090
    . "$_conf"
    break
  fi
done

# Defaults for anything the config did not set. := so the config always wins.
: "${BAR_WIDTH:=20}"
: "${LABEL_WIDTH:=7}"
: "${SHOW_SPACERS:=1}"

: "${SHOW_SESSION:=1}"
: "${SHOW_WEEK:=1}"
: "${SHOW_CONTEXT:=1}"

: "${SHOW_MODES:=1}"
: "${SHOW_DIR:=1}"
: "${SHOW_GIT:=1}"
: "${SHOW_CHURN:=1}"
: "${SHOW_COST:=1}"

: "${SHOW_RESETS:=1}"
: "${SHOW_PACE:=1}"
: "${SHOW_TOKENS:=1}"
: "${PACE_MIN_ELAPSED:=1200}"
: "${SESSION_WINDOW:=18000}"

: "${WARN_PCT:=60}"
: "${DANGER_PCT:=85}"
: "${DANGER_CUE:=! }"

: "${COMPACT_PCT:=}"
: "${GIT_CACHE_TTL:=3}"

: "${BAR_FILL:=█}"
: "${BAR_EMPTY:=░}"
: "${BAR_MARK:=┊}"
: "${SEP:= | }"
: "${MODE_SEP:= · }"

: "${LABEL_SESSION:=Session}"
: "${LABEL_WEEK:=Week}"
: "${LABEL_CONTEXT:=Context}"

# Colours are raw SGR parameters. Basic ANSI codes (31-37) follow the terminal
# theme; 38;5;N picks a fixed 256-colour index. Empty means no colour at all.
: "${COLOR_MODEL:=36}"
: "${COLOR_DIR:=32}"
: "${COLOR_GIT:=35}"
: "${COLOR_TEXT:=38;5;245}"
: "${COLOR_TROUGH:=38;5;238}"
: "${COLOR_MARK:=38;5;250}"
: "${COLOR_OK:=32}"
: "${COLOR_WARN:=33}"
: "${COLOR_DANGER:=31}"

ESC=$'\033'
set_colour() { # var name, SGR parameters
  if [ -z "$2" ]; then printf -v "$1" '%s' ""; else printf -v "$1" '%s' "$ESC[$2m"; fi
}
set_colour C_MODEL  "$COLOR_MODEL"
set_colour C_DIR    "$COLOR_DIR"
set_colour C_GIT    "$COLOR_GIT"
set_colour C_TEXT   "$COLOR_TEXT"
set_colour C_TROUGH "$COLOR_TROUGH"
set_colour C_MARK   "$COLOR_MARK"
set_colour C_OK     "$COLOR_OK"
set_colour C_WARN   "$COLOR_WARN"
set_colour C_DANGER "$COLOR_DANGER"
C_RESET="$ESC[0m"

# Spacer row. Claude Code post-processes status line output as
#   stdout.trim().split("\n").flatMap(l => l.trim() || []).join("\n")
# so any row that is empty after trimming is dropped, and a plain blank line
# disappears. U+2800 (braille blank) is not whitespace to JS trim(), so the row
# survives and still renders as blank. bash 3.2 has no \u escape, hence bytes.
SPACER=$'\xe2\xa0\x80'

# ---------------------------------------------------------------- payload ---
# One jq invocation for the whole payload. Unit separator as the delimiter
# because tab is an IFS-whitespace character, which would collapse empty fields.
US=$'\037'
IFS="$US" read -r model cwd effort thinking fast style \
  five_pct five_reset week_pct week_reset \
  ctx_pct ctx_used ctx_size cost_usd lines_add lines_rem <<EOF
$(printf '%s' "$input" | jq -r '[
  (.model.display_name // "Claude"),
  (.workspace.current_dir // ""),
  (.effort.level // ""),
  (if .thinking.enabled then "1" else "" end),
  (if .fast_mode then "1" else "" end),
  (if (.output_style.name // "default") == "default" then "" else .output_style.name end),
  (.rate_limits.five_hour.used_percentage // ""),
  (.rate_limits.five_hour.resets_at // ""),
  (.rate_limits.seven_day.used_percentage // ""),
  (.rate_limits.seven_day.resets_at // ""),
  (.context_window.used_percentage // ""),
  (.context_window.total_input_tokens // ""),
  (.context_window.context_window_size // ""),
  (.cost.total_cost_usd // ""),
  (.cost.total_lines_added // ""),
  (.cost.total_lines_removed // "")
] | join("\u001f")')
EOF

[ -z "$cwd" ] && cwd=$(pwd)
dir="${cwd/#$HOME/~}"

# ----------------------------------------------------------------- pieces ---
level_colour() {
  if   [ "$1" -ge "$DANGER_PCT" ]; then printf '%s' "$C_DANGER"
  elif [ "$1" -ge "$WARN_PCT" ];   then printf '%s' "$C_WARN"
  else printf '%s' "$C_OK"; fi
}

# Bar with an optional threshold tick. $2 is the marker cell index, or -1.
make_bar() {
  local pct=$1 mcell=$2 filled i out fill_colour
  fill_colour=$(level_colour "$pct")
  filled=$(((pct * BAR_WIDTH + 50) / 100))
  out="$fill_colour"
  for ((i = 0; i < BAR_WIDTH; i++)); do
    [ "$i" -eq "$filled" ] && out+="$C_TROUGH"
    if [ "$i" -eq "$mcell" ]; then
      out+="${C_MARK}${BAR_MARK}"
      if [ "$i" -lt "$filled" ]; then out+="$fill_colour"; else out+="$C_TROUGH"; fi
    elif [ "$i" -lt "$filled" ]; then
      out+="$BAR_FILL"
    else
      out+="$BAR_EMPTY"
    fi
  done
  printf '%s%s' "$out" "$C_RESET"
}

# Seconds until a reset, humanised.
until_reset() {
  local diff=$1 d h m
  [ "$diff" -le 0 ] && { printf 'resets now'; return; }
  d=$((diff / 86400)); h=$(((diff % 86400) / 3600)); m=$(((diff % 3600) / 60))
  if   [ "$d" -gt 0 ]; then printf 'resets in %dd %dh' "$d" "$h"
  elif [ "$h" -gt 0 ]; then printf 'resets in %dh %dm' "$h" "$m"
  else printf 'resets in %dm' "$m"; fi
}

# Project usage to the end of the window from the rate so far. Suppressed early
# in a window, where too little has elapsed for the number to mean anything.
on_pace() {
  local pct=$1 remaining=$2 window=$3 elapsed projected
  [ "$SHOW_PACE" != "1" ] && return
  [ -z "$pct" ] && return
  elapsed=$((window - remaining))
  [ "$elapsed" -lt "$PACE_MIN_ELAPSED" ] || [ "$elapsed" -ge "$window" ] && return
  projected=$((pct * window / elapsed))
  [ "$projected" -gt 999 ] && projected=999
  [ "$projected" -le "$pct" ] && return
  printf ' · on pace for %d%%' "$projected"
}

# label, percentage, note, marker-cell -> one spaced bar row
bar_row() {
  local label=$1 pct=$2 note=$3 mcell=${4:--1} cue colour lead
  [ -z "$pct" ] && return
  pct=${pct%.*}
  [ "$pct" -lt 0 ] && pct=0
  [ "$pct" -gt 100 ] && pct=100
  colour=$(level_colour "$pct")
  # Shape cue so the alarm is not carried by colour alone.
  if [ "$pct" -ge "$DANGER_PCT" ]; then cue="$DANGER_CUE"
  else printf -v cue '%*s' "${#DANGER_CUE}" ""; fi
  if [ "$SHOW_SPACERS" = "1" ]; then lead=$'\n'"$SPACER"$'\n'; else lead=$'\n'; fi
  printf '%s%s%-*s%s %s %s%s%3d%%%s' \
    "$lead" "$C_TEXT" "$LABEL_WIDTH" "$label" "$C_RESET" \
    "$(make_bar "$pct" "$mcell")" "$colour" "$cue" "$pct" "$C_RESET"
  [ -n "$note" ] && printf '  %s%s%s' "$C_TEXT" "$note" "$C_RESET"
}

human_tokens() {
  awk -v n="$1" 'BEGIN {
    if (n >= 1000000) printf "%.1fM", n / 1000000;
    else printf "%.0fk", n / 1000
  }'
}

# ------------------------------------------------------------------ line 1 ---
segs=()
head_seg="$C_MODEL$model$C_RESET"
if [ "$SHOW_MODES" = "1" ]; then
  modes=()
  [ -n "$effort" ] && modes+=("$effort")
  [ -n "$thinking" ] && modes+=("thinking")
  [ -n "$fast" ] && modes+=("fast")
  [ -n "$style" ] && modes+=("$style")
  if [ ${#modes[@]} -gt 0 ]; then
    printf -v mode_str "%s$MODE_SEP" "${modes[@]}"
    head_seg+="${C_TEXT}${MODE_SEP}${mode_str%$MODE_SEP}${C_RESET}"
  fi
fi
segs+=("$head_seg")
[ "$SHOW_DIR" = "1" ] && segs+=("$C_DIR$dir$C_RESET")

# git state, cached briefly: status walks the worktree on every render otherwise
if [ "$SHOW_GIT" = "1" ] && git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  cache_dir="${TMPDIR:-/tmp}/claude-statusline"
  mkdir -p "$cache_dir" 2>/dev/null
  cache_key=$(printf '%s' "$cwd" | md5 -q 2>/dev/null || printf '%s' "$cwd" | md5sum | cut -d' ' -f1)
  cache_file="$cache_dir/$cache_key"
  git_line=""
  if [ -f "$cache_file" ]; then
    age=$(( $(date +%s) - $(stat -f %m "$cache_file" 2>/dev/null || stat -c %Y "$cache_file" 2>/dev/null || echo 0) ))
    [ "$age" -lt "$GIT_CACHE_TTL" ] && git_line=$(cat "$cache_file" 2>/dev/null)
  fi
  if [ -z "$git_line" ]; then
    branch=$(git -C "$cwd" branch --show-current 2>/dev/null)
    [ -z "$branch" ] && branch=$(git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
    dirty=""
    # index-based check first; only walk for untracked files if it comes back clean
    if ! git -C "$cwd" diff --quiet HEAD 2>/dev/null; then
      dirty="*"
    elif [ -n "$(git -C "$cwd" ls-files --others --exclude-standard 2>/dev/null | head -1)" ]; then
      dirty="*"
    fi
    git_line="$branch$dirty"
    printf '%s' "$git_line" > "$cache_file" 2>/dev/null
  fi
  [ -n "$git_line" ] && segs+=("$C_GIT$git_line$C_RESET")
fi

# Session churn and spend. These are Claude's edits this session, not git state,
# so they get their own segment rather than riding along with the branch.
tail_bits=()
if [ "$SHOW_CHURN" = "1" ] && [ -n "$lines_add" ] && [ -n "$lines_rem" ] \
   && [ $((lines_add + lines_rem)) -gt 0 ]; then
  tail_bits+=("edited +$lines_add/-$lines_rem")
fi
if [ "$SHOW_COST" = "1" ] && [ -n "$cost_usd" ]; then
  cost_fmt=$(awk -v c="$cost_usd" 'BEGIN { printf "$%.2f", c }')
  [ "$cost_fmt" != '$0.00' ] && tail_bits+=("$cost_fmt")
fi
if [ ${#tail_bits[@]} -gt 0 ]; then
  printf -v tail_str "%s$MODE_SEP" "${tail_bits[@]}"
  segs+=("${C_TEXT}${tail_str%$MODE_SEP}${C_RESET}")
fi

line1=""
for seg in "${segs[@]}"; do
  if [ -z "$line1" ]; then line1="$seg"; else line1+="${C_TEXT}${SEP}${C_RESET}$seg"; fi
done
printf '%s' "$line1"

# -------------------------------------------------------------------- bars ---
now=$(date +%s)

five_note=""
if [ -n "$five_reset" ]; then
  remaining=$((five_reset - now))
  [ "$SHOW_RESETS" = "1" ] && five_note=$(until_reset "$remaining")
  five_note+=$(on_pace "${five_pct%.*}" "$remaining" "$SESSION_WINDOW")
  five_note=${five_note# · }
fi

week_note=""
if [ -n "$week_reset" ] && [ "$SHOW_RESETS" = "1" ]; then
  week_note=$(until_reset $((week_reset - now)))
fi

# Auto-compact threshold. Claude Code resolves an "auto" window internally and
# does not report it, so the tick only appears when a threshold is configured.
compact_cell=-1
ctx_note=""
if [ -n "$ctx_used" ] && [ -n "$ctx_size" ]; then
  [ "$SHOW_TOKENS" = "1" ] && ctx_note="$(human_tokens "$ctx_used") / $(human_tokens "$ctx_size")"
  cpct="$COMPACT_PCT"
  if [ -z "$cpct" ] && [ -n "$CLAUDE_AUTOCOMPACT_PCT_OVERRIDE" ]; then
    cpct=$CLAUDE_AUTOCOMPACT_PCT_OVERRIDE
  fi
  if [ -z "$cpct" ]; then
    win=$(grep -oE '"autoCompactWindow"[[:space:]]*:[[:space:]]*[0-9]+' \
      "$HOME/.claude/settings.json" 2>/dev/null | grep -oE '[0-9]+$' | tail -1)
    [ -n "$win" ] && cpct=$((win * 100 / ctx_size))
  fi
  if [ -n "$cpct" ] && [ "$cpct" -gt 0 ] && [ "$cpct" -le 100 ]; then
    compact_cell=$((cpct * BAR_WIDTH / 100))
    [ "$compact_cell" -ge "$BAR_WIDTH" ] && compact_cell=$((BAR_WIDTH - 1))
    [ -n "$ctx_note" ] && ctx_note+=" · "
    ctx_note+="compacts at ${cpct}%"
  fi
fi

[ "$SHOW_SESSION" = "1" ] && bar_row "$LABEL_SESSION" "$five_pct" "$five_note"
[ "$SHOW_WEEK" = "1" ]    && bar_row "$LABEL_WEEK"    "$week_pct" "$week_note"
[ "$SHOW_CONTEXT" = "1" ] && bar_row "$LABEL_CONTEXT" "$ctx_pct"  "$ctx_note" "$compact_cell"

exit 0
