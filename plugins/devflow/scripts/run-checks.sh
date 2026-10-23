#!/usr/bin/env bash
# Runs every mechanical check in checks/ against the branch's added lines.
# A check is the third rung of a learned rule: what a stage kept forgetting
# becomes a script that cannot forget. /devflow:learn adds them here.
#
# Usage: run-checks.sh <base-ref>   (run from inside the repo)
# Output: one finding per line; exit 0 clean, 1 findings, 2 a check could not run.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
base="${1:?usage: run-checks.sh <base-ref>}"
status=0
for c in "$here"/checks/*.sh; do
  [ -x "$c" ] || continue
  "$c" "$base"; rc=$?
  if [ $rc -eq 1 ]; then [ $status -eq 0 ] && status=1
  elif [ $rc -ne 0 ]; then echo "ERROR: $(basename "$c") exited $rc" >&2; status=2; fi
done
exit $status
