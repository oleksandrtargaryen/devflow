# devflow

A Claude Code plugin that runs a coding or ML task from ticket to merged PR in stages, and stops
after every one of them for your go-ahead. It picks the route itself: a one-stage quick path for
small, fully specified changes, the full cycle for everything else, or an investigation when nobody
knows yet what to change. It keeps the task's state on disk, outside the repo, so
`/clear` or a new session never loses the thread. It checks its work outside the test suite too:
in the running app, or as a caller of your API. It also keeps a ledger of what it got wrong. When
the same kind of mistake shows up in two tasks, `/devflow:learn` proposes a rule that would have
caught it, with an eval that proves the rule works. Nothing changes until you say yes.

```
start → design → plan → implement ×N → verify → review → ship → [feedback] → done    (full)
start → quick → ship → [feedback] → done                                              (quick)
start → investigate → done                                                            (investigation)
                                                         done └ retro → ledger → learn
```

Every checkpoint ends with one 💡 sentence for people new to agents: what you are deciding right
now, why it matters, and the one thing to look at in this task.

devflow orchestrates [Matt Pocock's skills](https://github.com/mattpocock/skills) (grilling, TDD,
code review, domain modeling, PR writing) and adds the parts they leave open: state between stages,
scope classification, runtime acceptance, deterministic race tests, a git guard, and the learning
loop.

- [Why](#why)
- [Requirements](#requirements)
- [Install](#install)
- [Quick start](#quick-start)
- [Routes: quick, full, investigation](#routes-quick-full-investigation)
- [Stages](#stages)
- [Task files](#task-files)
- [Runtime acceptance](#runtime-acceptance)
- [Deterministic tests and mechanical checks](#deterministic-tests-and-mechanical-checks)
- [ML tasks](#ml-tasks)
- [Optional tools](#optional-tools)
- [Learning from misses](#learning-from-misses)
- [ADRs and glossary](#adrs-and-glossary)
- [Git guard](#git-guard)
- [Configuration](#configuration)
- [GitHub and Gitea](#github-and-gitea)
- [Engineering habits](#engineering-habits)
- [Using it in a team](#using-it-in-a-team)
- [Troubleshooting](#troubleshooting)
- [Developing devflow](#developing-devflow)
- [License](#license)

## Why

An agent left to run a whole task on its own tends to fail in the same few ways:

- it designs before it knows who the feature is for and how many of them there are;
- it writes the tests after the code, or tests that pass on timing;
- it reports "done" because the suite is green, without anyone opening the app;
- it fixes the same defect five times in a row instead of re-reading the code;
- it repeats last month's mistake, because nothing remembers last month.

devflow answers each one with a stage, a checkpoint or a record:

- a mandatory reach interview before any design;
- vertical TDD slices at agreed seams, with named techniques for races;
- runtime acceptance before review;
- a hard stop after two failed attempts at one defect;
- a ledger of misses that turns recurring ones into rules.

## Requirements

- Claude Code with plugin support (plugin dependencies are used to pull in Matt Pocock's skills).
- `git`, `jq`, `bash` (macOS's bash 3.2 is enough), `curl`.
- Optional:
  - the `gh` CLI, logged in: `retro` reads PR comments and CI runs on GitHub with it;
  - `GITEA_URL` and `GITEA_TOKEN` (a read-only token is enough): the same on Gitea;
  - the Claude in Chrome extension: runtime acceptance of UI changes;
  - a Linear connector: `start` fetches tickets by id (`ABC-123`) when one is available;
  - Context7, Sentry, Exa, Firecrawl and the ML tools: see [Optional tools](#optional-tools).
- Recommended model settings in `~/.claude/settings.json`: `"model": "claude-opus-5-5"` and
  `"effortLevel": "high"`. The thinking stages raise themselves to `xhigh` through their skill
  frontmatter.

## Install

```sh
claude plugin marketplace add mattpocock/skills
claude plugin marketplace add oleksandrtargaryen/devflow
claude plugin install devflow@devflow
```

`devflow` declares `mattpocock-skills@mattpocock` as a dependency, so the install pulls it in.
The `mattpocock` marketplace has to be known first, which is what the first line does.

If you also have the `superpowers` plugin, disable it while using devflow: its TDD and review rules
conflict with Matt's.

```sh
claude plugin disable superpowers@claude-plugins-official
```

Pin a release instead of following the default branch:

```sh
claude plugin marketplace add https://github.com/oleksandrtargaryen/devflow.git#v0.3.2
```

**Update.** Run `claude plugin marketplace update devflow`, then
`claude plugin update devflow@devflow`, and start a new session. Or turn on auto-update for the
marketplace in `/plugin` → Marketplaces. A new version arrives only when `version` in
`plugin.json` changes.

**Uninstall.** Run `claude plugin uninstall devflow@devflow`. Your tasks and ledger stay in
`~/.devflow`.

## Quick start

Inside a git repo with a clean tree:

```text
/devflow:start ABC-123 users can export their invoices as CSV
```

`start` reads the ticket (from Linear when it can, otherwise from what you typed), sizes it, and
proposes a branch name. It writes `ticket.md` and `state.md` under `~/.devflow/tasks/<repo>/<branch>/`,
then stops with its open questions. Answer them, then:

```text
/devflow:next
```

Each `/devflow:next` (or a plain "next", "ok, go on") runs exactly one stage and stops at a
checkpoint that tells you what it produced and what comes next. A medium task runs like this:

1. **design** creates the branch, asks who uses the feature and how the next user gets in, grills
   you on the open decisions, and writes `spec.md`. Decisions that are lasting become ADRs.
2. **plan** classifies the scope and splits it into vertical slices, each with a seam and a test.
   It also decides how the change will be seen working (`acceptance`). You confirm the seams.
3. **implement** runs once per slice: red, green, suite, commit, stop.
4. **verify** runs the full suite and the mechanical checks, maps every acceptance criterion to
   evidence, and exercises the change in the running app or as the API's caller.
5. **review** does a two-axis code review (standards, spec) plus a security review. You pick what
   to fix. Every finding you pick is recorded as a miss of the stage that should have caught it.
6. **ship** writes the PR description, shows exactly what it will push, pushes after your yes, and
   prints the compare link. You open the PR.
7. **feedback**: `/devflow:feedback <pasted comments>` triages reviewers' comments (valid,
   question, disagree, unclear), fixes the valid ones test-first, and drafts your replies.
8. **done**, after the merge, checks CI on the merge commit, collects misses through `retro`,
   offers ADRs, deletes the branch and archives the task.

`/devflow:status` says where you are at any time. `/clear` between stages freely: a SessionStart
hook puts the task's state back into the new context.

## Routes: quick, full, investigation

`start` reads the ticket and the code, then chooses a route and an approach, and says which
criterion decided it. You confirm or override at its checkpoint.

**quick** is chosen only when all of these hold:
- the outcome is fully specified, with no open question;
- it is one behaviour in one place, or no behaviour change at all (copy, docs, a config value, a
  rename, a patch bump), in about 3 files and 100 lines;
- it touches none of: schema, a public API or webhook contract, auth or secrets, concurrency or
  limits or caching, CI or deployment, new dependencies, external systems, training or a change of
  model or dataset.

The `quick` stage does everything in one stop:
- the branch;
- one failing test, then the change (or no new test for a change with no behaviour);
- the suite and the mechanical checks;
- one real look at the change if it is visible;
- a self-review against the ticket, the repo's rules and other callers of the same code;
- a commit.

Then `ship`. If the task turns out bigger (another layer, a question the ticket does not answer, a
second failed attempt, the same bug elsewhere), `quick` stops, writes down what it learned, and
hands over to the full route. That hand-over is also recorded as a miss of `start`
(`route-too-small`), so a start that keeps underestimating gets a rule.

**full** is the stage-by-stage cycle below. **investigation** is described under Stages.

## Stages

| Stage | What it does | Writes | Effort |
|---|---|---|---|
| `start` | reads the ticket; picks route, approach, type, size, domain; names the branch | `ticket.md`, `state.md` | high |
| `quick` | small change in one stage: branch, test-first change, checks, self-review, commit | code, tests | high |
| `design` | creates the branch; reach interview; grilling on open decisions; ADRs | `spec.md`, ADRs | xhigh |
| `investigate` | facts, root cause, blast radius; no code, no branch | `report.md` | xhigh |
| `plan` | classification, vertical slices at seams, race techniques, acceptance mode | `plan.md` | xhigh |
| `implement` | one slice test-first, commit, stop; two failed attempts → stop | code, tests | high |
| `verify` | suite, mechanical checks, criterion → evidence, runtime acceptance | state log | high |
| `review` | standards + spec review, security review, chosen fixes; records misses | `review.md` | xhigh |
| `ship` | PR text, push after yes, compare link; refuses without acceptance evidence | `pr.md` | high |
| `feedback` | triage of PR comments, fixes, reply drafts; records misses | `review.md` | high |
| `done` | merge check, retro, ADR offer, branch cleanup, archive | `_done/` | high |

**Types and sizes.** `start` sets the type and the size.

- Types:
  - `feat`: new behaviour;
  - `fix`: wrong behaviour;
  - `chore`: no behaviour change;
  - `investigation`: the deliverable is facts, not code.
- Sizes:
  - `S`: one seam, a few files. It skips `design`.
  - `M`: several slices, or one real decision.
  - `L`: several decisions, or a cross-cutting change.

**Investigations.** When a ticket does not yet know what to change ("why do some exports come out empty?"),
`start` makes it an investigation. Its path is `start → investigate → done`, with no branch and no
code. `report.md` separates what was verified (with `file:line` or the query that showed it), what
was inferred and from what, what was assumed, and what could not be verified and why. A fix is then
a new task started from the report.

**Scope classification.** `plan` writes one line at the top of `plan.md`:

```text
Classification: point fix, because <reason>. Reclassify if <checkable condition>.
```

The options are point fix, vertical slice, systemic fix and refactor. The condition is concrete
("becomes systemic if the IMAP path parses the sender the same way"). `implement` stops when it
sees the condition hold.

**Two failed attempts, then stop.** This applies in every stage that changes code. After the second
attempt at one defect that did not fix it, there is no third variant. The stage goes back to
reading:

- Was a basic assumption wrong?
- Is the fix in the wrong layer?
- Is the cause shared with other callers?
- Is stale state hiding the real behaviour (a cache, seed data, a server from another branch)?

It brings what it found to the checkpoint.

## Task files

Everything devflow writes about a task lives outside the repo, under
`$DEVFLOW_HOME/tasks/<repo>/<branch>/`:

| File | Content |
|---|---|
| `ticket.md` | goal, numbered acceptance criteria, out of scope, open questions, the original text |
| `spec.md` | problem, reach, solution, testable behaviour, seams, decisions, unverified external facts |
| `plan.md` | classification, agreed seams, slices (seam, test, files, criteria covered), acceptance list, risks |
| `state.md` | a `key: value` header plus the slice checklist, decisions, verify log, acceptance log |
| `review.md` | findings by axis with ids (S1, P1, X1), the user's decision, fix commits, misses |
| `pr.md` | the PR title and body |
| `report.md` | an investigation's evidence-labelled report |

`state.md` header keys:

```text
stage: <last completed stage>
next: <stage to run on /devflow:next>
type: feat | fix | chore | investigation
size: S | M | L | -
acceptance: ui | api | both | none
id: <ticket id or ->
branch: <branch>
base: <base branch>
test_cmd: <full test command>
lint_cmd: <lint/typecheck command or ->
updated: <YYYY-MM-DD>
```

Each stage updates `stage` and `next` as its very last action. An interrupted stage therefore
reruns rather than being skipped. Archived tasks move to
`$DEVFLOW_HOME/tasks/<repo>/_done/<date>-<branch>/`.

## Runtime acceptance

A green suite is not evidence that anyone sees the change working. `plan` decides how `verify` will
see it, and writes `acceptance:` into `state.md`:

- **`ui`**: `verify` starts the app with the `run` skill on this branch (and checks the server
  really serves this worktree). It then drives Chrome through the Claude in Chrome extension:
  - the primary flow;
  - the states the change touches (populated, empty, loading, error, no permission);
  - console errors and failed network requests;
  - one more consumer of any shared component the branch changed.
- **`api`**: `plan` lists every response branch; `verify` sends real requests to a local server
  as the caller would, branch by branch. The branches include the success path, a malformed body,
  an oversized body, missing fields, unknown values and missing or wrong auth. For each one it
  records the status, machine code and body next to the expected ones. Each of these is a finding:
  - a 5xx or `internal_error` for a client's mistake;
  - a declared code that cannot be produced;
  - a body that leaks internals.
- **`both`**, or **`none`**: `none` is for when nothing is observable outside the tests (a pure
  refactor); plan says why.

The result is three lists, never merged: **verified** (exercised, and what was seen), **not
verified** (and why), and **blocked** (and the exact blocker). `ship` refuses to continue if there
is no verified entry at the current commit. It also refuses if a blocked item has no recorded
decision.

## Deterministic tests and mechanical checks

`reference/testing-patterns.md` describes how to test what usually gets tested on luck:

- **Check-then-act in async code.** A fake at the `await` point holds the first caller inside the
  window, on an event. The second caller runs, then the gate opens.
- **A crash between two transactions.** Write the rows the crash would leave, gate a real
  transaction, or kill a child process on a marker.
- **Locks.** `FOR UPDATE NOWAIT` shows what a lock excludes, and `lock_timeout` proves what it
  must not block. Waiting goes through `pg_stat_activity`, never through sleep.
- **A race at an exact instant.** A trigger, or a held row lock.
- **Counts.** Prove a count is non-zero before asserting that it did not grow.
- **Late and out-of-order input** for any time-window filter.

`plan` requires every slice about concurrency, dedup, idempotency, limits, quotas or locks to name
its technique. `implement` requires its red run to come from the race itself.

Mechanical checks live in `scripts/checks/`. `verify` and `review` run them through
`scripts/run-checks.sh <base>`, and they judge only the lines the branch added, so old code never
counts against a branch. The first one, `race-sleep.sh`, flags timed sleeps and timers added to
concurrency tests. Zero sleeps (`asyncio.sleep(0)`) are a yield, not a wait, and are not flagged.
`/devflow:learn` adds new checks when a class of miss is visible in diffs.

## ML tasks

`start` marks a task `domain: ml` when it is about models or data rather than application code. The
cycle stays the same; what counts as evidence changes. For code, evidence is a test that went red
then green. For a model, it is a number on data the model never saw, next to a baseline,
reproducible by someone else. Every stage follows `reference/ml-practices.md`, where each rule links
its source (Karpathy's training recipe, Google's Tuning Playbook and ML Crash Course, the PyTorch,
transformers, PEFT and lm-evaluation-harness docs).

- **Design** asks the ML reach questions first: the metric and the bar that means "good enough",
  the baselines (a dumb one, the current system, an untrained off-the-shelf model), the evaluation
  data with a frozen test split, the licences, and the compute budget and its approver.
- **Finding a model or dataset** is an investigation. `scripts/ml/hf-search.sh` queries the Hugging
  Face Hub without a token and prints one line per repo: licence (`NONE` when the repo declares
  none, which means it cannot be used), gating, size, 30-day downloads, freshness. The report
  shortlists by licence first. It keeps card claims under "not verified" until they are reproduced
  on your data, looks at real dataset rows, and always includes one boring option.
- **Plan** splits the work into code slices (test-first: loading, preprocessing, shapes, the metric
  function) and experiment slices (a hypothesis, one change, seed, budget, a decision rule). The
  order is: look at the data, then the eval harness and baselines, then overfit one batch, then a
  small run, then the full run.
- **Implement** logs every run in `experiments.md`: config, seed, data revision, metric, cost,
  decision.
- **Debugging training** works down an ordered checklist: the data as the model sees it, the loss at
  initialisation, overfitting one batch, NaN and divergence causes, train/eval mismatch, config and
  version diffs.
- **Verify** writes an eval report:
  - the metric against the bar and the baselines, with spread over seeds;
  - the test split, evaluated once;
  - a reproducibility re-run;
  - an error analysis;
  - the cost;
  - a leakage check with `scripts/ml/leakage.py`: exact, normalised and 13-gram overlap between
    train and test (jsonl, json, csv, tsv or txt, pure Python).
- **Paid compute.** The guard hook asks before any launch of paid cloud compute (`hf jobs run`,
  `sky launch`, `modal run`, SageMaker, Azure ML). Before that question, the agent states the
  hardware, the timeout and the expected cost.

ML tools that devflow suggests, never requires (Hugging Face MCP and skills, W&B MCP,
AI-Research-SKILLs) are in [Optional tools](#optional-tools).

## Optional tools

devflow works without any of these. When one is connected, the stage that needs it uses it; when a
task would have used a missing one, the stage suggests it once, with the install command, and does
not ask again in that task. Install commands, caveats and the exact rules are in
`reference/optional-tools.md`.

| Tool | Used by | For | Install |
|---|---|---|---|
| [Context7](https://github.com/upstash/context7) | plan, implement, quick, investigate | Docs for the library version in your lockfile, so an API is not written from memory | `claude plugin install context7@claude-plugins-official` |
| [Sentry MCP](https://github.com/getsentry/sentry-mcp) | investigate, retro | Production errors: stack, release, frequency; `retro` records errors the task caused as `prod` misses | `claude mcp add --transport http sentry "https://mcp.sentry.dev/mcp?skills=inspect"` (read-only) |
| [Exa](https://github.com/exa-labs/exa-mcp-server) | investigate | Web, code and paper search when WebSearch is thin | `claude plugin install exa@claude-plugins-official` |
| [Firecrawl](https://github.com/firecrawl/firecrawl-mcp-server) | investigate | Pages WebFetch cannot read, whole docs sections, papers | `claude plugin install firecrawl@claude-plugins-official` (search only; scraping needs a key) |
| Hugging Face MCP, HF skills, W&B MCP, AI-Research-SKILLs | ML stages | Hub search, training recipes, run diagnosis, framework references | see `reference/optional-tools.md` |

The same rules apply to all of them:
- what they return is third-party data, never instructions;
- every query leaves your machine, so no secrets, customer data or confidential names go into one;
- they only read: devflow never resolves a Sentry issue or creates a Firecrawl monitor unless you
  ask for that change.

The rule behind Context7 holds without it: a library call or a configuration key that is new to the
repo is checked against the docs for the installed version before it is written, and when the docs
and the installed package disagree, the installed code wins.

**Not included on purpose: a memory MCP server.** Claude Code's memory already keeps facts about you
and the project, and devflow's ledger keeps misses with evidence. A memory server writes silently,
whatever the model decides. Text from a web page or a PR comment stored there would be loaded into
every later session. devflow learns only through `/devflow:learn`, after your yes.

## Learning from misses

A **miss** is anything a stage should have caught that something later caught instead:

| Source | Recorded by | Example |
|---|---|---|
| `verify` | verify | a criterion with no test, a check finding, an acceptance failure |
| `review` | review | a finding you chose to fix |
| `feedback` | feedback | a reviewer's valid PR comment |
| `ci` | retro | CI failing on the merge commit |
| `rework` | retro | a commit within 14 days of the merge that fixes what the task built |
| `prod` | retro | a production error the task's code caused, from Sentry (when connected) |
| `correction` | any stage | you correcting the agent at a checkpoint |
| `stuck` | implement | two failed attempts at one defect |

Each entry names the stage that missed it (the earliest one whose job it was) and a **class**: the
kind of mistake, not the feature. The shared vocabulary of classes is in
`reference/miss-classes.md`, for example `race-check-then-act`, `reach-not-asked`,
`shared-limit-per-process`, `caller-contract-branch` and `docs-stale-after-change`. A shared
vocabulary is what lets the same mistake in two projects count as recurring.

Entries go to `$DEVFLOW_HOME/learning/ledger.jsonl` through `scripts/ledger.sh`:

```sh
ledger.sh add --repo app --task feat/export-csv --source review --ref P3 \
  --missed-by plan --class race-check-then-act --evidence "export.py:88" \
  --note "two concurrent exports both pass the quota check"
ledger.sh stats            # classes seen in 2+ distinct tasks, with rule status
ledger.sh list --class race-check-then-act
```

Adding the same (repo, task, source, ref) twice is a no-op, so collection is safe to rerun.

**`/devflow:retro [branch]`** looks back at a shipped task. It reads reviewers' PR comments and CI
runs on the merge commit, the commits that reworked the task's code in the two weeks after
merge, and, when a Sentry MCP server is connected, the production errors the task's code caused in
that time. It shows the table of misses it found and records them after your ok. `done` runs it. Run
it again two weeks after a merge, because rework keeps arriving.

**`/devflow:learn [class]`** picks a class seen in two or more tasks (one vivid case does not earn a
rule). It reads every entry and proposes the smallest rule that would have caught all of them. It
estimates the rule's precision and recall on those tasks. Rules climb a ladder, one rung each time
a class repeats after its rule:

1. a sentence in the skill of the stage that missed it, written as a check, not a wish;
2. a question that stage must answer at its checkpoint;
3. a script in `scripts/checks/`, run by verify and review on the branch's added lines;
4. a hook that stops the mistake before it is made.

Each rule comes with an eval case in `plugins/devflow/evals/<class>/`, run with
`claude plugin eval`. The case must fail on the plugin without the rule and pass with it. If it
passes without the rule, the eval does not reproduce the miss, and the case is fixed, not the
threshold. On your yes, `learn` does the following in the plugin's source (never the installed
cache):

- creates a `learn/<class>` branch;
- runs every test script;
- bumps the patch version;
- adds a CHANGELOG line;
- commits.

It pushes only on a second yes.

**`/devflow:learn --backfill`** seeds the ledger once from the `review.md` files of tasks that ran
before the ledger existed. It shows counts per class and ten random rows for you to spot-check
before it writes anything.

What is shared and what stays local:

- **Your ledger stays local.** It names your repos and tasks.
- **Only rules travel.** They reach others as a PR to the plugin repo and a new version, with
  counts and no names in the CHANGELOG.

## ADRs and glossary

devflow follows the team:

- **The repo has `docs/adr/`.** New ADRs go there, with the team's numbering (highest on
  `origin/<base>` plus one), template, language and statuses from its README. Each is committed on
  the task branch as its own `docs(adr):` commit and ships with the PR.
- **It does not.** ADRs and `GLOSSARY.md` stay private in `$DEVFLOW_HOME/context/<repo>/`, and
  nothing about them touches the repo.

`/devflow:bootstrap` runs once per repo. It drafts the ADRs (where things live, and the
architectural decisions visible in the code) and the glossary that review later holds code
against.

## Git guard

A PreToolUse hook (`scripts/guard-git.sh`) checks every Bash command:

- **Denied:**
  - push to `main`, `master`, `dev` or the task's base;
  - force push (`--force-with-lease` is allowed), `push --all/--mirror`, `+refspec`;
  - a commit on a protected branch;
  - `Co-Authored-By: Claude` or "Generated with Claude Code" in a commit message.
- **Asks first:** `reset --hard`, `clean -f`, `checkout/restore .`, `branch -D`, `rebase`,
  `push --delete`, and any launch of paid cloud compute (HF Jobs, SkyPilot, Modal, SageMaker, Azure
  ML). Reading job status or logs is not asked about.

If the guard blocks something, the stage stops and tells you rather than working around it. Extra
protected branches go in `DEVFLOW_PROTECTED`.

## Configuration

All optional. Set them in your shell, or in the `env` block of `~/.claude/settings.json`.

| Variable | Default | Meaning |
|---|---|---|
| `DEVFLOW_HOME` | `~/.devflow` | root of everything devflow writes |
| `DEVFLOW_TASKS_DIR` | `$DEVFLOW_HOME/tasks` | task folders |
| `DEVFLOW_CONTEXT_DIR` | `$DEVFLOW_HOME/context` | private ADRs and glossaries per repo |
| `DEVFLOW_LEARNING_DIR` | `$DEVFLOW_HOME/learning` | ledger, recorded rules, local classes |
| `DEVFLOW_BASE` | `dev` if `origin/dev` exists, else the remote's default branch | base branch |
| `DEVFLOW_PROTECTED` | (none) | extra protected branches, space-separated |
| `DEVFLOW_PLUGIN_SRC` | a directory marketplace holding `plugins/devflow`, else asks | the plugin's git clone, for `/devflow:learn` |
| `GITEA_URL`, `GITEA_TOKEN` | (none) | read PRs and CI on a Gitea host |

The ledger lives outside the plugin's cache, which every update replaces. It also lives outside
the plugin data directory, which uninstall deletes: it is accumulated evidence.

## GitHub and Gitea

`scripts/repo-info.sh` detects the forge from the `origin` remote:

- **GitHub** (`github.com`): read through the `gh` CLI.
- **Gitea**: when `GITEA_URL` points at the remote's host, read with `GITEA_TOKEN`.
- **Anything else** is `unknown`. Everything works except reading PR comments and CI in `retro` and
  `done`, which then say plainly that they were not checked.

All forge access goes through `scripts/forge-api.sh`. It is read-only and never prints a token.
devflow never opens, comments on, or merges a PR. `ship` prints the compare link and the PR text,
and opening the PR is your act.

## Engineering habits

`reference/engineering-habits.md` holds the engineering rules every stage checks against:

- reach before design;
- external facts confirmed by their owners;
- trust boundaries;
- remembered "no"s that must be retried after a configuration fix;
- proof instead of luck;
- the caller's contract;
- known risks that are fixed or ticketed, never parked;
- leftovers with an owner and a removal date.

`design`, `plan`, `review` and `ship` check against them explicitly. To have them in sessions
outside devflow too, import the file from your `~/.claude/CLAUDE.md` (use the path of your clone):

```text
@~/src/devflow/plugins/devflow/reference/engineering-habits.md
```

## Using it in a team

- Everyone installs the plugin as above. Pin a tag if you want the whole team on one version.
- Optionally, commit a `.claude/settings.json` to the team repo:

  ```json
  {
    "extraKnownMarketplaces": {
      "devflow": { "source": { "source": "github", "repo": "oleksandrtargaryen/devflow" } },
      "mattpocock": { "source": { "source": "github", "repo": "mattpocock/skills" } }
    },
    "enabledPlugins": { "devflow@devflow": true, "mattpocock-skills@mattpocock": true }
  }
  ```

  A teammate who trusts the folder is offered the marketplaces. Each person still runs the
  `claude plugin install` lines once.
- Rules learned by one person reach everyone as a PR to this repo: review it like code.

## Troubleshooting

- **`/devflow:next` says there is no task.** The current branch has no `state.md`, and no task is
  waiting for its branch. Check `/devflow:status`, or `ls $DEVFLOW_HOME/tasks/<repo>/`. If you used
  a custom root before, set `DEVFLOW_HOME` to it.
- **devflow fails to load after install.** The `mattpocock` marketplace was not added before
  `claude plugin install`. Add it and install again.
- **`retro` says CI and PR comments were not checked.** The forge is unknown: set `GITEA_URL` and
  `GITEA_TOKEN` for Gitea, or run `gh auth login` for GitHub.
- **The guard blocked a command.** That is its job. Do the step yourself if you mean it (for
  example `! git push origin main` from the prompt), or add a feature branch.
- **A check flags correct code.** Say so at the verify checkpoint. It is recorded as a
  `check-false-positive`, and `/devflow:learn` narrows the check.

## Developing devflow

```sh
git clone https://github.com/oleksandrtargaryen/devflow && cd devflow
claude plugin marketplace add "$PWD"       # a directory marketplace loads your edits in place
for t in plugins/devflow/scripts/test-*.sh; do "$t" >/dev/null || echo "FAILED: $t"; done   # needs python3 for test-ml
claude plugin validate plugins/devflow
claude plugin eval plugins/devflow --case '<glob>' --runs 3 --max-cost-usd 2   # real model calls
```

Layout:

```text
.claude-plugin/marketplace.json        the marketplace (one plugin)
plugins/devflow/
  .claude-plugin/plugin.json           version, dependencies
  skills/<stage>/SKILL.md              one skill per stage and command
  reference/                           conventions, engineering habits, testing patterns, ML practices, miss classes
  scripts/                             repo-info, ledger, forge-api, guard, checks, and their tests
  scripts/ml/                          hf-search.sh (Hub search), leakage.py (train/test overlap)
  hooks/hooks.json                     PreToolUse guard, SessionStart context
  evals/<class>/                       eval cases added by /devflow:learn
```

Conventions for changes:

- Scripts must run on macOS's bash 3.2 and BSD awk: no associative arrays, no `IGNORECASE`, no
  `\b`.
- Every script has a `test-*.sh` next to it that builds a throwaway repo.
- Skills are written for an agent: concrete checks, not wishes.
- Bump `version` in `plugin.json` for every change others should receive, and add a line to
  `CHANGELOG.md`.

## License

Apache License 2.0, see [LICENSE](LICENSE). devflow depends on, but does not include,
[mattpocock/skills](https://github.com/mattpocock/skills), which is distributed under its own
license.
