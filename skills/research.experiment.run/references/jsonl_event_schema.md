# events.jsonl スキーマ

`.research/<slug>/06_RUNS/<run_id>/events.jsonl` の 1 行 1 イベント JSON 仕様。
CLAUDE.md の構造化ログ規約に準拠。

## 必須フィールド

すべてのイベントに以下を含める:

| field | type | 説明 |
|-------|------|------|
| `event` | string | イベント名 (snake_case + dot 区切り) |
| `level` | string | `debug` / `info` / `warning` / `error` |
| `ts` | string | ISO 8601 UTC (例: `2026-05-09T10:45:23Z`) |
| `run_id` | string | 親 run の ID |
| `duration_ms` | int | このイベントが計測する処理の経過 ms (なければ 0) |

## 推奨イベント名

| event | 発生タイミング |
|-------|---------------|
| `run.started` | 訓練/評価開始時 (RunConfig も含めて記録) |
| `run.succeeded` | 正常終了時 |
| `run.failed` | 例外で終了時 (error_* フィールド必須) |
| `run.not_implemented` | NotImplementedError 時 (Red phase) |
| `data.loading` | dataset 読み込み開始 |
| `data.loaded` | dataset 読み込み完了 (n_examples) |
| `model.loading` | モデル読み込み開始 (model_id) |
| `model.loaded` | モデル読み込み完了 (param_count, dtype) |
| `train.step` | 訓練 step (step, loss, lr) |
| `train.epoch_end` | epoch 完了 |
| `eval.start` | 評価フェーズ開始 |
| `eval.metric` | 1 メトリクス計算 (metric, value, n) |
| `eval.complete` | 全評価完了 |
| `checkpoint.saved` | checkpoint 保存 (path, size_mb) |
| `attention.probe` | mechanistic interp の介入実行 (intervention, layer, head) |

## エラーイベント

`level: error` の場合は以下を **必須** で含める:

| field | type | 説明 |
|-------|------|------|
| `error_type` | string | 例外クラス名 |
| `error_message` | string | str(exc) |
| `error_stack` | string | traceback (短縮可、最終 20 行推奨) |

## PII 厳禁

- `prompt`, `input_text`, `output_text` の生テキストは絶対に含めない
- 必要なら token id か SHA256 hash の先頭 16 文字
- データセット由来の例文も同様

## サンプル

```jsonl
{"event":"run.started","level":"info","ts":"2026-05-09T10:45:23Z","run_id":"20260509-104523-a1b2c3d-9e8f7d","duration_ms":0,"model_id":"meta-llama/Llama-3.2-3B-Instruct","dtype":"bf16","seed":42}
{"event":"data.loaded","level":"info","ts":"2026-05-09T10:45:38Z","run_id":"20260509-104523-a1b2c3d-9e8f7d","duration_ms":15234,"n_examples":1000,"split":"test"}
{"event":"model.loaded","level":"info","ts":"2026-05-09T10:46:12Z","run_id":"20260509-104523-a1b2c3d-9e8f7d","duration_ms":34567,"param_count":3210000000}
{"event":"eval.metric","level":"info","ts":"2026-05-09T11:45:38Z","run_id":"20260509-104523-a1b2c3d-9e8f7d","duration_ms":3600000,"metric":"acc","value":0.671,"n":1000}
{"event":"run.succeeded","level":"info","ts":"2026-05-09T11:45:39Z","run_id":"20260509-104523-a1b2c3d-9e8f7d","duration_ms":3600123}
```

## 解析ヘルパー

集計時に jq で 1 ライナーが書きやすいスキーマを優先する:

```bash
# 全 run の primary acc を抽出
jq -c 'select(.event=="eval.metric" and .metric=="acc") | {run_id, value}' \
    06_RUNS/*/events.jsonl

# 失敗 run の error_type ヒストグラム
jq -c 'select(.event=="run.failed") | .error_type' 06_RUNS/*/events.jsonl \
    | sort | uniq -c
```
