#!/usr/bin/env sh

set -eu

# sh, not zsh: `mise bootstrap` installs zsh in this same run.
#
# This runs after apply, not before: `mise bootstrap` reads
# ~/.config/mise/config.toml, and chezmoi writes that file during apply. Run
# before apply, mise sees an empty config, reports "all tools are installed"
# and installs nothing.

if [ ! -x "$HOME/.local/bin/mise" ]; then
  echo "==> Installing mise..."
  curl -fsSL https://mise.run | sh
fi

PATH="$HOME/.local/bin:$PATH"
export PATH

MISE_JOBS="$(getconf _NPROCESSORS_ONLN 2>/dev/null || nproc)"
export MISE_JOBS

# DOTFILES_BOOTSTRAP_SKIP carries `mise bootstrap --skip` parts, and
# DOTFILES_BOOTSTRAP_TOOLS the tools to install when `tools` is one of them.
# CI sets both for its light run.
if [ -n "${DOTFILES_BOOTSTRAP_SKIP:-}" ]; then
  mise bootstrap --yes --skip "$DOTFILES_BOOTSTRAP_SKIP"
else
  mise bootstrap --yes
fi

if [ -n "${DOTFILES_BOOTSTRAP_TOOLS:-}" ]; then
  # shellcheck disable=SC2086 # DOTFILES_BOOTSTRAP_TOOLS is a list of tools
  mise install $DOTFILES_BOOTSTRAP_TOOLS
  mise reshim
fi
