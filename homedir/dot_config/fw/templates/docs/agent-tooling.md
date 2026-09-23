# Agent tooling in this repository

This project is set up for multiple coding agents (Claude Code, Codex,
OpenCode, Antigravity) working in the same worktree. The tools below come
from the "agentic coding flywheel" stack (Dicklesworthstone/acfs) and are
installed per machine with `mise`; this document only explains what the
repository expects.

## Tools

| Tool | What it is | Why it is here | How agents use it |
|---|---|---|---|
| `ntm` | Named Tmux Manager: one tmux session per project with a pane per agent, broadcast prompts, dashboard | The operator's cockpit for running several agents at once | Agents do not call it; the operator runs `ntm spawn <project> --cc=2 --cod=1`, `ntm send`, `ntm dashboard` |
| `br` | Beads (Rust): local dependency-aware issue tracker in `.beads/` (SQLite + committed `issues.jsonl`) | Single source of truth for what to do next; travels with the code | `br ready --brief --json`, `br update <id> --status in_progress`, `br close <id>`, `br sync --flush-only` |
| `bv` | Beads viewer: graph-aware triage (PageRank, critical path, parallel tracks) | Deterministic answer to "what unlocks the most work" | Only `bv --robot-triage`, `bv --robot-next`, `bv --robot-plan`; bare `bv` is a blocking TUI |
| `am` / `mcp-agent-mail` | MCP Agent Mail: HTTP MCP server (`http://127.0.0.1:8765/mcp/`) with agent identities, threaded messages and advisory file reservations | Coordination bus between agents; prevents two agents editing the same files | MCP tools `ensure_project`, `register_agent`, `file_reservation_paths`, `send_message`, `fetch_inbox`; the pre-commit guard enforces reservations |
| `dcg` | Destructive Command Guard: hook that blocks `rm -rf`, `git reset --hard`, `git clean -fd` and similar before they run | Safety net for autonomous agents; registered in every agent's hook config | Transparent; a blocked command is reported back to the agent |
| `cc-safety-net` | OpenCode plugin with the same role as `dcg`; blocks `git push -f` / `--force` | Same safety net inside OpenCode | Transparent |
| `ubs` | Ultimate Bug Scanner: multi-language pattern scanner tuned for generated code | Quality gate before every commit (pre-commit hook, findings fail the commit) | `ubs <changed files>` (exit 0 = clean) |
| `toon` | Token-Optimized Notation encoder | Compact `--format toon` output of `ubs`, `bv`, `br` for agents | Optional output format, e.g. `bv --robot-triage --format toon` |
| `typos` | Source-code spell checker | Cheap hygiene check on prose and identifiers | `typos` on changed files |
| `cass` | Coding Agent Session Search: indexes past agent sessions of all CLIs (re-indexed every 5 minutes, fully once a day) | Reuse solved problems instead of re-solving them | `cass search "<query>" --robot --limit 5`; never bare `cass`; setup status and pending upstream fixes: `docs/update_notes/cass.md` |
| `cm` | cass-memory: procedural memory distilled from sessions; also an MCP server (`http://127.0.0.1:8766/`, `cass-memory`) | Project conventions and past pitfalls in a token budget | `cm context "<task>" --json` before non-trivial work |
| `ru` | Repo updater: sync many repositories, detect conflicts | Operator hygiene across projects | Operator only (`ru sync`, `ru status --fetch`) |
| `jfp` | JeffreysPrompts CLI: curated prompt library | Prompt source for the operator's palette | Operator only |
| `brenner` | Brenner Bot: multi-agent research sessions with cited sources | Research and hypothesis work, not coding | On request only |
| `sbh` | Storage Ballast Helper: predictive disk-space protection and build-artifact cleanup | Keeps the machine alive under many parallel builds | Operator only (`sbh status`) |
| `fmd` | Franken Markdown: deterministic Markdown to HTML/PDF renderer | Rendering docs like this one | `fmd README.md --out README.html` |
| `aadc` | ASCII Art Diagram Corrector | Fixes ASCII diagrams in generated docs | `aadc <file>` when a diagram is misaligned |
| `agy` | Antigravity CLI (Google's agentic IDE runtime) | One more agent type in the swarm | Started by the operator via `ntm spawn ... --agy=1` |

## Per-repository bootstrap

`mise run fw:init` does all of this idempotently; the manual equivalent:

1. `git init -b main` (new repositories only).
2. `br init` creates `.beads/` with its own `.gitignore`; commit `.beads/`.
3. `AGENTS.md`, `.ubsignore`, `.gitignore`, `docs/agent-tooling.md` from the template.
4. `.pre-commit-config.yaml` + `scripts/hooks/agent-mail-guard`: the global
   git hook runs `prek`, which runs the reservation guard, `ubs`, `gitleaks`
   and formatters on every commit.

The Agent Mail and cass-memory MCP servers need no per-repository step: they
are registered at user scope for every agent client. Both run as pitchfork
daemons (`pitchfork status agent-mail cm`); start them before launching agents.

## Daily loop

1. Operator: `bv --robot-triage`, then `ntm spawn <project> --cc=2 --cod=1`.
2. Agent: read `AGENTS.md`, `register_agent` in Agent Mail, `cm context`.
3. Agent: `bv --robot-next` or `br ready --brief --json`, claim with `br update <id> --status in_progress`.
4. Agent: `file_reservation_paths(...)` with the bead id as `reason`, announce in thread `<bead id>`.
5. Agent: implement in a narrow slice; run project checks.
6. Agent: `ubs <changed files>`, `br close <id> --reason ...`, `br sync --flush-only`.
7. Agent: commit with the bead id in the message; the guard verifies reservations.
8. Agent: `git pull --rebase && git push`; release reservations; completion message.
9. Operator every 10-15 minutes: `bv --robot-next`, Agent Mail inbox, `ntm activity <project> --watch`.
10. End of session: remaining work filed as beads, nothing left unpushed.
