# Agent Instructions

## Repo Shape

- This is a chezmoi dotfiles repo, not an application package.
- `.chezmoiroot` sets the chezmoi source root to `homedir`; edit managed source files there, not rendered files under `$HOME`.
- There are no repo package manifests or task-runner files discovered (`package.json`, `pyproject.toml`, `go.mod`, `Makefile`, `justfile`, `Taskfile`). Do not invent npm/pytest/go test commands.
- Some high-value tracked paths can be absent from this sparse checkout; verify missing tracked files with `git show HEAD:<path>` before concluding they do not exist.

## Setup And CI

- README install command:
  ```sh
  sh -c "$(curl -fsLS get.chezmoi.io/lb)" -- init --apply --force --purge-binary --source ~/.dotfiles kvokka
  ```
- The chezmoi source is `~/.dotfiles` on the host and in the devcontainer, not the default `~/.local/share/chezmoi`: the compose file bind-mounts the host checkout there, and `chezmoi init --source` persists the path into `~/.config/chezmoi/chezmoi.yaml`. `chezmoi init` clones only when the source directory holds no git repository. Both sides apply the checked-out branch of that one checkout, so keep `master` checked out there and work on feature branches in a `git worktree`.
- Do not run install/bootstrap/`chezmoi apply` casually: they install tools, apply dotfiles, and mutate home state.
- CI lives in `.github/workflows/ci.yaml`. Push CI is path-filtered; PR CI is not.
- `run_once_after_100_mise-bootstrap.sh` installs the mise binary (or self-updates one older than the `min_version` of `config.fw.toml`) and runs `mise bootstrap` after apply, once chezmoi has written `~/.config/mise/config.toml`. Post-tools setup (atuin, openspec stores) lives in the mise `bootstrap` task, not in extra chezmoi scripts: chezmoi scripts run with chezmoi's own `PATH`, which has no `~/.local/bin`, and `mise run` installs the whole toolset before a task.
- CI light mode passes `DOTFILES_BOOTSTRAP_SKIP=packages,user,tools,task` and `DOTFILES_BOOTSTRAP_TOOLS="chezmoi oh-my-posh fnox"` to that script.
- Full CI runs on the workflow_dispatch input `full` and on a push of the `full` tag.
- CI smoke checks are `mise --version`, `mise bootstrap status`, `~/.local/share/mise/shims/chezmoi --version`, and `~/.local/share/mise/shims/chezmoi data`.

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

## Flywheel Agent Stack (fw)

- The acfs-derived agent stack (ntm, br/bv, Agent Mail `am`, dcg, ubs, cass/cm, sbh, agy, ...) lives in `homedir/dot_config/mise/config.fw.toml`, loaded only in the Linux devcontainer through the `fw` entry of `miserc.toml`; `toon`, `typos` and `fmd` are global tools.
- Every tool is a pinned `github:` release; `cm` is built from the tagged source tarball in a tool-level `postinstall` (`{{ version }}` in platform URLs needs mise >= 2026.9.12, enforced by `min_version` in that file).
- Services (`agent-mail` on 127.0.0.1:8765, `cm` on 8766, `sbh`) are pitchfork daemons declared in `[daemons]`; the container has no systemd. Never run `am service install`, `sbh install`, `dcg install`, `agy install` or any upstream `install.sh`: chezmoi owns the configs, `opencode/plugins/dcg-guard.js.tmpl` included, and the clients' MCP servers and hooks come from rulesync (next section).
- Per-repository files (`.pre-commit-config.yaml`, `AGENTS.md`, `docs/agent-tooling.md`, `.gitignore`, `.ubsignore`) come from `homedir/dot_config/fw/templates/` via the file task `mise run fw:init`; `mise run fw:doctor` smoke-checks the stack.

## AI Client MCP Servers and Hooks (rulesync)

- One source for Claude Code, Codex, OpenCode and agy: `homedir/dot_config/rulesync/`. `base/dot_rulesync/mcp.jsonc` holds the MCP servers for every machine; `fw/dot_rulesync/` (Linux devcontainer only, ignored elsewhere) adds the flywheel servers and holds the only hooks source. `mise run ai:sync` (`npm:rulesync`, pinned in `config.toml`) writes them into each client's user-scope files; `mise bootstrap` and the chezmoi script `run_after_200_ai-sync.sh` run it.
- rulesync owns whole keys: the MCP server lists of all four clients (`claude mcp add -s user` or `codex mcp add` entries are dropped on the next run) and the hook lists. It keeps every other key of the files it writes. Add servers and hooks in the source, never in the generated files.
- Hooks are generated only with the fw tree present: an empty or missing hooks source makes rulesync write an empty hook list. A hooks file in both trees is not merged; the fw one replaces the base one.
- Hooks live in per-client blocks (matchers use each client's tool names). OpenCode gets none from rulesync: its generated plugin runs a hook command with no stdin and ignores the result, so dcg would fail open there; OpenCode keeps dcg's own plugin.
- Only `SessionStart` runs Agent Mail (`~/.config/fw/bin/am-hook`): it is the one event whose plain stdout reaches the model in Claude Code and Codex. `am-hook` is silent unless `AGENT_NAME` is set and Agent Mail knows the repository and the agent.
- Secrets stay in the environment (fnox): Claude Code and OpenCode pass their whole environment to stdio servers (tested); Codex passes only the names in a server's `envVars`; agy is untested. `MORPH_API_KEY` is the one in use.
- After `ai:sync` changes `~/.codex/hooks.json`, Codex skips the changed hooks until they are approved once in Codex; then copy its new `[hooks.state]` entries into `homedir/dot_codex/private_config.toml.tmpl`.
- `homedir/dot_config/fw/templates/scripts/hooks/executable_agent-mail-guard` wraps `am guard check`; `am guard install` is incompatible with the global `core.hooksPath`.

## Local Dev Compose

- `homedir/dot_config/docker-compose/local-dev/README.md` describes local compose as the devcontainer replacement.
- The zsh aliases wrap `docker-compose -f "$HOME/.config/docker-compose/local-dev/docker-compose.yml"` through `dc`.
- Compose entrypoint applies dotfiles in the container and creates the OpenCode worktree symlink, so compose operations are not inspection-only.
- The host `~/.dotfiles` is mounted at `/home/ubuntu/.dotfiles` and passed as `--source` to the entrypoint's chezmoi one-liner. Keep it outside `~/.local`: docker creates the parent directories of a nested bind mount inside the `home` volume as root, which breaks mise writing to `~/.local`.

## Telegram Topics

- `homedir/private_dot_openclaw/skills/telegram-topics/SKILL.md` is the authority for OpenClaw Telegram topic workflows.
- `scripts/topic_config.py check` is not passive; it sends and deletes probe messages because Telegram lacks a read-only forum-topic lookup.
- `scripts/topic_config.py delete` deletes Telegram topics before config cleanup. Topic `1` is protected General/root topic; never delete it.
- For ACP project topics, the helper creates worktrees under `$WORKDIR`; never delete a source project directory when cleaning up a topic.
