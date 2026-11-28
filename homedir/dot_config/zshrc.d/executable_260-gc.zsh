# Completions of the agent tools: Gas City and Beads only while mise's `gc` env
# is on (miserc.toml), then deja and t3.

if mise_active gc; then
  # `gc` is Gas City here, not oh-my-zsh's git alias for `git commit --verbose`.
  unalias gc 2>/dev/null
  eval "$(gc completion zsh)"
fi

if mise_active bd; then
  eval "$(bd completion zsh)"
fi

if mise_active deja; then
  eval "$(deja completion zsh)"
fi

# t3 takes ~0.7 s to print its completions, so they are cached per t3 version.
if mise_active t3; then
  t3_comp="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/t3-completions-${${commands[t3]:A}:h:t}.zsh"
  if [[ ! -s $t3_comp ]]; then
    mkdir -p "${t3_comp:h}"
    t3 --completions zsh >| "$t3_comp"
  fi
  source "$t3_comp"
  unset t3_comp
fi
