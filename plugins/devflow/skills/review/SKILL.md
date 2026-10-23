---
name: review
description: devflow review stage. Matt Pocock's two-axis code-review (Standards + Spec) plus security-review on the task branch, written to review.md; the user picks what to fix. Invoked by /devflow:next or directly as /devflow:review.
effort: xhigh
---

# devflow: review

Read `${CLAUDE_PLUGIN_ROOT}/reference/conventions.md` first. Then `ticket.md`, `spec.md`, `state.md`.

If `review.md` already exists with a `Decision:` line that is not `pending`, skip to **Fix**.

## 1. Collect

Fixed point: `origin/<base>` (run `git fetch origin` first). The diff must be non-empty.

**Standards + Spec**: invoke `mattpocock-skills:code-review` with:
- fixed point `origin/<base>`;
- spec: `<task_dir>/ticket.md` and `<task_dir>/spec.md` (there is no issue tracker; do not suggest
  `/setup-matt-pocock-skills`);
- standards sources: the repo's CLAUDE.md / AGENTS.md / CONTRIBUTING.md, plus every ADR in
  `<adr_dir>/` and `<context_dir>/GLOSSARY.md`. ADRs are where things are supposed to live:
  code placed against an ADR is a hard Standards violation, not a judgement call. Also
  `${CLAUDE_PLUGIN_ROOT}/reference/engineering-habits.md`, `reference/testing-patterns.md` (a race
  test that waits on timing is a hard finding), and the repo's own skills in `.claude/skills/*/SKILL.md`
  whose description matches the files changed: their invariants are standards for that area. For
  `domain: ml`, also `${CLAUDE_PLUGIN_ROOT}/reference/ml-practices.md`: a metric with no baseline, a test split used for tuning, leaked eval
  data, an unrecorded seed or version, or an unlicensed model or dataset is a hard finding.

**Security**: invoke `security-review` on the same branch.

**Mechanical checks**: run `${CLAUDE_PLUGIN_ROOT}/scripts/run-checks.sh origin/<base>` and list
each finding under Standards as `[hard]`.

## 2. review.md

Write `<task_dir>/review.md`, keeping the axes separate as Matt's skill requires (no cross-axis
re-ranking):

```
# Review: <branch> vs <base> (<date>, <short sha>)
## Standards
- S1 [hard|judgement] <file:line> <finding> → <suggested fix>
## Spec
- P1 [missing|extra|wrong] <finding> (spec: "<quoted line>") → <suggested fix>
## Security
- X1 [high|medium|low] <file:line> <finding> → <suggested fix>
Decision: pending
```

Set `stage: review`, `next: review`.

Checkpoint: counts per axis and the worst finding in each; ask the user which ids to fix
("all hard + X*", "S1 P2", "none"…).

## Fix (after the user picks)

Write the chosen ids into `Decision:`.

**Record the misses first.** Every chosen finding is something an earlier stage let through. For
each one decide which stage should have caught it (the earliest one whose job it was: a missing
reach question is `design`; an untested race or a missing slice is `plan`; code that ignores a
planned test or an ADR is `implement`; a criterion with no evidence that verify passed is
`verify`) and the class of mistake. Add `(missed: <stage>, <class>)` to the finding's line and run
`ledger.sh add --source review --ref <id> --missed-by <stage> --class <class> --evidence
"<file:line>" --note "<finding in one line>"` (repo and task from repo-info). A second review in
the same task (`# Review 2`) records with `--missed-by review` for what the first one missed, in
addition to the earlier stage. Declined findings are not misses; do not record them. For each chosen finding: a behaviour change goes test-first
(`mattpocock-skills:tdd`), a pure refactor keeps the suite green; one commit per finding or per
tight group (`fix(review): S1 …`). Mark each as `✔ fixed <sha>` or `✘ declined: <reason>` in
review.md. Offer `/simplify` once if Standards had smells, and run it only on a yes.

Then run the suite (as in `devflow:verify` step 1) and log it. Green → `stage: review`,
`next: ship`. Checkpoint: what was fixed, with commits, and the test result.

## The 💡 line at the checkpoint

At the first checkpoint, the user is choosing which findings to fix. "[hard]" and "[high]" ones are
defects, and "[judgement]" ones are trade-offs. Declining a hard finding should come with a reason.
What to check: the worst finding on each axis, and whether its suggested fix is right. At the second
checkpoint, check that every chosen finding has a commit and that the suite is green.
