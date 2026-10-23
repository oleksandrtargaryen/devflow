#!/usr/bin/env bash
# Everything a devflow stage needs to know about the repo, as one JSON object,
# so skills never re-derive the base branch, the forge URLs or the task folder by hand.
# Usage: repo-info.sh [dir] [branch]   (branch defaults to the current one)
set -euo pipefail
. "$(dirname "$0")/lib.sh"

dir="${1:-$PWD}"
if ! top=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null); then
  echo "ERROR: $dir is not inside a git repository" >&2; exit 1
fi

branch="${2:-$(current_branch "$top" || true)}"
base=$(base_branch "$top")
parts=$(remote_parts "$top")
host="${parts%%$'\t'*}"; slug="${parts#*$'\t'}"
web=""; compare=""
if [ -n "$parts" ]; then
  web="https://$host/$slug"
  [ -n "$branch" ] && [ "$branch" != "$base" ] && compare="$web/compare/$base...$branch"
fi
# The forge decides how PR comments and CI runs are read (scripts/forge-api.sh).
# GitHub by host; Gitea when GITEA_URL points at this remote's host. Anything
# else is "unknown": the stages then say CI and PR comments were not checked.
forge=unknown; api=""
if [ -n "$parts" ]; then
  if [ "$host" = github.com ]; then forge=github; api="https://api.github.com/repos/$slug"
  elif [ -n "${GITEA_URL:-}" ]; then
    ghost="${GITEA_URL#*://}"; ghost="${ghost%%/*}"; ghost="${ghost%%:*}"
    [ "$ghost" = "$host" ] && { forge=gitea; api="${GITEA_URL%/}/api/v1/repos/$slug"; }
  fi
fi
ci=""; [ -n "$api" ] && ci="$api/actions/runs"
clean=true; [ -n "$(git -C "$top" status --porcelain)" ] && clean=false
tdir=""; [ -n "$branch" ] && tdir=$(task_dir "$top" "$branch")
cdir=$(context_dir "$top")
task_exists=false; [ -n "$tdir" ] && [ -f "$tdir/state.md" ] && task_exists=true
context_exists=false; [ -d "$cdir" ] && context_exists=true
adir=$(adr_dir "$top")
adr_in_repo=false; adr_in_repo "$top" && adr_in_repo=true

# A task whose branch is not created yet (start done, design not run), or an
# open investigation (which never gets a branch), is found by its state.md,
# so /devflow:next works from the base branch. Archived tasks never count.
rdir="$DEVFLOW_TASKS_DIR/$(repo_key "$top")"
pending=""
if [ "$task_exists" = false ] && [ -d "$rdir" ]; then
  f=""; newest=0
  while IFS= read -r st; do
    case "$st" in */_done/*) continue ;; esac
    stage=$(state_field "$st" stage)
    if [ "$stage" = start ] || { [ "$(state_field "$st" type)" = investigation ] && [ "$stage" != done ]; }; then
      m=$(stat -f %m "$st" 2>/dev/null || stat -c %Y "$st")
      [ "$m" -gt "$newest" ] && { newest=$m; f=$st; }
    fi
  done < <(find "$rdir" -name state.md 2>/dev/null)
  [ -n "$f" ] && pending=$(state_field "$f" branch)
fi

jq -n \
  --arg toplevel "$top" --arg repo "$(repo_key "$top")" --arg slug "$slug" \
  --arg web_url "$web" --arg branch "$branch" --arg base "$base" \
  --arg compare_url "$compare" --argjson clean "$clean" \
  --arg task_dir "$tdir" --argjson task_exists "$task_exists" \
  --arg context_dir "$cdir" --argjson context_exists "$context_exists" \
  --arg adr_dir "$adir" --argjson adr_in_repo "$adr_in_repo" \
  --arg repo_tasks_dir "$rdir" --arg pending_branch "$pending" \
  --arg ci_url "$ci" --arg learning_dir "$DEVFLOW_LEARNING_DIR" \
  --arg forge "$forge" --arg api_url "$api" \
  '{toplevel:$toplevel, repo:$repo, slug:$slug, web_url:$web_url, branch:$branch,
    base:$base, compare_url:$compare_url, clean:$clean,
    task_dir:$task_dir, task_exists:$task_exists,
    context_dir:$context_dir, context_exists:$context_exists,
    adr_dir:$adr_dir, adr_in_repo:$adr_in_repo,
    repo_tasks_dir:$repo_tasks_dir, pending_branch:$pending_branch,
    forge:$forge, api_url:$api_url, ci_url:$ci_url, learning_dir:$learning_dir}'
