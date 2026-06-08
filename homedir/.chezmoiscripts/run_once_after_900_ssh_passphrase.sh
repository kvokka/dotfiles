#!/usr/bin/env zsh

KEY="$HOME/.secrets/ssh/cat"

if [[ -f "$KEY" ]] && ! ssh-add -l &>/dev/null | grep -q "$(ssh-keygen -lf "$KEY" 2>/dev/null | awk '{print $2}')"; then
    echo "🔑 Adding CAT SSH key to ssh-agent..."

    if [[ "$(uname -s)" == "Darwin" ]]; then
        ssh-add --apple-use-keychain "$KEY"
    else
        ssh-add "$KEY"
    fi
fi
