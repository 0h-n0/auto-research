---
name: research.literature.matrix
description: >
  論文ノートを固定スキーマで集約し method × dataset × metric の比較表 (MATRIX.md) と
  機械可読インデックス (papers.jsonl) を生成する。並列読解時の重複を防ぐため papers.jsonl を
  mutex として claim 列で管理する。
  Use when: auto-research Phase 2 後半、複数の paper-deep-reader 結果を統合するとき、
  または既存サーベイに新規論文を追加するとき。
---

# `research.literature.matrix`

`auto-research` Phase 2 でサーベイ結果を集約する補助スキル。

## 入力 / 出力

入力:
- `.research/<slug>/02_SURVEY/papers.jsonl` (arxiv-mcp-agent が生成した候補 JSONL)
- `.research/<slug>/02_SURVEY/notes/<paper_id>.md` (paper-deep-reader が生成した深掘りノート)

出力:
- `.research/<slug>/02_SURVEY/MATRIX.md` (Markdown 比較表)
- `.research/<slug>/02_SURVEY/papers.jsonl` (claim 列を更新)

## papers.jsonl スキーマ

1 行 1 論文。並列実行のため `claim` 列で重複防止。

```json
{
  "id": "2403.12345",
  "title": "Attention Sink in Long-Context LLMs",
  "year": 2024,
  "authors_short": "Doe et al.",
  "venue": "arXiv",
  "url": "https://arxiv.org/abs/2403.12345",
  "abstract_summary": "1-2 文要約",
  "our_relevance": "なぜこの研究に関係するか 1 文",
  "claim": null,
  "deep_read_at": null,
  "note_path": null
}
```

paper-deep-reader を dispatch する際に `claim` を担当 agent ID で更新し、完了したら `deep_read_at` (ISO8601) と `note_path` を更新する。

## paper note 固定スキーマ

`02_SURVEY/notes/<paper_id>.md` は以下のスキーマで生成:

```markdown
# {paper_id} {title}

- arXiv: {url}
- year: {year}
- authors: {short}
- venue: {arXiv | NeurIPS | ...}

## Problem
{1-2 文}

## Method
{3-5 文。可能なら主要方程式を 1-3 個 inline で}

## Equations / Algorithms
- $\\mathcal{L}_{\\text{loss}} = \\dots$
- Algorithm pseudocode (3-10 行) があれば

## Dataset
{name, split, size}

## Metric
{primary metric とその定義}

## Claim
{論文の主張: モデル X が Y で Z を達成、有意差 yes/no}

## Limitation
- {限界 1}
- {限界 2}

## Replicability Checklist
- [ ] code public: {url or no}
- [ ] checkpoints public: {url or no}
- [ ] data public: {url or no}
- [ ] seeds reported: {yes/no}
- [ ] CI / 統計検定: {yes/no/method}

## Our Relevance
{1-3 文。本研究にどう関係するか、再利用可能なアイディアは何か}
```

固定スキーマを守ることで MATRIX.md 生成が機械的にできる。

## MATRIX.md 生成

```markdown
# Literature Survey Matrix

| ID | Year | Method 概要 | Dataset | Metric | 主張 | replicability |
|----|------|------------|---------|--------|------|----------------|
| 2403.12345 | 2024 | {method 1 行} | MMLU, BBH | acc | +1.5pt | code+ckpt |
| ... | ... | ... | ... | ... | ... | ... |

## カバレッジ分析

- Dataset カバー: MMLU (5本), BBH (3本), GSM8K (2本), ...
- Method カテゴリ: SFT (4本), RLHF (3本), DPO (2本), ...
- 未検証セル (gap): {例: GSM8K × DPO は 1 本のみ}

## 主要 contradictions / open questions

- {例: 論文 A は MMLU で +2pt、論文 B は -1pt → reproducibility 検証が必要}
```

## 実装ガイド

1. `papers.jsonl` を全件読み込む
2. `notes/` 配下の `.md` を全件読み、各セクション (`## Method`, `## Dataset`, ...) を正規表現でパース
3. 表の各行を生成。データ欠損は `?` または `n/a`
4. カバレッジ分析: dataset と method category のヒストグラム
5. 主要 contradictions: 同じ dataset で逆方向の主張をしている論文ペアを抽出
