# Evaluation Protocol

Phase 4 (Experiment Design) で必須項目化するベンチマーク選定・汚染チェックのガイド。

## ベンチマーク選定の基本

| focus_area | 推奨ベンチマーク | ハーネス |
|------------|------------------|----------|
| general capability | MMLU, BBH, GSM8K, HumanEval, ARC, HellaSwag | `lm-evaluation-harness` |
| reasoning | GSM8K, MATH, MMLU-Pro, ARC-Challenge | `lm-evaluation-harness` |
| coding | HumanEval, MBPP, LiveCodeBench | `bigcode-evaluation-harness` |
| agent / tool-use | SWE-bench, AgentBench, GAIA, ToolBench | 公式 repo |
| long-context | RULER, LongBench, ∞Bench, Needle-in-Haystack | `lm-evaluation-harness` v0.4+ |
| safety / refusal | XSTest, HarmBench, AdvBench | 公式 repo |
| post-training | AlpacaEval 2 LC, Arena-Hard, MT-Bench | 公式 repo |
| attention / mech interp | IOI, induction tasks (synthetic) | `transformer_lens` |

## 必須記録項目 (`04_EXPERIMENT_PLAN.md` に明記)

- benchmark name と version (例: `MMLU 5-shot, lm-eval v0.4.7`)
- 評価対象 split: train / val / test のどれか、サンプル数
- decoding (greedy / temperature / top_p / max_tokens)
- prompt template (chat template の system / user / assistant フォーマット)
- 評価指標とその実装ソース (実装が分かれている場合は明記)

## eval 汚染チェック

事前学習の cutoff date が公開されている場合 (open weights):

1. **n-gram overlap** — eval set の prompt と pretraining corpus の n-gram (n=10 推奨) overlap を計算。
   - 推奨ツール: `data-portraits`, `lm-deduplicate`, 自前なら `datasketch` MinHash
2. **canary string** — 既知の canary (例: BIG-bench canary GUID) を含む例を除外
3. **report**: overlap > 1% の場合は **必ず** 論文 Appendix で開示

API モデル (closed weights) の場合は cutoff date を明記し、cutoff 以降に作成された eval を優先。

## 統計的有意性

- ベンチマーク 2 系での比較は **paired bootstrap** (B=10000) を推奨
- ペアになっていない (run 単位) 場合は **Wilcoxon signed-rank** または **paired t-test** (正規性が満たせる場合)
- 効果量: **Cohen's d** (連続) or **Cliff's delta** (順序)
- 多重比較補正: ablation > 5 セルなら Holm-Bonferroni

## 報告フォーマット

results table は最低限以下を含む:

```
| Method     | MMLU    | BBH     | GSM8K   |
|------------|---------|---------|---------|
| baseline   | 65.3±0.4 | 50.1±0.6 | 72.4±0.5 |
| ours       | 67.1±0.3 | 51.8±0.5 | 73.9±0.4 |
| Δ (95% CI) | +1.8 [+1.1, +2.5]* | +1.7 [+0.9, +2.4]* | +1.5 [+0.8, +2.2]* |
```

`*` は paired bootstrap で p < 0.05、N seeds=3 以上。

## 計算予算超過時のフォールバック

`compute_budget_gpu_h` を超えそうな場合の優先順位:

1. **モデル小型化**: 70B → 8B / 7B base → small variants
2. **LoRA / QLoRA** で fine-tuning コストを抑える
3. **eval subset**: stratified sampling で 1000-3000 件に絞る (CI を必ず広めに報告)
4. **seed 削減**: 3 → 2 (有意性検定の検出力が落ちることを開示)
5. **ablation 軸を P0 のみに絞る**

これらを採用した場合は `04_EXPERIMENT_PLAN.md` の `## Compute Adjustments` 節に明記。
