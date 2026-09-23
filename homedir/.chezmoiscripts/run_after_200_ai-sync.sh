#!/usr/bin/env sh

set -eu

# chezmoi still owns ~/.claude/settings.json, ~/.codex/config.toml and
# ~/.config/opencode/opencode.json as whole files, so every apply that rewrites
# one of them drops the keys rulesync added (hooks, MCP servers). Regenerate
# them after each apply; `ai:sync` is cheap and idempotent.
#
# Absolute mise path: chezmoi scripts run with chezmoi's own PATH, which has no
# ~/.local/bin. Skipped until the bootstrap has installed mise and rulesync
# (first apply, CI light mode).

mise="$HOME/.local/bin/mise"
if [ ! -x "$mise" ] || ! "$mise" which rulesync >/dev/null 2>&1; then
  echo "skip ai:sync: mise or rulesync not installed yet"
  exit 0
fi

"$mise" run ai:sync
