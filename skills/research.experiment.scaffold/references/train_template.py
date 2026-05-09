"""train.py — Hydra + RunConfig + 構造化 JSON ログを統合した訓練エントリポイント。

NOTE: research.experiment.scaffold が `src/<pkg>/train.py` として展開する雛形。
実装本体 (forward / loss / step) は ml-engineer agent が Green phase で追加する。
"""

from __future__ import annotations

import json
import logging
import time
from dataclasses import asdict
from pathlib import Path
from typing import Any

import hydra
from omegaconf import DictConfig, OmegaConf

from .config import RunConfig, current_git_rev, set_global_determinism

log = logging.getLogger(__name__)


def jlog(event: str, *, level: str = "info", run_id: str, **fields: Any) -> None:
    """構造化 JSON ログを 1 行で stdout に出す (events.jsonl 互換)."""
    record = {
        "event": event,
        "level": level,
        "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "run_id": run_id,
        **fields,
    }
    print(json.dumps(record, ensure_ascii=False, separators=(",", ":")))


@hydra.main(version_base=None, config_path="../../configs", config_name="base")
def main(cfg: DictConfig) -> None:
    run_cfg = RunConfig(
        project_slug=cfg.project_slug,
        experiment_name=cfg.experiment_name,
        seed=cfg.seed,
        git_rev=current_git_rev(),
        model_id=cfg.model.id,
        dtype=cfg.model.dtype,
        attn_impl=cfg.model.attn_impl,
        dataset_name=cfg.data.name,
        dataset_split=cfg.data.split,
        max_examples=cfg.data.get("max_examples"),
        batch_size=cfg.train.batch_size,
        max_length=cfg.train.max_length,
        decoding=cfg.eval.decoding,
        temperature=cfg.eval.temperature,
        top_p=cfg.eval.top_p,
        max_new_tokens=cfg.eval.max_new_tokens,
        device=cfg.runtime.device,
        num_gpus=cfg.runtime.num_gpus,
        notes=cfg.get("notes", ""),
        tags=tuple(cfg.get("tags", [])),
    )
    set_global_determinism(run_cfg.seed)

    # 出力ディレクトリ
    out_dir = Path(cfg.output_root) / run_cfg.run_id
    out_dir.mkdir(parents=True, exist_ok=True)
    run_cfg.dump(out_dir / "config.json")
    OmegaConf.save(cfg, out_dir / "hydra_config.yaml")

    # status: started
    (out_dir / "STATUS").write_text("started")
    jlog("run.started", run_id=run_cfg.run_id, **asdict(run_cfg))
    t0 = time.monotonic()

    try:
        # ml-engineer がここを実装する想定:
        #   - data: load_dataset(run_cfg.dataset_name, run_cfg.dataset_split)
        #   - model: AutoModelForCausalLM.from_pretrained(run_cfg.model_id, dtype=...)
        #   - loop: for batch in dataloader: ...
        raise NotImplementedError(
            "Green phase: ml-engineer agent should implement training loop here."
        )
    except NotImplementedError:
        (out_dir / "STATUS").write_text("not_implemented")
        jlog(
            "run.not_implemented",
            level="warning",
            run_id=run_cfg.run_id,
            duration_ms=int((time.monotonic() - t0) * 1000),
        )
        raise
    except Exception as e:
        (out_dir / "STATUS").write_text("failed")
        jlog(
            "run.failed",
            level="error",
            run_id=run_cfg.run_id,
            duration_ms=int((time.monotonic() - t0) * 1000),
            error_type=type(e).__name__,
            error_message=str(e),
        )
        raise
    else:
        (out_dir / "STATUS").write_text("succeeded")
        jlog(
            "run.succeeded",
            run_id=run_cfg.run_id,
            duration_ms=int((time.monotonic() - t0) * 1000),
        )


if __name__ == "__main__":
    main()
