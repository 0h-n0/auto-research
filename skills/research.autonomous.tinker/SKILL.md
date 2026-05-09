---
name: research.autonomous.tinker
description: >
  karpathy/autoresearch (March 2026, MIT) に着想を得た autonomous tinker mode。
  8-phase ワークフローの Phase 5-6 alt mode として、agent が `tinker/train.py` 1 ファイルを
  反復編集し、固定 wall-clock budget (デフォルト 5 分) で nanochat-style な single-GPU
  LLM 訓練を overnight 自律探索する。単一比較メトリックは val_bpb (vocab-size-independent)。
  Use when: Phase 4 の experiment plan で `mode: tinker` を選んだとき、または
  「single GPU で寝てる間に LLM training を agent に最適化させたい」とき。
---

# `research.autonomous.tinker`

karpathy/autoresearch に着想を得た autonomous tinker mode。

> **Acknowledgement**: 本 skill の設計は [karpathy/autoresearch](https://github.com/karpathy/autoresearch) (Andrej Karpathy, March 2026, MIT License) を強く参考にしている。
> 概念 (single-file edit autonomy / fixed wall-clock budget / val_bpb 単一メトリック / program.md 設計) は karpathy のアイディアであり、本 skill は **そのアイディアを** auto-research プラグインの 8-phase ワークフローに統合した形で再実装したもの。
> train.py / prepare.py のコードは verbatim コピーではなく、本プラグイン内で **自前で書き直した最小実装** (~200 行 GPT + ~80 行 prepare)。

## 設計の核 (karpathy 流の踏襲)

1. **agent は 1 ファイル (`tinker/train.py`) のみ編集**: model / optimizer / hparams 全て fair game
2. **Fixed wall-clock budget per iteration** (default 300 秒 = 5 分): 改造内容に依らず experiment 直接比較可
3. **単一比較メトリック val_bpb**: validation cross-entropy を `1.4427 / bytes_per_token` でスケール
4. **`program.md` = agent への指示書**: human が iterate、agent は読むのみ
5. **Train → measure → keep/discard → repeat**: overnight ~100 iter

## 既存ワークフローとの統合

- **Phase 4 G3**: `04_EXPERIMENT_PLAN.md` の `mode: tinker` で本 skill を分岐選択
- **Phase 5 (Scaffold)**: `research.experiment.scaffold` の代わりに本 skill が `.research/<slug>/tinker/` を scaffold
- **Phase 6 (Run & Analysis)**: agent が `scripts/tinker_run.sh` を呼ぶたびに events.jsonl に `event=tinker.iteration` 追記
- **Phase 7 (Paper)**: `tinker/RESULTS.md` と best `train.py` を `research.paper.draft` に渡し "tinker journal" として論文化

## 入力 / 出力

入力:
- `<slug>` (`.research/<slug>/STATE.json` 存在前提、Phase 5 突入時に呼ばれる)
- (任意) `--budget-seconds N` (default 300)
- (任意) `--depth N`, `--max-seq-len N`, `--total-batch-size N` (template の小型化用)
- (任意) `--dataset {tinystories,fineweb-edu}` (default `tinystories` で軽量、必要に応じて `fineweb-edu`)

出力 (`.research/<slug>/tinker/`):
- `program.md` — agent への指示書 (human iterable、agent 読み込み専用)
- `train.py` — agent が編集する単一ファイル (最小 GPT、自前実装)
- `prepare.py` — data prep + utilities (immutable)
- `pyproject.toml` — uv で動く最小 deps
- `data/` — prepare.py で生成 (train/val split)
- `RESULTS.md` — iteration 履歴 (tinker_run.sh が auto-append)
- `BEST.json` — 最良 val_bpb の record + 該当 train.py の SHA256
- `history/iter_<N>.py` — 各 iter で committed train.py の snapshot (再現性)

## ワークフロー

### 1. Scaffold (skill が実行)

```bash
mkdir -p .research/<slug>/tinker/{data,history}
# templates をコピー (rename: .py.txt -> .py)
cp ${CLAUDE_PLUGIN_ROOT}/skills/research.autonomous.tinker/references/train_py_template.py.txt \\
   .research/<slug>/tinker/train.py
cp ${CLAUDE_PLUGIN_ROOT}/skills/research.autonomous.tinker/references/prepare_py_template.py.txt \\
   .research/<slug>/tinker/prepare.py
cp ${CLAUDE_PLUGIN_ROOT}/skills/research.autonomous.tinker/references/program_md_template.md \\
   .research/<slug>/tinker/program.md
cp ${CLAUDE_PLUGIN_ROOT}/skills/research.autonomous.tinker/references/tinker_pyproject_template.toml \\
   .research/<slug>/tinker/pyproject.toml
```

`program.md` の冒頭に project_slug と budget を inject。

### 2. データ準備

```bash
cd .research/<slug>/tinker
uv sync
uv run python prepare.py
# → data/ に train/val split (TinyStories or FineWeb-edu)
```

### 3. Baseline 実行 (1 iter sanity check)

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/tinker_run.sh <slug>
# tinker/result.json に val_bpb 記録、events.jsonl に append
# RESULTS.md / BEST.json も更新
```

### 4. Autonomous loop に入る

agent は `program.md` を読み、以下を繰り返す (1 iter ~5 分):

```
1. RESULTS.md を読み、現状の best と最近の試行履歴を把握
2. tinker/train.py を編集 (e.g. depth +1 / lr × 0.5 / mlp_ratio 変更 / etc.)
3. bash scripts/tinker_run.sh <slug> を実行
4. result.json から val_bpb を確認
5. 改善: history/iter_<N>.py に保存、RESULTS.md と BEST.json を更新
   悪化: train.py を best 版に revert (history から)
6. 全体 budget (e.g. 8h) に達したら停止
```

**重要**: agent は `prepare.py` / `data/` / val split を絶対に編集しない (program.md で明示)。

### 5. 仕上げ (Phase 7 へ)

overnight loop 完了後:
- `RESULTS.md` を `research.cross.compare` 風の table で view
- `BEST.json` を読み、`tinker/train.py` を best 版に restore
- `research.paper.draft` skill に `RESULTS.md` + `BEST.json` + best `train.py` を渡して "tinker journal" として論文化

## next-step trailer

```
─────────────────────────────────────
[Phase 6/8] ●●●●●●○○  G3 ✓  🔬 tinker mode

→ 推奨: agent autonomous loop を開始 (program.md 参照)
   bash scripts/tinker_run.sh <slug>

  代替:
   ・ /auto-research:research-status <slug>   進捗確認
   ・ research.cost.estimate skill   overnight USD 試算
─────────────────────────────────────
```

## 失敗モード

| failure | 検出 | 回復 |
|---------|------|------|
| train.py が syntax error (agent 編集ミス) | tinker_run.sh の `python -c "import ast; ast.parse(open('train.py').read())"` | iter として記録 (val_bpb=null, status=syntax_error)、history に保存して agent に revert を促す |
| loss が NaN / Inf に発散 | result.json の `diverged: true` | events.jsonl に `event=tinker.diverged` を warning level で記録、RESULTS.md にも明示 |
| OOM (`torch.cuda.OutOfMemoryError`) | tinker_run.sh の exit code | smaller batch / smaller seq_len への hint を agent に提示、iter は failed 扱い |
| timeout (budget 超過) | `timeout` コマンド | normal な完了として扱う (budget の意義)、result.json は "n_iters" まで write |
| val_bpb が前回と全く同じ (5 iter 連続) | RESULTS.md の値比較 | agent に「改造が反映されているか」を確認するメッセージ |
| 全体 wall budget (overnight) 経過 | tinker_run.sh が ENV `TINKER_OVERALL_BUDGET_HOURS` を見て自己停止 | normal exit、Phase 7 へ進む |

## Phase 連携の注意

- 本 skill は Phase 4 で `mode: tinker` 選択時のみ呼ばれる。non-tinker mode (通常 ablation 設計) はこれまで通り `research.experiment.scaffold` + `research.experiment.run` を使う。
- `research.cost.estimate` は tinker mode で **超有効** (overnight USD = `iter_per_hour × USD_per_hour × hours` を事前試算)
- `research.compute.shop` で **single-GPU on-demand** を推奨 (RTX-4090 / A100-80GB がコスパ筆頭)
- `research.cross.compare` は **複数の tinker run** (例: 異なる starting train.py) の比較に使える
- `research.publish` で `tinker/` 全体を bundle 化 (BEST.json + best train.py + RESULTS.md) → Zenodo DOI

## ユーザー向け小型化ガイド

karpathy README の "Platform support" 節に倣い、Macbook / RTX-3090 等の小規模環境向けに小型化推奨:

| パラメータ | default (H100) | 小型 (RTX-3090) | 極小 (CPU/MPS smoke) |
|-----------|---------------|-----------------|-----------------------|
| `DEPTH` | 8 | 4 | 2 |
| `MAX_SEQ_LEN` | 1024 | 512 | 256 |
| `TOTAL_BATCH_SIZE` | 2^16 | 2^14 | 2^10 |
| `vocab_size` | 8192 | 4096 | 1024 |
| dataset | fineweb-edu | tinystories | tinystories (subset) |
| `TINKER_BUDGET_SECONDS` | 300 | 300 | 60 (smoke only) |

詳細は `references/tinker_loop.md` の "Small-compute guide" を参照。

## 関連ドキュメント

- `references/tinker_loop.md` — autonomous loop 仕様 (SoT)、推奨アクション、reset / revert ロジック
- `references/program_md_template.md` — agent 指示書雛形
- `references/train_py_template.py.txt` — ~200 行最小 GPT
- `references/prepare_py_template.py.txt` — ~80 行 data prep + dataloader + eval util
- `references/results_log_format.md` — RESULTS.md / events.jsonl の format 仕様
- `references/tinker_pyproject_template.toml` — minimal deps (torch / numpy / tiktoken / datasets)
- 上流 inspiration: <https://github.com/karpathy/autoresearch>
