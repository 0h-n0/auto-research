---
name: research.notebook.viz
description: >
  実験ログ / lab notebook / paper draft を **MkDocs material で HTML site にビルド**する skill (v0.17.0+)。
  MD ファイルは SoT として残し、HTML は generated artifact として `.research/<slug>/viz/` に出力。
  events.jsonl を Chart.js で time-series chart 化、STATE.json を Phase progress bar 化、
  LAB_NOTEBOOK の Tags を mkdocs-material tags plugin で逆引き化する。
  Use when: 「視覚化された research notebook が見たい」「実験 log を browser で navigate したい」
  と明示的に要求されたとき。`/auto-research:notebook-viz <slug>` で manual 起動。
  Phase auto-dispatch なし (build は重め、user が見たい時に run)。
---

# `research.notebook.viz`

実験ログ / lab notebook を HTML site にビルドする skill (v0.17.0+)。

## なぜ HTML 視覚化か

v0.13.0 〜 v0.16.0 で **LAB_NOTEBOOK / POSTMORTEM / 06_RUNS / paper/DRAFT** の MD/JSON 構造が固まったが、plain markdown だけだと:
- events.jsonl の loss / metric の **time-series が見えない**
- LAB_NOTEBOOK の 100+ entry を tag で **逆引きしづらい**
- Phase 1-8 の **進捗が一目で分からない**
- POSTMORTEM の Hypothesis space table が **sortable でない**
- 全体を browser で **navigate しづらい**

HTML 視覚化はこれを補完。**MD は SoT として残し**、HTML は generated artifact。

## 設計の核

1. **MD は変更しない**: source は `.research/<slug>/` 配下の既存 MD、HTML は `.research/<slug>/viz/` に出力
2. **MkDocs material 採用**: search / dark mode / tag plugin / navigation 内蔵、研究 notebook に最適
3. **uvx 経由で実行**: 固定 install しない、build 時のみ `uvx --from mkdocs-material mkdocs build` で auto-install
4. **manual invoke only**: Phase auto-dispatch なし、user が見たい時に `/auto-research:notebook-viz <slug>` で起動
5. **Chart.js for time-series**: events.jsonl の loss / metric を line chart に (CDN load)
6. **Phase progress bar**: STATE.json の current_phase / last_gate_passed から HTML/CSS で全 page header に inject
7. **Tag inversion**: LAB_NOTEBOOK の `Tags: #...` を mkdocs frontmatter tags に変換、tag plugin で逆引き page auto-gen
8. **idempotent**: 同じ slug を再 build → 既存 `viz/` を削除して再生成 (artifact だから上書き OK)

## 入力 / 出力

入力 (全部 optional、不在ファイルは nav から auto skip):
- `.research/<slug>/STATE.json` (必須、progress bar 用)
- `.research/<slug>/01_BRIEF.md` (landing page)
- `.research/<slug>/02_SURVEY/MATRIX.md`
- `.research/<slug>/03_IDEAS.md`, `.research/<slug>/03_REJECTED_IDEAS.md`
- `.research/<slug>/04_EXPERIMENT_PLAN.md`
- `.research/<slug>/06_RUNS/INDEX.md`, `06_RUNS/<id>/{config.yaml,metrics.json,events.jsonl,STATUS,error.txt,POSTMORTEM.md,reproduce.sh}`
- `.research/<slug>/06_RESULTS.md`
- `.research/<slug>/08_REVIEW.md`
- `.research/<slug>/LAB_NOTEBOOK.md`, `LAB_NOTEBOOK_INDEX.md`
- `.research/<slug>/paper/DRAFT.md`, `paper/refs.bib`

出力:
- `.research/<slug>/viz-src/` (build 中間物、`mkdocs.yml` + 加工済 `docs/`)
- `.research/<slug>/viz/` (完成 static site、entry: `viz/index.html`)

## Build pipeline (5 ステップ、SoT は `viz_pipeline.md`)

```
1. mkdocs.yml auto-gen
   - theme: material (instant navigation / palette switcher)
   - plugins: search, tags
   - extra_javascript: Chart.js CDN

2. viz-src/docs/ に MD copy + 加工
   - events.jsonl → Chart.js <canvas> + JSON data embed (per-run page)
   - STATE.json → 全 page header に Phase progress bar inject
   - LAB_NOTEBOOK `Tags:` 行 → mkdocs frontmatter tags に変換
   - 06_RUNS/INDEX.md → mkdocs-material sortable table

3. uvx --from mkdocs-material mkdocs build --site-dir .research/<slug>/viz
   - 初回 install on demand (~30s)、cache 利用 (~3s)

4. .research/<slug>/viz/ に static site 完成
   - file:// で開ける、search box 内蔵

5. (任意 --serve) `mkdocs serve` を background で起動、localhost:8000 で preview
```

詳細: `viz_pipeline.md`、`chart_embedding.md`、`phase_progress_template.md`。

## ファイル雛形

| ファイル | SoT |
|---------|-----|
| `mkdocs.yml` template | `references/mkdocs_config_template.yml.md` |
| build pipeline (5 ステップ) | `references/viz_pipeline.md` |
| events.jsonl → Chart.js 仕様 | `references/chart_embedding.md` |
| navigation tree (Phase 別 section) | `references/nav_structure.md` |
| STATE.json → progress bar HTML/CSS | `references/phase_progress_template.md` |
| 06_RESULTS / MATRIX → sortable table | `references/metric_table_template.md` |

## Dependencies

- **uvx** (uv 0.4+、既存依存) — `uvx --from mkdocs-material mkdocs build ...`
- **mkdocs-material[recommended]** — uvx auto-install (≥9.5.0、tags plugin native support)
- **既存**: `python3`, `jq` (events.jsonl パース、metrics.json 変換)
- **CDN**: `https://cdn.jsdelivr.net/npm/chart.js` (offline で chart 描画不可、site 自体は build 済)

## Offline / vendor mode

v0.17.0 では CDN 前提。offline mode (Chart.js を `viz/assets/` に vendor copy) は v0.18+ で追加予定。

## 視覚化対象 (Phase 別 navigation)

`nav_structure.md` で SoT 化。典型構成:

```
Brief (01_BRIEF.md)               → viz/index.html (landing)
Survey (02_SURVEY/MATRIX.md)      → viz/survey/
Ideas (03_IDEAS + 03_REJECTED)    → viz/ideas/
Plan (04_EXPERIMENT_PLAN.md)      → viz/plan/
Runs (06_RUNS/INDEX + per-id)     → viz/runs/, viz/runs/<id>/
Lab Notebook (LAB_NOTEBOOK.md)    → viz/lab-notebook/
Postmortems (per-failure)         → viz/postmortems/<run_id>/
Results (06_RESULTS.md)           → viz/results/
Review (08_REVIEW.md)             → viz/review/
Paper (paper/DRAFT.md)            → viz/paper/
Tags (auto-gen by mkdocs-material) → viz/tags/
```

不在ファイルは nav から auto skip (broken link なし)。

## 安全機構

- **既存 MD は read-only**: build pipeline は `viz-src/docs/` で加工、source MD は変更しない
- **`viz/` は artifact**: 再 build で上書き OK、git track 不要 (.gitignore 推奨)
- **`viz-src/mkdocs.yml` の人手編集は再 build で消える**: warning 表示、custom override は v0.18+ で `mkdocs.override.yml` 追加予定
- **PII redaction 継承**: source MD が `responsible_research.md` 準拠で redacted なら viz も safe (再 redaction なし)
- **AI 開示 (provenance、v0.16.0+)**: viz でも `Provenance` field を mkdocs admonition `!!! note` で visible 描画

## Idempotency

- 同 slug 再 build: 既存 `viz/` 削除 → 再生成
- 同 events.jsonl 再パース: 同 JSON 出力 (timestamp 以外、Chart.js は labels = step で fixed)
- viz-src は debug 用に保持 (`--clean` flag で削除可、v0.18+)

## Build 時間目安

| 規模 | 時間 |
|------|------|
| 小規模 (3 run、Phase 6 まで) | ~5 秒 |
| 中規模 (10 run、Phase 8 完了) | ~15 秒 |
| 大規模 (50 run、複数 ablation) | ~30 秒 |
| 初回 uvx install | +~30 秒 (cache 後 +~3 秒) |

## next-step trailer (`/auto-research:notebook-viz <slug>` 完了時)

```
─────────────────────────────────────
[Phase 6/8] ●●●●●●○○  G3 ✓  🎨 visual notebook built

→ .research/<slug>/viz/index.html (file:// で開く)
→ 10 sections: brief / survey / ideas / plan / runs / lab-notebook / postmortems / results / review / paper
→ tag index: viz/tags/ で逆引き
→ search box: 全文検索 内蔵 (mkdocs-material)

  代替:
   ・ /auto-research:notebook-viz <slug> --serve   localhost:8000 で preview
   ・ open .research/<slug>/viz/index.html         browser で直接確認
─────────────────────────────────────
```

## 既存 skill との関係

| 既存 skill | 関係 |
|-----------|------|
| `research.lab.notebook` (v0.14.0+) | LAB_NOTEBOOK / POSTMORTEM / Tags を視覚化対象に取り込む。`tag_taxonomy.md` の controlled vocabulary を mkdocs frontmatter に mapping |
| `research.paper.scaffold` (v0.13.0+) | `paper/DRAFT.md` を viz/paper/ に render、bibtex inline 表示 |
| `research.experiment.run` (v0.1.0+) | events.jsonl / metrics.json / 06_RUNS/INDEX.md を視覚化 |
| `research.publish` (v0.6.0+) | v0.18+ で gh-deploy mode 統合候補 (Open Notebook Science 公開) |
| `auto-research` SKILL | Phase auto-dispatch なし (manual invoke only)。next-step trailer の代替案として案内 |

## アンチパターン

- ❌ MD ファイルを viz pipeline 内で書き換える (read-only 厳守、viz-src/ で加工)
- ❌ `viz/` を git commit (artifact、`.gitignore` 推奨)
- ❌ mkdocs-material を固定 install (uvx で都度実行、project 依存を軽量化)
- ❌ Chart.js を vendor copy (v0.17.0 では CDN 前提、offline は v0.18+)
- ❌ Phase auto-dispatch を強制 (build は重め、user が見たい時に manual)

## 失敗モード

| failure | 検出 | 回復 |
|---------|------|------|
| `uvx` 不在 (uv 未 install) | `command -v uvx` | error: "uv ≥0.4 を install してください" |
| `mkdocs-material` 初回 install 失敗 | uvx exit code | warning + retry 指示 |
| events.jsonl 巨大 (10k+ events) | line count | Chart.js decimation plugin 推奨 (v0.18+) |
| `STATE.json` 不在 | jq filter | error: project が initialize されていない |
| 元 MD 構文エラー (Tags: 形式破壊) | parse | warning + best-effort skip |

## 関連

- 雛形: `references/mkdocs_config_template.yml.md`, `references/viz_pipeline.md`
- ルール: `references/chart_embedding.md`, `references/phase_progress_template.md`, `references/metric_table_template.md`
- SoT: `references/nav_structure.md`
- 引用ルール (元 MD で適用済): `skills/auto-research/references/responsible_research.md`
- artifact retention: `skills/auto-research/references/data_lineage.md` (`viz/` rule)
- 新 slash command: `commands/notebook-viz.md`
