# auto-research

🇬🇧 [English version](README.en.md)

[![lint](https://github.com/0h-n0/auto-research/actions/workflows/lint.yml/badge.svg)](https://github.com/0h-n0/auto-research/actions/workflows/lint.yml)
[![release](https://img.shields.io/github/v/release/0h-n0/auto-research)](https://github.com/0h-n0/auto-research/releases)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

LLM 研究のフルライフサイクルを Claude Code 上で一気通貫で進めるためのプラグイン。
論文サーベイ → アイディア検証 → 実験設計・実装・実行 → 論文ドラフトまでを **8 phases / 4 user gates** の自動ワークフローでカバーする。

研究フォーカス領域:
- Evaluation & Benchmarking
- Agent / Tool-use 研究
- Fine-tuning / Post-training (SFT, RLHF, DPO, LoRA, ...)
- Prompt / In-context Learning
- **Attention 機構・LLM アーキテクチャ内部 (mechanistic interpretability)**

## 前提

- Python (uv) + PyTorch + HuggingFace Transformers
- 既存設定済みの [`arxiv-mcp-server`](https://github.com/blazickjp/arxiv-mcp-server) (本プラグインは同梱しない)
- (推奨) Semantic Scholar / HuggingFace Hub / GitHub の API トークン

## インストール (ローカル)

このプラグインはまだ marketplace に公開していません。お手元のディレクトリから直接インストールできます。
公式ドキュメント: <https://docs.claude.com/en/docs/claude-code/plugins>

### 方法 A: ローカル marketplace 経由 (Recommended、永続)

`.claude-plugin/marketplace.json` を同梱しています。Claude Code セッション内で:

```text
/plugin marketplace add ~/path/to/auto-research
/plugin install auto-research@auto-research
```

- `/plugin marketplace add <path>` でこのディレクトリを marketplace として登録
- `/plugin install auto-research@auto-research` で実プラグインを有効化
   (`<plugin-name>@<marketplace-name>` 形式。両方 `auto-research` なので二重)

確認:

```text
/plugin list           # 有効なプラグイン一覧
/help                  # /auto-research:research-start ... が見えれば成功
```

無効化したいときは `/plugin uninstall auto-research@auto-research`、
marketplace ごと外すなら `/plugin marketplace remove auto-research`。

### 方法 B: CLI フラグ (一時的、設定変更なし)

そのセッションだけ有効化したい場合:

```bash
claude --plugin-dir ~/path/to/auto-research
```

Claude Code を起動するたびに指定が必要。検証用途向け。

### 方法 C: シンボリックリンク (手動、最小)

marketplace を使わずユーザースコープに直接展開:

```bash
PLUGIN=~/path/to/auto-research

# skills を ~/.claude/skills/ に
for d in "$PLUGIN"/skills/*/; do
  ln -sf "$d" "$HOME/.claude/skills/$(basename "$d")"
done

# agents を ~/.claude/agents/ に
for f in "$PLUGIN"/agents/*.md; do
  ln -sf "$f" "$HOME/.claude/agents/$(basename "$f")"
done

# commands を ~/.claude/commands/ に
mkdir -p "$HOME/.claude/commands"
for f in "$PLUGIN"/commands/*.md; do
  ln -sf "$f" "$HOME/.claude/commands/$(basename "$f")"
done
```

PostToolUse hook と `.mcp.json` は手動マージが必要 (`~/.claude/settings.json` と `~/.claude.json` を編集)。
シンプルさを取るなら方法 A 推奨。

### 動作確認

```text
/help
```

以下が表示されれば成功:

```
/auto-research:research-start    新規 LLM 研究プロジェクトを開始 ...
/auto-research:research-design   Gap 分析・アイディア抽出と実験設計 ...
/auto-research:research-experiment
/auto-research:research-write
/auto-research:research-review
/auto-research:research-status
```

skill / agent も `/skills` および `Agent` ツールから参照できることを確認:

```text
> 「auto-research skill を使って "test topic" で Phase 1 の dry-run をして」
```

### テスト (v0.3.0+)

開発時は `tests/run_all.sh` で smoke / schema / regression を一括実行できます (CI でも自動):

```bash
bash tests/run_all.sh
# 8 tests pass / 0 fail を期待
```

依存: `bash`, `jq`, `python3` + `jsonschema` (or `uv`)。詳細は `tests/README.md`。

### MCP サーバーの取り扱い

`.mcp.json` で **動作確認済みの 2 種類** を同梱しています。**初回起動時に Claude Code が確認ダイアログを表示するので承認**してください。

#### 同梱 (実機検証済み)

| MCP server | パッケージ | 用途 | 認証 |
|------------|-----------|------|------|
| `semantic-scholar` | `uvx semanticscholar-mcp-server` | Phase 2/8 で論文メタ・引用グラフ補完、refs.bib の DOI 補完 | `SEMANTIC_SCHOLAR_API_KEY` (任意; 未設定でも動作するがレート制限が厳しい) |
| `github` | `npx -y @modelcontextprotocol/server-github` | Phase 5/8 で論文公式コード取得・issue 追跡 | `GITHUB_PERSONAL_ACCESS_TOKEN` (任意; 公開 repo のみなら不要) |

#### 同梱しない (依存・前提のみ)

- **`arxiv-mcp-server`** ([blazickjp/arxiv-mcp-server](https://github.com/blazickjp/arxiv-mcp-server)): 論文探索・取得・読解の中核。**ユーザー側で `~/.claude.json` に設定済みであることを前提とします**。
- **HuggingFace Hub**: PyPI の `huggingface-mcp-server` は実機検証で匿名スキャフォールド (no author / no docs / Python>=3.13 のみ) と判明したため v0.3.0 で同梱を停止しました。代わりに、実験コード内で `huggingface_hub` Python ライブラリ経由で直接アクセスするか、ユーザーが信頼できる HF MCP を独自に設定してください。

#### 未使用にしたい場合

- `~/.claude/settings.json` の `enabledMcpjsonServers` から外す
- または関連環境変数を未設定のままにする (認証なし fallback で動作)

### アンインストール

方法 A:

```text
/plugin uninstall auto-research@auto-research
/plugin marketplace remove auto-research
```

方法 C (symlink) で入れた場合:

```bash
# ~/.claude/skills, agents, commands から auto-research 関連の symlink を削除
find ~/.claude/skills ~/.claude/agents ~/.claude/commands -lname "*my-plugins/auto-research*" -delete
```

## クイックスタート

```text
/auto-research:research-start "attention sink in long-context Llama"
# Phase 1 (Topic Framing) → G1
# Phase 2 (Literature Survey) → MATRIX.md 生成

/auto-research:research-design
# Phase 3 (Gap & Ideation) → G2
# Phase 4 (Experiment Design) → G3

/auto-research:research-experiment
# Phase 5 (Scaffold + Baseline TDD)
# Phase 6 (Run & Analysis)

/auto-research:research-write
# Phase 7 (Paper Drafting)

/auto-research:research-review
# Phase 8 (Self-Review) → G4

/auto-research:research-status
# 現在の Phase / 直近 run / 次のアクション
```

### Next-Step Trailer (v0.2.0+)

各コマンドの完走時に、現在地と次のアクションを示す **trailer** が必ず出ます。
`STATE.json` から動的に組み立てられ、進捗・ゲート通過状況・推奨次コマンド・代替が一目で分かります。

```
─────────────────────────────────────
[Phase 4/8] ●●●●○○○○  G3 ✓

→ 推奨: /auto-research:research-experiment <slug>
  (Scaffold + Baseline TDD)

  代替:
   ・ /auto-research:research-status <slug>   進捗確認
   ・ /auto-research:research-design <slug>   G3 やり直し
─────────────────────────────────────
```

特殊状態にも対応:

| 状態 | trailer の挙動 |
|------|---------------|
| 通常進行 | 推奨: 次フェーズのコマンド + 代替 (status / 前フェーズやり直し) |
| sanity 失敗 (Phase 6 → 5 rollback) | 推奨: `research-experiment` 再実行 + 失敗詳細用の `status` |
| G4 致命的レビュー指摘 | 推奨: rollback target phase の re-entry |
| 複数 active project | slug 指定を促し `research-status` を推奨 |
| プロジェクト完了 (G4 ✓ + `completed_at`) | 推奨: 新規テーマで `research-start` |
| `STATE.json` 不在 (新規ユーザー) | 推奨: `research-start "<topic>"` |

表示仕様の単一ソースは `skills/auto-research/references/next_steps_template.md`。

## Cost & Observability (v0.5.0+)

### Cost tracking

`research.cost.estimate` skill で run 単位の USD コストを `metrics.json` に追記し、
プロジェクト累積コストを `06_COST_REPORT.md` に出力します。`compute_budget_gpu_h` の
80% / 100% で警告が出ます。

```text
> 「research.cost.estimate skill で <slug> のコストを更新して」
```

GPU 単価表は `skills/research.cost.estimate/references/gpu_price_table.json` に SoT 化
(A100 / H100 / H200 / L40S / RTX-4090 / TPU-v4 等を収録)。実契約価格と差がある場合は
`.research/<slug>/cost_overrides.json` で上書きできます:

```json
{
  "gpu_pricing": {"A100-80GB-SXM": 1.20},
  "note": "RunPod spot, 2026 Q2 contract"
}
```

### W&B / MLflow / TensorBoard 統合 (opt-in)

環境変数を設定するだけで自動有効化、未設定時は silent no-op:

| Backend | 環境変数 | extras |
|---------|---------|--------|
| W&B | `WANDB_API_KEY` (必須), `WANDB_PROJECT`, `WANDB_MODE` (任意) | `uv sync --extra wandb` |
| MLflow | `MLFLOW_TRACKING_URI` (必須), `MLFLOW_EXPERIMENT_NAME` (任意) | `uv sync --extra mlflow` |
| TensorBoard | `TB_LOG_DIR` | `uv sync --extra tensorboard` |

`events.jsonl` (auto-research core ログ) は常に書かれるため、observability backend は
**追加** ログ。完全 opt-in なので既存ユーザーは何もしなくて OK。

詳細: `skills/research.experiment.scaffold/references/observability_setup.md`

## Autonomous Tinker Mode (v0.9.0+)

[karpathy/autoresearch](https://github.com/karpathy/autoresearch) (Andrej Karpathy, 2026, MIT) に着想を得た **Phase 5-6 alt mode**。
Phase 4 G3 通過時に `04_EXPERIMENT_PLAN.md` で `mode: tinker` を選ぶと、agent が `tinker/train.py` 1 ファイルだけを反復編集し、固定 wall-clock budget (default 5 分) で nanochat-style な single-GPU LLM 訓練を **overnight 自律探索** します。

### 設計の核

1. **Agent は `tinker/train.py` のみ編集** (model / optimizer / hparams 全部 fair game)
2. **Fixed wall-clock budget per iteration** (`TINKER_BUDGET_SECONDS=300`、改造内容に依らず実験直接比較可、~12 iter/h、~100 iter overnight)
3. **単一比較メトリック `val_bpb`** (vocab-size-independent)
4. **`program.md` = agent への指示書** (human iterable、agent は読み込みのみ)
5. **Train → measure → keep/discard → repeat** の autonomous loop

### Quick start

```bash
# 1. tinker scaffold (Phase 5 で skill が自動展開)
> 「research.autonomous.tinker skill で <slug> に tinker mode を scaffold して」

# 2. データ準備 (1 回だけ)
cd .research/<slug>/tinker && uv sync && uv run python prepare.py

# 3. ベースライン 1 iter (sanity check)
bash scripts/tinker_run.sh <slug>

# 4. autonomous loop (agent が program.md を読んで反復編集 → tinker_run.sh)
> 「program.md に従って overnight loop を回して」
```

各 iter は:
- `tinker/RESULTS.md` に行追加 (human-readable)
- `06_RUNS/<run_id>/events.jsonl` に `event=tinker.iteration` を 1 行追加 (CLAUDE.md 規約準拠)
- 改善時のみ `tinker/history/iter_<N>.py` に train.py を snapshot + `tinker/BEST.json` 更新

### 安全機構

`scripts/tinker_run.sh` の pre-flight:
- train.py の Python syntax 検証
- forbidden import detection (`transformers` / `tokenizers` / `sentence_transformers` を block — pretrained 流入防止)
- timeout (`TINKER_BUDGET_SECONDS` 経過で SIGTERM、10 秒後 SIGKILL)
- OOM / divergence / runtime error は events.jsonl に `tinker.diverged` で記録

### 小型化ガイド (CPU/MPS/RTX-3090 でも動かしたい)

`skills/research.autonomous.tinker/references/tinker_loop.md` の "Small-compute guide" 節:

| 環境 | DEPTH | MAX_SEQ_LEN | TOTAL_BATCH_SIZE | dataset | budget |
|------|-------|-------------|------------------|---------|--------|
| CPU/MPS smoke | 2 | 128 | 2^10 | TinyStories subset | 60 s |
| RTX-3090 (24GB) | 4 | 512 | 2^14 | TinyStories full | 300 s |
| A100-80GB / H100 | 8 | 1024 | 2^16 | FineWeb-edu | 300 s |

詳細: `skills/research.autonomous.tinker/SKILL.md` および `references/tinker_loop.md`

### Acknowledgement

本 skill の概念 (single-file edit autonomy / fixed wall-clock budget / val_bpb / `program.md`) は karpathy/autoresearch のアイディア。本プラグインはそれを **8-phase ワークフローに統合する形で自前再実装** (コードの verbatim コピーはなし)。詳細は `skills/research.autonomous.tinker/SKILL.md` の Acknowledgement 節。

### Domain Packs (v0.11.0+)

v0.9.0 / v0.10.0 の tinker / swarm は **LLM pretraining** 専用でしたが、v0.11.0 から **3 つの新 domain** を追加:

| domain | dataset | starting model | metric (direction) |
|--------|---------|----------------|--------------------|
| `lm-pretrain` (default、v0.9.0+) | TinyStories / FineWeb-edu | minimal GPT (~280 LoC) | `val_bpb` (min) |
| `vision-classification` (v0.11.0+) | CIFAR-10 (torchvision) | minimal CNN (~200 LoC) | `val_acc` (max) |
| `rl-cartpole` (v0.11.0+) | CartPole-v1 (gymnasium) | REINFORCE policy (~190 LoC) | `episode_return` (max) |
| `tabular-classification` (v0.11.0+) | sklearn breast_cancer | minimal MLP (~150 LoC) | `val_acc` (max) |
| `nlp-classification` (v0.12.0+) | sklearn 20newsgroups (4-class) | TF-IDF + MLP (~150 LoC) | `val_acc` (max) |

```bash
# tinker single-agent + 別 domain
bash scripts/tinker_run.sh <slug> --domain vision-classification

# swarm (multi-agent) + 別 domain
bash scripts/swarm_init.sh <slug> --agents 3 --domain rl-cartpole
```

各 domain は **train.py.txt + prepare.py.txt + program.md + pyproject.toml + metric_spec.json** の 5 ファイルで完結。
`metric_spec.json` で direction (`min` / `max`) を宣言し、`tinker_run.sh` は direction-aware に best を比較。
**完全 後方互換**: 既存 `lm-pretrain` workspace は何も変えなくて良い (default のまま、`val_bpb` field も継続出力)。

5 戦略 (depth/lr/arch/batch/random-restart) は **どの domain でも適用可**。各戦略の program.md は LLM hparam を例示するが、本質は「規模 / 最適化 / 構造 / batch / random」なので agent が context で読み替える。

**v0.12.0+ で `strategy_adapters.md` 追加**: 5 戦略 × 5 domain = 25 セルのマッピング SoT (`skills/research.autonomous.swarm/references/strategy_adapters.md`)。各セルに「動かす Config」「触らない領域」「domain 固有 hint」を明示。swarm で非 LLM domain を回すとき、agent は `program_<strategy>.md` と本ファイルを併読して domain context に翻訳する。

詳細: `skills/research.autonomous.tinker/references/domains/README.md`

## Research Org Swarm Mode (v0.10.0+)

[karpathy/autoresearch](https://github.com/karpathy/autoresearch) の README で **future work** として明記されている "research org code" を具体化した **multi-agent 並列モード**。
v0.9.0 の単一 agent tinker を 1 単位として、**N agents (default 3) を並列**に走らせ、各 agent には異なる戦略を割り当てて diversity を確保します。

### 5 戦略

| strategy | 担当領域 |
|----------|---------|
| `depth-explore` | depth / n_heads / d_model / mlp_ratio (architecture scale) |
| `lr-explore` | lr / weight_decay / warmup / schedule / optimizer choice |
| `arch-explore` | attention variant / posenc / norm / activation (architectural ideas) |
| `batch-explore` | batch / grad_accum / seq_len (throughput vs gradient noise) |
| `random-restart` | 完全ランダム sampling (局所解突破) |

### Quick start

```bash
# 1. N agents の workspace を一括 scaffold
bash scripts/swarm_init.sh <slug> --agents 3
# → swarm/agent_1/tinker/  (depth-explore)
# → swarm/agent_2/tinker/  (lr-explore)
# → swarm/agent_3/tinker/  (arch-explore)
# → swarm/MANIFEST.json

# 2. データ準備 (agent_1 のみ実行、他 agent は symlink で共有)
cd .research/<slug>/swarm/agent_1/tinker && uv sync && uv run python prepare.py

# 3. 各 agent を並列に loop (別セッション or Task 並列で)
bash scripts/tinker_run.sh <slug> --workspace swarm/agent_1/tinker
bash scripts/tinker_run.sh <slug> --workspace swarm/agent_2/tinker
bash scripts/tinker_run.sh <slug> --workspace swarm/agent_3/tinker

# 4. 定期的に集約 (cron 1h 推奨)
bash scripts/swarm_orchestrate.sh <slug>
# → swarm/SHARED_BEST.json (global winner)
# → swarm/SWARM_RESULTS.md (集約 table)
# → swarm/best_train.py (winner snapshot)
```

### Cross-pollination

- 各 agent は `swarm/best_train.py` (orchestrator が更新する global best) を読める
- ただし **戦略から逸脱しない範囲で** inspiration として使うのみ
- `random-restart` agent は cross-pollination **無効** (purity 維持)
- 各戦略の `program_<strategy>.md` で個別に判断

### Protocol (file-based agent 通信)

- agent は `agent_<id>/` 配下のみ書き込む
- orchestrator は `swarm/` 配下のみ書き込む (`flock` 排他、atomic write)
- agent は `swarm/` を read-only
- 同時 orchestrator 起動は flock で skip (cron で重なっても害なし)

詳細仕様: `skills/research.autonomous.swarm/SKILL.md` および `references/swarm_protocol.md`

### Acknowledgement

本 skill は karpathy/autoresearch README の "research org code" 言及を具体化したもの。コアの単一 agent tinker は v0.9.0 と同じ自前実装を再利用し、orchestrator/protocol/戦略 templates のみ新規追加。詳細は `skills/research.autonomous.swarm/SKILL.md` の Acknowledgement 節。

## Publishing & Archival (v0.6.0+)

Phase 8 G4 通過後、`research.publish` skill で公開先を選んで一括 upload + DOI 取得:

```text
# 1. 前提: bundle を作成
> 「research.export skill で <slug> の公開バンドルを作って」

# 2. HF Hub + Zenodo に同時 upload (--draft で private/sandbox)
> 「research.publish skill で <slug> を draft で公開」

# 3. 本番公開 (Zenodo の DOI が確定する。取り消し困難)
> 「research.publish skill で <slug> を --no-draft で本公開」
```

### 公開先

| target | 用途 | 認証 env | 取り消し可 |
|--------|------|---------|-----------|
| HF Hub Datasets | modular な公開 / collaboration | `HF_TOKEN` | yes (private 化、削除可) |
| Zenodo | DOI 付き永続アーカイブ / 論文引用 | `ZENODO_ACCESS_TOKEN` (`ZENODO_SANDBOX=1` でテスト可) | **published 後は不可** (draft なら可) |

### 出力

- `.research/<slug>/PUBLICATION.md` — URL + DOI + bibtex 引用情報
- `.research/<slug>/STATE.json` の `published` フィールド更新

### Checkpoint Cleanup

```bash
# Dry-run (削除候補を表示するだけ、デフォルト)
bash scripts/cleanup_checkpoints.sh <slug>

# 30 日経過 + best run 保護で実削除
bash scripts/cleanup_checkpoints.sh <slug> --apply --keep-best
```

`--keep-best` は primary metric 最大の succeeded run の checkpoint を保護します。
詳細: `skills/auto-research/references/data_lineage.md` の "Retention 強制" / "Publishing & Archival" 節。

## Paper-First Methodology (v0.13.0+)

熟練研究者の暗黙知「**論文 (特に Abstract と Introduction) を実験前から書き始める**」を体現する仕組み。
v0.13.0 の `research.paper.scaffold` skill は **Phase 2 (literature survey 完了後)** から呼べて、
単一の living document `paper/DRAFT.md` を Phase 進行に合わせて上書き拡張します。

### Phase × DRAFT.md 充足度

| Phase done | 主に書かれる section | 充足度 |
|-----------|---------------------|--------|
| Phase 2 (Survey) | Abstract `[Background]` / `[Implication]` placeholder + Intro Motivation + **Related Work (引用付き)** + refs.bib | **55%** |
| Phase 3 (Idea) | + Abstract `[Method]` `[Hypothesis]` + Intro Contributions (3-4 bullets) | **70%** |
| Phase 4 (Plan) | + Method section + Setup + Baselines | **85%** |
| Phase 6 (Run) | + Results table + Abstract `[Hypothesis]→[Result]` 置換 | **95%** |
| Phase 7 (paper.draft) | Discussion + Limitations + 用語統合 + LaTeX 化 + DOI 補完 | **100%** |

### Hypothesis-driven Abstract

```markdown
[Background] LLM evaluation 領域の問題と既存手法の限界 (2-3 文)
[Method] 我々が提案する手法の核 (3-5 文)
[Hypothesis (Phase 6 で検証予定)] falsifiable な予測 + 統計的閾値 (1-2 文)
[Implication (検証成立時)] 研究コミュニティへの含意と次の問い (2-3 文)
```

Phase 6 完了後、`[Hypothesis]` ブロックは実測値の `[Result]` に置換されます。

### Related Work paragraph

`02_SURVEY/MATRIX.md` から sub-area グループ化、各 paper を 1-2 文で要約 + inline `\cite{}` 付き。
末尾に **"Position of our work"** paragraph を必ず入れて貢献位置を明示。
引用は `responsible_research.md` 準拠 (≤ 2 文 verbatim、商用 PDF キャッシュ禁止)。

### Quick start

`research.paper.scaffold` は `auto-research` ワークフローが Phase 2/3/4/6 末尾で **自動 dispatch**
しますが、手動でも:

```text
> 「research.paper.scaffold で <slug> の論文骨子を更新」
```

idempotent なので何度呼んでも問題ありません。
**agent-managed marker** (`<!-- agent-managed:Phase=N -->`) で人手編集を保護、削除すると skip + warning。

### 後方互換

- 既存プロジェクトで paper.scaffold を呼ばない → これまで通り Phase 7 で `research.paper.draft` が単独動作
- `paper.draft` (Phase 7、既存) は **DRAFT.md があれば使う、なければ既存挙動** (paper_skeleton から開始)

詳細: `skills/research.paper.scaffold/SKILL.md` および `references/phase_section_map.md`

## Lab Notebook & Reproducible Failures (v0.14.0+)

科学研究の本質は「成功した結果」だけでなく「**何を試して、なぜダメだったか、次に何を変えるか**」の積み重ねにあります。
v0.14.0 の `research.lab.notebook` skill は熟練研究者の lab notebook 文化をワークフローに統合し、
**失敗そのものも再現可能** にします。

### Hybrid 構造

| ファイル | 役割 |
|---------|------|
| `LAB_NOTEBOOK.md` (slug 直下) | 単一 living document、時系列の "思考航海日誌"。Phase 3/5/6/8 で entry が積み重なる |
| `06_RUNS/<id>/POSTMORTEM.md` | per-failure card (失敗 run のみ、auto-draft)。再現コマンド + Hypothesis space + Decision + Lessons |
| `03_REJECTED_IDEAS.md` | Phase 3 で捨てた idea の full body + reason + future revisit conditions (将来の pivot で再考可能) |

LAB_NOTEBOOK と POSTMORTEM は **双方向 link** で全体思考と個別失敗を navigate 可能。

### Phase × ノート動作

| Phase | 起動 | 主動作 |
|-------|------|--------|
| 3 (G2 通過後) | auto | rejected ideas 保存 + LAB_NOTEBOOK Phase 3 entry |
| 5 (TDD Red) | manual (任意) | LAB_NOTEBOOK に test failure short note (30 分 stuck で推奨) |
| 6 (run 完了) | **auto** | failed run があれば POSTMORTEM 下書き + reproduce.sh + uv.lock snapshot + LAB_NOTEBOOK entry。成功 run も 1 行 entry |
| 8 (Review) | auto | LAB_NOTEBOOK の Lessons を `08_REVIEW.md` に統合 |

### Hypothesis-driven 失敗 postmortem

POSTMORTEM の §3 Hypothesis space は **events.jsonl + error.txt から 3-5 仮説を auto-draft**:

```markdown
| H | Statement | Evidence | Verdict |
|---|-----------|----------|---------|
| H1 | batch_size=16 で activation memory が 40GB を超過 | events.jsonl:step=1240 gpu_mem=38.45GB | LIKELY |
| H2 | gradient checkpointing 未使用で activation 全保持 | config.yaml:gradient_checkpointing=false | LIKELY |
| H3 | data leak (前 step の tensor が GC されず) | code review (train.py:L120 zero_grad あり) | RULED OUT |
```

verdict は agent draft (LIKELY / UNLIKELY / RULED OUT) で、user が確定。
**§4 Decision と §5 Lessons は user polish 必須** (科学的価値の核心)。

### 失敗 run の Reproducibility 7-tuple

各 run (success / failed) で以下を自動保存:

1. **Code rev** (events.jsonl の git_rev、既存)
2. **Config** (`06_RUNS/<id>/config.yaml`、既存)
3. **Dependencies** (`06_RUNS/<id>/uv.lock` snapshot、**v0.14.0 で新規**)
4. **Random seed** (events.jsonl、既存)
5. **Data version** (data_lineage.md の hash、既存)
6. **Hardware** (events.jsonl の env、既存)
7. **Reproduce command** (`06_RUNS/<id>/reproduce.sh`、**v0.14.0 で新規**)

これにより `cd 06_RUNS/<id> && bash reproduce.sh` で同じ run (失敗 run も) を 1 コマンド再現可能。

### Quick start

`research.lab.notebook` は `auto-research` ワークフローが Phase 3/6/8 で **自動 dispatch** しますが、
手動でも呼べます:

```text
> 「research.lab.notebook で <slug> の失敗を記録 / lab notebook を更新」
```

idempotent — 再実行しても既存 POSTMORTEM の人手 polish を破壊しません。

### 後方互換性

- 既存プロジェクト (LAB_NOTEBOOK.md 不在) で Phase 1-8 通常動作
- v0.13.0 以前の `06_RUNS/<id>/` には best-effort で reproduce.sh だけ後付け (uv.lock は recover 不能、warning)
- `research.paper.scaffold` (v0.13.0) は LAB_NOTEBOOK Lessons を Phase 7 paper.draft の Limitations 節で素材化可能 (loose coupling)

詳細: `skills/research.lab.notebook/SKILL.md` および `references/phase_notebook_map.md`

## Lab Notebook Best Practices (v0.15.0+)

v0.14.0 の `research.lab.notebook` 構造に、外部の研究ノート best practice を取り入れた P0 4 要素 (Decision journal / Tag system / Cross-project Lessons DB / Blameless culture) を追加しました。
参考元: Annie Duke "How to Decide" (decision journal) / Google SRE "Blameless Postmortems" (blameless) / ELN FAIR guidelines (tags & index) / mlflow & W&B (metadata 慣習)。

### Decision journal (Light touch、Annie Duke 由来)

Phase 3 idea 採択時 / Phase 4 実験設計時に **「予測 / 信念 / 仮定」を記録**、Phase 6 で実測との Predicted vs Actual を auto 生成 (hindsight bias 防止):

```markdown
**Decision journal (Light touch)**:
- **Predicted outcome**: primary metric +3-5pp on MMLU baseline
- **Confidence**: 中 (prior work 5 本の平均改善が +2.5pp)
- **Key assumptions**:
  1. 4-factor variance が super-additively compose
  2. format が dominant (>30% contribution)
  3. 3-8B model size でも同 pattern
```

Phase 6 metacognition entry が agent draft で生成 (Surprise score 1-5 + What I missed、blameless で):

```markdown
| Metric / claim | Predicted | Actual | Surprise |
|----------------|-----------|--------|----------|
| primary acc improvement | +3-5pp | +1.2pp | 4 |
| dominant factor | format | decoding (3B) | 4 |
```

### Tag system (Hybrid、ELN FAIR 由来)

各 entry に末尾 `Tags: #...` を付与。Controlled vocabulary 28 個 + 自由 tag。`LAB_NOTEBOOK_INDEX.md` を auto-generate (tag 逆引き):

| カテゴリ | tags |
|---------|------|
| Failure type | `#oom` `#nan` `#shape-mismatch` `#timeout` `#import-error` `#data-bug` `#convergence-issue` |
| Outcome | `#hypothesis-confirmed` `#hypothesis-rejected` `#ruled-out` `#inconclusive` `#assumption-reversed` |
| Process | `#pivot` `#stuck` `#insight` `#peer-discussion` `#decision-adopted` `#decision-rejected` |
| Phase marker | `#phase-3` `#phase-4` `#phase-5` `#phase-6` `#phase-8` (auto) |

自由 tag (例: `#attention-sink`, `#llama-3b`) は INDEX.md 上で別節管理。

### Cross-project Lessons DB (`~/.research-lessons.json`)

Phase 8 で各プロジェクトの top 3 lessons を **全プロジェクト共通の DB** に atomic append。新プロジェクトの Phase 3 / 6 で類似 failure を検索可能 (institutional memory):

```text
> /auto-research:lessons-search "memory"               # free text
> /auto-research:lessons-search --tag #oom              # tag filter
> /auto-research:lessons-search "format" --phase 6      # phase filter
> /auto-research:lessons-search --model 3B              # context filter
```

### Blameless culture (Google SRE 由来)

POSTMORTEM 冒頭に **Blameless callout** を強制挿入。SKILL.md に Anti-pattern (人を責める言葉) と Pre-pattern (システム / プロセスを主語) を明示。失敗の原因はシステム / プロセスに帰属、個人の判断は「その時点の情報で reasonable だったか」の文脈で記述。

詳細: `skills/research.lab.notebook/references/decision_journal_template.md`、`tag_taxonomy.md`、`lessons_db_schema.md`、`blameless_principles.md`

## Lab Notebook P1 Polish (v0.16.0+)

v0.15.0 で Out of Scope に保留した **P1 3 要素** を v0.16.0 で実装。いずれも optional、workflow dispatch 不変。参考元: NIH IRP "Keeping Lab Notebooks" (ALCOA+) / Open Notebook Science (provenance) / 紙 lab notebook 伝統 (daily entry)。

### Provenance trace (思考の出処、任意)

各 entry / POSTMORTEM に出処を optional field で残す:

```markdown
**Provenance** (任意):
- **Inspired by**: ~\cite{hong2024chat} (MATRIX.md row #1)
- **Discussion**: AB @ 2026-05-11
- **External thread**: https://news.ycombinator.com/item?id=12345
- **AI assistant**: Claude Sonnet 4.6 @ 2026-05-11
```

- AI assistant の使用は **開示推奨** (NeurIPS / ICLR / ACL LLM-author ポリシー + Open Notebook Science 由来)
- agent は推測しない、user 手書きが基本
- Phase 7 で paper.draft が Acknowledgment auto-gen に活用 (将来 v0.17+)

### ALCOA+ correction guideline (紙 lab notebook 伝統)

> "Correct mistakes, but never remove them." — NIH IRP

markdown で `~~strike~~` + `<ins>new</ins>` + 注釈 (理由 + initials + 日付):

```markdown
The result was ~~3.14~~ <ins>2.71</ins>. (corrected 2026-05-15 by AB, reason: math error)
```

Git history で改ざん耐性を担保、markdown は人間可読 navigation aid。**lint 強制せず、教育 + ガイドラインで運用**。

### Daily summary entry (任意、Light touch 4-prompt)

Phase event 駆動を補完する日次 entry。完全フリーフォームではなく Light touch schema で書きやすさを担保:

```markdown
### 2026-05-13 [Daily summary]

- **Today's stuck**: lm-eval-harness の version 違いで 3h 進展なし
- **Today's insight**: harness version pinning が Phase 4 design checklist に欠落
- **Tomorrow's plan**: GitHub Issues 確認 → alternative version で再試行
- **Mood / energy**: 2/5

Tags: `#daily-summary` `#stuck` `#phase-5`
```

- **毎日強制でない**、書きたい日だけ
- Phase 1 / 2 / 7 (lab.notebook event 不在 Phase) でも notebook 連続性
- Phase 8 review 時に "Today's insight" / "Today's stuck" を generalizable lesson 素材に (将来 v0.17+)

詳細: `skills/research.lab.notebook/references/provenance_template.md`、`alcoa_correction_guideline.md`、`daily_summary_template.md`

## Visual Notebook (v0.17.0+)

実験ログ / lab notebook を **MkDocs material で HTML site にビルド**して視覚化します。MD は SoT として残し、HTML は `.research/<slug>/viz/` に generated artifact として出力 (git track 不要、`.gitignore` 推奨)。

### Quick start

```text
> /auto-research:notebook-viz <slug>           # build only
> /auto-research:notebook-viz <slug> --serve   # localhost:8000 で preview (live-reload)
> open .research/<slug>/viz/index.html         # browser で開く (build 後)
```

**Phase auto-dispatch なし** (build は重め、user が見たい時に manual 実行)。

### 視覚化要素

| 要素 | 機構 |
|------|------|
| **events.jsonl → time-series chart** | Chart.js (CDN) を per-run page に embed、loss / metric curves |
| **STATE.json → Phase progress bar** | HTML/CSS で全 page header に inject (done=緑 / current=青 / pending=灰) |
| **LAB_NOTEBOOK Tags → 逆引き index** | mkdocs frontmatter tags 変換 + tags plugin で auto-gen |
| **Sortable tables** | 06_RESULTS / MATRIX / 06_RUNS/INDEX を `attr_list` で sortable 化 |
| **Search box** | mkdocs-material native (日本語 + 英語 indexing) |
| **Dark / light mode** | mkdocs-material native palette switcher |

### 10 sections + tags index

`viz/index.html` を entry に:

```
Home (01_BRIEF) → Survey (MATRIX) → Ideas (adopted/rejected) → Plan
  → Runs (INDEX + per-id with Chart.js) → Lab Notebook (entries split + tags)
  → Postmortems (per-failure with Blameless callout) → Results
  → Review (08_REVIEW) → Paper (DRAFT.md preview)
  → Tags (mkdocs-material auto-gen 逆引き)
```

不在ファイルは nav から auto skip。

### 依存

- **`uvx`** (uv 0.4+、既存)
- **mkdocs-material[recommended] ≥9.5.0** — `uvx` で都度 auto-install (固定 install 不要)
- **Chart.js CDN** — `https://cdn.jsdelivr.net/npm/chart.js` (offline で chart 描画不可、build 自体は network 不要)

### Build 時間目安

| 規模 | 時間 |
|------|------|
| 初回 (`uvx mkdocs-material` install) | ~30 秒 |
| 2 回目以降 (cache 利用) | ~5 秒 (小) / ~15 秒 (中) / ~30 秒 (大) |

### `.gitignore` 推奨

```
.research/*/viz/
.research/*/viz-src/
```

詳細: `skills/research.notebook.viz/SKILL.md` および `references/{viz_pipeline,chart_embedding,nav_structure,phase_progress_template,metric_table_template,mkdocs_config_template.yml}.md`

## Data & Comparison (v0.3.0+)

実験データの取り扱いを `skills/auto-research/references/data_lineage.md` に集約しています。

### データ分類 (要点)

| カテゴリ | git track | 公開 |
|----------|-----------|------|
| brief / spec / survey notes / metrics / paper | yes | yes (paper 付録) |
| events.jsonl | yes (gzip 推奨) | redacted のみ |
| **checkpoints (model weights)** | **no** | HF Hub or Zenodo |
| **activation cache / 生 dataset** | **no** | no |

### ユーザー側 `.gitignore`

ユーザーは `templates/research-gitignore.txt` の内容を自プロジェクトの `.gitignore` に追記してください。
checkpoint / cache / dataset を誤って commit するのを防ぎます。

### Cross-project 比較・公開

軽量 (shell script 版):

```bash
# 複数プロジェクトの primary metric を 1 表で
bash scripts/cross_compare.sh <slug1> <slug2> ...

# 共有/公開向け bundle (checkpoint と cache は自動除外)
bash scripts/export_project.sh <slug>
# → <slug>_export_<YYYYMMDD>.tar.gz
```

統計検定 / publication grade (skill 版、v0.4.0+):

| skill | 機能 |
|-------|------|
| `research.cross.compare` | paired bootstrap / Welch's t / Cohen's d / Cliff's delta / Holm-Bonferroni / 比較図表生成 |
| `research.export` | PII redaction (prompt → sha256) + `MANIFEST.json` (commit SHA, deps, state) + `INTEGRITY.txt` (sha256 一覧) |

skill は Claude Code 経由で「`research.cross.compare skill を使って <slug1> と <slug2> を比較して」のように呼び出します。

## Finding cheap GPU resources (v0.8.0+)

Phase 4 (Experiment Design) で workload (GPU 種別 / 個数 / 時間) が固まったら、`research.compute.shop` skill が
**18 provider** から最安候補をランク表示します。AWS / GCP / Azure に加え、Lambda Labs / RunPod / Vast.ai / Salad /
TensorDock / CoreWeave / DataCrunch、無料枠 (Colab Pro+ / Kaggle / HF ZeroGPU)、研究助成 (GCP TRC / NSF ACCESS / 各国 HPC) を網羅。

```text
> 「research.compute.shop skill で A100-80GB 1 枚 24 時間の workload を最安で見つけて」
```

CLI shortcut も用意:

```bash
# 最安 5 件 (commercial)
bash scripts/find_cheap_gpu.sh A100-80GB-SXM 1 24 --max 5.0

# spot 価格優先 + 研究助成も含めて表示
bash scripts/find_cheap_gpu.sh H100-80GB-SXM 4 168 --prefer-spot --include-academic

# プロジェクトに保存 (.research/<slug>/COMPUTE_PROCUREMENT.md を生成)
bash scripts/find_cheap_gpu.sh A100-80GB-SXM 1 24 --slug attention-sink
```

### Catalog の透明性

- 価格は **publicly observable** な reference 値 (各 provider の pricing page リンク付き、最新は公式で確認)
- アフィリエイトリンク・紹介手数料**なし**。商用 / marketplace / free / academic を等しく扱う
- 実契約価格 (秘匿) は `.research/<slug>/cost_overrides.json` に記入 (git ignore 推奨)
- catalog SoT: `skills/research.compute.shop/references/gpu_providers.json` (`updated_at` 90 日経過で skill が note)

## ワークフロー (8 phases / 4 gates)

| # | Phase | 主担当 | 主成果物 | Gate |
|---|-------|--------|----------|------|
| 1 | Topic Framing | `auto-research` skill | `01_BRIEF.md` | **G1** |
| 2 | Literature Survey | `arxiv-mcp-agent` + `paper-deep-reader` ×N | `02_SURVEY/MATRIX.md` | — |
| 3 | Gap & Ideation | `research-gap-finder` ×3 | `03_IDEAS.md` | **G2** |
| 4 | Experiment Design | `experiment-designer` | `04_EXPERIMENT_PLAN.md` | **G3** |
| 5 | Scaffold + TDD | `research.experiment.scaffold` + `ml-engineer` | `code/` | — |
| 6 | Run & Analysis | `research.experiment.run` + `result-statistician` + `attention-analyst` | `06_RUNS/`, `06_RESULTS.md` | — |
| 7 | Paper Drafting | `research.paper.draft` | `paper/main.{tex,md}` | — |
| 8 | Self-Review | `research-gap-finder` (re-cast) + `gemini` | `08_REVIEW.md` | **G4** |

各プロジェクトは `.research/<slug>/` 配下に成果物を蓄積し、`STATE.json` で再開可能。

## 主要コンポーネント

### Skills

| skill | 役割 |
|-------|------|
| `auto-research` | メインワークフロー (state machine + Phase dispatch) |
| `research.literature.matrix` | 論文比較表生成 (固定スキーマ + mutex) |
| `research.experiment.scaffold` | `uv` プロジェクト雛形生成 |
| `research.experiment.run` | 再現性ある実行 + JSONL ログ |
| `research.paper.draft` | LaTeX/Markdown 論文ドラフト |
| `research.attention.probe` | TransformerLens / nnsight ベース介入プロトコル |
| `research.cross.compare` | 複数プロジェクトの metric を統計検定込みで比較 (v0.4.0+) |
| `research.export` | publication grade bundle (PII redaction + MANIFEST + INTEGRITY) (v0.4.0+) |
| `research.cost.estimate` | run 単位 USD 試算 + project 累積コスト + budget watch (v0.5.0+) |
| `research.publish` | HF Hub Datasets / Zenodo upload + DOI 取得 + PUBLICATION.md 生成 (v0.6.0+) |
| `research.compute.shop` | GPU 提供元のランク推奨 (18 provider catalog、商用 / marketplace / free / academic) (v0.8.0+) |
| `research.autonomous.tinker` | karpathy 流の autonomous tinker mode (Phase 5-6 alt: agent が train.py を反復編集、固定 wall-clock budget で val_bpb 最小化) (v0.9.0+) |
| `research.autonomous.swarm` | N agents 並列の research org mode (v0.10.0+、5 戦略 / orchestrator 集約 / cross-pollination 制御) |
| `research.paper.scaffold` | Phase 2+ から呼べる早期論文骨子 builder (v0.13.0+、hypothesis-driven Abstract + 引用付き Introduction を実験前から育てる、living paper/DRAFT.md) |
| `research.lab.notebook` | 実験 lab notebook + 失敗 postmortem skill (v0.14.0+、LAB_NOTEBOOK + per-failure POSTMORTEM、reproduce.sh + uv.lock snapshot で失敗 run も再現可能、rejected ideas を捨てない) |

### Subagents

| agent | 専門 |
|-------|------|
| `paper-deep-reader` | 単一論文 derivation-level 読解 |
| `research-gap-finder` | cross-paper 統合・研究ギャップ抽出 |
| `experiment-designer` | RQ → 仮説 → ablation 表 → 統計検定 |
| `attention-analyst` | mechanistic interpretability (logit lens / patching / probing / SAE) |
| `result-statistician` | bootstrap / Wilcoxon / Cohen's d / 可視化 |

既存の `~/.claude/agents/arxiv-mcp-agent` と `ml-engineer` を最大限再利用します (重複させません)。

### Hook

`PostToolUse` で `uv run *` 実行を全て捕捉し、`.research/<slug>/06_RUNS/<run_id>/events.jsonl` に
`{event, level, ts, run_id, duration_ms, exit_code, git_rev, stdout_tail}` を 1 行 JSON で追記します。**研究再現性の最重要装置**。

## 倫理・コンプライアンス

- arXiv は再配布 OK だが商用ジャーナル PDF はキャッシュしません。`notes/` には要約 + メタのみ保存、原文引用は ≤ 2 文。
- 評価データセットの汚染チェック (`eval_protocol.md` 必須項目)
- LLM-author 開示欄を `paper/` テンプレに同梱 (NeurIPS/ICLR/ACL ポリシー準拠)

## Examples (v0.4.0+)

`examples/` に walked-through な実プロジェクト構造を同梱しています:

- [`examples/llm-eval-mmlu-baseline/`](examples/llm-eval-mmlu-baseline/) — MMLU 公平比較研究の Phase 4 / G3 通過状態 (Brief, Survey, Gap, Ideas, Plan を実物として参照可)

新規プロジェクトを近い領域で始めるとき、example をコピーして `--resume` で続きを実行できます。詳細は `examples/README.md`。

## コントリビューション

PR 歓迎。`CONTRIBUTING.md` と `RELEASING.md` を参照してから issue / PR を立ててください。

- 新機能: MINOR bump 候補。既存 skill との重複境界を `agents/DISPATCH_MATRIX.md` で確認
- バグ修正: PATCH bump 候補。`tests/` に再現テストを先に追加 (TDD)
- ドキュメント: `[Unreleased]` セクションに `### Documentation` でエントリを残す

issue templates: `.github/ISSUE_TEMPLATE/` (bug / feature / install) を用意しています。

## ライセンス

MIT — 詳細は [LICENSE](LICENSE) 参照
