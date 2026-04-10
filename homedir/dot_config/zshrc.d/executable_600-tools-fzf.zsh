# fzf appearance and behavior
export FZF_DEFAULT_OPTS='
    --height 40%
    --layout=reverse
    --border
    --info=inline
'

# Ctrl+R: Search command history
export FZF_CTRL_R_OPTS='
    --preview "echo {}"
    --preview-window down:3:wrap
'

# Ctrl+T: Search files
export FZF_CTRL_T_OPTS='
    --preview "head -100 {}"
'

# Alt+C: Change directory
export FZF_ALT_C_OPTS='
    --preview "ls -la {}"
'

if command -v fd &> /dev/null; then
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
fi
