# Changelog

All notable changes to the `auto-research` plugin are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project adheres to [Semantic Versioning](https://semver.org/).
Release procedure: see [RELEASING.md](./RELEASING.md).

## [Unreleased]

## [0.7.0] - 2026-05-09 — Internationalization

### Added (Documentation)
- **`README.en.md`**: full English version of the README, covering all features
  through v0.6.0 (install / quick start / 8-phase workflow / next-step trailer /
  cost & observability / publishing / data & comparison / examples / contributing).
- `README.md` 冒頭に英語版へのリンクバナーを追加 (`🇬🇧 English version`)
- `README.en.md` 冒頭に日本語版へのリンクを追加
- `CONTRIBUTING.md` に **Translation contributions** 節を追加:
  - 既存翻訳一覧
  - 新規言語の追加方針 (`README.<lang>.md` 命名、SoT との同期)
  - 用語の不変条件 (skill / agent / command 名、Phase / Gate 番号、version 記法は翻訳しない)

### Added (Hygiene)
- **`scripts/gzip_old_events.sh`**: events.jsonl の retention 自動化
  - デフォルト dry-run (圧縮候補表示のみ)
  - `--days N` でしきい値 (default 90)
  - `--apply` で実 gzip (元ファイル削除)
  - 圧縮後は `zcat` / `zgrep` で検索可能、schema validation は raw のみ対象

### Changed (Documentation)
- `skills/auto-research/references/data_lineage.md`: events.jsonl retention 節に
  gzip script の使い方を明記

### Notes
- 後方互換あり。日本語 README が SoT であることに変わりなし、英語版は最低限の同期。
- `gzip_old_events.sh` は `cleanup_checkpoints.sh` と同じデザイン: dry-run default、
  `--apply` で実行、スコープは 1 project の events.jsonl のみ
- 翻訳貢献は CHANGELOG `[Unreleased]` `### Documentation` で管理する方針

## [0.6.0] - 2026-05-09 — Publishing & Archival

### Added (Skill)
- **`research.publish` skill** (`skills/research.publish/`):
  - HuggingFace Hub Datasets upload (`create_repo` + `upload_folder`)
  - Zenodo DOI 取得 (REST API、`--draft` で sandbox、`--no-draft` で publish)
  - 認証: `HF_TOKEN` / `ZENODO_ACCESS_TOKEN` 環境変数 (silent skip しない、明確に error)
  - `PUBLICATION.md` 自動生成 (URL, DOI, bibtex 引用情報)
  - `STATE.json.published` フィールドに記録
  - 部分 success にも対応 (HF OK / Zenodo NG 等を分けて記録)
  - 実装バックエンド: `references/publish.py.txt` (huggingface_hub + requests)

### Added (Hygiene)
- **`scripts/cleanup_checkpoints.sh`**: retention enforcement script
  - デフォルト dry-run (誤削除防止)
  - `--days N` で経過日数しきい値 (default 30)
  - `--keep-best` で primary metric 最大の succeeded run を保護
  - `--apply` で実削除、reclaimable disk size を summary 表示

### Changed (Schema)
- `tests/schemas/state.schema.json`: optional `published` block 追加
  (hf_hub, zenodo_doi, zenodo_url, published_at)
- `tests/fixtures/state_phase8_published.json`: 公開済みプロジェクトの fixture を追加

### Changed (Documentation)
- `skills/auto-research/references/data_lineage.md`:
  - "Retention 強制 (v0.6.0+)" セクション (cleanup_checkpoints.sh の使い方、checkpoint 保持判断表)
  - "Publishing & Archival (v0.6.0+)" セクション (HF Hub / Zenodo 公開フロー)
- `skills/auto-research/references/error_handling_spec.md`: Phase 8 表に publish 関連 7 項目追加
- `skills/auto-research/SKILL.md`: 関連ドキュメント一覧を更新

### Notes
- 後方互換あり。既存 `.research/<slug>/` プロジェクトは `published` フィールド無しで継続利用可。
- `research.publish` は **完全 opt-in**。token を設定しない既存ユーザーは何も変わらない。
- Zenodo published version は変更不能なため、本番公開前に必ず `--draft` (sandbox) で動作確認推奨。
- cleanup script は **デフォルト dry-run**。`--apply` を明示しない限り削除しない。

## [0.5.0] - 2026-05-09 — Cost Tracking & Observability

### Added (Skill)
- **`research.cost.estimate` skill** (`skills/research.cost.estimate/`):
  - 各 run の compute cost (USD) を `duration × usd_per_hour × gpu_count` で試算
  - project 累積コスト + budget watch (50% safe / 80% caution / 100% over)
  - GPU 単価表 (`references/gpu_price_table.json`) に A100/H100/H200/L40S/L4/RTX-4090/TPU 等を収録
  - ユーザー側 `cost_overrides.json` で実契約価格を上書き可能
  - 実装バックエンド: `references/cost_estimate.py.txt`
  - 出力: `06_RUNS/<id>/metrics.json` の `cost_estimate` ブロック + `06_COST_REPORT.md`

### Added (Observability — opt-in)
- **W&B / MLflow / TensorBoard 統合** (環境変数で有効化、未設定時は silent no-op):
  - `WANDB_API_KEY`, `WANDB_PROJECT`, `WANDB_MODE`
  - `MLFLOW_TRACKING_URI`, `MLFLOW_EXPERIMENT_NAME`
  - `TB_LOG_DIR`
- `pyproject_template.toml` に `wandb` / `mlflow` / `tensorboard` extras を追加
  (`uv sync --extra wandb` で個別 install)
- `research.experiment.scaffold/references/observability_setup.md` — 統合方針と
  helper 実装 (`observability_init/log_metric/finalize`)
- `research.experiment.scaffold/SKILL.md`: scaffold 時に観測 backend helper を
  `src/<pkg>/observability.py` として展開する手順を追加

### Changed (Schema)
- `tests/schemas/metrics.schema.json`: optional `cost_estimate` block を追加
  (duration_h, gpu_type, gpu_count, usd, usd_per_hour, pricing_source, estimated_at)
- `tests/fixtures/metrics_sample.json`: `cost_estimate` の例を追記

### Changed (Documentation)
- `skills/auto-research/references/error_handling_spec.md`: Phase 6 表に
  「compute budget 超過」「W&B/MLflow init 失敗」「W&B server 到達不能」の 3 項目を追加
- `skills/auto-research/SKILL.md`: 関連ドキュメント一覧を更新

### Notes
- 後方互換あり。`cost_estimate` block は metrics.json で **optional**、既存 run には
  影響しない (新規 run 完了時に skill が dispatch されると追記される)。
- W&B / MLflow / TensorBoard は **完全 opt-in**。環境変数を設定しない既存ユーザーには
  既存 `events.jsonl` ログ動作が維持される。
- 価格表は **publicly observable な reference 値**。実費とのずれは
  `cost_overrides.json` で個別補正してください。

## [0.4.0] - 2026-05-09 — Cross-Project Comparison & Export

### Added (Skills)
- **`research.cross.compare` skill** (`skills/research.cross.compare/`):
  複数プロジェクトの primary metric を集約し、paired bootstrap (B=10000) /
  Welch's t-test、Cohen's d / Cliff's delta、Holm-Bonferroni、ranking 表、
  比較図 (matplotlib / seaborn colorblind palette) を含むレポートを生成。
  `scripts/cross_compare.sh` の上位互換 (シェル script は引き続き軽量集約用に残す)。
- **`research.export` skill** (`skills/research.export/`):
  publication grade な共有 bundle を生成。
  - `MANIFEST.json` (commit SHA, dependency, project state)
  - `INTEGRITY.txt` (各ファイル sha256)
  - **events.jsonl の PII redaction**: `prompt` / `input_text` / `output_text` を
    sha256 hex 16 文字に置換、`/home/<user>/` を `<HOME>/` に正規化
  - schema validation で `STATE.json` が `state.schema.json` 準拠か検証

### Added (Documentation)
- **`examples/llm-eval-mmlu-baseline/`** — Phase 4 / G3 通過状態の実プロジェクト
  サンプル。`STATE.json`, `01_BRIEF.md`, `02_SURVEY/{papers.jsonl, MATRIX.md, notes/}`,
  `03_GAP_ANALYSIS.md`, `03_IDEAS.md`, `04_EXPERIMENT_PLAN.md` を実物で同梱。
  「具体的にどの粒度で書くのか」がすぐ理解できる。
- **`skills/auto-research/references/error_handling_spec.md`** — 8 Phase × 各 skill の
  failure mode カタログ。検出 / 回復手順 / エスカレーションルール (2 回連続→確認、
  3 回連続→強制 rollback) を明文化。

### Changed
- `skills/auto-research/SKILL.md`: 関連ドキュメント一覧に
  `error_handling_spec.md` を追加

### Notes
- 後方互換あり。既存 `.research/<slug>/` プロジェクトはそのまま継続利用可。
- `scripts/cross_compare.sh` / `scripts/export_project.sh` は引き続き軽量 utility として
  残し、新 skill は publication / 統計 grade の上位機能を提供する。

## [0.3.0] - 2026-05-09 — Production Hardening

### Added (Infrastructure)
- **`tests/` ディレクトリ** (8 test scripts + 5 STATE.json fixtures + 3 JSON Schemas):
  `state_schema`, `events_schema`, `metrics_schema`, `hook_smoke`,
  `init_state_idempotent`, `version_triple`, `json_manifests`, `bash_syntax`,
  および driver `run_all.sh`。`bash tests/run_all.sh` 全 pass を release 必須条件化。
- **`.github/workflows/`**:
  - `lint.yml` — push / PR で `tests/run_all.sh` 全項を実行
  - `release.yml` — tag (`vX.Y.Z`) push で manifest 三箇所一致 + CHANGELOG エントリ存在を検証
- **JSON Schemas** (`tests/schemas/`):
  - `state.schema.json` (`STATE.json`)
  - `events.schema.json` (`events.jsonl` 1 行)
  - `metrics.schema.json` (`metrics.json`)

### Added (Governance)
- `LICENSE` (MIT 全文; これまで `plugin.json` の `"license": "MIT"` のみだった)
- `CONTRIBUTING.md` (PR/branch/Conventional Commits/レビュー基準)
- `.github/ISSUE_TEMPLATE/{bug_report,feature_request,installation_issue}.md`
- `.github/PULL_REQUEST_TEMPLATE.md` (RELEASING.md checklist 埋込)
- `agents/DISPATCH_MATRIX.md` — 5 subagents × 8 phases の dispatch SoT

### Added (Data infrastructure)
- `skills/auto-research/references/data_lineage.md` — データ分類表
  (検証 / retention / git track / 公開方針) の SoT
- `templates/research-gitignore.txt` — ユーザー側
  `.gitignore` に追記するテンプレ (checkpoint / cache / dataset を ignore)
- `scripts/cross_compare.sh <slug1> <slug2> ...` — 複数プロジェクトの primary metric を 1 表で集約
- `scripts/export_project.sh <slug>` — 共有/公開向けの tar.gz bundle (checkpoint と cache を除外)
- `skills/research.experiment.run/SKILL.md` に
  `06_RUNS/INDEX.md` 自動更新 step を追加

### Changed
- **`.mcp.json`**: 実機検証で匿名スキャフォールドと判明した
  `huggingface-mcp-server` の同梱を停止。残り 2 (`semantic-scholar`, `github`) は実機起動確認済み。
  README で代替手段を案内。
- **`hooks/hooks.json`**: PostToolUse の `timeout` を `5` → `30` 秒に拡大
- **`hooks/post-experiment-log.sh`**: silent fail を可視化
  (jq 不在時 / append 失敗時に stderr 警告)。`level=error` のとき `error_type` / `error_message` を含めるよう
  `events.schema.json` に準拠化
- `skills/auto-research/SKILL.md`: 関連ドキュメント一覧に `data_lineage.md` と `DISPATCH_MATRIX.md` を追加

### Notes
- 後方互換あり (既存 `.research/<slug>/` プロジェクトは継続利用可)
- 既存ユーザーが HF Hub MCP を使っていた場合のみ、ユーザー側 `~/.claude.json` に独自設定を移す必要あり

## [0.2.1] - 2026-05-09

### Documentation
- README.md: v0.2.0 で追加した next-step trailer の解説節 (例 + 特殊状態の挙動表) を追加。
  v0.2.0 を README 未更新のまま出してしまった (doc drift) ので follow-up patch として補完。
- RELEASING.md: pre-release checklist に「ドキュメントが新バージョンと同期している」
  ブロックを追加。新機能を README に反映せずに release するのを禁止する旨を明記。

### Notes
- code 変更なし。doc-only release。
- 今後は機能追加 (MINOR) を出す前に、その変更点が README にも書かれていることを必ず確認する。

## [0.2.0] - 2026-05-09

### Added
- **Next-step trailer**: 全 6 コマンドの完走時に、Phase 進捗バー (●○) と
  最後通過したゲートマーカー (`G{n} ✓`)、推奨次コマンド + 代替を統一
  フォーマットで必ず出力する。`STATE.json` の `current_phase` /
  `last_gate_passed` / `completed_at` / `rollbacks` を読んで動的に切り替え。
- 表示仕様の単一ソース: `skills/auto-research/references/next_steps_template.md`
  - §1: literal フォーマット (罫線・進捗バー・代替欄)
  - §2: STATE.json → 推奨マッピング表 (10 ケース)
  - §3: 特殊状態 (sanity 失敗 / G4 ロールバック / 複数 active project /
    全 run 失敗 / 完了プロジェクト / STATE.json 不在)
  - §5: 不変条件 (進捗バー桁数、罫線文字、コードブロック禁止 等)

### Changed
- `commands/research-{start,design,experiment,write,review,status}.md`:
  本文末尾に「完了時の出力 (必須)」セクションを追加し、共通テンプレートを参照。
- `skills/auto-research/SKILL.md`: 「Phase 完了時の Next-Step Trailer (必須)」
  節と関連ドキュメント一覧を追加。

### Notes
- 後方互換あり。既存の `.research/<slug>/` プロジェクトはそのまま利用可能。
- 出力体験のみの変更で、ワークフロー (8 phases / 4 gates) や
  各 skill / agent / hook のロジックは不変。

## [0.1.3] - 2026-05-09

### Changed
- Documented invocation form is now plugin-prefixed: `/auto-research:research-start`
  (and the five sibling commands). v0.1.2 had switched the displayed form to
  the bare `/research-start`, but `/help` actually shows the namespaced form
  whenever the plugin is the canonical owner of the command. The bare form may
  still work as an alias when there is no name conflict, but the README,
  CHANGELOG, command files, and `phase_state_machine.md` now uniformly show
  the namespaced form so that pasted snippets match what `/help` displays.

### Notes
- No behavioural change. Both `/auto-research:research-start ...` and (when no
  conflict exists) `/research-start ...` resolve to the same command.

## [0.1.2] - 2026-05-09

### Fixed
- README.md, command files, CHANGELOG, and `phase_state_machine.md` referenced
  the wrong invocation syntax `/research:start` etc. Subdirectory-based command
  namespacing in Claude Code does **not** produce a colon (`/foo:bar`) in the
  invocation — the colon form is purely a `/help` display label. The actual
  command is `/auto-research:research-start`, `/auto-research:research-design`, ..., `/auto-research:research-status`,
  matching the file names under `commands/`.
- Removed non-standard frontmatter fields (`argument-hint`, `effort`,
  `allowed-tools`) from all 6 `SKILL.md` files. The Claude Code skill spec only
  recognises `name`, `description`, and (optional) `version`. The extra fields
  may have caused skills to be silently skipped during plugin install.

### Notes
- No code or workflow change. Existing `.research/<slug>/` projects from a
  v0.1.0 / v0.1.1 install remain compatible.

## [0.1.1] - 2026-05-09

### Fixed
- `.claude-plugin/plugin.json`: removed invalid string-typed fields
  `agents`, `skills`, `commands`, `hooks` that caused
  `Validation errors: agents: Invalid input` during `/plugin install`.
  Components are now resolved by Claude Code's auto-discovery from the
  standard directories (`agents/`, `skills/`, `commands/`, `hooks/`).
  No behavioural change — install path is the only difference.

## [0.1.0] - 2026-05-09

### Added
- Initial plugin scaffold (`plugin.json`, `.mcp.json`).
- 8-phase / 4-gate research workflow (`skills/auto-research/`).
- Phase-specific skills:
  - `research.literature.matrix` — paper comparison table
  - `research.experiment.scaffold` — uv/PyTorch/HF project bootstrap
  - `research.experiment.run` — reproducible execution + JSONL events
  - `research.paper.draft` — LaTeX/Markdown paper drafting
  - `research.attention.probe` — mechanistic interpretability setup
- Five specialist subagents:
  - `paper-deep-reader`, `research-gap-finder`, `experiment-designer`,
    `attention-analyst`, `result-statistician`
- Six entry-point commands: `/auto-research:research-start`, `/auto-research:research-design`,
  `/auto-research:research-experiment`, `/auto-research:research-write`, `/auto-research:research-review`,
  `/auto-research:research-status`.
- `PostToolUse` hook (`post-experiment-log.sh`) that captures every
  `uv run` invocation into `events.jsonl` for reproducibility.
- Bundled MCP servers: Semantic Scholar, HuggingFace Hub, GitHub.
  arxiv-mcp-server is reused from user config (not bundled).
