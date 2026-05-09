# Mission (vision-classification, CIFAR-10)

You are an autonomous research agent. Maximize **`val_acc`** (top-1 accuracy on the held-out CIFAR-10 test set) by iteratively editing **only** `tinker/train.py`.

- Wall-clock budget per experiment: 5 minutes (`TINKER_BUDGET_SECONDS=300`).
- Overall wall-clock budget: 8 hours (`TINKER_OVERALL_BUDGET_HOURS=8`).
- Project slug: `<slug>`.
- Domain: `vision-classification`. Metric direction: `max` (higher is better).

# Hard rules

1. **You may freely edit `tinker/train.py`** (CNN architecture, augmentation, optimizer, LR schedule, init, dropout, batch size, ...).
2. **You MUST NOT touch** `tinker/prepare.py`, `tinker/data/raw/`, `tinker/data/train.pt`, `tinker/data/val.pt`. Modifying any of these is **data leakage**.
3. **No pretrained models or pretrained weights from the internet.** No `timm`, no `torchvision.models.<X>(pretrained=True)`. Train from scratch.
4. **No accessing the validation tensors during training.** They are read only by `evaluate()`.
5. **Each iteration**: run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/tinker_run.sh <slug> --domain vision-classification`.
6. **`tinker/train.py` must always end by writing `tinker/result.json`** with `primary_metric`, `metric_name="val_acc"`, `direction="max"`, `wall_time_s`, `n_iters`, `diverged`, `domain="vision-classification"`.

# Per-iteration workflow

1. Read `tinker/RESULTS.md` to see history. Beat the current `BEST.json`.
2. Decide on **one** focused change to `tinker/train.py`. Examples:
   - Architecture: `n_filters`, `depth`, `fc_hidden`, dropout, batch norm
   - Augmentation: random crop / horizontal flip / cutout / mixup
   - Optimization: SGD vs AdamW, momentum, weight_decay, warmup, schedule shape
   - Init / activation: Kaiming init, GELU vs ReLU
3. Run: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/tinker_run.sh <slug> --domain vision-classification`
4. Read `tinker/result.json`. If `diverged=true` or `primary_metric` is null, revert to the previous best in `tinker/history/`.
5. The runner already updates `RESULTS.md`, `BEST.json`, and snapshots `history/iter_<N>.py`. Add a `notes:` line summarizing the change.

# Strategy hints (you can refine)

- **Strong baselines**: a 3-block VGG-like CNN with BatchNorm and AdamW reaches ~70% in 5 minutes on a mid GPU. Beating that is real progress.
- **Augmentation is high-leverage**: random crop + flip gives you several points for free; cutout/mixup can give a few more.
- **Don't go too deep too fast**: with 32×32 inputs, depth=4 means 2×2 spatial — beyond that you're at 1×1.
- **Weight decay**: AdamW with `wd=5e-4` is a strong default for CIFAR.
- **Verify big jumps**: a +3 pp accuracy improvement deserves a 2nd run with `seed+1`.
- **Compute budget**: a CNN at 32×32 is fast — 5 minutes can yield 10-50k steps depending on size.

# Strategy anti-patterns (don't do this)

- Pretraining on a different dataset and "warm-starting".
- Using `torchvision.models.resnet18(pretrained=True)`.
- Test-time augmentation (TTA) — that uses val data for inference, blurring the comparison.
- Cherry-picking a lucky seed without verification.
- Editing `prepare.py` to "clean" the dataset.

# Logging

The runner appends to:
- `tinker/RESULTS.md` (human-readable table; you may add notes)
- `.research/<slug>/06_RUNS/<run_id>/events.jsonl` (`event=tinker.iteration`, schema in `tests/schemas/events.schema.json`)

You should not need to write logs yourself.

# Stop conditions

Stop when **any** of:

- 8 hours of wall-clock have elapsed.
- 30 consecutive iterations without improvement.
- 10 consecutive iterations with `diverged=true` (probably exploding loss or bad architecture).

Append a one-paragraph summary to `tinker/RESULTS.md` when stopping.

# How to start

1. Read `tinker/train.py` to understand the baseline (3-block CNN with BatchNorm, basic flip+crop aug).
2. Run a baseline iteration: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/tinker_run.sh <slug> --domain vision-classification`
3. Inspect `tinker/result.json`. This becomes iteration 0.
4. Begin the loop above.

Good luck. Keep diffs reviewable.
