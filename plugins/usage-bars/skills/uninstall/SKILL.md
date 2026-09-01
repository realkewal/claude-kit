---
description: Remove the usage status line from settings.json, backing the file up first.
disable-model-invocation: true
---

# Remove the status line

Run:

```sh
bash "${CLAUDE_PLUGIN_ROOT}/scripts/install.sh" --uninstall
```

This backs up `settings.json` with a timestamp and deletes only its `statusLine`
entry. Nothing else in the file is touched.

The installed `~/.claude/statusline.sh` and `~/.claude/statusline.conf` are left
in place on purpose, so a reinstall keeps the user's customisations. Mention this,
and offer to delete them if the user wants a clean removal:

```sh
rm -f ~/.claude/statusline.sh ~/.claude/statusline.conf
```

If the user only wants to hide the status line temporarily, point out that
uninstalling is not the only option: they can set `SHOW_SESSION=0`,
`SHOW_WEEK=0`, and `SHOW_CONTEXT=0` in the config to strip it back to the single
header line, which is reversible without reinstalling.
