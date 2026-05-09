# Agent Dispatch Matrix

`auto-research` プラグインで使う **5 specialist subagents** と既存ユーザー側エージェント (`arxiv-mcp-agent`, `ml-engineer`) の役割境界を 1 表にまとめる。
重複を避け、各 phase でどの agent をどう dispatch するかの単一参照点。

最終更新: v0.3.0

## エージェント一覧

| agent | 場所 | model | 主用途 | 並列起動可? |
|-------|------|-------|--------|-------------|
| `arxiv-mcp-agent` | `~/.claude/agents/arxiv-mcp-agent.md` (ユーザー側) | sonnet | breadth-first arXiv 探索 | 通常 1 回 / phase |
| `ml-engineer` | `~/.claude/agents/ml-engineer.md` (ユーザー側) | sonnet | 一般 ML 実装 (training loop, data pipeline, eval) | 通常 1 回 / phase |
| `paper-deep-reader` | `agents/paper-deep-reader.md` (本プラグイン) | sonnet | 単一論文 derivation-level 読解 | **YES** (papers ごとに並列) |
| `research-gap-finder` | `agents/research-gap-finder.md` (本プラグイン) | opus | cross-paper 統合・ギャップ抽出 / Phase 8 では reviewer モード | **YES** (Phase 3 で seed違い ×3) |
| `experiment-designer` | `agents/experiment-designer.md` (本プラグイン) | opus | RQ → 仮説 → ablation 表 → 統計検定 (仕様化のみ、実装は ml-engineer に handoff) | 通常 1 回 |
| `attention-analyst` | `agents/attention-analyst.md` (本プラグイン) | opus | mechanistic interpretability (logit lens / patching / probing / SAE) | 1 回 / probe |
| `result-statistician` | `agents/result-statistician.md` (本プラグイン) | sonnet | 統計検定 / CI / 効果量 / matplotlib | 通常 1 回 |

## Phase × Agent dispatch 表

各 phase で「どの agent を、どんな入力で、何を返してもらうか」を表にする。
**同じ phase で重複呼び出しが起きない** ように設計。

| Phase | dispatch される agent | 入力 | 期待出力 | 注 |
|-------|----------------------|------|----------|-----|
| 1 (Topic Framing) | (なし — `auto-research` skill 自身が処理) | `$ARGUMENTS` | `01_BRIEF.md` | Gate G1 で対話 |
| 2 (Lit Survey) breadth | `arxiv-mcp-agent` × 1 | 検索クエリ群 (3-6 個) | `02_SURVEY/papers.jsonl` (≥10 候補) | breadth-first |
| 2 (Lit Survey) depth | `paper-deep-reader` × 3-5 並列 | 各 `paper_id` | `02_SURVEY/notes/<id>.md` (固定スキーマ) | 並列重複防止に `papers.jsonl` を mutex |
| 3 (Gap & Ideation) | `research-gap-finder` × 3 並列 | `MATRIX.md`, `papers.jsonl`, `notes/*.md`, `seed_angle=A/B/C` | `03_GAP_ANALYSIS_{A,B,C}.md` | seed バリエーションで多様性 |
| 3 (統合) | (なし — skill 内で 3 出力をマージ) | 3 つの gap analysis | `03_IDEAS.md` | Gate G2 で対話 |
| 4 (Experiment Design) | `experiment-designer` × 1 | 採択 idea, `01_BRIEF.md` の budget | `04_EXPERIMENT_PLAN.md` | Gate G3 で対話 |
| 5 (Scaffold + TDD) impl | `ml-engineer` × 1 (handoff) | `04_EXPERIMENT_PLAN.md`, scaffold 済みコード | Green phase 実装 | TDD: experiment-designer → ml-engineer |
| 5 (focus_area=attention) probe setup | `attention-analyst` × 1 | RQ + 仮説 | `analysis/<slug>.py` 雛形 | 内部解析 setup |
| 6 (Run & Analysis) stats | `result-statistician` × 1 | `06_RUNS/*/metrics.json` | `06_RESULTS.md`, `figures/*.pdf` | paired bootstrap 等 |
| 6 (focus_area=attention) probe | `attention-analyst` × 1-N | 完了 run の checkpoint | `06_RUNS/attention/<probe_id>.md` | mechanistic interpretation |
| 7 (Paper Drafting) related work 最終確認 | `arxiv-mcp-agent` × 1 | focus_area + main keywords, 直近 3 ヶ月 | 追加候補 ≤5 本 | 既存 `papers.jsonl` で claim 済みは除外 |
| 7 (章ごと並列) | (なし — main thread の Task 並列でドラフト) | sections 用入力 | `paper/sections/*.md` | agent ではなく Task 並列を使う |
| 8 (Self-Review) reviewer | `research-gap-finder` × 1 (mode=reviewer) | `paper/main.{tex,md}`, `06_RESULTS.md` | `08_REVIEW.md` | 同 agent を別モードで再利用 |

### Phase 4 後段 — Procurement (v0.8.0+)

| Phase | dispatch される skill | 入力 | 期待出力 | 注 |
|-------|----------------------|------|----------|-----|
| 4 (Experiment Design) 後段 | `research.compute.shop` skill | gpu_type / gpu_count / duration_h (`04_EXPERIMENT_PLAN.md` の compute estimate から) | `.research/<slug>/COMPUTE_PROCUREMENT.md` (provider ランク) | agent ではなく skill。`experiment-designer` が出した compute 見積を受けて借りる先を決める |

### Phase 5-6 — Autonomous Tinker Mode alt (v0.9.0+)

`04_EXPERIMENT_PLAN.md` の `mode: tinker` 選択時、Phase 5-6 はこの alt path を取る (通常 ablation 設計 path とは別ルート):

| Phase | dispatch される skill | 入力 | 期待出力 | 注 |
|-------|----------------------|------|----------|-----|
| 5 (Scaffold alt) | `research.autonomous.tinker` skill | `04_EXPERIMENT_PLAN.md` mode=tinker | `.research/<slug>/tinker/{train.py, prepare.py, program.md, pyproject.toml, data/, history/}` | `research.experiment.scaffold` の代わりに dispatch |
| 6 (Run alt, agent loop) | (no agent — autonomous loop in main thread) | `program.md` をエージェントが読む、`scripts/tinker_run.sh` を反復起動 | `tinker/RESULTS.md`, `tinker/BEST.json`, `06_RUNS/<run_id>/events.jsonl` (event=tinker.iteration) | `research.experiment.run` を使わず `tinker_run.sh` が直接 run を駆動 |
| 7 (Paper) | `research.paper.draft` skill | `tinker/RESULTS.md` + best `train.py` + `BEST.json` | "tinker journal" 形式のドラフト | 通常 path と同じ skill を使う (入力ソースが違うだけ) |

karpathy/autoresearch (March 2026, MIT) の単一ファイル編集自律ループ概念を、本プラグインの 8-phase 規律に統合した形。詳細は `skills/research.autonomous.tinker/SKILL.md`。

### Phase 5-6 — Swarm Mode (multi-agent, v0.10.0+)

`04_EXPERIMENT_PLAN.md` の `mode: tinker-swarm` 選択時、N agents (default 3) を並列に走らせる research org モード:

| Phase | dispatch される skill / script | 入力 | 期待出力 | 注 |
|-------|-------------------------------|------|----------|-----|
| 5 (Scaffold alt) | `research.autonomous.swarm` skill + `scripts/swarm_init.sh` | `04_EXPERIMENT_PLAN.md` mode=tinker-swarm + `--agents N --strategies a,b,c` | `.research/<slug>/swarm/agent_<id>/tinker/` × N + `swarm/MANIFEST.json` | tinker workspace を agent ごとに展開、data は symlink 共有 |
| 6 (Run alt, parallel) | (no agent — 各 agent が独立 autonomous loop) | 各 agent の strategy 別 program.md、`tinker_run.sh --workspace swarm/<aid>/tinker` | 各 agent の `BEST.json` + `RESULTS.md` + history snapshots | 戦略別に agent ごとに独立、cross-pollination は agent の判断 |
| 6 (Aggregator) | `scripts/swarm_orchestrate.sh` (cron 1h or manual) | 全 agent の BEST.json | `swarm/SHARED_BEST.json`, `swarm/SWARM_RESULTS.md`, `swarm/best_train.py` | flock 排他、atomic write、events.jsonl に `swarm.consensus` 追記 |
| 7 (Paper) | `research.paper.draft` skill | `swarm/SWARM_RESULTS.md` + winner agent の best train.py | "swarm research journal" ドラフト | 通常 path と同じ skill |

karpathy/autoresearch README で **future work** として明記された "research org code" を具体化したもの。詳細は `skills/research.autonomous.swarm/SKILL.md`。

## 重複境界 (anti-pattern)

各 agent が「自分の領分」を超えそうな場合、ここに従って handoff する:

- **paper-deep-reader → arxiv-mcp-agent への逆流禁止**
  paper-deep-reader が引用論文を追加で取得したくなったら、search_papers fallback を使うが、breadth-first 検索全体は arxiv-mcp-agent に委譲する。
- **experiment-designer → ml-engineer の handoff**
  仕様 (`04_EXPERIMENT_PLAN.md`) を作るのが experiment-designer の責務。実装は触らない。Phase 5 で main thread が ml-engineer を別途 dispatch する。
- **attention-analyst が訓練を必要としたとき**
  `Request to ml-engineer: train probe head on layer X activations, return checkpoint path` 形式で main thread 経由で ml-engineer に handoff。attention-analyst が直接訓練しない。
- **result-statistician と attention-analyst の並列実行**
  Phase 6 後段で同時に走るが、入力は `06_RUNS/*/metrics.json` (statistician) と checkpoint (analyst) で重複なし。書き出し先も違うため OK。
- **research-gap-finder のモード分岐**
  `mode=ideation` (Phase 3) と `mode=reviewer` (Phase 8) は別ロール。同じ agent を再利用するが、呼び出し時に `mode` 引数を必ず指定する。

## 並列起動の上限

- `paper-deep-reader`: 5 並列まで (token 予算と paper 入手レート制限による)
- `research-gap-finder`: 3 並列 (seed-A / B / C 固定)
- 上記以外: 1 並列が原則

並列起動の判断は `auto-research` skill の各 phase 説明に従う。`SKILL.md` に明示してある。

## 既存資産との非重複保証

**arxiv-mcp-agent と paper-deep-reader が重複しないか?**
- arxiv-mcp-agent: breadth (10+ 件を浅く triage)
- paper-deep-reader: depth (1 件を derivation-level で読解)
breadth → depth の順で必ず分離。同 phase で同じ paper を両方が処理することはない。

**ml-engineer と experiment-designer / attention-analyst が重複しないか?**
- experiment-designer: 仕様化 (実装しない)
- attention-analyst: 内部解析 (mechanistic interpretability、訓練しない)
- ml-engineer: 訓練・推論・eval pipeline 実装
3 者の責務はオーバーラップ ゼロ。

**ml-engineer と既存 (`~/.claude/agents/ml-engineer.md`) が同じか?**
本プラグインは ml-engineer を **新規作成しない**。ユーザー設定済みの既存 ml-engineer をそのまま dispatch する。
プラグインを別マシンに install する場合、ml-engineer agent (or 同等) がユーザー側に存在しないと Phase 5 が回らないため、README で前提として明記する。

## 変更時の更新義務

新しい subagent を追加 / 既存 agent の役割を変更したときは:

1. 当該 agent の `agents/<name>.md` を編集
2. 本ファイル (`DISPATCH_MATRIX.md`) の表を更新
3. `skills/auto-research/SKILL.md` の該当 phase 記述を更新
4. `RELEASING.md` の checklist で「DISPATCH_MATRIX が現状を反映」を確認
5. version bump (MINOR or MAJOR、後方互換性に応じて)
