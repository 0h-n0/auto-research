# Research Brief: MMLU prompt-format effect on small open-weights LLMs

## Motivation

オープンウェイト 3-8B モデルで MMLU の性能は prompt format (chat template の使い方、5-shot vs zero-shot、CoT の有無) に強く依存することが報告されているが、近年の Llama-3.2 / Qwen2.5 / Phi-4 系で系統的な比較がない。実用上「どの prompt が公平な比較か」が曖昧なまま leaderboard が引用されている。

## Scope

- focus_area: evaluation
- 対象モデル規模: 3B-8B open weights のみ (Llama-3.2-3B, Qwen2.5-7B, Phi-4-mini)
- 検証する現象: prompt format による MMLU acc の variance

## Out of Scope

- 70B 以上の大型モデル (compute budget の制約)
- API 専用モデル (再現性確保のため)
- MMLU 以外のベンチマーク (BBH 等は v2 で別途)

## Success Criteria

- 主要指標: format 間の Δ acc が paired bootstrap で p<0.05 で有意か検出できる
- 副次指標: format ごとの計算コスト比 (throughput qps)
- novelty: 「fair comparison protocol」を 1 つ提案

## Budgets

- time_budget_days: 14
- compute_budget_gpu_h: 80
- compute_kind: 1× A100 80GB (個人所有 or cloud)

## Paper Format

- latex-acl

## Starting Pointers

- arXiv 2403.07974 (chat template impact)
- arXiv 2406.14045 (MMLU robustness)
- huggingface.co/datasets/cais/mmlu
- lm-eval-harness v0.4.7
