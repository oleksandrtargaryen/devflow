#!/usr/bin/env bash
# Exercises ledger.sh in a throwaway learning dir. Exit status is the number of failures.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
export DEVFLOW_LEARNING_DIR="$tmp/learning"
L="$here/ledger.sh"
fails=0
is() {  # is <want> <got> <label>
  if [ "$1" = "$2" ]; then echo "ok    $3"; else echo "FAIL  $3: want '$1' got '$2'"; fails=$((fails+1)); fi
}

is added  "$($L add --repo r --task a --source review --ref S1 --missed-by plan --class race-check-then-act --date 2026-10-01)" "add"
is exists "$($L add --repo r --task a --source review --ref S1 --missed-by plan --class race-check-then-act)" "same (repo, task, source, ref) is a no-op"
is 1 "$(wc -l < "$DEVFLOW_LEARNING_DIR/ledger.jsonl" | tr -d ' ')" "one line after the duplicate"

$L add --repo r --task a --source review --ref S2 --missed-by plan --class race-check-then-act --date 2026-10-01 >/dev/null
is '[]' "$($L stats | jq -c .)" "two entries from ONE task are not a recurring class"

$L add --repo r --task b --source feedback --ref R1 --missed-by review --class race-check-then-act --date 2026-10-05 >/dev/null
is race-check-then-act "$($L stats | jq -r '.[0].class')" "second task makes it recur"
is 2 "$($L stats | jq -r '.[0].tasks')" "distinct tasks counted"
is null "$($L stats | jq -r '.[0].repeats_after_rule')" "no rule yet"

$L rule --class race-check-then-act --where "skills/plan/SKILL.md" --rung 1 --date 2026-10-03 >/dev/null
is 1 "$($L stats | jq -r '.[0].repeats_after_rule')" "an entry after the rule's date is a repeat"
is 1 "$($L stats | jq -r '.[0].rule.rung')" "rule rung reported"

$L add --repo r --task c --source review --ref S1 --missed-by design --class lonely >/dev/null
is 1 "$($L stats | jq 'length')" "min 2 hides single-task classes"
is 2 "$($L stats --min 1 | jq 'length')" "--min 1 shows them"
is 3 "$($L list --class race-check-then-act | wc -l | tr -d ' ')" "list filters by class"

is added "$($L add --repo r --task d --source prod --ref sentry:123 --missed-by verify --class lonely)" "prod source accepted"
$L add --repo r --task a --source nope --ref X --missed-by plan --class a 2>/dev/null; is 2 $? "bad source rejected"
$L add --repo r --task a --source review --ref X --missed-by nowhere --class a 2>/dev/null; is 2 $? "bad stage rejected"
$L add --repo r --task a --source review --ref X --missed-by plan --class Bad_Slug 2>/dev/null; is 2 $? "non-kebab class rejected"
$L add --repo r --task a --source review --ref X --missed-by plan 2>/dev/null; is 2 $? "missing --class rejected"
$L rule --class a --where x --rung 7 2>/dev/null; is 2 $? "rung outside 1-4 rejected"

echo "failures: $fails"
exit $fails
