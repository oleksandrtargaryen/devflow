---
name: feedback
description: Address PR review comments pasted by the user on a devflow task branch, each checked on its merits, fixed test-first and pushed after approval.
argument-hint: <review comments pasted from the PR>
disable-model-invocation: true
effort: high
---

# devflow: feedback

Read `${CLAUDE_PLUGIN_ROOT}/reference/conventions.md` first. Then `ticket.md`, `spec.md`,
`state.md`, and the ADRs for the area. Check you are on the task branch; `git pull --ff-only` if
the remote moved.

Comments: $ARGUMENTS

1. Number the comments R1…Rn. For each, check it against the code, the spec and the ADRs, and
   classify: **valid** (fix), **question** (answer, no code), **disagree** (explain why, with
   evidence; a reviewer can be wrong), **unclear** (ask). No performative agreement.
2. Append a `## PR feedback <date>` section to `review.md` with that table. Checkpoint: the table,
   and which ones you will fix. Wait for the user's ok.
   After the ok, each **valid** comment is a miss of devflow's own review and of the stage before it:
   record it with `ledger.sh add --source feedback --ref R<n> --missed-by <earliest stage whose job
   it was> --class <class> --evidence "<file:line>" --note "<comment in one line>"`, the same way
   review records its findings. A reviewer catching what devflow's review passed is the strongest
   signal the ledger gets.
3. After ok: fix each valid one (behaviour → test-first via `mattpocock-skills:tdd`), one commit
   each (`fix(review): R2 …`), run the full suite, log it. If a fix changes a lasting decision,
   offer an ADR update via `mattpocock-skills:domain-modeling`.
4. Checkpoint before push: commits + test result + `git push` (no force). Push after yes.
   Then give the user the short reply text for each comment, ready to paste into the PR.

`stage: feedback`, `next: done`.

## The 💡 line at the checkpoint

The user is deciding how to answer each reviewer comment. "disagree" means the agent thinks the
reviewer is wrong, with its evidence. What to check: every "disagree" and "question" row before
anything is fixed or sent.
