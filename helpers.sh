#!/bin/bash

git_repo_name() {
  local git_dir=$(git rev-parse --show-toplevel 2>/dev/null)
  if [ -n "$git_dir" ]; then
    echo $(basename "$git_dir")
  fi
}

git_sub_path() {
  local toplevel=$(git rev-parse --show-toplevel 2>/dev/null)
  if [ -n "$toplevel" ]; then
    local rel="${PWD#"$toplevel"}"
    if [ -n "$rel" ]; then
      echo "$rel"
    fi
  fi
}

git_branch() {
  echo $(git symbolic-ref --short HEAD 2>/dev/null)
}

git_status() {
  echo "$(git status --porcelain 2>/dev/null)"
}

git_unstaged_changes() {
  local status="${1:-$(git_status)}"
  echo "$status" | grep -E '^[ MARC][^ ]'
}

git_staged_changes() {
  local status="${1:-$(git_status)}"
  echo "$status" | grep -E '^[AMDR]'
}

git_remote_branch_exists() {
  local branch=$(git_branch)
  if [ -n "$branch" ]; then
    git rev-parse --verify origin/$branch &>/dev/null && echo "1"
  fi
}

git_behind_ahead() {
  local branch=$(git_branch)
  if [ -n "$branch" ]; then
    local counts=$(git rev-list --left-right --count origin/$branch...$branch 2>/dev/null)
    if [ -n "$counts" ]; then
      local behind=$(echo "$counts" | awk '{print $1}')
      local ahead=$(echo "$counts" | awk '{print $2}')
      echo "$behind $ahead"
    fi
  fi
}

git_behind() {
  local ba="${1:-$(git_behind_ahead)}"
  if [ -n "$ba" ]; then
    local count=$(echo "$ba" | awk '{print $1}')
    if [ -n "$count" ] && [ "$count" -gt 0 ] 2>/dev/null; then
      echo "$count"
    fi
  fi
}

git_ahead() {
  local ba="${1:-$(git_behind_ahead)}"
  if [ -n "$ba" ]; then
    local count=$(echo "$ba" | awk '{print $2}')
    if [ -n "$count" ] && [ "$count" -gt 0 ] 2>/dev/null; then
      echo "$count"
    fi
  fi
}
