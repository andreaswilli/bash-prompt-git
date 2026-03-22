# bash-prompt-git

A lightweight, customizable git prompt for Bash. Shows repository info, branch,
sync status, and working tree state directly in your `PS1`.

### Default output

```
[my-repo/src] (main|↓3|↑1|+|*)
 ^^^^^^^^^^^   ^^^^ ^^ ^^ ^ ^
 repo + path     │   │  │ │ └─ unstaged changes
                 │   │  │ └─── staged changes
                 │   │  └───── ahead of remote
                 │   └──────── behind remote
                 └──────────── branch
```

When there is no remote tracking branch, `×` is shown instead of behind/ahead.

## Installation

Source `prompt.sh` in your `~/.bashrc` and use `PROMPT_COMMAND` to set `PS1`:

```bash
source /path/to/bash-prompt-git/prompt.sh
PROMPT_COMMAND=set_prompt

set_prompt() {
  prompt=$(git_prompt)
  # print working directory only outside of git repos
  PS1="${prompt:-\w} \$ "
}
```

> **Why `PROMPT_COMMAND`?** If you assign `PS1` directly (e.g.
`PS1="$(git_prompt) \$ "`), the prompt is evaluated once at assignment time and
never updates when you change directories. `PROMPT_COMMAND` re-evaluates before
every prompt, so it always reflects the current repository and status.

## Configuration

All configuration is done through environment variables. Set them **before**
sourcing `prompt.sh` or anywhere in your `~/.bashrc` before the prompt is
evaluated.

> **Tip:** Use the [Prompt Builder](https://andreaswilli.github.io/bash-prompt-git/) to interactively
> pick a format and colors with a live preview, then copy the generated config.

### Colors

Override any color with standard Bash PS1 escape sequences:

| Variable                         | Default  | Description            |
|----------------------------------|----------|------------------------|
| `GIT_PROMPT_COLOR_REPO`          | Blue     | Repository name        |
| `GIT_PROMPT_COLOR_PATH`          | Reset    | Sub-path within repo   |
| `GIT_PROMPT_COLOR_BRANCH`        | Blue     | Branch name            |
| `GIT_PROMPT_COLOR_BEHIND`        | Yellow   | Behind remote counter  |
| `GIT_PROMPT_COLOR_AHEAD`         | Yellow   | Ahead of remote counter|
| `GIT_PROMPT_COLOR_NO_REMOTE`     | Yellow   | No-remote indicator    |
| `GIT_PROMPT_COLOR_STAGED`        | Green    | Staged indicator       |
| `GIT_PROMPT_COLOR_UNSTAGED`      | Red      | Unstaged indicator     |

Colors must use PS1-safe escapes (`\[...\]` wrappers) to avoid line-wrapping
issues:

```bash
export GIT_PROMPT_COLOR_REPO='\[\033[1;36m\]'   # bold cyan
export GIT_PROMPT_COLOR_BRANCH='\[\033[0;35m\]'  # magenta
```

### Format template

Override the layout with `GIT_PROMPT_FORMAT`. The template supports placeholders
and conditional groups.

#### Placeholders

| Placeholder    | Description                                          |
|----------------|------------------------------------------------------|
| `<repo>`       | Repository name                                      |
| `<path>`       | Sub-path within the repo (empty at repo root)        |
| `<branch>`     | Current branch name (empty in detached HEAD)         |
| `<behind>`     | Behind remote indicator, e.g. `↓3` (empty if 0)      |
| `<ahead>`      | Ahead of remote indicator, e.g. `↑2` (empty if 0)    |
| `<no_remote>`  | `×` when no remote tracking branch (empty otherwise) |
| `<staged>`     | `+` when staged changes exist (empty otherwise)      |
| `<unstaged>`   | `*` when unstaged changes exist (empty otherwise)    |

#### Conditional groups

Wrap any text in `{ }` to make it conditional. A group is **removed entirely**
when **all** placeholders inside it resolved to empty. This prevents leftover
separators.

```
{|<behind>}   →  "|↓3"  when behind remote
              →  ""     when not behind (group removed)
```

> **Note:** Nested groups are not supported. Braces cannot be nested.

#### Default template

```
[<repo><path>] (<branch>{|<behind>}{|<ahead>}{|<no_remote>}{|<staged>}{|<unstaged>})
```

### Examples

Minimal — branch only:

```bash
export GIT_PROMPT_FORMAT='<branch>'
# main
```

Compact — no brackets:

```bash
export GIT_PROMPT_FORMAT='<repo> <branch>{:<behind>}{:<ahead>}{:<staged>}{:<unstaged>}'
# myrepo main:↓3:+:*
```

## Testing

```bash
bash test_prompt.sh
```

The test script mocks all git helper functions and verifies the template engine
output across various scenarios.
