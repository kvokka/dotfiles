# dotfiles

Template dotfiles repository, managed with [chezmoi](https://chezmoi.io/).

## Installation

```bash
export DOTFILES_GITHUB_USERNAME=kvokka # or your own username
bash -c "$(curl -fsLS https://raw.githubusercontent.com/${DOTFILES_GITHUB_USERNAME}/dotfiles/refs/heads/master/bootstrap.sh)" \
  -- ${DOTFILES_GITHUB_USERNAME}
```

## Scripts

* [bootstrap.sh](./homedir/bootstrap.sh) - bootstraps environment, including [install.sh](install.sh)

## Manual steps

### Linux

Install fonts from [here](https://github.com/romkatv/powerlevel10k#meslo-nerd-font-patched-for-powerlevel10k)

## License

MIT
