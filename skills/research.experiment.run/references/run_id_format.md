# run_id 形式

## フォーマット

```
{YYYYMMDD-HHMMSS}-{git_sha[:7]}-{config_hash[:6]}
```

3 セグメントを `-` で連結。例:

```
20260509-104523-a1b2c3d-9e8f7d
```

## 各セグメントの意味

### 1. timestamp (`YYYYMMDD-HHMMSS`)
UTC、秒精度。同一秒に並列起動された run は config_hash で識別される。

### 2. git_sha[:7]
`git rev-parse HEAD` の先頭 7 文字。working tree が dirty な場合は接尾辞 `-dirty` を付けない (run_id を変えると config_hash と整合しなくなる)。代わりに `metrics.json` の `meta.git_dirty: true` で記録。

### 3. config_hash[:6]
`RunConfig` (created_at を除く) の canonical JSON の SHA256 先頭 6 文字。
seed / dtype / model_id / dataset / batch_size / decoding 等の全パラメータを反映。

## 衝突可能性

- timestamp 衝突: 同一秒並列実行で発生。git_sha が同じなら config_hash で識別。3 セグメント全衝突は実質不可能 (~ 16M runs/秒 で初めて hash collision)。
- 衝突した場合: ファイル書き込み時に `OSError` で検出、suffix `-2` を追加。

## ディレクトリレイアウト

```
.research/<slug>/06_RUNS/
├── 20260509-104523-a1b2c3d-9e8f7d/
│   ├── STATUS                    # started | succeeded | failed | not_implemented | failed_sanity
│   ├── config.json               # RunConfig dump
│   ├── config.yaml               # Hydra resolved config (omegaconf)
│   ├── metrics.json              # primary + secondary metrics
│   ├── events.jsonl              # 1 行 1 イベント
│   ├── error.txt                 # failed 時のみ traceback
│   └── checkpoints/              # 任意: small なら同梱、大きいなら外部 (HF Hub)
└── 20260509-104530-a1b2c3d-3a8b1e/
    └── ...
```

## metrics.json スキーマ

```json
{
  "run_id": "20260509-104523-a1b2c3d-9e8f7d",
  "primary": {"name": "acc", "value": 0.671, "n": 1000},
  "secondary": [
    {"name": "f1", "value": 0.65},
    {"name": "throughput_qps", "value": 12.4}
  ],
  "per_class": {...},
  "elapsed_seconds": 3600,
  "meta": {
    "git_dirty": false,
    "cuda_version": "12.4",
    "torch_version": "2.5.0",
    "gpu": "NVIDIA A100-SXM4-80GB",
    "num_gpus": 1
  }
}
```
