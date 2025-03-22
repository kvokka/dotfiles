# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi
# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

typeset -g POWERLEVEL9K_KUBECONTEXT_SHOW_ON_COMMAND='provision|deploy|skaffold|kubectl|helm|kubens|kubectx|oc|istioctl|kogito|k9s|helmfile|flux|fluxctl|stern'

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
ZSH_DOTENV_PROMPT=false

. $HOME/.asdf/asdf.sh

fpath=(${ASDF_DIR}/completions $fpath)

# initialise completions with ZSH's compinit
autoload -Uz compinit && compinit

# https://github.com/asdf-vm/asdf/issues/692#issuecomment-642748733
autoload -U +X bashcompinit && bashcompinit

[ -f ~/.iterm2_shell_integration.zsh ] && source ~/.iterm2_shell_integration.zsh

# The next line updates PATH for the Google Cloud SDK.
[ -f ~/.google-cloud-sdk/path.zsh.inc ] && source ~/.google-cloud-sdk/path.zsh.inc

# The next line enables shell command completion for gcloud.
[ -f ~/.google-cloud-sdk/completion.zsh.inc ] && source ~/.google-cloud-sdk/completion.zsh.inc
[ -f ~/.google-cloud-sdk/path.zsh.inc ] && source ~/.google-cloud-sdk/path.zsh.inc
[ -f "$(brew --prefix)/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/path.zsh.inc" ] && source "$(brew --prefix)/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/path.zsh.inc"
[ -f "$(brew --prefix)/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/completion.zsh.inc" ] && source "$(brew --prefix)/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/completion.zsh.inc"

# added by travis gem
[ -f ~/.travis/travis.sh ] && source ~/.travis/travis.sh

[ -f ~/.skaffold-completion ] && source ~/.skaffold-completion
[ -f ~/.minikube/completion ] && source ~/.minikube/completion

[ -f ~/.zshrc_os_specific ] && source ~/.zshrc_os_specific

if type brew &>/dev/null; then
  FPATH=$(brew --prefix)/share/zsh-completions:$(brew --prefix)/share/zsh/site-functions:$FPATH

  autoload -Uz compinit
  compinit
fi

plugins+=(asdf cp docker dotenv gem git github golang kubectl
# globalias
minikube npm rails rake ruby sudo tig vagrant yarn zsh-navigation-tools helm thefuck)

plugins+=(zsh-autosuggestions) # from https://github.com/zsh-users/zsh-autosuggestions
# ZSH_AUTOSUGGEST_STRATEGY=(history completion)

source $ZSH/oh-my-zsh.sh

alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

alias be="bundle exec"
alias gcane='git commit --amend --no-edit'
alias ggggg='rm *.gem && gem build *.gemspec && gem install *.gem && gem push *.gem && gaa'

#alias rubocopstrict="bundle exec rubocop `gss | awk '{print $2}' | grep "rb$" | tr '\n' ' '`"

alias docker_clean_images='docker rmi $(docker images -a --filter=dangling=true -q)'
alias docker_clean_ps='docker rm $(docker ps --filter=status=exited --filter=status=created -q)'

kill_process(){ps -aux | grep $1 | awk '{print $2}' | xargs kill -9 }

# run in docker-conpose bundle context
function dcre() { docker-compose run --entrypoint 'bundle exec' "$@" }

# connet to docker-compose pry
function dcpry() { docker attach $(docker-compose ps -q $1) }

alias bera='bundle exec rubocop -a'
alias beraa='bera && bera'
alias tmp='mkdir -p tmp && cd tmp'

export EDITOR="code -w"
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
export PATH="$PATH:$HOME/.local/bin"

alias rg='/usr/local/bin/rg'
alias gsha='git rev-parse HEAD'
alias gcom='git checkout master'
alias crails='kubectl exec -c rails -it $(kubectl get po -l component=rp-rails-corg -o name --chunk-size=1 | tail -1) -- bundle exec rails console'
alias brepl='gcloud compute ssh --zone "us-central1-a" "mysql-rplication-test1"  --project "replay-gaming"'
alias f=fuck

export USE_GKE_GCLOUD_AUTH_PLUGIN=True
export ASDF_GOLANG_MOD_VERSION_ENABLED=true

