#!/usr/bin/env sh

set -eu

# sh, not zsh: `mise bootstrap` installs zsh later in this same run.

if [ ! -x "$HOME/.local/bin/mise" ]; then
  echo "==> Installing mise..."
  curl -fsSL https://mise.run | sh
fi

PATH="$HOME/.local/bin:$PATH"
export PATH

MISE_JOBS="$(getconf _NPROCESSORS_ONLN 2>/dev/null || nproc)"
export MISE_JOBS

# DOTFILES_BOOTSTRAP_SKIP carries `mise bootstrap --skip` parts; CI sets it to
# `packages` for its light run.
if [ -n "${DOTFILES_BOOTSTRAP_SKIP:-}" ]; then
  mise bootstrap --yes --skip "$DOTFILES_BOOTSTRAP_SKIP"
else
  mise bootstrap --yes
fi
