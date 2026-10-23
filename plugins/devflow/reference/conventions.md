# devflow conventions

Every devflow stage skill follows these. Read once per session, together with
`${CLAUDE_PLUGIN_ROOT}/reference/engineering-habits.md` (the engineering rules every stage holds
work to; `design`, `plan`, `review` and `ship` check against them explicitly).

## The cycle

`start` reads the task and picks one of three routes; the user confirms it at start's checkpoint.

- **full**: `start → design → plan → implement (once per slice) → verify → review → ship → [feedback]* → done`
- **quick**: `start → quick → ship → [feedback]* → done`, for small, fully specified changes
  (criteria in `devflow:start`). `quick` does branch, test-first change, checks and a self-review in
  one stage. If the task turns out bigger than the criteria allow, `quick` stops and hands it over to
  the full route; that is a normal outcome, not a failure.
- **investigation**: `start → investigate → done`, see below.

- `start` writes the ticket. `design` creates the branch as its first step (stopping right after a
  branch is created would be a stop with nothing to approve).
- Size S skips `design`: `start` sets `next: plan`.
- `type: investigation` is a different path: `start → investigate → done`. No branch, no code;
  the deliverable is `report.md`. Implementation, if wanted, is a new task started from it.
- Exactly one stage per invocation. A stage ends with a **checkpoint** and the user's go-ahead is
  `/devflow:next` (or an explicit "ok/go/далі" in chat, which you treat as `/devflow:next`).
- Never start the following stage on your own, even when it looks trivial.

## Where things are

Run `${CLAUDE_PLUGIN_ROOT}/scripts/repo-info.sh [dir] [branch]` and use its JSON; never re-derive
the base branch, the forge URLs or the task folder by hand.

| What | Where |
|---|---|
| Task artifacts | `task_dir`: `ticket.md spec.md plan.md state.md review.md pr.md report.md experiments.md` |
| ADRs | `adr_dir`: `NNNN-slug.md` |
| Glossary | `context_dir/GLOSSARY.md` |
| Code and tests | the repo |

ADRs follow the team. When the repo already keeps `docs/adr/` (`adr_in_repo: true`), `adr_dir` is
that folder: new ADRs go there with the team's numbering (highest number on `origin/<base>` plus
one, after `git fetch`), template, language and statuses from its README, plus a row in the
README's table; the ADR is committed on the task branch as its own `docs(adr):` commit and ships
with the PR. ADRs in `context_dir/adr/` of such a repo are older private notes with their own
numbering: read them, add nothing there. When the repo has no `docs/adr/`, `adr_dir` is
`context_dir/adr/` and nothing about ADRs touches the repo.

Matt Pocock's skills say `docs/adr/` and `GLOSSARY.md` at the repo root: pass `adr_dir` and
`context_dir/GLOSSARY.md` explicitly whenever you invoke one of them. Apart from ADRs in
`adr_dir`, nothing devflow writes (spec, plan, review) goes into the repo, not even into
gitignored folders.

## state.md

A `key: value` header (scripts read it with sed, so one key per line, no quotes), then free sections.

```
stage: <last completed stage>
next: <stage to run on /devflow:next>
type: feat | fix | chore | investigation
route: quick | full | investigation
domain: code | ml   (ml: see reference/ml-practices.md)
size: S | M | L
acceptance: ui | api | both | eval | none   (set by plan; absent before it)
id: <ticket id or ->
branch: <branch>
base: <base branch from repo-info>
test_cmd: <full test command>
lint_cmd: <lint/typecheck command or ->
updated: <YYYY-MM-DD>

## Slices
- [ ] 1. <slice> (seam: <public interface under test>)

## Decisions
- <date> <stage>: <what the user decided at a checkpoint>

## Verify log
- <date> <command>: <pass/fail, counts>

## Acceptance
- <date> <sha> verified: <what was exercised, how, where>
- <date> <sha> not verified: <what, why>
- <date> <sha> blocked: <what, the exact blocker>
```

Update `stage`, `next`, `updated` as the very last action before the checkpoint, so an interrupted
stage reruns rather than being skipped.

## Checkpoint format

End every stage with exactly this, in the user's language:

```
✅ <stage> done
<2–5 lines: what was produced, with paths>
💡 <one sentence: what you are deciding here, why it matters, what exactly to look at>
⚠️ <anything the user must decide or look at; omit if none>
➡️ Next: <next stage> — /devflow:next
```

Then stop. No further tool calls.

The 💡 line is for someone who has not worked with agents much. One plain sentence, no jargon left
unexplained: name the decision at this checkpoint, the cost of getting it wrong, and the one thing
to check, *in this task* (name the actual seam, file, endpoint or finding, not a generic
category). Each stage's skill says what its checkpoint decides; turn that into the sentence. Never
skip it, and never pad it into a paragraph.

## Two failed attempts, then stop

Applies in every stage that changes code (`implement`, review fixes, `feedback`). Count attempts
per defect. After the second attempt that did not fix it, do not try a third variant. Stop and go
back to reading: was a basic assumption wrong? Is this the wrong layer? Is a contract or invariant
being broken that you have not read? Is the cause shared by other callers (a systemic fix, not a
point fix)? Is stale state hiding the real behaviour (build cache, seed data, a server process from
another branch, browser storage)? Invoke `mattpocock-skills:diagnosing-bugs`, and bring what you
found to the checkpoint. Record it in the ledger as `--source stuck`.

## Learning from misses

devflow keeps a ledger of its own misses: things a stage should have caught that a later stage, a
reviewer or the user caught instead. `/devflow:learn` turns a class of miss that recurs across
tasks into a rule. Stages never edit the plugin themselves.

Record a miss with `${CLAUDE_PLUGIN_ROOT}/scripts/ledger.sh add --repo <repo> --task <branch>
--source <s> --ref <id> --missed-by <stage> --class <slug> --evidence "<file:line or sha>"
--note "<one line>"`:

- `--source`: `verify` (a gap verify found), `review` (a finding the user chose to fix),
  `feedback` (a valid PR comment),
  `rework` (someone else changed the code after merge), `ci` (CI failed on the merge commit),
  `prod` (an error in production caused by the task's code, found by retro through Sentry),
  `correction` (the user corrected you at a checkpoint), `stuck` (two failed attempts).
- `--missed-by`: the earliest stage whose job it was to catch it. A race that review found was
  missed by `plan` (no test named it) when the plan had no concurrency slice. It was missed by
  `implement` when the plan named the test and the code still raced.
- `--class`: reuse a slug from `${CLAUDE_PLUGIN_ROOT}/reference/miss-classes.md` (shared) or
  `<learning_dir>/classes.md` (yours, not yet promoted) when one fits. Read both first. Add a new
  one to the local file, with a one-line description, only when none fits. The class names the
  kind of mistake (`race-check-then-act`, `docs-stale-after-change`), not the feature.

When the user corrects you at a checkpoint ("no, not like that", a decision you got wrong),
record it as `correction` right then, quoting the user, before continuing.

## Git

- Commits: conventional (`feat:`, `fix:`, `test:`, `refactor:`, `chore:`), ticket id in the body
  when there is one. No attribution of any kind: no `Co-Authored-By:` trailer, no
  "Generated with Claude Code" line, in commits or in PR text. The guard hook rejects them.
- Commit only on the task branch; push only the task branch. The guard hook enforces this;
  if it blocks something, stop and tell the user rather than working around it.

## Model effort

Thinking stages (`design`, `plan`, `review`, `bootstrap`) run at `effort: xhigh`, the rest at
`high`. This is set in each skill's frontmatter; do not change effort yourself.
