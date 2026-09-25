# AGENTS.md — PROJECT_NAME_PLACEHOLDER

Instructions for coding agents working in this repository. The user's
explicit instructions always take precedence over this file. Read
`README.md` and `docs/agent-tooling.md` before changing anything.

The agent tools of this machine (cross-session memory, session search,
Agent Mail coordination, the Beads tracker, the bug scanner) bring their
own instructions into the session when they are installed; follow them.
This file only holds what belongs to the repository.

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
  exact command and states the consequences are intended. Guard hooks may
  block these and other known-dangerous commands before they run; a
  blocked command needs another approach, not a workaround.
- Prefer inspection first: `git status`, `git diff`, `git stash list`.
- Do not bulk-edit code with ad-hoc scripts or giant `sed` runs; make
  small, reviewable changes and read the diff.

## Before every commit

Run the project checks on what you changed and fix real findings at the
root cause. The pre-commit hooks (`.pre-commit-config.yaml`) run on every
commit; do not bypass them with `--no-verify`.

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
