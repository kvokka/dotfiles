# Container name detection for Oh My Posh
# Add this to your .zshrc BEFORE the oh-my-posh init line

_omp_detect_container() {
  if [[ -f /.dockerenv || (-f /proc/self/cgroup && $(grep -q docker /proc/self/cgroup 2>/dev/null && echo "true") == "true") ]]; then
    if command -v docker >/dev/null 2>&1 && [[ -S /var/run/docker.sock ]]; then
      local container_name
      container_name=$(docker ps --filter "id=$(hostname)" --format "{{.Names}}" 2>/dev/null)
      if [[ -n $container_name ]]; then
        # Remove Docker Compose numeric suffix (e.g., -1) and last word (e.g., -app)
        container_name=$(echo "$container_name" | sed 's/-[^-]*-[0-9][0-9]*$//')
        # Create acronym: take first letter of each word (split by - or _), make lowercase
        export CONTAINER_NAME=$(echo "$container_name" | awk -F'[-_]' '{for(i=1; i<=NF; i++) if ($i != "") {printf "%s", substr($i,1,1)}}' | tr '[:upper:]' '[:lower:]')
      else
        export CONTAINER_NAME=$(hostname | cut -c 1-12)
      fi
    else
      export CONTAINER_NAME=$(hostname | cut -c 1-12)
    fi
  elif [[ -f /run/.containerenv ]]; then
    export CONTAINER_NAME="${HOSTNAME:-podman}"
  elif [[ -n "$DEVCONTAINER_ID" ]]; then
    export CONTAINER_NAME="${DEVCONTAINER_ID:0:12}"
  elif [[ -n "$CODESPACES" ]]; then
    export CONTAINER_NAME="codespace"
  else
    unset CONTAINER_NAME
  fi
}
