#!/usr/bin/env bash
# SessionStart: after /clear or in a new window the model learns where the
# repo's ADRs live and which devflow stage the current branch is at, without
# anyone re-explaining it. Silent where there is neither.
set -uo pipefail
. "$(dirname "$0")/lib.sh"

input=$(cat)
dir=$(jq -r '.cwd // empty' <<<"$input"); [ -n "$dir" ] || dir=$PWD
top=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || exit 0

cdir=$(context_dir "$top")
branch=$(current_branch "$top")
state=""; [ -n "$branch" ] && state="$(task_dir "$top" "$branch")/state.md"

ctx=""
if adr_in_repo "$top"; then
  base=$(base_branch "$top")
  adrs=$(git -C "$top" ls-tree --name-only "origin/$base" docs/adr/ 2>/dev/null | grep -E '/[0-9]{4}-[^/]*\.md$' | sed 's/^/  - /')
  ctx+="devflow: this repo's ADRs live IN THE REPO, in $top/docs/adr/, as the team keeps them.
- Write new ADRs there, never into $cdir/adr/. Number = the highest number in docs/adr/ on origin/$base, plus one (fetch first: teammates add ADRs too).
- Follow docs/adr/README.md: its template, language and statuses; add the new row to its table. An ADR is committed on the task branch as its own docs(adr): commit and ships with the PR.
- GLOSSARY: $cdir/GLOSSARY.md (outside the repo; the team keeps none).
Read the ADRs that touch the area you are about to change before changing it.
${adrs:+Existing ADRs (origin/$base):
$adrs
}"
  old=$(cd "$cdir" 2>/dev/null && ls adr/*.md 2>/dev/null | sed 's/^/  - /')
  [ -n "$old" ] && ctx+="Older private notes in $cdir/adr/ (not team ADRs, separate numbering; read-only, add nothing there):
$old
"
elif [ -d "$cdir" ]; then
  adrs=$(cd "$cdir" && ls adr/*.md 2>/dev/null | sed 's/^/  - /')
  ctx+="devflow: this repo's domain docs live OUTSIDE the repo, in $cdir/
- GLOSSARY: $cdir/GLOSSARY.md
- ADRs: $cdir/adr/ (sequential 0001-slug.md)
Wherever a skill says GLOSSARY.md or docs/adr/ at the repo root, use these paths instead, for reading and for writing. Never create docs/adr/ or GLOSSARY.md inside the repo.
Read the ADRs that touch the area you are about to change before changing it.
${adrs:+Existing ADRs:
$adrs
}"
fi

if [ -n "$state" ] && [ -f "$state" ]; then
  ctx+="
devflow: branch '$branch' is an active task. Task folder: $(dirname "$state")/
--- state.md (head) ---
$(head -n 40 "$state")
---
Continue only when the user asks (/devflow:next); do not start the next stage on your own."
fi

[ -z "$ctx" ] && exit 0
jq -n --arg c "$ctx" '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$c}}'
