---
name: research.paper.draft
description: >
  06_RESULTS.md と 02_SURVEY/MATRIX.md から論文ドラフトを LaTeX (NeurIPS/ACL) または
  Markdown で生成する。章ごとに並列ドラフト → 用語/記号統合 → refs.bib (Semantic Scholar 補完)。
  AI 利用開示節を必ず含める。
  Use when: auto-research Phase 7、06_RESULTS.md と 06_RUNS/*/metrics.json が揃った後。
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebFetch, Agent
---

# `research.paper.draft`

`auto-research` Phase 7 の論文ドラフト生成スキル。

## 入力 / 出力

入力:
- `.research/<slug>/01_BRIEF.md` (paper_format で latex-neurips / latex-acl / markdown を分岐)
- `.research/<slug>/04_EXPERIMENT_PLAN.md`
- `.research/<slug>/06_RESULTS.md` + `06_RUNS/*/metrics.json`
- `.research/<slug>/02_SURVEY/MATRIX.md` + `02_SURVEY/notes/*.md`
- (focus_area=attention の場合) `.research/<slug>/code/analysis/<slug>.py` の結果

出力:
- `.research/<slug>/paper/main.{tex,md}`
- `.research/<slug>/paper/refs.bib`
- `.research/<slug>/paper/figures/` (06_RUNS/figures から symlink or copy)
- `.research/<slug>/paper/sections/` (章ごとのドラフト、main から \input)

## ステップ

### 1. paper_format で雛形分岐

| paper_format | 雛形ファイル |
|--------------|-------------|
| `latex-neurips` | `references/paper_skeleton.tex` |
| `latex-acl` | `references/paper_skeleton.tex` (ACL command set に書き換え) |
| `markdown` | `references/paper_skeleton.md` |

雛形を `paper/main.{tex,md}` にコピーし、`{title}`, `{authors}`, `{abstract}` 等を置換。

### 2. 章ごと並列ドラフト

以下の章を **1 メッセージ複数 Task で並列** ドラフト (Task tool ベース、subagent ではなく main thread で sub-task として):

- Abstract (200-250 words, structured)
- Introduction (motivation, contributions, RQ)
- Related Work (02_SURVEY/MATRIX.md ベース)
- Method (04_EXPERIMENT_PLAN.md ベース、図を含める)
- Experiments (setup, baselines, ablation)
- Results (06_RESULTS.md の表 + 統計検定)
- Discussion (主要 finding 3 つ、reasonable bias)
- Limitations (compute / scope / generalization)
- (focus_area=attention) Mechanistic Analysis 章を追加

各章は `paper/sections/<chapter>.{tex,md}` に書き、`main` から include する。

### 3. 用語・記号統合パス

並列ドラフト後の問題 (用語不一致など) を解消:

- 主要記号 (例: $\\theta$, $\\mathcal{D}$) を `paper/notation.{tex,md}` で一覧化
- 用語 (例: "in-context learning" vs "ICL") の使用統一
- 参照番号 (Tab. 1, Fig. 2) の整合
- bibtex キーの conflict 解消

### 4. 関連研究の最終確認

`Agent(subagent_type="arxiv-mcp-agent")` で「直近 3 ヶ月の関連最新論文」を再検索し、Related Work に追補:

```
arxiv-mcp-agent への依頼:
  目的: paper Related Work セクションの最新性確認
  検索クエリ: {focus_area + main keywords from 04_EXPERIMENT_PLAN.md}
  期間: 直近 3 ヶ月
  既存サーベイ: 02_SURVEY/papers.jsonl (claim 済みは除外)
  出力: 追加候補 N 本 (5本以下) と Related Work への組み込み案
```

### 5. refs.bib 生成

すべての引用を Semantic Scholar MCP で DOI / venue 補完:

```
mcp__semantic_scholar__paper_search → DOI 取得
→ refs.bib に bibtex エントリを書き出し
```

bibtex キー命名: `{first_author_lastname}{year}{first_word_of_title}` (例: `vaswani2017attention`)

### 6. 図表

- `06_RUNS/figures/*.pdf` を `paper/figures/` に symlink or copy
- 各図にキャプション (`paper/figures_captions.{tex,md}`)
- 表は `06_RESULTS.md` の Markdown 表を LaTeX 表に変換 (`pandoc` 使えるなら使用)

### 7. AI 利用開示

`paper/ai_disclosure.{tex,md}` を `references/paper_skeleton.{tex,md}` から展開し、`main` から include。

### 8. ビルド確認 (LaTeX のみ)

```bash
cd .research/<slug>/paper
pdflatex -interaction=nonstopmode main.tex || true
bibtex main || true
pdflatex -interaction=nonstopmode main.tex || true
pdflatex -interaction=nonstopmode main.tex || true
```

エラーが出れば `paper/build_errors.log` に保存し、報告 (Phase 7 完了時に伝える)。

### 9. 進捗表示

```
[Phase 7/8] Paper Drafting 完了
  paper/main.{tex|md}: N 章ドラフト
  refs.bib: M エントリ (DOI 補完率: K%)
  figures: P 個
  build: ok / failed (詳細 build_errors.log)
  次: Phase 8 (Self-Review)
```
