# Observability Setup (W&B / MLflow / TensorBoard)

`auto-research` v0.5.0 から、外部 observability backend を **環境変数 opt-in** で有効化できます。
未設定時は何もしない (silent no-op) ので既存ユーザーには影響なし。

## 設計方針

- **opt-in only**: 環境変数が設定されているときだけ有効化
- **既存 logging を壊さない**: `events.jsonl` (JSONL ローカルログ) は常に書く
- **冗長性**: W&B / MLflow / events.jsonl の 3 系統を並列で記録できる
- **cost-aware**: `research.cost.estimate` の `cost_estimate.usd` も併せて log

## 検出される環境変数

| Backend | 環境変数 | 動作 |
|---------|---------|------|
| W&B | `WANDB_API_KEY` 設定済 | `wandb.init(project=<slug>)` を自動実行 |
| W&B | `WANDB_PROJECT` (任意) | project 名上書き (default: `<slug>`) |
| W&B | `WANDB_MODE=offline` | offline mode (後で sync 可) |
| MLflow | `MLFLOW_TRACKING_URI` 設定済 | `mlflow.set_tracking_uri()` + `mlflow.start_run()` |
| MLflow | `MLFLOW_EXPERIMENT_NAME` (任意) | experiment 名上書き (default: `auto-research-<slug>`) |
| TensorBoard | `TB_LOG_DIR` 設定済 | `SummaryWriter(TB_LOG_DIR)` を作成 |

## scaffold が生成する training template の対応

`research.experiment.scaffold` が `train.py` を生成するとき、observability_init() helper を含める:

```python
import os
from typing import Any

def observability_init(run_cfg: "RunConfig") -> dict[str, Any]:
    """W&B / MLflow / TensorBoard を opt-in で有効化."""
    backends: dict[str, Any] = {}

    if os.environ.get("WANDB_API_KEY"):
        try:
            import wandb
            backends["wandb"] = wandb.init(
                project=os.environ.get("WANDB_PROJECT", run_cfg.project_slug),
                name=run_cfg.run_id,
                config={
                    "model_id": run_cfg.model_id,
                    "dtype": run_cfg.dtype,
                    "seed": run_cfg.seed,
                    "git_rev": run_cfg.git_rev,
                    "config_hash": run_cfg.config_hash,
                },
                mode=os.environ.get("WANDB_MODE", "online"),
            )
        except ImportError:
            print("[observability] wandb requested but not installed; skipping", flush=True)
        except Exception as e:
            print(f"[observability] wandb init failed: {e}; continuing without", flush=True)

    if os.environ.get("MLFLOW_TRACKING_URI"):
        try:
            import mlflow
            mlflow.set_tracking_uri(os.environ["MLFLOW_TRACKING_URI"])
            mlflow.set_experiment(
                os.environ.get("MLFLOW_EXPERIMENT_NAME", f"auto-research-{run_cfg.project_slug}")
            )
            backends["mlflow"] = mlflow.start_run(run_name=run_cfg.run_id)
            for k, v in {
                "model_id": run_cfg.model_id,
                "dtype": run_cfg.dtype,
                "seed": run_cfg.seed,
                "git_rev": run_cfg.git_rev,
                "config_hash": run_cfg.config_hash,
            }.items():
                mlflow.log_param(k, v)
        except ImportError:
            print("[observability] mlflow requested but not installed; skipping", flush=True)
        except Exception as e:
            print(f"[observability] mlflow init failed: {e}; continuing without", flush=True)

    if os.environ.get("TB_LOG_DIR"):
        try:
            from torch.utils.tensorboard import SummaryWriter
            backends["tensorboard"] = SummaryWriter(os.environ["TB_LOG_DIR"])
        except Exception as e:
            print(f"[observability] tensorboard init failed: {e}; continuing without", flush=True)

    return backends


def observability_log_metric(backends: dict[str, Any], name: str, value: float, step: int | None = None):
    """全有効 backend に同時 log."""
    if "wandb" in backends:
        backends["wandb"].log({name: value, **({"step": step} if step is not None else {})})
    if "mlflow" in backends:
        import mlflow
        mlflow.log_metric(name, value, step=step)
    if "tensorboard" in backends and step is not None:
        backends["tensorboard"].add_scalar(name, value, step)


def observability_finalize(backends: dict[str, Any], cost_estimate: dict | None = None):
    """終了処理 + cost を最後に log."""
    if cost_estimate and cost_estimate.get("usd") is not None:
        if "wandb" in backends:
            backends["wandb"].summary["cost_usd"] = cost_estimate["usd"]
            backends["wandb"].summary["gpu_type"] = cost_estimate["gpu_type"]
        if "mlflow" in backends:
            import mlflow
            mlflow.log_metric("cost_usd", cost_estimate["usd"])
            mlflow.set_tag("gpu_type", cost_estimate["gpu_type"])

    if "wandb" in backends:
        backends["wandb"].finish()
    if "mlflow" in backends:
        import mlflow
        mlflow.end_run()
    if "tensorboard" in backends:
        backends["tensorboard"].close()
```

## 使い方 (ユーザー視点)

### W&B を使う

```bash
export WANDB_API_KEY=xxx
export WANDB_PROJECT=my-eval-study  # optional
uv run python -m my_pkg.train --config-name base
```

train.py 内で何もする必要はない。scaffold が生成した template が environment variable を見て自動で `wandb.init()` する。

### MLflow を使う (local SQLite backend)

```bash
export MLFLOW_TRACKING_URI=sqlite:///mlflow.db
export MLFLOW_EXPERIMENT_NAME=my-eval-study
uv run python -m my_pkg.train --config-name base
```

その後 `mlflow ui` で web UI から閲覧。

### TensorBoard

```bash
export TB_LOG_DIR=runs/my-eval-study
uv run python -m my_pkg.train --config-name base
tensorboard --logdir runs/
```

### 何も設定しない (既存ユーザー)

環境変数を一切設定しなければ silent no-op。`events.jsonl` のみ書かれる従来挙動。

## events.jsonl との関係

`events.jsonl` は **常に** 書かれる (auto-research の core ログ)。
W&B / MLflow / TensorBoard は **追加** ログ (任意)。

```
events.jsonl  ←─ 常時、CLAUDE.md ログ規約準拠、再現性最優先
W&B / MLflow ←─ opt-in、リアルタイム閲覧・チーム共有用
```

events.jsonl が止まることはなく、observability backend は壊れても `events.jsonl` への記録は継続。

## 失敗モード

| failure | 検出 | 対処 |
|---------|------|------|
| `WANDB_API_KEY` 設定済だが `wandb` 未インストール | `import wandb` で `ImportError` | 警告出力、skip して続行 (`uv sync --extra wandb` を案内) |
| `MLFLOW_TRACKING_URI` 設定済だが `mlflow` 未インストール | 同上 | 同上 (`uv sync --extra mlflow`) |
| W&B サーバー到達不能 | `wandb.init()` exception | offline mode (`WANDB_MODE=offline`) に fallback、後で `wandb sync` |
| MLflow tracking URI invalid | `mlflow.set_tracking_uri()` exception | 警告出力、skip |

## CI / クラウド integration の future hook

v0.5.0 ではローカル開発機を主対象。将来:
- v0.6.0: HF Hub Spaces / Zenodo dataset 自動 upload (research.export 拡張)
- v0.7.0+: Slurm / Ray dispatch (別プラグイン化)
