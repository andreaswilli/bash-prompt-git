#!/bin/bash

# Tests for the prompt template engine.
# Verifies expected output and that bash prompt.sh and JS engine.js
# produce identical plain-text results.

set -uo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SOURCE_DIR/prompt.sh"

passed=0
failed=0

strip_colors() {
  sed 's/\\\[\x1b\[[0-9;]*m\\\]//g' <<< "$1"
}

bash_render() {
  export GIT_PROMPT_FORMAT="$1"
  strip_colors "$(git_prompt)"
}

# -- Mock setters --

set_mock_clean() {
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

set_mock_all_active() {
  git_repo_name()            { echo "myrepo"; }
  git_sub_path()             { echo "/src"; }
  git_branch()               { echo "main"; }
  git_remote_branch_exists() { echo "1"; }
  git_behind_ahead()         { echo "3 2"; }
  git_behind()               { echo "3"; }
  git_ahead()                { echo "2"; }
  git_staged_changes()       { echo "A new.txt"; }
  git_unstaged_changes()     { echo "M old.txt"; }
}

set_mock_no_remote() {
  git_repo_name()            { echo "myrepo"; }
  git_sub_path()             { echo ""; }
  git_branch()               { echo "feature-x"; }
  git_remote_branch_exists() { echo ""; }
  git_behind_ahead()         { echo ""; }
  git_behind()               { echo ""; }
  git_ahead()                { echo ""; }
  git_staged_changes()       { echo "A new.txt"; }
  git_unstaged_changes()     { echo ""; }
}

set_mock_behind_only() {
  git_repo_name()            { echo "myrepo"; }
  git_sub_path()             { echo ""; }
  git_branch()               { echo "main"; }
  git_remote_branch_exists() { echo "1"; }
  git_behind_ahead()         { echo "5 0"; }
  git_behind()               { echo "5"; }
  git_ahead()                { echo ""; }
  git_staged_changes()       { echo ""; }
  git_unstaged_changes()     { echo ""; }
}

set_mock_empty_branch() {
  git_repo_name()            { echo "myrepo"; }
  git_sub_path()             { echo ""; }
  git_branch()               { echo ""; }
  git_remote_branch_exists() { echo "1"; }
  git_behind_ahead()         { echo "0 0"; }
  git_behind()               { echo ""; }
  git_ahead()                { echo ""; }
  git_staged_changes()       { echo ""; }
  git_unstaged_changes()     { echo ""; }
}

# -- Test data --

FORMATS=(
  '[<repo><path>] (<branch>{|<behind>}{|<ahead>}{|<no_remote>}{|<staged>}{|<unstaged>})'
  '<branch>{ <behind>}{ <ahead>}{ <staged>}{ <unstaged>}'
  '<repo> <branch>{:<behind>}{:<ahead>}{:<staged>}{:<unstaged>}'
  '<repo><path> on <branch>{ behind <behind>}{ ahead <ahead>}{<no_remote>}{ staged <staged>}{ dirty <unstaged>}'
  '[<branch>]{[<behind>]}{[<ahead>]}{[<no_remote>]}{[<staged>]}{[<unstaged>]} <repo><path>'
  '<repo>{|<branch>}{|<staged>}{|<unstaged>}'
  '<repo> :: {<branch>}{ <behind>}{ <ahead>}'
  '{<branch> }<asdf> <repo>'
)

FORMAT_NAMES=(Default Minimal Compact Verbose Bracket "Custom 1" "Custom 2" "Unknown placeholder")

MOCK_FUNCS=(set_mock_clean set_mock_all_active set_mock_no_remote set_mock_behind_only set_mock_empty_branch)
SCENARIO_NAMES=("clean" "all active" "no remote" "behind only" "empty branch")

SCENARIO_JSONS=(
  '{"repo":"myrepo","path":"","branch":"main","behind":"","ahead":"","no_remote":"","staged":"","unstaged":""}'
  '{"repo":"myrepo","path":"/src","branch":"main","behind":"↓3","ahead":"↑2","no_remote":"","staged":"+","unstaged":"*"}'
  '{"repo":"myrepo","path":"","branch":"feature-x","behind":"","ahead":"","no_remote":"×","staged":"+","unstaged":""}'
  '{"repo":"myrepo","path":"","branch":"main","behind":"↓5","ahead":"","no_remote":"","staged":"","unstaged":""}'
  '{"repo":"myrepo","path":"","branch":"","behind":"","ahead":"","no_remote":"","staged":"","unstaged":""}'
)

# -- Expected outputs --
# Key: "format_index:scenario_index"

declare -A EXPECTED

# Default
EXPECTED["0:0"]="[myrepo] (main)"
EXPECTED["0:1"]="[myrepo/src] (main|↓3|↑2|+|*)"
EXPECTED["0:2"]="[myrepo] (feature-x|×|+)"
EXPECTED["0:3"]="[myrepo] (main|↓5)"
EXPECTED["0:4"]="[myrepo] ()"

# Minimal
EXPECTED["1:0"]="main"
EXPECTED["1:1"]="main ↓3 ↑2 + *"
EXPECTED["1:2"]="feature-x +"
EXPECTED["1:3"]="main ↓5"
EXPECTED["1:4"]=""

# Compact
EXPECTED["2:0"]="myrepo main"
EXPECTED["2:1"]="myrepo main:↓3:↑2:+:*"
EXPECTED["2:2"]="myrepo feature-x:+"
EXPECTED["2:3"]="myrepo main:↓5"
EXPECTED["2:4"]="myrepo "

# Verbose
EXPECTED["3:0"]="myrepo on main"
EXPECTED["3:1"]="myrepo/src on main behind ↓3 ahead ↑2 staged + dirty *"
EXPECTED["3:2"]="myrepo on feature-x× staged +"
EXPECTED["3:3"]="myrepo on main behind ↓5"
EXPECTED["3:4"]="myrepo on "

# Bracket
EXPECTED["4:0"]="[main] myrepo"
EXPECTED["4:1"]="[main][↓3][↑2][+][*] myrepo/src"
EXPECTED["4:2"]="[feature-x][×][+] myrepo"
EXPECTED["4:3"]="[main][↓5] myrepo"
EXPECTED["4:4"]="[] myrepo"

# Custom 1
EXPECTED["5:0"]="myrepo|main"
EXPECTED["5:1"]="myrepo|main|+|*"
EXPECTED["5:2"]="myrepo|feature-x|+"
EXPECTED["5:3"]="myrepo|main"
EXPECTED["5:4"]="myrepo"

# Custom 2
EXPECTED["6:0"]="myrepo :: main"
EXPECTED["6:1"]="myrepo :: main ↓3 ↑2"
EXPECTED["6:2"]="myrepo :: feature-x"
EXPECTED["6:3"]="myrepo :: main ↓5"
EXPECTED["6:4"]="myrepo :: "

# Unknown placeholder
EXPECTED["7:0"]="main <asdf> myrepo"
EXPECTED["7:1"]="main <asdf> myrepo"
EXPECTED["7:2"]="feature-x <asdf> myrepo"
EXPECTED["7:3"]="main <asdf> myrepo"
EXPECTED["7:4"]="<asdf> myrepo"

# -- Generate all JS results in a single node call --

fmt_jsons=()
for fmt in "${FORMATS[@]}"; do
  fmt_jsons+=("$(printf '%s' "$fmt" | node -e 'let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>process.stdout.write(JSON.stringify(d)))')")
done

js_input="["
first=true
for fi in "${!FORMATS[@]}"; do
  for si in "${!SCENARIO_JSONS[@]}"; do
    $first && first=false || js_input+=","
    js_input+="{\"format\":${fmt_jsons[$fi]},\"scenario\":${SCENARIO_JSONS[$si]}}"
  done
done
js_input+="]"

readarray -t JS_OUTPUTS < <(echo "$js_input" | node -e '
const { renderTemplate } = require("./prompt-builder/engine.js");
const cases = JSON.parse(require("fs").readFileSync("/dev/stdin","utf8"));
cases.forEach(c => {
  const values = {};
  for (const p of ["repo","path","branch","behind","ahead","no_remote","staged","unstaged"]) {
    values[p] = { text: c.scenario[p] || "", wrap: null };
  }
  console.log(renderTemplate(c.format, values));
});
')

# -- Run tests --

echo "=== Prompt template tests ==="
echo ""

idx=0
for fi in "${!FORMATS[@]}"; do
  fname="${FORMAT_NAMES[$fi]}"
  for si in "${!MOCK_FUNCS[@]}"; do
    ${MOCK_FUNCS[$si]}
    sname="${SCENARIO_NAMES[$si]}"
    expected="${EXPECTED[$fi:$si]}"

    bash_out=$(bash_render "${FORMATS[$fi]}")
    js_out="${JS_OUTPUTS[$idx]}"

    if [ "$bash_out" = "$expected" ] && [ "$js_out" = "$expected" ]; then
      echo "  PASS: $fname + $sname"
      ((passed++))
    else
      echo "  FAIL: $fname + $sname"
      echo "    expected: '$expected'"
      [ "$bash_out" != "$expected" ] && echo "    bash:     '$bash_out'"
      [ "$js_out" != "$expected" ]   && echo "    js:       '$js_out'"
      ((failed++))
    fi
    ((idx++))
  done
done

unset GIT_PROMPT_FORMAT

echo ""
echo "Results: $passed passed, $failed failed"
exit $failed
