# Flywheel agent stack helpers: only while mise's `fw` env is on (miserc.toml);
# every tool is optional.

# ntm shell integration: `ntm bind` palette key, session helpers
if mise_active ntm; then
  eval "$(ntm shell zsh)"
fi

if mise_active cass; then
  eval "$(cass completions zsh)"
fi

# agents [session] [ntm spawn flags]; the session defaults to the cwd name.
agents() {
  local s="${1:-${PWD:t}}"; (( $# )) && shift
  command ntm spawn "$s" --cc="${NTM_CLAUDE_COUNT:-2}" --cod="${NTM_CODEX_COUNT:-1}" "$@"
}

# scouts [session]: the scout session <session>--scout (~/.config/ntm/recipes.toml).
scouts() { command ntm spawn "${1:-${PWD:t}}" --label scout -r scout --no-recovery; }

# scout <bead> [claude|codex], in the repository: a scout explores the bead,
# then an idle pane of the coding session starts on its brief.
scout() {
  command ntm pipeline run ~/.config/ntm/pipelines/scout-work.yaml \
    --session "${PWD:t}--scout" --var bead="$1" --var agent="${2:-any}"
}
