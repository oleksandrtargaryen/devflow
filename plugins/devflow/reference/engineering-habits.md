# Engineering habits

A checklist that applies in every project: in design, in code, in review and before a PR. Each
item is phrased as something to check, not as advice. `/devflow:learn` adds to this file when a
class of miss keeps recurring.

## Reach before design
- The first question in a design or a grilling is reach: who uses it from day one (a few named
  people, or everyone in a group), from which organisations or installs, how many of them, and
  how the next one gets in. Then the operating cost: who does how much manual work for each new
  one. No design is written without the answer.
- The dev environment is a rehearsal of production. Production requirements (isolation,
  permissions, secrets) are checked on dev too, unless the user explicitly says otherwise. Mark
  each requirement or milestone separately for dev and for production.
- When a similar system already does something, treat it first as a requirement, then as an
  attack vector. Offer "do the same, but safely", not only "don't do it".
- Do not stretch a security rule beyond its threat. Name the threat, and check that the
  restriction cuts exactly that and nothing a product needs.

## External systems
- Every field or behaviour of someone else's system that a decision rests on (what a field means,
  which date a filter uses, who writes what, who decides) is either confirmed by its owner (who,
  when) or marked in the PR as a "Not verified" blocker, not a footnote.
- The quality of a rule is measured by both precision and recall. A hit rate with no false
  negatives counted is not proof.
- A filter by a time window: what happens to a record that arrives late or out of order. Either
  it is a silent loss, or it is a handled case.

## Trust boundaries and scopes
- Threat-model by trust boundary, not by environment. For every privilege (a token, root, a
  privileged container, a deploy key) write down which events and branches get it and what it can
  reach. Grant it to the one job that needs it. "It's only dev" is not an argument if unreviewed
  code can reach it.
- Tokens: read and write separate, read-only where reading is enough, a service account instead
  of a personal one.
- One invariant enforced in several places (dedup in two layers, a key in two tables): write the
  columns of each unique index side by side, check that their scopes match, and write a collision
  test along the dimension where they differ.

## Remembered "no"s
- For every remembered negative decision (skipped, rejected, a cache of refusals): is it a
  property of the input, or of the configuration at that moment? If of the configuration, a retry
  after it is fixed must go through again, and a test proves it: "fixed the setting, retried, got
  the result".

## Proof, not luck
- Races are reproduced deterministically (hold the first transaction open, a barrier), not with N
  parallel requests. A test that passed on timing proves nothing. See `testing-patterns.md`.
- Claims about data are checked by querying the data, not by reading the code.
- Demos and acceptance run on data in production's format, including the hard case, not on
  seeded values that are already normalised.
- CI and deployment changes are proven before merge, on a branch or a manual run. The meaning of
  every configuration key of a tool comes from its documentation, not from a failed run.
- Major dependency upgrades: run e2e locally before merge, not "CI will tell".

## The caller's contract
- Before handing over an API or a webhook, walk every response branch as the sender: status,
  machine code and body, including malformed JSON, an oversized body, missing fields. Not one
  generic error for a client mistake; not one declared code that never happens.
- Public documentation contains no internal references (secret names, ticket numbers, internal
  config). Traps for the caller belong in the specification, not the README.
- Check the requirements for where and in what format the documentation must live.

## A known risk is not parked
- Every "I know, but later", "that's a separate decision", "a separate task" becomes, before
  merge, either a fix in the same PR or an issue in the tracker with a link. A sentence in the PR
  description or the README is not an issue. A one-line fix is just made.
- Documented dangerous behaviour is a TODO, not a feature.
- Before a PR, go through your own "Not verified" notes and the agent's suggestions from the
  session: each one is closed or moved to an issue.

## Leftovers and process
- Whatever is kept "for rollback" (an old database, a service, a directory): check what it still
  does (scheduled jobs, writes, archiving), and give it an owner and a removal date.
- Your own documentation that the change made false is fixed in the same PR as the change. After
  someone else's changes in your area, re-read your READMEs.
- Working code does not live only on a local branch: deferred work is pushed as a draft or wip
  branch.
- A PR is not merged by its author without a requested review, unless the user explicitly says
  otherwise.
- Secrets (passwords, registration tokens, API tokens) are never pasted into the chat. If the user
  pastes one, remind them to rotate it at once, and never repeat the value.
