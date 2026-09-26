# Agent tooling in this repository

This project is set up for multiple coding agents (Claude Code, Codex,
OpenCode, Antigravity) working in the same worktree. The tools below come
from the "agentic coding flywheel" stack (Dicklesworthstone/acfs) and are
installed per machine with `mise`; this document only explains what the
repository expects.

## Tools

| Tool | What it is | Why it is here | How agents use it |
|---|---|---|---|
| `ntm` | Named Tmux Manager: one tmux session per repository under `~/proj/active` with a pane per agent, broadcast prompts, dashboard (F12), prompt palette (F6), web dashboard (<http://localhost:7337>) | The operator's cockpit for running several agents at once; registers every pane in Agent Mail | Agents do not call it; the operator runs `ntm spawn <repo> --cc=2 --cod=1`, `ntm send`, `ntm dashboard`; setup notes: `docs/agent-tooling/ntm.md` |
| `br` | Beads (Rust): local dependency-aware issue tracker in `.beads/` (SQLite + committed `issues.jsonl`) | Single source of truth for what to do next; travels with the code | `br ready --brief --json`, `br update <id> --status in_progress`, `br close <id>`, `br sync --flush-only` |
| `bv` | Beads viewer: graph-aware triage (PageRank, critical path, parallel tracks) | Deterministic answer to "what unlocks the most work" | Only `bv --robot-triage`, `bv --robot-next`, `bv --robot-plan`; bare `bv` is a blocking TUI |
| `am` / `mcp-agent-mail` | MCP Agent Mail: HTTP MCP server (`http://127.0.0.1:8765/mcp/`, web UI at `/mail`) with agent identities, threaded messages and advisory file reservations | Coordination bus between agents; prevents two agents editing the same files | In an ntm pane the agent is already registered (`am agents resolve-pane --project <repo>`), elsewhere it registers once; MCP tools `file_reservation_paths`, `send_message`, `fetch_inbox`; the pre-commit guard enforces reservations; setup notes: `docs/agent-tooling/agent-mail.md` |
| `dcg` | Destructive Command Guard: hook that blocks `rm -rf`, `git reset --hard`, `git clean -fd` and similar before they run | Safety net for autonomous agents in this repository; a repository hook of each agent (`.rulesync/`, `.opencode/plugins/dcg-guard.js`), not a machine-wide one, so a chat session outside such a repository runs what the user asks for | Transparent; a blocked command is reported back to the agent |
| `cc-safety-net` | OpenCode plugin with the same role as `dcg`; blocks `git push -f` / `--force` | Same safety net inside OpenCode; loaded by this repository's `opencode.json` | Transparent |
| `ubs` | Ultimate Bug Scanner: multi-language pattern scanner tuned for generated code | Quality gate before every commit (pre-commit hook, findings fail the commit) | Runs in the pre-commit hook; agents fix its findings, `ubs <files>` reproduces them (exit 0 = clean); setup notes: `docs/agent-tooling/ubs.md` |
| `toon` | Token-Optimized Notation encoder | Compact `--format toon` output of `ubs`, `bv`, `br` for agents | Optional output format, e.g. `bv --robot-triage --format toon` |
| `typos` | Source-code spell checker | Cheap hygiene check on prose and identifiers | `typos` on changed files |
| `cass` | Coding Agent Session Search: indexes past agent sessions of all CLIs (re-indexed every 5 minutes, fully once a day) | Reuse solved problems instead of re-solving them | `cass search "<query>" --robot --limit 5`; never bare `cass`; setup notes: `docs/agent-tooling/cass.md` |
| `cm` | cass-memory: rules and pitfalls learned from past sessions (reflected once a day, at noon); also an MCP server (`http://127.0.0.1:8766/`, `cass-memory`) | Project conventions and past pitfalls in a token budget | Rules for the task arrive with the first prompt; `cm_context` / `cm context "<task>" --json`, `cm_feedback`, `Lessons for memory:` at the end |
| trauma guard | cass-memory traumas: command patterns the owner registered after real damage (`cm trauma add`), blocked for Claude Code and Codex by cass-memory's own guard hook | Stops a repeat of a known incident that generic guards do not know | Transparent; only the owner adds or heals a trauma |
| `pi` | Minimal agent harness for one-shot LLM calls (no tools, no session), one profile per job | Cheap text generation for tooling, e.g. cass-memory's reflection | Operator and tooling only |
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
3. `AGENTS.md`, `.ubsignore`, `.gitignore`, `docs/agent-tooling.md` and `docs/agent-tooling/` from the template.
4. `.pre-commit-config.yaml` + `scripts/hooks/agent-mail-guard`: the global
   git hook runs `prek`, which runs the reservation guard, `ubs`, `gitleaks`
   and formatters on every commit.
5. The `dcg` guard: `rulesync.jsonc` and `.rulesync/hooks.jsonc`, from which
   `rulesync generate` writes `.claude/settings.json`, `.codex/hooks.json` and
   `.agents/hooks.json` (agy); `.opencode/plugins/dcg-guard.js` and
   `opencode.json` (`cc-safety-net`) for OpenCode. Commit them all. rulesync
   replaces the whole hook list of each file it writes, so the task generates
   only while none of them exists; add further hooks to `.rulesync/hooks.jsonc`.
   Codex runs them only in a trusted project, after they are approved once.

The Agent Mail and cass-memory MCP servers need no per-repository step: they
are registered at user scope for every agent client. Both run as pitchfork
daemons (`pitchfork list`); start them before launching agents.

## Instructions for agents

The instructions for cass-memory, cass and Agent Mail are not in
`AGENTS.md`: every session uses them, in this repository or not. Each client
gets them at session start from `~/.config/fw/instructions/` (Claude Code and
Codex through a SessionStart hook, again after compaction; OpenCode through
`instructions`). The first prompt of a session also gets the cass-memory
rules relevant to it. Beads belongs to this repository, so its instructions
are in `AGENTS.md`; `ubs` needs none, the pre-commit hook runs it.

## Component notes

`docs/agent-tooling/<tool>.md` explains how a tool works on this machine and
which parts of its setup look odd but are deliberate. Read it when a tool
behaves unexpectedly or before changing its setup. Before bumping a tool's pin,
read its section in `docs/agent-tooling/upstream-todo.md`: the open upstream
problems, what to check in the new release, and what to change once a problem
is fixed.

## Daily loop

1. Operator: `bv --robot-triage`, then `ntm spawn <repo> --cc=2 --cod=1` (the repository is `~/proj/active/<repo>`) and `ntm attach <repo>`.
2. Agent: read `AGENTS.md` and the tool instructions of the session; the Agent Mail name comes with the session (ntm registered the pane), and the cass-memory rules for the task are already in the first prompt.
3. Agent: `bv --robot-next` or `br ready --brief --json`, claim with `br update <id> --status in_progress`.
4. Agent: `file_reservation_paths(...)` with the bead id as `reason`, announce in thread `<bead id>`.
5. Agent: implement in a narrow slice; run project checks.
6. Agent: `br close <id> --reason ...`, `br sync --flush-only`.
7. Agent: commit with the bead id in the message; the pre-commit hook verifies reservations and runs `ubs`.
8. Agent: `git pull --rebase && git push`; release reservations; completion message.
9. Operator every 10-15 minutes: `bv --robot-next`, `ntm activity <repo> --watch` or the dashboard (F12, <http://localhost:7337>), the Agent Mail web UI (<http://localhost:8765/mail>); `ntm mail send <repo> --all "..."` to steer.
10. End of session: remaining work filed as beads, nothing left unpushed, durable lessons listed under `Lessons for memory:` in the final reply.
