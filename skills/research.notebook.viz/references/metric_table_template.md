# Sortable metric table template (06_RESULTS / MATRIX / RUNS INDEX)

`research.notebook.viz` の build pipeline で **`06_RESULTS.md` / `02_SURVEY/MATRIX.md` /
`06_RUNS/INDEX.md` の markdown table を sortable HTML table** にレンダリングする仕様。

> **目的**: 大量の run / paper / metric を column header クリックで sort できるようにする。
> mkdocs-material は native で sortable table 対応 (JS plugin 不要)、`attr_list` で attribute 付与。

## mkdocs-material native sortable table

mkdocs.yml で:
```yaml
markdown_extensions:
  - tables
  - attr_list
  - md_in_html
```

これで markdown table が HTML `<table>` に変換され、`{: .sortable}` で sortable 化:

```markdown
| Run | Status | Primary metric | Duration | Tags |
|-----|--------|---------------:|---------:|------|
| r_a3f2 | failed | — | 4min | #oom |
| r_b1c8 | succeeded | 0.671 | 60min | #hypothesis-confirmed |
| r_c5d9 | succeeded | 0.683 | 58min | #hypothesis-confirmed |
{: .sortable}
```

mkdocs-material default で `.sortable` class table は header クリックで sort 可能。

## 各 source の変換 rule

### 1. `06_RUNS/INDEX.md` → `viz-src/docs/runs/index.md`

source (`06_RUNS/INDEX.md`):
```markdown
| run_id | status | primary metric | duration | notes |
|--------|--------|----------------|----------|-------|
| 20260509-104523-a1b2c3d-9e8f7d | succeeded | acc=0.671 | 60min | baseline |
| 20260509-114523-a1b2c3d-3a8b1e | failed | — | 4min | OOM |
```

加工:
1. run_id を short id (r_<sha-tail>) に変換 + per-run page link
2. status に色分け icon (✅ succeeded / ❌ failed / ⏳ running)
3. primary metric に sort key 抽出 (=後の数値)
4. Tags column を追加 (POSTMORTEM の Failure type tag から、failed の場合)
5. `{: .sortable}` を末尾に追加

output (`viz-src/docs/runs/index.md`):
```markdown
# All runs

| Run | Status | Primary metric | Duration | Tags |
|-----|--------|---------------:|---------:|------|
| [r_a3f2](runs/20260509-114523-a1b2c3d-3a8b1e.md) | ❌ failed | — | 4min | #oom |
| [r_9e8f](runs/20260509-104523-a1b2c3d-9e8f7d.md) | ✅ succeeded | 0.671 | 60min | #hypothesis-confirmed |
{: .sortable}
```

### 2. `02_SURVEY/MATRIX.md` → `viz-src/docs/survey/index.md`

source (`02_SURVEY/MATRIX.md`、`skills/research.literature.matrix` の schema):
```markdown
| paper_id | year | title | method category | claim | our relevance |
|----------|------|-------|-----------------|-------|---------------|
| 2403.07974 | 2024 | Chat template ablation on MMLU | format effect | +2-5pp variance | direct baseline |
| ... |
```

加工:
1. paper_id を arXiv link に変換 (`https://arxiv.org/abs/2403.07974`)
2. year column に sort key 追加
3. method category を controlled tag に正規化 (Lab notebook tag taxonomy と整合)
4. `{: .sortable}` 末尾

### 3. `06_RESULTS.md` → `viz-src/docs/results/index.md`

source: 集約 metric 表 (result-statistician agent 出力)、典型:
```markdown
| Model | Factor | Mean | 95% CI | n |
|-------|--------|-----:|-------:|--:|
| Llama-3.2-3B | format=A | 0.671 | ±0.012 | 3 |
| Llama-3.2-3B | format=B | 0.654 | ±0.011 | 3 |
| ... |
```

加工:
1. 各 row に **statistical significance marker** (`*` for p<0.05、`**` for p<0.01)
2. baseline との diff column を auto-add (色分け: 改善 = green, 劣化 = red)
3. `{: .sortable}` 末尾

## 拡張: filter functionality

v0.17.0 では sort のみ、filter (column 上に search box) は **mkdocs-material native 不対応**。
v0.18+ で custom JS で filter 追加候補 (datatables.js or 自前 implementation)。

代替案: tag plugin で逆引きできる (Tags column 経由で tag → runs を navigate)。

## Status icon mapping

| status | icon | 色 |
|--------|------|-----|
| succeeded | ✅ | green |
| failed | ❌ | red |
| failed_sanity | ⚠️ | yellow |
| running | ⏳ | blue |
| not_implemented | ⊘ | gray |
| started | ▶️ | blue |

CSS で per-icon の色分けは `tag-colors.css` (mkdocs material tag plugin と同居):

```css
.md-typeset .icon-status-success { color: #28a745; }
.md-typeset .icon-status-failed { color: #dc3545; }
.md-typeset .icon-status-running { color: #007bff; }
/* etc. */
```

## 大規模 table (50+ rows) の対応

mkdocs-material は scroll が必要な table を auto で `<div style="overflow-x: auto">` に wrap。
50+ rows は pagination 必要だが、v0.17.0 では未対応 (1 page で全表示)。

50+ run 想定の project は **tag filter で section 分け** を推奨 (LAB_NOTEBOOK_INDEX.md tag inversion 経由)。

## 色分け (改善 / 劣化)

`06_RESULTS.md` の diff column で baseline 比較:

```markdown
| Model | Factor | Metric | Diff vs baseline |
|-------|--------|-------:|-----------------:|
| Llama-3.2-3B | format=A | 0.671 | <span class="diff-positive">+0.025</span> |
| Llama-3.2-3B | format=B | 0.654 | <span class="diff-negative">−0.008</span> |
```

CSS:
```css
.diff-positive { color: #28a745; font-weight: bold; }
.diff-negative { color: #dc3545; font-weight: bold; }
```

build pipeline で result-statistician 出力の数値を parse して diff を auto 計算。

## アクセシビリティ

- 各 `<th>` に `scope="col"` 属性 (markdown では `attr_list` で `{: scope="col"}`)
- status icon に `aria-label="succeeded"` 等
- 数値 column は右揃え (`|--:|` でテキスト alignment)
- color に依存しない (icon と color を併用、不可視ユーザー対応)

## アンチパターン

- ❌ HTML table を直書き (markdown table + `attr_list` で sortable に)
- ❌ status を文字列のみ ("succeeded") で表現 (icon + color で視認性)
- ❌ 50+ rows を 1 page で出す (将来 pagination 必要)
- ❌ baseline diff を計算済 number で書く (color 化、視覚的に diff が分かる)

## 関連

- mkdocs config (`tables` + `attr_list`): `mkdocs_config_template.yml.md`
- build pipeline step 2: `viz_pipeline.md`
- per-run page (Chart.js): `chart_embedding.md`
- 元 schema:
  - `06_RUNS/INDEX.md`: `skills/auto-research/references/data_lineage.md`
  - `02_SURVEY/MATRIX.md`: `skills/research.literature.matrix/references/paper_note_schema.md`
  - `06_RESULTS.md`: `result-statistician` agent output
- tag colors: `skills/research.lab.notebook/references/tag_taxonomy.md`
