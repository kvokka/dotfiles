#!/bin/bash

set -eufo pipefail

[[ "$OSTYPE" != "darwin"* ]] && exit 0

defaults write -g AppleMiniaturizeOnDoubleClick -int 0
defaults write -g ApplePressAndHoldEnabled -int 0
defaults write -g InitialKeyRepeat -int 25
defaults write -g KeyRepeat -int 1
defaults write -g InitialKeyRepeat -float 0.4
defaults write -g KeyRepeat -float 0.016666
defaults write -g NSAutomaticCapitalizationEnabled -int 1
defaults write -g NSAutomaticDashSubstitutionEnabled -int 1
defaults write -g NSAutomaticPeriodSubstitutionEnabled -int 1
defaults write -g NSAutomaticSpellingCorrectionEnabled -int 1
defaults write -g NSAutomaticQuoteSubstitutionEnabled -int 1
defaults write -g NSDocumentSaveNewDocumentsToCloud -int 0
defaults write -g WebAutomaticSpellingCorrectionEnabled -int 1
defaults write -g com.apple.swipescrolldirection -int 0
defaults write -g com.apple.trackpad.forceClick -int 0

defaults write com.apple.dock autohide -int 0
defaults write com.apple.dock largesize -int 128

defaults write com.apple.finder FXPreferredViewStyle -string Nlsv
defaults write com.apple.finder FXRemoveOldTrashItems -int 1
