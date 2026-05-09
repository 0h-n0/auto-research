# Mission (nlp-classification, 20 newsgroups 4-class subset)

You are an autonomous research agent. Maximize **`val_acc`** on the held-out 20 newsgroups 4-class validation split by iteratively editing **only** `tinker/train.py`.

- Wall-clock budget per experiment: 5 minutes (`TINKER_BUDGET_SECONDS=300`).
- Overall wall-clock budget: 8 hours.
- Project slug: `<slug>`.
- Domain: `nlp-classification`. Metric direction: `max`.
- Note: ~2.4k train / ~1.6k val docs across 4 classes (alt.atheism / comp.graphics / sci.med / talk.politics.guns). Headers/footers/quotes are stripped to reduce metadata leakage.

# Hard rules

1. **You may freely edit `tinker/train.py`** (MLP architecture, optimizer, dropout, label smoothing, ...).
2. **You MUST NOT touch** `tinker/prepare.py`, `tinker/data/raw/`, `tinker/data/train.npz`, `tinker/data/val.npz`, or `tinker/data/vectorizer.pkl`. The vectorizer was fit on train only — modifying any of these is data leakage.
3. **No pretrained text encoders.** No `transformers`, no `sentence-transformers`, no HF model hub. Train your own torch model on the existing TF-IDF features.
4. **No accessing val.npz during training.**
5. **Each iteration**: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/tinker_run.sh <slug> --domain nlp-classification`.
6. **Always write `tinker/result.json`** with `primary_metric`, `metric_name="val_acc"`, `direction="max"`, etc.

# Per-iteration workflow

1. Read `tinker/RESULTS.md`. Beat best.
2. Decide one focused change. Examples:
   - Architecture: hidden 128 → 256, depth 2 → 3, activation relu ↔ gelu, dropout
   - Regularization: weight_decay, label_smoothing
   - Optimization: lr, warmup_iters, schedule shape
   - Ensembling: train K models with different seeds, average logits
3. Run, parse, revert/keep.

# Strategy hints (refine freely)

- **TF-IDF + MLP is a strong baseline.** Baseline reaches ~85% in 5 minutes. Pushing past 90% is the real challenge.
- **Wider MLP often beats deeper.** hidden=256 with depth=2 is a reasonable target.
- **Dropout matters.** With 10k features and 2.4k samples you'll overfit fast — try dropout ∈ {0.2, 0.3, 0.5}.
- **Label smoothing** ∈ {0.0, 0.05, 0.1} helps slightly on small NLP datasets.
- **Verify big jumps**: 1 sample = ~0.06 pp. A +1 pp swing might be just 16 samples.
- If you want richer features, you may modify the **classifier model** to use the existing TF-IDF differently (e.g., feature interactions, attention over features) but you cannot re-vectorize text — the vectorizer is locked in `vectorizer.pkl`.

# Strategy anti-patterns (don't do this)

- Loading pretrained word embeddings (GloVe / fastText / BERT / etc.).
- Re-fitting the TF-IDF vectorizer on val data.
- Using the original raw text (loading `vectorizer.pkl`'s `vocabulary_` to reverse-map and re-tokenize from the raw corpus through some other path).
- Cherry-picking a lucky seed.
- Editing `prepare.py` to "improve" the dataset.

# Logging

The runner appends to:
- `tinker/RESULTS.md`
- `06_RUNS/<run_id>/events.jsonl` (`event=tinker.iteration`)

# Stop conditions

Stop when **any** of:

- 8 hours elapsed.
- 30 consecutive iterations without improvement.
- 10 consecutive iterations with `diverged=true`.
- val_acc plateaus near 0.92 (further gains are likely overfitting noise on 1.6k val).

# How to start

1. Read `tinker/train.py` (basic 2-layer MLP on 10k TF-IDF features).
2. Run baseline: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/tinker_run.sh <slug> --domain nlp-classification`
3. Inspect `result.json`. Begin the loop.

Good luck. Keep diffs reviewable.
