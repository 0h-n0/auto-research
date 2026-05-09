---
description: "新規 LLM 研究プロジェクトを開始 (Phase 1-2: Topic Framing + Literature Survey)。auto-research skill を起点として呼ぶ。"
argument-hint: "[研究テーマ | arXiv URL | --resume <slug>]"
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep, WebFetch, Agent]
---

LLM 研究の入口コマンド。`auto-research` skill を起動して Phase 1 (Topic Framing) と Phase 2 (Literature Survey) を実行する。

## 実行手順

1. `$ARGUMENTS` を確認:
   - `--resume <slug>` が含まれる → 既存プロジェクトの再開
   - `arxiv.org` URL → 起点論文として記録
   - それ以外 → 自然言語の研究テーマ

2. `auto-research` skill を invoke:
   - skill 内の Phase 1 (Topic Framing) を完走 → `01_BRIEF.md` を生成
   - **Gate G1** (スコープ確認) でユーザー承認を取る

3. 承認後、Phase 2 (Literature Survey) を自動継続:
   - `arxiv-mcp-agent` で breadth 検索 → `02_SURVEY/papers.jsonl`
   - `paper-deep-reader` を上位 3-5 本に **並列 dispatch** → `02_SURVEY/notes/*.md`
   - `research.literature.matrix` skill で `MATRIX.md` を生成

4. Phase 2 完了で報告:
   - 読解済み論文数
   - MATRIX.md のパス
   - 次は `/auto-research:research-design` (Phase 3-4) を実行する旨を案内

## 制約

- 1 つの Claude Code セッション内で完走することを期待 (中断時は `STATE.json` で `--resume` 可能)
- `compute_budget_gpu_h` が 0 の場合は Gate G1 で警告し再入力を促す
- 商用ジャーナル PDF はキャッシュしない (responsible_research.md 準拠)

## 引数

- `$ARGUMENTS = ""` → ユーザーに研究テーマを対話で聞く
- `$ARGUMENTS = "topic free text"` → そのテーマで Phase 1 を開始
- `$ARGUMENTS = "https://arxiv.org/abs/..."` → その論文を起点に Phase 1
- `$ARGUMENTS = "--resume <slug>"` → `.research/<slug>/STATE.json` から再開

## 失敗モード

- arxiv-mcp-server が未設定 → README に従って設定を促し中断
- `.research/` 書き込み権限なし → 親ディレクトリ確認を促し中断
- Phase 2 で論文が 5 本未満 → キーワード拡張を提案、ユーザー確認後に再検索
