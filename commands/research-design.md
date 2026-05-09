---
description: "Gap 分析・アイディア抽出と実験設計 (Phase 3-4)。research-gap-finder ×3 並列 → experiment-designer。"
argument-hint: "[<slug>] (省略時は最新の active project)"
allowed-tools: [Read, Write, Edit, Bash, Glob, Agent]
---

研究ギャップ抽出と実験設計フェーズ。`auto-research` skill の Phase 3 と Phase 4 を実行。

## 前提条件

- `STATE.json.last_gate_passed == "G1"` (Phase 2 完了)
- `.research/<slug>/02_SURVEY/MATRIX.md` 存在

満たさない場合: 「Phase 2 が未完了です。`/research:start` を先に実行してください」を表示して中断。

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

4. 承認後、`STATE.json.last_gate_passed = "G3"` に更新し、次は `/research:experiment` を案内。

## 失敗モード

- novelty 低い idea しか出ない → Phase 2 にロールバック (キーワード再拡張)
- どう絞っても budget 2x 超 → smaller model / LoRA / subset eval を提案、それでも難しければ idea 再選 (Phase 3 ロールバック)
