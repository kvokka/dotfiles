#!/usr/bin/env zsh

# 1. Exit silently if not WSL
if ! grep -qi "microsoft" /proc/version; then
    exit 0
fi

# 2. Verify Homebrew Zsh exists
ZSH_PATH="/home/linuxbrew/.linuxbrew/bin/zsh"
if [ ! -x "$ZSH_PATH" ]; then
    echo "Error: Homebrew Zsh not found at $ZSH_PATH. Please install Zsh via Homebrew." >&2
    exit 1
fi

# 3. Add Zsh switch to ~/.bashrc
BASHRC_FILE="$HOME/.bashrc"
ZSH_SNIPPET=$(cat << 'EOF'
if [ -t 1 ]; then
    exec /home/linuxbrew/.linuxbrew/bin/zsh
fi
EOF
)
if [ -f "$BASHRC_FILE" ] && ! grep -F "exec /home/linuxbrew/.linuxbrew/bin/zsh" "$BASHRC_FILE" > /dev/null; then
    echo "$ZSH_SNIPPET" >> "$BASHRC_FILE"
fi
[ ! -f "$BASHRC_FILE" ] && echo "$ZSH_SNIPPET" > "$BASHRC_FILE" && chmod 644 "$BASHRC_FILE"

# 4. Source ~/.bashrc to apply changes
source "$BASHRC_FILE"
