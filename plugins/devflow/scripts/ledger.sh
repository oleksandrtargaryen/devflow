#!/usr/bin/env bash
# The ledger of devflow's own misses: every finding a stage should have caught
# but a later one (or a person) did. Stages write through this script so every
# entry has the same shape; /devflow:learn reads `stats` to decide which class
# of miss has recurred enough to earn a rule.
#
# Usage:
#   ledger.sh add --repo R --task T --source S --ref ID --missed-by STAGE --class SLUG
#                 [--evidence TEXT] [--note TEXT] [--date YYYY-MM-DD]
#   ledger.sh list [--class SLUG]
#   ledger.sh stats [--min N]            classes seen in at least N distinct tasks (default 2)
#   ledger.sh rule --class SLUG --where TEXT --rung N [--date YYYY-MM-DD]
#
# One entry per (repo, task, source, ref): adding it again is a no-op, so a
# backfill can be rerun safely.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

dir="$DEVFLOW_LEARNING_DIR"
ledger="$dir/ledger.jsonl"
rules="$dir/rules.jsonl"

sources="verify review feedback rework ci prod correction stuck"
stages="start design plan implement verify review ship"

die() { echo "ERROR: $*" >&2; exit 2; }
one_of() { local v="$1"; shift; for x in "$@"; do [ "$v" = "$x" ] && return 0; done; return 1; }

# macOS ships bash 3.2: no associative arrays, so each option is its own variable.
opt_repo=""; opt_task=""; opt_source=""; opt_ref=""; opt_missed_by=""; opt_class=""
opt_evidence=""; opt_note=""; opt_date=""; opt_min=""; opt_where=""; opt_rung=""
cmd="${1:-}"; [ -n "$cmd" ] && shift
while [ $# -gt 0 ]; do
  case "$1" in
    --repo|--task|--source|--ref|--missed-by|--class|--evidence|--note|--date|--min|--where|--rung)
      [ $# -ge 2 ] || die "$1 needs a value"
      v="${1#--}"; v="${v//-/_}"; printf -v "opt_$v" '%s' "$2"; shift 2 ;;
    *) die "unexpected argument: $1" ;;
  esac
done
arg() { local v="opt_${1//-/_}"; echo "${!v}"; }
need() { [ -n "$(arg "$1")" ] || die "--$1 is required"; }
today=$(date +%F)

case "$cmd" in
  add)
    for k in repo task source ref missed-by class; do need "$k"; done
    one_of "$(arg source)" $sources || die "--source must be one of: $sources"
    one_of "$(arg missed-by)" $stages || die "--missed-by must be one of: $stages"
    [[ "$(arg class)" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || die "--class must be a kebab-case slug"
    date=$(arg date); date=${date:-$today}
    [[ "$date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || die "--date must be YYYY-MM-DD"
    mkdir -p "$dir"; touch "$ledger"
    if jq -e --arg r "$(arg repo)" --arg t "$(arg task)" --arg s "$(arg source)" --arg f "$(arg ref)" \
         'select(.repo==$r and .task==$t and .source==$s and .ref==$f)' "$ledger" >/dev/null 2>&1; then
      echo "exists"; exit 0
    fi
    jq -cn --arg date "$date" --arg repo "$(arg repo)" --arg task "$(arg task)" \
      --arg source "$(arg source)" --arg ref "$(arg ref)" --arg missed_by "$(arg missed-by)" \
      --arg class "$(arg class)" --arg evidence "$(arg evidence)" --arg note "$(arg note)" \
      '{date:$date, repo:$repo, task:$task, source:$source, ref:$ref, missed_by:$missed_by,
        class:$class, evidence:$evidence, note:$note}' >> "$ledger"
    echo "added"
    ;;
  list)
    [ -f "$ledger" ] || exit 0
    if [ -n "$(arg class)" ]; then jq -c --arg c "$(arg class)" 'select(.class==$c)' "$ledger"
    else cat "$ledger"; fi
    ;;
  stats)
    min=$(arg min); min=${min:-2}
    [[ "$min" =~ ^[0-9]+$ ]] || die "--min must be a number"
    [ -f "$ledger" ] || { echo "[]"; exit 0; }
    # A class's rule is its latest entry in rules.jsonl. Entries dated after
    # that rule are repeats: the rule did not hold and needs the next rung.
    jq -s --argjson min "$min" --slurpfile rules <( [ -f "$rules" ] && cat "$rules" || true ) '
      ($rules | group_by(.class) | map({key: .[0].class, value: (sort_by(.date) | last)}) | from_entries) as $r
      | group_by(.class)
      | map(.[0].class as $c | {
          class: $c,
          entries: length,
          tasks: (map(.repo + "/" + .task) | unique | length),
          missed_by: (group_by(.missed_by) | map({key: .[0].missed_by, value: length}) | from_entries),
          sources: (group_by(.source) | map({key: .[0].source, value: length}) | from_entries),
          last: (map(.date) | max),
          rule: ($r[$c] // null),
          repeats_after_rule: (if $r[$c] then (map(select(.date > $r[$c].date)) | length) else null end)
        })
      | map(select(.tasks >= $min))
      | sort_by(-.tasks, -.entries)' "$ledger"
    ;;
  rule)
    for k in class where rung; do need "$k"; done
    [[ "$(arg rung)" =~ ^[1-4]$ ]] || die "--rung must be 1 (skill text), 2 (checkpoint question), 3 (check script) or 4 (hook)"
    date=$(arg date); date=${date:-$today}
    mkdir -p "$dir"
    jq -cn --arg class "$(arg class)" --arg where "$(arg where)" --argjson rung "$(arg rung)" --arg date "$date" \
      '{class:$class, where:$where, rung:$rung, date:$date}' >> "$rules"
    echo "recorded"
    ;;
  *)
    sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2 ;;
esac
