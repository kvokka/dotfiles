# Flywheel agent stack helpers (Linux devcontainer only; every block is guarded,
# so this file is harmless where the tools are absent).

# ntm shell integration: `ntm bind` palette key, session helpers
if (( $+commands[ntm] )); then
  eval "$(ntm shell zsh)"
fi

# Foreground fallback when the pitchfork daemon is not running
# (normal path: `pitchfork status agent-mail`, `pitchfork start agent-mail`).
amserve() {
  (( $+commands[am] )) || { print -u2 "am is not installed"; return 127; }
  command am serve-http --no-tui --host "${AGENT_MAIL_HOST:-127.0.0.1}" --port "${AGENT_MAIL_PORT:-8765}" --path /mcp/ "$@"
}

# agents [session] [ntm spawn flags]; the session defaults to the cwd name.
agents() {
  local s="${1:-${PWD:t}}"; (( $# )) && shift
  (( $+commands[ntm] )) || { print -u2 "ntm is not installed"; return 127; }
  command ntm spawn "$s" --cc="${NTM_CLAUDE_COUNT:-2}" --cod="${NTM_CODEX_COUNT:-1}" "$@"
}

# Unattended launchers (acfs "vibe mode"); plain `claude`/`codex` keep their defaults.
(( $+commands[claude] )) && {
  unalias cc 2>/dev/null
  cc() {
    NODE_OPTIONS="--max-old-space-size=${CLAUDE_HEAP_MB:-16384}" command claude --dangerously-skip-permissions "$@"
  }
}
(( $+commands[codex] )) && {
  unalias cod 2>/dev/null
  cod() { command codex --dangerously-bypass-approvals-and-sandbox --search "$@"; }
}
