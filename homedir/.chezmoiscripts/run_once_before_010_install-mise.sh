#!/usr/bin/env sh

set -eu

# sh, not zsh: `mise bootstrap` installs zsh later in this same run.

if [ ! -x "$HOME/.local/bin/mise" ]; then
  echo "==> Installing mise..."
  curl -fsSL https://mise.run | sh
fi
