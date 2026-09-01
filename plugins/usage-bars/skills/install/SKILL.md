---
description: Install the usage status line into settings.json. Pass "--dry-run" to preview without changing anything.
disable-model-invocation: true
---

# Install the status line

Claude Code does not let plugins set a status line directly (plugin-provided
customizations exclude `statusLine`), so this command runs the bundled installer,
which copies the script into the user's Claude directory and writes the
`statusLine` entry in their `settings.json`.

## Steps

1. Check that `jq` is available. If it is missing, tell the user to install it
   (`brew install jq` on macOS) and stop. The installer checks this too, but
   failing early gives a clearer message.

2. Run the installer, passing through any argument the user gave:

   ```sh
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/install.sh" $ARGUMENTS
   ```

   With no arguments this installs to `~/.claude`. Supported flags are
   `--dry-run`, `--prefix DIR`, `--force-conf`, and `--uninstall`.

3. The installer backs up any existing `statusline.sh` and `settings.json` with a
   timestamp, refuses to install if the script fails `bash -n`, refuses to touch a
   `settings.json` that is not valid JSON, and keeps an existing
   `statusline.conf` unless `--force-conf` is passed.

4. It finishes by running a smoke test against a sample payload and printing the
   rendered output. Show that output to the user so they can see what they are
   getting.

## After installing

Tell the user:

- The status line appears on the next render. If they do not see it, a new
  session will definitely pick it up.
- Everything is configurable in `~/.claude/statusline.conf`: bar width, which
  bars and segments show, thresholds, glyphs, labels, and colours. Changes apply
  on the next render, with no restart.
- The auto-compact tick on the context bar stays hidden unless a threshold is
  actually known, because Claude Code resolves its "auto" compact window
  internally and does not report it. Setting a window via `/config` makes the
  tick appear.

Do not edit the installed `~/.claude/statusline.sh` directly to customise it. Any
reinstall overwrites it. Use the config file.
