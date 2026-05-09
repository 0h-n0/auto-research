---
description: "Self-Review (Phase 8)。research-gap-finder を reviewer モードで invoke + gemini で最新差分確認。Gate G4 で公開判断。"
argument-hint: "[<slug>] (省略時は最新の active project)"
allowed-tools: [Read, Write, Edit, Bash, Glob, Agent]
---

セルフレビューフェーズ。`auto-research` skill の Phase 8 を実行。

## 前提条件

- `paper/main.{tex,md}` 存在 (Phase 7 完了)

## 実行手順

1. **Reviewer dispatch**:
   - `Agent(subagent_type="research-gap-finder")` を `mode=reviewer` で起動
   - 入力: `paper/main.{tex,md}`, `06_RESULTS.md`, `04_EXPERIMENT_PLAN.md`
   - 観点: Soundness / Presentation / Contribution / Reproducibility (1-5 採点)
   - 出力: `08_REVIEW.md` (major / minor concerns + reviewer-likely-questions)

2. **最新差分確認** (並列):
   - `gemini` skill で「直近 1 週間の関連最新論文」を web search
   - ヒットがあれば Related Work に追加候補として `08_REVIEW.md` の `## Recent Related Work` 節に付記

3. **Gate G4** — 公開判断:

```
🟢 Gate G4: 公開判断

セルフレビュー完了:
  Soundness:        {score}/5  {主要懸念 1 行}
  Presentation:     {score}/5
  Contribution:     {score}/5
  Reproducibility:  {score}/5

Major Concerns: {N} 件
Reviewer-likely Questions: {M} 件
Recent Related Work (last week): {K} 件 (要確認)

[Y] 公開 (CHANGELOG.md にリリース記録、STATE.json.completed_at 設定、終了)
[I] 致命的問題を修正 (Phase 4 または 6 にロールバック)
[E] レビューコメントだけ反映してもう 1 周 (Phase 7 へ戻る)
[Q] 中断 (現状凍結、後日 --resume で復帰可)
```

4. ユーザー選択に応じて分岐:
   - `Y` → `STATE.json.completed_at` を ISO8601 で設定、`CHANGELOG.md` に entry を追加
   - `I` → ロールバック先 phase を聞き、`STATE.json` を巻き戻し、`CHANGELOG.md` 記録
   - `E` → Phase 7 から再ドラフト (差分 review コメントだけ反映)
   - `Q` → 何もせず終了

## 出力

- `.research/<slug>/08_REVIEW.md`
- `.research/<slug>/CHANGELOG.md` (公開 or rollback 記録)

## 失敗モード

- gemini skill が応答なし → 最新差分確認をスキップ、その旨を `08_REVIEW.md` に記録
- reviewer が致命的問題を 5 件以上指摘 → 自動的に `[I]` を推奨、ロールバック先候補を 1-2 個提示
