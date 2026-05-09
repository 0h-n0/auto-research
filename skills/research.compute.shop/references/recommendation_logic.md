# Recommendation Logic — `research.compute.shop`

`research.compute.shop` skill が provider をランク付けする際の詳細仕様。
本ファイルは推奨ロジックの **single source of truth**。実装変更時は本書を先に更新する。

## 1. 入力 schema

| field | type | default | validation |
|-------|------|---------|------------|
| `gpu_type` | string | (required) | catalog `aliases` または `providers[*].gpus` のキーに解決可能 |
| `gpu_count` | int >= 1 | (required) | |
| `duration_h` | float > 0 | (required) | |
| `max_usd_per_hour` | float > 0 \| null | null | per-GPU 単価の上限 |
| `prefer_spot` | bool | false | true のとき spot 価格を優先 (未提供なら on-demand fallback) |
| `region_preference` | list[str] \| null | null | 例 `["us", "jp"]` 部分文字列 match |
| `include_free` | bool | true | tier=free を出力する |
| `include_academic` | bool | false | tier=academic を出力する |

## 2. 価格選択

```python
g = provider["gpus"][gpu_type_normalized]
if prefer_spot and g.get("spot") is not None:
    unit = g["spot"]
    price_kind = "spot"
else:
    unit = g["on_demand"]
    price_kind = "on_demand"
total_usd = unit * gpu_count * duration_h
```

`unit is None` (catalog で価格未記載) の場合、その provider は除外し warning を出す。

## 3. フィルタ

ステップ順に適用:

1. **gpu_type match**: `provider.gpus[gpu_type_normalized]` が存在しない provider を除外
2. **price availability**: `unit is None` の provider を除外
3. **`max_usd_per_hour`**: `unit > max_usd_per_hour` の provider は除外 (warnings リストに記録)
4. **`include_free=false`**: `tier == "free"` を除外
5. **`include_academic=false`**: `tier == "academic"` を除外

## 4. ランキング (commercial section)

ソートキー (低い total_usd 優先):

```python
sort_key = (
    total_usd,                          # primary: cheapest first
    tier_rank(provider["tier"]),        # tiebreak: enterprise > cloud > marketplace > consumer
    -region_match_score(provider, region_preference),  # higher region match first
    provider["id"],                     # stable
)
```

`tier_rank` は `tier_order = ["enterprise", "cloud", "marketplace", "consumer", "free", "academic"]` の index。
`region_match_score` は `region_preference` の各要素について `provider.regions` のいずれかが部分文字列を含めば +1 (合計を返す)。

### 表示件数

- commercial section (tier in {enterprise, cloud, marketplace, consumer}): top 5
- free section (tier=free): all matching, 別 subsection
- academic section (tier=academic): all matching, `include_academic=true` のときのみ表示

候補 0 件の場合: warning を出して fallback (近い GPU type 提案) へ進む。

## 5. Fallback (候補 0 件)

`gpu_type` で 0 件マッチの場合、以下の代替候補を提案:

| 元の gpu_type | 代替候補 |
|---------------|---------|
| `A100-80GB-SXM` | `A100-80GB`, `A100-40GB`, `H100-80GB-SXM` |
| `H100-80GB-SXM` | `H100-80GB`, `H100-PCIe`, `H200-141GB`, `A100-80GB-SXM` |
| `H200-141GB` | `H100-80GB-SXM` |
| `L40S` | `RTX-A6000`, `L4`, `RTX-4090` |
| `RTX-4090` | `RTX-3090`, `RTX-A6000`, `L4` |
| `T4` | `L4`, `RTX-3090` |
| `TPU-v4-8` | `TPU-v3-8`, `TPU-v5e-8` |

代替提案では `(代替) 表記` を出力し、ユーザーに選択を委ねる。自動切替はしない。

## 6. Reliability hints

各 provider の `caveats` を出力 row に短縮表示:

| tier / 種別 | 表記例 |
|-------------|--------|
| `marketplace` (consumer host) | `⚠ host availability fluctuates` |
| `marketplace` (spot 価格選択時) | `⚠ spot 中断リスク` |
| `cloud` (enterprise) | `reliable, on-demand` |
| `free` | `⚪ free tier (limits apply)` |
| `academic` | `⚪ application required` |

## 7. Catalog rotation policy

- `updated_at` フィールドは毎 release で確認。**90 日経過で warning**、**180 日経過で error level warning**
- 価格変動が大きい provider (Vast.ai / Salad / RunPod community) は半年ごとに quote を再確認
- 新 provider 追加は PR ベース (CONTRIBUTING.md の Translation/Provider 節参照)

## 8. Disclaimer 要件 (出力に必ず含める)

- "Reference prices observable on each provider's pricing page as of <updated_at>"
- "Spot/community/marketplace prices fluctuate hourly"
- "The auto-research project has no affiliation with any provider listed here"
- "Verify current quotes on the linked pricing page before committing"

## 9. 倫理上の不変条件

- 商用 provider 推奨を上位に固定しない (純粋な total_usd ソート)
- アフィリエイトリンクは含めない (公式 root URL のみ)
- academic / free を「劣等扱い」しない (別 section で対等に提示)
- 紹介手数料 / 広告契約は受けない (catalog SoT の中立性を保つ)
