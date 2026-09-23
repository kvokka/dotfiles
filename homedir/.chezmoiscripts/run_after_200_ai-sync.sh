#!/usr/bin/env sh

set -eu

# chezmoi owns ~/.claude/settings.json, ~/.codex/config.toml and
# ~/.config/opencode/opencode.json as whole files, so an apply that rewrites
# one of them drops the keys rulesync added (hooks, MCP servers). Regenerate
# them after every apply; this is the only place `ai:sync` runs automatically,
# and it also covers the first apply, after run_once_after_100 has bootstrapped
# mise and its tools.
#
# ~/.config/rulesync and the `ai:sync` task exist only in the Linux
# devcontainer (see .chezmoiignore and config.fw.toml); elsewhere this is a
# no-op. Absolute mise path: chezmoi scripts run with chezmoi's own PATH, which
# has no ~/.local/bin.

[ -f "$HOME/.config/rulesync/rulesync.jsonc" ] || exit 0

mise="$HOME/.local/bin/mise"
if [ ! -x "$mise" ] || ! "$mise" which rulesync >/dev/null 2>&1; then
  echo "skip ai:sync: mise or rulesync not installed yet"
  exit 0
fi

"$mise" run ai:sync
