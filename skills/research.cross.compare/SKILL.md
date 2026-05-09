---
name: research.cross.compare
description: >
  複数の `.research/<slug>/` プロジェクトの primary metric を集約し、統計検定込みで
  cross-project 比較レポートを生成する skill。paired bootstrap (B=10000) や Welch's t、
  Cohen's d / Cliff's delta、ranking 表まで作る。`scripts/cross_compare.sh` の上位互換。
  Use when: 複数の関連研究プロジェクトを跨いで結果を統合したい、または同じ研究テーマで
  複数バージョン (例: baseline vs improved) を厳密に比較したいとき。
---

# `research.cross.compare`

`auto-research` プラグインで複数プロジェクト跨ぎの結果統合・比較を行う skill。

## 入力 / 出力

入力:
- 比較対象プロジェクトの slug 一覧 (≥ 2 個)
- 各プロジェクトの `.research/<slug>/06_RUNS/*/metrics.json` (status=succeeded のみ対象)
- (任意) 共通 metric 名 (指定なければ各プロジェクトの primary を自動採用)

出力:
- `.research/_compare/<comparison_id>/REPORT.md` — 結果報告書
- `.research/_compare/<comparison_id>/raw.json` — 集計データ (再計算可能)
- `.research/_compare/<comparison_id>/figures/*.pdf` — 比較図

`<comparison_id>` 形式: `{YYYYMMDD-HHMMSS}-{first_two_slugs_hash[:6]}`

## 制約

- **シェル script (`scripts/cross_compare.sh`) は引き続き利用可** — 統計検定なしの単純集約用。
  本 skill はそれをラップして統計検定を加える。
- 比較対象 metric 名が異なる場合、normalize は行わない (異常終了)
- runs が 0 個のプロジェクトは warning + 集約から除外
- failed run は集約から除外 (但し件数は report に明記)

## ワークフロー

### 1. 入力検証

```
入力 slug: [<slug1>, <slug2>, ...]
最低 2 個必要、各 slug について `.research/<slug>/STATE.json` の存在確認
```

無い場合は明確にエラー。

### 2. 集約 (raw.json)

各プロジェクト × 各 succeeded run について:

```json
{
  "comparison_id": "20260509-103000-a1b2c3",
  "generated_at": "2026-05-09T10:30:00Z",
  "projects": ["llm-eval-mmlu-baseline", "llm-eval-mmlu-cot"],
  "common_metric": "acc",
  "data": {
    "llm-eval-mmlu-baseline": [
      {"run_id": "...", "config_hash": "...", "value": 0.671, "n": 1000, "seed": 42},
      ...
    ],
    "llm-eval-mmlu-cot": [
      ...
    ]
  },
  "exclusions": {
    "failed_runs": 3,
    "missing_metric": 0,
    "metric_mismatch": []
  }
}
```

### 3. 統計検定

実装は Python (uv で `scipy` + `numpy`) で書く。`scripts/cross_compare_stats.py` として skill に同梱。

#### 3.1. Pairwise comparison

全プロジェクトペア (N(N-1)/2) について:
- **paired bootstrap** (B=10000): 同 seed で対応取れる場合
- **Welch's t-test**: paired できない場合 (異なる seeds)
- 効果量: **Cohen's d** + **Cliff's delta**
- 多重比較補正: **Holm-Bonferroni**

#### 3.2. Ranking

各プロジェクトの mean ± 95% CI で ranking。Cliff's delta で順位の robustness を表示。

### 4. 図表生成

- `figures/comparison_box.pdf`: プロジェクトごとの metric 分布 (boxplot + 個別 run scatter)
- `figures/pairwise_effect.pdf`: ペアごとの mean Δ + 95% CI
- (matplotlib + seaborn `colorblind` palette、300 dpi)

### 5. REPORT.md

```markdown
# Cross-Project Comparison Report — {comparison_id}

Generated: 2026-05-09T10:30:00Z
Projects: llm-eval-mmlu-baseline, llm-eval-mmlu-cot

## Summary
- Common metric: {acc}
- Total succeeded runs: {N}
- Excluded (failed): {M}

## Main Table
| Project | N runs | mean ± 95% CI | rank |
|---------|--------|--------------|------|
| ...     | ...    | ...          | 1    |

## Pairwise comparison
| Pair | Δ mean (95% CI) | p (Holm) | Cohen's d | Cliff's δ |
|------|-----------------|----------|-----------|-----------|
| baseline vs cot | +1.5 [+0.8, +2.2] | 0.001** | 0.42 | 0.31 |

## Statistical Notes
- Test: paired bootstrap, B=10000 (where seeds aligned), else Welch's t
- Correction: Holm-Bonferroni across {N(N-1)/2} pairs
- Significance: * p<0.05, ** p<0.01, *** p<0.001

## Figures
- figures/comparison_box.pdf
- figures/pairwise_effect.pdf

## Reproducibility
Re-run with `code/analysis/cross_compare_stats.py raw.json`
```

## 実装ガイド

skill 本体 (Claude が実行する流れ):

1. 入力検証: `.research/<slug>/STATE.json` 存在チェック × N
2. 各プロジェクトの `06_RUNS/*/STATUS` を Glob、succeeded のみ集める
3. 各 metrics.json を Read → raw.json を Write
4. `Bash` で `uv run --with 'numpy scipy matplotlib seaborn' python scripts/cross_compare_stats.py <raw.json>` を実行
5. 出力 REPORT.md / figures を確認
6. **next-step trailer 必須出力** (`next_steps_template.md` 参照)

### `scripts/cross_compare_stats.py` の最小実装

```python
"""scripts/cross_compare_stats.py — research.cross.compare skill backend.

Usage: uv run --with 'numpy scipy matplotlib seaborn' \\
         python scripts/cross_compare_stats.py <raw.json> <output_dir>
"""
import json, sys
from pathlib import Path
import numpy as np
from scipy import stats
import matplotlib.pyplot as plt
import seaborn as sns

raw = json.loads(Path(sys.argv[1]).read_text())
out = Path(sys.argv[2])
out.mkdir(parents=True, exist_ok=True)

projects = raw["projects"]
data = {p: np.array([r["value"] for r in raw["data"][p]]) for p in projects}

# Main table
rows = []
for p in projects:
    arr = data[p]
    if len(arr) == 0:
        continue
    m = arr.mean()
    se = arr.std(ddof=1) / np.sqrt(len(arr)) if len(arr) > 1 else 0
    lo, hi = stats.t.interval(0.95, len(arr)-1, loc=m, scale=se) if len(arr) > 1 else (m, m)
    rows.append((p, len(arr), m, lo, hi))
rows.sort(key=lambda r: -r[2])
for i, (p, n, m, lo, hi) in enumerate(rows):
    print(f"| {p} | {n} | {m:.3f} [{lo:.3f}, {hi:.3f}] | {i+1} |")

# Pairwise comparison (paired bootstrap or Welch)
def paired_bootstrap(a, b, B=10000, rng=None):
    rng = rng or np.random.default_rng(0)
    diffs = a - b
    boot = np.array([diffs[rng.integers(0, len(diffs), len(diffs))].mean() for _ in range(B)])
    lo, hi = np.quantile(boot, [0.025, 0.975])
    p = 2 * min((boot <= 0).mean(), (boot >= 0).mean())
    return diffs.mean(), (lo, hi), p

# Save figures, REPORT.md, etc...
```

(詳細は `references/cross_compare_stats.py.txt` 参照)

## 失敗モード

- 比較対象が 1 個以下 → エラー終了
- metric 名が異なる → エラー (normalize しない)
- 全 run が failed → warning + 空 REPORT
- scipy 未インストール → uv で自動取得 (実行環境エラー時はメッセージで案内)

## Phase 連携

- `auto-research` skill の Phase 8 で **複数プロジェクト跨ぎ** が必要な場合に dispatch
- `commands/research-write.md` の Related Work 強化用に使うことも想定
- 単一プロジェクト内の run 比較は `result-statistician` agent (本 skill ではない)

## next-step trailer

skill 完了時に通常の next-step trailer を出すのに加え、複数プロジェクトを横断して扱うため
trailer の `slug` フィールドは比較対象を `,` 区切りで列挙、または「複数プロジェクト比較中」の旨を表示。
