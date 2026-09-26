Scout bead ${vars.bead}. You only read and explore: edit no code, change no
bead, reserve no files. The one file you write is the brief. Earlier beads in
this conversation are unrelated to this one.

1. Run `br show ${vars.bead} --json`, then `br show <id> --json` for each
   dependency and parent it names.
2. Read AGENTS.md and the code the bead touches.
3. Write `.ntm/briefs/${vars.bead}.md`, at most about 150 lines, with:
   - Goal: the outcome and how to tell it is reached.
   - Already done: what the code and closed dependencies already provide.
   - Plan: ordered steps.
   - Files: `path:start-end` with a short excerpt (at most 10 lines) each.
   - Constraints: the AGENTS.md rules that apply and the checks to run.
   - Open questions: what you could not settle, or "none".

A coding agent gets the brief as its first prompt in place of its own
exploration, so name exact paths, symbols and commands.
