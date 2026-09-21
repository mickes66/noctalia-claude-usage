# Claude Usage — Noctalia plugin

A bar widget for [Noctalia](https://noctalia.dev) showing Claude Code's session and weekly rate-limit usage, right in your shell — the same numbers Omarchy's own `omarchy.agents` widget shows, since it reuses the same collector.

- **Left click**: notification with a quick session/weekly summary.
- **Right click**: opens a new Claude Code session in a terminal, running `claude --permission-mode auto` (auto-approves permission prompts — know that before you click).

## Dependencies

- [Noctalia](https://noctalia.dev) v5+ (`plugin_api = 3`)
- [Claude Code](https://claude.com/claude-code), logged in (`~/.claude/projects` transcripts and `~/.claude/.credentials.json` are what the collector reads)
- `python3` (stdlib only, no pip packages)
- `bash`, `jq`, `mktemp`, `mv` (all standard on any Linux install)

None of the above are Omarchy- or Arch-specific — see "On any other system" below.

## Install

```bash
mkdir -p ~/.local/share/noctalia/plugins
cp -r claude-usage ~/.local/share/noctalia/plugins/
```

(Or clone this repo directly into `~/.local/share/noctalia/plugins/claude-usage`.)

Then enable it: `noctalia msg plugins enable mickes/claude-usage`, and add the "Claude Usage" widget to your bar from Noctalia's Settings.

### On Omarchy

Works out of the box — it calls Omarchy's own `omarchy-agent-usage-update`, already on `PATH`.

### On any other system (confirmed working on CachyOS)

Omarchy's collector scripts have no actual Omarchy runtime dependency — they just aren't installed elsewhere by default. Copy the two bundled scripts from [`bin/`](bin/) to somewhere on your `PATH`:

```bash
mkdir -p ~/.local/bin
cp bin/omarchy-agent-usage-claude bin/omarchy-agent-usage-update ~/.local/bin/
```

Make sure `~/.local/bin` is on `PATH` for the user Noctalia runs as — if it isn't, edit the command in `usage.luau`'s `refresh()` to the absolute path instead (`~/.local/bin/omarchy-agent-usage-update`).

## How it works

`usage.luau` runs `omarchy-agent-usage-update claude` on a 60-second interval, then reads the JSON record it writes to `~/.local/state/omarchy/agents/usage/claude.json`. `omarchy-agent-usage-update` is a small orchestrator that finds sibling `omarchy-agent-usage-*` collector scripts (by `$OMARCHY_PATH/bin/` on Omarchy, or its own script directory otherwise) and writes each one's JSON output atomically to that state directory. `omarchy-agent-usage-claude` is the actual collector: it reads local Claude Code transcripts and hits Anthropic's OAuth usage endpoint for the authoritative rate-limit numbers.

## Attribution & License

`usage.luau`, `plugin.toml`, and `claude.svg` are original work, MIT licensed (see [LICENSE](LICENSE)).

`bin/omarchy-agent-usage-claude` and `bin/omarchy-agent-usage-update` are from the [Omarchy](https://github.com/omacom/omarchy) project (Copyright © David Heinemeier Hansson, MIT), bundled here for standalone portability off Omarchy. `bin/omarchy-agent-usage-update` carries a small local patch: it looks for sibling collectors in its own script directory instead of requiring `$OMARCHY_PATH`, so the pair works unmodified on any system.
