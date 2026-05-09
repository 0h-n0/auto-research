---
name: research.experiment.scaffold
description: >
  uv ベースの Python ML 実験プロジェクト雛形を `.research/<slug>/code/` 配下に生成する。
  PyTorch + HuggingFace transformers/datasets/accelerate + Hydra 構成、RunConfig dataclass、
  決定論的 seed セットアップ、最小テストスケルトンまで含む。
  Use when: auto-research Phase 5 の冒頭、04_EXPERIMENT_PLAN.md が承認された直後。
---

# `research.experiment.scaffold`

`auto-research` Phase 5 の冒頭で実行する uv プロジェクト雛形生成スキル。

## 入力 / 出力

入力:
- `.research/<slug>/04_EXPERIMENT_PLAN.md`
- `.research/<slug>/STATE.json` (project_slug, focus_area, paper_format)

出力 (`.research/<slug>/code/` 配下):
- `pyproject.toml`
- `src/<pkg>/{__init__.py, config.py, data.py, model.py, train.py, eval.py, utils.py}`
- `tests/{conftest.py, test_data.py, test_model.py, test_metrics.py, test_contamination.py}`
- `configs/{base.yaml, ablations/*.yaml}`
- `notebooks/.gitkeep`
- `results/.gitkeep`
- `Makefile`
- `IMPL_NOTES.md`
- `DATA_CARD.md`

## ステップ

### 1. パッケージ名決定

`STATE.json.project_slug` から Python パッケージ名を生成: `{slug}` を `_` 区切りに正規化。

例: `attention-sink-llama-long-ctx` → `attention_sink_llama`

### 2. uv プロジェクト初期化

```bash
cd .research/<slug>/code
uv init --package --name {pkg_name}
```

### 3. pyproject.toml をテンプレで上書き

`references/pyproject_template.toml` を読み、`{pkg_name}`, `{slug}` を置換して書き出す。

依存関係 (focus_area で分岐):
- 共通: `torch>=2.4`, `transformers>=4.45`, `datasets>=3.0`, `accelerate>=1.0`, `hydra-core>=1.3`, `numpy`, `pandas`, `matplotlib`, `seaborn`, `tqdm`, `pydantic>=2.0`
- focus_area=`attention`: `transformer_lens`, `nnsight`, `circuitsvis`, `einops`, `jaxtyping`
- focus_area=`evaluation`: `lm-eval[api]`
- focus_area=`post-training`: `peft`, `trl`, `bitsandbytes`
- focus_area=`agent`: `langchain-core`, `openai` (optional, API access only)
- 開発: `pytest>=8`, `pytest-xdist`, `ruff`, `mypy`, `pyright`

### 4. RunConfig dataclass を生成

`src/<pkg>/config.py` を `references/run_config_dataclass.py` から生成。

### 5. train_template.py / test_template.py の展開

`src/<pkg>/train.py` を `references/train_template.py` から生成。
`tests/test_data.py` を `references/test_template.py` から生成。
`configs/base.yaml` を `references/hydra_config_template.yaml` から生成。

### 6. テスト雛形 — Red phase

`superpowers:test-driven-development` skill を invoke し、以下のテストが **必ず失敗** する状態で書く:

- `test_data.py`: `load_dataset()` が DatasetDict を返す形状テスト
- `test_model.py`: `forward(input_ids)` が `(batch, seq, vocab)` を返す形状テスト
- `test_metrics.py`: primary metric が `04_EXPERIMENT_PLAN.md` の sanity 範囲内
- `test_contamination.py`: eval set と pretraining cutoff の overlap < 1%

`uv run pytest -q` で **全部失敗する** ことを確認 (Red 完了)。

### 7. Makefile

```make
.PHONY: install lint test reproduce clean

install:
	uv sync

lint:
	uv run ruff check .
	uv run mypy src

test:
	uv run pytest -q

reproduce:
	uv run python -m {pkg_name}.train --config-name base
	uv run python -m {pkg_name}.eval --config-name base

clean:
	rm -rf results/run_*
```

### 8. IMPL_NOTES.md と DATA_CARD.md

- `IMPL_NOTES.md`: 環境情報 (`nvidia-smi`, `uname -a`, CUDA / cuDNN version) を `bash` で取得して記載
- `DATA_CARD.md`: メインスキル references の `data_card_template.md` をコピー、`{name}` 等を `04_EXPERIMENT_PLAN.md` の dataset から置換

### 9. 進捗確認

```
[Phase 5/8] Scaffold 完了
  pkg: {pkg_name}
  uv sync: ok / failed
  pytest -q (Red): N tests failing as expected
  次: ml-engineer agent に Green phase 実装を委任
```

## ml-engineer への委任テンプレ

```
Agent(subagent_type="ml-engineer") への依頼:

  ベースライン実装をお願いします。

  プロジェクト: .research/{slug}/code/
  仕様: .research/{slug}/04_EXPERIMENT_PLAN.md (RQ, primary metric, baseline)
  config: configs/base.yaml
  失敗中テスト: tests/test_{data,model,metrics,contamination}.py

  TDD で進めてください:
    1. test_data の Green まで持っていく (HF datasets で {dataset_name} を load)
    2. test_model の Green (transformers で {model_id} を load + forward)
    3. test_contamination の Green (n-gram overlap check)
    4. test_metrics の Green (primary metric が sanity 範囲内)

  使ってはいけない: モック、TODO のまま放置。実装できないものは
  NotImplementedError で明示的に失敗させてください。

  完了報告: uv run pytest -q がオールグリーンになったら結果を返してください。
```
