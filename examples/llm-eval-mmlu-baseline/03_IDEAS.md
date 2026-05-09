# Ideas

3 つのアイディアを novelty/feasibility/impact (1-5) でスコアリング。
G2 で **Idea 2** を採択。

---

## Idea 1: Open weights 3-8B での format ablation 単独再現

**Core hypothesis**: Llama-3.2-3B / Qwen2.5-7B / Phi-4-mini で 4 chat template の MMLU acc 差は paired bootstrap で有意 (Δ ≥ 1pt) に出る。

**Why now**:
- 関連: 2403.07974
- 未検証セル: 3-8B 系 × 直近モデル

**Proposed experiment**: 3 model × 4 format × 5 seed × 14042 questions の grid。

**Scoring**:
- novelty: 2 (単純な追試)
- feasibility: 5 (compute 余裕)
- impact: 2 (再現実験のみ)

**Risks**: 既知結果と整合的なら novelty が低い

**Estimated GPU-h**: 30

---

## Idea 2: Format × Order × Decoding × Subset 統合 protocol (採択)

**Core hypothesis**: 4 因子 (format, few-shot order, decoding, subset) を直交させて測定すると、各因子が leaderboard score に与える variance 寄与は format > order > decoding > subset の順に並び、合算 std は単一因子の +50% 以上になる。

**Why now**:
- 関連: 2403.07974, 2406.14045, 2407.03963, 2401.06766
- 矛盾: format と order の交互作用が未検証
- 隣接領域示唆: code evaluation でも format 効果が大きい

**Proposed experiment**:
- factor: format (4), few-shot order (3 perms), decoding (greedy / temp 0.7), subset (full / stratified 2000)
- 3 model × 4 × 3 × 2 × 2 = 144 cells × 3 seeds = 432 runs
- Llama-3.2-3B / Qwen2.5-7B / Phi-4-mini
- primary metric: 各因子の variance 寄与 (ANOVA-style decomposition) + paired bootstrap on format pairs

**Scoring**:
- novelty: 4 (4 因子統合は新しい)
- feasibility: 4 (compute 80h で 432 runs は subset 化で達成可能)
- impact: 4 (fair comparison checklist として実用)

**Risks**:
- compute budget 超過 (subset 化が必須)
- factor 間の交互作用が小さくて oversized claim になる

**Estimated GPU-h**: 65 (subset 化前提)

---

## Idea 3: prompt 最適化を使った leaderboard hack vs fair benchmark

**Core hypothesis**: Prompt-OIRL (2310.19956) を Llama-3.2-3B に適用した場合の MMLU acc は fair な protocol よりも +3-5pt 高くなり、leaderboard 競争のリスクを実証できる。

**Scoring**:
- novelty: 3
- feasibility: 3 (Prompt-OIRL の再実装が重い)
- impact: 3 (ethics / leaderboard quality 議論)

**Risks**: Prompt-OIRL 実装が paper の通り動かない

**Estimated GPU-h**: 45
