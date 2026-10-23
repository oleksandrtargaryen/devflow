#!/usr/bin/env bash
# Forge detection in repo-info.sh. Exit status is the number of failures.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
export DEVFLOW_HOME="$tmp/home"
repo="$tmp/repo"; git init -q -b dev "$repo"
fails=0
is() { if [ "$1" = "$2" ]; then echo "ok    $3"; else echo "FAIL  $3: want '$1' got '$2'"; fails=$((fails+1)); fi; }
info() { "$here/repo-info.sh" "$repo" | jq -r "$1"; }

git -C "$repo" remote add origin git@github.com:someone/thing.git
is github "$(env -u GITEA_URL "$here/repo-info.sh" "$repo" | jq -r .forge)" "github by host"
is https://api.github.com/repos/someone/thing/actions/runs "$(env -u GITEA_URL "$here/repo-info.sh" "$repo" | jq -r .ci_url)" "github ci_url"

git -C "$repo" remote set-url origin ssh://git@git.example.org:2222/team/app.git
is unknown "$(env -u GITEA_URL "$here/repo-info.sh" "$repo" | jq -r .forge)" "self-hosted without GITEA_URL is unknown"
is "" "$(env -u GITEA_URL "$here/repo-info.sh" "$repo" | jq -r .ci_url)" "no ci_url when unknown"
is gitea "$(GITEA_URL=https://git.example.org "$here/repo-info.sh" "$repo" | jq -r .forge)" "gitea when GITEA_URL host matches"
is https://git.example.org/api/v1/repos/team/app/actions/runs "$(GITEA_URL=https://git.example.org/ "$here/repo-info.sh" "$repo" | jq -r .ci_url)" "gitea ci_url, trailing slash"
is unknown "$(GITEA_URL=https://other.example.org "$here/repo-info.sh" "$repo" | jq -r .forge)" "GITEA_URL for another host does not match"
is "$tmp/home/learning" "$(info .learning_dir)" "learning dir under DEVFLOW_HOME"
is "$tmp/home/tasks/app/dev" "$(info .task_dir)" "task dir keyed by repo name and branch"

(cd "$repo" && env -u GITEA_URL "$here/forge-api.sh" pulls >/dev/null 2>&1); is 3 $? "forge-api refuses an unknown forge"

echo "failures: $fails"
exit $fails
