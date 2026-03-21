#!/bin/bash

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SOURCE_DIR/helpers.sh"

git_prompt() {
  local reset='\[\033[0m\]'
  local blue='\[\033[0;34m\]'
  local yellow='\[\033[0;33m\]'
  local green='\[\033[0;32m\]'
  local red='\[\033[0;31m\]'

  local repo=$(git_repo_name)
  [ -z "$repo" ] && return

  local prompt="[${blue}${repo}${reset}$(git_sub_path)]"

  local parts=()

  # Branch
  local branch=$(git_branch)
  if [ -n "$branch" ]; then
    parts+=("${blue}${branch}${reset}")
  fi

  # Behind / Ahead
  local remote_exists=$(git_remote_branch_exists)
  if [ -n "$remote_exists" ]; then
    local behind=$(git_behind)
    if [ -n "$behind" ]; then
      parts+=("${yellow}↓${behind}${reset}")
    fi

    local ahead=$(git_ahead)
    if [ -n "$ahead" ]; then
      parts+=("${yellow}↑${ahead}${reset}")
    fi
  else
    parts+=("${yellow}×${reset}")
  fi

  # Staged
  local staged=$(git_staged_changes)
  if [ -n "$staged" ]; then
    parts+=("${green}+${reset}")
  fi

  # Unstaged
  local unstaged=$(git_unstaged_changes)
  if [ -n "$unstaged" ]; then
    parts+=("${red}*${reset}")
  fi

  if [ ${#parts[@]} -gt 0 ]; then
    local status=""
    for i in "${!parts[@]}"; do
      [ "$i" -gt 0 ] && status+="|"
      status+="${parts[$i]}"
    done
    prompt+=" (${status})"
  fi

  echo -e "$prompt"
}

# Test: echo the prompt
git_prompt
