#!/usr/bin/env zsh


if [ -f ~/.secrets/ssh/cat ]; then
  echo "Enter CAT SSH key passphrase"
  if [ "$OS" = "darwin" ]; then
    ssh-add --apple-use-keychain ~/.secrets/ssh/cat
  else
    ssh-add -l | grep -q "$(ssh-keygen -lf ~/.secrets/ssh/cat | awk '{print $2}')" || ssh-add ~/.secrets/ssh/cat
  fi
fi
