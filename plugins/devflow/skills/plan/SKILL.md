---
name: plan
description: devflow plan stage. Splits the task into vertical TDD slices, each with an agreed seam, and writes plan.md. Invoked by /devflow:next.
user-invocable: false
effort: xhigh
---

# devflow: plan

Read `${CLAUDE_PLUGIN_ROOT}/reference/conventions.md` first. Then `ticket.md`, `spec.md` (absent
for size S), `state.md`, and the ADRs in `adr_dir` for the area.

## 1. Branch (size S only)

Size S skipped `design`, so the branch does not exist yet: do the Branch step from
`devflow:design` here (`git fetch origin`, `git switch -c <branch> origin/<base>`).

## 2. Classification

Name the scope before slicing, in one line that goes at the top of plan.md:
`Classification: <point fix | vertical slice | systemic fix | refactor>, because <reason>.
Reclassify if <concrete condition>.`

- **point fix**: one wrong behaviour in one place. Fix exactly that. Do not add tests + docs +
  migration + audit by default to a two-line fix, only the layers the fix really needs.
- **vertical slice**: new behaviour across layers, ending in something a user or caller can use.
  Only the layers it needs; never "just the backend" of a user-visible feature unless the user
  asked for exactly that.
- **systemic fix**: the cause is shared by several callers. Fix the shared cause and prove it on
  at least one more caller. This is an outcome of reading the code, not a starting default.
- **refactor**: only when restructuring IS the request.

The reclassification condition must be checkable ("becomes systemic if `parse_sender` has the same
bug in the IMAP path"), not "may grow". `implement` stops when it sees that condition hold.

## 3. Slices

Read the "Seams" and "Rules of the loop" sections of `mattpocock-skills:tdd` (invoke it) and plan
by them:

- **Vertical slices**: each slice is one behaviour, end to end, through one seam: one failing test,
  the minimal code to pass it. No "all tests first" slice, no "infrastructure" slice that tests
  nothing.
- Order slices so each one teaches something the next can use (tracer bullets).
- Every acceptance criterion in `ticket.md` is covered by at least one slice; say which.
- Name the files each slice is expected to touch, following where the ADRs and the existing
  layout say things live. If a slice needs a new module, say where and why.
- For `chore` with no behaviour change, slices are steps that keep the existing test suite green
  after each one.
- **Concurrency, dedup, idempotency, limits, quotas, locks, crash recovery**: read
  `${CLAUDE_PLUGIN_ROOT}/reference/testing-patterns.md`. Such a slice names its technique in
  `Test:` (barrier at the await, gated transaction, NOWAIT probe, trigger, rows-the-crash-left,
  killed child) and says how the test fails on the unprotected code. "Run N in parallel" or a
  sleep is not a technique; a slice without one is not planned yet. Look for these slices
  actively: every "check, then await, then write" in the design and every counter or cap shared
  between sessions, processes or replicas is one.
- **Third-party APIs**: a slice that rests on a library's API or a configuration key names the
  version installed (from the lockfile) and where its documentation for that version was read:
  Context7 when present, else the official docs (`${CLAUDE_PLUGIN_ROOT}/reference/optional-tools.md`).
  An API planned from memory goes under `## Risks` as not verified.
- Check the plan against `${CLAUDE_PLUGIN_ROOT}/reference/engineering-habits.md` (reach, dev vs
  prod, trust boundaries, late or out-of-order input, the caller's contract) and add the slices
  it implies.

**ML tasks** (`domain: ml`): plan code slices and experiment slices as in `${CLAUDE_PLUGIN_ROOT}/reference/ml-practices.md` section 4, ordered
data look → eval harness and baseline numbers → loss at init and overfit one batch → small run →
full run. Each experiment slice has a hypothesis, one change, config, seed, budget, expected result
and a decision rule instead of a red test. Anything that launches paid compute names the hardware,
timeout and expected cost in the slice.

## 4. Acceptance

Decide how `verify` will see this change working outside the test suite, and write
`acceptance:` into `state.md`:

- `ui`: a person sees or does something different in a browser;
- `api`: a caller (HTTP API, webhook, inbound mail, a queue consumer) sees a different response
  or effect. List in plan.md, under `## Acceptance`, each response branch to exercise as the
  sender: the success path, then malformed body, oversized body, missing fields, unknown values,
  no or wrong auth, plus every branch the spec's Behaviour adds. Each with the expected status,
  machine code and body;
- `both`;
- `eval` (`domain: ml`): the evidence is the eval report from ml-practices.md section 7: the
  metric against the bar and the baselines, on a frozen test split evaluated once, with the leakage
  check;
- `none`: nothing observable changes outside the tests (a pure refactor, a test-only chore).
  Say why in plan.md.

## 5. plan.md

```
# Plan: <title>
Classification: <...>, because <...>. Reclassify if <...>.
Seams (agreed): <list>
## Slice 1: <behaviour>
- Seam: <interface>
- Test: <test name, file, the assertion in one line, expected value and where it comes from>
- Code: <files>
- Covers: AC <n>
...
## Acceptance
- <ui flows and states, or api branches with expected status / code / body, or why none>
## Risks
```

Mirror the slices as a checklist in `state.md` → `## Slices`, write `acceptance:`. Set
`stage: plan`, `next: implement`.

## 6. Checkpoint

The seams are the decision here: list them and ask the user to confirm them explicitly, plus the
classification, the slice list and the acceptance mode. Matt's TDD rule is that no test is written
at an unconfirmed seam.

## The 💡 line at the checkpoint

The user is confirming the seams: the public interfaces the tests will call (name them, for example
`ImportService.handle(message)`). Tests at the wrong seam either break on every refactor or prove
nothing. Also confirm the classification, and the acceptance mode, which decides how "it works" will
be shown. What to check: that each seam is an interface real callers use, and that every acceptance
criterion has a slice.
