# Local dev compose

The devcontainer replacement.

The host `~/.dotfiles` (the chezmoi source) is bind-mounted at `~/.dotfiles`
inside the container, and `entrypoint.sh` passes it as `--source` to the
chezmoi one-liner: the container applies the same checkout the host does and
clones nothing. The image runs the entrypoint from there too, so a change to
it needs no rebuild. It is mounted outside `~/.local` on purpose: docker creates
the parent directories of a nested bind mount inside the `home` volume as
root, which would break mise writing to `~/.local/bin` and `~/.local/share`.

The `home` volume outlives the container, the root filesystem does not. A
fresh volume gets the dotfiles, and chezmoi's `run_once` script runs
`mise bootstrap`. A new `console` container on an existing volume
(`dcupb`, `up --force-recreate`) runs `mise bootstrap` once more for the apt
packages, accounts and `/etc` files it lost: the marker
`/var/lib/dotfiles-bootstrapped` lives in the container, so a restart or
`chezmoi apply` does not repeat it. Only `console` sets
`DOTFILES_BOOTSTRAP_CONTAINER`; `dcr` turns it off for its throwaway
container.
