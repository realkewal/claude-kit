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

# A repo with a planted .git/config must not get its commands run on render.
# The edit lands in the same second as the commit, so diff-index sees it as
# racily clean and would read it through the filter if one were left active.
repo=$(mktemp -d)
trap 'rm -f "$conf"; rm -rf "$repo"' EXIT
git init -q -b main "$repo/r" && echo a > "$repo/r/f" && echo '* filter=x' > "$repo/r/.gitattributes"
git -C "$repo/r" add . && git -C "$repo/r" -c user.name=t -c user.email=t@t commit -qm init
git -C "$repo/r" config core.fsmonitor "touch $repo/fsmonitor; false"
git -C "$repo/r" config filter.x.clean "touch $repo/filter; cat"
echo b > "$repo/r/f"
# A git that only leaves a trace, to prove the default render never calls git.
mkdir "$repo/bin" && printf '#!/bin/sh\ntouch "%s/ran-git"\n' "$repo" > "$repo/bin/git"
chmod +x "$repo/bin/git"

# cwd [VAR=value ...] -> header line, colours stripped
render_repo() {
  local cwd=$1; shift
  printf '{"workspace":{"current_dir":"%s"}}' "$cwd" \
    | env CLAUDE_STATUSLINE_CONF="$conf" XDG_CACHE_HOME="$repo/cache" "$@" bash "$dir/statusline.sh" \
    | sed $'s/\033\\[[0-9;]*m//g' | head -1
}

out=$(render_repo "$repo/r" PATH="$repo/bin:$PATH")
check "default render shows the branch" "$out" "| main" 1
check "default render has no dirty marker" "$out" "main*" 0
check "default render never runs git" "$(ls "$repo")" "ran-git" 0

out=$(render_repo "$repo/r" SHOW_DIRTY=1)
check "SHOW_DIRTY=1 shows the dirty marker" "$out" "main*" 1
check "planted fsmonitor never runs" "$(ls "$repo")" "fsmonitor" 0
check "planted filter never runs" "$(ls "$repo")" "filter" 0

# Worktrees have a .git file pointing elsewhere, not a .git directory. Rendering
# from a subfolder also covers the walk up to the repo root.
git -C "$repo/r" -c core.fsmonitor=false -c filter.x.clean=cat worktree add -q -b wt "$repo/wt" 2>/dev/null
mkdir "$repo/wt/sub"
check "worktree branch read through its .git file" "$(render_repo "$repo/wt/sub")" "| wt" 1

# The config is data. Command substitution, arithmetic that evaluates array
# subscripts, and names the script does not own must all be ignored.
bad=$(mktemp)
trap 'rm -f "$conf" "$bad"; rm -rf "$repo"' EXIT
cat > "$bad" <<EOF
\$(touch "$repo/conf-ran")
SEP="\$(touch $repo/conf-ran)"
BAR_WIDTH='a[\$(touch $repo/conf-ran)]'
COLOR_OK="32m\$(touch $repo/conf-ran)"
PATH=/nonexistent
LABEL_SESSION='Five hr'
EOF
out=$(render_repo "$repo/r" CLAUDE_STATUSLINE_CONF="$bad")
check "hostile config runs nothing" "$(ls "$repo")" "conf-ran" 0
check "quoted values are literal, not expanded" "$out" '$(touch' 1
full=$(printf '{"workspace":{"current_dir":"/"},"rate_limits":{"five_hour":{"used_percentage":5,"resets_at":%s}}}' \
  $((now + 600)) | env CLAUDE_STATUSLINE_CONF="$bad" SHOW_GIT=0 bash "$dir/statusline.sh" \
  | sed $'s/\033\\[[0-9;]*m//g')
check "valid lines in a hostile config still apply" "$full" "Five hr" 1
check "rejected BAR_WIDTH falls back to 20 cells" "$full" "█░░░░░░░░░░░░░░░░░░░" 1

# Valid edge cases: an export prefix, an empty colour, and % and * in a
# separator. Invalid ones keep their default: a leading zero (bash would read it
# as octal) and an unclosed quote. The model name carries escape bytes.
odd=$(mktemp)
trap 'rm -f "$conf" "$bad" "$odd"; rm -rf "$repo"' EXIT
cat > "$odd" <<'EOF'
export LABEL_SESSION=Exported
COLOR_OK=""
MODE_SEP=" %s* "
BAR_WIDTH=010
LABEL_CONTEXT="Unclosed
EOF
out=$(jq -n --argjson r $((now + 600)) '{model: {display_name: "M\u001b]0;pwn\u0007"},
    effort: {level: "high"}, thinking: {enabled: true}, workspace: {current_dir: "/"},
    context_window: {used_percentage: 5, total_input_tokens: 1, context_window_size: 2},
    rate_limits: {five_hour: {used_percentage: 5, resets_at: $r}}}' \
  | env CLAUDE_STATUSLINE_CONF="$odd" SHOW_GIT=0 bash "$dir/statusline.sh")
plain=$(printf '%s' "$out" | sed $'s/\033\\[[0-9;]*m//g')
check "export prefix is accepted" "$plain" "Exported" 1
check "separator % and * stay literal" "$plain" "high %s* thinking" 1
check "leading-zero number keeps the default" "$plain" "█░░░░░░░░░░░░░░░░░░░" 1
check "unclosed quote keeps the default" "$plain" "Context" 1
check "empty colour means no colour" "$out" "$(printf '\033')[32m█" 0
check "model name escape bytes are stripped" "$out" "$(printf '\033')]0" 0

# Escape bytes in a folder name must not reach the terminal.
esc_dir="$repo/x$(printf '\033')]0;pwn$(printf '\007')y"
mkdir "$esc_dir"
out=$(jq -n --arg d "$esc_dir" '{workspace: {current_dir: $d}}' \
  | env CLAUDE_STATUSLINE_CONF="$conf" bash "$dir/statusline.sh")
check "folder name escape bytes are stripped" "$out" "$(printf '\033')]0" 0

[ "$fails" -eq 0 ] && echo "all passed" || { echo "$fails failed"; exit 1; }
