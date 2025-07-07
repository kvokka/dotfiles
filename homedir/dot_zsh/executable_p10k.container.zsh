# Function to get container name acronym (only inside Docker)
get_container_name() {
  # Check if running inside a Docker container
  if [[ -f /.dockerenv || -f /proc/self/cgroup && $(grep -q docker /proc/self/cgroup && echo "true") == "true" ]]; then
    if command -v docker >/dev/null 2>&1 && [ -S /var/run/docker.sock ]; then
      # Get container name from docker ps, filter by container ID
      local container_name=$(docker ps --filter "id=$(hostname)" --format "{{.Names}}" 2>/dev/null)
      if [[ -n $container_name ]]; then
        # Remove Docker Compose numeric suffix (e.g., -2) and last word (e.g., -app)
        container_name=$(echo "$container_name" | sed 's/-[^-]*-[0-9][0-9]*$//')
        # Create acronym: take first letter of each word (split by - or _), make lowercase
        echo "$container_name" | awk -F'[-_]' '{for(i=1; i<=NF; i++) if ($i != "") {printf "%s", substr($i,1,1)}}' | tr '[:upper:]' '[:lower:]'
      else
        # Fallback to hostname (container ID) if docker ps fails
        echo "$(hostname)" | cut -c 1-12
      fi
    else
      # Fallback to hostname (container ID) if Docker CLI/socket unavailable
      echo "$(hostname)" | cut -c 1-12
    fi
  else
    # Return empty string if not in a Docker container
    echo ""
  fi
}

# Define a custom prompt segment for container name
function prompt_container() {
  local container_name=$(get_container_name)
  if [[ -n $container_name ]]; then
    p10k segment -i '' -f cyan -t "$container_name"
  fi
}

# # Add the container segment to the left prompt
# typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(
#   container  # Add custom container segment
# )
