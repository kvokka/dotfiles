# Local dev compose

The devcontainer replacement.

The host `~/.dotfiles` (the chezmoi source) is bind-mounted at `~/.dotfiles`
inside the container, and `entrypoint.sh` passes it as `--source` to the
chezmoi one-liner: the container applies the same checkout the host does and
clones nothing. It is mounted outside `~/.local` on purpose: docker creates
the parent directories of a nested bind mount inside the `home` volume as
root, which would break mise writing to `~/.local/bin` and `~/.local/share`.
