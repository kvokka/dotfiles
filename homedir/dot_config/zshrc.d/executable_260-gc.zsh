# Gas City and Beads: only while mise's `gc` env is on (miserc.toml).

if mise_active gc; then
  # `gc` is Gas City here, not oh-my-zsh's git alias for `git commit --verbose`.
  unalias gc 2>/dev/null
  eval "$(gc completion zsh)"
fi

if mise_active bd; then
  eval "$(bd completion zsh)"
fi
