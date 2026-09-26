# ntm

How ntm (Named Tmux Manager) runs an agent swarm on this machine and which parts of its setup look odd but are deliberate. The settings and their reasons are in `~/.config/ntm/config.toml` and `~/.config/mise/config.fw.toml` (dotfiles: `homedir/dot_config/ntm/config.toml`, `homedir/dot_config/mise/config.fw.toml`). Open upstream problems and the release check are in [upstream-todo.md](upstream-todo.md#ntm).

## How it works

- **Pin:** `ntm` 1.35.1 in `~/.config/mise/config.fw.toml`.
- **Config:** `~/.config/ntm/config.toml` holds ntm's whole reference config with the defaults commented out. Ours: `projects_base = ~/proj/active` and `[agent_mail] pane_badges = true` (each pane's Agent Mail name in its border).
- **Spawn:** `ntm spawn <repo> --cc=2 --cod=1` in the repository `~/proj/active/<repo>` starts the tmux session `<repo>` with two Claude Code panes and one Codex pane, then `ntm attach <repo>`. `--cc=N:model:effort` picks the model and reasoning effort per spawn; the zsh helper `agents [repo]` spawns with the counts from `NTM_CLAUDE_COUNT` and `NTM_CODEX_COUNT`.
- **Identity:** ntm registers every pane it spawns in Agent Mail under the project key `~/proj/active/<repo>` and writes the pane identity file. It sets no variable in the pane; the Agent Mail hooks, the pre-commit guard and the agents find the name with `am agents resolve-pane --project <repo>`. See [agent-mail.md](agent-mail.md).
- **Manager:** `ntm controller <repo>` launches a coordinating agent in pane 1. `ntm mail send <repo> --all "..."` writes to the agents as HumanOverseer, which bypasses contact policies and asks them to put the message first.
- **tmux keys** (`~/.config/tmux/tmux.conf`): F6 opens the command palette (prompts from `~/.config/ntm/command_palette.md`), F12 the dashboard of the current session, both as popups.
- **Dashboard:** `ntm dashboard <repo>`, or F12. Its layout follows the width of its own pane or popup:

  | Columns | Layout |
  |---|---|
  | < 120 | card grid |
  | 120-239 | list + Detail/Attention tabs |
  | 240-319 | list + detail + sidebar (locks, cost, metrics, history, files, CASS, timeline; the keys `$ o a w` work only here, `J`/`K` cycle the sidebar) |
  | >= 320 | adds the Beads and Alerts columns |

  The status bar names the current tier; nothing else forces one. The F12 popup is 95% of the client, so the sidebar needs about 253 client columns: open the dashboard in its own tmux window, full screen, with a smaller font. The Cost panel works without extra tools (an estimate; `NTM_DASH_BUDGET_DAILY_USD` adds a budget).
- **Web:** the pitchfork daemons `ntm-web` (`ntm web` on 127.0.0.1:7338) and `ntm-web-publish` (socat on 7337) serve the web dashboard at <http://localhost:7337> from the macOS host, with no login. Navigation: Sessions, Agents, Beads, Mail, Memory; unlinked pages: `/accounts`, `/analytics`, `/pipelines`, `/safety`, `/scanner`. Beads and Mail show one project, which is set through the API (below).

## Quirks

- **The web dashboard works without login only through the forwarder.** ntm serves in auth mode `local` only on a loopback address; any other address needs an API key, and then the dashboard page and its websocket answer 401 in a browser. So ntm binds 127.0.0.1:7338, socat listens on 7337 on every interface, and the compose file publishes 7337: whoever reaches it can type into the agents' panes. The dashboard calls the API at `http://localhost:7337`, and ntm accepts only localhost origins, so open it as `localhost`, not through the OrbStack domain.
- **Beads and Mail in `ntm web` need a project.** Without one, Beads runs `br` in the daemon's working directory (`$HOME`) and Mail fails. Set the project until the next restart: `curl -X PATCH localhost:7337/api/v1/config -H 'Content-Type: application/json' -d '{"project_dir":"/home/ubuntu/proj/active/<repo>"}'`.
- **ntm registers its working directory as an Agent Mail project**, `ntm web` included; the daemon runs from `$HOME`, already a project.
- **The config file is not ntm's alone.** `ntm coordinator enable|disable`, pins and favourites in the palette, and `ntm config set|reset|migrate` write into `~/.config/ntm/config.toml`; the next `chezmoi apply` reverts them. `ntm assign --watch` appends the F12 binding to `~/.tmux.conf` when that file lacks it; tmux loads both files, so the binding is only duplicated.
- **The palette file replaces ntm's built-in entries**, with no merge. A line starting with `#` is a comment only outside a command (before the first `###`, or between a `## Category` and its first `###`); inside a command it is prompt text, so the file keeps its comments in the header. A repository adds its own entries with `[palette] file = "palette.md"` in `.ntm/config.toml` (the path is relative to `.ntm/`, else to the repository root); an entry with the same key as a global one wins. The palette sends a prompt verbatim, with no placeholders: `e` edits it before sending.
- **Agent commands override the clients' own config.** ntm launches Codex with `-m gpt-6-astra -c model_reasoning_effort=xhigh` and Claude Code with `--effort xhigh`, whatever `~/.codex/config.toml` and `~/.claude/settings.json` say, unless the spawn names a model and effort.
- **Empty dashboard panels:** the Metrics panel stays hidden, the quota panel (`$`) reads "unavailable", and the rano panel is empty; see [upstream-todo.md](upstream-todo.md#ntm).
- **`--with-agent-name`** prefixes only `--init-prompt`, which spawn sends only with `--assign`.
