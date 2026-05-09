# Gap Analysis (合議: seed-A / B / C を統合)

3 つの seed angle (A: 未検証セル, B: 矛盾, C: 隣接領域) で並列起動した research-gap-finder の出力を統合。

## 確認できた事実

1. format ablation (2403.07974) と order/few-shot ablation (2406.14045) は別々に行われており、合算 variance は未報告
2. decoding ablation (2407.03963) は BBH のみ。MMLU で同等検証なし
3. subset selection 影響 (2401.06766) は Llama-2 系で検証済みで、近年モデルでは不明

## 未検証セル (seed-A)

| モデル × format | 評価あり |
|----------------|---------|
| Llama-2-7B × {公式, no-system, raw-completion} | yes (2403.07974) |
| Llama-2-13B × {同} | yes |
| **Llama-3.2-3B × any format** | **no** |
| **Qwen2.5-7B × any format** | **no** |
| **Phi-4-mini × any format** | **no** |
| Llama-2-7B × CoT format | no (out of scope of 2403.07974) |

## 矛盾 (seed-B)

- 2403.07974: 「公式 template が必ずしもベストではない」と主張
- 2406.14045: 「順序効果は format 効果と独立」と主張
  → 直交性の検証が不十分。format × order 交互作用は未検証

## 隣接領域 (seed-C)

- code 評価 (HumanEval) では prompt format 効果が更に大きいという報告 (Liu et al., 2024)
  → MMLU だけでなく code/reasoning でも format protocol が必要かもしれない (本研究の Out of Scope だが、論文の Discussion で言及)

## ギャップ要約

**直近 (2024 後半 -) の open-weights 3-8B モデルで、format + few-shot order + decoding + subset を統合した protocol は未提案**。
本研究はこのギャップを埋め、(1) 統合 protocol, (2) Llama-3.2 / Qwen2.5 / Phi-4 系での実証データ, (3) fair comparison checklist の 3 つを成果物とする。
