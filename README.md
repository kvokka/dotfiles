# dotfiles

Template dotfiles repository, managed with [chezmoi](https://chezmoi.io/).

## Installation

```bash
bash -c "$(curl -fsLS https://raw.githubusercontent.com/kvokka/dotfiles/refs/heads/master/bootstrap.sh)"
```

With connected terminal in process you will be asked:

```plaintext
headless install? [bool] # if this machine does not have a screen and keyboard; t/f, default: false
ephemeral install? [bool] # if this machine is ephemeral, e.g. a cloud or VM instance; t/f, default: false
name: # GitHub username, default: kvokka
email: # GitHub email, default: kvokka@yahoo.com
```

NOTES:

* `personal` setting is responsible for extra tools installation and should be patched
with the actual hostname

### WSL/Parallels MacOs

```bash
# This is optional, some casks for macOs require that, can be entered in the installation process
export SUDO_PASSWORD="your_password_here"

bash -c "$(curl -fsLS https://raw.githubusercontent.com/kvokka/dotfiles/refs/heads/master/bootstrap.sh)"
```

#### Use with another user

```shell
export GITHUB_USERNAME=my-user

bash -c "$(curl -fsLS https://raw.githubusercontent.com/kvokka/dotfiles/refs/heads/master/bootstrap.sh)"
```

## Notes

* [fonts](https://github.com/romkatv/powerlevel10k#meslo-nerd-font-patched-for-powerlevel10k)

## License

MIT
