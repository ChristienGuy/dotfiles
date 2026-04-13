#!/usr/bin/env zsh

# Source the file under test
source "${0:A:h}/.zsh_aliases"

ztr clear-summary

# Editor aliases
ztr test '[[ "$(alias cod)" == *"code ."* ]]' 'cod alias points to code .'
ztr test '[[ "$(alias curs)" == *"cursor ."* ]]' 'curs alias points to cursor .'

# Core git aliases
ztr test '[[ "$(alias ga)" == *"git add"* ]]' 'ga alias defined'
ztr test '[[ "$(alias gaa)" == *"git add --all"* ]]' 'gaa alias defined'
ztr test '[[ "$(alias gb)" == *"git branch"* ]]' 'gb alias defined'
ztr test '[[ "$(alias gba)" == *"git branch --all"* ]]' 'gba alias defined'
ztr test '[[ "$(alias gbd)" == *"git branch --delete"* ]]' 'gbd alias defined'
ztr test '[[ "$(alias gc)" == *"git commit --verbose"* ]]' 'gc alias defined'
ztr test '[[ "$(alias gcb)" == *"git checkout -b"* ]]' 'gcb alias defined'
ztr test '[[ "$(alias gco)" == *"git checkout"* ]]' 'gco alias defined'
ztr test '[[ "$(alias gcp)" == *"git cherry-pick"* ]]' 'gcp alias defined'
ztr test '[[ "$(alias gd)" == *"git diff"* ]]' 'gd alias defined'
ztr test '[[ "$(alias gl)" == *"git pull"* ]]' 'gl alias defined'
ztr test '[[ "$(alias gm)" == *"git merge"* ]]' 'gm alias defined'
ztr test '[[ "$(alias gp)" == *"git push"* ]]' 'gp alias defined'
ztr test '[[ "$(alias grb)" == *"git rebase"* ]]' 'grb alias defined'
ztr test '[[ "$(alias gst)" == *"git status"* ]]' 'gst alias defined'
ztr test '[[ "$(alias gpsup)" == *"git push --set-upstream"* ]]' 'gpsup alias defined'

# Git spice
ztr test '[[ "$(alias gs)" == *"git-spice"* ]]' 'gs alias points to git-spice'

echo
ztr summary
