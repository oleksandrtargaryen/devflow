---
name: done
description: devflow done stage. After the PR is merged, confirms the merge, checks CI on the merge commit and collects misses through retro, offers an ADR for lasting decisions, cleans up the branch and archives the task. For an investigation, archives the report. Invoked by /devflow:next.
user-invocable: false
effort: high
---

# devflow: done

Read `${CLAUDE_PLUGIN_ROOT}/reference/conventions.md` first. Then `state.md`.

**Investigation** (`type: investigation`): there is no branch and no merge. Show the report's
question and answer in two lines. If the report proposes a change, offer `/devflow:start` for it,
with a link to `report.md`. After a yes to archiving, move the task folder as in step 4, then stop.

For every other type:

1. `git fetch origin --prune`. The task is merged if `git merge-base --is-ancestor <branch> origin/<base>`
   succeeds, or (squash merges) the PR's changes are in `origin/<base>`, which you can tell by
   `git diff <branch> origin/<base> -- <files the branch touched>` showing nothing of the branch's.
   Not merged → say so and stop; change nothing.
2. Invoke `devflow:retro` for this task: CI on the merge commit (wait until terminal, classify every
   non-success), reviewers' PR comments, and rework so far. It records misses only after the user's
   ok. Rework keeps arriving for two weeks after a merge, so tell the user they can run
   `/devflow:retro <branch>` again later. It works on archived tasks too.
3. Look back over `## Decisions` and `review.md`: if something meets the ADR bar and has no ADR yet,
   offer it (`mattpocock-skills:domain-modeling`, written to `adr_dir`; in-repo ADRs need their own branch and PR now that the task is merged).
4. Checkpoint: list exactly what will happen, then after yes:
   `git switch <base> && git pull --ff-only`, `git branch -d <branch>` (lowercase -d: refuses if
   unmerged; if it refuses after a squash merge, ask before -D), and move the task folder to
   `<repo_tasks_dir>/_done/<YYYY-MM-DD>-<branch with / as ->`.
5. Final lines: what was archived where, the CI result on the merge commit, and the
   `DEVFLOW MAINTENANCE:` line from retro.

## The 💡 line at the checkpoint

The user is confirming cleanup after a merge: the branch is deleted and the task is archived.
Nothing can be lost, because the work is in the base branch. What to check: that the merge is really
there, and the retro table of what devflow missed, which is what it will learn from.
