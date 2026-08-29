#!/usr/bin/env sh

set -eu

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

echo ">>> mise bootstrap is done!"
