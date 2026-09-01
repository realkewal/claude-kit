#!/usr/bin/env bash
# Install the Claude Code status line: copy the script and config into place,
# then point settings.json at it. Existing files are backed up, never clobbered.
set -euo pipefail

SRC_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PREFIX="${PREFIX:-$HOME/.claude}"
DRY_RUN=0
FORCE_CONF=0

usage() {
  cat <<'USAGE'
Usage: ./install.sh [options]

  --prefix DIR    install into DIR instead of ~/.claude
  --force-conf    overwrite an existing statusline.conf (default: keep yours)
  --dry-run       print what would happen, change nothing
  --uninstall     remove the statusLine entry from settings.json
  -h, --help      show this

The script is installed to PREFIX/statusline.sh and the config to
PREFIX/statusline.conf. Your settings.json statusLine entry is rewritten to
point at the installed script. Edit the installed config, not this directory,
unless you plan to reinstall.
USAGE
}

UNINSTALL=0
while [ $# -gt 0 ]; do
  case "$1" in
    --prefix) PREFIX="$2"; shift 2 ;;
    --force-conf) FORCE_CONF=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --uninstall) UNINSTALL=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

say() { printf '%s\n' "$*"; }
run() { if [ "$DRY_RUN" = 1 ]; then say "  would: $*"; else "$@"; fi; }

SETTINGS="$PREFIX/settings.json"
STAMP=$(date +%Y%m%d-%H%M%S)

# ------------------------------------------------------------ dependencies ---
missing=()
command -v jq >/dev/null 2>&1 || missing+=("jq")
command -v git >/dev/null 2>&1 || missing+=("git")
command -v awk >/dev/null 2>&1 || missing+=("awk")
if [ ${#missing[@]} -gt 0 ]; then
  say "Missing required commands: ${missing[*]}"
  say "On macOS: brew install ${missing[*]}"
  exit 1
fi

# --------------------------------------------------------------- uninstall ---
if [ "$UNINSTALL" = 1 ]; then
  if [ ! -f "$SETTINGS" ]; then
    say "No settings.json at $SETTINGS, nothing to remove."
    exit 0
  fi
  say "Removing statusLine entry from $SETTINGS"
  run cp "$SETTINGS" "$SETTINGS.bak.$STAMP"
  if [ "$DRY_RUN" = 0 ]; then
    tmp=$(mktemp)
    jq 'del(.statusLine)' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
  fi
  say "Done. $PREFIX/statusline.sh and .conf were left in place; delete them if you want."
  exit 0
fi

# ------------------------------------------------------------------ verify ---
for f in statusline.sh statusline.conf; do
  [ -f "$SRC_DIR/$f" ] || { say "Missing $SRC_DIR/$f"; exit 1; }
done
bash -n "$SRC_DIR/statusline.sh" || { say "statusline.sh has a syntax error, refusing to install"; exit 1; }

say "Installing into $PREFIX"
[ "$DRY_RUN" = 1 ] && say "(dry run, nothing will be written)"
run mkdir -p "$PREFIX"

# ------------------------------------------------------------------ script ---
if [ -f "$PREFIX/statusline.sh" ] && ! cmp -s "$SRC_DIR/statusline.sh" "$PREFIX/statusline.sh"; then
  say "Backing up existing statusline.sh to statusline.sh.bak.$STAMP"
  run cp "$PREFIX/statusline.sh" "$PREFIX/statusline.sh.bak.$STAMP"
fi
run cp "$SRC_DIR/statusline.sh" "$PREFIX/statusline.sh"
run chmod +x "$PREFIX/statusline.sh"
say "  statusline.sh installed"

# ------------------------------------------------------------------ config ---
if [ -f "$PREFIX/statusline.conf" ] && [ "$FORCE_CONF" = 0 ]; then
  say "  statusline.conf already exists, keeping yours (--force-conf to replace)"
else
  if [ -f "$PREFIX/statusline.conf" ]; then
    say "Backing up existing statusline.conf to statusline.conf.bak.$STAMP"
    run cp "$PREFIX/statusline.conf" "$PREFIX/statusline.conf.bak.$STAMP"
  fi
  run cp "$SRC_DIR/statusline.conf" "$PREFIX/statusline.conf"
  say "  statusline.conf installed"
fi

# ---------------------------------------------------------------- settings ---
if [ ! -f "$SETTINGS" ]; then
  say "Creating $SETTINGS"
  run sh -c "printf '{}\n' > '$SETTINGS'"
else
  run cp "$SETTINGS" "$SETTINGS.bak.$STAMP"
  say "  settings.json backed up to settings.json.bak.$STAMP"
fi

if [ "$DRY_RUN" = 0 ]; then
  if ! jq empty "$SETTINGS" 2>/dev/null; then
    say "$SETTINGS is not valid JSON. Fix it and rerun; nothing else was changed."
    exit 1
  fi
  tmp=$(mktemp)
  jq --arg cmd "bash $PREFIX/statusline.sh" \
    '.statusLine = {type: "command", command: $cmd}' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
fi
say "  settings.json statusLine points at $PREFIX/statusline.sh"

# ------------------------------------------------------------ smoke test ---
if [ "$DRY_RUN" = 0 ]; then
  sample='{"model":{"display_name":"Test"},"effort":{"level":"high"},"thinking":{"enabled":true},
  "workspace":{"current_dir":"'"$HOME"'"},"cost":{"total_cost_usd":1.5,"total_lines_added":10,"total_lines_removed":2},
  "context_window":{"used_percentage":42,"total_input_tokens":84000,"context_window_size":200000},
  "rate_limits":{"five_hour":{"used_percentage":30,"resets_at":'"$(( $(date +%s) + 3600 ))"'},
  "seven_day":{"used_percentage":90,"resets_at":'"$(( $(date +%s) + 200000 ))"'}}}'
  out=$(printf '%s' "$sample" | bash "$PREFIX/statusline.sh") || {
    say "Smoke test failed: the script exited non-zero."
    exit 1
  }
  [ -n "$out" ] || { say "Smoke test failed: no output."; exit 1; }
  say ""
  say "Smoke test output:"
  printf '%s\n' "$out"
  say ""
fi

say "Done. Restart Claude Code, or start a new session, to pick it up."
say "Tune it by editing $PREFIX/statusline.conf; changes apply on the next render."
