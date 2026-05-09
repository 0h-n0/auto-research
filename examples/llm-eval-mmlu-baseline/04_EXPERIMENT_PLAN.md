# Experiment Plan: MMLU Fair-Comparison Protocol (Idea 2 採択)

## Research Questions

- **RQ1**: open-weights 3-8B で MMLU acc に対する 4 因子 (format / order / decoding / subset) の variance 寄与は分離できるか?
- **RQ2**: 4 因子の合算 std は単一因子の std の +50% を超えるか?
- **RQ3**: 因子間の交互作用 (特に format × order) は統計的に有意か?

## Hypotheses

- **H1 (primary, falsifiable)**: 4 因子のうち format が最大の variance 寄与を持ち、Cohen's d ≥ 0.5 で他因子と区別できる
- **H2**: 合算 std ≥ format 単独 std × 1.5 (paired bootstrap, B=10000, p<0.05)
- **H0 (null)**: 因子間 variance 寄与に有意差なし

## Factors

| factor | type | levels | priority |
|--------|------|--------|----------|
| model | categorical | [Llama-3.2-3B, Qwen2.5-7B, Phi-4-mini] | P0 |
| format | categorical | [official-chat, no-system, single-turn, raw-completion] | P0 |
| order | categorical | [original, reverse, shuffle-seed-42] | P1 |
| decoding | categorical | [greedy, temp-0.7] | P1 |
| subset | categorical | [full-14042, stratified-2000] | P1 |

## Ablation Matrix

- 全 cell: 3 × 4 × 3 × 2 × 2 = **144 cells**
- × seeds: 144 × 3 = **432 runs**
- 開始 sanity: full-14042 × greedy × original × official-chat × Llama-3.2-3B (公表値 62.3 ± 0.5 と比較)

## Metrics

### Primary
- name: MMLU 5-shot accuracy (lm-eval-harness v0.4.7)
- 期待: format 因子の variance 寄与 ≥ 30% (ANOVA-style)

### Sanity
- baseline ベンチマーク再現: lm-eval default (Llama-3.2-3B-Instruct) が 62.3 ± 0.5 内
- forward pass NaN/Inf check
- decoding=greedy の確定性 (同 seed で完全一致)

### Secondary
- throughput (qps)
- memory peak (GB)

## Statistical Test

- per-factor variance contribution: ANOVA-style decomposition
- format pairs: paired bootstrap (B=10000, seed-pair で対応)
- 多重比較補正: Holm-Bonferroni (4 factors × 3 models = 12 比較)
- 効果量: Cohen's d (連続) and Cliff's delta (順序)

## Seeds Plan

- N_seeds = 3
- seed values: 42, 1337, 2024
- per-cell の variance を確認、CI 幅が 大きい (>2pt) 場合は seed=4 へ拡張 (要 budget 確認)

## Compute Budget

| step | per-run GPU-h | runs | total GPU-h |
|------|---------------|------|-------------|
| baseline sanity (full subset, greedy) | 0.5 | 9 | 4.5 |
| ablation (full subset 部分) | 0.4 | 108 | 43.2 |
| ablation (stratified 2000 部分) | 0.06 | 324 | 19.4 |
| **total** | | 441 | **67.1** |

Budget: 80 GPU-h, 利用率: 84%。余裕は seed 追加用に確保。

## Reproducibility Checklist

- [x] `pyproject.toml` 完全固定 (`uv.lock` コミット)
- [x] `git rev` を `RunConfig` に記録
- [x] `config_hash` を `RunConfig` から計算
- [x] random / numpy / torch / accelerate seed 全部固定
- [x] `torch.use_deterministic_algorithms(True)`
- [x] CUDA / cuDNN / driver version を `IMPL_NOTES.md` に記載
- [x] dataset license: MIT (cais/mmlu)
- [x] tokenizer version 固定
- [x] events.jsonl 必須フィールド: event, level, ts, run_id, duration_ms

## Eval 汚染チェック

- eval dataset: cais/mmlu (作成: 2020-09)
- pretraining cutoff:
  - Llama-3.2-3B: 2023-12
  - Qwen2.5-7B: 2024-09
  - Phi-4-mini: 2024-12
- MMLU は全モデルで cutoff 前に存在 → 汚染リスクあり
- 検出: BIG-bench canary を含むサンプルを除外、n-gram (n=10) overlap は事前計算済み (1.2%)
- 報告: paper Appendix で overlap 実態を開示

## Compute Adjustments (実装時に発生したもの)

(まだなし。実装時に超過したらここに追記)

## Status

**Gate G3 通過**: 2026-04-22T17:30:00Z. Phase 5 (Scaffold) へ進行可。
