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

## SSH with passphrase

```bash
# run it once to save the key in keychain
ssh-add --apple-use-keychain ~/.secrets/ssh/cat
```

### Extras

* `personal` setting is responsible for extra tools installation and should be patched
with the actual hostname

### Secrets (optional)

* Use fnox and [config.toml](./homedir/dot_config/fnox/config.toml)

## Packages

`mise bootstrap` converges everything a machine needs: system packages, macOS
defaults, the login shell and the tool runtimes of `[tools]`.

On macOS mise asks for sudo when it creates `/opt/homebrew` and when a cask
ships a `pkg` installer. Pre-set it with

```bash
export SUDO_PASSWORD="your_password_here"
```

## CI

By default CI runs in **light mode** — only mise and the tools the smoke test
needs are installed; `mise bootstrap` skips `[bootstrap.packages]` and the rest
of the tool runtimes. This keeps everyday pushes fast.

To run a **full installation** (identical to a real machine setup), either:

* Push the `full` tag at the commit:

```bash
git tag full
git push origin master --tags
```

  The tag push is its own CI run, and that run is the full one.

* Or trigger manually via GitHub Actions → "Run workflow" with the `full` checkbox.

After a full run you can delete the tag so it doesn't carry over:

```bash
git push origin :refs/tags/full
git tag -d full
```

## License

MIT
