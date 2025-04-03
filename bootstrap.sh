#!/bin/bash

set -eu

sh -c "$(curl -fsLS get.chezmoi.io/lb)" -- init --apply

command -v brew &> /dev/null || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

source ~/.zprofile ~/.asdf/asdf.sh

brew bundle --global

cat .tool-versions | while read v;do asdf plugin add $(cut -f1 -d' ' <<<$v);done
asdf install && asdf list

command -v helm &>/dev/null && helm plugin install https://github.com/databus23/helm-diff || true

pre-commit install --install-hooks

echo ">>> Installation is done!"
