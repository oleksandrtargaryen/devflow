---
name: investigate
description: devflow investigate stage, for tasks of type investigation. Establishes facts, root cause and blast radius, writes report.md with every claim labelled verified, inference, assumption or not verified, and changes no code. Invoked by /devflow:next.
user-invocable: false
effort: xhigh
---

# devflow: investigate

Read `${CLAUDE_PLUGIN_ROOT}/reference/conventions.md` first. Then `ticket.md` and `state.md`.

The deliverable is facts, not code. Do not edit, create or delete anything in the repo, do not
create a branch, and do not "quickly fix" what you find. If the user wants it fixed, that becomes a
new task started from this report.

## 1. Read

Depth follows uncertainty, not task size. A five-line question about a critical path can need more
reading than a large addition to well-understood code.

1. Read the code the question is about. Quote `file:line` for every behaviour you rely on.
2. Read its neighbours: callers of the function, producers and consumers of the data, the tests
   that pin the current contract, the ADRs in `adr_dir` for the area.
3. Confirm the real shapes; do not infer them: DB schema and migration state (query the data when
   the claim is about data, do not grep code for it), request and response payloads, fixtures,
   log lines, live HTTP responses.
4. For an external system, the source is its owner, its documentation or a captured payload.
   Never memory. For a dependency, that is the documentation for the installed version
   (Context7 when present), and its installed source when the two disagree.
5. A bug seen in production starts from the error itself: the stack, the release it first
   appeared in, how often, since when. Read it from Sentry when it is present (read-only,
   `inspect` only), else ask the user for the stack trace or the event link. Copy frames, counts
   and the link into the report, never event payloads: they can carry personal data.
6. Outside facts (prior art, how others solved it, papers): WebSearch and WebFetch first; Exa
   when the results are thin, Firecrawl when a page will not render. A search result is a lead.
   The report cites the primary source.
7. Delegate wide sweeps to an Explore agent. You need its conclusions, not the file dumps.
   Subagents read; they do not edit.

The tools in 4-6 are optional (`${CLAUDE_PLUGIN_ROOT}/reference/optional-tools.md`). When one
would have changed the answer and is missing, suggest it once at the checkpoint.

**ML investigations** (`domain: ml`):
- "Find a model / dataset for X": search with `${CLAUDE_PLUGIN_ROOT}/scripts/ml/hf-search.sh` and
  build the shortlist as `${CLAUDE_PLUGIN_ROOT}/reference/ml-practices.md` section 3 says. Licences are checked first. Card claims go under "Not
  verified". Look at real rows of any dataset you recommend. Include at least one boring option.
- "Why does training diverge / why did the metric drop": work down section 6 in order and stop at the
  first thing that is wrong. Each step is checked on the actual run, data or config, not reasoned
  about.

## 2. Root cause and blast radius

- The symptom is not the root cause. Trace back through the layers until one explanation covers
  every observed symptom. If one does not, say which symptom is left unexplained.
- If the same cause sits behind several callers, say so: the fix is systemic, not local.
- Blast radius: the files, modules, consumers, tests, runtime states and environments (dev and
  prod separately) a change here would touch.

## 3. report.md

Write `<task_dir>/report.md`:

```
# <question>
Date: <YYYY-MM-DD>, at <repo>@<short sha of the base you read>
## Question            (restated in one sentence)
## Verified            (read from code, schema, data or a live run; each with its source)
## Inferences          (each with the verified facts it rests on)
## Assumptions         (taken without checking, and why they were not checked)
## Not verified        (each with the reason: no access, no data, no environment)
## Root cause          (or "not established", and what would establish it)
## Blast radius
## Proposed change     (the smallest correct one; options only if there is a real trade-off)
## Verification plan   (how a fix would be proven: tests, a query, browser acceptance)
```

Every claim sits in exactly one of the four evidence sections. An assumption written as a fact is
the one mistake this stage exists to prevent.

Set `stage: investigate`, `next: done`.

## 4. Checkpoint

The answer in 3-5 lines, the count per evidence section, and the most important "not verified"
item. Offer two ways on: `/devflow:next` archives the report, or `/devflow:start <ticket>` with a
link to report.md starts the fix as its own task.

## The 💡 line at the checkpoint

The user is deciding whether the answer is trustworthy enough to act on. An assumption that reads
like a fact leads to fixing the wrong thing. What to check: the "Not verified" and "Assumptions"
sections, not the conclusion. Name the one that matters most.
