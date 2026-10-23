#!/usr/bin/env bash
# PreToolUse guard for Bash. A rule the model only "remembers" fails silently
# once in a while; a hook does not. Pushing a feature branch stays allowed:
# only what can damage shared branches or lose work is stopped.
#   deny: push to a protected branch, force push, --all/--mirror, commit on a protected branch,
#         AI attribution lines in a commit or tag message
#   ask:  reset --hard, clean -f, checkout/restore of the whole tree, branch -D, rebase, push --delete,
#         and launching paid cloud compute (training jobs cost money from the first minute)
set -uo pipefail
. "$(dirname "$0")/lib.sh"

input=$(cat)
cmd=$(jq -r '.tool_input.command // empty' <<<"$input")
dir=$(jq -r '.cwd // empty' <<<"$input")
[ -z "$cmd" ] && exit 0

# Paid compute is billed from the moment a job starts, and a forgotten run keeps
# billing: every launch is the user's decision, with the cost in front of them.
compute=$(printf '%s\n' "$cmd" | awk '{gsub(/&&|\|\||;|\|/, "\n"); print}' | sed 's/^[[:space:]]*//' \
  | grep -E '^([A-Za-z_][A-Za-z0-9_]*=[^ ]* )*(hf jobs (run|uv run|scheduled run)|sky (launch|jobs launch|serve up)|modal (run|deploy)|runpodctl create|gcloud ai custom-jobs create|aws sagemaker create-training-job|az ml job create)( |$)' | head -n1)
if [ -n "$compute" ]; then
  jq -n --arg r "devflow guard: this launches paid cloud compute ($compute). Confirm the hardware, the timeout and the expected cost first." \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$r}}'
  exit 0
fi

case "$cmd" in *git*) ;; *) exit 0 ;; esac
[ -n "$dir" ] || dir=$PWD

# The user wants no AI attribution in history. Checked on the whole command,
# because the message usually arrives in a heredoc on later lines.
if grep -qE '(^|[^a-z])git( -C [^ ]+)? (commit|tag)' <<<"$cmd" \
   && grep -qiE 'co-authored-by:.*(claude|anthropic)|generated with .*claude' <<<"$cmd"; then
  jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",
    permissionDecisionReason:"devflow guard: remove the Co-Authored-By / Generated with Claude Code lines; the user wants no AI attribution in commits"}}'
  exit 0
fi

decide() {
  jq -n --arg d "$1" --arg r "devflow guard: $2" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:$d,permissionDecisionReason:$r}}'
  exit 0
}

is_protected() {
  local b
  for b in $protected; do [ "$1" = "$b" ] && return 0; done
  return 1
}

# Split compound commands so "cd x && git push" is seen segment by segment;
# a leading "cd <dir>" moves where the branch is read from.
segments=$(printf '%s\n' "$cmd" | awk '{gsub(/&&|\|\||;|\|/, "\n"); print}')
ask_reason=""

while IFS= read -r seg; do
  read -ra t <<<"$seg"
  [ ${#t[@]} -eq 0 ] && continue
  if [ "${t[0]}" = cd ] && [ ${#t[@]} -ge 2 ]; then
    target="${t[1]/#\~/$HOME}"
    case "$target" in /*) dir="$target" ;; *) dir="$dir/$target" ;; esac
    continue
  fi

  # Find "git", skipping env assignments; honour "git -C <dir>".
  i=0; while [ $i -lt ${#t[@]} ] && [[ "${t[$i]}" == *=* ]]; do i=$((i+1)); done
  [ "${t[$i]:-}" = git ] || continue
  i=$((i+1)); gdir="$dir"
  while [ $i -lt ${#t[@]} ] && [[ "${t[$i]}" == -* ]]; do
    if [ "${t[$i]}" = -C ]; then gdir="${t[$((i+1))]/#\~/$HOME}"; i=$((i+2)); else i=$((i+1)); fi
  done
  sub="${t[$i]:-}"; args=("${t[@]:$((i+1))}" "")  # trailing "" keeps bash 3.2 happy under set -u
  protected=$(protected_branches "$gdir")
  branch=$(current_branch "$gdir")

  case "$sub" in
    push)
      positional=()
      for a in "${args[@]}"; do [ -z "$a" ] && continue
        case "$a" in
          --force|-f|--force-if-includes) decide deny "force push is blocked; use --force-with-lease on your own branch" ;;
          -[a-zA-Z]*f*) [[ "$a" != --* ]] && decide deny "force push is blocked; use --force-with-lease on your own branch" ;;
          --all|--mirror) decide deny "push --all/--mirror would touch protected branches" ;;
          --delete|-d) ask_reason="deleting a remote branch" ;;
          -*) ;;
          *) positional+=("$a") ;;
        esac
      done
      refs=(); [ ${#positional[@]} -gt 1 ] && refs=("${positional[@]:1}")
      [ ${#refs[@]} -eq 0 ] && refs=("$branch")
      for r in "${refs[@]}"; do
        [[ "$r" == +* ]] && decide deny "force refspec $r is blocked"
        dst="${r##*:}"; dst="${dst#refs/heads/}"
        [ "$dst" = HEAD ] && dst="$branch"
        is_protected "$dst" && decide deny "push to protected branch '$dst' is blocked; push a feature branch and open a PR"
      done
      ;;
    commit)
      is_protected "$branch" && decide deny "committing on protected branch '$branch' is blocked; create a feature branch first"
      ;;
    reset)   [[ " ${args[*]} " == *" --hard "* ]] && ask_reason="git reset --hard discards uncommitted work" ;;
    clean)   [[ " ${args[*]} " =~ \ -[a-zA-Z]*f ]] && ask_reason="git clean -f deletes untracked files" ;;
    checkout|restore)
      [[ " ${args[*]} " == *" . "* ]] && ask_reason="git $sub . discards changes in the whole tree" ;;
    branch)  [[ " ${args[*]} " =~ \ -[a-zA-Z]*D ]] && ask_reason="git branch -D deletes a branch even if unmerged" ;;
    rebase)  ask_reason="git rebase rewrites history" ;;
  esac
done <<<"$segments"

[ -n "$ask_reason" ] && decide ask "$ask_reason"
exit 0
