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
- **Web:** the pitchfork daemons `ntm-web` (`ntm web` on 127.0.0.1:7338) and `ntm-web-publish` (socat on 7337) serve the web dashboard at <http://localhost:7337> from the macOS host, with no login. Navigation: Sessions, Agents, Beads, Mail, Memory; unlinked pages: `/accounts`, `/analytics`, `/pipelines`, `/safety`, `/scanner`. The project pages (Beads, Mail, Memory, Pipelines, Scanner) follow the focused tmux session (below). Sessions and Agents stay empty in 1.35.1. Mail adds nothing to Agent Mail's own UI at <http://localhost:8765/mail>, one inbox across all projects.

## Scout → worker

A Codex scout on gpt-6-luna (high effort) explores a bead and writes a brief; a coding pane then starts on the brief instead of exploring on its own. The recipe `scout` and the operator rules are in `~/.config/ntm/recipes.toml`, the pipeline in `~/.config/ntm/pipelines/scout-work.yaml`, its prompts beside it in `prompts/explore.md` and `prompts/work.md`.

- **Spawn:** the coding session as usual (`agents`), then, in the repository, the scout session: `scouts`, which runs `ntm spawn <repo> --label scout -r scout --no-recovery`. It is the tmux session `<repo>--scout`, with the same project directory and Agent Mail project.
- **A bead:** `scout <bead> [claude|codex]` in the repository runs `ntm pipeline run ~/.config/ntm/pipelines/scout-work.yaml --session <repo>--scout --var bead=<bead> --var agent=<type>`:
  1. `explore`: the scout reads the bead, its dependencies, AGENTS.md and the code, and writes `.ntm/briefs/<bead>.md` (Goal, Already done, Plan, Files as `path:start-end` with excerpts, Constraints, Open questions). It edits nothing else.
  2. `record`: the brief becomes a comment on the bead.
  3. `handoff`: `ntm assign <repo> --beads=<bead> --auto` claims the bead and sends an idle pane of the coding session `work.md` followed by the brief. The worker reserves its files in Agent Mail: ntm's own reservation takes paths from the bead title only and refuses the dispatch when there are none (`--reserve-files=false`).
  4. The worker closes the bead and runs `ntm assign <repo> --clear <bead>`: ntm keeps a pane fenced by its assignment after the bead closes, and only a clear or the completion detector of `ntm assign --watch` frees it.
- **Rules:** never `ntm add` to the scout session, since an added pane starts on ntm's Codex default model; spawn another labelled session with the recipe instead. Never run `ntm coordinator run` or `ntm assign` on it: they hand beads to the scouts as coding work. `--no-recovery` keeps ntm's first prompt, which asks a new pane to continue the repository's in-progress beads, away from the scout.
- **Limits:**
  - The scout is done when ntm's idle heuristic says so. A scout that stops early (a question, a stall) ends `explore`, and `record` fails for the missing brief; one still busy after 30 minutes fails the run. Either way no pane gets the bead.
  - One bead at a time per scout pane: a second run waits up to 2 minutes for the pane's lock, then fails without sending anything. Run beads one after another, or spawn more scout sessions (`--label scout2`) and pass `--session <repo>--scout2` to `ntm pipeline run`; `scout` targets `<repo>--scout` only.
  - `handoff` succeeds even when no pane of the coding session is free (all busy or still fenced): nothing is assigned, the bead stays open with the brief as its comment, and `ntm assign <repo> --beads=<bead> --auto --reserve-files=false --template=custom --template-file=.ntm/briefs/<bead>.prompt` hands it over later. `ntm assign --watch` on the coding session would free fenced panes, but it also hands every ready bead to idle panes, unscouted.
  - The brief's size (about 150 lines, excerpts of at most 10) is a request in the prompt, not a limit; the whole brief is pasted into the worker's pane.
  - Both panes keep their conversation from bead to bead: the scout's context grows and older beads can leak into a brief, and the worker gets the brief on top of its previous work. `ntm respawn <repo>--scout` gives the scout a fresh context.
  - Model and effort are fixed per pane at spawn: the scout pane is titled `cod_N_gpt-6-luna@high`, and a respawn reads them back from the title. The worker runs whatever its coding pane runs.

## Quirks

- **The web dashboard works without login only through the forwarder.** ntm serves in auth mode `local` only on a loopback address; any other address needs an API key, and then the dashboard page and its websocket answer 401 in a browser. So ntm binds 127.0.0.1:7338, socat listens on 7337 on every interface, and the compose file publishes 7337: whoever reaches it can type into the agents' panes. The dashboard calls the API at `http://localhost:7337`, and ntm accepts only localhost origins, so open it as `localhost`, not through the OrbStack domain.
- **`ntm web` has one project for all its project pages,** kept in memory and settable only through `PATCH /api/v1/config`; without one, Beads runs `br` in `$HOME` and Mail fails. The tmux hooks `client-attached` and `client-session-changed` (`~/.config/tmux/tmux.conf`) run `~/.config/fw/bin/ntm-web-project <session>`, which sets `~/proj/active/<repo>` for the sessions `<repo>` and `<repo>--<label>` when that directory exists; the page refetches when its browser window gets focus. So two browser windows on two projects both show the session focused last, and after a daemon restart the project stays empty until the next attach or switch. By hand: `~/.config/fw/bin/ntm-web-project <repo>`.
- **ntm registers its working directory as an Agent Mail project**, `ntm web` included; the daemon runs from `$HOME`, already a project.
- **The config file is not ntm's alone.** `ntm coordinator enable|disable`, pins and favourites in the palette, and `ntm config set|reset|migrate` write into `~/.config/ntm/config.toml`; the next `chezmoi apply` reverts them. `ntm assign --watch` appends the F12 binding to `~/.tmux.conf` when that file lacks it; tmux loads both files, so the binding is only duplicated.
- **The palette file replaces ntm's built-in entries**, with no merge. A line starting with `#` is a comment only outside a command (before the first `###`, or between a `## Category` and its first `###`); inside a command it is prompt text, so the file keeps its comments in the header. A repository adds its own entries with `[palette] file = "palette.md"` in `.ntm/config.toml` (the path is relative to `.ntm/`, else to the repository root); an entry with the same key as a global one wins. The palette sends a prompt verbatim, with no placeholders: `e` edits it before sending.
- **Agent commands override the clients' own config.** ntm launches Codex with `-m gpt-6-astra -c model_reasoning_effort=xhigh` and Claude Code with `--effort xhigh`, whatever `~/.codex/config.toml` and `~/.claude/settings.json` say, unless the spawn names a model and effort.
- **Empty dashboard panels:** the Metrics panel stays hidden, the quota panel (`$`) reads "unavailable", and the rano panel is empty; see [upstream-todo.md](upstream-todo.md#ntm).
- **`--with-agent-name`** prefixes only `--init-prompt`, which spawn sends only with `--assign`.
