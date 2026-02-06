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

### Extras

* `personal` setting is responsible for extra tools installation and should be patched
with the actual hostname

### Shared secrets (optional)

* Recommended to set shared with devcontainer secrets in `~/.secrets/shared/.env`

```text
# optional GitHub PAT with public access to increace download quota for packages installation
# take from https://github.com/settings/personal-access-tokens for public repos only (minimal access)
export MISE_GITHUB_TOKEN=github_pat...

# Quotio GUI App API Key for CLI Proxy access
export QUOTIO_PROXY_API_KEY=quotio-local-...

# https://context7.com/ api key
export CONTEXT7_API_KEY=abc...

# https://brave.com/search/api/ api key
BRAVESEARCH_API_KEY=abc...
```

## WSL/Parallels MacOs

```bash
# This is optional, some casks for macOs require that, can be entered in the installation process
export SUDO_PASSWORD="your_password_here"

bash -c "$(curl -fsLS https://raw.githubusercontent.com/kvokka/dotfiles/refs/heads/master/bootstrap.sh)"
```

### Use with another user

```shell
export GITHUB_USERNAME=my-user

bash -c "$(curl -fsLS https://raw.githubusercontent.com/kvokka/dotfiles/refs/heads/master/bootstrap.sh)"
```

## Notes

* [fonts](https://github.com/romkatv/powerlevel10k#meslo-nerd-font-patched-for-powerlevel10k)

## License

MIT
