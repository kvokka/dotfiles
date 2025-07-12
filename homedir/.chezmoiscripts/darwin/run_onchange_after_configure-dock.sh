#!/bin/bash

set -eufo pipefail

trap 'killall Dock' EXIT

command -v dockutil &> /dev/null || brew install dockutil

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

for label in "${remove_labels[@]}"; do
	dockutil --no-restart --remove "${label}" || true
done
