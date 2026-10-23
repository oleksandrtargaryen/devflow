---
name: ship
description: devflow ship stage. Writes the PR description, pushes the task branch after explicit approval and prints the compare link. Invoked by /devflow:next.
user-invocable: false
effort: high
---

# devflow: ship

Read `${CLAUDE_PLUGIN_ROOT}/reference/conventions.md` first. Then `ticket.md`, `state.md`, and
`review.md` (full route) or the `## Self-review` section of `state.md` (quick route).

## 1. Gate

Refuse to continue, and say why, if any of these hold: the last Verify log entry is not green or
is older than the last commit; `review.md` has `Decision: pending`; the tree is dirty; you are not on
the task branch; `acceptance` is not `none` and `## Acceptance` has no `verified` entry at the
current sha (review fixes after verify need acceptance re-run for what they touched); any
`blocked` acceptance item has no decision about it in `## Decisions`.

On the quick route there is no `review.md`: require a `## Self-review` section in `state.md`
instead. Also, a "not verified" acceptance entry with its reason is enough there, as long as the PR
body states it.

## 2. pr.md

Invoke `mattpocock-skills:pr` and write `<task_dir>/pr.md` with that template:
- title: `<type>(<id>): <summary>` or `<type>: <summary>`;
- body: the template, plus "Closes <id>" when there is an id, the test evidence from the Verify
  log, the acceptance lists (verified / not verified / blocked, as they are; a "not verified" is
  stated, not hidden), and review fixes in one line each (quick route: the self-review lines). No
  "Generated with Claude Code" or co-author lines.

## 3. Checkpoint before push

Show the title and body, `git log --oneline origin/<base>..HEAD`, and say exactly what will run:
`git push -u origin <branch>`. Stop and wait for an explicit yes.

## 4. Push (after yes)

Push. If the remote branch exists and diverged, stop and explain; never force. Print
`compare_url` from `repo-info.sh` and the PR title/body ready to paste into the forge's
"new pull request" form. devflow does not open PRs itself: opening one is the user's act.

Set `stage: ship`, `next: done`. Checkpoint: the link, plus "paste reviewers' comments into
/devflow:feedback; run /devflow:next after the merge".

## The 💡 line at the checkpoint

Before the push, the user is approving exactly what leaves their machine: the branch, the commits
listed, and the PR text others will read. What to check: the commit list (nothing unexpected), and
that the PR body states what was not verified. After the push, the next step is the user's: open the
PR from the link.
