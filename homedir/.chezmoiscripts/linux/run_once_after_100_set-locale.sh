#!/usr/bin/env zsh

# 2. Check if en_US.UTF-8 is already enabled in /etc/locale.gen
if [ -f /etc/locale.gen ] && grep -q "^en_US.UTF-8 UTF-8" /etc/locale.gen; then
    # Do nothing if locale is already enabled
    :
else
    # Configure en_US.UTF-8 if missing or commented
    if [ -f /etc/locale.gen ]; then
        if ! grep -q "en_US.UTF-8 UTF-8" /etc/locale.gen; then
            echo "en_US.UTF-8 UTF-8" | sudo tee -a /etc/locale.gen > /dev/null
        else
            sudo sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
        fi
        sudo locale-gen en_US.UTF-8
        sudo update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
    else
        echo "Error: /etc/locale.gen not found. Cannot configure locale." >&2
        exit 1
    fi
fi
