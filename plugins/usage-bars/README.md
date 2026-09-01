# usage-bars

A multi-line status line for [Claude Code](https://claude.com/claude-code). Shows your
session and weekly rate limits alongside context window usage, as three aligned bars.

```
Opus 5 · high · thinking | ~/dev | main* | edited +214/-31 · $0.92

Session ██░░░░░░░░░░░░░░░░░░   9%  resets in 4h 31m · on pace for 22%

Week    ███░░░░░░░░░░░░░░░░░  16%  resets in 3d 15h

Context █████░┊░░░░░░░░░░░░░  26%  52k / 200k · compacts at 30%
```

Every value comes from the JSON payload Claude Code pipes to the status line command
on stdin. Nothing is scraped, guessed, or fetched over the network.

## Install

As a plugin, from the [claude-kit](https://github.com/realkewal/claude-kit) marketplace:

```
/plugin marketplace add realkewal/claude-kit
/plugin install usage-bars@claude-kit
/usage-bars:install
```

The third step is not redundant. Claude Code's plugin system does not allow
plugins to provide a status line (`statusLine` is excluded from plugin-provided
customizations), so installing the plugin gives you the command, and the command
writes the `settings.json` entry.

Or standalone, without the marketplace:

```sh
git clone https://github.com/realkewal/claude-kit
cd claude-kit/plugins/usage-bars/scripts
./install.sh
```

Either path copies `statusline.sh` and `statusline.conf` into `~/.claude/` and points
the `statusLine` entry in `~/.claude/settings.json` at the installed script. Your
existing status line and settings.json are backed up with a timestamp first. The
status line appears on the next render.

Useful flags:

| Flag | Effect |
| --- | --- |
| `--dry-run` | Print what would happen, change nothing |
| `--prefix DIR` | Install somewhere other than `~/.claude` |
| `--force-conf` | Replace an existing `statusline.conf` (default is to keep yours) |
| `--uninstall` | Remove the `statusLine` entry from settings.json |

Requires `bash`, `jq`, `git`, and `awk`. Works on bash 3.2, so stock macOS is fine.

## Configuring

Edit `~/.claude/statusline.conf`. It is sourced as plain bash, so it is `NAME=value`
with no spaces around the `=`. Changes apply on the next render, no restart needed.
Comment any line out to fall back to the built-in default, and delete the whole file
to run on defaults entirely.

The config is looked up in this order, first match winning:

1. `$CLAUDE_STATUSLINE_CONF`
2. `~/.claude/statusline.conf`
3. `statusline.conf` sitting next to the script

### Options

**Layout**

| Option | Default | Meaning |
| --- | --- | --- |
| `BAR_WIDTH` | `20` | Cells per bar. All bars share the width, so they stay aligned. |
| `LABEL_WIDTH` | `7` | Label column width, counted in bytes. Keep labels ASCII. |
| `SHOW_SPACERS` | `1` | Blank row between bars. `0` packs them together. |

**Which bars**

`SHOW_SESSION`, `SHOW_WEEK`, `SHOW_CONTEXT`, all `1` by default.

**Header segments**

`SHOW_MODES` (effort, thinking, fast, output style), `SHOW_DIR`, `SHOW_GIT`,
`SHOW_CHURN` (lines Claude edited this session), `SHOW_COST` (session spend).
All `1` by default.

**Notes after each bar**

| Option | Default | Meaning |
| --- | --- | --- |
| `SHOW_RESETS` | `1` | `resets in 4h 31m` |
| `SHOW_PACE` | `1` | `on pace for 41%`, projected from the rate so far |
| `SHOW_TOKENS` | `1` | `41k / 1.0M` on the context bar |
| `PACE_MIN_ELAPSED` | `1200` | Seconds into a window before the projection appears |
| `SESSION_WINDOW` | `18000` | Length of the session rate-limit window, in seconds |

**Thresholds**

| Option | Default | Meaning |
| --- | --- | --- |
| `WARN_PCT` | `60` | Bar turns amber at or above this |
| `DANGER_PCT` | `85` | Bar turns red and gains the cue at or above this |
| `DANGER_CUE` | `"! "` | Marker before the percentage past `DANGER_PCT` |

**Glyphs and labels**

`BAR_FILL`, `BAR_EMPTY`, `BAR_MARK`, `SEP`, `MODE_SEP`, `LABEL_SESSION`,
`LABEL_WEEK`, `LABEL_CONTEXT`.

**Colours**

Raw SGR parameters, without the escape or the trailing `m`:

```sh
COLOR_MODEL="36"          # basic ANSI, follows your terminal theme
COLOR_TEXT="38;5;245"     # fixed 256-colour index
COLOR_OK="38;2;46;204;113" # 24-bit truecolour
COLOR_GIT=""              # no colour
```

Available: `COLOR_MODEL`, `COLOR_DIR`, `COLOR_GIT`, `COLOR_TEXT`, `COLOR_TROUGH`,
`COLOR_MARK`, `COLOR_OK`, `COLOR_WARN`, `COLOR_DANGER`.

**Performance**

`GIT_CACHE_TTL` (default `3`) is how many seconds git state is reused. Raising it is
cheaper in large repos; the cost is that a fresh edit can show a stale dirty marker
for that long.

## The auto-compact tick

`BAR_MARK` on the context bar shows where auto-compaction fires, so the tail of the
bar does not imply headroom you do not have.

Claude Code resolves its "auto" compact window internally and does not report it in
the status line payload or write it to any readable config, so **no tick is drawn by
default**. It appears once a threshold is actually known, from any of:

1. `COMPACT_PCT` in the config
2. the `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` environment variable
3. `autoCompactWindow` in `~/.claude/settings.json`, which `/config` sets

Guessing a default here would have been wrong more often than right, so it stays off
until one of those says otherwise.

## Accessibility

- ANSI dim (SGR 2) is not used anywhere. Many terminals render it at roughly 40%
  opacity, which fails contrast on both light and dark themes. Explicit greys are
  used instead, and every one is configurable.
- Past `DANGER_PCT` a bar gains a `!` cue as well as turning red, so the alarm is not
  carried by colour alone. The cue's width is reserved on every row, so the
  percentage column stays aligned whether or not it is showing.
- Every bar is labelled and carries its numeric percentage. The bar is redundant
  encoding, not the only channel.

## Notes for anyone modifying this

Three things about this environment cost real debugging time. They are easy to
reintroduce.

**Claude Code deletes blank rows.** Status line stdout is post-processed as:

```js
stdout.trim().split("\n").flatMap(l => l.trim() || []).join("\n")
```

Every row is trimmed and any row that is empty afterwards is dropped, so a spacer row
of `" "` silently vanishes. The spacer here is U+2800 (braille blank), which JS
`trim()` does not treat as whitespace, so the row survives and still renders blank.
U+200B also survives but has zero width, which risks the row collapsing. NBSP
(U+00A0) and the BOM are both stripped by `trim()` and do not work.

**bash 3.2 has no `\u` escape.** Stock macOS ships bash 3.2.57, so `$'⠀'` is not
available. The spacer is written as raw UTF-8 bytes, `$'\xe2\xa0\x80'`.

**Brace expansions before non-ASCII characters.** `"$C_TEXT·"` makes bash fold the
`·` UTF-8 lead byte into the variable name, so both the escape and half the character
disappear. Write `"${C_TEXT}·"`. This fails silently and produces invalid UTF-8.

Beyond that: the payload is read with a single `jq` call joined on a unit separator,
because tab is an IFS-whitespace character and consecutive tabs would collapse, losing
empty fields. Git state is cached briefly because `git status` walks the whole
worktree on every render.

## Uninstall

```
/usage-bars:uninstall
```

or directly:

```sh
./scripts/install.sh --uninstall
```

Removes the `statusLine` entry from settings.json and backs the file up first. The
installed `statusline.sh` and `statusline.conf` are left in `~/.claude/` for you to
delete if you want them gone.
