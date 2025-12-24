#!/bin/bash

set -eu

[[ ! -t 0 ]] && export NONINTERACTIVE=1 # Allow user to enter sudo pass for brew setup on mac
command -v brew &> /dev/null || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# POSIX way to get script's dir: https://stackoverflow.com/a/29834779/12156188
script_dir="$(cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P)"

command -v chezmoi &>/dev/null || sh -c "$(curl -fsLS get.chezmoi.io/lb)" -- init --apply --force --purge-binary --source=$script_dir kvokka
