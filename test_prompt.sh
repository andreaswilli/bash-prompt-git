#!/bin/bash

# Test the group/template logic from prompt.sh in isolation
# by mocking the git helper functions.

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source once; we override the helper functions via mocks
source "$SOURCE_DIR/prompt.sh"

passed=0
failed=0

# Strip PS1 color escapes from echo -e output for comparison.
# echo -e turns \[\033[0;34m\] into: \[ ESC[0;34m \]
strip_colors() {
  # Remove \[ ESC[...m \] sequences (PS1 wrappers around ANSI codes)
  sed 's/\\\[\x1b\[[0-9;]*m\\\]//g' <<< "$1"
}

run_test() {
  local description="$1"
  local expected="$2"

  local actual
  actual=$(git_prompt)
  local actual_stripped
  actual_stripped=$(strip_colors "$actual")

  if [ "$actual_stripped" = "$expected" ]; then
    echo "  PASS: $description"
    ((passed++))
  else
    echo "  FAIL: $description"
    echo "    expected: '$expected'"
    echo "    actual:   '$actual_stripped'"
    ((failed++))
  fi
}

# --- Mock helpers ---

mock_basic() {
  git_repo_name()            { echo "myrepo"; }
  git_sub_path()             { echo ""; }
  git_branch()               { echo "main"; }
  git_remote_branch_exists() { echo "1"; }
  git_behind_ahead()         { echo "0 0"; }
  git_behind()               { echo ""; }
  git_ahead()                { echo ""; }
  git_staged_changes()       { echo ""; }
  git_unstaged_changes()     { echo ""; }
}

# --- Tests ---

echo "=== Group template tests ==="

# Test 1: clean repo, synced, no changes
unset GIT_PROMPT_FORMAT
mock_basic
run_test "clean repo, no changes" "[myrepo] (main)"

# Test 2: with sub-path
unset GIT_PROMPT_FORMAT
mock_basic
git_sub_path() { echo "/src/lib"; }
run_test "with sub-path" "[myrepo/src/lib] (main)"

# Test 3: behind only
unset GIT_PROMPT_FORMAT
mock_basic
git_behind() { echo "3"; }
run_test "behind only" "[myrepo] (main|↓3)"

# Test 4: ahead only
unset GIT_PROMPT_FORMAT
mock_basic
git_ahead() { echo "2"; }
run_test "ahead only" "[myrepo] (main|↑2)"

# Test 5: behind + ahead
unset GIT_PROMPT_FORMAT
mock_basic
git_behind() { echo "3"; }
git_ahead()  { echo "2"; }
run_test "behind + ahead" "[myrepo] (main|↓3|↑2)"

# Test 6: no remote
unset GIT_PROMPT_FORMAT
mock_basic
git_remote_branch_exists() { echo ""; }
run_test "no remote" "[myrepo] (main|×)"

# Test 7: staged only
unset GIT_PROMPT_FORMAT
mock_basic
git_staged_changes() { echo "M file.txt"; }
run_test "staged only" "[myrepo] (main|+)"

# Test 8: unstaged only
unset GIT_PROMPT_FORMAT
mock_basic
git_unstaged_changes() { echo "M file.txt"; }
run_test "unstaged only" "[myrepo] (main|*)"

# Test 9: staged + unstaged
unset GIT_PROMPT_FORMAT
mock_basic
git_staged_changes()   { echo "M file.txt"; }
git_unstaged_changes() { echo "M other.txt"; }
run_test "staged + unstaged" "[myrepo] (main|+|*)"

# Test 10: everything active
unset GIT_PROMPT_FORMAT
mock_basic
git_sub_path()         { echo "/src"; }
git_behind()           { echo "1"; }
git_ahead()            { echo "4"; }
git_staged_changes()   { echo "A new.txt"; }
git_unstaged_changes() { echo "M old.txt"; }
run_test "everything active" "[myrepo/src] (main|↓1|↑4|+|*)"

# Test 11: no remote + staged + unstaged
unset GIT_PROMPT_FORMAT
mock_basic
git_remote_branch_exists() { echo ""; }
git_staged_changes()   { echo "M file.txt"; }
git_unstaged_changes() { echo "M other.txt"; }
run_test "no remote + staged + unstaged" "[myrepo] (main|×|+|*)"

# Test 12: custom format
export GIT_PROMPT_FORMAT="<repo> :: {<branch>}{ <behind>}{ <ahead>}"
mock_basic
git_behind() { echo "5"; }
run_test "custom format" "myrepo :: main ↓5"

# Test 13: custom format, all empty status
export GIT_PROMPT_FORMAT="<repo>{|<branch>}{|<staged>}{|<unstaged>}"
mock_basic
git_branch() { echo ""; }
run_test "custom format, empty branch + status" "myrepo"

unset GIT_PROMPT_FORMAT

# --- Summary ---
echo ""
echo "Results: $passed passed, $failed failed"
exit $failed
