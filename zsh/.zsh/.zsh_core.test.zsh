#!/usr/bin/env zsh

# We don't source .zsh_core directly because it initializes external tools
# (starship, fzf, zoxide, antidote, nvm) which may not be available or fast.
# Instead we use zsh -n for syntax check and grep to verify expected config.

ztr clear-summary

core_file="${0:A:h}/.zsh_core"

# File is valid zsh syntax
ztr test 'zsh -n "$core_file"' '.zsh_core passes syntax check'

# Environment variables are configured
ztr test 'grep -q "EDITOR=" "$core_file"' 'EDITOR is configured in .zsh_core'
ztr test 'grep -q "HISTFILE=" "$core_file"' 'HISTFILE is configured in .zsh_core'
ztr test 'grep -q "HISTSIZE=100000" "$core_file"' 'HISTSIZE is set to 100000'
ztr test 'grep -q "SAVEHIST=100000" "$core_file"' 'SAVEHIST is set to 100000'

# History options are set
ztr test 'grep -q "APPEND_HISTORY" "$core_file"' 'APPEND_HISTORY option is set'
ztr test 'grep -q "HIST_IGNORE_ALL_DUPS" "$core_file"' 'HIST_IGNORE_ALL_DUPS option is set'
ztr test 'grep -q "INC_APPEND_HISTORY" "$core_file"' 'INC_APPEND_HISTORY option is set'

# Sourcing chain is intact
ztr test 'grep -q "source.*\.zsh_aliases" "$core_file"' '.zsh_core sources .zsh_aliases'
ztr test 'grep -q "source.*\.zsh_functions" "$core_file"' '.zsh_core sources .zsh_functions'

echo
ztr summary
