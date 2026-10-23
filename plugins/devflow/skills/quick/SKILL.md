---
name: quick
description: devflow quick stage, for small fully specified changes. In one stage - branch, test-first change (or no new test for a change with no behaviour), suite and checks, a self-review against the ticket and the repo's rules - then stops with the diff. Hands the task to the full route if it turns out bigger. Invoked by /devflow:next.
user-invocable: false
effort: high
---

# devflow: quick

Read `${CLAUDE_PLUGIN_ROOT}/reference/conventions.md` first. Then `ticket.md` and `state.md`.

The quick route trades ceremony for speed only while the task stays small. The criteria in
`devflow:start` ("Route") are the contract. The moment one of them stops holding, stop (see
**Escalate**). Finishing a big change through the quick route is the one failure this stage
exists to avoid.

## 1. Branch

`repo-info.sh`, require a clean tree, `git fetch origin`, `git switch -c <branch> origin/<base>`
(or switch to it if it exists).

## 2. Change

Behaviour change (`feat`, `fix`): follow `mattpocock-skills:tdd` for exactly one cycle.
1. Write the test that shows the wrong or missing behaviour, at the most public interface that
   reaches it (the one the bug report or the ticket talks about). Run it alone and see it fail for
   the expected reason. Paste the failing line.
2. Make the smallest change that passes it. A library API or configuration key new to this repo
   is checked against the docs for the installed version first (Context7 when present,
   `${CLAUDE_PLUGIN_ROOT}/reference/optional-tools.md`).

No behaviour change (`chore`: copy, docs, config value, rename, patch bump): no new test. Say in
one line why none is needed.

Two attempts at most (conventions: "Two failed attempts, then stop"). A third attempt at a "small"
change means it is not small: escalate.

## 3. Checks

- Run `test_cmd` and `lint_cmd` in full, and `${CLAUDE_PLUGIN_ROOT}/scripts/run-checks.sh
  origin/<base>`. Never report a result you did not see in this run.
- `git diff origin/<base>...HEAD --stat`: still within the size the route allows?
- If the change is visible in the UI or in an API response, look at it once for real: the `run`
  skill and one page in claude-in-chrome, or one real request. Log it under `## Acceptance` in
  `state.md` as verified / not verified (with the reason) / blocked, and set `acceptance:`
  accordingly (`none` when nothing is visible outside the tests).

## 4. Self-review

One pass over the diff, by you, with no subagents:
- against `ticket.md`: every acceptance criterion is met, nothing extra was added;
- against the repo's CLAUDE.md / AGENTS.md and the ADRs for the touched files;
- docs, README or comments that the change made false (fix them in this change);
- for `fix`: is the same bug present at the other callers of what you changed? If yes, that is a
  systemic fix: escalate.

Write the result under `## Self-review` in `state.md`, one line per point, with what you fixed.

## 5. Commit

`<type>: <behaviour>` (+ ticket id in the body). Log the run under `## Verify log`. Set
`stage: quick`, `next: ship`.

## Escalate

Stop before writing more code as soon as any of these holds: a route criterion breaks (another
layer, a contract, auth, concurrency, a schema, more files than allowed); a question appears that
the ticket does not answer; the second attempt failed; the same cause sits in other callers.

Then: leave the work uncommitted, or committed only if the suite is green, and say which. Write what
you learned into `ticket.md` (`## Open questions`) and set `route: full` and `next: design`
(`plan` when there is no design question, only more slices). Record the misjudged route with
`ledger.sh add --source correction --missed-by start --class route-too-small --ref quick --note
"<which criterion broke>"`. The checkpoint explains what made it bigger.

## Checkpoint

The diff summary (files, lines), the test that went red → green (or why none), suite and check
results, acceptance, self-review lines, commit hash.

💡 This checkpoint asks whether this small change is what you wanted and is safe to push. A quick
change skips design and review, so this diff is the only review it gets. Read the diff itself
(`git show --stat HEAD`, then the changed lines), not only this summary.
