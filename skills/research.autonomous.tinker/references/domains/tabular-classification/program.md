# Mission (tabular-classification, breast_cancer)

You are an autonomous research agent. Maximize **`val_acc`** on the held-out breast_cancer validation split by iteratively editing **only** `tinker/train.py`.

- Wall-clock budget per experiment: 5 minutes (`TINKER_BUDGET_SECONDS=300`).
- Overall wall-clock budget: 8 hours.
- Project slug: `<slug>`.
- Domain: `tabular-classification`. Metric direction: `max`.
- Note: this is a **small** dataset (569 samples). Strong baselines reach 95%+; gains above 97% are noisy.

# Hard rules

1. **You may freely edit `tinker/train.py`** (architecture, optimizer, schedule, regularization, ensembling, data augmentation, ...).
2. **You MUST NOT touch** `tinker/prepare.py` or `tinker/data/`. Train/val split is fixed at SPLIT_SEED=12345 with stratification — modifying it is data leakage.
3. **No AutoML / TabPFN / sklearn pretrained models.** Train from scratch.
4. **No reading `val.npz` during training** (loaders only access `train.npz`).
5. **Each iteration**: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/tinker_run.sh <slug> --domain tabular-classification`.
6. **Always write `tinker/result.json`** with `primary_metric`, `metric_name="val_acc"`, `direction="max"`, etc.

# Per-iteration workflow

1. Read `tinker/RESULTS.md`. Beat best.
2. Decide one focused change. Examples:
   - Architecture: hidden 64 → 128, depth 2 → 3, activation relu ↔ gelu, dropout
   - Optimizer: SGD vs AdamW, weight_decay, warmup
   - Regularization: label smoothing, mixup-for-tabular (linear blend), early stopping by val
   - Ensembling: train K models with different seeds, average logits
3. Run, parse, revert/keep.

# Strategy hints

- **Tabular is data-constrained, not compute-constrained.** You'll burn through 1k+ steps in 5 minutes. Watch for overfitting (train loss << val acc).
- **Weight decay is your friend.** Try wd ∈ {1e-3, 1e-2, 1e-1}.
- **Wide-and-shallow tends to beat deep on small tabular.** hidden=128, depth=2 often outperforms depth=4.
- **Verify** improvements by running with `seed+1`. On 114 val samples, 1 sample = ~0.9 pp.
- **Diminishing returns above ~97%.** Don't chase noise; report variance honestly.

# Strategy anti-patterns

- Importing `tabpfn` or other foundation tabular models.
- Running `sklearn.linear_model.LogisticRegression` and shipping its accuracy. (You may use it for comparison, but the result.json must come from your own torch model.)
- Editing `prepare.py` to "balance" classes or drop "outliers".
- Using val labels at training time, even via "self-distillation".

# Logging

The runner appends to:
- `tinker/RESULTS.md`
- `06_RUNS/<run_id>/events.jsonl`

# Stop conditions

Stop when **any** of:

- 8 hours elapsed.
- 30 consecutive iterations without improvement.
- 10 consecutive iterations with `diverged=true`.
- val_acc plateaus near 0.97 with high variance run-to-run (further gains are likely overfitting noise).

# How to start

1. Read `tinker/train.py` (basic 2-layer MLP).
2. Run baseline: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/tinker_run.sh <slug> --domain tabular-classification`
3. Inspect `result.json`. Begin the loop.

Good luck. Keep diffs reviewable.
