# Claude Code's shell only (CLAUDECODE=1 comes from its environment, and the snapshot it takes of this
# shell keeps these options): bash's globbing, which agents write for. An unmatched glob stays a plain
# word instead of failing the whole line (`grep -r --include=*.py`), and a word that starts with `=` is
# not looked up as a command (`echo =====`). deja's index of past sessions counted these two as the
# machine's most frequent agent failures: 84-122 sessions per glob form and 104 for `=` (2026-11-08).
if [[ -n $CLAUDECODE ]]; then
  setopt no_nomatch
  unsetopt equals
fi
