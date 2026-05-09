---
description: "現在の研究プロジェクトの進行状況 (Phase / Gate / 直近 run / 次アクション) を表示。STATE.json を直接読む。"
argument-hint: "[<slug>] (省略時は active project 一覧)"
allowed-tools: [Read, Bash, Glob]
---

研究プロジェクトの状態確認コマンド。skill を経由せず `.research/*/STATE.json` を直接読む軽量コマンド。

## 実行手順

1. **slug 解決**:
   - `$ARGUMENTS` が空 → `.research/*/STATE.json` を全て読み、active (`completed_at == null`) と完了の一覧を表示
   - `$ARGUMENTS = <slug>` → 該当プロジェクトの詳細表示

2. **詳細表示** (slug 指定時):

```text
Research Project: {slug}
─────────────────────────────────────
Created:        2026-05-09T10:00:00Z
Updated:        2026-05-09T14:23:00Z
Focus Area:     attention
Paper Format:   latex-neurips

Current Phase:  4 / 8
Last Gate:      G3 (passed 2026-05-09T14:20:00Z)
Adopted Idea:   #2

Time Budget:    14 days  (consumed: ~3 days)
Compute Budget: 200 GPU-h (consumed: 0 GPU-h)

Active Runs:    none
Latest Run:     none yet (Phase 5 で生成)

Rollbacks:      0

Artifacts:
  ✓ 01_BRIEF.md
  ✓ 02_SURVEY/MATRIX.md (15 papers)
  ✓ 03_IDEAS.md (3 ideas, adopted: #2)
  ✓ 04_EXPERIMENT_PLAN.md
  ✗ code/                    (next: /auto-research:research-experiment)
  ✗ 06_RESULTS.md
  ✗ paper/

Next Action: /auto-research:research-experiment {slug}
```

3. **一覧表示** ($ARGUMENTS 空時):

```text
Active Projects (.research/):
  1. attention-sink-llama-long-ctx  Phase 4/8  G3 passed
  2. mmlu-prompt-eval-2026          Phase 7/8  Phase 6 完了
  3. icl-induction-heads            Phase 1/8  G0 (未承認)

Completed (last 5):
  - rlhf-vs-dpo-mmlu-2026  ✓ 2026-04-12
  - ...

Use: /auto-research:research-status <slug> for details
```

## 実装ガイド

軽量に実装するため Bash ヘルパーを使う:

```bash
for f in .research/*/STATE.json; do
  jq -r '[.project_slug, .current_phase, .last_gate_passed, .completed_at] | @tsv' "$f"
done
```

詳細表示は `Read` で `STATE.json` を読み、関連 .md ファイルの存在を `Glob` で確認。
