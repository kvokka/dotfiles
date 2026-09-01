#!/usr/bin/env bash
# Claude Code status line. Reads the status-line JSON on stdin and prints one
# row: a powerline chain on the left, a second chain pushed to the right edge.
set -uo pipefail

# ${#plain} must count characters, not bytes, or the right-edge padding is off.
case ${LC_ALL:-${LANG:-}} in
  *[Uu][Tt][Ff]*) : ;;
  *) export LC_ALL=C.utf8 ;;
esac

input=$(cat)

# Muted palette, as "r;g;b" for 24-bit ANSI.
FG_ON_DARK="223;229;236"
FG_ON_LIGHT="31;41;51"
BG_MODEL="47;59;71"
BG_DIR="90;125;154"
GIT_CLEAN="127;168;127"
GIT_MODIFIED="201;162;109"
GIT_DIVERGED="184;122;122"
GIT_AHEAD="127;163;184"
GIT_BEHIND="185;138;106"
BG_RAM="92;95;102"
BG_CTX="122;106;158"
BG_CTX_WARN="201;162;109"
BG_CTX_HOT="184;106;106"
BG_QUOTA="74;107;124"

# Nerd Font glyphs. Built with printf so this file stays ASCII: a literal
# private-use character does not survive every editor that touches it.
SEP=$'\ue0b0'        # powerline separator, pointing right
SEP_L=$'\ue0b2'      # powerline separator, pointing left
I_FOLDER=$'\ue5ff'
I_BRANCH=$'\ue0a0'
I_DIRTY=$'\uf044'
I_TREE=$'\uf126'
I_RAM=$'\ue266'      # the glyph the oh-my-posh sysinfo segment uses
I_CTX=$'\uf0f6'      # text document: the context window
I_QUOTA=$'\uf252'    # hourglass: the 5h/7d subscription windows
UP=$'\u2191'
DOWN=$'\u2193'

ESC=$'\033'
RESET="${ESC}[0m"

# Columns held back from the right edge. Claude Code renders the line inside its
# own frame, so the last columns of the terminal are not usable; raise this if
# the tail is still replaced by an ellipsis.
PAD=${CLAUDE_STATUSLINE_PAD:-4}

left=""; left_plain=""; left_bg=""

lseg() { # lseg <bg> <fg> <text>
  local bg=$1 fg=$2 text=$3
  [ -z "$text" ] && return 0
  if [ -n "$left_bg" ]; then
    left+="${ESC}[38;2;${left_bg}m${ESC}[48;2;${bg}m${SEP}"
    left_plain+="$SEP"
  fi
  left+="${ESC}[48;2;${bg}m${ESC}[38;2;${fg}m${text}"
  left_plain+="$text"
  left_bg=$bg
}

command -v jq >/dev/null 2>&1 || { basename "$(pwd)"; exit 0; }

# One jq pass; @sh quotes every value so a path with spaces cannot break eval.
eval "$(printf '%s' "$input" | jq -r '
  @sh "model=\(.model.display_name // "")",
  @sh "effort=\(.effort.level // "")",
  @sh "dir=\(.workspace.current_dir // .cwd // "")",
  @sh "worktree=\(.workspace.git_worktree // .worktree.name // "")",
  @sh "ctx=\(.context_window.used_percentage // "")",
  @sh "pr_num=\(.pr.number // "")",
  @sh "pr_kind=\(.pr.kind // "")",
  @sh "five=\(.rate_limits.five_hour.used_percentage // "")",
  @sh "week=\(.rate_limits.seven_day.used_percentage // "")"
')"

# -- left: model, project folder, branch --------------------------------------
label=$model
[ -n "$effort" ] && label="$label ·$effort"
label=$(printf '%b' "$label")
[ -n "$model" ] && lseg "$BG_MODEL" "$FG_ON_DARK" " $label "

[ -n "$dir" ] && lseg "$BG_DIR" "$FG_ON_DARK" " $I_FOLDER $(basename "$dir") "

if [ -n "$dir" ] && git --no-optional-locks -C "$dir" rev-parse --git-dir >/dev/null 2>&1; then
  head=$(git --no-optional-locks -C "$dir" symbolic-ref --quiet --short HEAD 2>/dev/null) ||
    head=$(git --no-optional-locks -C "$dir" rev-parse --short HEAD 2>/dev/null)
  dirty=$(git --no-optional-locks -C "$dir" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  ahead=0
  behind=0
  if counts=$(git --no-optional-locks -C "$dir" rev-list --left-right --count '@{upstream}...HEAD' 2>/dev/null); then
    behind=${counts%%[[:space:]]*}
    ahead=${counts##*[[:space:]]}
  fi

  git_bg=$GIT_CLEAN
  [ "$dirty" -gt 0 ] && git_bg=$GIT_MODIFIED
  [ "$ahead" -gt 0 ] && git_bg=$GIT_AHEAD
  [ "$behind" -gt 0 ] && git_bg=$GIT_BEHIND
  { [ "$ahead" -gt 0 ] && [ "$behind" -gt 0 ]; } && git_bg=$GIT_DIVERGED

  git_txt=" $I_BRANCH $head"
  [ "$ahead" -gt 0 ] && git_txt="$git_txt $UP$ahead"
  [ "$behind" -gt 0 ] && git_txt="$git_txt $DOWN$behind"
  [ "$dirty" -gt 0 ] && git_txt="$git_txt $I_DIRTY $dirty"
  [ -n "$worktree" ] && git_txt="$git_txt $I_TREE $worktree"
  [ -n "$pr_num" ] && { [ "$pr_kind" = "mr" ] && git_txt="$git_txt !$pr_num" || git_txt="$git_txt #$pr_num"; }
  lseg "$git_bg" "$FG_ON_LIGHT" "$git_txt "
fi

[ -n "$left_bg" ] && { left+="${RESET}${ESC}[38;2;${left_bg}m${SEP}${RESET}"; left_plain+="$SEP"; }

# -- right: RAM, context window, subscription quota ---------------------------
# Collected first, rendered once the width is known: a narrow terminal drops
# them from the back, so the context percentage is the last one to go.
cand=()

if [ -r /proc/meminfo ]; then
  read -r total avail < <(awk '/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2} END{print t, a}' /proc/meminfo)
  if [ "${total:-0}" -gt 0 ]; then
    cand+=("$BG_RAM|$FG_ON_DARK| $I_RAM $(( (total - avail) * 100 / total ))% ")
  fi
fi

if [ -n "$ctx" ]; then
  pct=$(printf '%.0f' "$ctx")
  ctx_bg=$BG_CTX
  ctx_fg=$FG_ON_DARK
  if [ "$pct" -ge 85 ]; then
    ctx_bg=$BG_CTX_HOT
  elif [ "$pct" -ge 60 ]; then
    ctx_bg=$BG_CTX_WARN
    ctx_fg=$FG_ON_LIGHT
  fi
  cand+=("$ctx_bg|$ctx_fg| $I_CTX ${pct}% ")
fi

# Both windows share one segment: 5-hour / 7-day.
quota=""
[ -n "$five" ] && quota=$(printf '%.0f' "$five")
if [ -n "$week" ]; then
  [ -n "$quota" ] && quota="$quota/$(printf '%.0f' "$week")" || quota="-/$(printf '%.0f' "$week")"
fi
[ -n "$quota" ] && cand+=("$BG_QUOTA|$FG_ON_DARK| $I_QUOTA ${quota}% ")

# -- terminal width -----------------------------------------------------------
# /dev/tty may pass [ -r ] and still fail to open (no controlling terminal),
# so the redirect itself has to run inside the silenced group.
cols=${COLUMNS:-0}
if [ "${cols:-0}" -le 0 ]; then
  cols=$({ tput cols </dev/tty; } 2>/dev/null) || cols=0
fi
if [ "${cols:-0}" -le 0 ]; then
  cols=$({ stty size </dev/tty; } 2>/dev/null | cut -d' ' -f2) || cols=0
fi
[ -z "$cols" ] && cols=0

# -- render the right chain, dropping segments until it fits ------------------
budget=$(( cols - ${#left_plain} - PAD ))
n=${#cand[@]}
right=""; right_plain=""
while [ "$n" -gt 0 ]; do
  right=""; right_plain=""; prev_bg=""
  for ((i = 0; i < n; i++)); do
    IFS='|' read -r bg fg text <<<"${cand[i]}"
    if [ -z "$prev_bg" ]; then
      right+="${ESC}[38;2;${bg}m${SEP_L}"
    else
      right+="${ESC}[48;2;${prev_bg}m${ESC}[38;2;${bg}m${SEP_L}"
    fi
    right_plain+="$SEP_L"
    right+="${ESC}[48;2;${bg}m${ESC}[38;2;${fg}m${text}"
    right_plain+="$text"
    prev_bg=$bg
  done
  right+="$RESET"
  # A width Claude Code could not report leaves cols at 0: render everything.
  [ "$cols" -le 0 ] && break
  [ "${#right_plain}" -le "$budget" ] && break
  n=$(( n - 1 ))
done
[ "$n" -eq 0 ] && { right=""; right_plain=""; }

gap=$(( budget - ${#right_plain} ))
if [ "$gap" -lt 1 ]; then gap=1; fi
printf '%s%*s%s' "$left" "$gap" "" "$right"
