---
name: next
description: Run the next devflow stage for the current branch's task, exactly one, then stop. Use when the user says /devflow:next, "next", "ok, go on", "далі" during a devflow task.
---

# devflow: next

1. Run `${CLAUDE_PLUGIN_ROOT}/scripts/repo-info.sh`.
   - `task_exists: true` → read `<task_dir>/state.md`.
   - Otherwise, if `pending_branch` is set, the task was started but its branch is not created
     yet, or it is an investigation (which never gets a branch): read
     `<repo_tasks_dir>/<pending_branch>/state.md`.
   - Otherwise tell the user to run `/devflow:start` and stop.
2. Take the `next:` field and invoke that stage's skill with the Skill tool:
   `devflow:quick`, `devflow:design`, `devflow:investigate`, `devflow:plan`, `devflow:implement`,
   `devflow:verify`, `devflow:review`, `devflow:ship`, `devflow:done`. Invoke it as a skill rather than following its steps from
   memory: its frontmatter sets the effort level for the stage.
3. Do nothing else. The stage skill ends with its own checkpoint.
