---
name: research.experiment.run
description: >
  ablation 全 cell × 複数 seed で実験を実行し、各 run を `06_RUNS/<run_id>/` に
  config.yaml + metrics.json + events.jsonl + STATUS で保存する。
  失敗 run も破棄せず STATUS=failed で残す。再現性 (run_id, git rev, config hash) を強制。
  Use when: auto-research Phase 6、04_EXPERIMENT_PLAN.md のベースラインが Phase 5 で通った後。
---

# `research.experiment.run`

`auto-research` Phase 6 の本番実行スキル。

## 入力 / 出力

入力:
- `.research/<slug>/04_EXPERIMENT_PLAN.md` (ablation 軸 + seeds)
- `.research/<slug>/code/configs/base.yaml` (baseline 設定)

出力:
- `.research/<slug>/06_RUNS/<run_id>/config.yaml` (Hydra resolved config)
- `.research/<slug>/06_RUNS/<run_id>/config.json` (RunConfig dump)
- `.research/<slug>/06_RUNS/<run_id>/metrics.json` (primary + secondary metrics)
- `.research/<slug>/06_RUNS/<run_id>/events.jsonl` (1 行 1 イベント)
- `.research/<slug>/06_RUNS/<run_id>/STATUS` (started | succeeded | failed | not_implemented)

## run_id 形式

```
{YYYYMMDD-HHMMSS}-{git_sha[:7]}-{config_hash[:6]}
```

例: `20260509-104523-a1b2c3d-9e8f7d`

3 つの要素全てが揃って初めて再現可能。

## events.jsonl 必須スキーマ

`references/jsonl_event_schema.md` 参照。最低限:

```json
{"event":"run.started","level":"info","ts":"2026-05-09T10:45:23Z","run_id":"...","duration_ms":0}
{"event":"data.loaded","level":"info","ts":"...","run_id":"...","duration_ms":15234,"n_examples":1000}
{"event":"step","level":"debug","ts":"...","run_id":"...","duration_ms":230,"step":100,"loss":0.42}
{"event":"eval.metric","level":"info","ts":"...","run_id":"...","duration_ms":...,"metric":"acc","value":0.671}
{"event":"run.succeeded","level":"info","ts":"...","run_id":"...","duration_ms":3600000}
```

エラー時は追加で `error_type`, `error_message`, `error_stack` を含める。

## ablation 計画の解釈

`04_EXPERIMENT_PLAN.md` の `## Ablation Matrix` 節から (factor, levels) のリストを取り出し、Cartesian product で cells を生成する:

例:
```markdown
## Ablation Matrix
- factor: model_size, levels: [3B, 8B, 70B]
- factor: temperature, levels: [0.0, 0.7, 1.0]
- factor: prompting, levels: [zero-shot, 5-shot]
```

→ 3 × 3 × 2 = 18 cells × seeds 3+ = 54+ runs

`compute_budget_gpu_h` を超える場合は警告し、優先度の低い軸 (P2) から削るか smaller model を提案。

## ステップ

### 1. ablation 計画の読み込みと検証

`04_EXPERIMENT_PLAN.md` をパースし cells を作る。各 cell の推定 GPU-h を合計し budget と比較。

### 2. configs/ablations/ 生成

各 cell に対して `configs/ablations/<cell_id>.yaml` を生成 (Hydra override で base.yaml に重ねる)。

### 3. 並列実行戦略

- 単一 GPU 環境: 直列実行 (Bash で `uv run python -m {pkg}.train ...` ループ)
- 複数 GPU 環境: GPU per process で並列 (`CUDA_VISIBLE_DEVICES=0 ...` & `1 ...`)
- Slurm / Ray 統合は Out of Scope (next iteration)

実行は **ブロッキング** で進めず、各 run の `STATUS` ファイルを poll する形がよい (失敗時に他の cell を継続できる)。

### 4. PostToolUse hook との連携

`hooks/post-experiment-log.sh` が `uv run *` の bash を捕捉して各 `events.jsonl` に追記する仕組み。スキル側では `uv run python -m {pkg}.train ...` を Bash tool で実行するだけで、hook が exit_code / duration を記録してくれる。

### 5. 失敗 run の扱い

- `STATUS=failed` で残す (削除しない)
- `06_RUNS/<run_id>/error.txt` に traceback を保存
- 全体実行の最後に「failed: N / total: M」を報告

### 5.5. Reproducibility 保証 (v0.14.0+)

各 run 完了時 (success / failed 両方) に以下を **自動保存**:

1. **`06_RUNS/<run_id>/uv.lock`** — project root の `uv.lock` を copy (deps drift 防止)
   - project root に `uv.lock` 不在なら warning + skip
2. **`06_RUNS/<run_id>/reproduce.sh`** — events.jsonl の最初の `tool.bash.uv_run` から構築:
   ```bash
   #!/bin/bash
   # Auto-generated reproduce script for <run_id>
   # Generated: <ISO 8601 timestamp>
   # Original status: <succeeded|failed>
   set -euo pipefail
   cd "$(dirname "$0")"
   uv sync --frozen --quiet
   exec uv run --frozen python <entry> --config config.yaml "$@"
   ```
   - `set -euo pipefail` 必須 (silent fail 禁止)
   - `--frozen` 必須 (deps drift 検出)
   - 既存なら overwrite せず diff log のみ
3. **chmod +x reproduce.sh**

これにより `06_RUNS/<id>/` だけで `bash reproduce.sh` で同じ run を再現可能 (失敗 run も同様)。

詳細は `skills/research.lab.notebook/references/reproducibility_checklist.md` (7-tuple checklist) を参照。

### 5.6. 失敗 run の lab notebook 化 (v0.14.0+)

`STATUS=failed` を書いた直後に **`research.lab.notebook` skill を auto-trigger**:

- 各 failed run について `06_RUNS/<id>/POSTMORTEM.md` 下書きを生成
  - `<!-- agent-managed:Phase=6 -->` marker 付き (人手 polish 保護)
  - Hypothesis space §3 を events.jsonl + error.txt から 3-5 候補 draft (`hypothesis_table_rules.md` 準拠)
  - §4 Decision / §5 Lessons は `<TODO: user polish>` placeholder
- `LAB_NOTEBOOK.md` に Phase 6 entry (POSTMORTEM への link 含)
- next-step trailer に "POSTMORTEM 下書き生成済" を表示

成功 run でも `LAB_NOTEBOOK.md` に 1 行 entry を残す (時系列の連続性のため)。

### 6. metrics 集計 → 06_RESULTS.md 雛形

全 run 終了後、各 `metrics.json` を読み込み:
- (factor, level) ごとに mean ± 95% CI
- baseline との paired bootstrap (seed pair で対応)
- 表形式で `06_RESULTS.md` に書き出す (実際の検定は `result-statistician` agent が後段で行う)

### 6.5. INDEX.md 自動更新

各 run 完了時 (succeeded / failed どちらも)、`.research/<slug>/06_RUNS/INDEX.md` を再生成する:

```markdown
# Run Index — <slug>

| run_id | status | primary metric | duration | notes |
|--------|--------|----------------|----------|-------|
| 20260509-104523-a1b2c3d-9e8f7d | succeeded | acc=0.671 | 60min | baseline |
| 20260509-114523-a1b2c3d-3a8b1e | failed | — | 4min | OOM |
| ... | ... | ... | ... | ... |
```

これは re-generation 可能 (各 `06_RUNS/<id>/{config.json,metrics.json,STATUS}` を読めば作れる) なので、
壊れたら delete & regenerate で復旧できる。git track することで人間が PR で diff を見られる。

実装: skill 内で全 `06_RUNS/*/` を Glob し、各 `STATUS`/`metrics.json` を Read して表を組み立てて Write。

### データ retention

- **checkpoints/**: 30 日経過 or 採用 run 以外は削除候補。`scripts/cleanup_checkpoints.sh` (将来) で自動化
- **events.jsonl**: 90 日経過したら gzip 推奨
- **失敗 run のディレクトリそのもの**: 削除しない (再現性のため `STATUS=failed` で残す)
- 詳細は `skills/auto-research/references/data_lineage.md` 参照

### 7. 進捗表示

```
[Phase 6/8] Run & Analysis 進行中
  total cells × seeds: N
  完了: K (succeeded: K1, failed: K2)
  実行中: ... (ETA ~30min)
  次: result-statistician + attention-analyst (focus_area=attention のみ) を並列 dispatch
```

## sanity check

各 run 完了時に以下を確認:
- `metrics.json` に primary metric が存在
- 値が `04_EXPERIMENT_PLAN.md` の sanity range 内 (例えば baseline metric が 0.0 や 1.0 など極端値ならバグ疑い)
- 範囲外なら `STATUS=failed_sanity` にして次の cell へ進む

5 cell 連続で sanity 失敗した場合は **ロールバック** して Phase 5 へ戻る (`CHANGELOG.md` 記録)。

## 実装ガイド

スキル本体 (Claude が実行する流れ):

1. ablation 軸を読み込み cells 列挙
2. 全 cells を `configs/ablations/<cell_id>.yaml` に展開
3. for cell in cells × seeds:
   - Bash: `cd .research/<slug>/code && uv run python -m {pkg}.train --config-name ablations/<cell_id>` (hook が events.jsonl 記録)
   - Bash で `cat 06_RUNS/<latest>/STATUS` を確認
4. 全 run 後に `metrics.json` を集約し `06_RESULTS.md` 雛形を書く
5. `result-statistician` と (focus_area=attention のとき) `attention-analyst` を **並列** dispatch
