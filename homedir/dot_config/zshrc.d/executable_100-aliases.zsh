alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

alias gcane='git commit --amend --no-edit'

alias docker_clean_images='docker rmi $(docker images -a --filter=dangling=true -q)'
alias docker_clean_ps='docker rm $(docker ps --filter=status=exited --filter=status=created -q)'

kill_process(){ps -aux | grep $1 | awk '{print $2}' | xargs kill -9 }

alias tmp='mkdir -p tmp && cd tmp'

alias gsha='git rev-parse HEAD'
alias gcom='git checkout master'
alias ag='aicommit2'

alias brave_debug="open -a 'Brave Browser' --args --remote-debugging-port=9222"

alias quotio_models='curl -H "Authorization: Bearer ${QUOTIO_PROXY_API_KEY}" "${QUOTIO_PROXY_URL}/models" | jq'

DC_FILE_LOCAL_DEV="$HOME/.config/docker-compose/local-dev/docker-compose.yml"

dc() {
    command docker compose -f "$DC_FILE_LOCAL_DEV" "$@"
}

alias dcup='dc up -d'
alias dcupb='dc up -d --build'
alias dcdown='dc down'
alias dcwipe='dc down --remove-orphans --rmi all --volumes'
alias dcrebuild='dcwipe && dcupb'
alias dcl='dc logs -f --tail=100'
alias dcps='dc ps --format "table {{.Name}}\t{{.State}}\t{{.Ports}}"'

# Interactive shell aliases (both variants are useful)
alias dcr='dc run --rm -it console zsh'
alias dce='dc exec -it console zsh'
