#!/bin/bash

set -eu

[[ ! -t 0 ]] && export NONINTERACTIVE=1 # Allow user to enter sudo pass for brew setup on mac
command -v brew &> /dev/null || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

command -v chezmoi &>/dev/null || sh -c "$(curl -fsLS get.chezmoi.io/lb)" -- init --apply --force --purge-binary ${@}

command -v compaudit &> /dev/null && compaudit | xargs chmod g-w
source ~/.zsh/homebrew.zsh

brew bundle --global
mise install

command -v helm &>/dev/null && helm plugin install https://github.com/databus23/helm-diff || true

echo ">>> Installation is done!"
