if command -v openclaw &> /dev/null; then
  [ -f ~/.openclaw/completions/openclaw.zsh ] || openclaw completion --write-state --yes
  source ~/.openclaw/completions/openclaw.zsh
fi
