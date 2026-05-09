---
name: research.attention.probe
description: >
  TransformerLens / nnsight ベースの mechanistic interpretability セットアップ。
  介入プロトコル (logit lens, attention pattern, activation patching, path patching, probing,
  SAE feature lookup) を `analysis/<slug>.py` 1 ファイル原則 + 活性キャッシュで効率的に実行。
  Use when: focus_area=attention の auto-research プロジェクトで Phase 5/6 に内部解析を行うとき、
  または attention-analyst agent の前段で環境を整えるとき。
allowed-tools: Read, Write, Edit, Bash, Glob
---

# `research.attention.probe`

LLM 内部 (attention / activation / circuits) の介入実験セットアップを支援するスキル。

## 入力 / 出力

入力:
- `.research/<slug>/04_EXPERIMENT_PLAN.md` (内部解析の RQ がある前提)
- `.research/<slug>/code/` (Phase 5 で生成済みの uv プロジェクト)

出力:
- `.research/<slug>/code/src/<pkg>/probe.py` (介入実装の薄いラッパー)
- `.research/<slug>/code/analysis/<slug>.py` (1 ファイル単位の介入スクリプト雛形)
- `.research/<slug>/code/cache/activations/` (活性キャッシュ用ディレクトリ)
- `.research/<slug>/code/results/probe/<probe_id>.json` (介入結果)

## 必須依存

`pyproject.toml` の `attention` extra:
- `transformer_lens>=2.0`
- `nnsight>=0.3` (>7B モデル用、リモートトレーシング)
- `circuitsvis>=1.43`
- `einops>=0.8`
- `jaxtyping>=0.2.34`

`uv sync --extra attention` を実行する。

## 介入プロトコル一覧

`references/intervention_protocols.md` に詳細。各介入ごとに `analysis/{intervention}_{date}.py` を 1 ファイルで書く原則:

| プロトコル | 目的 | 主要ライブラリ |
|-----------|------|---------------|
| logit lens | 各層で next-token 予測がどう形成されるか | transformer_lens |
| attention pattern | 特定 head が何を attend しているか | transformer_lens + circuitsvis |
| activation patching | (clean → corrupted) 介入で因果性検証 | transformer_lens |
| path patching | 経路レベルの因果性 (head → head) | transformer_lens |
| probing classifier | 表現に特定情報が encode されているか | sklearn + torch |
| SAE feature lookup | 単義特徴抽出 (Anthropic-style) | sae-lens or 自前 |

## 思考規律 (attention-analyst と同じ原則)

1. **falsifiable hypothesis** で始める ("Head L5H3 implements previous-token copy" は testable、"L5 has interesting structure" は NG)
2. **causal > correlational**: attention pattern を眺めるより patching を優先
3. **localize before generalize**: 8 prompts での所見は仮説、>=64 examples + seed variance で初めて結果
4. **polysemantic vs monosemantic** を明示的に区別

## ステップ

### 1. probe.py の生成

`src/<pkg>/probe.py` に以下を含む:
- `load_hooked_model(model_id, dtype)` — TransformerLens の HookedTransformer
- `load_nnsight_model(model_id)` — nnsight の LanguageModel (>7B 用)
- `cache_activations(model, prompts, layers, hook_point)` — torch.save で `cache/activations/<hash>.pt` に保存、再読み込みで forward pass を回避
- `clean_corrupted_pair_dataset(prompts_clean, prompts_corrupted)` — patching 用ペア dataset

### 2. 介入スクリプト雛形

`analysis/<slug>.py` を `references/intervention_protocols.md` の対応セクションから雛形展開。

### 3. 活性キャッシュ運用

- 30 分以上かかる forward pass は **必ずキャッシュ**
- キャッシュキー: `sha256({model_id, prompts, layers, hook_point}) → hex`
- 再実行時はキャッシュ hit / miss を `events.jsonl` に記録 (`cache.hit` / `cache.miss`)

### 4. 結果保存

`results/probe/<probe_id>.json` フォーマット:

```json
{
  "probe_id": "logit_lens_layers_0_to_31",
  "intervention": "logit_lens",
  "model_id": "meta-llama/Llama-3.2-3B-Instruct",
  "n_examples": 256,
  "seeds": [0, 1, 2],
  "layers": [0, 4, 8, 12, 16, 20, 24, 28, 31],
  "metric": "rank_of_correct_token",
  "values_per_layer": [...],
  "ci_per_layer": [...],
  "alternative_explanations_not_ruled_out": ["...", "..."]
}
```

`alternative_explanations_not_ruled_out` を空にしない (常に 2 つ以上書く)。

### 5. attention-analyst へのハンドオフ

`probe.py` セットアップが終わったら、本格解析は `Agent(subagent_type="attention-analyst")` に委任:

```
Agent(subagent_type="attention-analyst") への依頼:

  プロジェクト: .research/<slug>/code/
  RQ: {04_EXPERIMENT_PLAN.md の RQ}
  仮説: {falsifiable な 1 文}
  想定 intervention: {logit_lens | activation_patching | path_patching | ...}

  setup 完了:
    - probe.py: 実装済み
    - cache/: 利用可能
    - data: clean / corrupted ペア dataset 用意済み (path: ...)

  以下を実行してください:
    1. 仮説の検証スクリプトを analysis/<slug>.py に書く
    2. >= 64 examples × 3 seeds で介入を実行
    3. results/probe/<probe_id>.json に結果保存
    4. analysis レポートを .research/<slug>/06_RUNS/attention/<probe_id>.md に書く
       - Hypothesis / Method / Setup / Results / Causal check / Limitations & next probe
       - 効果量と noise floor を必ず報告
       - 代替説明を 2 つ以上残す
```
