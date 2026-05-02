# Agent Instructions

## Repo Shape

- This is a chezmoi dotfiles repo, not an application package.
- `.chezmoiroot` sets the chezmoi source root to `homedir`; edit managed source files there, not rendered files under `$HOME`.
- `.chezmoiversion` pins chezmoi compatibility to `2.68.1`.
- There are no repo package manifests or task-runner files discovered (`package.json`, `pyproject.toml`, `go.mod`, `Makefile`, `justfile`, `Taskfile`). Do not invent npm/pytest/go test commands.
- Some high-value tracked paths can be absent from this sparse checkout; verify missing tracked files with `git show HEAD:<path>` before concluding they do not exist.

## Setup And CI

- README install command:
  ```sh
  sh -c "$(curl -fsLS get.chezmoi.io/lb)" -- init --apply --force --purge-binary kvokka
  ```
- Do not run install/bootstrap/`chezmoi apply` casually: they install tools, apply dotfiles, and mutate home state.
- CI lives in `.github/workflows/ci.yaml`. Push CI is path-filtered; PR CI is not.
- CI light mode sets `MISE_ENABLE_TOOLS="chezmoi,oh-my-posh,zoxide"` and skips most Homebrew packages.
- Full CI is enabled with workflow input `full=true` or a `full` tag.
- CI smoke checks are `brew shellenv`, `mise --version`, `~/.local/share/mise/shims/chezmoi --version`, and `~/.local/share/mise/shims/chezmoi data`.

## Verification

- Repo-local pre-commit config is `.pre-commit-config.yaml`; run hooks with:
  ```sh
  prek run
  ```
- The managed git hook uses repo-local `.pre-commit-config.yaml` when present, otherwise falls back to `~/.config/pre-commit/pre-commit-config.yaml`.
- Hooks include `gitleaks protect -v --redact --staged` and `rumdl-fmt`; do not bypass or weaken secret scanning.
- `.rumdl.toml` excludes `AGENTS.md`, `GEMINI.md`, `CHANGELOG.md`, `prompts/`, and `docs/**/*`, and disables `MD013` and `MD033`.

## File Formats

- Chezmoi filename prefixes are semantic: `dot_`, `private_`, `exact_`, and `executable_` affect rendered targets. Preserve them when moving or adding managed files.
- Several `.json` files are intentionally JSONC/JSON5-like. For example, `homedir/dot_config/opencode/opencode.json` contains comments and trailing commas. Do not normalize these to strict JSON unless explicitly asked.

## OpenCode And OpenClaw

- Managed OpenCode config is `homedir/dot_config/opencode/opencode.json`; plugins include `oh-my-openagent` and `cc-safety-net`, and the default model is `openai/gpt-5.5`.
- `cc-safety-net` is configured to block `git push -f` and `git push --force`.
- For OpenClaw ACP topics, keep OpenClaw `agentId` as `opencode`; `sisyphus` is the internal OpenCode/oh-my-opencode agent.
- The ACP command must stay:
  ```sh
  env OPENCODE_DEFAULT_AGENT=sisyphus opencode acp
  ```
- Do not replace it with `opencode --agent=sisyphus acp`; `opencode acp` has its own option parser and does not accept that flag.

## Local Dev Compose

- `homedir/dot_config/docker-compose/local-dev/README.md` describes local compose as the devcontainer replacement.
- The zsh aliases wrap `docker compose -f "$HOME/.config/docker-compose/local-dev/docker-compose.yml"` through `dc`.
- Compose entrypoint applies dotfiles in the container and creates the OpenCode worktree symlink, so compose operations are not inspection-only.

## Telegram Topics

- `homedir/private_dot_openclaw/skills/telegram-topics/SKILL.md` is the authority for OpenClaw Telegram topic workflows.
- `scripts/topic_config.py check` is not passive; it sends and deletes probe messages because Telegram lacks a read-only forum-topic lookup.
- `scripts/topic_config.py delete` deletes Telegram topics before config cleanup. Topic `1` is protected General/root topic; never delete it.
- For ACP project topics, the helper creates worktrees under `$WORKDIR`; never delete a source project directory when cleaning up a topic.

## Secrets And Sensitive Files

- README recommends shared secrets in `~/.secrets/shared/.env`; mention env var names only, never real values.
- Treat Quotio, OpenClaw, kube, Telegram, and `private_` configs as sensitive. Do not quote secrets in docs, logs, prompts, or commits.
- `homedir/dot_config/zshrc.d/executable_800-secrets.zsh` sources shared secrets and symlinks `~/.secrets/home/*` into `$HOME`; changing it affects login shells.
