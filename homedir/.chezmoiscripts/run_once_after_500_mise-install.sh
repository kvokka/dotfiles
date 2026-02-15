#!/usr/bin/env zsh

source ~/.zsh/homebrew.zsh

export MISE_JOBS=$(getconf _NPROCESSORS_ONLN 2>/dev/null || nproc)

mise install

echo ">>> Mise install is done!"
