# Deterministic tests for concurrency, crashes and counts

Read by `plan` when a slice is about concurrency, deduplication, idempotency, limits, quotas,
locks or crash recovery, and by `implement` when writing that slice's test.

The rule behind every section: a test of a race has to *produce* the interleaving it claims to
cover. A test that fires N parallel requests, or waits with `sleep`, passes on the timing of the
machine it ran on. On a fast machine the window never opens and the test proves nothing, and the
day it goes red it looks like flakiness instead of a bug. `scripts/checks/race-sleep.sh` flags
sleeps and timers added to concurrency tests.

Each slice of this kind names its technique in plan.md's `Test:` line, for example
`Test: barrier between check and write (testing-patterns: check-then-act)`. And its red run must
fail on the unprotected code. A race test that passes before the fix is not covering the race.

## Check-then-act in async code (Python, TypeScript)

The usual bug: a check (`if name not pinned`, `if slots left`) and the write that depends on it
sit on either side of an `await`. Two callers both pass the check, then both write.

Make the first caller stop inside the window and hold it there while the second runs:

- Inject a hook at the `await` point (a fake dependency whose call waits on an `asyncio.Event` /
  a deferred promise). Start caller A and wait until the hook reports that A has arrived. Run
  caller B to completion. Then release A and assert on the final state.
- The gate opens when the other side *reports* it has arrived, never after a duration. A single
  `await asyncio.sleep(0)` (or `setTimeout(f, 0)`) before opening the gate bets that every other
  task reached the window in one loop tick. That holds only until the code under test gains an
  await. Have the fake count arrivals and wait for the count (an Event set at N), then open the
  gate. Polling a predicate with `sleep(0)` in a bounded loop is acceptable: it waits for a fact,
  not a duration.
- Assert both halves: the loser is refused (or retried), *and* any side effect it already
  started is undone. A slot taken and never returned is the second half of the same bug.

## A window between two transactions (lost finalization)

The invariant is about what survives a crash between two commits. There are three honest ways to
produce the window, and they are not interchangeable:

1. **Write the rows the crash would have left.** Cheap, deterministic, and the right default.
   It only works if the shape is faithful: the state really left between the two commits, not
   a simplified one that takes a different branch (an "already done" skip) and so exercises
   nothing. Put the injector in a shared fixture, with the distinction written next to it.
2. **Gate a real transaction.** Two workers, one parked mid-mutation on a deferred, the other
   run to completion. This proves that a protocol serialises, that the loser's writes roll back,
   and that nothing is visible to an outside reader before the single commit.
3. **Kill a real child process.** Needed when, and only when, the invariant is that NOTHING ran
   on the way out. An in-process `throw` always unwinds its own stack (`finally`, `atexit`,
   handlers), so it cannot stand in for `SIGKILL`. Have the child print a marker at the point of
   no return, kill it on that marker, and assert on the signal it died from.

## Proving a lock, and its mode (PostgreSQL)

A lock is correct only relative to what it must exclude *and* what it must not block. Assert both:

- **What it excludes:** probe from a second connection with `SELECT ... FOR UPDATE NOWAIT`. It
  raises `55P03` at once if the row is locked. For a statement that cannot take `NOWAIT` (an
  INSERT checking a foreign key), use `SET LOCAL lock_timeout = '50ms'`, which turns the same
  question into a deterministic error code.
- **What it must not block:** run that statement under a short `lock_timeout` and assert that it
  *succeeds*. A regression then fails fast and names itself instead of hanging until the test
  timeout.

## Injecting a race at an exact instant

- **A database trigger** on the row the first transaction writes. It runs inside that
  transaction and commits with it, so the interleaving is certain, not likely. Create it in the
  test and drop it afterwards.
- **Holding a row lock** that the production code will need, to park a real action mid-mutation
  without patching it. Wait for the block to show in `pg_stat_activity`
  (`wait_event_type = 'Lock'`), not for a duration. A row-lock wait is on a `transactionid`, so
  `pg_locks.relation` is NULL for it.
- **Redis / external stores:** wrap the client in the test so the call between "read" and
  "write" blocks on an event, the same as the async check-then-act above. Run Lua scripts against
  a real Redis when the atomicity of the script is the property under test. A fake does not
  execute Lua the same way.

## Counts must be non-vacuous

"This count did not grow" holds for free when the count is always zero. Before asserting that a
count did not change, prove the baseline counts real rows: assert that it went from 0 to 1 on the
first event, then that it stays at 1 on the duplicate. Typical ways a count is silently zero:

- the rows are written only under a condition the test never sets up (an active subscription,
  a feature flag, a matching rule);
- the filter column is NULL where the test expects a value (an actor kind, a correlation id);
- the event under test never carries the field the count is scoped by.

If the zero is legitimate, assert it explicitly with a comment saying why. Then the day it stops
being zero, the suite says so.

## Late and out-of-order input

For any filter by a time window or a sequence: write a case for the record that arrives late, and
one for the record that arrives out of order. State whether it is lost (and logged), or handled.
Silent loss is a finding.
