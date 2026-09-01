# claude-kit

A small marketplace of [Claude Code](https://claude.com/claude-code) plugins.

## Install

In Claude Code:

```
/plugin marketplace add realkewal/claude-kit
```

Then install what you want:

```
/plugin install usage-statusline@claude-kit
```

## What's in it

### usage-statusline

A multi-line status line showing your session and weekly rate limits alongside
context window usage, as three aligned bars.

```
Opus 5 · high · thinking | ~/dev | main* | edited +214/-31 · $0.92

Session ██░░░░░░░░░░░░░░░░░░   9%  resets in 4h 31m · on pace for 22%

Week    ███░░░░░░░░░░░░░░░░░  16%  resets in 3d 15h

Context █████░┊░░░░░░░░░░░░░  26%  52k / 200k · compacts at 30%
```

Rate limits are the thing Claude Code is quietest about, and the built-in status
line does not surface them at all. This puts both windows in front of you
continuously, with reset countdowns and a burn-rate projection so you can see you
are on pace to run out before the window resets, rather than finding out when it
happens.

Everything is configurable through a plain config file: bar width, which bars and
segments appear, warn and danger thresholds, glyphs, labels, and every colour.
No ANSI dim is used anywhere, and the danger state carries a shape cue as well as
a colour, so it holds up on light themes and without colour vision.

After installing the plugin, run `/usage-statusline:install` once. Claude Code does not
let plugins set a status line directly, so that command runs the bundled
installer, which writes the `settings.json` entry for you and backs up anything it
replaces.

Full documentation: [plugins/usage-statusline](plugins/usage-statusline).

## Requirements

`bash`, `jq`, `git`, and `awk`. Everything works on bash 3.2, so stock macOS is
fine with no upgrade.

## License

MIT. See [LICENSE](LICENSE).
