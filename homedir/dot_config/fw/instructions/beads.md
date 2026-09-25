## Work tracking: Beads (`br`) and triage (`bv`)

`.beads/` in this repository is the single source of truth for task status, priority and dependencies, committed with the code. `br` never runs git.

```bash
br ready --brief --json                 # unblocked work, pick the highest priority
br show <id> --json                     # details and dependencies
br update <id> --status in_progress     # claim before editing
br create "Title" --type task --priority 2 --description "..."
br dep add <child> <parent>             # child is blocked by parent
br close <id> --reason "What changed"   # after checks pass
br sync --flush-only                    # export before every commit
```

Priorities: 0 critical to 4 backlog. Types: task, bug, feature, epic. Follow-up work becomes a new bead, not a markdown TODO. Commit messages carry the bead id (`fix(auth): ... (br-123)`), and `.beads/` is committed with the change.

Triage with `bv --robot-triage` (full picture), `bv --robot-next` (single pick plus its claim command) or `bv --robot-plan` (parallel tracks); only `--robot-*` flags, bare `bv` opens a blocking TUI. Run `br sync --flush-only` first if the picture looks stale.
