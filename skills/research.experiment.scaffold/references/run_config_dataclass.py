"""RunConfig — 全実験で固定すべきメタデータと再現性パラメータ。

このファイルは research.experiment.scaffold によってプロジェクト初期化時に
src/<pkg>/config.py として展開される。
"""

from __future__ import annotations

import hashlib
import json
import subprocess
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Literal


@dataclass(frozen=True)
class RunConfig:
    """1 実験 (1 run) の不変メタデータ。

    `run_id` は `{ts}-{git_sha[:7]}-{config_hash[:6]}` 形式で生成する。
    `config_hash` は dtype/seed/モデル/データを含む全フィールドの SHA256。
    """

    # --- 識別子 ---
    project_slug: str
    experiment_name: str
    seed: int
    git_rev: str

    # --- モデル ---
    model_id: str
    dtype: Literal["fp32", "bf16", "fp16", "int8", "int4"] = "bf16"
    attn_impl: Literal["sdpa", "flash_attention_2", "eager"] = "sdpa"

    # --- データ ---
    dataset_name: str = ""
    dataset_split: str = "test"
    max_examples: int | None = None

    # --- 訓練/推論共通 ---
    batch_size: int = 8
    max_length: int = 2048

    # --- 推論 ---
    decoding: Literal["greedy", "sample"] = "greedy"
    temperature: float = 0.0
    top_p: float = 1.0
    max_new_tokens: int = 256

    # --- ハードウェア ---
    device: str = "cuda"
    num_gpus: int = 1

    # --- 実験追加メタ ---
    notes: str = ""
    tags: tuple[str, ...] = field(default_factory=tuple)
    created_at: str = field(
        default_factory=lambda: datetime.now(timezone.utc).isoformat()
    )

    # ---- 派生プロパティ ----
    @property
    def config_hash(self) -> str:
        d = asdict(self)
        d.pop("created_at")  # 時刻はハッシュから外す
        canonical = json.dumps(d, sort_keys=True, separators=(",", ":"))
        return hashlib.sha256(canonical.encode()).hexdigest()

    @property
    def run_id(self) -> str:
        ts = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
        return f"{ts}-{self.git_rev[:7]}-{self.config_hash[:6]}"

    # ---- I/O ----
    def dump(self, path: str | Path) -> None:
        Path(path).write_text(
            json.dumps(asdict(self), indent=2, sort_keys=True, ensure_ascii=False)
        )

    @classmethod
    def load(cls, path: str | Path) -> RunConfig:
        return cls(**json.loads(Path(path).read_text()))


def current_git_rev() -> str:
    """最新コミットの SHA を返す。git がない / コミットがない場合は ``unknown``."""
    try:
        out = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            capture_output=True,
            text=True,
            check=True,
        )
        return out.stdout.strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return "unknown"


def set_global_determinism(seed: int) -> None:
    """全乱数源を固定し、PyTorch を決定論モードに切り替える。"""
    import os
    import random

    import numpy as np
    import torch

    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    if torch.cuda.is_available():
        torch.cuda.manual_seed_all(seed)
    os.environ.setdefault("CUBLAS_WORKSPACE_CONFIG", ":4096:8")
    torch.use_deterministic_algorithms(True, warn_only=True)
    torch.backends.cudnn.benchmark = False
    torch.backends.cudnn.deterministic = True
