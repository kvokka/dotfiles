#!/bin/bash
set -euo pipefail

# bootstrap.sh
# Safe concurrent bootstrap for Dev Containers / Codespaces / multi-container setups
# Installs Homebrew + chezmoi + applies dotfiles exactly once, safely handling parallel runs

# --------------------------------------------------
# Config
# --------------------------------------------------
GITHUB_USERNAME="${1:-kvokka}"
LOCKFILE="$HOME/.bootstrap-in-progress.lock"
MARKER="$HOME/.dotfiles-applied"                    # Persistent success marker

# Timeout: 1800 seconds (30 minutes) by default, override via env var
TIMEOUT="${BOOTSTRAP_TIMEOUT:-1800}"
SLEEP_INTERVAL=10

# --------------------------------------------------
# Fast exit if already bootstrapped
# --------------------------------------------------
if [[ -f "$MARKER" ]] && command -v brew >/dev/null 2>&1 && command -v chezmoi >/dev/null 2>&1; then
  echo "==> Bootstrap already completed (marker exists and tools present)."
  exit 0
fi

# --------------------------------------------------
# Main bootstrap with lock
# --------------------------------------------------
bootstrap_with_lock() {
  exec 200>"$LOCKFILE"

  if flock -n 200; then
    # ==================== LEADER ====================
    echo "==> Acquired lock — running as leader."

    # On failure: clean up both lock and marker so retry is possible
    trap 'echo "==> Bootstrap failed — cleaning up lock and marker."; rm -f "$LOCKFILE" "$MARKER"' EXIT

    # Install Homebrew if missing
    if ! command -v brew >/dev/null 2>&1; then
      echo "==> Installing Homebrew..."
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    else
      echo "==> Homebrew already present."
    fi

    # Install and apply dotfiles via chezmoi
    echo "==> Installing and applying dotfiles via chezmoi (user: $GITHUB_USERNAME)..."
    sh -c "$(curl -fsLS get.chezmoi.io/lb)" -- init --apply --force --purge-binary "$GITHUB_USERNAME"

    # Success: create persistent marker
    touch "$MARKER"
    echo "==> Bootstrap completed successfully! Marker created at $MARKER"

    # Cancel trap — keep the marker forever
    trap - EXIT

    # Clean up only the lock file
    rm -f "$LOCKFILE"
  else
    # ==================== FOLLOWER ====================
    echo "==> Another container is running bootstrap. Waiting up to ${TIMEOUT}s for completion..."

    local elapsed=0
    while (( elapsed < TIMEOUT )); do
      if [[ -f "$MARKER" ]]; then
        echo "==> Bootstrap completed by leader. Everything is ready!"
        return 0
      fi
      sleep "$SLEEP_INTERVAL"
      (( elapsed += SLEEP_INTERVAL ))
    done

    echo "==> ERROR: Timed out after ${TIMEOUT}s waiting for bootstrap completion."
    exit 1
  fi
}

# --------------------------------------------------
# Run
# --------------------------------------------------
[[ ! -t 0 ]] && export NONINTERACTIVE=1  # Detect non-interactive environment

bootstrap_with_lock

echo "==> Bootstrap script finished."
exit 0
