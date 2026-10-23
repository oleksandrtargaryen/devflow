---
name: verify
description: devflow verify stage. Runs the full test and lint suite and the mechanical checks on the task branch, checks every acceptance criterion has evidence, and exercises the change in the running app or as the API's caller. Invoked by /devflow:next.
user-invocable: false
effort: high
---

# devflow: verify

Read `${CLAUDE_PLUGIN_ROOT}/reference/conventions.md` first. Then `ticket.md`, `state.md`, and the
`## Acceptance` section of `plan.md`.

## 1. Suite

Run `test_cmd` and `lint_cmd` fresh, in full. Never report a result you did not see in this run's
output.

## 2. Mechanical checks

Run `${CLAUDE_PLUGIN_ROOT}/scripts/run-checks.sh origin/<base>` from the repo (after
`git fetch origin`). It judges only lines this branch added. Each finding is a gap to fix in a new
slice, unless the user decides at the checkpoint that it is a false positive. In that case record
it, so `/devflow:learn` can narrow the check: `ledger.sh add --source correction --missed-by
verify --class check-false-positive --ref <check>:<file:line>`.

## 3. Criteria

For each acceptance criterion in `ticket.md`, name the test (or command output) that proves it. A
criterion with no evidence is a gap, even if the suite is green.

## 4. Runtime acceptance

Tests passing is not evidence that a person or a caller sees the change working. Use
`acceptance:` from `state.md`. If it is missing (the task was planned before devflow 0.2), decide it
by the rules in `devflow:plan` step 4 and say so at the checkpoint.

**`ui`**: start the app with the `run` skill on this branch. Make sure the server serves this
worktree, not a process left from another branch. Then use claude-in-chrome: load its tools in one
ToolSearch call, open a new tab, never trigger `alert`/`confirm`/`prompt`. Exercise, as far as
the change reaches:

- the primary flow, as a user would do it;
- the states it touches: populated, empty, loading, error, no permission;
- console errors and failed requests during those interactions (`read_console_messages` with a
  pattern, `read_network_requests`). If the network tracker and the page disagree, check the
  browser's own evidence before blaming the app;
- one more consumer of any shared component or hook the branch changed.

**`api`**: start the server locally and act as the sender, branch by branch, from plan.md's
`## Acceptance` list: real requests (curl, or the project's client), not the test harness. For
each branch record the status, machine code and body you got next to the ones expected. Each of
these is a finding: a `5xx` or `internal_error` for a client mistake; a status or code the spec
declares that you could not produce; a body that leaks internals (SQL, stack, provider error
text); a contract detail only someone reading the code would know.

**`eval`** (`domain: ml`): write `## Eval report` in `state.md` as `${CLAUDE_PLUGIN_ROOT}/reference/ml-practices.md` section 7 lists it. That
includes running `python3 -I ${CLAUDE_PLUGIN_ROOT}/scripts/ml/leakage.py --train <train> --test
<test>` and reporting its numbers. The test split is evaluated once, here. The metric is compared to
the bar from spec.md and to the baselines. A missed bar is a gap like a failing test: it routes back
to implement, with a new experiment slice, or to the user if the budget is spent.

**`none`**: nothing to do; the reason is in plan.md.

Report three lists, never merged:

- **verified**: exercised and observed to match. Say what was done, where (URL, tab, viewport or
  endpoint), and with what result;
- **not verified**: not exercised, with the reason (no environment, no representative data, out
  of reach);
- **blocked**: tried and could not finish, with the exact blocker (server does not start, login
  fails, a dialog that will not close).

Nothing counts as verified that was only seen through unit or integration tests. If acceptance is
not possible on this machine at all, say that plainly; do not substitute a weaker check and call it
verified.

## 5. Tree

`git status` must be clean. `git diff origin/<base>...HEAD --stat` must contain only files the plan
expected (flag the rest).

## 6. Log and route

Log the suite under `## Verify log` and acceptance under `## Acceptance` in `state.md`, each
entry with the date and the short sha.

- All green, no check findings, every criterion covered, acceptance with no unexplained gaps →
  `next: review`.
- Otherwise → `next: implement`, and add a slice to `## Slices` / `plan.md` for each gap or
  failure. Each gap that the plan or the implementation should have prevented (an uncovered
  criterion, a check finding, an acceptance failure) is a miss: record it with `ledger.sh add
  --source verify --missed-by <plan|implement> ...`.

`blocked` items do not route back to implement. They go to the checkpoint, and `ship` refuses them
unless the user records a decision about each one in `## Decisions`.

Set `stage: verify`.

Checkpoint: pass/fail with counts, check findings, the criterion → evidence table, the three
acceptance lists, unexpected files.

## The 💡 line at the checkpoint

The user is deciding whether the change is proven to work, beyond "the tests are green". What to
check: the "not verified" and "blocked" acceptance items. Each one is a part of the change that
nobody has seen working yet.
