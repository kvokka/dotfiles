# Flywheel agent stack helpers (Linux devcontainer only; every block is guarded,
# so this file is harmless where the tools are absent).

# ntm shell integration: `ntm bind` palette key, session helpers
if (( $+commands[ntm] )); then
  eval "$(ntm shell zsh)"
fi

if (( $+commands[cass] )); then
  eval "$(cass completions zsh)"
fi

# agents [session] [ntm spawn flags]; the session defaults to the cwd name.
agents() {
  local s="${1:-${PWD:t}}"; (( $# )) && shift
  (( $+commands[ntm] )) || { print -u2 "ntm is not installed"; return 127; }
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

# Unattended launchers (acfs "vibe mode"); plain `claude`/`codex` keep their defaults.
(( $+commands[claude] )) && alias cc='NODE_OPTIONS="--max-old-space-size=${CLAUDE_HEAP_MB:-16384}" command claude --dangerously-skip-permissions'
(( $+commands[codex] )) && alias cod='command codex --dangerously-bypass-approvals-and-sandbox --search'
