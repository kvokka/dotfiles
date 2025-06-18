# dotfiles

Template dotfiles repository, managed with [chezmoi](https://chezmoi.io/).

## Installation

```bash
export DOTFILES_GITHUB_USERNAME=kvokka # or your own username
bash -c "$(curl -fsLS https://raw.githubusercontent.com/${DOTFILES_GITHUB_USERNAME}/dotfiles/refs/heads/master/bootstrap.sh)" \
  -- ${DOTFILES_GITHUB_USERNAME}
```

With connected terminal in process you will be asked:

```plaintext
headless install? [bool] # if this machine does not have a screen and keyboard; t/f, default: false
ephemeral install? [bool] # if this machine is ephemeral, e.g. a cloud or VM instance; t/f, default: false
name: # GitHub username, default: kvokka
email: # GitHub email, default: kvokka@yahoo.com
```

### WSL

```bash
export SUDO_PASSWORD="your_password_here"
echo $SUDO_PASSWORD | sudo -S apt update

export DOTFILES_GITHUB_USERNAME=kvokka # or your own username
bash -c "$(curl -fsLS https://raw.githubusercontent.com/${DOTFILES_GITHUB_USERNAME}/dotfiles/refs/heads/master/bootstrap.sh)" \
  -- ${DOTFILES_GITHUB_USERNAME}
```

## Environment variables

Should be placed in default `.env` file, list only common variables

```env
GOOGLE_AI_STUDIO_API_KEY= # Google AI Studio API key
```

## Scripts

* [bootstrap.sh](./homedir/bootstrap.sh) - bootstraps environment, including [install.sh](install.sh)

## Manual steps

### Linux

Install fonts from [here](https://github.com/romkatv/powerlevel10k#meslo-nerd-font-patched-for-powerlevel10k)

## License

MIT
