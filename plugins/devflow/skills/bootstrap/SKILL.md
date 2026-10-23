---
name: bootstrap
description: Once per repo, create the local ADRs and GLOSSARY that later devflow stages and reviews rely on to know where things belong. Writes to $DEVFLOW_HOME/context/<repo>/ (default ~/.devflow), never into the repo.
disable-model-invocation: true
effort: xhigh
---

# devflow: bootstrap

Read `${CLAUDE_PLUGIN_ROOT}/reference/conventions.md` first. Run `repo-info.sh` for `context_dir`.
If `context_dir/adr/` already has ADRs, list them and offer to add or revise instead of starting over.
If `adr_in_repo` is true, the team already keeps ADRs in the repo: list those, write no ADRs here
(new ones follow the conventions and go into `adr_dir` through a task), and bootstrap only the
GLOSSARY.

Invoke `mattpocock-skills:domain-modeling` for the ADR format and its bar, with every path
redirected into `context_dir`.

## 1. Learn the repo

Read CLAUDE.md / AGENTS.md / README and the top two levels of the tree; dispatch Explore agents
(in parallel) for: entry points and layering, how tests are organised and run, where config lives,
external services and data stores. You want the *why* behind the layout, not an inventory.

## 2. Draft

- `adr/0001-project-layout.md`: what lives where and why; where new code of each kind goes; what
  must not depend on what. This is the ADR reviews will hold code against, so make each rule
  concrete enough to judge a diff by ("CLIs print JSON to stdout and one `ERROR:` line": yes;
  "code is clean": no).
- One ADR per architectural decision visible in the code that meets the bar (hard to reverse,
  surprising, a real trade-off), with the evidence (paths). Mark ones you inferred rather than
  saw documented as `Status: proposed`.
- `GLOSSARY.md`: the domain terms the code and docs use, one line each, flagging synonyms the
  code uses for the same thing.

Do not restate what CLAUDE.md already says; reference it.

## 3. Confirm

Show the list of drafts with one-line summaries, then each ADR in full. Write only what the user
approves. Checkpoint: files written, and which `proposed` ADRs need the user's confirmation later.

## The 💡 line at the checkpoint

The user is approving the ADRs that review will later hold code against. A wrong ADR makes review
flag correct code. What to check: every ADR marked "proposed". Those are inferred from the code, not
documented anywhere.
