# Autonomous Tinker Loop — Specification (SoT)

`research.autonomous.tinker` skill の autonomous loop の仕様 SoT。本ファイルが loop アルゴリズムの単一参照元。

> Inspired by [karpathy/autoresearch](https://github.com/karpathy/autoresearch) (March 2026, MIT). See SKILL.md for full attribution.

## 不変条件 (どの実装でも変えない)

1. **Single file under agent edit**: `tinker/train.py` のみ。`prepare.py` / `data/` / `program.md` は agent から read-only
2. **Fixed wall-clock budget per iteration**: `TINKER_BUDGET_SECONDS` (default 300 秒)。短くすることはあっても、iteration 内で動的に伸ばさない
3. **Single comparable metric**: `val_bpb` (validation bits per byte)。複数の secondary metric を取るのは可だが ranking は val_bpb のみ
4. **Train / val split は変更不可**: `prepare.py` で固定、agent は触らない
5. **No external pretrained**: HF Hub からの pretrained model / pretrained tokenizer の流入禁止 (cheating 防止)
6. **History snapshots**: `history/iter_<N>.py` に commit、再現性確保
7. **events.jsonl 必須出力**: 1 iteration = 1 event line (`event=tinker.iteration` or `tinker.diverged`)

## State machine

```
[scaffold] → [data prep] → [baseline iter (#0)] → [autonomous loop]
                                                          ↓
                                           ┌──────────────┴────────────────┐
                                           ↓                                ↓
                                    [iter completes]                 [overall budget exhausted]
                                           ↓                                ↓
                                    [agent decides revert/keep]       [stop, transition Phase 7]
                                           ↓
                                       [next iter]
```

## Per-iteration sequence

```
0. Pre-flight check (tinker_run.sh):
   - Verify train.py syntactically valid (`python -c "import ast; ast.parse(open('train.py').read())"`)
   - Verify forbidden imports not introduced (e.g. `from transformers import AutoModel`)
   - Snapshot train.py to history/iter_<N>_pre.py

1. Run train.py with timeout (tinker_run.sh):
   timeout ${TINKER_BUDGET_SECONDS}s uv run python train.py
   - exit 0: complete (parse result.json)
   - exit 124 (SIGTERM from timeout): treat as normal completion (budget の意義)
   - exit 137 (SIGKILL): OOM 等、treat as failed
   - exit 1+: syntax error or runtime exception

2. Parse result.json:
   {"val_bpb": float|null, "wall_time_s": float, "n_iters": int,
    "diverged": bool, "loss_history": [...], "notes": "..."}

3. Compute decision metric:
   - succeeded + val_bpb < best: improvement
   - succeeded + val_bpb >= best: no improvement (kept for diversity, not new best)
   - diverged: discard, mark as failed
   - syntax_error / OOM: discard

4. Append to RESULTS.md:
   | iter | wall_time_s | val_bpb | best so far | diff | notes |

5. If improvement: update BEST.json + copy train.py to history/iter_<N>.py (committed)
   If no improvement: keep history/iter_<N>_pre.py (for analysis), don't update BEST

6. Append to events.jsonl:
   {"event":"tinker.iteration","level":"info","ts":...,"run_id":<run_id>,"duration_ms":...,
    "iter":<N>,"val_bpb":...,"best_val_bpb":...,"diff":...,"diverged":false,"notes":"..."}

   Or for divergence/error:
   {"event":"tinker.diverged","level":"warning","ts":...,"run_id":<run_id>,"duration_ms":...,
    "iter":<N>,"reason":"loss=NaN at step 1500"}

7. Check overall budget (TINKER_OVERALL_BUDGET_HOURS, default 8):
   - 経過時間 < budget: agent が次の iter を計画
   - 経過時間 >= budget: 強制停止、Phase 7 transition prompt
```

## Agent decision policy (推奨ヒント、program.md で agent に伝達)

agent は以下のいずれかの戦略を取る (組み合わせも可):

1. **Hill climbing**: best train.py をベースに 1 つだけ hparam を動かす (depth, heads, lr, batch_size, ...)
2. **Random restart**: 局所解を抜けるため、たまに完全新規アーキテクチャを試す
3. **Verification**: best 候補が来たら別 seed で再走 (val_bpb が 0.005 以内なら本物)
4. **Ablation**: 改善の原因特定のため、1 因子だけ戻して効果を測定

## 小型化ガイド (Small-compute guide)

karpathy README に倣う + 自前推奨:

### CPU / MPS smoke (とにかく動かしたい)

- `TINKER_BUDGET_SECONDS=60` (1 分)
- `DEPTH=2`, `D_MODEL=128`, `N_HEADS=2`
- `MAX_SEQ_LEN=128`, `TOTAL_BATCH_SIZE=2**10`
- `vocab_size=1024`
- dataset: TinyStories の最初の 1000 sample のみ

### RTX-3090 / A4000 (24GB consumer)

- `TINKER_BUDGET_SECONDS=300` (5 分、karpathy default)
- `DEPTH=4`, `D_MODEL=384`, `N_HEADS=6`
- `MAX_SEQ_LEN=512`, `TOTAL_BATCH_SIZE=2**14`
- `vocab_size=4096`
- dataset: TinyStories full

### A100-80GB / H100 (enterprise default)

- `TINKER_BUDGET_SECONDS=300`
- `DEPTH=8`, `D_MODEL=512`, `N_HEADS=8`
- `MAX_SEQ_LEN=1024`, `TOTAL_BATCH_SIZE=2**16`
- `vocab_size=8192`
- dataset: FineWeb-edu (一部)

これらは prepare.py / train.py の constant 部分で調整可能。`program.md` で agent に「DEPTH/MAX_SEQ_LEN は減らさず、その他で勝負しろ」等の制約を書ける。

## Reset / Revert policy

agent が train.py を破壊した場合 (syntax error が連続 5 回等):

1. tinker_run.sh が `events.jsonl` に `event=tinker.recover` で警告
2. `history/best.py` (BEST.json が指す iter) を `tinker/train.py` に戻す (skill が自動 revert)
3. RESULTS.md にも "auto-reverted to iter_<N>" の row を追加

Manual revert (ユーザー判断):

```bash
# Best 版に戻す
cp .research/<slug>/tinker/history/iter_<best_N>.py .research/<slug>/tinker/train.py

# 任意の iter に戻す
cp .research/<slug>/tinker/history/iter_<N>.py .research/<slug>/tinker/train.py
```

## Stop conditions

agent / skill は以下の **いずれか** が満たされたら autonomous loop を停止:

1. `TINKER_OVERALL_BUDGET_HOURS` 経過 (default 8h)
2. 連続 30 iter 改善なし
3. 連続 10 iter syntax_error / diverge
4. ユーザーが Ctrl+C で介入

停止後は Phase 7 (paper drafting) への transition を next-step trailer で促す。

## Disclaimer (program.md でも明示)

- 本 loop で得られた best モデルは **その compute platform / dataset / budget に最適化されたもの**。
  他環境での generalize は保証されない (karpathy も明記)。
- val_bpb は LM の **特定 dataset** での比較指標であり、downstream task 性能とは別物。
- Validation set は固定。agent が val 側を学習に流用したら cheating として skill が detect (将来的には preprare.py で hash 検証)。
