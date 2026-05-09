---
name: research.autonomous.swarm
description: >
  research.autonomous.tinker (v0.9.0) の拡張。N agents (default 3) を並列に走らせ、
  各 agent に異なる探索戦略 (depth-explore / lr-explore / arch-explore / batch-explore /
  random-restart) を割り当てて diversity を確保する research org モード。
  全 agent の BEST.json を `swarm_orchestrate.sh` が定期集約し SHARED_BEST.json で global best を共有。
  Use when: 単一 agent の tinker (v0.9.0) で局所解にハマる、または overnight でより広範な
  探索空間をカバーしたいとき。
---

# `research.autonomous.swarm`

karpathy 流 autonomous tinker (v0.9.0) を **N agents 並列** に拡張した research org モード。

> **Acknowledgement**: 本 skill は [karpathy/autoresearch](https://github.com/karpathy/autoresearch) の README で **future work** として明記されている "research org code" (複数 agent 並列) のアイディアを具体化したもの。tinker single-agent と同じ規律を保ちつつ、戦略多様性で局所解を抜ける目的。

## なぜ multi-agent が必要か

単一 agent の hill-climbing は **局所解にハマりやすい**:

- 1 つの戦略にコミット → 改善が止まる → 全体探索が止まる
- 同じ「失敗パターン」を繰り返す
- 探索空間の大半が手付かず

複数 agent 並列で:

- agent ごとに **異なる戦略**で diversity 確保
- 1 つが行き詰まっても他が進む
- 戦略間の cross-pollination は orchestrator 経由で SHARED_BEST.json に集約

## 設計の核 (v0.9.0 tinker からの差分)

| 観点 | v0.9.0 tinker (single agent) | v0.10.0 swarm (N agents) |
|------|------------------------------|--------------------------|
| workspace | `.research/<slug>/tinker/` | `.research/<slug>/swarm/agent_<id>/tinker/` × N |
| program.md | 1 つ (general) | N 個 (戦略別、`references/program_<strategy>.md`) |
| BEST.json | `tinker/BEST.json` | 各 agent の `swarm/agent_<id>/tinker/BEST.json` + 集約 `swarm/SHARED_BEST.json` |
| 集約 | n/a | `scripts/swarm_orchestrate.sh` が定期実行 (cron / manual) |
| 結果表 | `tinker/RESULTS.md` | 各 agent + `swarm/SWARM_RESULTS.md` (集約) |
| events | `06_RUNS/<run_id>/events.jsonl` (1 つ) | `06_RUNS/<run_id>/events.jsonl` (各 agent が tag 付きで append) |

`research.autonomous.tinker` の core (train.py / prepare.py / tinker_run.sh) は **そのまま再利用**。swarm は agent 数 × workspace を増やすラッパー。

## 戦略 (5 種類)

各 agent には 1 つの戦略を割り当て (`references/program_<strategy>.md`):

| strategy | 何を変えるか | 推奨される使いどころ |
|----------|--------------|---------------------|
| `depth-explore` | depth / n_heads / d_model の構造変化に focus | architecture 探索 |
| `lr-explore` | lr / weight_decay / warmup / schedule に focus | optimization tuning |
| `arch-explore` | 大胆なアーキ変更 (attention variant / positional / norm 等) | 新アイディア試行 |
| `batch-explore` | batch / seq_len / grad_accum の throughput vs gradient noise tradeoff | compute efficiency |
| `random-restart` | 各 iter 完全ランダム初期化 (escape from local optima) | 局所解突破 |

## ワークフロー

### 1. Swarm scaffold

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/swarm_init.sh <slug> --agents 3
# Creates:
#   .research/<slug>/swarm/agent_1/tinker/  (program.md = depth-explore)
#   .research/<slug>/swarm/agent_2/tinker/  (program.md = lr-explore)
#   .research/<slug>/swarm/agent_3/tinker/  (program.md = arch-explore)
# Each agent_<id>/tinker/ is a full tinker workspace (train.py, prepare.py, etc.)
```

戦略選択は `--strategies depth-explore,lr-explore,arch-explore` で明示可能。
default は `agents=3` で `[depth-explore, lr-explore, arch-explore]`、`agents=5` で全 5 戦略。

### 2. Data prep (各 agent 共通、1 回のみ)

```bash
cd .research/<slug>/swarm/agent_1/tinker && uv sync && uv run python prepare.py
# 他 agent は同じ data/ を symlink で共有
for i in 2 3; do
  ln -sfn ../../agent_1/tinker/data .research/<slug>/swarm/agent_$i/tinker/data
done
```

(swarm_init.sh が自動で symlink を作る)

### 3. 各 agent に並列で autonomous loop を走らせる

各 agent ごとに別々の Claude Code セッション、または同じセッションで Task 並列で:

```text
# Agent 1
> "swarm/agent_1/tinker/program.md に従って overnight loop を回して。
   workspace は swarm/agent_1/tinker/。`bash scripts/tinker_run.sh <slug> --workspace swarm/agent_1/tinker` を反復起動して。"

# Agent 2 (別セッション or 並列 Task)
> "swarm/agent_2/tinker/program.md に従って..."
```

各 agent は同じ `tinker_run.sh` を再利用 (v0.9.0 で導入)。`--workspace` 引数を追加して runner が
agent ごとの subdirectory を扱えるようにする (v0.10.0 で `tinker_run.sh` に追加実装)。

### 4. Orchestrator (定期 or on-demand 集約)

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/swarm_orchestrate.sh <slug>
# Reads: .research/<slug>/swarm/agent_*/tinker/BEST.json
# Picks: global best across all agents
# Writes:
#   .research/<slug>/swarm/SHARED_BEST.json     (winner record)
#   .research/<slug>/swarm/SWARM_RESULTS.md     (aggregated table)
#   .research/<slug>/swarm/best_train.py        (winner snapshot)
```

cron 推奨頻度:
- overnight loop なら 1 時間に 1 回
- 短時間 burst なら 5 分に 1 回

### 5. Cross-pollination (任意)

orchestrator が global best を更新したら、各 agent は次の iter で `swarm/best_train.py` を base として参照可能。
**ただし強制ではない** (戦略多様性を維持)。program_<strategy>.md で agent ごとに使うか使わないか指定。

### 6. 仕上げ

overnight 完了後:
- `swarm/SWARM_RESULTS.md` を view (各 agent x 各 iter の matrix)
- `swarm/SHARED_BEST.json` の winner agent + iter を確認
- best train.py を `research.paper.draft` に渡して "swarm journal" として論文化

## next-step trailer

```
─────────────────────────────────────
[Phase 6/8] ●●●●●●○○  G3 ✓  🐝 swarm mode (3 agents)

→ 推奨: agent ごとに autonomous loop を起動
  agent_1 (depth-explore): bash scripts/tinker_run.sh <slug> --workspace swarm/agent_1/tinker
  agent_2 (lr-explore):    bash scripts/tinker_run.sh <slug> --workspace swarm/agent_2/tinker
  agent_3 (arch-explore):  bash scripts/tinker_run.sh <slug> --workspace swarm/agent_3/tinker

  代替:
   ・ bash scripts/swarm_orchestrate.sh <slug>   現状集約
   ・ /auto-research:research-status <slug>     進捗確認
─────────────────────────────────────
```

## 失敗モード

| failure | 検出 | 回復 |
|---------|------|------|
| agent 数 > 5 | swarm_init.sh の引数 check | 5 戦略しか定義されていないため reject、または同じ戦略を複数 agent に割当て可 (`--allow-duplicate`) |
| 1 agent が完全に発散 (連続 30 iter diverged) | swarm_orchestrate.sh の集計 | warning 出力、人間 review を促す。他 agent には影響なし |
| SHARED_BEST.json への並列書き込み衝突 | filesystem lock | swarm_orchestrate.sh は `flock` で排他、tinker_run.sh は read-only |
| data/ symlink が壊れる | swarm_init.sh の verify | re-init で symlink を作り直す (data を消さない) |
| 戦略名が不正 | swarm_init.sh の引数 validation | 5 種類のいずれか (depth/lr/arch/batch/random-restart) を提示 |

## Phase 連携

- v0.9.0 と同じく Phase 5-6 alt mode。`04_EXPERIMENT_PLAN.md` の `mode: tinker-swarm` で分岐
- Phase 7 (paper drafting) では `research.paper.draft` に `SWARM_RESULTS.md` を渡す
- `research.cost.estimate` で **agent 数倍の overnight USD** を試算 (3 agents × 12 iter/h × USD/h × hours)
- `research.compute.shop` で multi-GPU box (e.g. 4× RTX-4090) を推奨可能

## 関連ドキュメント

- `references/swarm_strategies.md` — 5 戦略の詳細仕様 (SoT)
- `references/swarm_protocol.md` — agent 間 file-based 通信プロトコル (BEST.json / SHARED_BEST.json)
- `references/program_depth_explore.md` — depth/n_heads/d_model 戦略の program.md 雛形
- `references/program_lr_explore.md` — lr/weight_decay/schedule 戦略
- `references/program_arch_explore.md` — 大胆アーキ変更戦略
- `references/program_batch_explore.md` — batch/seq_len/grad_accum 戦略
- `references/program_random_restart.md` — random restart 戦略
- 上流 inspiration: <https://github.com/karpathy/autoresearch> の "research org code" 言及部分
- 単一 agent 版: `skills/research.autonomous.tinker/SKILL.md`
