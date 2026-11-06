mise_active fnox && eval "$(fnox activate zsh)"

# deja reads its key only from DEJA_EMBED_KEY, and that key is fnox's
# MONGODB_API_KEY. fnox exports its secrets in a precmd hook, not here, so the
# name is mapped in a precmd hook too: add-zsh-hook appends, and fnox puts its
# own hook first. Not in mise's [env]: mise caches what it renders there, and
# its first prompt may not run at all.
_deja_embed_key() { export DEJA_EMBED_KEY=$MONGODB_API_KEY }
add-zsh-hook precmd _deja_embed_key
