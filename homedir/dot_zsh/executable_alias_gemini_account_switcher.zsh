#!/bin/bash

# Ensure we don't have an alias conflicting
unalias gemini_account_switcher 2>/dev/null || true

gemini_account_switcher() {
    # Don't use set -e in a sourced function to avoid closing the terminal on error
    # set -e

    local SOURCE_BASE=""
    local TARGET_DIR="$HOME/.gemini"

    # Prioritize .devcontainer shared folder
    if [ -d "shared/gemini" ]; then
        SOURCE_BASE="shared/gemini"
    elif [ -d "/workspace/shared/gemini" ]; then
        SOURCE_BASE="/workspace/shared/gemini"
    elif [ -d "$HOME/.devcontainer/shared/gemini" ]; then
        SOURCE_BASE="$HOME/.devcontainer/shared/gemini"
    else
        echo "Error: No shared gemini accounts folder found in ~/.devcontainer/shared/gemini or /workspace/shared/gemini"
        return 1
    fi


    # Ensure target directory exists
    if [ ! -d "$TARGET_DIR" ]; then
         mkdir -p "$TARGET_DIR"
    fi

    # Get list of accounts (directories)
    # Portable way to read lines into an array
    local accounts=()
    while IFS= read -r line; do
        accounts+=("$line")
    done < <(find "$SOURCE_BASE" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort)

    if [ ${#accounts[@]} -eq 0 ]; then
        echo "No accounts found in $SOURCE_BASE"
        return 0
    fi

    # Get active email from current configuration
    local active_email=""
    if [ -f "$TARGET_DIR/google_accounts.json" ]; then
        active_email=$(jq -r '.active // empty' "$TARGET_DIR/google_accounts.json" 2>/dev/null || true)
    fi

    # Function to list accounts (Portable iteration)
    list_accounts() {
        echo "Available accounts:"
        local i=0
        for acc in "${accounts[@]}"; do
            i=$((i+1))

            local is_active=0
            local config_file="$SOURCE_BASE/$acc/google_accounts.json"

            if [[ -n "$active_email" ]] && [[ -f "$config_file" ]]; then
                 local acc_email=$(jq -r '.active // empty' "$config_file" 2>/dev/null || true)
                 if [[ "$acc_email" == "$active_email" ]]; then
                     is_active=1
                 fi
            fi

            if [[ "$is_active" -eq 1 ]]; then
                printf "%d. \033[1;31m%s\033[0m\n" "$i" "$acc"
            else
                printf "%d. %s\n" "$i" "$acc"
            fi
        done
    }

    # Check argument
    if [ -z "$1" ]; then
        list_accounts
        return 0
    fi

    local target_account=""
    local arg="$1"

    # Check if argument is a number
    if [[ "$arg" =~ ^[0-9]+$ ]]; then
        local i=0
        for acc in "${accounts[@]}"; do
            i=$((i+1))
            if [ "$i" -eq "$arg" ]; then
                target_account="$acc"
                break
            fi
        done

        if [ -z "$target_account" ]; then
            echo "Error: Invalid account number $arg."
            return 1
        fi
    else
        # Check if argument is a name
        for acc in "${accounts[@]}"; do
            if [ "$acc" == "$arg" ]; then
                target_account="$acc"
                break
            fi
        done

        if [ -z "$target_account" ]; then
            echo "Error: Account '$arg' not found."
            return 1
        fi
    fi

    echo "Switching to account: $target_account"

    # Perform the switch
    # Suppress errors if files are missing but directory exists.
    cp "$SOURCE_BASE/$target_account/"* "$TARGET_DIR/" 2>/dev/null || true

    echo "Successfully switched to $target_account"
}
