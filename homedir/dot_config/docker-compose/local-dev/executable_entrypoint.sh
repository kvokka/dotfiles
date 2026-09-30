#!/usr/bin/env sh

# $HOME is the `home` volume and outlives the container; the root filesystem is
# new in every container. A fresh volume gets the dotfiles, and chezmoi's
# run_once script runs `mise bootstrap`. A new console container on an old
# volume (`up --build`, `up --force-recreate`) has lost what the bootstrap put
# outside $HOME (apt packages, accounts, /etc files), while chezmoi's state in
# the volume says the script ran: so the console bootstraps once per container,
# marked outside the volume. `chezmoi apply` and a restart never bootstrap.
# Only the console sets DOTFILES_BOOTSTRAP_CONTAINER: the other services wait
# for the dotfiles (wait-for-ready) and need no system packages.
bootstrapped=/var/lib/dotfiles-bootstrapped

if [ ! -f "$HOME/.local/.dotfiles-applied" ]; then
  sh -c "cd $HOME && $(curl -fsLS get.chezmoi.io/lb)" -- init --apply --force --purge-binary --source "$HOME/.dotfiles" kvokka &&
    touch "$HOME/.local/.dotfiles-applied" &&
    sudo touch "$bootstrapped"
elif [ "${DOTFILES_BOOTSTRAP_CONTAINER:-}" = true ] && [ ! -f "$bootstrapped" ]; then
  "$HOME/.local/bin/mise" bootstrap --yes && sudo touch "$bootstrapped"
fi

# # Use this block for mitmproxy, #mitmproxy
# sudo cp .devcontainer/proxy/mitmproxy/mitmproxy-ca-cert.pem /usr/local/share/ca-certificates/mitmproxy-ca-cert.crt
# sudo update-ca-certificates
# export NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt

if [ $# -eq 0 ]; then
    # No command was given → just start an interactive shell (e.g. `docker run -it` or compose without `command:`)
    exec zsh -l -i
else
    # Command was given (e.g. `tail -f /dev/null`, `python app.py`, `npm start`, …)
    # The trick `zsh -c 'exec "$@"' _ "$@"` makes zsh:
    #   1. source .zshenv → .zprofile → .zshrc (because of -l -i)
    #   2. then replace itself with the original command + all its arguments
    exec zsh -l -i -c 'exec "$@"' _ "$@"
fi
