# Hypothesis-Driven Abstract Template

`research.paper.scaffold` が DRAFT.md の Abstract section に書く 4 ブロック構造の仕様 (SoT)。

## 設計目的

伝統的な Abstract は「結果が出てから書く」ため、Phase 6 まで何も書けない。
**Hypothesis-driven** に書くと Phase 2-3 から下書きでき、検証すべき仮説が明確になる効果も得られる。

## 4 ブロック構造

```markdown
## Abstract

[Background] {2-3 文。問題の重要性 + ギャップ}

[Method] {3-5 文。提案手法の核 + どう動くか}

[Hypothesis (Phase 6 で検証予定)] {1-2 文。falsifiable な予測 + 統計的閾値}

[Implication (検証成立時)] {2-3 文。研究コミュニティへの含意 + 次の問い}
```

合計 200-250 words 目安 (NeurIPS/ACL 慣習)。

Phase 6 完了後、`[Hypothesis (Phase 6 で検証予定)]` ブロックを `[Result]` に置換:

```markdown
[Result] {1-2 文。実測値 + 統計検定結果}
```

## 各ブロックの仕様

### `[Background]`

- **目的**: 読者が興味を持ち、本論文が解く問題を 30 秒で把握できる
- **長さ**: 2-3 文
- **必須要素**:
  - 研究領域の現状 (1 文)
  - 既存手法の限界 / 未解決の問題 (1-2 文)
- **入力**: `01_BRIEF.md` の `Motivation` セクション

例:
```
LLM evaluation results vary by 2-5 percentage points depending on prompt format choice (Hong et al., 2024; Liu et al., 2024). Despite this fragility being well-documented, no unified protocol exists to fairly compare models across multiple prompting axes.
```

### `[Method]`

- **目的**: 提案手法の核を 1 段落で説明
- **長さ**: 3-5 文
- **必須要素**:
  - 手法の名前 (or 特徴づけ)
  - 入力と出力 (何を変えて何を改善するか)
  - 主要な innovation 1-2 点
- **入力 (Phase 3+)**: `03_IDEAS.md` の adopted Idea の `Core hypothesis` + `Proposed experiment`
- **入力 (Phase 4+)**: `04_EXPERIMENT_PLAN.md` の `RQ` と `Method` で refine

例 (Phase 3):
```
We propose a 4-factor fair-comparison protocol that combines format, few-shot order, decoding, and subset selection into a single ablation matrix. We measure each factor's variance contribution via ANOVA-style decomposition and report compute-aware effect sizes.
```

### `[Hypothesis (Phase 6 で検証予定)]`

- **目的**: 検証すべき主仮説を **falsifiable** な形で明示
- **長さ**: 1-2 文
- **必須要素**:
  - 主張する効果の方向と大きさ
  - 統計的有意性の閾値 (p-value or effect size)
  - 評価対象 (dataset / model)
- **入力 (Phase 3+)**: `03_IDEAS.md` の adopted Idea の `Core hypothesis`

例 (Phase 3):
```
We expect format to dominate variance contribution (≥30% of total) over the other three factors, with paired bootstrap p<0.05 across Llama-3.2-3B, Qwen2.5-7B, and Phi-4-mini.
```

**Phase 6 後の `[Result]` への置換例**:

```
We find that format contributes 35.2% of variance (95% CI [31.4, 39.8]), exceeding order (18.1%), decoding (12.4%), and subset selection (4.7%) by a wide margin (paired bootstrap p<0.001 after Holm-Bonferroni).
```

### `[Implication (検証成立時)]`

- **目的**: 仮説が成立した場合の研究コミュニティへのメッセージ
- **長さ**: 2-3 文
- **必須要素**:
  - 既存の常識 / 慣行が変わるべき点
  - 公開する成果物 (code / data / checklist 等)
  - 次の自然な研究の問い (1-2 個)
- **入力**: `01_BRIEF.md` の `Success Criteria` + `03_IDEAS.md` の `Impact` 評価

例:
```
If validated, this means leaderboard comparisons must report all four factors or at least their variance contributions; we release a 1-page fair-comparison checklist and lm-eval-harness extension. Future work should explore the same protocol for code-generation and reasoning benchmarks where prompt sensitivity is even larger.
```

## Phase ごとの更新ルール (idempotent)

| Phase | Abstract に対する処理 |
|-------|---------------------|
| 2 | `[Background]` + `[Implication]` (placeholder で先行) を書く |
| 3 | `[Method]` + `[Hypothesis]` を adopted Idea から書く |
| 4 | `[Method]` を `04_EXPERIMENT_PLAN.md` の精緻情報で refine |
| 6 | `[Hypothesis (Phase 6 で検証予定)]` を `[Result]` に置換 (実測値) |
| 7 | 全体を 1 段落の通常 Abstract 形式に「flatten」して LaTeX 化 (paper.draft 担当) |

## アンチパターン (避けるべき書き方)

- ❌ "We propose a novel approach to X" — "novel" は中身が空、何が novel かを書く
- ❌ "Our method achieves state-of-the-art" — Phase 6 前は実測値がないので実測値が出るまで書かない
- ❌ Result が出る前に断定的な過去形を使う ("we showed that ...")
- ❌ `[Hypothesis]` を vague (例: "improve performance") で書く — falsifiable に
- ❌ `[Implication]` で grand claim ("this revolutionizes the field") — 控えめに

## 文字数制限

- ACL: 250 words
- NeurIPS: ~250 words
- ICLR: ~300 words
- ICML: ~250 words

skill 内で `paper_format` (BRIEF.md or STATE.json) を見て上限を意識した出力を生成。
超過時は `[Implication]` から削る (情報密度低い順)。

## 例 (full Abstract、Phase 3 時点)

```markdown
## Abstract

**[Background]** LLM evaluation results vary by 2-5 percentage points depending on prompt format choice (Hong et al., 2024; Liu et al., 2024). Despite this fragility being well-documented, no unified protocol exists to fairly compare models across multiple prompting axes.

**[Method]** We propose a 4-factor fair-comparison protocol that combines format (4 levels), few-shot order (3 levels), decoding (2 levels), and subset selection (2 levels) into a single ablation matrix. We measure each factor's variance contribution via ANOVA-style decomposition and report compute-aware effect sizes via paired bootstrap.

**[Hypothesis (Phase 6 で検証予定)]** We expect format to dominate variance contribution (≥30% of total) over the other three factors, with paired bootstrap p<0.05 across Llama-3.2-3B, Qwen2.5-7B, and Phi-4-mini.

**[Implication (検証成立時)]** If validated, this means leaderboard comparisons must report all four factors or at least their variance contributions; we release a 1-page fair-comparison checklist and lm-eval-harness extension.
```
