# Remove this part after full transition to fnox
[ -f ~/.secrets/shared/.env ] && source ~/.secrets/shared/.env

for item in ~/.secrets/host/*(N) ~/.secrets/host/.*(N); do [[ -e $item ]] || continue; ln -sf "$item" ~; done

################## Until this line

command -v fnox >/dev/null 2>&1 && eval "$(fnox activate zsh)"
