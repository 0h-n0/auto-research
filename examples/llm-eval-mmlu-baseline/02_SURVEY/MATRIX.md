# Literature Survey Matrix

| ID | Year | Method 概要 | Dataset | Metric | 主張 | replicability |
|----|------|------------|---------|--------|------|----------------|
| 2403.07974 | 2024 | chat template ablation (4 形式 × 4 model) | MMLU | 5-shot acc | template 差 +2-5pt | code+ckpt |
| 2406.14045 | 2024 | few-shot 数 / 順序 perturbation | MMLU + BBH | acc, std | 順序効果 >1pt | code only |
| 2310.19956 | 2023 | IRL で prompt 探索 | MMLU | acc | +3pt 改善 | code |
| 2407.03963 | 2024 | decoding setting ablation | BBH | acc, variance | greedy 再現性最高 | code |
| 2401.06766 | 2024 | subset selection 影響分析 | MMLU | acc | stratified 推奨 | code+data |

## カバレッジ分析

- Dataset カバー: MMLU (4 papers), BBH (2 papers)
- Method カテゴリ: prompt format ablation (2), prompt 最適化 (1), decoding (1), subset (1)
- 未検証セル (gap): **3-8B レンジに絞った Llama-3.2 / Qwen2.5 / Phi-4 系での format ablation は不在**

## 主要 contradictions / open questions

- 2403.07974 は template 差を 2-5pt と主張、2406.14045 は順序効果も 1pt 以上 → **両方を含めた合算 variance は未報告**
- decoding ablation (2407.03963) は BBH のみ。MMLU で同等の検証が必要
- subset 削減 (2401.06766) は Llama-2 ベース。直近モデルでも成立するか未検証

## 我々の研究の位置付け

- 直近 open-weights 3-8B 系で **format + decoding + subset** を 1 つの protocol で統合
- fair comparison checklist を 1 ページにまとめて公開
