# Agent Instructions

## Repo Shape

- This is a chezmoi dotfiles repo, not an application package.
- `.chezmoiroot` sets the chezmoi source root to `homedir`; edit managed source files there, not rendered files under `$HOME`.
- There are no repo package manifests or task-runner files discovered (`package.json`, `pyproject.toml`, `go.mod`, `Makefile`, `justfile`, `Taskfile`). Do not invent npm/pytest/go test commands.
- Some high-value tracked paths can be absent from this sparse checkout; verify missing tracked files with `git show HEAD:<path>` before concluding they do not exist.
- `origin` is `kvokka/dotfiles`; `kvokka-agent` pushes feature branches there as a collaborator and opens pull requests against `master`. A ruleset refuses deleting or rewriting `master`, and dcg refuses a force push.
- The repository's own agent hooks (dcg) are the `fw:init` template's, at the repository root outside the chezmoi source root: `rulesync.jsonc` and `.rulesync/hooks.jsonc`, generated with `rulesync generate` into `.claude/settings.json`, `.codex/hooks.json` and `.agents/hooks.json`; `.opencode/plugins/dcg-guard.js` and `opencode.json` for OpenCode. Change the source and regenerate, never the generated files; keep them in step with `homedir/dot_config/fw/templates/`.

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
- A managed config of a third-party tool carries only the values that differ from the tool's defaults, never a copy of its default or generated config. Check each key against the tool's source or docs, and leave out any key that equals its default. A default value is kept only when the tool would otherwise rewrite the file itself; a comment next to it names the reason.
- Scripts, hooks and tasks call a tool directly. Never check whether it is installed (`command -v`, a fallback to a shim path, a wrapper that skips when it is missing): mise installs every tool before a task runs, or fails with its own error. Checking the installation is the job of `fw:doctor` alone. Likewise, use a tool's own output format (e.g. `--format markdown`) rather than re-rendering its JSON.
- Comments describe the setup as it is and why. They never say where or when something was fixed or broken: no upstream issue numbers, release versions, "fixed on main", "until X ships" or "the first run showed". That history belongs in the commit and PR message. Once a fix is in and works, drop the note.

## Flywheel Agent Stack (fw)

- The acfs-derived agent stack (ntm, br/bv, Agent Mail `am`, dcg, ubs, cass/cm, sbh, agy, ...) lives in `homedir/dot_config/mise/config.fw.toml`, loaded only in the Linux devcontainer through the `fw` entry of `miserc.toml`; `toon`, `typos` and `fmd` are global tools.
- Every tool is a pinned `github:` release; `cm` is built from a pinned main-commit tarball (`http:cass-memory`, the `github:` backend demands a release for SLSA) in a tool-level `postinstall` (`{{ version }}` in platform URLs needs mise >= 2026.9.12, enforced by `min_version` in that file).
- `pi` is the minimal harness for one-shot LLM calls (a prompt in, text out, no tools, no session): prefer it over a full coding agent for tooling that only needs text. One profile per job under `homedir/dot_config/fw/pi/<name>/`, selected with `PI_CODING_AGENT_DIR`; the `cm` profile (`fw/bin/cm-llm`) reaches `gpt-6-luna` with high effort through the same proxy as Codex (`models.json` is a chezmoi template: pi does not expand env vars in `baseUrl`; the key comes from `fnox exec`).
- cm's own prompts cannot be configured, and cm passes a CLI provider no system prompt, so the criteria for what becomes a cass-memory rule (diary preferences, when a delta is an `add`, `scope`, `kind`, validator rejects) live in the `cm` profile's `SYSTEM.md`, one section per cm prompt. Check a change with `fnox exec -- cm reflect --session <path> --force --dry-run --json` against sessions that produced good and bad rules; the dry run writes nothing to the store.
- Services (`agent-mail` on 127.0.0.1:8765, `cm` on 8766, `sbh`, and the cron jobs `cass-index` every 5 minutes, `cass-nightly` daily at 10:05, `cm-reflect` daily at 12:00) are pitchfork daemons declared in `[daemons]`; the container has no systemd. Never run `am service install`, `sbh install`, `dcg install`, `agy install` or any upstream `install.sh`: chezmoi owns the configs, and the clients' MCP servers and user-scope hooks come from rulesync (next section).
- Per-repository files (`.pre-commit-config.yaml`, `AGENTS.md`, `docs/agent-tooling.md`, `docs/agent-tooling/`, `.gitignore`, `.ubsignore`, the dcg guard) come from `homedir/dot_config/fw/templates/` via the file task `mise run fw:init`; `mise run fw:doctor` smoke-checks the stack.
- Notes on the stack live in `homedir/dot_config/fw/templates/docs/agent-tooling/`:
  - `<tool>.md` says how the tool works now and lists the quirks of its setup, briefly. A setting's reason stays in a comment next to the setting; the note summarizes and points there.
  - `upstream-todo.md` holds one section per tool: each open upstream problem with its issue or PR link, what to check in a new release, and what to change here once it is fixed.

  Read a tool's note before changing its setup, and its `upstream-todo.md` section before bumping its pin. After investigating a tool, record its quirks in the note and its open upstream problems in `upstream-todo.md`. Describe the current state only: no history, no record of work done, no earlier setups. A working setup is its own proof. Once an upstream fix is adopted, delete its item and the quirk it caused. `fw:init` copies these files only into a repository that lacks them, so the template is the source of truth.
- Only what every session needs is global: cm, cass and Agent Mail (instructions, MCP servers, hooks) and the trauma guard. The tools of a working repository come with `fw:init`: `ubs` runs only in its pre-commit hook and has no agent instructions, Beads' instructions are in its `AGENTS.md`, and dcg is a repository hook (`rulesync.jsonc` and `.rulesync/hooks.jsonc` in the template, generated by `rulesync generate` into `.claude/settings.json`, `.codex/hooks.json` and `.agents/hooks.json`; `.opencode/plugins/dcg-guard.js` and `opencode.json` with `cc-safety-net` for OpenCode). A chat session outside such a repository runs the destructive commands the user asks for.
- `homedir/dot_config/fw/templates/scripts/hooks/executable_agent-mail-guard` wraps `am guard check`; `am guard install` is incompatible with the global `core.hooksPath`.
- cass and cass-memory keep their default data dirs; `fw:bootstrap` links `~/.local/share/coding-agent-search` to `~/proj/share/cass` and `~/.cass-memory` to `~/proj/share/cass-memory`. Do not set `CASS_DATA_DIR` or `CASS_MEMORY_HOME`: parts of both tools ignore them.
- cass-memory rules are global, in one store, as cass-memory's author designed it: cass collects all history in one place, and cm distils it into one set of rules. Leave `projectRuleRouting` at its default (`off`) and add no repository `.cass/`. cm runs from `$HOME` (the reflect job, the context hook).
- The cass-memory config is the dotfile `homedir/dot_config/cass-memory/config.yaml.tmpl`, and `fw:bootstrap` links it into the store (`~/.cass-memory/config.yaml`). cm writes its config back on its own (`cm privacy`, `cm doctor --fix`, the budget on a first reflect) and replaces the link with a copy; the next bootstrap restores the link.
- Learning is cm's own: the `cm-reflect` cron daemon runs `cm reflect` through `cm-llm`, subagent sessions included. The `cm` MCP daemon runs without the LLM key on purpose, so an agent's `memory_reflect` fails.
- Traumas are command regexes the owner activates with `cm trauma add` after real damage. cass-memory's own guard blocks them: `fw:bootstrap` generates it with `cm guard --install` in a throwaway project and installs it as `~/.claude/hooks/trauma_guard.py`. The script is the same for every project apart from the store path baked into it, and rulesync registers it for Claude Code and Codex. Never let an agent heal, remove or add a trauma.
- Instructions of the global tools live in `homedir/dot_config/fw/instructions/<tool>.md`, not in repository AGENTS.md files: a SessionStart hook (`cat` of the blocks) prints them for Claude Code and Codex, and `instructions` in `opencode.json` loads them for OpenCode. The first prompt of a session gets `cm context` from `fw/bin/cm-context-hook`.

## AI Client MCP Servers and Hooks (rulesync)

- All coding runs in the Linux devcontainer, so this whole setup is devcontainer-only (`.config/rulesync/**` is ignored elsewhere). One source for Claude Code, Codex, OpenCode and agy: `homedir/dot_config/rulesync/` (`dot_rulesync/mcp.jsonc`, `dot_rulesync/hooks.jsonc.tmpl`). `mise run ai:sync` (`config.fw.toml`, `npm:rulesync` pinned there) writes them into each client's user-scope files.
- `ai:sync` runs automatically only from the chezmoi script `run_after_200_ai-sync.sh`, after every apply: chezmoi still rewrites `~/.claude/settings.json`, `~/.codex/config.toml` and `opencode.json` whole, which drops the generated keys, and the first apply reaches it after `run_once_after_100` has installed the tools. When chezmoi goes, the same call moves into a mise task.
- rulesync owns whole keys: the MCP server lists of all four clients (`claude mcp add -s user` or `codex mcp add` entries are dropped on the next run) and the hook lists. It keeps every other key of the files it writes. Add servers and hooks in the source, never in the generated files. An empty hooks source erases every client's hooks.
- Every MCP server is a shared pitchfork daemon reached over HTTP, one process per container, no secret in any client config. A stdio-only server goes behind `mcp-proxy` (punkpeye's TypeScript proxy, commented out in `config.fw.toml` while unused): one child for all sessions, where `supergateway` starts one per request. Run it with `--host 127.0.0.1`: its default `::` exposes the server to the compose network. A daemon that needs a secret runs under `fnox exec`: the pitchfork supervisor keeps the environment of the process that started it, which may lack the fnox secrets. pitchfork runs each daemon through mise, so the daemon gets the current tool versions and `[env]`. A variable removed from `[env]` still lingers there until the supervisor restarts. A stopped supervisor is started again within a second by any mise-activated process, agent sessions included, with that process's environment. So restart the shells and agent sessions opened before the change first, or the whole container.
- One hooks block serves Claude Code, Codex and agy; matchers list each client's tool name (`Bash|run_command`). OpenCode gets no hooks (`targets` in `rulesync.jsonc`): rulesync's OpenCode plugin runs a hook command with no stdin and ignores the result, so a guard would fail open there; the fw:init template brings dcg's own OpenCode plugin, and `opencode/plugins/cass-memory.js.tmpl` adds the first-prompt cm context.
- agy takes a PreToolUse hook that prints nothing as a deny, so a hook that stays silent on agy's input (such as the trauma guard) gets the matcher `Bash`, never `run_command`.
- dcg's hook self-heal is off (`self_heal_hook = false` in `homedir/dot_config/dcg/config.toml`): on every call dcg would register itself in `~/.claude/settings.json` and guard every session again.
- Agent Mail hooks (`~/.config/fw/bin/am-hook`) respect what Claude Code and Codex show the model: plain stdout only from `SessionStart` (acks and reservations), and from `PostToolUse` only a JSON `additionalContext` (the `am check-inbox` reminder, rate-limited by am). Plain `PostToolUse` stdout, as in the hooks `am setup` writes, never reaches the model. The agent is `AGENT_NAME`, else `AGENT_MAIL_AGENT`, else `NTM_AGENT_NAME`; without one `am-hook` prints nothing. In ntm sessions ntm itself also nudges agents about mail.
- After `ai:sync` changes `~/.codex/hooks.json`, Codex skips the changed hooks until they are approved once in Codex; then copy its new `[hooks.state]` entries into `homedir/dot_codex/private_config.toml.tmpl`.

## Local Dev Compose

- `homedir/dot_config/docker-compose/local-dev/README.md` describes local compose as the devcontainer replacement.
- The zsh aliases wrap `docker-compose -f "$HOME/.config/docker-compose/local-dev/docker-compose.yml"` through `dc`.
- Compose entrypoint applies dotfiles in the container and creates the OpenCode worktree symlink, so compose operations are not inspection-only.
- The host `~/.dotfiles` is mounted at `/home/ubuntu/.dotfiles` and passed as `--source` to the entrypoint's chezmoi one-liner. Keep it outside `~/.local`: docker creates the parent directories of a nested bind mount inside the `home` volume as root, which breaks mise writing to `~/.local`.
