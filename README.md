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
