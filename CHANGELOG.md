# Changelog

## 0.3.2 - 2026-10-23

- `reference/engineering-habits.md` rewritten as a project-neutral checklist; examples in the
  design stage and the README made generic.

## 0.3.1 - 2026-10-23

- `reference/optional-tools.md`: Context7, Sentry MCP (read-only, `inspect` skill), Exa and
  Firecrawl, next to the ML tools moved from `ml-practices.md`. Each has the stages that use it, a
  fallback, and an install command checked against its documentation. Stages suggest a missing tool
  once per task.
- plan, implement and quick check a library API or configuration key new to the repo against the
  docs for the installed version (Context7 when present); the installed code wins a disagreement.
- investigate starts a production bug from its error (Sentry when present) and searches outside
  facts with WebSearch first, then Exa or Firecrawl.
- retro step 2d: production errors the task's code caused within 14 days of the merge, recorded
  with the new ledger source `prod`.
- A memory MCP server is deliberately not included; the README says why.

## 0.3.0 - 2026-10-23

- Routes: `start` picks quick, full or investigation from explicit criteria and states the deciding
  one. The new `quick` stage does branch, test-first change, checks, a real look, self-review and
  commit in one stop, and hands over to the full route (recorded as `route-too-small`) when the
  task turns out bigger.
- Every checkpoint ends with a 💡 sentence: what is being decided, why it matters, what to look at,
  in this task's terms.
- ML tasks (`domain: ml`): `reference/ml-practices.md`, which covers ML reach, model and dataset
  search, experiments, paid compute, training debugging and the eval report, each rule with its
  source. `scripts/ml/hf-search.sh` searches the Hugging Face Hub with licences, gating and size.
  `scripts/ml/leakage.py` checks train/test overlap (exact, normalised, 13-gram). There is a new
  `acceptance: eval`, an `experiments.md` log, and ML miss classes.
- The guard asks before launching paid cloud compute.
- Optional ML tools (HF MCP, HF skills, W&B MCP, AI-Research-SKILLs) are suggested, never required.

## 0.2.0 - 2026-10-23

First public release.

- Stages: start, design, plan, implement, verify, review, ship, feedback, done; status, bootstrap.
  One stage per `/devflow:next`, a checkpoint after each, state on disk outside the repo.
- `type: investigation`: `start → investigate → done`, an evidence-labelled report.md, no branch,
  no code.
- plan: scope classification with a checkable reclassification condition; an acceptance mode.
- verify: runtime acceptance, in the browser for UI or as the sender for APIs, reported as
  verified / not verified / blocked. ship refuses to continue without acceptance evidence at the
  current commit.
- `reference/testing-patterns.md`: deterministic tests for races, locks, crash windows and counts;
  plan must name a technique for every concurrency, dedup or limit slice.
- Mechanical checks on the branch's added lines (`scripts/run-checks.sh`), starting with
  `race-sleep`.
- Two failed attempts at one defect, then stop and re-investigate.
- Learning loop: `scripts/ledger.sh`, `reference/miss-classes.md`, `/devflow:retro` (CI on the
  merge commit, PR comments, rework after merge), `/devflow:learn` (recurring class → rule on a
  four-rung ladder, with an eval case).
- GitHub (through `gh`) and Gitea (through `GITEA_URL` / `GITEA_TOKEN`) for retro, through the
  read-only `scripts/forge-api.sh`.
- Git guard hook; `reference/engineering-habits.md`.
