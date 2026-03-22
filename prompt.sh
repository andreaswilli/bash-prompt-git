#!/bin/bash

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SOURCE_DIR/helpers.sh"

# Customizable git prompt. See README.md for configuration details.

git_prompt() {
  local reset='\[\033[0m\]'
  local color_repo="${GIT_PROMPT_COLOR_REPO:-\[\033[0;34m\]}"
  local color_path="${GIT_PROMPT_COLOR_PATH:-\[\033[0m\]}"
  local color_branch="${GIT_PROMPT_COLOR_BRANCH:-\[\033[0;34m\]}"
  local color_behind="${GIT_PROMPT_COLOR_BEHIND:-\[\033[0;33m\]}"
  local color_ahead="${GIT_PROMPT_COLOR_AHEAD:-\[\033[0;33m\]}"
  local color_no_remote="${GIT_PROMPT_COLOR_NO_REMOTE:-\[\033[0;33m\]}"
  local color_staged="${GIT_PROMPT_COLOR_STAGED:-\[\033[0;32m\]}"
  local color_unstaged="${GIT_PROMPT_COLOR_UNSTAGED:-\[\033[0;31m\]}"
  local format
  if [ -n "$GIT_PROMPT_FORMAT" ]; then
    format="$GIT_PROMPT_FORMAT"
  else
    format='[<repo><path>] ({<branch>}{|<behind>}{|<ahead>}{|<no_remote>}{|<staged>}{|<unstaged>})'
  fi

  local repo=$(git_repo_name)
  [ -z "$repo" ] && return

  local c_repo="${color_repo}${repo}${reset}"
  local c_path=""
  local sub_path=$(git_sub_path)
  if [ -n "$sub_path" ]; then
    c_path="${color_path}${sub_path}${reset}"
  fi

  local c_branch=""
  local branch=$(git_branch)
  if [ -n "$branch" ]; then
    c_branch="${color_branch}${branch}${reset}"
  fi

  local c_behind="" c_ahead="" c_no_remote=""
  local remote_exists=$(git_remote_branch_exists)
  if [ -n "$remote_exists" ]; then
    local ba=$(git_behind_ahead)
    local behind=$(git_behind "$ba")
    if [ -n "$behind" ]; then
      c_behind="${color_behind}↓${behind}${reset}"
    fi
    local ahead=$(git_ahead "$ba")
    if [ -n "$ahead" ]; then
      c_ahead="${color_ahead}↑${ahead}${reset}"
    fi
  else
    c_no_remote="${color_no_remote}×${reset}"
  fi

  local c_staged=""
  local staged=$(git_staged_changes)
  if [ -n "$staged" ]; then
    c_staged="${color_staged}+${reset}"
  fi

  local c_unstaged=""
  local unstaged=$(git_unstaged_changes)
  if [ -n "$unstaged" ]; then
    c_unstaged="${color_unstaged}*${reset}"
  fi

  # Substitute placeholders using sentinels to track empty vs non-empty
  local empty=$'\x01'
  local filled=$'\x02'
  _sub() { if [ -n "$1" ]; then echo "${filled}${1}"; else echo "$empty"; fi; }
  local output="$format"
  output="${output//'<repo>'/$(_sub "$c_repo")}"
  output="${output//'<path>'/$(_sub "$c_path")}"
  output="${output//'<branch>'/$(_sub "$c_branch")}"
  output="${output//'<behind>'/$(_sub "$c_behind")}"
  output="${output//'<ahead>'/$(_sub "$c_ahead")}"
  output="${output//'<no_remote>'/$(_sub "$c_no_remote")}"
  output="${output//'<staged>'/$(_sub "$c_staged")}"
  output="${output//'<unstaged>'/$(_sub "$c_unstaged")}"

  # Process groups: remove {…} blocks that contain no filled placeholder
  local result=""
  local rest="$output"
  while [[ "$rest" == *"{"* ]]; do
    result+="${rest%%\{*}"
    rest="${rest#*\{}"
    local group="${rest%%\}*}"
    rest="${rest#*\}}"
    # Keep the group only if at least one placeholder was non-empty
    if [[ "$group" == *"$filled"* ]]; then
      result+="$group"
    fi
  done
  result+="$rest"

  # Remove sentinels
  result="${result//$empty/}"
  result="${result//$filled/}"

  echo -e "$result"
}

