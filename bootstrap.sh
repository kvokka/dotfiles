#!/bin/bash

set -eu

sh -c "$(curl -fsLS get.chezmoi.io/lb)" -- init --apply --force --purge-binary

command -v brew &> /dev/null || NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
source ~/.zsh/homebrew.zsh

brew bundle --global
mise install

command -v helm &>/dev/null && helm plugin install https://github.com/databus23/helm-diff || true

pre-commit install --install-hooks

echo ">>> Installation is done!"
