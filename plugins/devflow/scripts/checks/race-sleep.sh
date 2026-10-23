#!/usr/bin/env bash
# A race or concurrency test that waits with sleep or a timer passes on the
# timing of the machine it ran on, not on the code: on a fast machine the
# window never opens and the test proves nothing. reference/testing-patterns.md
# lists the deterministic replacements (a barrier, a held lock, a trigger).
#
# A zero sleep (`asyncio.sleep(0)`, `setTimeout(f, 0)`) only yields to the
# event loop; it does not wait on time, so it is not flagged here.
#
# Flags added sleep/timer lines in test files that are about concurrency: the
# path says so (race, concurren, parallel, dedup, idempot, lock), or the
# branch's added lines in that file run things side by side (gather,
# Promise.all, threads, a barrier).
#
# Usage: race-sleep.sh <base-ref>   (run from inside the repo)
# Output: "path:line<TAB>race-sleep<TAB>text"; exit 0 clean, 1 findings, 2 error.
set -uo pipefail
. "$(dirname "$0")/lib-diff.sh"
base="${1:?usage: race-sleep.sh <base-ref>}"
git rev-parse --verify --quiet "$base" >/dev/null || { echo "ERROR: unknown ref $base" >&2; exit 2; }

added=$(added_lines "$base") || exit 2
[ -z "$added" ] && exit 0

# BSD awk on macOS: no IGNORECASE and no \b, so match on lowercased text.
printf '%s\n' "$added" | awk -F'\t' '
  function is_test(p) { return p ~ /(^|\/)(tests?|__tests__|spec|e2e)\// || p ~ /(_test|\.test|\.spec|_spec)\.[a-z]+$/ || p ~ /(^|\/)test_[^\/]*$/ }
  {
    p = $1; n = $2; t = $3; lp = tolower(p); lt = tolower(t)
    if (!is_test(lp)) next
    if (lp ~ /(race|concurren|parallel|dedup|idempot|lock)/) conc[p] = 1
    if (lt ~ /(asyncio\.gather|promise\.all|threading\.|threadpool|barrier|concurrent\.futures|errgroup|go func)/) conc[p] = 1
    if (lt ~ /sleep\( *0(\.0*)? *\)/ || lt ~ /settimeout\(.*, *0 *\)/) next
    if (lt ~ /(time\.sleep\(|asyncio\.sleep\(|settimeout\(|waitfortimeout\(|thread\.sleep\(|(^|[^a-z_.])sleep\(|(^|[^a-z_])sleep [0-9])/) hit[++k] = p "\t" n "\t" t
  }
  END {
    found = 0
    for (i = 1; i <= k; i++) { split(hit[i], f, "\t"); if (f[1] in conc) { sub(/^[ \t]+/, "", f[3]); printf "%s:%s\trace-sleep\t%s\n", f[1], f[2], f[3]; found = 1 } }
    exit found
  }'
