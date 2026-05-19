#!/usr/bin/env zsh


if [ -f ~/.ssh/cat ]; then
  echo "Enter CAT SSH key passphrase"
  if [ "$OS" = "darwin" ]; then
    ssh-add --apple-use-keychain ~/.ssh/cat
  else
    eval $(keychain --eval --agents ssh cat)
  fi
fi
