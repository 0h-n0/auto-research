# Swarm Strategies — Specification (SoT)

`research.autonomous.swarm` で各 agent に割り当てる **5 種類の探索戦略** の仕様。
program.md テンプレ群 (`program_<strategy>.md`) と 1:1 対応。

## 設計原則

1. **Diversity > Coverage**: 同じ空間を綿密に探るより、戦略間で重ならない探索領域を担当
2. **Hard restrict**: 各 agent は割り当てられた戦略 **以外の変更を控える** (探索粒度を保つため)
3. **Cross-pollination は許可**: orchestrator が共有する `swarm/best_train.py` を base に取り入れるのは可、ただし戦略から逸脱はしない
4. **共通制約は v0.9.0 と同じ**: forbidden imports / val split 不可侵 / `tinker/result.json` 出力契約

## 戦略 1: `depth-explore`

**目的**: アーキテクチャ規模の sweet spot を探す。

**主に動かす**:
- `Config.depth` (Transformer 層数、default 4)
- `Config.n_heads` (default 6)
- `Config.d_model` (default 384)
- `Config.mlp_ratio` (default 4)

**触らない (他 agent の領域)**:
- `Config.lr`, `Config.weight_decay`, `Config.warmup_iters`
- `Config.device_batch_size`, `Config.max_seq_len`

**推奨アクション例**:
- depth: 2 → 4 → 6 → 8 と log scale で探る
- n_heads × head_dim = d_model になるよう調整
- "small + many" vs "large + few" の comparison

**避けるべき**:
- 急激な depth 倍増 (OOM)
- mlp_ratio の極端化 (1 や 16)

## 戦略 2: `lr-explore`

**目的**: optimization の収束 / 安定性を改善。

**主に動かす**:
- `Config.lr` (default 3e-4)
- `Config.weight_decay` (default 0.1)
- `Config.warmup_iters` (default 100)
- `Config.min_lr_ratio` (default 0.1)
- `Config.betas` (default (0.9, 0.95))
- `Config.grad_clip` (default 1.0)

**触らない**:
- アーキテクチャ (`depth`, `n_heads`, `d_model`, `mlp_ratio`)
- batch / seq_len

**推奨アクション例**:
- lr を log scale で sweep (1e-4 から 1e-3)
- warmup ratio を全体 step の 5% 〜 20% で動かす
- weight_decay を 0 / 0.05 / 0.1 / 0.2 で比較
- betas[1] を 0.95 / 0.99 で比較 (Adam vs Lion 風)

**避けるべき**:
- 100x のジャンプ (発散しやすい)
- grad_clip を外す (NaN リスク)

## 戦略 3: `arch-explore`

**目的**: 構造的な新アイディアを試す。

**主に動かす**:
- attention 実装 (causal self-attn vs grouped-query)
- positional encoding (learned vs RoPE / ALiBi 風)
- normalization (LayerNorm vs RMSNorm)
- activation (GELU vs SwiGLU / GeGLU)
- residual scaling / init scheme

**触らない**:
- `Config.lr` 等の optimization (lr-explore の領域)
- batch / seq_len (batch-explore の領域)

**推奨アクション例**:
- weight tying あり / なし
- pre-LN vs post-LN
- bias の有無 (linear / norm)
- token embedding scale (sqrt(d_model) 乗算)

**避けるべき**:
- 全部一度に変える (因子分離不能)
- 外部ライブラリ依存 (forbidden imports)

## 戦略 4: `batch-explore`

**目的**: throughput と gradient noise の trade-off を最適化。

**主に動かす**:
- `Config.device_batch_size` (default 32)
- `Config.grad_accum_steps` (default 1)
- `Config.max_seq_len` (default 512)
- `Config.total_batch_size` (= bs × accum × seq_len)

**触らない**:
- アーキ
- lr (但し effective batch が変わるので linear scaling は推奨される — それは lr-explore agent と協調)

**推奨アクション例**:
- effective batch を 2x / 4x / 8x にして wall-clock 内 step 数の変化を観察
- seq_len を 256 / 512 / 1024 で context length 効果を測る
- grad_accum で memory 制約下で large batch を再現

**避けるべき**:
- OOM 直前ギリギリ (時間を浪費)
- seq_len と batch を同時に増やす (因子混合)

## 戦略 5: `random-restart`

**目的**: 局所解からの脱出。Hill climbing の罠を回避。

**主にやる**:
- 1 iter ごとに **完全ランダム** な Config (上記 1-4 戦略の範囲を一様抽選)
- 過去の best を一切参照しない (cross-pollination 無効)
- 単独の改善より、global best からは到達できない領域を狙う

**Random sampling 範囲 (program_random_restart.md に記載)**:
- depth ∈ {2, 4, 6, 8}
- n_heads ∈ {2, 4, 6, 8}
- d_model ∈ {128, 256, 384, 512}
- lr ∈ log_uniform(1e-4, 1e-3)
- batch_size ∈ {16, 32, 64}
- max_seq_len ∈ {256, 512, 1024}

**避けるべき**:
- 過去 iter の参照 (戦略が崩れる)
- 範囲外の極端値

## 戦略の組み合わせ

| agent 数 | default 戦略割当 |
|---------|-----------------|
| 1 | depth-explore (single でも有効) |
| 2 | depth-explore + lr-explore |
| 3 | depth-explore + lr-explore + arch-explore |
| 4 | + batch-explore |
| 5 | + random-restart |
| 6+ | 同戦略を `--allow-duplicate` で重複可能 (seed 違い) |

`swarm_init.sh --strategies a,b,c` で明示指定可。

## 戦略間の共通契約

全戦略は `references/swarm_protocol.md` 準拠:

1. **`tinker/result.json` を必ず書く** (`val_bpb`, `wall_time_s`, `n_iters`, `diverged`)
2. **forbidden imports は守る** (`transformers`, `tokenizers`, etc.)
3. **val split を学習に使わない**
4. **history snapshot を残す** (改善時 `tinker/history/iter_<N>.py`)
5. **戦略外の Config 変更を控える** (program.md で hard rule として明記)

## 戦略追加の方針

新戦略を追加するときは:

1. `references/program_<name>.md` を作成 (mission / hard rules / strategy hints / anti-patterns)
2. `references/swarm_strategies.md` (本ファイル) に節追加
3. `scripts/swarm_init.sh` の strategy validation list に追加
4. `tests/test_swarm_smoke.sh` で新 program.md の存在 + attribution check
5. SKILL.md と CHANGELOG にエントリ追加 (MINOR or PATCH bump)
