---
description: "Gap 分析・アイディア抽出と実験設計 (Phase 3-4)。research-gap-finder ×3 並列 → experiment-designer。"
argument-hint: "[<slug>] (省略時は最新の active project)"
allowed-tools: [Read, Write, Edit, Bash, Glob, Agent]
---

研究ギャップ抽出と実験設計フェーズ。`auto-research` skill の Phase 3 と Phase 4 を実行。

## 前提条件

- `STATE.json.last_gate_passed == "G1"` (Phase 2 完了)
- `.research/<slug>/02_SURVEY/MATRIX.md` 存在

満たさない場合: 「Phase 2 が未完了です。`/auto-research:research-start` を先に実行してください」を表示して中断。

## 実行手順

1. **slug 解決**: `$ARGUMENTS` が空なら `.research/` 配下で `STATE.json.completed_at == null` の最新プロジェクトを探す。複数あればリストで選ばせる。

2. **Phase 3 (Gap & Ideation)**:
   - `research-gap-finder` を **3 並列 dispatch** (`seed_angle=A`, `B`, `C`)
   - 3 つの `03_GAP_ANALYSIS_{A,B,C}.md` を統合し `03_GAP_ANALYSIS.md` を作成
   - アイディアを `03_IDEAS.md` に novelty/feasibility/impact (1-5) でスコアリング
   - **Gate G2** (アイディア採択): ユーザーに採択番号を選ばせる

3. **Phase 4 (Experiment Design)**:
   - `experiment-designer` agent に採択 idea を渡して `04_EXPERIMENT_PLAN.md` を生成
   - reproducibility checklist 全項目を埋める
   - compute budget 検証 (`compute_budget_gpu_h` 内に収まっているか)
   - **Gate G3** (予算+設計合意): 数値を表示してユーザー承認

4. 承認後、`STATE.json.last_gate_passed = "G3"` に更新し、次は `/auto-research:research-experiment` を案内。

## 失敗モード

- novelty 低い idea しか出ない → Phase 2 にロールバック (キーワード再拡張)
- どう絞っても budget 2x 超 → smaller model / LoRA / subset eval を提案、それでも難しければ idea 再選 (Phase 3 ロールバック)

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
