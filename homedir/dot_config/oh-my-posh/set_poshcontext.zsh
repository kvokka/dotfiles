# Container name detection for Oh My Posh
# Add this to your .zshrc AFTER the oh-my-posh init line

function set_poshcontext() {
  # ── Set and format docker compose container name ───────────────────────────────
  if [[ -f /.dockerenv ]] || {
    [[ -f /proc/self/cgroup ]] && grep -q -i -e docker -e lxc /proc/self/cgroup 2>/dev/null
  }; then
    if (( ${+commands[docker]} )) && [[ -S /var/run/docker.sock ]]; then
      local raw_name service_name

      raw_name=$(docker ps --no-trunc --filter "id=${HOSTNAME}" --format '{{.Names}}' 2>/dev/null)

      if [[ -n $raw_name ]]; then
        service_name=$raw_name

        # 1. Remove trailing -NNNN (compose scale / replica suffix)
        service_name=${service_name%-*}     # removes last -something (good for -1)
        service_name=${service_name##*-}    # then takes ONLY the part after the LAST -

        # 2. Remove known project / compose project prefixes
        #    → add your own prefixes here
        local -a common_prefixes=(
          'local-dev-'
          'dev-'
          'compose-'
          'project-'
          'app-'
        )

        for p in $common_prefixes; do
          if [[ $service_name == ${p}* ]]; then
            service_name=${service_name#$p}
            break
          fi
        done

        # 3. Lowercase (and optional length limit)
        export CONTAINER_NAME=${${(L)service_name}}

      else
        export CONTAINER_NAME=${${(L)HOSTNAME}}
      fi

    else
      export CONTAINER_NAME=${${(L)HOSTNAME}}
    fi

  # ── Podman ──────────────────────────────────────────────────
  elif [[ -f /run/.containerenv ]]; then
    export CONTAINER_NAME="${HOSTNAME:-podman}"

  # ── VS Code devcontainer ────────────────────────────────────
  elif [[ -n $DEVCONTAINER_ID ]]; then
    export CONTAINER_NAME="${DEVCONTAINER_ID}"

  # ── GitHub Codespaces ───────────────────────────────────────
  elif [[ -n $CODESPACES ]]; then
    export CONTAINER_NAME="codespace"

  else
    unset CONTAINER_NAME
  fi
}
