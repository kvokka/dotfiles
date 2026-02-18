#!/usr/bin/env zsh

sudo groupadd -f docker && sudo usermod -aG docker $(whoami)
sudo chown $(whoami):$(whoami) /var/run/docker.sock

[ -f "$HOME/.local/.dotfiles-applied" ] || \
sh -c "cd $HOME && $(curl -fsLS get.chezmoi.io/lb)" -- init --apply --force --purge-binary kvokka && \
touch "$HOME/.local/.dotfiles-applied"

# Use zsh from brew
sudo usermod -s $(which zsh) $(whoami) &>/dev/null
sudo usermod -s $(which zsh) root &>/dev/null
sudo chsh -s $(which zsh) $(whoami) &>/dev/null

# until https://github.com/anomalyco/opencode/issues/14032
mkdir -p ~/proj/active/opencode_worktrees
ln -sfT ~/proj/active/opencode_worktrees ~/.local/share/opencode/worktree

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
