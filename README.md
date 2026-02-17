# dotfiles

Template dotfiles repository, managed with [chezmoi](https://chezmoi.io/).

## Installation

```bash
sh -c "$(curl -fsLS get.chezmoi.io/lb)" -- init --apply --force --purge-binary kvokka
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

For MacOs you might be asked for sudo pass, that is required for some casks, in
the installation process, also it might be pre-set via

```bash
export SUDO_PASSWORD="your_password_here"
```

## CI

By default CI runs in **light mode** — only brew and mise are installed, skipping
all other packages and tool runtimes. This keeps everyday pushes fast.

To run a **full installation** (identical to a real machine setup), either:

* Tag the commit with `full` before pushing:

```bash
git tag full
git push origin main --tags
```

* Or trigger manually via GitHub Actions → "Run workflow" with the `full` checkbox.

After a full run you can delete the tag so it doesn't carry over:

```bash
git push origin :refs/tags/full
git tag -d full
```

## Notes

* [fonts](https://github.com/romkatv/powerlevel10k#meslo-nerd-font-patched-for-powerlevel10k)

## License

MIT
