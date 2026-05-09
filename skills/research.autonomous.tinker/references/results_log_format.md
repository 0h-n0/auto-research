# RESULTS.md and events.jsonl format — autonomous tinker

## RESULTS.md (human-readable iteration log)

Markdown table appended by `tinker_run.sh` after every iteration. Sorted by iteration number (insertion order, **not** by val_bpb).

```markdown
# Tinker Results — <slug>

| iter | wall_time_s | val_bpb | best so far | diff | status | notes |
|------|-------------|---------|-------------|------|--------|-------|
| 0    | 298.4       | 1.485   | 1.485       | —    | ok     | baseline |
| 1    | 297.1       | 1.501   | 1.485       | +0.016 | ok   | depth 4 → 6 (worse) |
| 2    | 124.5       | null    | 1.485       | n/a  | diverged | NaN at step 1500 |
| 3    | 295.0       | 1.467   | 1.467       | -0.018 | NEW BEST | lr 3e-4 → 5e-4 |
| 4    | 296.2       | 1.469   | 1.467       | +0.002 | ok     | seed 43 (verify #3) |
| ...  |             |         |             |      |        |       |

## Summary
- best val_bpb: 1.467 at iter 3 (seed 42, lr=5e-4)
- iters total: N
- diverged: M
- syntax errors: K
```

### Status values

- `ok`: train.py ran to completion, `result.json.diverged=false`
- `NEW BEST`: improved over previous best by any amount
- `diverged`: NaN/Inf loss (`result.json.diverged=true`)
- `syntax_error`: train.py failed Python syntax check before running
- `oom`: process killed by OOM (exit 137)
- `forbidden`: pre-flight detected forbidden import (e.g. transformers pretrained model)
- `timeout`: hit `TINKER_BUDGET_SECONDS` cleanly (treated as ok if val_bpb is recorded, otherwise as `timeout`)

## BEST.json

Updated atomically when a `NEW BEST` iteration finishes:

```json
{
  "iter": 3,
  "val_bpb": 1.467,
  "wall_time_s": 295.0,
  "n_iters_train": 14823,
  "config_snapshot_path": "tinker/history/iter_3.py",
  "config_sha256": "abc1234...",
  "recorded_at": "2026-05-10T01:23:45Z"
}
```

## events.jsonl (machine-readable, CLAUDE.md regulation)

One line per iteration, appended to `.research/<slug>/06_RUNS/<run_id>/events.jsonl`. Conforms to `tests/schemas/events.schema.json`.

### Successful iteration

```json
{"event":"tinker.iteration","level":"info","ts":"2026-05-10T01:23:45Z",
 "run_id":"20260510-012345-abc1234-def567","duration_ms":295042,
 "iter":3,"val_bpb":1.467,"best_val_bpb":1.467,"diff":-0.018,
 "diverged":false,"status":"new_best","wall_time_s":295.0,
 "n_iters_train":14823,"params_M":11.2,"notes":"lr 3e-4 -> 5e-4"}
```

### Diverged

```json
{"event":"tinker.diverged","level":"warning","ts":"...",
 "run_id":"...","duration_ms":124500,"iter":2,
 "reason":"loss=NaN at step 1500","status":"diverged",
 "error_type":"DivergenceError","error_message":"loss became NaN; train aborted"}
```

### Syntax error (pre-flight)

```json
{"event":"tinker.diverged","level":"error","ts":"...",
 "run_id":"...","duration_ms":0,"iter":4,
 "reason":"SyntaxError at line 87","status":"syntax_error",
 "error_type":"SyntaxError","error_message":"...",
 "error_stack":"..."}
```

### Forbidden import (pre-flight)

```json
{"event":"tinker.diverged","level":"error","ts":"...",
 "run_id":"...","duration_ms":0,"iter":5,
 "reason":"forbidden import: transformers.AutoModelForCausalLM",
 "status":"forbidden","error_type":"PolicyViolation",
 "error_message":"pretrained models are not allowed"}
```

### Auto-revert

```json
{"event":"tinker.recover","level":"warning","ts":"...",
 "run_id":"...","duration_ms":50,"iter":11,
 "reason":"5 consecutive failed iterations; reverting train.py to history/iter_3.py",
 "reverted_to_iter":3,"reverted_to_val_bpb":1.467}
```

## jq one-liners (for analysis)

```bash
# Best val_bpb timeline
jq -c 'select(.event=="tinker.iteration" and .val_bpb != null) | [.ts, .iter, .val_bpb] | @tsv' \
  .research/<slug>/06_RUNS/*/events.jsonl

# How many diverged?
jq -c 'select(.event=="tinker.diverged")' \
  .research/<slug>/06_RUNS/*/events.jsonl | wc -l

# Status breakdown
jq -r '.status // "unknown"' .research/<slug>/06_RUNS/*/events.jsonl | sort | uniq -c
```

These are useful in Phase 7 (paper drafting) for plotting the "tinker journey" curve.
