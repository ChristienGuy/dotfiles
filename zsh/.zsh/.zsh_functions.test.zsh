#!/usr/bin/env zsh

# Source the file under test
source "${0:A:h}/.zsh_functions"

ztr clear-summary

# Functions are defined
ztr test '(( ${+functions[fsb]} ))' 'fsb function is defined'
ztr test '(( ${+functions[fsbd]} ))' 'fsbd function is defined'
ztr test '(( ${+functions[fslog]} ))' 'fslog function is defined'
ztr test '(( ${+functions[dash:dev]} ))' 'dash:dev function is defined'

# Shared FZF config variables are set
ztr test '[[ -n "$_fzf_git_branch_preview" ]]' '_fzf_git_branch_preview is set'
ztr test '(( ${#_fzf_git_branch_opts} > 0 ))' '_fzf_git_branch_opts array is non-empty'
ztr test '(( ${#_fzf_git_preview_opts} > 0 ))' '_fzf_git_preview_opts array is non-empty'

# FZF opts contain expected values
ztr test '[[ "${_fzf_git_branch_opts[*]}" == *"--layout=reverse"* ]]' '_fzf_git_branch_opts includes --layout=reverse'
ztr test '[[ "${_fzf_git_branch_opts[*]}" == *"--padding=1,2"* ]]' '_fzf_git_branch_opts includes --padding=1,2'
ztr test '[[ "${_fzf_git_preview_opts[*]}" == *"--preview-window=down:70%"* ]]' '_fzf_git_preview_opts includes --preview-window=down:70%'

echo
ztr summary
