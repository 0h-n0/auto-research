---
name: research.cost.estimate
description: >
  各 run の compute cost (USD) を duration × GPU 単価で試算し、project 累積コストと
  `compute_budget_gpu_h` 残量を可視化する skill。budget の 80% で警告、100% 超過で
  ロールバック提案。GPU 単価表は `references/gpu_price_table.json` を SoT とし、
  ユーザー側で上書き可能。
  Use when: Phase 6 (Run & Analysis) で run が完了した直後、または `/auto-research:research-status`
  で予算確認したいとき。
---

# `research.cost.estimate`

Compute cost の試算と budget watch を行う skill。Phase 6 の終盤で `result-statistician` と並列に dispatch される想定。

## 入力 / 出力

入力:
- `<slug>` (`.research/<slug>/` 内 STATE.json + 06_RUNS/*/metrics.json)
- (任意) ユーザー側 GPU 単価上書き (`.research/<slug>/cost_overrides.json` があれば優先)

出力:
- `.research/<slug>/06_RUNS/<run_id>/metrics.json` に `cost_estimate` ブロックを追記 (run 完了時)
- `.research/<slug>/06_COST_REPORT.md` (project 累積)
- 標準出力: 警告メッセージ (budget 80% 超過時)

## GPU 単価表 (SoT)

`references/gpu_price_table.json` に market price reference を集約。
**目安値**であり、契約・spot/on-demand・region によって変動するためあくまで estimate。

主要 GPU の `usd_per_hour` (2026 Q2 時点の publicly observable):

| GPU | on-demand USD/h | spot USD/h | source |
|-----|-----------------|------------|--------|
| NVIDIA A100 80GB SXM | ~$2.0 | ~$1.0 | AWS p4de, Lambda Labs, RunPod |
| NVIDIA A100 40GB | ~$1.5 | ~$0.8 | RunPod, Lambda |
| NVIDIA H100 80GB SXM | ~$3.5 | ~$1.8 | Lambda, RunPod, AWS p5 |
| NVIDIA H200 | ~$4.5 | ~$2.5 | RunPod (limited) |
| NVIDIA L40S | ~$1.0 | ~$0.5 | RunPod |
| NVIDIA L4 | ~$0.5 | ~$0.25 | GCP, RunPod |
| NVIDIA RTX 4090 (24GB) | ~$0.5 | ~$0.3 | RunPod, Vast.ai |
| TPU v4-8 | ~$3.5 (TRC 無料枠あり) | n/a | GCP |
| Apple M-series | $0 (own hardware) | $0 | local |

実際の単価は契約による。本 skill のレポートには「estimate (公開価格ベース)」と必ず明記。

## ワークフロー

### 1. STATE.json 読み込み

`.research/<slug>/STATE.json` から:
- `compute_budget_gpu_h` (Phase 1 で設定された予算)
- `time_budget_days` (時間予算、参考)

### 2. 各 run の cost 計算

`06_RUNS/*/metrics.json` を Glob:

```python
duration_h = elapsed_seconds / 3600
gpu_usd_per_hour = lookup(gpu_type)  # references/gpu_price_table.json
gpu_count = meta.num_gpus
cost_usd = duration_h * gpu_usd_per_hour * gpu_count
```

`metrics.json` を **read-modify-write** で `cost_estimate` ブロック追記:

```json
{
  "run_id": "...",
  "primary": {...},
  "cost_estimate": {
    "usd": 4.27,
    "duration_h": 1.0,
    "gpu_type": "A100-80GB-SXM",
    "gpu_count": 1,
    "usd_per_hour": 2.0,
    "pricing_source": "on-demand (AWS p4de est. 2026 Q2)",
    "estimated_at": "2026-05-09T15:00:00Z"
  }
}
```

### 3. 累積 Report

`06_COST_REPORT.md` を生成:

```markdown
# Cost Report — <slug>

Generated: 2026-05-09T15:00:00Z

## Budget vs Actual

| 項目 | 値 |
|------|-----|
| Budget (Phase 1) | 80 GPU-h |
| Used GPU-h (succeeded runs only) | 23.4 GPU-h |
| Used GPU-h (incl. failed) | 26.1 GPU-h |
| Estimated USD (succeeded) | $46.80 |
| Estimated USD (total) | $52.20 |
| Budget remaining | 53.9 GPU-h (67.4%) |

## Status

✓ Within budget (32.6% used). Safe to continue.

(警告レベルは: 80%超 → ⚠ caution、100%超 → ✗ overrun)

## Per-run breakdown

| run_id | status | duration | gpu | cost (USD) |
|--------|--------|----------|-----|-----------|
| 20260509-104523-a1b2c3d-9e8f7d | succeeded | 1.0 h | A100-80GB × 1 | $2.00 |
| 20260509-114523-a1b2c3d-3a8b1e | succeeded | 0.7 h | A100-80GB × 1 | $1.40 |
| ... | ... | ... | ... | ... |

## Disclaimer

公開価格 (on-demand AWS / Lambda / RunPod 平均) ベースの **estimate**。
実費は契約・spot/on-demand・region・期間によって異なる。
正確な値は cloud provider の billing dashboard を参照のこと。
```

### 4. Budget watch

| 利用率 | 表示 | 推奨アクション |
|--------|------|---------------|
| < 50% | ✓ Safe | 通常進行 |
| 50-80% | ✓ On track | 進行可、節約検討も |
| 80-100% | ⚠ Caution | 残り cells を P0 のみに絞る検討 |
| 100%+ | ✗ Over budget | rollback 提案 (`research-experiment` 中断、`experiment-designer` で plan 縮小) |

警告は標準出力 + `06_COST_REPORT.md` の Status セクションに反映。

### 5. next-step trailer

通常の trailer に加え、cost 状況を 1 行表示:

```
─────────────────────────────────────
[Phase 6/8] ●●●●●●○○  G3 ✓

→ 推奨: /auto-research:research-write <slug>
  (Paper Drafting)

  📊 Cost: $46.80 used / $160 budget (29.3%)

  代替:
   ・ /auto-research:research-status <slug>   進捗確認
─────────────────────────────────────
```

## ユーザー上書き

`.research/<slug>/cost_overrides.json` を作成すると優先される:

```json
{
  "gpu_pricing": {
    "A100-80GB-SXM": 1.20,    // ユーザーの実契約 USD/h
    "H100-80GB-SXM": 2.50
  },
  "currency": "USD",
  "note": "RunPod spot, 2026 Q2 contract"
}
```

これを skill が検知して上書き計算する。`pricing_source` には `"user override (cost_overrides.json)"` と記録。

## 失敗モード

- `gpu_type` が `meta` にない → `unknown_gpu` として `usd=null`、警告 + ユーザーに gpu_type を尋ねる
- `elapsed_seconds` が 0 / null → `incomplete run` として skip
- gpu_price_table.json が読めない → user override が無ければ警告して abort

## Phase 連携

- Phase 4 (`experiment-designer`): 実験計画時に `compute_budget_gpu_h × usd_per_hour` を予算 USD として表示する補助
- Phase 6 (`research.experiment.run` 後): 各 run 完了直後に dispatch して metrics.json を更新
- Phase 8 (`research-review`): COST_REPORT を `paper/limitations.md` の計算リソース節に展開

## error_handling_spec.md との連携

「cost overrun」を `error_handling_spec.md` の Phase 6 表に追記 (v0.5.0 で実施):

| failure | 検出 | 回復 |
|---------|------|------|
| compute budget 超過 | research.cost.estimate の budget watch | 残り cells を P0 のみに絞る、or smaller model に switch、最悪は Phase 4 へ rollback |
