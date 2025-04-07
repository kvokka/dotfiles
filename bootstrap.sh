#!/bin/bash

set -eu

sh -c "$(curl -fsLS get.chezmoi.io/lb)" -- init --apply --force --purge-binary

command -v brew &> /dev/null || NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Until brew 4.5 is out we have to install it manually, only if we are in codespaces
[ "$CODESPACES" = "true" ] && brew install --build-from-source go asdf

source ~/.zprofile ~/.asdf/asdf.sh

brew bundle --global

while read -r v || [[ -n "$v" ]]; do [[ -z "$v" ]] || asdf plugin add "$(cut -f1 -d' ' <<<"$v")"; done < ~/.tool-versions
asdf install && asdf list

command -v helm &>/dev/null && helm plugin install https://github.com/databus23/helm-diff || true

pre-commit install --install-hooks

echo ">>> Installation is done!"
