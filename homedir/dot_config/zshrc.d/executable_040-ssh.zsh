{{ if eq .chezmoi.os "linux" }}
eval "$(ssh-agent -s)" 1> /dev/null
{{ end }}
