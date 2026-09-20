unset HISTFILE
HISTSIZE=10000
SAVEHIST=0

command -v atuin >/dev/null 2>&1 && eval "$(atuin init zsh --disable-up-arrow)"
