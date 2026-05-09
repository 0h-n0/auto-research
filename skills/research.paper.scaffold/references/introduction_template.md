# Introduction Template (3 sub-sections)

`research.paper.scaffold` が DRAFT.md の Introduction section に書く 3 sub-section 構造の仕様。

## 構造

```markdown
## 1. Introduction

### 1.1 Motivation         (Phase 2+ 充足)

### 1.2 Related Work       (Phase 2+ 充足、MATRIX-derived)

### 1.3 Contributions      (Phase 3+ 充足、IDEAS-derived)
```

合計 800-1500 words 目安 (4 ページ論文なら 1000 words 強)。

## 1.1 Motivation (Phase 2+ で書く)

### 目的

読者を 3 段論法で Related Work に橋渡しする:
1. 領域は重要
2. 現状の解決策には限界
3. 我々はこの限界を埋める

### 構造 (4 paragraph、合計 250-400 words)

| 段落 | 内容 | 入力ソース |
|------|------|-----------|
| 1 | 領域の重要性 / 現実的なインパクト | `01_BRIEF.md` `Motivation` |
| 2 | 既存手法の概観 (Related Work への接続) | `02_SURVEY/MATRIX.md` のカバレッジ要約 |
| 3 | ギャップ / 矛盾の指摘 | `02_SURVEY/MATRIX.md` の "未検証セル" or "矛盾" |
| 4 | 我々の問い (research question) と一行サマリー | `01_BRIEF.md` `Success Criteria` |

### 例

```markdown
### 1.1 Motivation

LLM evaluation has become the de facto signal for comparing foundation models, with leaderboards driving model release decisions and influencing billion-dollar GPU allocations. Yet recent work has shown these benchmark scores are alarmingly fragile to seemingly minor experimental choices.

Existing studies of this fragility have addressed prompt format (Hong et al., 2024), few-shot ordering (Liu et al., 2024), and decoding settings (Wang et al., 2024) in isolation. Each finds variance comparable to claimed model improvements, but no work has quantified how these factors interact or which dominates.

This isolation is problematic: a leaderboard "win" of +1pp could entirely be format luck if format variance is on that order. Without a unified protocol, model rankings are practically meaningless when reported with single-format evaluation.

We ask: which evaluation factor contributes the most variance, and how do they compose? Our answer enables principled fair-comparison protocols that we hope will become standard practice.
```

## 1.2 Related Work (Phase 2+ で書く)

### 目的

`02_SURVEY/MATRIX.md` の papers を **sub-area グループ化** + 各 paper を 1-2 文で要約 + 我々の貢献位置を明示。
詳細仕様は `related_work_template.md` を参照。

### 構造 (3-5 paragraph、合計 300-600 words)

各 paragraph = 1 sub-area。Sub-area は MATRIX.md の "Method カテゴリ" 列から抽出。

| 段落 | 役割 | 例 |
|------|------|-----|
| 1 | 主要な sub-area A | "Format effect on LLM evaluation" |
| 2 | 関連 sub-area B | "Compute-aware evaluation" |
| 3 | 関連 sub-area C (任意) | "Multi-factor variance studies" |
| 末尾 | **Position of our work** (1 段落、明示的) | "While prior work studies these axes in isolation, we are the first to ..." |

### Citation 形式

inline `\cite{key}` (LaTeX 化前は `[Hong et al., 2024]` でも可、Phase 7 で paper.draft が変換)。
key は `firstauthor{year}firstword` (refs_bib_growth.md 参照)。

## 1.3 Contributions (Phase 3+ で書く)

### 目的

**3-4 bullet** で contribution を列挙。各 bullet は **1 hypothesis に対応** (検証可能性を担保)。

### 構造

```markdown
### 1.3 Contributions

This paper makes the following contributions:

1. **{Contribution 1 short title}**: {1-2 文の要約}.
   We hypothesize that {H1: falsifiable claim}.

2. **{Contribution 2}**: ...
   We hypothesize that {H2: ...}.

3. **{Contribution 3}**: ...
   {Optional: more methodological / engineering contributions}

4. **{Public artifacts}** (任意): code / dataset / checklist / lm-eval-harness extension 等。
```

### 入力ソース

`03_IDEAS.md` の adopted Idea の `Core hypothesis` を直接 H1 に変換。
他の hypothesis (H2, H3) は `04_EXPERIMENT_PLAN.md` の Hypotheses 節から (Phase 4 後)。

### 例

```markdown
### 1.3 Contributions

This paper makes the following contributions:

1. **A unified 4-factor fair-comparison protocol** for LLM evaluation, integrating format, order, decoding, and subset selection. We hypothesize (H1) that format dominates variance contribution (≥30% of total) across modern open-weights 3-8B models.

2. **Empirical variance decomposition** on Llama-3.2-3B, Qwen2.5-7B, and Phi-4-mini using MMLU. We hypothesize (H2) that the four factors compose super-additively, with combined std exceeding any single factor's std by ≥50%.

3. **A reproducible reference implementation** as an lm-eval-harness extension, with seed/decoding pinning and a 1-page fair-comparison checklist for paper authors and leaderboard maintainers.
```

## Phase ごとの更新ルール (idempotent)

| Phase | Introduction に対する処理 |
|-------|--------------------------|
| 2 | 1.1 Motivation + 1.2 Related Work を書く。1.3 は TBD placeholder |
| 3 | 1.3 Contributions を adopted Idea から書く。1.1 / 1.2 は touch しない (人手 polish 尊重) |
| 4 | (no change in Introduction; method 系は §2 へ) |
| 6 | (no change in Introduction) |
| 7 | paper.draft が flow / 用語統一 / inline citation → \cite 変換 |

## アンチパターン

- ❌ 1.1 Motivation で 5 paragraph 以上書く (冗長)
- ❌ 1.2 Related Work で MATRIX papers 全部を 1 paragraph に詰め込む (グループ化必須)
- ❌ 1.3 Contributions を falsifiable でない claim で書く ("we improve X")
- ❌ Related Work で **批判のみ** (建設的 contribution position が必要)
- ❌ 自分の貢献を **Related Work paragraph 内** に埋め込む (1.3 で明示する)

## 引用ルール (responsible_research.md 準拠)

- 各 paper の note (`02_SURVEY/notes/<id>.md`) の Method / Claim / Our Relevance フィールドから **1-2 文要約**
- 原文 verbatim copy 禁止 (≤ 2 文ルール、商用 PDF キャッシュ禁止)
- 全 cited paper は refs.bib に entry 必須 (paper.scaffold が自動 sync)
