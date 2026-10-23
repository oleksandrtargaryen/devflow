#!/usr/bin/env bash
# Runs the mechanical checks against a throwaway repo. Exit status is the number of failures.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
repo="$tmp/repo"
git init -q -b dev "$repo"
g() { git -C "$repo" -c user.email=t@t -c user.name=t "$@"; }
put() { mkdir -p "$(dirname "$repo/$1")"; printf '%s\n' "$2" >> "$repo/$1"; }

# On the base: an old sleep in a race test. It must never be reported.
put tests/test_race_old.py 'time.sleep(1)  # old'
g add -A; g commit -q -m base
g switch -q -c feat/x

put tests/test_race_old.py 'assert True'
put tests/test_dedup.py 'def test_dup():'
put tests/test_dedup.py '    time.sleep(0.1)'
put tests/test_users.py '    await asyncio.gather(a(), b())'
put tests/test_users.py '    await asyncio.sleep(0.05)'
put web/limits.concurrency.test.ts '  await new Promise(r => setTimeout(r, 50));'
put tests/test_plain.py '    time.sleep(1)'
put src/race.py 'time.sleep(1)'
put tests/test_lock_ok.py '    barrier.wait()'
put tests/test_race_yield.py '    await asyncio.gather(a(), b())'
put tests/test_race_yield.py '    await asyncio.sleep(0)'
put web/yield.concurrency.test.ts '  await new Promise(r => setTimeout(r, 0));'
g add -A; g commit -q -m work

fails=0
out=$(cd "$repo" && "$here/checks/race-sleep.sh" dev); rc=$?
expect() {  # expect <present|absent> <path:line>
  if printf '%s\n' "$out" | grep -q "^$2	"; then got=present; else got=absent; fi
  if [ "$got" = "$1" ]; then echo "ok    $1  $2"; else echo "FAIL  want $1 got $got  $2"; fails=$((fails+1)); fi
}
expect present tests/test_dedup.py:2                 # race-ish path, added sleep
expect present tests/test_users.py:2                 # gather in added lines makes it a concurrency test
expect present web/limits.concurrency.test.ts:1      # TS timer
expect absent  tests/test_race_old.py:1              # line from the base
expect absent  tests/test_plain.py:1                 # not about concurrency
expect absent  src/race.py:1                         # not a test file
expect absent  tests/test_lock_ok.py:1               # no sleep at all
expect absent  tests/test_race_yield.py:2            # sleep(0) yields, it does not wait on time
expect absent  web/yield.concurrency.test.ts:1       # setTimeout(..., 0) likewise
[ $rc -eq 1 ] && echo "ok    exit 1 on findings" || { echo "FAIL  exit $rc, want 1"; fails=$((fails+1)); }

(cd "$repo" && "$here/run-checks.sh" dev >/dev/null); rc=$?
[ $rc -eq 1 ] && echo "ok    run-checks propagates findings" || { echo "FAIL  run-checks exit $rc, want 1"; fails=$((fails+1)); }

g switch -q dev; g switch -q -c feat/clean
put tests/test_race_new.py '    barrier.wait()'
g add -A; g commit -q -m clean
(cd "$repo" && "$here/run-checks.sh" dev >/dev/null); rc=$?
[ $rc -eq 0 ] && echo "ok    clean branch exits 0" || { echo "FAIL  clean exit $rc, want 0"; fails=$((fails+1)); }

(cd "$repo" && "$here/checks/race-sleep.sh" no-such-ref 2>/dev/null); rc=$?
[ $rc -eq 2 ] && echo "ok    unknown ref exits 2" || { echo "FAIL  unknown ref exit $rc, want 2"; fails=$((fails+1)); }

echo "failures: $fails"
exit $fails
