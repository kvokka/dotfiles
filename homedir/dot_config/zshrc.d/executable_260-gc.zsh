# Gas City and Beads (Linux devcontainer only; every block is guarded, so this
# file is harmless where the tools are absent).

if (( $+commands[gc] )); then
  # `gc` is Gas City here, not oh-my-zsh's git alias for `git commit --verbose`.
  unalias gc 2>/dev/null
  eval "$(gc completion zsh)"
fi

if (( $+commands[bd] )); then
  eval "$(bd completion zsh)"
fi
