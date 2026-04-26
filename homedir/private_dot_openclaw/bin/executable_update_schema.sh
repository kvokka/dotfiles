#!/usr/bin/env zsh

# Openclaw schema drift is easier to track this way for now

openclaw config schema > ~/.openclaw/openclaw_schema.json
chezmoi add ~/.openclaw/openclaw_schema.json
