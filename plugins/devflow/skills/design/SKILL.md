---
name: design
description: devflow design stage. Creates the task branch, grills the user on the open decisions, records lasting ones as ADRs and writes spec.md. Invoked by /devflow:next.
user-invocable: false
effort: xhigh
---

# devflow: design

Read `${CLAUDE_PLUGIN_ROOT}/reference/conventions.md` first. Then `ticket.md` and `state.md`.

## 1. Branch

Run `repo-info.sh`. Require a clean tree. Then:
`git fetch origin` → `git switch -c <branch> origin/<base>`.
If the branch already exists locally, switch to it and say so; do not recreate it.

## 2. Understand before asking

- Read the ADRs in `adr_dir` and GLOSSARY in `context_dir` for the area the ticket touches.
- Explore the code paths involved. Use an Explore agent for wide sweeps; you need conclusions,
  not file dumps. Finding facts is your job: never ask the user something the code can answer.

## 3. Grill

### 3a. Reach first (mandatory, before any design question)

These questions come from `${CLAUDE_PLUGIN_ROOT}/reference/engineering-habits.md` ("Reach before design"); read it. Reach also means scale across runtime units. If the feature has a limit, quota,
dedup or "one at a time" rule, ask whether it must hold across sessions, processes and replicas,
or only inside one.

Ask these first, as their own questions. Do not let a later answer stand in for one of them. Do
not write a design until each is answered or the user explicitly defers it, and record each
answer in `state.md` -> `## Decisions`:

1. **Who uses it on day one.** Is it a few named people or everyone in a group? Which
   organisations or installs do they come from, and how many?
2. **How the next one gets in.** When a new person, company or install arrives, what does
   someone have to do by hand, who does it, and how long does it take? If the design needs
   manual setup per user (binding an id, adding a row, editing env), state that cost
   explicitly. Do not leave it as a footnote or "a separate task".
3. **Which environments.** Does each requirement also hold on dev? The default is yes: dev is a
   rehearsal of prod. List the requirement items that apply to dev and to prod separately.
4. **What similar systems already do.** If a similar system (another repo, the old system, a
   reference implementation) already has a behaviour, offer "do the same, but safely" as an option before
   treating it only as an attack vector.

When a security rule shapes an option, name the exact threat it closes. Check that the
restriction cuts only that threat, not a product need next to it. An option the threat does not
require is not a security trade-off; present it as a product choice.

Every fact about an external system that a decision rests on must be one of two things:
confirmed by its owner (record who and when), or listed in spec.md under `## Unverified external
facts` as a blocker. Such facts include what a field means, which date a filter uses, and who
writes or decides what.

**ML tasks** (`domain: ml`): the ML reach questions in `${CLAUDE_PLUGIN_ROOT}/reference/ml-practices.md` section 2 come first, alongside the
ones above: the task, the metric and the bar, the baselines, the evaluation data and its frozen test
split, the licences, and the compute budget. Unanswered, they become rework after the first
expensive run.

### 3b. Open decisions

Invoke `mattpocock-skills:grilling` on the open decisions of this ticket: behaviour at the edges,
where the change belongs, what the public interface looks like, what is out of scope.
Use `mattpocock-skills:codebase-design` as the vocabulary when the question is where a seam or
module boundary goes. The session ends when the user confirms shared understanding.

While grilling, invoke `mattpocock-skills:domain-modeling` when a term needs sharpening or a
decision meets its ADR bar (hard to reverse, surprising, a real trade-off). Write the glossary
entry into `context_dir` and the ADR into `adr_dir` (see conventions), showing each to the user
before writing it.

## 4. spec.md

Write `<task_dir>/spec.md`:

```
# <title>
## Problem            (from the user's perspective)
## Reach              (who on day one, how the next one gets in and its manual cost, dev vs prod)
## Solution           (from the user's perspective)
## Behaviour          (numbered, testable statements; each maps to a ticket acceptance criterion)
## Seams              (the public interfaces tests will go through; prefer existing, as few as possible)
## Decisions          (link ADRs written in this stage)
## Unverified external facts  (each one a blocker until its owner confirms; "none" if none)
## ML                 (domain: ml only: metric and bar, baselines, eval data and frozen test split,
                      licences, compute budget and approver; ml-practices.md section 2)
## Out of scope
```

Update `ticket.md` if grilling changed the acceptance criteria. Record the user's decisions in
`state.md` → `## Decisions`. Set `stage: design`, `next: plan`.

## 5. Checkpoint

Summarise the spec in a few lines: the Reach answers, the seams, any ADRs written, and the
unverified external facts that remain.

## The 💡 line at the checkpoint

The user is confirming the spec: who it is for (Reach), the behaviour as testable statements, and
the seams. Everything after builds on this, so a wrong Reach answer means rework after merge. What
to check: the Reach answers and each "Unverified external fact". Each one is an assumption the code
will rest on.
