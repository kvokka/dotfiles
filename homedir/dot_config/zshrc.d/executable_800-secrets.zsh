[ -f ~/.secrets/shared/.env ] && source ~/.secrets/shared/.env

for item in ~/.secrets/home/*(N) ~/.secrets/home/.^*(N); do [[ -e $item ]] || continue; ln -sf "$item" ~; done
