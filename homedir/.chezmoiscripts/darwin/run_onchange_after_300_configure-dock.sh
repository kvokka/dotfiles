#!/bin/bash

set -eufo pipefail

trap 'killall Dock' EXIT

declare -a remove_labels=(
	Launchpad
	Messages
	Mail
	Maps
	Photos
	FaceTime
	Calendar
	Contacts
	Reminders
	Notes
	Freeform
	TV
	Music
	Keynote
	Numbers
	Pages
	"App Store"
)

source ~/.zsh/homebrew.zsh

for label in "${remove_labels[@]}"; do
	dockutil --no-restart --remove "${label}" || true
done

dockutil --add /Applications/Visual\ Studio\ Code.app --position 1 &>/dev/null

dockutil --add /Applications/Google\ Chrome.app --position 2 &>/dev/null

dockutil --add /Applications/iTerm.app/ --position 3 &>/dev/null
