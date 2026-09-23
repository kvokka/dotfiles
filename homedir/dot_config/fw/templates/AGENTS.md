# AGENTS.md — PROJECT_NAME_PLACEHOLDER

Instructions for coding agents working in this repository. The user's
explicit instructions always take precedence over this file. Read
`README.md` and `docs/agent-tooling.md` before changing anything.

## Project commands

Replace this section with the real commands before assigning agents:

- setup: `<command>`
- format: `<command>`
- lint: `<command>`
- type-check: `<command>`
- test: `<command>`
- build: `<command>`

Never claim completion without running the applicable checks and
reporting the observed result.

## Before you start

```bash
cm context "<task summary>" --json        # conventions and pitfalls distilled from past sessions
cass search "<query>" --robot --limit 5   # how similar problems were solved before
```

Both are also available as MCP servers (`cass-memory`, `mcp-agent-mail`).

## Safety

- Never delete files or directories without explicit written permission
  in the current session, including files you created yourself.
- Never run `git reset --hard`, `git checkout -- .`, `git clean -fd`,
  `rm -rf`, force pushes or history rewrites unless the user gives the
  exact command and states the consequences are intended. A guard hook
  (`dcg`) blocks these commands before they run.
- Prefer inspection first: `git status`, `git diff`, `git stash list`.
- Do not bulk-edit code with ad-hoc scripts or giant `sed` runs; make
  small, reviewable changes and read the diff.

## Work tracking: Beads (`br`)

`.beads/` is the single source of truth for task status, priority and
dependencies, and it is committed with the code. `br` never runs git.

```bash
br ready --brief --json                 # unblocked work, pick highest priority
br show <id> --json                     # details and dependencies
br update <id> --status in_progress     # claim before editing
br create "Title" --type task --priority 2 --description "..."
br dep add <child> <parent>             # child is blocked by parent
br close <id> --reason "What changed"   # after checks pass
br sync --flush-only                    # final JSONL export check before commit
```

Priorities: 0 critical, 1 high, 2 medium, 3 low, 4 backlog. Types:
task, bug, feature, epic. Discovered follow-up work becomes a new bead;
do not keep markdown TODO lists.

## Triage: `bv`

Use only `--robot-*` flags; bare `bv` opens a TUI that blocks the session.

```bash
bv --robot-triage      # full picture: what to do now and why
bv --robot-next        # single top pick plus the claim command
bv --robot-plan        # parallel execution tracks
```

`bv` reads `.beads/issues.jsonl`; run `br sync --flush-only` after
mutations if the picture looks stale.

## Coordination: MCP Agent Mail

The `mcp-agent-mail` MCP server is registered at user scope for every agent
client on the machine, so this repository carries no MCP configuration of its
own. Use the repository's absolute path as `project_key`, and the bead id as
the shared identifier.

1. Register:
   `ensure_project(human_key=<abs repo path>)`,
   `register_agent(project_key, program, model, task_description)`.
2. Reserve before editing:
   `file_reservation_paths(project_key, agent_name, ["src/**"],
   ttl_seconds=3600, exclusive=true, reason="br-123")`.
3. Announce and talk in the bead's thread:
   `send_message(..., thread_id="br-123", subject="[br-123] Start: ...")`,
   `fetch_inbox(project_key, agent_name)`,
   `acknowledge_message(project_key, agent_name, message_id)`.
4. Finish: `release_file_reservations(project_key, agent_name)` and a
   final `[br-123] Completed: ...` message.
5. Quick reads: `resource://inbox/{Agent}?project=<abs path>&limit=20`,
   `resource://thread/{id}?project=<abs path>&include_bodies=true`.

Macros `macro_start_session`, `macro_prepare_thread`,
`macro_file_reservation_cycle` and `macro_contact_handshake` bundle the
steps above; use granular tools when you need control.

Pitfalls: `from_agent not registered` means `register_agent` was skipped
for this `project_key`; `FILE_RESERVATION_CONFLICT` means another agent
holds the path: narrow the pattern, wait for expiry, or reserve
non-exclusively. Reservations are advisory; the pre-commit guard blocks
commits that touch files reserved by someone else.

## Before every commit

```bash
ubs $(git diff --name-only --cached)    # bug scanner on staged files; exit 0 = clean
br sync --flush-only
```

Fix real findings at the root cause, re-run until exit 0. Commit
messages include the bead id (`fix(auth): ... (br-123)`). The pre-commit
hooks (`.pre-commit-config.yaml`) run the Agent Mail reservation guard,
`ubs`, secret scanning and formatters; do not bypass them with `--no-verify`.

## Landing the plane (ending a session)

Work is not finished until it is pushed.

1. File beads for remaining work; update or close the ones you touched.
2. Run the project checks and `ubs` on changed files.
3. `git pull --rebase`, `br sync --flush-only`, `git add .beads/` plus
   the intended files, commit, `git push`, then `git status` must show
   the branch up to date with its remote.
4. Release file reservations, send the completion message, hand off
   context for the next session.

## Multi-agent environment

Other agents work in this worktree at the same time. Uncommitted changes
you did not make are normal: never stash, revert, overwrite or "clean
up" them, and do not stop to ask about them. Treat them as your own
in-progress work and stay inside your reserved paths.
