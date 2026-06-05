[ -f ~/.secrets/shared/.env ] && source ~/.secrets/shared/.env

for item in ~/.secrets/host/*(N) ~/.secrets/host/.*(N); do [[ -e $item ]] || continue; ln -sf "$item" ~; done
