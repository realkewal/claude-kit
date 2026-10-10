#!/bin/bash
# Smoke test for the pace projection. Feeds statusline.sh fixed payloads and
# asserts on the rendered text. Run: bash plugins/usage-bars/scripts/check.sh

dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
conf=$(mktemp)          # empty config, so a user's own statusline.conf can't leak in
trap 'rm -f "$conf"' EXIT
now=$(date +%s)
fails=0

# five_pct five_left week_pct week_left [VAR=value ...] -> plain text, colours stripped
render() {
  local payload
  payload=$(printf '{"model":{"display_name":"Test"},"workspace":{"current_dir":"/"},
    "rate_limits":{"five_hour":{"used_percentage":%s,"resets_at":%s},
                   "seven_day":{"used_percentage":%s,"resets_at":%s}}}' \
    "$1" $((now + $2)) "$3" $((now + $4)))
  shift 4
  printf '%s' "$payload" | env CLAUDE_STATUSLINE_CONF="$conf" SHOW_GIT=0 "$@" \
    bash "$dir/statusline.sh" | sed $'s/\033\\[[0-9;]*m//g'
}

check() { # description, haystack, needle, expect (1 = present, 0 = absent)
  if printf '%s' "$2" | grep -qF -- "$3"; then got=1; else got=0; fi
  if [ "$got" = "$4" ]; then echo "ok   $1"; else echo "FAIL $1"; fails=$((fails + 1)); fi
}

# Week 16% used with 3d 15h left: 81h elapsed, so 16 * 168 / 81 = 33%.
out=$(render 9 16260 16 313200)
week=$(printf '%s\n' "$out" | grep '^Week')
check "week bar shows its projection" "$week" "resets in 3d 15h · on pace for 33%" 1
check "session projection still works" "$out" "on pace for 93%" 1

# Only 4h into the week: below the 12h minimum, so no week projection.
week=$(render 9 16260 2 590400 | grep '^Week')
check "week projection waits for WEEK_PACE_MIN_ELAPSED" "$week" "on pace" 0

# Projection without resets must not start with a dangling separator.
week=$(render 9 16260 16 313200 SHOW_RESETS=0 | grep '^Week')
check "projection alone has no leading separator" "$week" "16%  on pace for 33%" 1

# SHOW_PACE=0 turns off both projections.
check "SHOW_PACE=0 hides all projections" "$(render 9 16260 16 313200 SHOW_PACE=0)" "on pace" 0

[ "$fails" -eq 0 ] && echo "all passed" || { echo "$fails failed"; exit 1; }
