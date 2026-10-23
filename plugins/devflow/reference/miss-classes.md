# Classes of miss

The shared vocabulary for `ledger.sh --class`. One slug names one kind of mistake, not a feature or
a repo, so the same mistake in two projects lands in the same class and counts as recurring.
Reuse a slug here before inventing one. A new slug goes into `<learning_dir>/classes.md` first;
`/devflow:learn` promotes it here once it earns a rule.

| class | the mistake | usually missed by |
|---|---|---|
| `route-too-small` | the quick route was chosen for a task that needed design, slices or review | start |
| `reach-not-asked` | who uses it, how many, from where, across how many sessions/processes/tenants was not established, so the design fits one case | design |
| `shared-limit-per-process` | a limit, quota, dedup or lock that only holds inside one process, session or replica, while the requirement is global | design |
| `race-check-then-act` | a check and the write that depends on it sit on either side of an await or a transaction boundary | plan |
| `side-effect-not-undone` | a refusal or failure path leaves a slot, reservation, row or message behind | plan |
| `test-timing-not-structure` | a race or concurrency test that relies on sleep, timers or N parallel calls | implement |
| `test-vacuous-count` | an assertion that holds for free (a count that is always zero, a filter that matches nothing) | implement |
| `caller-contract-branch` | a client mistake answered with 5xx or `internal_error`, a declared code that never happens, an undocumented trap for the sender | plan |
| `leak-internal-detail` | provider errors, SQL, stack traces or internal identifiers reach a client, a room or an audit row | implement |
| `input-normalization` | real-world input (Unicode apostrophes, NFD, case, whitespace, placeholders like "User") rejected or accepted wrongly | plan |
| `late-or-out-of-order-input` | a time-window or sequence filter that silently drops a late or reordered record | design |
| `external-fact-unverified` | a decision rests on what an external system does, unconfirmed by its owner | design |
| `dev-prod-divergence` | a requirement checked on prod only, or dev granted what prod would not | design |
| `trust-boundary-privilege` | a privilege (token, role, privileged container, deploy key) reaches events or code that should not have it | design |
| `stored-no-not-retried` | a remembered refusal or skip that was a property of configuration, and never re-tried after the configuration is fixed | design |
| `docs-stale-after-change` | the change made the repo's own docs, README or comments false, and they were not updated in the same PR | implement |
| `adr-not-updated` | the change contradicts or extends an ADR without a new or amended ADR | design |
| `spec-deviation` | the code does something different from what spec.md says, and neither was changed to match | implement |
| `duplicated-instead-of-shared` | a second copy of a concept (helper, client, rule) instead of using or extracting the existing one | implement |
| `glossary-drift` | names in code or docs that the glossary avoids, or one concept under two names | implement |
| `risk-parked` | a known risk left as "later" or "separate task" without a fix or a tracker issue | review |
| `ml-no-baseline` | a model result reported or acted on without a baseline on the same split | plan |
| `ml-eval-leakage` | evaluation data overlaps training data, or the test split was used for tuning | verify |
| `ml-unreproducible` | a run that cannot be repeated: seed, versions, data revision or config not recorded | implement |
| `ml-license-unchecked` | a model or dataset used without a licence that allows it, or private data sent to a third party | design |
| `ml-compute-unbudgeted` | a paid run started without an agreed hardware, timeout and cost, or left running | plan |
| `check-false-positive` | a mechanical check flagged correct code; the check needs narrowing | verify |
