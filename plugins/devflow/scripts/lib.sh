# Shared by every devflow script, so the repo key, the task folder and the
# protected branches are computed in exactly one place.

DEVFLOW_HOME="${DEVFLOW_HOME:-$HOME/.devflow}"
DEVFLOW_TASKS_DIR="${DEVFLOW_TASKS_DIR:-$DEVFLOW_HOME/tasks}"
DEVFLOW_CONTEXT_DIR="${DEVFLOW_CONTEXT_DIR:-$DEVFLOW_HOME/context}"
# Outside the plugin cache, which every update replaces, and outside
# CLAUDE_PLUGIN_DATA, which uninstall deletes: the ledger is accumulated evidence.
DEVFLOW_LEARNING_DIR="${DEVFLOW_LEARNING_DIR:-$DEVFLOW_HOME/learning}"

# Prints "host<TAB>owner/repo" for the origin remote, or nothing.
# Handles ssh://git@host:port/owner/repo.git, git@host:owner/repo.git, https://host/owner/repo.git.
remote_parts() {
  local url
  url=$(git -C "$1" remote get-url origin 2>/dev/null) || return 0
  url="${url%.git}"
  case "$url" in
    ssh://*)   url="${url#ssh://}"; url="${url#*@}"; printf '%s\t%s\n' "${url%%[:/]*}" "${url#*/}" ;;
    http*://*) url="${url#*://}"; url="${url#*@}"; printf '%s\t%s\n' "${url%%/*}" "${url#*/}" ;;
    *@*:*)     url="${url#*@}"; printf '%s\t%s\n' "${url%%:*}" "${url#*:}" ;;
  esac
}

# The folder name used for this repo under tasks/ and context/: the remote's
# repo name, so two clones of one repo share their ADRs.
repo_key() {
  local parts
  parts=$(remote_parts "$1")
  if [ -n "$parts" ]; then basename "${parts#*$'\t'}"; else basename "$(git -C "$1" rev-parse --show-toplevel)"; fi
}

current_branch() { git -C "$1" symbolic-ref --quiet --short HEAD 2>/dev/null; }

# dev wins over the default branch: the team integrates on dev where it exists.
base_branch() {
  if [ -n "${DEVFLOW_BASE:-}" ]; then echo "$DEVFLOW_BASE"; return; fi
  if git -C "$1" rev-parse --verify --quiet refs/remotes/origin/dev >/dev/null; then echo dev; return; fi
  local head
  head=$(git -C "$1" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)
  echo "${head#origin/}"
}

task_dir() { echo "$DEVFLOW_TASKS_DIR/$(repo_key "$1")/$2"; }
context_dir() { echo "$DEVFLOW_CONTEXT_DIR/$(repo_key "$1")"; }

# ADRs follow the team: where the repo already keeps docs/adr/ (in the working
# tree or on origin/<base>, so an old branch without it still counts), they go
# there and ship with the PR. Otherwise they stay private in context_dir.
adr_in_repo() {
  local base
  [ -d "$1/docs/adr" ] && return 0
  base=$(base_branch "$1")
  [ -n "$base" ] && git -C "$1" cat-file -e "origin/$base:docs/adr" 2>/dev/null
}
adr_dir() { if adr_in_repo "$1"; then echo "$1/docs/adr"; else echo "$(context_dir "$1")/adr"; fi; }

# A field from the "key: value" header of state.md.
state_field() { [ -f "$1" ] && sed -n "s/^$2:[[:space:]]*//p" "$1" | head -n1; }

protected_branches() {
  local list="main master dev ${DEVFLOW_PROTECTED:-}" branch base
  branch=$(current_branch "$1")
  if [ -n "$branch" ]; then
    base=$(state_field "$(task_dir "$1" "$branch")/state.md" base)
    [ -n "$base" ] && list="$list $base"
  fi
  echo "$list"
}
