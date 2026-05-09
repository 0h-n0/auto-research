# Data Lineage & Retention

`auto-research` プラグインがプロジェクトで生成・参照するデータの **所在・サイズ・保持期間・git track** ポリシーを集約。
`responsible_research.md` (倫理・PII)、`phase_state_machine.md` (state)、`reproducibility_checklist.md` (再現性) と相補。

## データ分類表

| カテゴリ | パス例 | サイズ感 | retention | git track | 公開 |
|----------|--------|----------|-----------|-----------|------|
| **Brief / Spec** (人手で書く) | `01_BRIEF.md`, `04_EXPERIMENT_PLAN.md` | 小 (KB) | 永続 | yes | yes (paper 付録) |
| **Survey notes** | `02_SURVEY/notes/<paper_id>.md` | 小 (KB) × N | 永続 | yes | 抜粋のみ (≤2 文引用) |
| **Survey index** | `02_SURVEY/papers.jsonl` | 小 (KB) | 永続 | yes | yes |
| **Comparison matrix** | `02_SURVEY/MATRIX.md`, `06_RESULTS.md` | 小 (KB) | 永続 | yes | yes |
| **Run config** | `06_RUNS/<id>/config.{json,yaml}` | 小 (KB) | 永続 | yes | yes |
| **Run metrics** | `06_RUNS/<id>/metrics.json` | 小 (KB) | 永続 | yes | yes |
| **Events log** | `06_RUNS/<id>/events.jsonl` | 中 (MB) | 90 日 (target) | yes (gzip 推奨) | redacted only (PII 除去後) |
| **Run status flag** | `06_RUNS/<id>/STATUS` | 極小 | 永続 | yes | yes |
| **Run index** | `06_RUNS/INDEX.md` | 小 (KB) | 永続 (auto-regen 可) | yes | yes |
| **Figures** | `figures/*.pdf`, `06_RUNS/<id>/figures/*.pdf` | 中 (MB) | 永続 | yes | yes |
| **Paper draft** | `paper/main.{tex,md}`, `paper/sections/`, `paper/refs.bib` | 小 (KB) | 永続 | yes | yes (公開時) |
| **Checkpoints** (model weights) | `06_RUNS/<id>/checkpoints/` | 大 (GB-TB) | 30 日 or 採用版のみ | **NO** | HF Hub or Zenodo へ |
| **Activation cache** | `code/cache/activations/` | 大 (GB) | 一時 (再生成可) | **NO** | NO |
| **Datasets** (生データ) | HF datasets cache or `code/data/` | 大 (GB-TB) | 一時 | **NO** | 公開済 dataset のみ HF Hub 経由参照 |
| **Paper PDFs** (他者の論文) | (キャッシュしない) | — | 0 | **NO** | NO |
| **Probe analysis** | `code/analysis/<slug>.py`, `code/results/probe/<probe_id>.json` | 小〜中 | 永続 | yes | yes |
| **Probe cache** | `code/cache/probe_<hash>.pt` | 大 (GB) | 一時 | **NO** | NO |

## 設計原則

1. **メタデータは git track**: config / metrics / notes / results / figures は再現性の核。リポジトリに含める。
2. **バイナリは外部ストレージ**: checkpoint / cache / dataset は GB スケールになるので git に入れない。HF Hub / Zenodo / S3 へ。
3. **PII / 著作権は厳格**: events.jsonl の prompt 全文や商用 PDF はそもそも保存しない。`responsible_research.md` 参照。
4. **失敗 run も保持**: `STATUS=failed` でディレクトリは残す (raw stack trace と config が再現に必要)。**失敗 run の checkpoint は削除可**。
5. **再生成可能なものは保存しない**: `code/cache/`, dataset cache。

## Phase 別データフロー

```
Phase 1: BRIEF ─────────────────────────────────────────► 01_BRIEF.md (git)
Phase 2: arxiv 取得 ────► papers.jsonl + notes/*.md ────► MATRIX.md (全部 git)
Phase 3: gap 分析 ─────► 03_GAP_ANALYSIS.md, 03_IDEAS.md (git)
Phase 4: 実験設計 ─────► 04_EXPERIMENT_PLAN.md (git)
Phase 5: scaffold ─────► code/ (git, ただし cache/data/checkpoints は ignore)
       │
       └─ tests/ (git) + DATA_CARD.md (git)
Phase 6: train/eval ──► 06_RUNS/<id>/{config, metrics, events.jsonl, STATUS} (git)
       │             ──► 06_RUNS/<id>/checkpoints/  (NOT git, 30 日後削除候補)
       │             ──► 06_RUNS/INDEX.md (git, auto-regen)
       └─ analysis ─► figures/ (git) + 06_RESULTS.md (git)
Phase 7: paper draft ─► paper/main.{tex,md}, paper/refs.bib, paper/figures/ (git)
Phase 8: review ─────► 08_REVIEW.md (git)
                     ─► export ─► <slug>_export_<date>.tar.gz (公開ストレージへ)
```

## Cross-Project / Cross-Run 比較

複数プロジェクト跨ぎの結果比較は次の 2 経路:

1. **`scripts/cross_compare.sh <slug1> <slug2> ...`** (v0.3.0 — shell スクリプト最小実装)
   - 各 project の `06_RUNS/*/metrics.json` から primary metric を抽出
   - markdown 表で stdout に出力
2. **`research.cross.compare` skill** (v0.3.1 で予定 — 統計検定込み)

INDEX.md 形式 (Phase 6 で `research.experiment.run` skill が自動更新):

```markdown
# Run Index — <slug>

| run_id | status | primary metric | duration | notes |
|--------|--------|----------------|----------|-------|
| 20260509-104523-a1b2c3d-9e8f7d | succeeded | acc=0.671 | 60min | baseline |
| 20260509-114523-a1b2c3d-3a8b1e | failed | — | 4min | OOM |
| ... | ... | ... | ... | ... |
```

## 公開・アーカイブ

- **paper 公開時**: `scripts/export_project.sh <slug>` で `<slug>_export_<YYYYMMDD>.tar.gz` を作成
  - 含む: brief, spec, survey, ideas, plan, runs (config/metrics/events redacted), results, paper, figures
  - 除外: checkpoints (HF Hub URL を `paper/limitations.md` に記載), dataset (公開済 dataset のみ参照)
  - PII redaction: events.jsonl の prompt 全文を hash 化、API key を環境変数参照に置換
- **長期アーカイブ**: Zenodo (DOI 付き) を推奨

## Retention 自動化 (v0.4.0 候補、現状は手動)

- 30 日経過した failed run の checkpoint を `find -mtime +30 -delete` で削除
- 90 日経過した events.jsonl を gzip
- これらは `RELEASING.md` の手動ハウスキープ手順に追加するか、別 skill で自動化検討

## ユーザー側 `.gitignore`

ユーザーは自分のプロジェクト root の `.gitignore` に `templates/research-gitignore.txt` の内容を追記する。
そうすれば cache / checkpoints / dataset が誤って commit されない。
