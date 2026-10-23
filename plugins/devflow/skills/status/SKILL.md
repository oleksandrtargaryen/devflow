---
name: status
description: Show where the current devflow task is and what comes next. Use when the user asks for devflow status, "where are we", "що далі".
---

# devflow: status

Run `${CLAUDE_PLUGIN_ROOT}/scripts/repo-info.sh`. If there is no task for this branch:
- if `pending_branch` is set, report that task (started and its branch not created yet, or an
  investigation, which has none; next is `/devflow:next`);
- otherwise list `<repo_tasks_dir>/**/state.md` (branches have slashes, so they nest; skip `_done/`) with their `branch`/`next`, newest first,
  and say that a new task begins with `/devflow:start <ticket>`. Then stop.

Otherwise report in 5–8 lines, reading only `state.md` (and `git log --oneline <base>..HEAD`):
- ticket title, type/size/domain, route, branch → base;
- last completed stage and next one;
- slices done / total;
- last verify result;
- review findings still open, if `review.md` exists;
- the compare URL once the branch is pushed.

Read-only: change nothing.
