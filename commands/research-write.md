---
description: "結果から論文ドラフト生成 (Phase 7)。research.paper.draft skill で章ごと並列ドラフト + Semantic Scholar による refs.bib 補完。"
argument-hint: "[<slug>] (省略時は最新の active project)"
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep, WebFetch, Agent]
---

論文ドラフト生成フェーズ。`auto-research` skill の Phase 7 を実行。

## 前提条件

- `06_RESULTS.md` 存在
- `06_RUNS/*/metrics.json` が完了している (Phase 6 完了)

## 実行手順

1. **形式分岐**: `01_BRIEF.md` の `paper_format` を読む:
   - `latex-neurips` → NeurIPS スタイルで雛形展開
   - `latex-acl` → ACL スタイル
   - `markdown` → Markdown

2. **章ごと並列ドラフト** — `research.paper.draft` skill を起動。
   - main thread 内で Task 並列を使って章を分担:
     - Abstract / Intro / Related Work / Method / Experiments / Results / Discussion / Limitations
     - (focus_area=attention) Mechanistic Analysis 章を追加
   - 各章は `paper/sections/<chapter>.{tex,md}` に書き、main から include

3. **用語・記号統合パス**: 並列ドラフト後に notation, terminology, 参照番号を整理

4. **関連研究の最終確認**: `Agent(subagent_type="arxiv-mcp-agent")` で「直近 3 ヶ月の関連最新論文」を検索し Related Work に追補

5. **refs.bib 補完**: Semantic Scholar MCP で DOI / venue を補完。bibtex キーは `{first_author_lastname}{year}{first_word_of_title}` 形式

6. **AI 利用開示**: `paper/ai_disclosure.{tex,md}` を必ず include

7. **(LaTeX のみ) ビルド試行**: `pdflatex` を 2-3 回回し、エラーがあれば `paper/build_errors.log` に保存

8. 進捗報告し、次は `/auto-research:research-review` を案内。

## 出力

- `paper/main.{tex,md}`
- `paper/sections/{abstract,introduction,related_work,method,experiments,results,discussion,limitations,ai_disclosure}.{tex,md}`
- `paper/refs.bib`
- `paper/figures/`

## 失敗モード

- pdflatex 未インストール → ビルドはスキップし `.tex` のみ出力、メッセージで案内
- Semantic Scholar API レート制限 → 取得済みエントリのみで refs.bib を作成、不足分は arXiv ID から手動 bibtex 生成
- 結果が null result → Discussion / Limitations 重視のドラフトに切り替え (negative result paper 扱い)

## 完了時の出力 (必須)

このコマンドの**最後**に必ず next-step trailer を出力する。**スキップ不可**。

1. `.research/<slug>/STATE.json` を Read (なければ「STATE.json 不在」分岐へ)
2. プラグイン同梱の `skills/auto-research/references/next_steps_template.md`
   (§2 マッピング表 + §3 特殊状態) に従って「推奨」と「代替」を決定
3. §1 の literal フォーマットで出力:
   - `─` 罫線 (U+2500 を 37 個)
   - `[Phase {N}/8] {●×N + ○×(8-N)}  {gate_marker}`
   - `→ 推奨: ...` と `代替: ...`
   - 直前に空行 1 個、コードブロックの中に入れない

特殊状態 (sanity 失敗、G4 ロールバック、複数 active project、全 run 失敗、完了プロジェクト)
は §3 を参照して優先適用する。不変条件は §5 を厳守。
