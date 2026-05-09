# Strategy × Domain Adapter Matrix (v0.12.0+)

`research.autonomous.swarm` の 5 戦略 (depth/lr/arch/batch/random-restart) は LLM hparam を例示しているが、本質は普遍的:

| 戦略 | 普遍的テーマ |
|------|-------------|
| `depth-explore` | model scale (層数 / 幅 / 容量) |
| `lr-explore` | optimization (lr / decay / schedule / optimizer choice) |
| `arch-explore` | structural ideas (attention variant / norm / activation / new components) |
| `batch-explore` | throughput vs gradient noise (batch / seq_len / accumulation) |
| `random-restart` | escape from local optima (uniform sampling) |

本 SoT は **domain × strategy の 20 セル** で「**何を動かすか / 何を触らないか / domain 固有 hint**」を明示する。
agent は swarm/program_<strategy>.md と本ファイルを併読して domain context に翻訳する。

> 参照順: `program_<strategy>.md` (戦略の核) → 本ファイル (domain への翻訳) → `domains/<name>/program.md` (domain 固有制約)

## 戦略 1: `depth-explore` × 各 domain

| domain | 動かす Config | 触らない | hint |
|--------|---------------|---------|------|
| `lm-pretrain` | `depth`, `n_heads`, `d_model`, `mlp_ratio` | lr / batch / seq_len | head_dim ≥ 32 を保つ |
| `vision-classification` | `n_filters`, `depth` (block 数), `fc_hidden`, `mlp_ratio` (相当) | lr / batch_size / augmentation | 32×32 入力では depth=4 で 2×2 spatial、それ以上は overkill |
| `rl-cartpole` | `hidden`, `depth`, `activation` 種別 (構造的) | lr / gamma / batch | CartPole は obs_dim=4 で大規模 net 不要、hidden=128 で頭打ち |
| `tabular-classification` | `hidden`, `depth`, `dropout`, `activation` | lr / weight_decay / batch | 30 features の小規模 dataset、wide-and-shallow が深層より有効 |
| `nlp-classification` | `hidden`, `depth`, `embed_dim` (もしあれば), `dropout` | lr / batch / vectorizer params | bag-of-words MLP は depth=2-3 で頭打ち、embedding dim は vocab に対し 64-256 |

## 戦略 2: `lr-explore` × 各 domain

| domain | 動かす Config | 触らない | hint |
|--------|---------------|---------|------|
| `lm-pretrain` | `lr`, `weight_decay`, `betas`, `warmup_iters`, `min_lr_ratio`, `grad_clip`, schedule shape, optimizer (AdamW / Lion 風) | depth / d_model / batch | lr ∈ [1e-4, 1e-3]、warmup 5-20%、grad_clip 0.5-2.0 |
| `vision-classification` | `lr`, `weight_decay`, `momentum` (if SGD), `warmup`, schedule, optimizer (SGD / AdamW) | n_filters / depth / batch / augmentation | CIFAR は SGD+momentum が伝統的、AdamW も競合。wd=5e-4 が強い default |
| `rl-cartpole` | `lr`, `gamma`, `weight_decay`, `entropy_coef`, optimizer, return normalization | hidden / depth / episodes_per_update | RL は hyperparam sensitive、lr 1e-3 〜 5e-3、gamma 0.99 が default |
| `tabular-classification` | `lr`, `weight_decay`, `betas`, `warmup`, optimizer, label smoothing | hidden / depth / batch | wd ∈ {1e-3, 1e-2, 1e-1} (小 dataset で重要)、label_smoothing 0.0-0.1 |
| `nlp-classification` | `lr`, `weight_decay`, `warmup`, optimizer | hidden / depth / vectorizer | TF-IDF + MLP では lr 1e-3 ~ 5e-3、wd 1e-4 ~ 1e-2 |

## 戦略 3: `arch-explore` × 各 domain

| domain | 動かす (構造的) | 触らない | hint |
|--------|----------------|---------|------|
| `lm-pretrain` | attention variant (causal / GQA / MQA / sliding) / posenc (learned / RoPE / ALiBi) / norm (LN/RMSNorm) / activation (GELU / SwiGLU) / weight tying / pre-vs-post LN | lr / batch / depth | 1 つだけ変える、外部ライブラリ依存禁止 |
| `vision-classification` | conv variant (3x3 / depthwise / dilated) / norm (BN / GN / LN) / activation (ReLU / GELU / SiLU) / SE block / residual / 1×1 bottleneck | n_filters / depth / batch / lr | BN は CNN の伝統的勝ち手、GN は small batch で有効 |
| `rl-cartpole` | policy 出力 (categorical / Gaussian) / value head の有無 / LSTM 導入 / discount 戻り正規化 / GAE | hidden / depth / lr | actor-critic で baseline を導入、PPO-lite で clipped objective |
| `tabular-classification` | residual connections / batch norm / layer norm / mixup-for-tabular / feature crossing / ensembling 構造 | hidden / depth / lr | 30 features は線形性も強い、residual は複雑化のみだと逆効果 |
| `nlp-classification` | text 表現 (BoW / TF-IDF / hashing trick) / 文字 n-gram 追加 / IDF 重み / SVD 圧縮 | classifier hparam | 浅い MLP では text 表現の差が dominant、bigram 追加が小コスト大効果 |

## 戦略 4: `batch-explore` × 各 domain

| domain | 動かす Config | 触らない | hint |
|--------|---------------|---------|------|
| `lm-pretrain` | `device_batch_size`, `grad_accum_steps`, `max_seq_len`, `total_batch_size` | lr / depth / arch | seq_len 倍増は attn 計算 4x、lr の linear scaling 注意 |
| `vision-classification` | `batch_size`, image resolution scale (固定 32×32 では n/a) | n_filters / lr / aug | 大 batch + 大 lr (linear scaling rule)、small batch + BN は不安定 |
| `rl-cartpole` | `episodes_per_update`, `batch_size` (PPO-lite なら mini-batch も) | hidden / lr / gamma | 5-20 ep/update、多すぎるとサンプル効率悪化、少なすぎるとノイズ高 |
| `tabular-classification` | `batch_size` (16-128) | hidden / lr / wd | 569 sample なら full-batch も viable。SGD with batch=32 が伝統 |
| `nlp-classification` | `batch_size`, `max_features` (vectorizer 出力次元) | classifier hparam | TF-IDF の次元が effective batch に効く、5k-20k features 推奨 |

## 戦略 5: `random-restart` × 各 domain

`random-restart` は **過去履歴を見ない uniform sampling** が本質。各 domain で hparam range を定義:

| domain | sampling 範囲 (例) |
|--------|-------------------|
| `lm-pretrain` | depth ∈ {2,4,6,8}, n_heads ∈ {2,4,6,8}, d_model ∈ {128,256,384,512}, lr ∈ logU(1e-4,1e-3), batch ∈ {16,32,64} |
| `vision-classification` | n_filters ∈ {32,64,128}, depth ∈ {2,3,4}, lr ∈ logU(1e-4,5e-3), wd ∈ {1e-4,5e-4,1e-3}, aug_flip ∈ {0,1}, aug_crop_pad ∈ {0,2,4} |
| `rl-cartpole` | hidden ∈ {32,64,128,256}, depth ∈ {1,2,3}, lr ∈ logU(1e-4,1e-2), gamma ∈ {0.95,0.99,0.995}, episodes_per_update ∈ {3,5,10,20} |
| `tabular-classification` | hidden ∈ {16,32,64,128,256}, depth ∈ {1,2,3,4}, lr ∈ logU(1e-4,1e-2), wd ∈ logU(1e-4,1e-1), dropout ∈ {0.0,0.1,0.2,0.3} |
| `nlp-classification` | max_features ∈ {1000,5000,10000,20000}, hidden ∈ {32,64,128,256}, depth ∈ {1,2,3}, lr ∈ logU(1e-4,1e-2) |

constraint check (例: `d_model % n_heads == 0`) を agent が再 draw で守る。

## 共通の不変条件 (どの戦略 / どの domain でも)

1. **forbidden imports は domain ごとに守る** (pyproject.toml の禁止リスト + tinker_run.sh の grep)
2. **val split は不可侵** (各 domain prepare.py で固定)
3. **`tinker/result.json` を必ず書く** (`primary_metric` / `metric_name` / `direction` / `domain`)
4. **history snapshot を残す** (改善時 `tinker/history/iter_<N>.py`)
5. **戦略から逸脱しない** (program_<strategy>.md の hard rules を守る)

## どう使うか (agent 視点)

1. `swarm/agent_<id>/tinker/program.md` を読む (戦略指示)
2. 自分の **domain** が何か確認 (`tinker/data/manifest.json` の `domain` field)
3. 本ファイル (`strategy_adapters.md`) で `(domain, strategy)` セルを参照
4. domain 固有の Config 範囲で hill-climb / random sample を実行

## 拡張 (将来)

新 domain / 新戦略を追加する際は本ファイルに行を追加すること。**4 + 5 ≤ 10** までは管理可能、それ以上は分割を検討。
