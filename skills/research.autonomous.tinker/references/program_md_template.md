# Mission

You are an autonomous research agent. Minimize **`val_bpb`** (validation bits per byte) on the held-out validation set in `tinker/data/val.bin` by iteratively editing **only** `tinker/train.py`.

- Wall-clock budget per experiment: **5 minutes** (`TINKER_BUDGET_SECONDS=300`).
- Overall wall-clock budget: 8 hours (`TINKER_OVERALL_BUDGET_HOURS=8`) unless overridden.
- Project slug: `<slug>` (auto-injected by skill scaffold).

# Hard rules

1. **You may freely edit `tinker/train.py`** (model, optimizer, LR schedule, batch size, init, dropout, attention impl, etc.).
2. **You MUST NOT touch** `tinker/prepare.py`, `tinker/data/`, or `tinker/data/val.bin`. Modifying any of these is **data leakage** and invalidates results.
3. **No external pretrained models or pretrained tokenizers from the internet.** Stay self-contained.
4. **No accessing the validation tokens during training** (they are loaded only by `eval_val_bpb`).
5. **Each iteration**: run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/tinker_run.sh <slug>`. Do not call `python train.py` directly — the wrapper enforces timeout and logs to `events.jsonl`.
6. **`tinker/train.py` must always end by writing `tinker/result.json`** with at least `{"val_bpb", "wall_time_s", "n_iters", "diverged"}`. The runner depends on this contract.

# Per-iteration workflow

1. Read `tinker/RESULTS.md` to see history. The current `BEST.json` is what to beat.
2. Decide on **one** focused change to `tinker/train.py`. Examples:
   - Architecture: depth, n_heads, d_model, mlp_ratio, attention variant
   - Optimization: lr, betas, weight_decay, warmup_iters, schedule
   - Batch: device_batch_size, grad_accum_steps, seq_len
   - Init: std, scale by depth, residual scaling
3. Run: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/tinker_run.sh <slug>`
4. Read `tinker/result.json`. If `diverged=true` or `val_bpb` is null, the change failed — **revert to the previous best** by copying `tinker/history/iter_<best_N>.py` over `tinker/train.py`.
5. If `val_bpb` improved: the runner has already updated `BEST.json` and saved a snapshot to `tinker/history/iter_<N>.py`. Move on to the next idea.
6. Append one row to `tinker/RESULTS.md` (the runner does this automatically; you may add a `notes:` column entry describing what you tried).

# Strategy hints (you can refine)

- **Hill-climb cheaply.** Change one thing at a time so cause and effect are clear.
- **Verify big jumps.** When you find a +0.05 bpb improvement, re-run the same `train.py` with `seed = seed + 1` (edit the Config) to confirm it isn't variance.
- **Don't overfit the schedule to the budget.** Cosine LR with warmup is robust. Don't pre-compute a perfect schedule for exactly N steps — you don't know N up front.
- **Watch the wall-clock fraction.** If `wall_time_s` is much less than 300, you may be doing too few steps; consider larger batch or smaller arch.
- **Avoid pathologies.** NaN/Inf loss → reduce LR or add grad clipping. OOM → smaller batch or seq_len.

# Strategy anti-patterns (don't do this)

- Cherry-picking a lucky seed without verification.
- Reading val tokens into the optimizer.
- Editing `prepare.py` to "fix" the dataset.
- Using a hand-tuned vocabulary or pretrained tokenizer.
- Using `assert val_bpb < X` to abort and re-run training silently.

# Logging

The runner appends to two places automatically:

- `tinker/RESULTS.md` (human-readable table; add notes if you want)
- `.research/<slug>/06_RUNS/<run_id>/events.jsonl` (one JSON line per iter, schema in `tests/schemas/events.schema.json`)

You should not need to write logs yourself.

# Stop conditions

You should stop the autonomous loop when **any** of:

- 8 hours of wall-clock have elapsed (`TINKER_OVERALL_BUDGET_HOURS`).
- 30 consecutive iterations without improvement.
- 10 consecutive iterations with `diverged=true` or syntax errors (probable bug in your strategy).

When stopping, leave a one-paragraph summary at the bottom of `tinker/RESULTS.md` explaining what you found and what you would try next.

# How to start

1. Read `tinker/train.py` to understand the baseline.
2. Run a baseline iteration: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/tinker_run.sh <slug>`
3. Inspect `tinker/result.json`. This becomes iteration 0.
4. Begin the loop above.

Good luck. Keep diffs reviewable.
