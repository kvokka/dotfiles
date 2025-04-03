#!/bin/bash

set -eu

command -v brew &> /dev/null || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

case $(uname) in
  [Dd]arwin*)
    TMP_BREW_PATH="/opt/homebrew/bin/brew"
    ;;
  [Ll]inux*)
    TMP_BREW_PATH="/home/linuxbrew/.linuxbrew/bin/brew"
    # TODO: Kill this installation spike after brew 4.5 release
    go install github.com/asdf-vm/asdf/cmd/asdf@v0.16.7
    ;;
  *)
    echo "Unsupported operating system: '$(uname)'"; exit 1;;
esac
[ -f "$TMP_BREW_PATH" ] && eval "$($TMP_BREW_PATH shellenv)" && unset TMP_BREW_PATH

sh -c "$(curl -fsLS get.chezmoi.io/lb)" -- init --apply --no-tty --no-pager --force --purge-binary

brew bundle --global

source ~/.asdf/asdf.sh

cat .tool-versions | while read v;do asdf plugin add $(cut -f1 -d' ' <<<$v);done
asdf install && asdf list

command -v helm &>/dev/null && helm plugin install https://github.com/databus23/helm-diff || true

echo ">>> Installation is done!"
