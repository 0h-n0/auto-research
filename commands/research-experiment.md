---
description: "実験スキャフォールド (TDD) と本番実行 (Phase 5-6)。ml-engineer + research.experiment.run + result-statistician + (attention-analyst)。"
argument-hint: "[<slug>] (省略時は最新の active project)"
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep, Agent]
---

実装+本番実行フェーズ。`auto-research` skill の Phase 5 と Phase 6 を実行。

## 前提条件

- `STATE.json.last_gate_passed == "G3"`
- `04_EXPERIMENT_PLAN.md` 存在

## 実行手順

### Phase 5: Scaffold + Baseline TDD

1. `research.experiment.scaffold` skill で `.research/<slug>/code/` に uv プロジェクト雛形を生成
2. **Red phase** (TDD): test_data, test_model, test_metrics, test_contamination が **意図的に** 失敗する状態
3. `superpowers:test-driven-development` skill を invoke して規律を確認
4. **Green phase**: `Agent(subagent_type="ml-engineer")` に実装を委任
   - 全テスト緑になるまで実装
5. **ベースライン実行**: 1 seed でベースライン run、`uv run pytest -q` 全パス、metric が sanity range 内

### Phase 6: Run & Analysis

6. `research.experiment.run` skill で ablation matrix を展開し全 cell × seed を実行
   - `hooks/post-experiment-log.sh` (PostToolUse hook) が `events.jsonl` を自動記録
   - 失敗 run は `STATUS=failed` で残す
7. 全実行完了後、**並列 dispatch**:
   - `Agent(subagent_type="result-statistician")` → `06_RESULTS.md`, `figures/*.pdf`
   - (focus_area=attention のみ) `Agent(subagent_type="attention-analyst")` → `06_RUNS/attention/<probe_id>.md`

8. 進捗を表示し、次は `/research:write` (Phase 7) を案内。

## sanity check 失敗時

5 cell 連続で sanity 失敗 → Phase 5 にロールバック。`CHANGELOG.md` に記録。

## 失敗モード

- ml-engineer が tests を緑にできない → 失敗テストの内容を表示し、設計の問題か実装の問題か切り分けを促す
- GPU OOM → batch size 縮小、attn_impl=`sdpa` 強制、それでもダメなら smaller model に fallback
- 実行が予算超過 → 残り cells を P0 のみに縮小して継続、`CHANGELOG.md` に記録
