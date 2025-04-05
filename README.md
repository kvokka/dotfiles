# dotfiles

Template dotfiles repository, managed with [chezmoi](https://chezmoi.io/).

## Installation

* [bootstrap.sh](bootstrap.sh) - bootstraps environment, including [install.sh](install.sh)
* [install.sh](install.sh) - installs chezmoi and init dotfiles

## Manual steps

### Linux

Install fonts from [here](https://github.com/romkatv/powerlevel10k#meslo-nerd-font-patched-for-powerlevel10k)

## Notes

* Environment variables for devcontainers are autoloaded from
`~/devcontainer/devcontainer.env`. Lately they are fetched
[here](https://github.com/kvokka/vscode-devcontainer-boilerplate/blob/f6cbba64d84edc33fb1903c877248751e2b84955/.devcontainer/devcontainer.json#L59).
See
[here](https://code.visualstudio.com/docs/remote/containers#_using-environment-variables-in-container-recipes)
for more details.

## License

MIT
