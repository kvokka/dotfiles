# AGENTS.md — PROJECT_NAME_PLACEHOLDER

Instructions for coding agents working in this repository. The user's
explicit instructions always take precedence over this file. Read
`README.md` and `docs/agent-tooling.md` before changing anything.

The agent tools of this machine (cross-session memory, session search,
Agent Mail coordination) bring their own instructions into the session
when they are installed; follow them. This file holds what belongs to the
repository, the Beads tracker included.

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

## Safety

- Never delete files or directories without explicit written permission
  in the current session, including files you created yourself.
- Never run `git reset --hard`, `git checkout -- .`, `git clean -fd`,
  `rm -rf`, force pushes or history rewrites unless the user gives the
  exact command and states the consequences are intended. The repository's
  guard hooks (dcg, from `.rulesync/`) block these and other known-dangerous
  commands before they run; a blocked command needs another approach or
  the user, not a workaround.
- Prefer inspection first: `git status`, `git diff`, `git stash list`.
- Do not bulk-edit code with ad-hoc scripts or giant `sed` runs; make
  small, reviewable changes and read the diff.

## Work tracking: Beads (`br`) and triage (`bv`)

`.beads/` is the single source of truth for task status, priority and
dependencies, committed with the code. `br` never runs git.

```bash
br ready --brief --json                 # unblocked work, pick the highest priority
br show <id> --json                     # details and dependencies
br update <id> --status in_progress     # claim before editing
br create "Title" --type task --priority 2 --description "..."
br dep add <child> <parent>             # child is blocked by parent
br close <id> --reason "What changed"   # after checks pass
br sync --flush-only                    # export before every commit
```

Priorities: 0 critical to 4 backlog. Types: task, bug, feature, epic.
Follow-up work becomes a new bead, not a markdown TODO. Commit messages
carry the bead id (`fix(auth): ... (br-123)`), and `.beads/` is committed
with the change.

Triage with `bv --robot-triage` (full picture), `bv --robot-next` (single
pick plus its claim command) or `bv --robot-plan` (parallel tracks); only
`--robot-*` flags, bare `bv` opens a blocking TUI. Run
`br sync --flush-only` first if the picture looks stale.

## Before every commit

Run the project checks on what you changed and fix real findings at the
root cause. The pre-commit hooks (`.pre-commit-config.yaml`: the Agent Mail
reservation guard, the `ubs` bug scanner, `gitleaks`, formatters) run on
every commit; fix what they report and do not bypass them with
`--no-verify`.

## Landing the plane (ending a session)

Work is not finished until it is pushed.

1. Record remaining work in the tracker; update or close the items you
   touched.
2. Run the project checks on changed files.
3. `git pull --rebase`, commit the intended files, `git push`, then
   `git status` must show the branch up to date with its remote.
4. Hand off context for the next session.

## Multi-agent environment

Other agents work in this worktree at the same time. Uncommitted changes
you did not make are normal: never stash, revert, overwrite or "clean
up" them, and do not stop to ask about them. Treat them as your own
in-progress work and stay inside your reserved paths.
