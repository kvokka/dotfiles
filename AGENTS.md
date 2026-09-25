# Agent Instructions

## Repo Shape

- This is a chezmoi dotfiles repo, not an application package.
- `.chezmoiroot` sets the chezmoi source root to `homedir`; edit managed source files there, not rendered files under `$HOME`.
- There are no repo package manifests or task-runner files discovered (`package.json`, `pyproject.toml`, `go.mod`, `Makefile`, `justfile`, `Taskfile`). Do not invent npm/pytest/go test commands.
- Some high-value tracked paths can be absent from this sparse checkout; verify missing tracked files with `git show HEAD:<path>` before concluding they do not exist.
- `origin` is `kvokka/dotfiles`; `kvokka-agent` pushes feature branches there as a collaborator and opens pull requests against `master`. A ruleset refuses deleting or rewriting `master`, and dcg refuses a force push.

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
- Every tool is a pinned `github:` release; `cm` is built from a pinned main-commit tarball (`http:cass-memory`, the `github:` backend demands a release for SLSA) in a tool-level `postinstall` (`{{ version }}` in platform URLs needs mise >= 2026.9.12, enforced by `min_version` in that file). Back to a tag once cass-memory 0.2.15 ships; still open upstream: project-scoped learning (#81) and re-reflecting a grown session (#85).
- `pi` is the minimal harness for one-shot LLM calls (a prompt in, text out, no tools, no session): prefer it over a full coding agent for tooling that only needs text. One profile per job under `homedir/dot_config/fw/pi/<name>/`, selected with `PI_CODING_AGENT_DIR`; the `cm` profile (`fw/bin/cm-llm`) reaches `gpt-6-luna` with high effort through the same proxy as Codex (`models.json` is a chezmoi template: pi does not expand env vars in `baseUrl`; the key comes from `fnox exec`).
- Services (`agent-mail` on 127.0.0.1:8765, `cm` on 8766, `sbh`, and the cron jobs `cass-index` every 5 minutes, `cass-nightly` daily at 10:05, `cm-reflect` every 30 minutes, `cm-trauma-scan` daily at 11:15) are pitchfork daemons declared in `[daemons]`; the container has no systemd. Never run `am service install`, `sbh install`, `dcg install`, `agy install` or any upstream `install.sh`: chezmoi owns the configs, `opencode/plugins/dcg-guard.js.tmpl` included, and the clients' MCP servers and hooks come from rulesync (next section).
- Per-repository files (`.pre-commit-config.yaml`, `AGENTS.md`, `docs/agent-tooling.md`, `.gitignore`, `.ubsignore`) come from `homedir/dot_config/fw/templates/` via the file task `mise run fw:init`; `mise run fw:doctor` smoke-checks the stack.
- `homedir/dot_config/fw/templates/scripts/hooks/executable_agent-mail-guard` wraps `am guard check`; `am guard install` is incompatible with the global `core.hooksPath`.
- cass-memory: the store `$CASS_MEMORY_HOME` = `~/proj/share/cm-playbooks` is a local git repository (no remote yet; its `config.yaml`, `.gitignore` and gitleaks-only `.pre-commit-config.yaml` come from `homedir/proj/share/cm-playbooks/`). Only the `cm-reflect` queue (`tasks/fw/cm-reflect`) learns: it reflects finished sessions one by one through `cm-llm`, subagent sessions included, and commits the store. The `cm` MCP daemon runs without the LLM key on purpose, so an agent's `memory_reflect` fails. `mise run fw:cm-report` shows rules by origin, the backlog and traumas.
- Traumas are command regexes the owner activates with `cm trauma add` after real damage; `fw/bin/trauma-guard.tmpl` (our copy of upstream's guard, which even after #82 reads the project from the process cwd, knows only Claude's input and tells agents to heal traumas; ours takes the project from the hook input, answers agy in its format, matches each segment of a chained command and also reads the store it was rendered for) blocks them in every client. `cm-trauma-scan` only proposes candidates in `$CASS_MEMORY_HOME/trauma-candidates.md`. Never let an agent heal, remove or add a trauma.
- Tool instructions for agents live in `homedir/dot_config/fw/instructions/<tool>.md`, not in repository AGENTS.md files: SessionStart hooks (`fw/bin/fw-context <tool>`) print them for Claude Code and Codex, the always-on rule `private_dot_gemini/config/rules/fw-agent-stack.md.tmpl` includes them for agy, and `instructions` in `opencode.json` for OpenCode. The first prompt of a session gets `cm context` from `fw/bin/cm-context-hook`.

## AI Client MCP Servers and Hooks (rulesync)

- All coding runs in the Linux devcontainer, so this whole setup is devcontainer-only (`.config/rulesync/**` is ignored elsewhere). One source for Claude Code, Codex, OpenCode and agy: `homedir/dot_config/rulesync/` (`dot_rulesync/mcp.jsonc`, `dot_rulesync/hooks.jsonc.tmpl`). `mise run ai:sync` (`config.fw.toml`, `npm:rulesync` pinned there) writes them into each client's user-scope files.
- `ai:sync` runs automatically only from the chezmoi script `run_after_200_ai-sync.sh`, after every apply: chezmoi still rewrites `~/.claude/settings.json`, `~/.codex/config.toml` and `opencode.json` whole, which drops the generated keys, and the first apply reaches it after `run_once_after_100` has installed the tools. When chezmoi goes, the same call moves into a mise task.
- rulesync owns whole keys: the MCP server lists of all four clients (`claude mcp add -s user` or `codex mcp add` entries are dropped on the next run) and the hook lists. It keeps every other key of the files it writes. Add servers and hooks in the source, never in the generated files. An empty hooks source erases every client's hooks.
- Every MCP server is a shared pitchfork daemon reached over HTTP, one process per container, no secret in any client config. A stdio-only server goes behind `mcp-proxy` (punkpeye's TypeScript proxy, commented out in `config.fw.toml` while unused): one child for all sessions, where `supergateway` starts one per request. Run it with `--host 127.0.0.1`: its default `::` exposes the server to the compose network. A daemon that needs a secret runs under `fnox exec`: the pitchfork supervisor keeps the environment of the process that started it, which may lack the fnox secrets.
- One hooks block serves Claude Code, Codex and agy; matchers list each client's tool name (`Bash|run_command`). OpenCode gets no hooks (`targets` in `rulesync.jsonc`): rulesync's OpenCode plugin runs a hook command with no stdin and ignores the result, so dcg would fail open there; OpenCode keeps dcg's own plugin, and `opencode/plugins/cass-memory.js.tmpl` runs the trauma guard and the first-prompt cm context.
- Never give agy a `preModelInvocation`, `postModelInvocation` or `stop` hook through rulesync: rulesync nests them as `{"hooks": [...]}`, agy 1.2.7 reads them as a flat `[{type, command}]` list and then rejects the whole `rulesync` named hook, dcg included. agy's cass-memory PreInvocation hook is a separate named hook that `fw/bin/agy-cm-hook` adds as the second step of `ai:sync` (rulesync rewrites the whole file). agy reads no hooks from its `settings.json`, and a PreToolUse answer without a decision (even `{}`) is a deny there.
- dcg's hook self-heal is off (`self_heal_hook = false` in `homedir/dot_config/dcg/config.toml`): it rewrote the rulesync entry in `~/.claude/settings.json` on every call.
- Agent Mail hooks (`~/.config/fw/bin/am-hook`) respect what Claude Code and Codex show the model: plain stdout only from `SessionStart` (acks and reservations), and from `PostToolUse` only a JSON `additionalContext` (the `am check-inbox` reminder, rate-limited by am). Plain `PostToolUse` stdout, as in the hooks `am setup` writes, never reaches the model. The agent is `AGENT_NAME`, else `AGENT_MAIL_AGENT`, else `NTM_AGENT_NAME`; without one `am-hook` prints nothing. In ntm sessions ntm itself also nudges agents about mail.
- After `ai:sync` changes `~/.codex/hooks.json`, Codex skips the changed hooks until they are approved once in Codex; then copy its new `[hooks.state]` entries into `homedir/dot_codex/private_config.toml.tmpl`.

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
