#!/usr/bin/env bash
# Read-only GET against the repo's forge API, so retro and done read PRs and
# CI the same way on GitHub and Gitea. The two APIs share the paths devflow
# uses (pulls, pulls/<n>/reviews, issues/<n>/comments, actions/runs[?head_sha=],
# actions/runs/<id>/jobs) and the fields it reads.
#
# Usage: forge-api.sh <path relative to the repo, e.g. "pulls?state=all"> [dir]
# Auth: GitHub through the gh CLI; Gitea through GITEA_TOKEN. Never prints a token.
# Exit: 0 with JSON on stdout; 3 when the forge is unknown or not authenticated.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
path="${1:?usage: forge-api.sh <path> [dir]}"
info=$("$here/repo-info.sh" "${2:-$PWD}") || exit 2
forge=$(jq -r .forge <<<"$info"); api=$(jq -r .api_url <<<"$info")
sep='?'; case "$path" in *\?*) sep='&' ;; esac
case "$forge" in
  github)
    command -v gh >/dev/null || { echo "ERROR: GitHub needs the gh CLI (gh auth login)" >&2; exit 3; }
    slug=$(jq -r .slug <<<"$info")
    gh api "repos/$slug/$path${sep}per_page=100" ;;
  gitea)
    [ -n "${GITEA_TOKEN:-}" ] || { echo "ERROR: Gitea needs GITEA_TOKEN in the environment" >&2; exit 3; }
    curl -sf -H "Authorization: token $GITEA_TOKEN" "$api/$path${sep}limit=50" ;;
  *)
    echo "ERROR: unknown forge for this remote (GitHub by host; Gitea needs GITEA_URL)" >&2; exit 3 ;;
esac
