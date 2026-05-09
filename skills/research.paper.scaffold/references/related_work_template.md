# Related Work paragraph generation rules

`research.paper.scaffold` が `02_SURVEY/MATRIX.md` から DRAFT.md の `### 1.2 Related Work` を生成するルール (SoT)。

## ステップ

### 1. Sub-area グループ化

`02_SURVEY/MATRIX.md` の "Method カテゴリ" 列 (or note の `## Method` フィールド) を集計し、3-5 グループに分類する。
各グループは Related Work の 1 paragraph になる。

例 (5 papers, 4-class subset of `02_SURVEY/MATRIX.md`):

| paper | method category | sub-area |
|-------|----------------|----------|
| 2403.07974 | chat template ablation | Format effect on LLM evaluation |
| 2406.14045 | few-shot order ablation | Format effect on LLM evaluation |
| 2310.19956 | prompt optimization (IRL) | Prompt optimization |
| 2407.03963 | decoding setting ablation | Compute-aware evaluation |
| 2401.06766 | subset selection | Compute-aware evaluation |

→ 3 sub-area: "Format effect", "Prompt optimization", "Compute-aware evaluation"

### 2. Sub-area ごとの paragraph 構造

```markdown
**{Sub-area name}**: {Paper A note 由来 1 文}~\cite{authorA}. {Paper B note 由来 1 文}~\cite{authorB}. {Optional: contrast / synthesis 1 文}.
```

各 paragraph 50-120 words。Paper 1 つあたり 1-2 文。

### 3. Note からの引用ルール

`02_SURVEY/notes/<id>.md` の以下フィールドを使う:
- `## Method` の 1-2 文 → 何をしたか
- `## Claim` の 1 文 → 何を示したか
- `## Our Relevance` の 1 文 → どう関係するか (paragraph 末尾の synthesis に使う)

**verbatim copy 禁止** (`responsible_research.md` の引用 ≤ 2 文ルール準拠)。要約 + paraphrase。

### 4. Position of our work paragraph (必須)

Related Work の **末尾** に明示的な position 段落を入れる:

```markdown
**Position of our work**: While prior work studies these axes in isolation, we are the first to integrate {axes A, B, C} into a single ablation matrix and quantify their relative variance contributions. Our protocol differs from {key prior work} in that {one specific differentiator}.
```

これにより reviewer が「貢献位置」を一読で把握できる。

## 出力例 (full Related Work、5 papers)

```markdown
### 1.2 Related Work

**Format effect on LLM evaluation**: Hong et al.~\cite{hong2024chat} report that prompt format choice introduces 2-5pt variance in MMLU scores across four models, with the canonical chat template not always outperforming alternatives. Liu et al.~\cite{liu2024robustness} extend this analysis to perturbation studies, showing few-shot ordering alone contributes >1pt variance and that order × format interaction is unstudied.

**Prompt optimization**: Sun et al.~\cite{sun2023prompt} use inverse reinforcement learning to search for optimal prompts, achieving +3pt on MMLU. While effective for leaderboard pursuit, this work tunes the prompt rather than asking what a *fair* comparison looks like.

**Compute-aware evaluation**: Wang et al.~\cite{wang2024decoding} show that decoding settings (greedy vs. sampling) dominate variance on BIG-bench Hard, recommending greedy as the most reproducible choice. Patel et al.~\cite{patel2024sample} demonstrate that subset selection for benchmark efficiency introduces 1-3pt variance, with stratified sampling outperforming uniform.

**Position of our work**: While prior work studies format, order, decoding, and subset selection in isolation — each finding meaningful variance — no work has integrated them into a single protocol or quantified their relative contributions. Our 4-factor protocol fills this gap, enabling fair model comparisons that account for all four sources of variability simultaneously.
```

## アンチパターン

- ❌ 全 paper を時系列順に列挙 (グループ化なし、読みづらい)
- ❌ "X et al. (2024) did Y" 構文を全 paper に繰り返し (冗長)
- ❌ Position paragraph を省略 (reviewer に「で、貢献は何?」と思わせる)
- ❌ 5 paper 未満の MATRIX で Related Work を fabricate (papers が足りない場合は Phase 2 に戻る warning)
- ❌ verbatim copy from notes (引用 ≤ 2 文ルール違反)

## 多言語対応

paper.scaffold は **英語前提** で Related Work を生成 (NeurIPS/ACL/ICLR 等の標準)。
日本語 paper の場合は paper_format = `markdown-ja` 等を Phase 1 G1 で指定 (将来拡張、現状は英語のみ)。

## 失敗モード

| failure | 検出 | 回復 |
|---------|------|------|
| MATRIX 行数 < 3 | jq filter | warning + Related Work を TBD で残し Phase 2 に戻る提案 |
| Method カテゴリ列が空 | grep | sub-area 化を skip、全 paper を 1 group の paragraph に flatten |
| 同一 first author + year で複数 paper | bibtex キー uniqueness | refs_bib_growth.md の衝突解消ルールで suffix 付与 |
| Note ファイルが固定スキーマ違反 | grep `## Method` `## Claim` | フィールド欠落 paper を warning + 引用文短縮 |

## 関連

- 入力フォーマット: `skills/research.literature.matrix/references/paper_note_schema.md`
- 引用ルール: `skills/auto-research/references/responsible_research.md` (≤ 2 文 verbatim、商用 PDF 禁止)
- bibtex: `refs_bib_growth.md`
