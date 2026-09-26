## Memory: cass-memory (`cm`)

Rules learned from earlier agent sessions on this machine, served by the MCP server `cass-memory`: global ones, and the repository's own in `.cass/playbook.yaml`. They are hints: the current code, AGENTS.md and the user win when they disagree. `.cass/playbook.yaml` is written by cass-memory: never edit it, commit its changes as they are.

- Before non-trivial work, read the `# Context for:` block from cass-memory if the session has one; otherwise call `cm_context(task="<one line>", workspace="<absolute repository root>")`, or run `cm context "<task>" --json` in the repository.
- When you act on a rule, name its id in your reply: "Following b-xxxx: ...". Only ids written in the conversation are graded.
- When a rule clearly helped or misled you, call `cm_feedback(bulletId="b-xxxx", helpful=true, reason="...")` (or `harmful=true`).
- When you finish a task and learned something durable (a pitfall, a convention, a command that works), end your final reply with a `Lessons for memory:` list, one imperative line per lesson; name the repository when a lesson holds only there. Lessons are learned from the transcript later; do not add rules yourself.
- Never call `memory_reflect` or `cm_outcome`, never write `[cass: ...]` markers into files, never run `cm trauma heal`, `cm trauma remove` or `cm playbook add`. A command blocked by a trauma needs another approach or the owner.
