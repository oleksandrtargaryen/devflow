# ML practices

Read by every stage when `state.md` says `domain: ml`: choosing or searching for models and
datasets, fine-tuning or training, evaluation, inference quality, debugging training. The cycle
is the same as for code. What changes is what counts as evidence. For code it is a test that went
red then green. For a model it is a number on data the model never saw, next to a baseline,
reproducible by someone else.

Each rule cites its source. Where a rule is devflow's own, it says so.

## 1. What changes per stage

| Stage | For `domain: ml` |
|---|---|
| start | Route: anything that trains, or changes a model or dataset, is never quick. "Find a model / dataset for X" and "why does training diverge" are investigations. |
| design | ML reach (section 2) before any other question; spec.md gets an `## ML` section. |
| investigate | Model/dataset search (section 3) or training debugging (section 6). |
| plan | Two kinds of slices, code and experiment (section 4); `acceptance: eval`. |
| implement | Code slices test-first; experiment slices run and log (section 4); paid compute gate (section 5). |
| verify | The eval report (section 7) and `scripts/ml/leakage.py`. |
| review | Standards include this file; a metric without a baseline, or measured on leaked data, is a hard finding. |

## 2. ML reach (design)

Ask these before any design question, and record the answers in spec.md under `## ML`:

1. **The task and its users.** What goes in, what must come out, who consumes it, and at what
   volume and latency.
2. **The metric and the bar.** One primary metric that matches the user's cost of errors (for
   imbalanced classes, not accuracy). Then the threshold that means "good enough to ship". Without
   a bar, no result can be called done.
3. **Baselines.** A dumb one: the majority class, or a rule. The current system, if there is one.
   An off-the-shelf model with no training. "Build dumb baselines" and compare everything to them
   ([Karpathy](https://karpathy.github.io/2019/04/25/recipe/); start with a simple baseline and
   improve incrementally,
   [Tuning Playbook](https://github.com/google-research/tuning_playbook)).
4. **The evaluation data.** Where it comes from, its size, who labelled it. Three splits:
   train / validation / test. The test split is used once, at the end. "The more often you use the
   same test set, the more likely the model closely fits the test set"
   ([ML Crash Course](https://developers.google.com/machine-learning/crash-course/overfitting/dividing-datasets)).
   Freeze it: record its revision, or a hash of the file.
5. **Data and model licences.** Every dataset and base model has a licence that allows this use.
   No declared licence means it cannot be used until its owner says so
   ([HF: licenses](https://huggingface.co/docs/hub/repositories-licenses)). Customer or personal
   data needs its owner's consent to leave its system, and that includes uploads to a hub or a
   cloud job.
6. **Compute budget.** Hardware, maximum wall time, maximum money, and who approves a run. Where
   the model will run, and the memory and latency it must fit.

## 3. Searching for models and datasets (investigate)

Use `${CLAUDE_PLUGIN_ROOT}/scripts/ml/hf-search.sh models|datasets "<query>" --filter <tag> ...`.
It needs no token, prints one JSON line per repo, and marks a missing licence as `NONE`. Useful
filters:
- a task: `text-classification`, `automatic-speech-recognition`;
- a library: `peft`, `gguf`;
- a licence: `license:apache-2.0`;
- a language: `uk`;
- a dataset size: `size_categories:10K<n<100K`.

Filters are ANDed. `downloads_30d` counts the last 30 days only.

The API's traps:
- An unknown filter returns no results and no error, so zero results is not proof that nothing
  exists. Retry with fewer filters.
- `library=` is ignored silently; use `--filter <library>` instead.

The shortlist in report.md is a table: id, licence, gated, parameters or size, downloads_30d, last
modified, and what the card claims. Then:

- Drop `NONE` and incompatible licences first, and say how many were dropped.
- Card claims (benchmarks, languages, quality) are **not verified** until reproduced on this
  task's evaluation set. Write them in the "Not verified" section, not as facts.
- Look at actual data before recommending a dataset: the first rows through
  `https://datasets-server.huggingface.co/first-rows?dataset=<id>&config=<c>&split=<s>`.
  The configs and splits come from `/splits?dataset=<id>`.
- Include at least one boring option: the smallest model that might do, or a non-ML baseline.
- Papers and prior art for the task: WebSearch, or Exa or Firecrawl's paper search when present
  (section 8). An abstract's claim is not verified until reproduced, like a card's.
- Before recommending a model that has to run somewhere, estimate whether it fits: parameters ×
  bytes per parameter for the weights, plus activations.

## 4. Experiments (plan, implement)

Two kinds of slices:

- **Code slices**, test-first like any code. Data loading and preprocessing are deterministic. The
  collate function produces the shapes the model expects. The metric function returns the
  hand-computed value on a three-example case. These bugs silently poison every experiment after
  them.
- **Experiment slices**. Each one has:
  - a hypothesis ("LoRA r=16 on all linear layers beats the frozen baseline by 3 F1 points");
  - exactly one change against the previous run;
  - the config, seed, budget (steps or epochs, wall time, money), expected result, and a decision
    rule ("keep if F1 improves by at least 1 point on validation").

  There is no red/green. The evidence is the logged run.

Order the slices like this, each step cheap before the next is expensive
([Karpathy](https://karpathy.github.io/2019/04/25/recipe/)):

1. Look at the data. Visualise a batch exactly as it enters the model.
2. The evaluation harness and the baseline numbers.
3. Check the loss at initialisation, and overfit a single batch. If the model cannot memorise a
   handful of examples, nothing larger will work.
4. A small run, then the full run.

Add complexity one change at a time.

Every run is logged in `<task_dir>/experiments.md`, one row per run:

```text
| id | slice | hypothesis | change | config (path@sha) | seed | data rev | budget | val metric | cost | decision |
```

Untracked experiments "might as well not exist"
([Tuning Playbook](https://github.com/google-research/tuning_playbook)).

Reproducibility:
- Set `seed` and `data_seed`.
- Record the library versions and the git sha.
- Use the dataset's revision.
- Set `report_to` and a `run_name`
  ([transformers Trainer](https://huggingface.co/docs/transformers/main/en/main_classes/trainer)).

Seeds are not enough across PyTorch versions or platforms; that is why versions are recorded
([PyTorch randomness](https://docs.pytorch.org/docs/stable/notes/randomness.html)). Commit code
and configs. Weights and data go to their own storage, never into git.

Tuning uses the validation split only. The test split is evaluated once, after tuning ends.

LoRA claims "performance comparable to full fine-tuning". Verify that against the baseline on this
task rather than assuming it
([PEFT LoRA](https://huggingface.co/docs/peft/main/en/developer_guides/lora)).

## 5. Paid compute and tokens

- The guard hook asks before any launch of paid cloud compute (`hf jobs run`, `sky launch`, `modal
  run`, SageMaker, Azure ML and others). Before asking, state the hardware, the timeout, the
  expected duration and the expected cost.
- Always set a timeout, and cancel runs that are no longer needed. HF Jobs bill per minute while
  starting or running, with a default timeout of 30 minutes
  ([HF Jobs pricing](https://huggingface.co/docs/hub/jobs-pricing)).
- Validate the pipeline on CPU or a tiny subset before the first GPU run.
- Tokens:
  - read-only by default;
  - a write token only for the job that pushes a model or dataset, and never printed;
  - private data never goes to a public repo.

## 6. Debugging training (investigate, implement)

Work down this list and stop at the first thing that is wrong. Each item is checked, not assumed.

1. **Data.**
   - Visualise a batch right before the model: tokens decoded back to text, images, labels.
   - Check that labels are aligned with inputs.
   - Check padding, truncation and `max_length`: in TRL it is `max_length`, not `max_seq_length`.
   - Check the class balance.
2. **Loss at initialisation.** For classification it should be close to ln(number of classes).
   Far off means a bug in the labels, the loss or the initialisation
   ([Karpathy](https://karpathy.github.io/2019/04/25/recipe/)).
3. **Overfit one batch.** If the loss does not go to near zero on a few examples, the model, the
   loss or the optimiser is wired wrong.
4. **NaN or divergence.**
   - Learning rate too high, or warmup too short.
   - fp16 overflow: try bf16.
   - Missing gradient clipping.
   - A bad sample: log the ids of the batch where it happened.
   - Division by zero in a masked loss.
5. **Train is good, eval is bad.**
   - Preprocessing differs between train and eval.
   - The model was left in train mode.
   - Generation settings differ.
   - Leakage in the other direction: validation that is easier than the real data.
6. **A regression after a change.** Diff the configs and the versions of the two runs before
   reading any code.

Training-run diagnosis tools, when the team already uses them: the W&B MCP server has
`diagnose_run_tool` and `compare_runs_tool`; use it in read-only mode (see section 8).

## 7. Evaluation and the eval report (verify, `acceptance: eval`)

`verify` writes `## Eval report` in state.md:

- The model (id and revision), and the data (id, revision, split, size).
- The primary metric with its spread: standard deviation over at least 3 seeds when runs are cheap
  enough; otherwise say there was one seed.
- The baseline numbers on the same split.
- **Leakage**: `python3 -I ${CLAUDE_PLUGIN_ROOT}/scripts/ml/leakage.py --train <train> --test
  <test> [--field ...]`. Exact, normalised and 13-gram overlap
  ([lm-eval decontamination](https://github.com/EleutherAI/lm-evaluation-harness/blob/main/docs/decontamination.md)).
  Leaked test examples are removed, or the metric is reported both with and without them.
- The test split is evaluated once, after tuning, and the report says so.
- Reproducibility: a second evaluation of the same checkpoint gives the same number within a
  stated tolerance.
- Error analysis: at least 10 failures looked at by hand, grouped into kinds.
- The cost of all runs, from experiments.md.

The bar from spec.md is either met or not. "Close" is not met.

## 8. Optional tools

Hugging Face MCP and skills, the W&B MCP server and AI-Research-SKILLs are described, with install
commands and caveats, in `${CLAUDE_PLUGIN_ROOT}/reference/optional-tools.md` ("ML tools"). Paper
search goes through Exa or Firecrawl there. devflow requires none of them.
