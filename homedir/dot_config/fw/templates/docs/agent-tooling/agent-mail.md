# Agent Mail

How MCP Agent Mail runs on this machine and which parts of its setup look odd but are deliberate. The settings and their reasons are in `~/.config/mise/config.fw.toml`, `~/.config/mcp-agent-mail/config.env` and `~/.config/mcp-agent-mail/tui.tmux.conf` (dotfiles: `homedir/dot_config/mise/config.fw.toml` and the files in `homedir/dot_config/mcp-agent-mail/`). Open upstream problems and the release check are in [upstream-todo.md](upstream-todo.md#agent-mail).

## How it works

- **Pin:** `am` 0.3.36 (`mcp_agent_mail_rust`, which also ships `mcp-agent-mail`) in `~/.config/mise/config.fw.toml`.
- **Service:** the pitchfork daemon `agent-mail`, `am serve-http` with its TUI on 0.0.0.0:8765, MCP at `/mcp/`, registered for every client by `mise run ai:sync`. am runs in the session `am` of a private tmux server (socket `agent-mail`) that the daemon holds in the foreground. Data: the SQLite database and the git archive (`STORAGE_ROOT`) under `~/proj/share/agent-mail`.
- **TUI:** `mise run fw:am-tui` attaches to the running server's TUI from any terminal or tmux pane. Detach with Ctrl-\ (or the default prefix, C-b d); the server keeps running, at about 3% of a core while nobody is attached. The window takes the size of the last attached terminal. The TUI saves its preferences and dismissed hints under `~/proj/share/agent-mail/tui/` (`CONSOLE_PERSIST_PATH`), not in the managed `config.env`.
- **Web UI:** <http://localhost:8765/mail> from the macOS host: projects, agents, threads, reservations, and the HumanOverseer compose page. `ntm mail send <repo> ...` is the same overseer from the shell.
- **Terminal views:** the `am` commands [below](#am-cli).
- **Identity:**
  - In an ntm pane the agent is registered before it starts: ntm calls `create_agent_identity` with the pane id, and the pane identity file `~/.config/agent-mail/identity/<sha1(project)[:12]>/<session>-<window>-<pane>` names the agent. `am agents resolve-pane --project <repo>` reads it for the current `$TMUX_PANE`.
  - Anywhere else the agent registers itself once and keeps the name; for the pre-commit guard it commits with `AGENT_NAME=<name>`.
  - A harness subagent (Claude Code, Codex) gets its own identity from `~/.config/fw/bin/am-subagent`, below.
  - The project key is the repository's absolute path, which for ntm is `~/proj/active/<session>`.
- **Hooks** (`~/.config/fw/bin/am-hook`, registered by rulesync for Claude Code and Codex): at session start the agent's name, pending acknowledgements and active reservations; after a tool call an unread-mail reminder, at most every 120 s. The agent is `AGENT_NAME`, else `AGENT_MAIL_AGENT`, else the pane identity; inside a subagent (`agent_id` in the hook input) only the subagent's own identity. Without one the hooks stay silent.
- **Subagents** (`am-subagent`, the `SubagentStart` and `SubagentStop` hooks from rulesync; agy has neither event):
  - `start` runs `am agents create` (no pane id, so the parent's pane binding stays) for every agent type except the read-only ones (`Explore`, `Plan`, `claude-code-guide`, Codex's `explorer`), keeps name, project and registration token in `~/.cache/fw/am-subagents/<agent_id>`, and hands the subagent its name as `additionalContext`. A later start for the same `agent_id` reuses the name.
  - `stop` releases the subagent's reservations and keeps the state.
  - The cron daemon `am-subagent-reap` (daily at 11:30) retires the identities whose state went unused for a day, through the MCP tool `retire_agent` with the saved token, and deletes the state. `pitchfork logs am-subagent-reap` shows each retirement.
  - Commits: a Codex subagent's shell carries `CODEX_THREAD_ID`, its `agent_id`, and the guard finds its name from that. A Claude Code subagent has no such variable and commits with the `AGENT_NAME=<name>` prefix its start context asks for.
- **Pre-commit guard** (`scripts/hooks/agent-mail-guard` from `fw:init`): `am guard check` on the staged files against the exclusive reservations in the archive. The committer is resolved like the hooks' agent, with a Codex subagent's identity before the pane's; a person in a plain shell commits as `human:<user>`. `AGENT_MAIL_GUARD_MODE=warn` reports without blocking; `PREK_SKIP=agent-mail-guard` skips one commit.

## MCP tools

45 tools in nine clusters (`am tooling directory --json`); `tools/list` shows 42, because the filter in `config.env` hides `build_slots`. Every tool but the product bus works inside one project, the `project_key` (the repository path): names, messages, threads, contacts and reservations never cross it; how agents of two repositories talk is under [Across repositories](#across-repositories). Marks: **daily**, what a working agent calls; **ad hoc**, useful now and then; **operator**, for the owner, ntm or our scripts; **avoid**, harmful here; **unused**; **hidden**.

**identity**

| Tool | Mark | Here |
| --- | --- | --- |
| `register_agent` | daily | Outside ntm, once per session. Idempotent with `name` (updates the profile, whoever registered it, with no token); without `name` every call mints a new agent. Names are unique per project only: the same name in another project is that project's agent. |
| `create_agent_identity` | operator | Always a new agent (`name_hint` must be free); ntm and `am-subagent` (as `am agents create`) create identities with it. Never to rejoin a session. |
| `whois` | ad hoc | One agent's profile and recent archive commits. |
| `list_agents` | ad hoc | The project's roster, at most 250. |
| `resolve_pane_identity` | ad hoc | The agent bound to `pane_id` of the default tmux server (quirk below); in the pane itself, `am agents resolve-pane` does the same. |
| `retire_agent`, `unretire_agent` | operator | Over HTTP only with the agent's `registration_token`. A retired agent neither sends nor receives. `am-subagent-reap` retires with the saved token. |
| `deregister_agent` | avoid | Permanent; token as for `retire_agent`. |
| `cleanup_pane_identities` | operator | Deletes the identity files of dead panes, all projects without `project_key`; a plain-name file counts as live only for a pane of the default tmux server. |

**messaging**

| Tool | Mark | Here |
| --- | --- | --- |
| `send_message` | daily | Recipients resolve only in `project_key`. An unknown name, a typo or an agent of another repository, becomes a placeholder agent in this project and the send succeeds, so nobody reads it; for another repository see [Across repositories](#across-repositories). Use `thread_id` (the bead id) and `ack_required` for what needs an answer. |
| `reply_message` | daily | Keeps the thread. Needs the `project_key` of the original: message ids are global, but another project's key gets `NOT_FOUND`. |
| `fetch_inbox` | daily | Marks what it returns read unless `mark_read=false`. |
| `acknowledge_message` | daily | Also marks read; same `project_key` rule as `reply_message`. |
| `mark_message_read`, `mark_all_read` | ad hoc | Clearing an inbox without reading it through `fetch_inbox`. |
| `get_message_delivery_receipt` | ad hoc | Whether each recipient got, read or acknowledged a message. |
| `fetch_topic` | unused | Every message of a project with a topic tag, whoever the recipient; the instructions use threads, not topics. |
| `fetch_inbox_events` | unused | Cursor-based delivery events for restart-safe monitors; the hooks use `am check-inbox`. |

**contact**: every agent keeps the default policy `auto` with enforcement on, so a first message between two agents of one project goes through, and the recipient finds a "Contact approved: A -> B" notice in its inbox next to it.

| Tool | Mark | Here |
| --- | --- | --- |
| `set_contact_policy` | avoid | `contacts_only` or `block_all` make every unapproved sender's messages to that agent fail. |
| `list_contacts` | ad hoc | The approved links of an agent. |
| `request_contact`, `respond_contact` | unused | Within a project `auto` makes them unnecessary; across projects the handshake records the link and files a notice, and no message can follow it (the delivery path reads links of one project only). |

**file_reservations**

| Tool | Mark | Here |
| --- | --- | --- |
| `file_reservation_paths` | daily | Exclusive before editing; the pre-commit guard blocks other committers on those paths. |
| `release_file_reservations` | daily | At the end of the task; `am-subagent stop` does it for subagents. |
| `renew_file_reservations` | daily | For work that outlives the TTL. |
| `check_file_reservation_conflicts` | ad hoc | Read-only check before reserving. |
| `force_release_file_reservation` | operator | Takes a stale reservation from an inactive holder and notifies it. |

**infrastructure**

| Tool | Mark | Here |
| --- | --- | --- |
| `ensure_project` | daily | First call in a repository: only it writes the archive's `project.json`, which the guard needs (quirk below). |
| `health_check` | operator | Server readiness. |
| `install_precommit_guard`, `uninstall_precommit_guard` | avoid | The guard comes from `fw:init` (`scripts/hooks/agent-mail-guard`); am's own hook install clashes with the global `core.hooksPath`. |

**search**

| Tool | Mark | Here |
| --- | --- | --- |
| `search_messages` | ad hoc | Full-text search within the project. |
| `summarize_thread` | ad hoc | Participants, key points and action items of one or more threads; heuristic only, as `LLM_ENABLED` is off. |

**workflow_macros**

| Tool | Mark | Here |
| --- | --- | --- |
| `macro_start_session` | daily | Outside ntm: `ensure_project`, registration, reservations and the inbox in one call. Pass `agent_name` once you have one: without it the macro takes the agent bound to `pane_id` (ntm's pane agent keeps its name) and otherwise mints a new agent. |
| `macro_prepare_thread` | ad hoc | Joins an existing thread: registration, its summary and the inbox; pass `agent_name` for the same reason. |
| `macro_file_reservation_cycle` | ad hoc | Reserve, and optionally release, in one call. |
| `macro_contact_handshake` | unused | See contact. |

**product_bus**: a product is a named set of projects, and its tools read across them. `WORKTREES_ENABLED=true` in `config.env` turns the cluster on (the flag is misnamed: it gates the product bus and the build slots, nothing about git worktrees).

| Tool | Mark | Here |
| --- | --- | --- |
| `ensure_product`, `products_link` | operator | Once per set of repositories that talk to each other: `ensure_product(product_key=<product>)`, then `products_link(<product>, ~/proj/active/<repo>)` for each of them, through the MCP tools of any session (`am products link` writes the database itself and is refused while the daemon owns it). Both idempotent. |
| `fetch_inbox_product` | daily | `(product_key, agent_name)`: the messages addressed to agents of that name in every linked project, newest first, each with its `project_id` and its own `read_ts` and `ack_ts`; marks nothing read; `since_ts` and `limit` page it. The join is by name, so an agent that joined several projects under one name reads one inbox here. |
| `search_messages_product`, `summarize_thread_product` | ad hoc | Search, and one thread id (the bead), across the linked projects; the thread summary names the participants of every project. |

Apart from its product records the product bus only reads. It sends nothing across projects: replies, acknowledgements and reservations still go to each message's own project. `WORKTREES_ENABLED` (or `GIT_IDENTITY_ENABLED`, which implies it) also makes every project resolution, in the server and in `am guard check`, write `<git common dir>/agent-mail/project-id` into the repository; project slugs do not change while `PROJECT_IDENTITY_MODE` stays `dir`.

**build_slots** (hidden by the filter in `config.env`; the server reads it once at start, `pitchfork restart agent-mail` after a change): `acquire|renew|release_build_slot` are advisory named leases, written as JSON under `build_slots/` in the project's archive; only `am am-run` and `am verify` take them.

## Across repositories

Each repository is its own project, and `send_message` delivers only inside the project it is called with: the recipient name is looked up there, an unknown one becomes a placeholder, and the approved links of a cross-project contact handshake are never read for delivery (its welcome message is dropped; the target only gets a "Contact approved" notice). Upstream: [issue #335](https://github.com/Dicklesworthstone/mcp_agent_mail_rust/issues/335); the author's decision is to refuse such sends rather than route them, see [upstream-todo.md](upstream-todo.md#agent-mail). An agent of one repository asks another repository like this:

1. **Find the addressee** in the other repository: `list_agents(project_key=<other repo>)` for the roster and `am file_reservations active <other repo>` for who holds the files in question; otherwise its coordinator.
2. **Join that project under your own name:** `register_agent(project_key=<other repo>, program, model, name=<your name>, task_description="<repo> agent, asking about <bead>")`. Look at the roster first: `register_agent` with a name that exists there updates that agent's profile instead of refusing. When the name is taken, `create_agent_identity(project_key=<other repo>, ...)` mints a fresh one, and your inbox there carries that name. Reserve nothing there. The pane identity, the hooks and the commits of your own repository stay as they are.
3. **Send there:** `send_message(project_key=<other repo>, sender_name=<name>, to=[<addressee>], thread_id=<bead>, ack_required=true, ...)`. The addressee gets it in its ordinary inbox, with the hooks' reminder, and answers with `reply_message` in that project.
4. **Read the answer** with `fetch_inbox_product(<product>, <name>)`, one list over every project of the product, or `fetch_inbox(project_key=<other repo>, agent_name=<name>)`. The hooks' reminder covers only the project of the git toplevel, so poll while waiting and do the work that does not depend on the answer. Acknowledge with the `project_key` of the message's project (`project_id` in the product rows).
5. **Afterwards** nothing needs to happen: the identity in the other project costs nothing and the next visit reuses it. `retire_agent` takes the `registration_token` the registration returned.

Nothing is relayed and nothing piles up: a message belongs to one recipient in one project, and its read and acknowledged state lives on that pair, so the product view shows it read once the recipient acknowledged it in its own project. `MESSAGES_RETENTION_DAYS=2` in `config.env` prunes messages that every recipient has read and acknowledged after two days; the git archive keeps them. `summarize_thread_product(<product>, <bead>)` reads the whole exchange of a bead across the repositories when every side keeps the bead as `thread_id`.

## `am` CLI

The same data from a shell. `--project` defaults to `AGENT_MAIL_PROJECT`, then the working directory, and `--agent` to `AGENT_MAIL_AGENT`, then `AGENT_NAME`.

- `am robot status`: health, inbox counts, reservations and top threads of a project.
- `am robot inbox [--all|--urgent|--ack-overdue]`: an agent's unread messages; never marks them read.
- `am robot thread <id>`, `am robot message <id>`, `am robot search <query>`: reading without an MCP client.
- `am robot agents`, `am robot reservations`, `am robot timeline --since <iso>`: roster, reservations with their expiry, recent events.
- `am robot overview [--counts]`: unread, urgent and overdue counts per project, over all projects and all agents.
- `am tui-dump`: the TUI's snapshot as text.
- `am agents resolve-pane --project <repo>`: the name of the current pane's agent (it writes, quirk below).
- `am agents list|show --project <repo>`: the roster, one agent.
- `am file_reservations active|soon <repo>`: active reservations, those about to expire.
- `am acks pending|overdue <repo> <agent>`: acknowledgements the agent still owes.
- `am check-inbox`: the unread count the `PostToolUse` hook prints, rate-limited (`--rate-limit 0` to force); one project (`--project`), no product.
- `am products ensure|link|status|inbox|search|summarize-thread`: the product bus from the shell; `link` only while no daemon owns the database.
- `am mail send --project <repo> --from <agent> --to <a,b> --subject <s> --body <md> [--thread-id <id>]`: sends as an agent; `ntm mail send` sends as the HumanOverseer.
- `printf '%s\0' <paths> | AGENT_NAME=<agent> am guard check --stdin-nul --advisory`: the pre-commit guard's verdict on those paths, without blocking.
- `am tooling directory --json`: every tool with its cluster.
- `mise run fw:am-tui`: the interactive TUI, as above.

## Quirks

- **Quitting the TUI stops the server for every agent.** `q`, Esc Esc and Ctrl-C Ctrl-C end `am serve-http` itself; pitchfork starts it again within about 10 s. Detach instead. am's own Ctrl-D ("detach headless") would drop the TUI until the next restart, so the tmux config turns it off.
- **The server logs to the TUI.** Its event console holds the log, and `pitchfork logs agent-mail` stays nearly empty; read the state with `am tui-dump` and `am robot ...`.
- **No second `am` server and no takeover.** The TUI renders only inside the serving process, and one server owns the storage root. `am` in a terminal next to the daemon offers a read-only attach or a takeover; a takeover kills the daemon's server, and am starts only a systemd or launchd service again afterwards. Use `mise run fw:am-tui`.
- **`/web-dashboard` answers 501:** the browser mirror of the TUI is deferred upstream.
- **MCP calls carry no tmux pane.** Over HTTP the server learns the caller's pane only from an explicit `pane_id` (`macro_start_session`, `resolve_pane_identity`, `create_agent_identity`), so an agent in an ntm pane uses the name the hook printed; a bare `register_agent` mints a second identity. The server takes the caller's tmux socket only from an `X-Tmux-Socket` header, which the `am` CLI sends and the MCP clients do not, and drops a `tmux_socket_path` in the arguments; it looks a `pane_id` up on the tmux server of its own environment. The daemon runs am without the `TMUX` and `TMUX_PANE` of its private tmux server, so pane lookups and `cleanup_pane_identities` use the default server, where ntm's panes live; a pane on another tmux socket is not found.
- **`send_message` never leaves its project.** The name of an agent of another repository silently becomes a placeholder in the sender's project, and a contact handshake across projects records a link that no delivery reads. The way across is [Across repositories](#across-repositories): join the other project, send there, read through the product bus.
- **`am guard check` needs a name even when nothing is reserved** (`missing AGENT_NAME env var`, exit 1), and ignores `AGENT_MAIL_GUARD_MODE`; the wrapper supplies the `human:<user>` fallback and turns `warn` into `--advisory`. An agent outside ntm without `AGENT_NAME` commits as that human, so its own exclusive reservations block it.
- **`am agents resolve-pane` writes.** Although documented as read-only, it upgrades a plain-name identity file to a structured record. It exits 1 when no identity matches.
- **Hooks and guard follow the git toplevel.** An agent working in another worktree or a nested repository is a different project to Agent Mail, and the hooks stay silent there.
- **`ntm web` and other ntm commands register their working directory as a project**, which is why stray projects such as `/` can appear in the web UI. am has no command that removes one project, only `am clear-and-reset-everything`, which wipes them all; run ntm from a repository or `$HOME`.
- **`last_active_ts` is set only at registration.** Messages, reservations and inbox reads leave it alone, so `am agents reap --stale-days N` would retire every agent registered more than N days ago, ntm pane agents at work included, and a retired agent can neither send nor receive. The subagent reap retires only the identities am-subagent created.
- **Only `ensure_project` writes the archive's `project.json`,** and `am guard check` finds a project's reservations only through it. A project that first appeared through `register_agent`, `create_agent_identity` or a reservation has none, and the guard lets every commit there pass. ntm and the instructions call `ensure_project`; a subagent whose parent never registered creates its project without it.
- **A subagent's `SubagentStart` context is its only source of its name.** A Claude Code subagent that forgets the `AGENT_NAME=` prefix commits as its parent (or as `human:<user>`), and its own exclusive reservations then block it with its name as holder. In ntm the subagent inherits `$TMUX_PANE`, so `am agents resolve-pane` in its shell names the parent, never the subagent.
- **Subagent hooks fire more than once.** Claude Code runs `SubagentStart` again on resume and for every message of an agent-team teammate, and both clients run `SubagentStop` after every turn of a subagent, so a teammate or a Codex subagent that gets another turn has to reserve its files again.
