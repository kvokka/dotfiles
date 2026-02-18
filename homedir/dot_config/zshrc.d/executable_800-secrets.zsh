for item in ~/.secrets/home/*(N) ~/.secrets/home/.^*(N); do [[ -e $item ]] || continue; ln -sf "$item" ~; done
[ -f ~/.secrets/shared/.env ] && source ~/.secrets/shared/.env
