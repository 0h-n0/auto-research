# STATE.json と Phase 状態遷移

## STATE.json schema

`.research/<slug>/STATE.json` に以下を JSON で保持する。

```json
{
  "schema_version": 1,
  "project_slug": "string",
  "created_at": "ISO8601 UTC",
  "updated_at": "ISO8601 UTC",
  "current_phase": 1,
  "last_gate_passed": "G0|G1|G2|G3|G4",
  "focus_area": "evaluation|agent|post-training|prompt|attention|other",
  "paper_format": "latex-neurips|latex-acl|markdown",
  "time_budget_days": 0,
  "compute_budget_gpu_h": 0,
  "adopted_idea_id": null,
  "active_run_ids": [],
  "completed_at": null,
  "rollbacks": [
    {"from_phase": 6, "to_phase": 5, "reason": "sanity failure on metric X", "ts": "..."}
  ]
}
```

`schema_version` は将来の互換性のため。`G0` は初期状態 (Phase 1 未完)。

## 正方向の遷移

```
[init] → Phase 1 → G1 → Phase 2 → Phase 3 → G2 → Phase 4 → G3
       → Phase 5 → Phase 6 → Phase 7 → Phase 8 → G4 → [completed]
```

## Rollback edges (許可されるもの)

| from | to | trigger |
|------|----|---------|
| G2 | Phase 2 | novelty 不足、検索軸直交化が必要 |
| G3 | Phase 4 | 予算超過、scope 縮小 (同じ Phase で再設計でもよい) |
| G3 | Phase 3 | アイディア再選 (G3 で根本的に違うと判断したとき) |
| Phase 6 | Phase 5 | sanity check 失敗、実装バグ |
| G4 | Phase 6 | 追加 ablation が必要 |
| G4 | Phase 4 | 設計レベルの問題、再設計+再実行 |
| G4 | Phase 7 | レビューコメント反映だけで OK |

**禁止**: Phase 5 → Phase 1 のような Brief 再定義。それは新プロジェクト (`/research-start` を再実行) として扱う。

## ロールバックの記録

ロールバックは `STATE.json.rollbacks` 配列にエントリ追加し、同時に `.research/<slug>/CHANGELOG.md` に人間可読な 1 行を追記:

```
2026-05-09T14:23:00Z: rolled back from Phase 6 → 5 (sanity failure: MMLU baseline 0.42 vs expected 0.55±0.02)
```

## 並列実行の境界

以下は明示的に並列実行可:

- Phase 2 の `paper-deep-reader` (異なる paper_id ごと)
- Phase 3 の `research-gap-finder` (seed違い ×3)
- Phase 6 の analysis (`result-statistician`, `attention-analyst`)
- Phase 7 の章ごと paper drafting

並列のとき **書き込み先ファイルが衝突しないこと** が必須。`papers.jsonl` を mutex (claim 列) として使う場合は Phase 2 のみ。

## 再開フロー (`--resume <slug>`)

1. `.research/<slug>/STATE.json` を読み込む。存在しなければエラー。
2. `current_phase` が `completed_at` ありなら「完了済み」表示で終了。
3. `last_gate_passed` から次のステップを決定:
   - `G0` (Phase 1 未完) → Phase 1 から再開
   - `G1` → Phase 2 から再開
   - `G2` → Phase 4 から再開
   - `G3` → Phase 5 から再開
   - `G4` → 完了済み扱い
4. 中間 phase (Phase 5/6/7) の途中で中断していた場合は、そのフェーズの先頭から再実行 (idempotent な phase 設計を前提とする)。
