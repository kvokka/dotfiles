# Agent Mail

How MCP Agent Mail runs on this machine and which parts of its setup look odd but are deliberate. The settings and their reasons are in `~/.config/mise/config.fw.toml` and `~/.config/mcp-agent-mail/config.env` (dotfiles: `homedir/dot_config/mise/config.fw.toml`, `homedir/dot_config/mcp-agent-mail/config.env.tmpl`). Open upstream problems and the release check are in [upstream-todo.md](upstream-todo.md#agent-mail).

## How it works

- **Pin:** `am` 0.3.36 (`mcp_agent_mail_rust`, which also ships `mcp-agent-mail`) in `~/.config/mise/config.fw.toml`.
- **Service:** the pitchfork daemon `agent-mail`, `am serve-http --no-tui` on 0.0.0.0:8765, MCP at `/mcp/`, registered for every client by `mise run ai:sync`. Data: the SQLite database and the git archive (`STORAGE_ROOT`) under `~/proj/share/agent-mail`.
- **Web UI:** <http://localhost:8765/mail> from the macOS host: projects, agents, threads, reservations, and the HumanOverseer compose page. `ntm mail send <repo> ...` is the same overseer from the shell.
- **Terminal views:** `am robot status`, `am robot inbox --project <repo> --agent <name>`, `am robot reservations`, `am robot agents`, `am robot thread <id>`, and `am tui-dump` for the snapshot the TUI would show.
- **Identity:**
  - In an ntm pane the agent is registered before it starts: ntm calls `create_agent_identity` with the pane id, and the pane identity file `~/.config/agent-mail/identity/<sha1(project)[:12]>/<session>-<window>-<pane>` names the agent. `am agents resolve-pane --project <repo>` reads it for the current `$TMUX_PANE`.
  - Anywhere else the agent registers itself once and keeps the name; for the pre-commit guard it commits with `AGENT_NAME=<name>`.
  - The project key is the repository's absolute path, which for ntm is `~/proj/active/<session>`.
- **Hooks** (`~/.config/fw/bin/am-hook`, registered by rulesync for Claude Code and Codex): at session start the agent's name, pending acknowledgements and active reservations; after a tool call an unread-mail reminder, at most every 120 s. The agent is `AGENT_NAME`, else `AGENT_MAIL_AGENT`, else the pane identity; without one the hooks stay silent.
- **Pre-commit guard** (`scripts/hooks/agent-mail-guard` from `fw:init`): `am guard check` on the staged files against the exclusive reservations in the archive. The committer is resolved like the hooks' agent; a person in a plain shell commits as `human:<user>`. `AGENT_MAIL_GUARD_MODE=warn` reports without blocking; `PREK_SKIP=agent-mail-guard` skips one commit.

## Quirks

- **No interactive TUI beside the daemon.** The TUI renders only inside the serving process, and one server owns the storage root. `am` in a terminal next to the daemon offers a read-only attach, which reprints `am robot tui-dump` every second, or a takeover. Never take over: it kills the pitchfork daemon's server, and am starts only a systemd or launchd service again afterwards. Use the web UI and the `am robot` views.
- **No product bus or build slot tools.** Their eight tools only return an error while `WORKTREES_ENABLED` is off (the default, kept), so the tool filter in `config.env` (`TOOLS_FILTER_*`, clusters `product_bus` and `build_slots`) drops them from `tools/list`. The server reads the filter once at start: `pitchfork restart agent-mail` after a change.
- **`/web-dashboard` answers 501:** the browser mirror of the TUI is deferred upstream.
- **MCP calls carry no tmux pane.** Over HTTP the server learns the caller's pane only from an explicit `pane_id` (`macro_start_session`, `resolve_pane_identity`), so an agent in an ntm pane must pass `$TMUX_PANE` or use the name the hook printed; a bare `register_agent` mints a second identity.
- **`am guard check` needs a name even when nothing is reserved** (`missing AGENT_NAME env var`, exit 1), and ignores `AGENT_MAIL_GUARD_MODE`; the wrapper supplies the `human:<user>` fallback and turns `warn` into `--advisory`. An agent outside ntm without `AGENT_NAME` commits as that human, so its own exclusive reservations block it.
- **`am agents resolve-pane` writes.** Although documented as read-only, it upgrades a plain-name identity file to a structured record. It exits 1 when no identity matches.
- **Hooks and guard follow the git toplevel.** An agent working in another worktree or a nested repository is a different project to Agent Mail, and the hooks stay silent there.
- **`ntm web` and other ntm commands register their working directory as a project**, which is why stray projects such as `/` can appear in the web UI. am has no command that removes one project, only `am clear-and-reset-everything`, which wipes them all; run ntm from a repository or `$HOME`.
