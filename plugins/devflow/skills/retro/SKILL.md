---
name: retro
description: Look back at a shipped devflow task for what devflow missed - reviewers' PR comments, CI on the merge commit, later commits that reworked the task's code, and production errors when Sentry is connected - and record each miss in the learning ledger after the user confirms. Works on any task that reached ship, merged or archived or not.
argument-hint: [branch or task folder; default: the current branch's task]
effort: xhigh
---

# devflow: retro

Read `${CLAUDE_PLUGIN_ROOT}/reference/conventions.md` first, especially "Learning from misses".

Input: $ARGUMENTS

## 1. Which task

Run `${CLAUDE_PLUGIN_ROOT}/scripts/repo-info.sh`. The task is the argument (a branch name, or a
task folder, including one under `_done/`), else the current branch's task. Read its `ticket.md`,
`spec.md`, `plan.md`, `state.md`, `review.md`. Records already in the ledger for this task
(`ledger.sh list`, filtered by repo and task) are not added again.

## 2. Collect, read-only

Everything here only reads. Forge calls go through
`${CLAUDE_PLUGIN_ROOT}/scripts/forge-api.sh <path>` (GitHub through the `gh` CLI, Gitea through
`GITEA_URL` / `GITEA_TOKEN`; it never prints a token). If it exits 3 (unknown forge, or not
authenticated), skip 2a and 2b, and say so at the checkpoint with the reason it printed.

a. **The PR.** `forge-api.sh "pulls?state=all"`: the one whose `head.ref` is the task branch. If
   merged: `merge_commit_sha`, `merged_at`. Reviewers' comments: `pulls/<n>/reviews`,
   `pulls/<n>/reviews/<id>/comments`, `issues/<n>/comments`. Leave out the author's own and the
   ones already handled by `/devflow:feedback` (in review.md).
b. **CI on the merge commit.** `forge-api.sh "actions/runs?head_sha=<merge_commit_sha>"`. Every
   run must be terminal. A run still going means wait (a short `Monitor` until-loop, not a sleep).
   Every non-`success` conclusion gets a cause from the run's jobs (`actions/runs/<id>/jobs`): the
   task's code, a flaky test, or infrastructure. A forge with no Actions (or none configured)
   returns no runs: say "no CI runs found", not "CI green".
c. **Rework.** `git fetch origin`. The task's files: `git diff --name-only <merge-base>
   <merge_commit_sha>^2` (or the branch tip). Then the commits on `origin/<base>` after
   `merged_at`, within 14 days, touching those files:
   `git log origin/<base> --since=<merged_at> --until=<merged_at + 14d> --format='%h %an %ad %s' -- <files>`.
   Read each diff. Count only commits that change what the task built: a fix, a missed case,
   a hardening, a doc that had become false. Someone else's unrelated feature in the same file is
   not rework. The author's own follow-up fix counts too.
d. **Production errors**, only when a Sentry MCP server is present (read-only, `inspect` only;
   `${CLAUDE_PLUGIN_ROOT}/reference/optional-tools.md`). Find the release that carried the merge
   commit. Take the issues first seen in it, or regressed in it, within 14 days of `merged_at`, whose
   stack frames are in the task's files from 2c. Each one that the task's code caused is a `prod`
   miss; one that only passes through those files is not. Record the issue link, the frame and the
   count, never event payloads. When Sentry is not present, say "production errors not checked: no
   Sentry server", and suggest it once if the project reports to Sentry.

If the task never merged, 2a still applies (comments on an open or closed PR); 2b to 2d do not.

## 3. Classify

For each item from 2a-2d that is a real miss, decide, as in the conventions: `--source` (feedback,
ci, rework, prod), `--missed-by` (the earliest stage whose job it was), `--class` (from
`<learning_dir>/classes.md`, or a new slug with a one-line description). Write the evidence as a
URL or `sha file:line`.

Be honest in both directions. A reviewer's preference is not a miss. A rework commit that fixes
what the spec did not ask for is a miss of `design` (the question was not asked), not "out of
scope".

## 4. Checkpoint, then record

Show the table: source, ref, missed-by, class, evidence, one-line note. Also show what you looked at
and left out, with a reason. After the user's ok (they may reclassify), record each row with
`ledger.sh add`, using the date of the comment, CI run or commit as `--date`, not today.

End with one line:

```
DEVFLOW MAINTENANCE: none
DEVFLOW MAINTENANCE: <class> -- <n> tasks now; run /devflow:learn
```

The second form appears when `ledger.sh stats` shows a class at 2+ tasks with no rule, or with
repeats after its rule. This skill does not change the plugin; `/devflow:learn` does, after a yes.

## The 💡 line at the checkpoint

The user is confirming which items count as devflow's misses. These become the evidence for future
rules, so a wrong row teaches the wrong lesson. What to check: the "missed-by" stage and the class
on each row. Reclassify where the agent blamed the wrong stage.
