# Tinker Domain Packs (v0.11.0+)

`research.autonomous.tinker` は v0.9.0 で **LLM pretraining** に特化して始まったが、v0.11.0 から **domain-pluggable** に拡張された。
各 domain は **agent が単一ファイルを編集して固定 wall-clock budget で primary_metric を最適化する** という tinker の核を保ちつつ、領域固有の data / model / metric を持ち込む。

## 同梱される domain

| domain | metric (direction) | dataset | starting model | extras |
|--------|-------------------|---------|----------------|--------|
| `lm-pretrain` (default, v0.9.0+) | `val_bpb` (min) | TinyStories / FineWeb-edu | minimal GPT (~280 LoC) | torch + numpy |
| `vision-classification` (v0.11.0+) | `val_acc` (max) | CIFAR-10 (torchvision) | minimal CNN (~150 LoC) | torchvision |
| `rl-cartpole` (v0.11.0+) | `episode_return` (max) | CartPole-v1 (gymnasium) | REINFORCE policy net | gymnasium |
| `tabular-classification` (v0.11.0+) | `val_acc` (max) | sklearn breast_cancer | minimal MLP | scikit-learn |

`lm-pretrain` の templates はトップレベル (`references/{train,prepare}_py_template.py.txt` 等) にあり、後方互換のため移動していない。新 domain は `domains/<name>/` 配下に閉じ込められている。

## Domain pack の構成 (新 domain)

```
domains/<name>/
├── train.py.txt           # agent が編集する単一ファイル
├── prepare.py.txt         # 不変の data prep + dataloader/eval util
├── program.md             # 領域固有 mission / hard rules / hints / anti-patterns
├── pyproject.toml         # 領域固有 deps (extras)
└── metric_spec.json       # 主要 metric の名前と方向 (max/min)
```

### `metric_spec.json` の schema

```json
{
  "schema_version": 1,
  "name": "val_acc",
  "direction": "max",
  "scale": "linear",
  "min_useful": 0.0,
  "max_useful": 1.0,
  "notes": "CIFAR-10 top-1 validation accuracy; chance level = 0.10"
}
```

- `direction`: `max` か `min`。`tinker_run.sh` がこれを読んで best 判定を切り替える
- `min_useful` / `max_useful`: 報告時のスケール参考 (任意)
- `scale`: `linear` / `log` (val_bpb のような log 系か、acc のような linear か)

### `result.json` schema (v0.11.0+)

各 domain の `train.py` は domain に依らず以下を `tinker/result.json` に書く:

```json
{
  "primary_metric": 0.847,
  "metric_name": "val_acc",
  "direction": "max",
  "wall_time_s": 297.4,
  "n_iters": 12000,
  "diverged": false,
  "domain": "vision-classification",
  "config": {...}
}
```

**後方互換**: `lm-pretrain` domain は `val_bpb` フィールドも引き続き emit する (legacy callers のため)。
`primary_metric` フィールドが新標準で、`tinker_run.sh` は両方を見る。

## tinker_run.sh / swarm_init.sh の `--domain` フラグ

```bash
# Default (backward compatible: lm-pretrain)
bash scripts/tinker_run.sh <slug>

# Explicit domain
bash scripts/tinker_run.sh <slug> --domain vision-classification
bash scripts/swarm_init.sh <slug> --agents 3 --domain rl-cartpole
```

scaffold 時に domain 名から template path を解決:

- `lm-pretrain` → トップレベル `references/{train,prepare}_py_template.py.txt`, `program_md_template.md`, `tinker_pyproject_template.toml` (legacy)
- `<other>` → `references/domains/<other>/{train,prepare}.py.txt`, `program.md`, `pyproject.toml`

## 後方互換の保証

- `lm-pretrain` は default のままで、既存 v0.9.0/v0.10.0 プロジェクトは何も変えなくて良い
- `result.json` の `val_bpb` field は lm-pretrain では引き続き出力される
- `tinker_run.sh` は `primary_metric` 不在時に `val_bpb` を fallback として読む

## 戦略との関係 (swarm)

`research.autonomous.swarm` の 5 戦略 (depth-explore / lr-explore / arch-explore / batch-explore / random-restart) は **どの domain でも適用可**。各戦略の `program_<strategy>.md` は LLM hparam (depth, n_heads, d_model 等) を例示しているが、本質は「アーキ規模 / optimization / 構造的アイディア / batch / random」という方向性なので、domain 固有の Config (例: vision の `n_filters`, `kernel_size` 等) に読み替える。

将来 (v0.12.0+) には domain × strategy の cross-product で program_<domain>_<strategy>.md を細分化する余地あり (現時点では agent が文脈で読み替える前提)。

## 新 domain の追加手順 (将来の拡張)

1. `domains/<new-domain>/` ディレクトリ作成 (5 ファイル: train.py.txt / prepare.py.txt / program.md / pyproject.toml / metric_spec.json)
2. `train.py` は **必ず** `tinker/result.json` を上記 schema で書く
3. `prepare.py` は **immutable contract** (agent 編集不可)
4. `program.md` は領域固有の hard rules / hints / anti-patterns を明記
5. `tests/test_domains_smoke.sh` に新 domain の syntax check を追加
6. README ja/en の domain 表に行追加
7. CHANGELOG に MINOR entry

## 倫理 / data licensing

各 domain の `prepare.py` 冒頭に dataset license を明記:
- `lm-pretrain` TinyStories: MIT、FineWeb-edu: ODC-BY
- `vision-classification` CIFAR-10: license の confirm が必要 (https://www.cs.toronto.edu/~kriz/cifar.html)
- `rl-cartpole` gymnasium: MIT
- `tabular-classification` sklearn breast_cancer: BSD (sklearn 同梱)

PII を含む dataset は採用しない (responsible_research.md 準拠)。
