# Upstream todo

Open upstream problems of the agent-stack tools, what to check when a new release ships, and what to change here once a problem is fixed. Pins live in `~/.config/mise/config.fw.toml` (dotfiles: `homedir/dot_config/mise/config.fw.toml`).

Read the tool's section before bumping its pin. Remove an item once the fix is released and adopted here; how the setup worked before does not belong here.

## cass

Pin: 0.9.0. Setup notes: [cass.md](cass.md).

- **Lexical search tokenizes only ASCII and CJK.** Russian words never match, and one Russian word empties a mixed query. No upstream issue exists yet.
  - Check: does `CassAnalyzer::analyze` in `crates/frankensearch-quill/src/scribe.rs` still keep only `is_ascii_alphanumeric()` and CJK?
  - When fixed: rebuild the lexical index with `mise run fw:cass-index`, unless the changelog says cass rebuilds it itself. Then drop the Cyrillic quirk from [cass.md](cass.md) and the English-keywords line from the instruction block `~/.config/fw/instructions/cass.md`.
- **Every release:**
  1. On a copy of the data dir, run `cass models backfill --tier quality --embedder multilingual-minilm --batch-conversations 1 --json`. It should exit 0 and report `embedder_id: multilingual-minilm-384`.
  2. Bump the pin and run `mise install`.
  3. Run `mise run fw:cass-nightly`, then `mise run fw:doctor`. The doctor should be all green.

## ubs

Pin: 5.4.9. Setup notes: [ubs.md](ubs.md).

- **Shared rule packs**: [issue #144](https://github.com/Dicklesworthstone/ultimate_bug_scanner/issues/144), illustrated by [PR #145](https://github.com/Dicklesworthstone/ultimate_bug_scanner/pull/145). Requested: a repeatable `--rules`, a `UBS_RULES` environment variable, and git rule packs (`git+URL[@REF][#subdirectory=DIR]`). The issue also reports two defects: rules in subdirectories are skipped by the Python module, and the README's `severity: critical` example does not parse.
  - The design of custom rules for this setup waits for the author's answer here: a separate rules repository whose rules every project hook loads. The upstream answer decides how the hook gets those rules.
  - Check: the release notes and the `--rules` entry of `ubs --help`.
- **Newer versions refuse a missing or empty `--rules` directory** (on `main` after 5.4.9). 5.4.9 ignores it silently. Once the hook passes `--rules`, make sure the directory always exists.
- **Every release:** after bumping the pin, commit once in a repository that has the template's `.pre-commit-config.yaml`. The first run downloads the new modules.

## cass-memory (cm)

Pin: a `main` commit, built from the source tarball.

- **No linux-arm64 release binary** (0.2.14 ships linux-x64, macOS and Windows only). This is why `cm` is built from source with the `http:` backend.
  - Check: the assets of the new release.
  - When one ships: switch to a `github:` release pin and drop the `postinstall` build.

## ntm

Pin: 1.35.1. Setup notes: [ntm.md](ntm.md). No upstream issue exists yet for any item here; file references are to the `v1.35.1` tag.

- **Dashboard Metrics panel is a stub.** `fetchMetricsCmd` returns an empty `panels.MetricsData{}` (`internal/tui/dashboard/commands.go:522-531`), and the panel hides itself while empty (`internal/tui/dashboard/dashboard.go:1265`); no tool can fill it.
  - Check: the same two places in the new release.
- **Quota panel (`$`) always reads "unavailable".** It reads the caut usage cache, which nothing writes any more (`internal/integrations/caut/poller.go:7-12`). The caut adapter also calls `caut status --json` and `caut usage --all --json` (`internal/tools/caut.go:300`, `:373`), which caut lacks.
  - Check: the poller comment and the adapter's subcommands.
  - When fixed: consider pinning caut in `config.fw.toml`.
- **rano panel is empty.** ntm calls `rano stats --all --json` (`internal/tools/rano.go:440`), a subcommand rano 0.2.x does not have.
  - Check: the arguments at that line against `rano --help`.
  - When fixed: consider pinning rano.
- **No identity variable in panes.** ntm registers each pane in Agent Mail and reads `AGENT_NAME` itself (`internal/cli/mail.go:696`, `internal/cli/work.go:1150`), but sets nothing in the pane. `am-hook` and the pre-commit guard fall back to `am agents resolve-pane`.
  - Check: whether spawn exports `AGENT_NAME` or `AGENT_MAIL_AGENT` into the pane environment.
  - When fixed: keep the pane lookup as the fallback; the instruction block `~/.config/fw/instructions/agent-mail.md` can name the variable instead of the command.
- **`--with-agent-name` needs `--assign`.** It prefixes only `--init-prompt`, which spawn sends only in the assignment phase (`internal/cli/spawn.go:3771`, `:3950`).
- **`ntm web` without login only on loopback.** Auth mode `local` refuses any other bind address (`internal/serve/server.go:1137`), and in `api_key` mode the dashboard page and its websocket sit behind the same auth middleware, which a browser cannot satisfy. Hence the socat daemon `ntm-web-publish`.
  - When ntm accepts a trusted forwarder or a browser login: drop `ntm-web-publish` and bind `ntm web` to 0.0.0.0:7337.
- **`ntm web` project pages need `project_dir`,** settable only through `PATCH /api/v1/config` and kept in memory (`internal/serve/server.go:2940`). The tmux hooks and `~/.config/fw/bin/ntm-web-project` set it to the focused session's repository.
  - When a flag or a project picker exists: set a default in the `ntm-web` daemon; with a picker, drop the script and the hooks.
- **`ntm web` Sessions and Agents pages are empty.** Fixed upstream after 1.35.1.
  - Check: `/api/v1/sessions` lists live tmux sessions.
- **A closed bead keeps its pane fenced.** `ntm assign` skips a pane whose assignment record is still active (`internal/cli/assign_placeability.go:147`), and only `--clear` or the completion detector of `ntm assign --watch` (`internal/cli/assign.go:6476`) ends the record; closing the bead in `br` does not. The worker prompt of the scout pipeline ends with `ntm assign <session> --clear <bead>`.
  - Check: whether `ntm assign` releases a pane whose bead is closed.
  - When fixed: drop the clear from `~/.config/ntm/pipelines/prompts/work.md` and step 4 in [ntm.md](ntm.md#scout--worker).

## Agent Mail

Pin: `mcp_agent_mail_rust` 0.3.36. Setup notes: [agent-mail.md](agent-mail.md). File references are to the `v0.3.36` tag.

- **`/web-dashboard` returns 501.** The browser mirror of the TUI is deferred (`docs/SPEC-browser-parity-contract-deferred.md`, tracker `br-il53l`; the routes are in `crates/mcp-agent-mail-server/src/lib.rs`). The interactive TUI exists only in the serving process, so it is reached only through the daemon's tmux server (`mise run fw:am-tui`).
  - Check: `curl -s -o /dev/null -w '%{http_code}' localhost:8765/web-dashboard`.
  - When it serves the mirror: link it from [agent-mail.md](agent-mail.md).
- **MCP over HTTP carries no tmux pane.** The server learns the caller's pane only from an explicit `pane_id` or an `X-Tmux-Pane` header that the clients do not send, so an agent in an ntm pane that calls `register_agent` without it gets a second identity. Related proposal: [issue #279](https://github.com/Dicklesworthstone/mcp_agent_mail_rust/issues/279) (session-bound identity).
  - When the server binds the MCP session to the pane identity: shorten the identity step of `~/.config/fw/instructions/agent-mail.md`.
- **`am guard check` needs a name and ignores `AGENT_MAIL_GUARD_MODE`.** The CLI calls `guard_check`, which resolves the committer before it reads any reservation, instead of `guard_check_full`, which honours the mode (`crates/mcp-agent-mail-cli/src/lib.rs:11001-11051`). The template's `agent-mail-guard` supplies the fallback name and maps `warn` to `--advisory`.
  - When fixed: drop the fallback and the mapping from the guard script.
- **`am agents resolve-pane` is documented as read-only with exit 2 on a miss,** but it upgrades a plain-name identity file and exits 1. Harmless for the hooks.
  - Check: the help text against the behaviour.
- **`last_active_ts` is set only at registration, and `retire_agent` has no CLI command.** `touch_agent` has no caller outside tests (`crates/mcp-agent-mail-db/src/queries.rs:6622`), so `am agents reap` (`crates/mcp-agent-mail-cli/src/lib.rs:39293-39420`) selects agents by registration time and would retire busy ntm pane agents. `am-subagent reap` therefore retires its own identities through a JSON-RPC `retire_agent` call with curl.
  - Check: send a message as an agent, then `am agents show --project <repo> <name> --json | jq .last_active_ts`; `am agents --help` for a retire command.
  - When activity counts: consider `am agents reap` for the subagent identities. When a retire command exists: use it in `am-subagent reap` instead of curl.
- **Only `ensure_project` writes `project.json`, and `am guard check` needs it.** `create_agent_identity`, `register_agent` and reservations create a project without it (writer: `crates/mcp-agent-mail-tools/src/identity.rs:2219`), and the guard resolves the archive only through it (`crates/mcp-agent-mail-cli/src/lib.rs:11107-11140`), so it passes every commit in such a project.
  - Check: `am agents create --project <new repo> ...` through the server, then look for `projects/<slug>/project.json` under `STORAGE_ROOT`.
  - When fixed: drop the quirk from [agent-mail.md](agent-mail.md).
