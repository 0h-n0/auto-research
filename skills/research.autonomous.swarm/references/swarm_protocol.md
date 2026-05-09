# Swarm Protocol — file-based agent communication (SoT)

複数 agent が干渉せずに並列実行するための **file-based protocol**。
共有メモリ / 排他制御は最小限で、ファイルロックと append-only ログで race を回避する。

## ディレクトリレイアウト

```
.research/<slug>/
├── swarm/
│   ├── SHARED_BEST.json       # 全 agent 横断 global best (orchestrator が更新、agents は read-only)
│   ├── SWARM_RESULTS.md       # 集約 table (orchestrator が定期再生成)
│   ├── best_train.py          # SHARED_BEST.json が指す train.py のスナップショット
│   ├── orchestrator.lock      # swarm_orchestrate.sh が実行中の flock
│   └── agent_<id>/
│       └── tinker/            # 通常の tinker workspace (v0.9.0 構造)
│           ├── program.md     # 戦略別 (depth/lr/arch/batch/random-restart)
│           ├── train.py       # agent が編集
│           ├── prepare.py     # immutable
│           ├── data/          # agent_1/tinker/data の symlink (1 回だけ生成)
│           ├── BEST.json      # この agent の local best
│           ├── RESULTS.md     # この agent の iter log
│           ├── history/       # iter_<N>.py snapshots
│           └── result.json    # 直近 iter の生 result
```

## ファイル所有権

| ファイル | 書き込む主体 | 読み込む主体 | lock 必要? |
|----------|-------------|-------------|-----------|
| `agent_<id>/tinker/train.py` | その agent | その agent + orchestrator (read) | no (agent は単一プロセス) |
| `agent_<id>/tinker/BEST.json` | その agent (の tinker_run.sh) | orchestrator | atomic write (tmp + rename) |
| `agent_<id>/tinker/RESULTS.md` | その agent (append) | orchestrator + 人間 | append-only (race-free) |
| `agent_<id>/tinker/history/iter_*.py` | その agent | その agent (revert) + orchestrator (best snapshot) | write-once filename |
| `swarm/SHARED_BEST.json` | orchestrator のみ | 全 agent (read-only) | flock |
| `swarm/SWARM_RESULTS.md` | orchestrator のみ | 人間 | flock (regenerate 全体) |
| `swarm/best_train.py` | orchestrator のみ | 全 agent (read for cross-pollination) | atomic write |
| `swarm/orchestrator.lock` | orchestrator のみ | orchestrator | flock 自身 |

## 通信パターン

### Bottom-up (agent → swarm)

各 agent が `tinker_run.sh` を実行するたび、以下が更新される:
- `agent_<id>/tinker/BEST.json` (改善時)
- `agent_<id>/tinker/RESULTS.md` (毎 iter append)
- `agent_<id>/tinker/result.json` (毎 iter overwrite)

agent は `swarm/` 配下を **読むだけ**、書かない。

### Top-down (swarm → agents)

`swarm_orchestrate.sh` が定期 (cron / 手動) 実行されるたび:
1. `swarm/orchestrator.lock` で `flock` (排他)
2. 全 `agent_<id>/tinker/BEST.json` を read
3. 最良 (val_bpb 最小) を選定
4. `swarm/SHARED_BEST.json` を atomic write (tmp + rename)
5. winner agent の `history/iter_<N>.py` を `swarm/best_train.py` に copy
6. 全 agent の RESULTS.md を集約して `swarm/SWARM_RESULTS.md` を再生成
7. `events.jsonl` に `event=swarm.consensus` を 1 行追加 (任意)
8. lock 解放

agent はこれを **次の iter の冒頭で読み込み** 、cross-pollination するか戦略に従って決める (program.md で個別指定)。

### Cross-pollination (optional)

各戦略の program.md で **個別に** 指定:
- `depth-explore` の program.md: "Reading swarm/best_train.py is OK as a base, but only borrow architectural ideas."
- `random-restart` の program.md: "DO NOT read swarm/best_train.py — full random sampling only."
- `arch-explore` の program.md: "May read swarm/best_train.py for inspiration, but explore radically different ideas."

つまり cross-pollination は agent の戦略に sub-ordinate する。orchestrator が強制しない。

## Race condition 対策

### 同時 BEST.json 更新

各 agent は単一プロセス、`tinker_run.sh` が serial に実行されるので agent 内に race なし。
複数 agent は **異なる `agent_<id>/` 配下**で動くので衝突しない。

### orchestrator vs agent

agent が `tinker/result.json` を書いている瞬間 orchestrator が読むと中途状態を読みうる。対策:
- agent の tinker_run.sh は `result.json.tmp` に書いて `mv` で atomic rename
- orchestrator は `flock` で排他し、各 BEST.json を 1 回ずつ読む (atomic write 前提なので tmp は読まない)

### 複数 orchestrator 同時起動

`orchestrator.lock` で `flock` を取り、取れない場合は `[swarm_orchestrate] another orchestrator running, skipping.` で exit 0。
よって cron で重なっても害なし。

### symlink: data/

`agent_1/tinker/data/` を実体、agent_2 以降は `agent_<i>/tinker/data → ../../agent_1/tinker/data` の symlink。
prepare.py は agent_1 で 1 回だけ実行、他 agent は symlink を読むだけなので race なし。
swarm_init.sh が symlink を貼る。

## SHARED_BEST.json schema

```json
{
  "schema_version": 1,
  "winner_agent_id": "agent_2",
  "winner_strategy": "lr-explore",
  "iter_in_agent": 42,
  "val_bpb": 1.398,
  "wall_time_s": 297.4,
  "n_iters_train": 14820,
  "config_snapshot_path": "swarm/agent_2/tinker/history/iter_42.py",
  "config_sha256": "abc1234...",
  "best_train_py_path": "swarm/best_train.py",
  "consensus_at": "2026-05-10T03:14:15Z",
  "agents_summary": [
    {"id": "agent_1", "strategy": "depth-explore", "best_val_bpb": 1.430, "iters_completed": 38},
    {"id": "agent_2", "strategy": "lr-explore",    "best_val_bpb": 1.398, "iters_completed": 42},
    {"id": "agent_3", "strategy": "arch-explore",  "best_val_bpb": 1.512, "iters_completed": 35}
  ]
}
```

## SWARM_RESULTS.md format

```markdown
# Swarm Results — <slug>

Last consensus: 2026-05-10T03:14:15Z

## Global Best
- Winner: agent_2 (lr-explore) at iter 42, val_bpb=1.398
- Snapshot: swarm/agent_2/tinker/history/iter_42.py
- Best train.py: swarm/best_train.py

## Per-agent best

| agent_id | strategy | best val_bpb | iters | improvement vs baseline |
|----------|----------|--------------|-------|-------------------------|
| agent_1  | depth-explore | 1.430 | 38 | -0.055 |
| agent_2  | lr-explore    | 1.398 | 42 | -0.087 ← winner |
| agent_3  | arch-explore  | 1.512 | 35 | +0.027 (worse) |

## Cross-strategy timeline (optional, last 10 best updates)

| ts | agent | iter | val_bpb | new_global? |
|----|-------|------|---------|-------------|
| ... | agent_1 | 8 | 1.487 | yes |
| ... | agent_2 | 17 | 1.430 | yes |
| ... | agent_2 | 42 | 1.398 | yes |
```

## events.jsonl への新 event (任意)

orchestrator が consensus 更新時に追記 (events.schema.json の `event` pattern にマッチ):

```json
{"event":"swarm.consensus","level":"info","ts":"2026-05-10T03:14:15Z",
 "run_id":"...","duration_ms":120,
 "winner_agent":"agent_2","winner_strategy":"lr-explore",
 "winner_iter":42,"global_best_val_bpb":1.398}
```

## まとめ

- **agent は agent_<id>/ 配下のみ書き込む**
- **orchestrator は swarm/ 配下のみ書き込む** (flock 排他)
- **agent は swarm/ を read-only**
- atomic write (tmp + rename) と append-only ログで race を回避
- cross-pollination は agent の戦略に従う (orchestrator は強制しない)
