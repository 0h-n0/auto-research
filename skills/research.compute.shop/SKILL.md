---
name: research.compute.shop
description: >
  指定した workload (gpu_type, count, duration_h) に最適な GPU リソース提供元を
  ランク付け推奨する skill。AWS/GCP/Azure に加え Lambda/RunPod/Vast.ai/Salad/TensorDock/
  CoreWeave/DataCrunch 等の marketplace、Colab/Kaggle/HF ZeroGPU の free tier、
  GCP TRC/NSF ACCESS/national HPC の academic grant を含む 18 provider を網羅。
  Use when: Phase 4 (Experiment Design) で compute estimate が固まった直後、または
  借りる前に「同じ workload を最安でどこで動かせるか」を知りたいとき。
---

# `research.compute.shop`

GPU 調達 (compute procurement) のためのカタログ駆動推奨 skill。
価格は静的 catalog ベース、API 連携なし、最新は各 provider の `pricing_url` で確認する前提。

## 入力

| field | 必須 | 例 | 説明 |
|-------|------|-----|------|
| `gpu_type` | yes | `A100-80GB-SXM` | GPU 種別。aliases (`A100`, `H100`) 解決 |
| `gpu_count` | yes | 1 | per-job の GPU 数 |
| `duration_h` | yes | 24 | 所要時間 (時) |
| `max_usd_per_hour` | no | 5.0 | 単価上限 (filter) |
| `prefer_spot` | no (default false) | true | 中断可なら spot 価格優先 |
| `region_preference` | no | `["us", "jp"]` | region match を加点 |
| `include_free` | no (default true) | true | free tier も提示 |
| `include_academic` | no (default false) | true | academic grant も提示 (要 eligibility) |
| `slug` | no | `attention-sink` | 指定時 `.research/<slug>/COMPUTE_PROCUREMENT.md` を生成 |

## 出力

stdout: markdown 表形式の ranked list (commercial top N + free / academic 別枠)。
ファイル: `slug` 指定時は `.research/<slug>/COMPUTE_PROCUREMENT.md` に保存。

## ワークフロー

### 1. 入力解析と alias 解決

```python
gpu_type_normalized = catalog["aliases"].get(gpu_type, gpu_type)
```

`gpu_type` が catalog の aliases や providers[*].gpus に存在しない場合は warning + fuzzy 候補提示
(例: `A100` → `A100-80GB-SXM`)。

### 2. 候補絞り込み

各 provider について:
- `gpus[gpu_type_normalized]` が存在する provider のみ採用
- `prefer_spot=true` なら `spot != null` のものを優先 (未提供は on_demand を使う)
- `max_usd_per_hour` 指定時、超過する provider は除外 (リストに warning として残す)
- `include_free=false` なら `tier=free` を除外
- `include_academic=false` なら `tier=academic` を除外

### 3. 単価決定とコスト計算

```python
unit = (provider["gpus"][gpu_type]["spot"] if prefer_spot and provider["gpus"][gpu_type]["spot"] else
        provider["gpus"][gpu_type]["on_demand"])
total_usd = unit * gpu_count * duration_h
```

### 4. ランキング

詳細仕様: `references/recommendation_logic.md`

ソートキー (asc total_usd) → tiebreak (`tier_order` 逆順、enterprise > cloud > marketplace > consumer > free > academic)。

free / academic は別 section で表示 (要件マッチするもののみ)。

### 5. 出力フォーマット

```markdown
# Compute Procurement Recommendation

Generated: 2026-05-10T...
Workload: 1× A100-80GB-SXM, 24 hours
Filters: max_usd_per_hour=5, prefer_spot=true

## Top 5 (commercial, sorted by total estimated USD)

| # | Provider | Tier | usd/h | total USD | reliability | notes |
|---|----------|------|-------|-----------|-------------|-------|
| 1 | DataCrunch | cloud | 1.65 | $39.60 | high | EU 拠点 / 低 carbon |
| 2 | RunPod (Community) | marketplace | 1.69 | $40.56 | medium | host availability fluctuates |
| 3 | RunPod (Secure) | cloud | 1.89 | $45.36 | high | reliable on-demand |
| 4 | Lambda Labs | cloud | 1.99 | $47.76 | high | weekly reservation cheaper |
| 5 | TensorDock (spot) | marketplace | 0.95 | $22.80 | medium | ⚠ spot 中断リスク |

## Free options matching this workload (best effort)

- ⚪ HF Spaces ZeroGPU: A100-40GB burst (1-2 min/call) — 24h 連続 training には不向き
- ⚪ Colab Pro+ Compute Units: A100-40GB は ~$50/月で ~6-8 GPU-h 換算

(該当なし: A100-80GB-SXM の free tier はなし。L4 等への変更を検討すれば Colab Pro / Kaggle が候補)

## Academic options (要 eligibility)

- ⚪ NSF ACCESS (Discover allocation): US academic researcher 向け、application ~1-2 週間
- ⚪ National HPC centers: 所在国の academic 研究者は確認の価値あり (PRACE/EuroHPC, Cyfronet, Jülich, Riken, JADE2, AIST ABCI など)

## Caveats

- 価格は `gpu_providers.json` の reference 値、最新は公式 pricing page で確認
- Marketplace / spot は事前 reservation 不可、interrupted のリスクあり
- 24h 連続 training なら spot より on-demand 推奨
- Vast.ai / Salad は host 個別の reliability に大きな差 → 事前 DLPerf 確認推奨

## Next steps

- 推奨 1 を採用するなら: <pricing_url>
- 試算を反映: `.research/<slug>/cost_overrides.json` に契約価格を記入し
  `research.cost.estimate` を再実行
- 公平な比較を保つため複数 provider で同じ workload を回す場合、
  `research.cross.compare` で結果統合
```

### 6. next-step trailer 必須

```
─────────────────────────────────────
[Phase 4/8] ●●●●○○○○  G3 ✓  📊 Procurement ready

→ 推奨: DataCrunch (A100-80GB) ~$39.60 for 24h job
  catalog: skills/research.compute.shop/references/gpu_providers.json

  代替:
   ・ /auto-research:research-experiment <slug>   実行に進む
   ・ research.cost.estimate skill   実費試算 (実行後)
─────────────────────────────────────
```

## 失敗モード

| failure | 検出 | 回復 |
|---------|------|------|
| `gpu_type` が catalog に存在しない | aliases lookup 失敗 | fuzzy 候補 3 つを提示 + 公式 pricing_url 一覧 |
| 全 provider が予算超過 | `max_usd_per_hour` でフィルタ後 0 件 | top 5 を warning 付きで表示 + smaller GPU 提案 |
| catalog が古い (>180 日) | `updated_at` 比較 | warning 出力 + 公式 pricing 確認を強く促す |
| `gpu_providers.json` が読めない | jq fail | エラー終了、catalog 修復を案内 |

## Phase 連携

- **Phase 4 (Experiment Design)**: `experiment-designer` agent が compute 見積を出した直後、
  本 skill を続けて invoke して provider 候補を表示。`auto-research` SKILL.md の Phase 4 ガイドに記載
- **Phase 6 連携**: `research.cost.estimate` で `cost_overrides.json` を介して
  実契約価格を反映。事前 procurement 推奨と実費の乖離を可視化

## 倫理 / 開示

- **No affiliation**: 本 skill は紹介手数料 / アフィリエイト関係なし
- **公平性**: 商用 / marketplace / free / academic を等しく扱う
- **academic eligibility**: NSF ACCESS / GCP TRC 等は要件あり、出力で「⚪ 要確認」マーク + application URL を必ず併記
- **contract pricing 秘匿**: ユーザーの実契約 (`cost_overrides.json`) は git ignore 推奨を
  README で明記済み

## 参照実装

- `references/gpu_providers.json` — catalog SoT (18 providers, A100/H100/H200/L4/L40S/RTX-4090/3090/T4/P100/TPU 系)
- `references/recommendation_logic.md` — ranking / filter / fallback の詳細
- `references/compute_shop.py.txt` — Python 参照実装 (uv で実行可能)
- `scripts/find_cheap_gpu.sh` — CLI shortcut (skill を経由しないクイック比較)
