#!/bin/bash

compaudit | xargs chmod g-w

echo ">>> Installation is done!"
[[ -t 0 ]] && echo ">>> Re-login to apply all changes" && zsh || true
