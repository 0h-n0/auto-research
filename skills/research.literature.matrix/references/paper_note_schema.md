# Paper Note 固定スキーマ

`02_SURVEY/notes/<paper_id>.md` のテンプレート。`paper-deep-reader` agent はこの形式で出力する。

```markdown
# {paper_id} {title}

- arXiv: {url}
- year: {year}
- authors: {short}
- venue: {arXiv | NeurIPS | ICLR | ACL | ...}

## Problem
1-2 文で何の問題を解いているか。

## Method
3-5 文。記号は LaTeX inline (`$ ... $`) で書く。

## Equations / Algorithms
主要式 1-3 個。pseudocode があれば 3-10 行。

```math
\mathcal{L} = \mathbb{E}_{x \sim \mathcal{D}}[-\log p_\theta(x)]
```

## Dataset
- name: {例: MMLU}
- split: {train / val / test}
- size: {N samples}
- license: {例: CC-BY-4.0}

## Metric
{name + 定義}

## Setup
- model: {例: Llama-3-8B-Instruct}
- decoding: {greedy / temperature 0.7 / ...}
- compute: {例: 4× A100, 24h}

## Claim
{論文の主要主張、効果量、有意性}

## Limitation
- {自己申告 limitation}
- {読者として気付いた追加 limitation}

## Replicability Checklist
- [ ] code public: {url or no}
- [ ] checkpoints public: {url or no}
- [ ] data public: {url or no}
- [ ] seeds reported: {yes (N=?) / no}
- [ ] statistical test: {method or none}

## Our Relevance
1-3 文。本研究 (Brief.md) との関係。再利用できるアイディア、対比軸、ベースラインとして使うか。
```

## スキーマを破ってよい場合

- "Equations" セクション: 数式が論文の核ではない場合 (例: empirical study) はスキップ可
- "Setup": 論文に記載がない場合は `not reported` と書く
- "Replicability": 全項目を埋める。情報がない場合は `unknown` ではなく `not stated`

## 命名規則

- `paper_id`: arXiv ID (例: `2403.12345`)。venue 公式版がある場合は `arxiv-2403.12345-neurips24` のように suffix を付ける
- ファイル名: `02_SURVEY/notes/{paper_id}.md` (slash や colon は含めない)
