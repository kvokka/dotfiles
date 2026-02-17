#!/usr/bin/env zsh

source ~/.config/zshrc.d/010-brew.zsh

export MISE_JOBS=$(getconf _NPROCESSORS_ONLN 2>/dev/null || nproc)

if [ "${CODESPACES:-}" = "true" ] && [ "${CI_FULL:-}" != "true" ]; then
  export MISE_ENABLE_TOOLS="chezmoi"
fi

mise install

echo ">>> Mise install is done!"
