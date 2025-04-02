#!/bin/sh

set -eu

dotfiles_bootstrap/install_chezmoi.sh

hash brew &> /dev/null || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
source ~/.zprofile

brew install chezmoi
chezmoi init --apply --force
brew bundle --global

source ~/.zshrc

cat .tool-versions | while read v;do asdf plugin add $(cut -f1 -d' ' <<<$v);done
asdf install

command -v helm >/dev/null && helm plugin install https://github.com/databus23/helm-diff || true
