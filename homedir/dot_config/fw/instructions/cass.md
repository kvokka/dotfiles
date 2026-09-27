## Past sessions: `cass`

`cass` indexes every agent session on this machine (Claude Code, Codex and others), so a problem another agent already solved is reused, not solved again.

- Never run bare `cass`: it opens a TUI and blocks the session. Always pass `--robot` or `--json`.
- Search: `cass search "<query>" --robot --limit 5`; narrow with `--days N`, `--agent <name>`, `--workspace <path>`, and use `--fields minimal` for lean output.
- Read a hit: `cass view <session.jsonl> --message-index <line_number> --json`, with the hit's `line_number` (`-n` is a physical file line); surrounding context: `cass expand <session.jsonl> --message-index <line_number> -C 3 --json`.
- Search in English keywords: the lexical index drops non-Latin words, so Russian terms find nothing.
- More: `cass capabilities --json`, `cass robot-docs guide`. stdout is data, stderr diagnostics, exit 0 success.
