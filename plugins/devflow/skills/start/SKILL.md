---
name: start
description: Start a devflow task from a pasted ticket text or a ticket id. Decides the route (quick, full or investigation), the approach and the domain (code or ML), writes ticket.md and state.md outside the repo, then stops for approval.
argument-hint: <ticket text, or an id like ABC-123 followed by optional notes>
disable-model-invocation: true
effort: high
---

# devflow: start

Read `${CLAUDE_PLUGIN_ROOT}/reference/conventions.md` first.

Input: $ARGUMENTS

## 1. Preconditions

Run `${CLAUDE_PLUGIN_ROOT}/scripts/repo-info.sh`. Stop with a clear message if:
- not a git repo;
- `clean` is false and the task will change code (list `git status --short` and ask the user to
  commit or stash; do not do it yourself). An investigation does not need a clean tree;
- the current branch already has `task_exists: true` (offer `/devflow:status` instead).

If `context_exists` is false, say once in the checkpoint that `/devflow:bootstrap` would give
later stages ADRs about this repo's structure. It is a suggestion, not a blocker.

## 2. The ticket

- If the input contains an id like `ABC-123` and Linear tools are available, fetch that issue
  (title, description, comments) and merge it with whatever the user pasted. The user's text wins
  where they disagree. If Linear has no such issue, carry on with the pasted text; most tickets
  are written by hand.
- Read the repo's CLAUDE.md / AGENTS.md / README and look around just enough to judge scope.
  Delegate wide searches to an Explore agent rather than reading many files yourself.
- Find the test command (and lint/typecheck if any) from CLAUDE.md, package.json scripts,
  Makefile, pyproject/tox, etc. If unsure, say so at the checkpoint, don't guess silently.

Classify:
- **type**: `feat` (new behaviour), `fix` (wrong behaviour), `chore` (no behaviour change),
  `investigation` (the deliverable is facts: a root cause, "why does X happen", "is this a bug",
  a comparison of options, an audit). Choose `investigation` whenever the ticket does not yet
  know what to change. A bug report whose cause is unknown is a `fix` only if the user wants it
  fixed in this task; when in doubt, ask at the checkpoint;
- **size**: S = one seam, a few files, no design questions; M = several slices or one real design
  decision; L = several decisions or cross-cutting. When in doubt pick the bigger one.
- **domain**: `ml` when the work is about models or data rather than application code: choosing or
  searching for a model or dataset, fine-tuning or training, evaluation, inference quality, or
  debugging training (loss, divergence, metrics, data). Otherwise `code`. Read
  `${CLAUDE_PLUGIN_ROOT}/reference/ml-practices.md` for an `ml` task before choosing the route.

### Route

Decide it yourself from what you read; the user confirms or overrides it at the checkpoint.

**quick** only when ALL of these hold:

1. The outcome is fully specified: you could write the acceptance check now, and no question is open.
2. One behaviour in one place, or no behaviour change at all (copy, docs, config value, rename,
   a dependency patch bump). Expected diff: about 3 files and 100 changed lines or fewer.
3. It touches none of: database schema or migrations; a public API, webhook or event contract;
   authentication, permissions, secrets or tokens; concurrency, limits, quotas, dedup or caching;
   CI, deployment or infrastructure; a new dependency or a major upgrade; an external system's
   behaviour the change relies on; for `ml`, any training run or a change of model or dataset.
4. Nothing in engineering-habits.md applies beyond "write a test".

**investigation** when nobody knows yet what to change (cause unknown, options to compare, "find
a model / dataset for X"). **full** for everything else. When unsure between quick and full, choose
full and say which criterion made you hesitate: a wrong quick costs a restart, a wrong full costs a
few extra checkpoints.

**Approach** goes with the route, and you state it at the checkpoint in one line:
- quick, behaviour change → a failing regression or behaviour test first, then the change;
- quick, no behaviour change → no new test; the existing suite must stay green;
- full → design (unless size S), then slices at agreed seams, test-first;
- investigation → read, query, report; no code;
- `ml` → as in ml-practices.md: baseline and evaluation set before any training, experiments as
  slices with a hypothesis and a metric.

Branch name: `<type>/<id-lowercase>-<slug>` or `<type>/<slug>` without an id; slug is 3–6 words,
kebab-case, English. For `investigation` the same form (`investigation/<slug>`) is only the task's
key under the tasks folder: no git branch is ever created for it.

## 3. Write

Run `repo-info.sh . <branch>` to get `task_dir` for the planned branch, create it, and write:

`ticket.md`
```
# <title>
Source: <pasted | Linear ID + url>
## Goal
## Acceptance criteria   (numbered, each one checkable)
## Out of scope
## Open questions        (numbered; omit if none)
## Original text         (verbatim input, for the Spec review later)
```

`state.md` per the conventions, with `stage: start`, `route`, `domain`, and `next`: `quick` for the
quick route; `design` for full (or `plan` for size S); `investigate` for an investigation (with
`size: -`). `branch` = planned name (not created yet), `base` from repo-info.

Do not create the branch here.

## 4. Checkpoint

Show the goal, acceptance criteria, open questions, the route with the one criterion that decided
it, the approach in one line, type/size/domain, branch name, base, test command. Ask the open
questions here (a quick route has none by definition). If the user's answers change the ticket or
the route, update `ticket.md` / `state.md` before they say go.

💡 This checkpoint decides the route and what "done" means. A route that is too small skips the
design questions the task needs, and vague criteria let anything count as done. Check that every
criterion is something you could verify yourself, and that the route fits.
