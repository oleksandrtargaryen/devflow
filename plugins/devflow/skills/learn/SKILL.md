---
name: learn
description: Turn devflow's recurring misses into rules. Reads the learning ledger, finds classes of miss seen in two or more tasks (or repeating after a rule), and proposes the smallest rule that would have caught every one, with an eval case, as a change to the plugin's source. Applies it only after the user says yes. Use with --backfill once to seed the ledger from past review.md files.
argument-hint: [--backfill] [class]
disable-model-invocation: true
effort: xhigh
---

# devflow: learn

Read `${CLAUDE_PLUGIN_ROOT}/reference/conventions.md` ("Learning from misses") and
`${CLAUDE_PLUGIN_ROOT}/reference/miss-classes.md` first. Invoke
`mattpocock-skills:writing-for-agents`: every rule you draft is text for an agent.

Input: $ARGUMENTS

devflow does not rewrite itself. This skill proposes; the user decides; a rule changes the plugin
only through a commit in its source repo, and reaches others only through a reviewed PR and a new
version.

## 0. Where the plugin's source is

Never edit `${CLAUDE_PLUGIN_ROOT}` (the installed cache, replaced on every update) or anything under
`~/.claude/plugins/`. The source is, in order: `$DEVFLOW_PLUGIN_SRC`; a `directory` marketplace in
`~/.claude/plugins/known_marketplaces.json` whose folder holds `plugins/devflow/`; otherwise ask
the user for the path to their git clone of the marketplace repo. It must be a git work tree with a
clean status.

## 1. Backfill (only with --backfill)

Seeds the ledger from tasks that ran before the ledger existed. Find every `review.md` under the
tasks root (`repo-info.sh` → `repo_tasks_dir`, one level up, all repos, including `_done/`). Only
findings marked fixed count (a declined finding is not a miss). Dispatch one Explore agent per task
in parallel. Give each the task folder, the class table, and the `missed_by` rule from the
conventions. Each returns rows `{repo, task, ref, missed_by, class, evidence, note, date}` with
`date` from the review header. Second reviews (`# Review 2`) also yield `missed_by: review` rows.

Then show the result before writing anything: the count per class and per stage, and 10 random rows
for the user to spot-check. After the ok, record each with `ledger.sh add --source review ... --date`.
Reruns are safe: existing (repo, task, source, ref) entries are skipped.

The rules in `reference/engineering-habits.md` already exist. For each class one of them covers,
record that rule once, dated by the commit that added the habit (`git log --diff-filter=A
--format=%as -S '<habit text>' -- plugins/devflow/reference/engineering-habits.md` in the plugin
source, or the file's first commit): `ledger.sh rule --class <c> --where
reference/engineering-habits.md --rung 1 --date <that date>`. Then any miss after that date counts
as the habit not holding.

## 2. Candidates

`ledger.sh stats` (classes in 2+ distinct tasks). A candidate is a class with no rule, or with
`repeats_after_rule > 0`. Without a class argument, list the candidates ranked by tasks and
repeats, and let the user pick. A class seen in one task only is not a candidate, however vivid the
case: one novel edge case does not earn a rule.

## 3. Draft the rule

For the chosen class, read every ledger entry (`ledger.sh list --class <c>`) and its evidence. Read
the current text of the stage named most in `missed_by`, and any rule already recorded for the
class.

Choose the rung:

1. **Skill text**: a sentence in the stage that missed it, written as a check the stage performs
   ("every counter shared between sessions gets a slice with a named technique"), not a wish
   ("be careful with concurrency").
2. **Checkpoint question**: the stage must ask or answer it at its checkpoint, so the user sees it
   every time.
3. **Check script**: `scripts/checks/<class>.sh`, the same interface as `race-sleep.sh` (base ref
   in; `path:line<TAB>class<TAB>text` out; exit 0/1/2; only added lines, via `lib-diff.sh`), with
   cases in `scripts/test-checks.sh`. Use it when the miss is visible in the diff.
4. **Hook**: a PreToolUse or Stop check, when the mistake can be stopped before it is made.

Start at the lowest rung that would have caught every recorded entry. A class with repeats after
its rule goes one rung up from that rule. Text that did not hold is not made louder. Measure the
draft both ways: would it have fired on each recorded entry (recall)? Would it fire on the
correct code in those tasks (precision)? Say both.

Also draft an **eval case** `evals/<class>/` in the plugin: `prompt.md` gives the stage the minimal
input that produced the miss. Make it self-contained and anonymised: no customer data, no internal
URLs, no secrets. The case has `max_turns` and `allowed_tools` frontmatter, plus `graders/` that
check the rule's observable effect. Prefer `regex`, `tool_used` and `file_exists` graders; `llm`
only when no computed grader can tell. Format: https://code.claude.com/docs/en/plugin-evals.md.

## 4. Checkpoint

Show: the class, its entries (count, tasks, stages), the rung and why, the exact edit (file, old
text, new text), the check script and its test cases if rung 3, the eval case, the precision and
recall estimate, and the cost of the eval run (each run is real model calls on the user's account).
Stop for a yes.

## 5. Apply (after yes)

In the plugin source:

1. `git switch -c learn/<class>` from its main integration branch.
2. Make the edit; add the check script and its tests, and the eval case.
3. Run every `plugins/devflow/scripts/test-*.sh`. All must pass.
4. Run the eval, after the user agrees to the cost: `claude plugin eval plugins/devflow --case
   <class> --runs 3 --max-cost-usd <agreed>`, on this branch, and on the parent commit with only the
   eval case added (a `git worktree` of the parent with `evals/<class>/` copied in). The rule is
   accepted when the case fails without it and passes with it. If it passes without the rule, the
   eval does not reproduce the miss: fix the case, not the threshold.
5. Bump the patch version in `plugins/devflow/.claude-plugin/plugin.json`. Add a line to
   `CHANGELOG.md`: version, class, rung, where, and how many tasks it is drawn from (counts only,
   no repo or task names).
6. Commit: `feat(learn): <class> -> rung <n> in <where>`.
7. `ledger.sh rule --class <class> --where <file> --rung <n>`.
8. A new class used here moves from `<learning_dir>/classes.md` into
   `reference/miss-classes.md` in the same commit.

Push and opening a PR happen only on a separate, explicit yes. The guard hook blocks pushing to
protected branches. After the merge: `claude plugin marketplace update <marketplace>`, and start a
new session.

End with one line: what changed, at which rung, and the eval result (before, then after).

## The 💡 line at the checkpoint

The user is deciding whether a new rule enters the plugin and changes how every future task runs.
What to check: whether the rule would really have caught the recorded cases (recall), whether it
would fire on correct code (precision), and the cost of running the eval before agreeing to it.
