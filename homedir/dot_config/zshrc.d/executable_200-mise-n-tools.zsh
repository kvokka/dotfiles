eval "$(mise activate zsh)"

# mise_active <command>: the command is there and is not a stale mise shim.
# mise keeps a shim for every installed tool, also for the tools of a config
# env that is off (their installs stay in the home volume), and such a shim
# fails with "No version is set". `mise activate` puts the directories of the
# active tools on PATH ahead of the shims.
mise_active() {
  [[ -n ${commands[$1]} && ${commands[$1]:h} != ${MISE_DATA_DIR:-$HOME/.local/share/mise}/shims ]]
}
