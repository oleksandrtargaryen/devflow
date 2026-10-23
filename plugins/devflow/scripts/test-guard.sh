#!/usr/bin/env bash
# Runs guard-git.sh against a throwaway repo. Exit status is the number of failures.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
export DEVFLOW_TASKS_DIR="$tmp/tasks"

repo="$tmp/repo"
git init -q -b dev "$repo"
git -C "$repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
git -C "$repo" branch feat/x
git -C "$repo" branch release-2   # becomes the task's base below

fails=0
check() {  # check <expected allow|ask|deny> <branch> <command>
  git -C "$repo" checkout -q "$2"
  local got
  got=$(jq -n --arg c "$3" --arg d "$repo" '{tool_input:{command:$c},cwd:$d}' \
        | "$here/guard-git.sh" | jq -r '.hookSpecificOutput.permissionDecision // empty')
  got=${got:-allow}  # no output at all is how the hook says "allow"
  if [ "$got" = "$1" ]; then echo "ok    $1  [$2] $3"; else echo "FAIL  want $1 got $got  [$2] $3"; fails=$((fails+1)); fi
}

check deny  feat/x "git push origin dev"
check deny  feat/x "git push origin feat/x:main"
check deny  feat/x "git push -f origin feat/x"
check deny  feat/x "git push --force origin feat/x"
check deny  feat/x "git push origin +feat/x"
check deny  feat/x "git push --all"
check deny  dev    "git push"
check deny  dev    "git push origin HEAD"
check deny  dev    "git commit -m wip"
check deny  feat/x "cd /tmp && git -C $repo push origin master"
check allow feat/x "git push -u origin feat/x"
check allow feat/x "git push --force-with-lease origin feat/x"
check allow feat/x "git push"
check allow feat/x "git commit -m 'fix: a; b'"
check allow feat/x "git status && git log --oneline -5"
check allow dev    "git switch -c feat/y"
check allow feat/x "echo hello"
check deny  feat/x "git commit -m \"\$(cat <<'X'
feat: a

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
X
)\""
check deny  feat/x "git commit -m 'feat: a' -m '🤖 Generated with [Claude Code](https://claude.com/claude-code)'"
check allow feat/x "git commit -m 'feat: a' -m 'Co-Authored-By: Ivan <ivan@example.com>'"
check ask   feat/x "git reset --hard HEAD~1"
check ask   feat/x "git clean -fd"
check ask   feat/x "git checkout -- ."
check ask   feat/x "git branch -D feat/y"
check ask   feat/x "git rebase origin/dev"
check ask   feat/x "git push origin --delete feat/old"

# Paid cloud compute asks; reading job status does not.
check ask   feat/x "hf jobs uv run --flavor a10g-small --timeout 2h train.py"
check ask   feat/x "HF_TOKEN=x hf jobs run pytorch/pytorch python train.py"
check ask   feat/x "cd /tmp && sky launch -c gpu task.yaml"
check ask   feat/x "modal run train.py"
check ask   feat/x "aws sagemaker create-training-job --training-job-name t"
check allow feat/x "hf jobs ps"
check allow feat/x "hf jobs logs abc123"
check allow feat/x "echo 'hf jobs run is billed per minute'"
check allow feat/x "python train.py --max-steps 10"

# The task's own base is protected too, even when it is not main/master/dev.
mkdir -p "$DEVFLOW_TASKS_DIR/repo/feat/x"
printf 'stage: implement\nbase: release-2\n' > "$DEVFLOW_TASKS_DIR/repo/feat/x/state.md"
check deny  feat/x "git push origin release-2"

echo "failures: $fails"
exit $fails
