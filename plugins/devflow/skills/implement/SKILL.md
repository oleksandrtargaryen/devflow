---
name: implement
description: devflow implement stage. Implements exactly one unchecked slice from plan.md test-first, commits it, and stops. Invoked by /devflow:next.
user-invocable: false
effort: high
---

# devflow: implement (one slice)

Read `${CLAUDE_PLUGIN_ROOT}/reference/conventions.md` first. Then `state.md`, and from `plan.md`
only the first unchecked slice. Check you are on the task branch.

Follow `mattpocock-skills:tdd` (invoke it). For this one slice:

1. **Red.** Write the test the plan names, at the agreed seam. Run it alone and see it fail
   *for the expected reason* (an assertion, not an import error or a typo). Paste the failing line.
   For a concurrency, dedup, limit or lock slice, use the technique the plan names from
   `${CLAUDE_PLUGIN_ROOT}/reference/testing-patterns.md`. Red must come from the race itself
   (the second caller gets through, the slot leaks), on the code without the protection. No
   `sleep` or timer as the mechanism of the race.
2. **Green.** Write the minimal code that passes it. No speculative parameters, no extra features.
   Put code where the ADRs and the existing layout say it belongs. A library call or a
   configuration key this repo does not use yet is checked before you write it, not after it
   fails: the docs for the installed version (Context7 when present), and the installed package's
   types or source when the docs and the code disagree
   (`${CLAUDE_PLUGIN_ROOT}/reference/optional-tools.md`).
3. **Suite.** Run `test_cmd` (and `lint_cmd`). If something else broke, fix it now. If the cause
   is not obvious within one attempt, invoke `mattpocock-skills:diagnosing-bugs` rather than
   guessing. Never more than two attempts at one defect: after the second, follow "Two failed
   attempts, then stop" in the conventions. Stop and bring what you found to the checkpoint, not
   a third patch.
4. **Commit** the slice: `<type>: <behaviour>` (+ ticket id in the body).
5. Tick the slice in `state.md`, log the test run under `## Verify log`.
   `next:` stays `implement` while slices remain, else becomes `verify`. Set `stage: implement`.

**Experiment slices** (`domain: ml`) have no red/green. Follow `${CLAUDE_PLUGIN_ROOT}/reference/ml-practices.md` section 4: run exactly the
planned change with the planned seed and budget, and log the run as a row in
`<task_dir>/experiments.md` (config path@sha, data revision, metric on validation, cost). Apply the
slice's decision rule and commit code and configs, never weights or data. A launch of paid compute
goes through the guard's question: state the hardware, timeout and expected cost in the same message.
A run that fails or diverges is debugged with section 6, and the two-attempts rule applies to runs
too.

Do not refactor beyond what the slice needs (refactoring belongs to review), and do not start the
next slice.

If the plan turns out wrong (the seam doesn't exist, the slice needs a decision the spec didn't
make), stop before writing code, explain, and propose the change to `plan.md` at the checkpoint.
The same applies when the plan's "Reclassify if" condition holds (the same cause in another
caller): stop and propose the reclassification rather than patching only this caller. Either way,
record the miss with `ledger.sh` (`--source correction`, `--missed-by plan`, or `design` if the
spec was wrong).

Checkpoint: slice n/total, the test that went red → green, files changed, commit hash.

## The 💡 line at the checkpoint

The user is checking one small, finished step. The red line proves the test can catch the bug; a
test that never failed proves nothing. What to check: that the failing line shown fails for the
reason the slice is about, and that the diff touches only the files the plan named.
