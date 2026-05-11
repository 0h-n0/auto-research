# Navigation tree structure (SoT)

`research.notebook.viz` の build pipeline が `viz-src/mkdocs.yml` の `nav:` セクションを
auto-generate する際の **canonical navigation tree** 仕様。

> **設計方針**: Phase 1-8 workflow の順番で section を並べ、user が研究プロセスを左→右で
> navigate できるようにする。不在ファイルは nav から auto skip。

## Canonical navigation tree

```
nav:
  - Home: index.md                          # 01_BRIEF.md
  - Survey: survey/index.md                 # 02_SURVEY/MATRIX.md
  - Ideas:
      - Adopted: ideas/adopted.md           # 03_IDEAS.md
      - Rejected: ideas/rejected.md         # 03_REJECTED_IDEAS.md (v0.14.0+)
  - Plan: plan/index.md                     # 04_EXPERIMENT_PLAN.md
  - Runs:
      - All runs: runs/index.md             # 06_RUNS/INDEX.md
      - <per-run pages auto-list>           # 06_RUNS/<id>/
  - Lab Notebook:
      - Timeline: lab-notebook/index.md     # LAB_NOTEBOOK.md (entry per file split)
      - <date-phase entries auto-list>
  - Postmortems:
      - <per-failure pages auto-list>       # 06_RUNS/<id>/POSTMORTEM.md
  - Results: results/index.md               # 06_RESULTS.md
  - Review: review/index.md                 # 08_REVIEW.md
  - Paper: paper/index.md                   # paper/DRAFT.md (v0.13.0+)
  - Tags: tags.md                           # mkdocs-material tags plugin (auto-gen)
```

合計 10 top-level sections (Home / Survey / Ideas / Plan / Runs / Lab Notebook / Postmortems / Results / Review / Paper) + Tags index。

## Section 別仕様

### 1. Home (`index.md`)

入力: `01_BRIEF.md` + `STATE.json`

レンダリング:
- Project title (site_name)
- Phase progress bar (`phase_progress_template.md` 準拠)
- Topic / Motivation (from 01_BRIEF.md)
- Quick links: latest run, latest postmortem, paper draft

不在時: minimal landing (slug 名のみ)。

### 2. Survey (`survey/index.md`)

入力: `02_SURVEY/MATRIX.md` + `02_SURVEY/papers.jsonl` + `02_SURVEY/notes/*.md`

レンダリング:
- MATRIX.md (sortable table、`metric_table_template.md` 準拠)
- papers.jsonl のリスト (link to arxiv)
- per-paper notes (任意展開)

不在時: section ごと skip。

### 3. Ideas (`ideas/`)

入力: `03_IDEAS.md` (adopted) + `03_REJECTED_IDEAS.md` (rejected、v0.14.0+)

レンダリング:
- `ideas/adopted.md`: adopted idea の full body + Decision journal block (v0.15.0+)
- `ideas/rejected.md`: rejected ideas の full body + reason + future revisit conditions

`03_REJECTED_IDEAS.md` 不在 (v0.13.0 以前 project): rejected sub-nav を skip。

### 4. Plan (`plan/index.md`)

入力: `04_EXPERIMENT_PLAN.md`

レンダリング: そのまま (ablation matrix table + RQ + Hypothesis 一覧)。

### 5. Runs (`runs/`)

入力: `06_RUNS/INDEX.md` + `06_RUNS/<id>/` 全 run

レンダリング:
- `runs/index.md`: 全 run の sortable table (status / metric / duration、`metric_table_template.md` 準拠)
- `runs/<run_id>.md` (per-run page、各 run について):
  - Status badge (succeeded / failed)
  - Phase progress bar
  - config.yaml の重要 field 抽出 (model / batch_size / lr / seed)
  - **Chart.js time-series** (`chart_embedding.md` 準拠、loss + metric curves)
  - metrics.json の summary table
  - POSTMORTEM への link (failed の場合)
  - reproduce.sh link

### 6. Lab Notebook (`lab-notebook/`)

入力: `LAB_NOTEBOOK.md` (v0.14.0+) + `LAB_NOTEBOOK_INDEX.md` (v0.15.0+)

LAB_NOTEBOOK.md を **entry per file に split**:
- `lab-notebook/index.md`: 全 entries を時系列リスト + Tags overview
- `lab-notebook/<YYYY-MM-DD>-<phase>.md`: 各 entry を独立 page

各 entry page:
- frontmatter に `tags: [oom, hypothesis-rejected]` (元 `Tags: #...` から変換)
- Decision journal block (v0.15.0+) を mkdocs admonition `!!! note "Decision journal"` で強調
- Provenance field (v0.16.0+) を `!!! info "Provenance"` で表示

不在時: section skip。

### 7. Postmortems (`postmortems/`)

入力: 各 `06_RUNS/<id>/POSTMORTEM.md` (failed run のみ)

レンダリング:
- `postmortems/<run_id>.md`:
  - 冒頭 **Blameless callout** (v0.15.0+) を `!!! warning "Blameless principle"` で表示
  - Hypothesis space table (mkdocs-material sortable、verdict 別色分け)
  - Decision / Lessons section
  - Reproducibility 7-tuple checklist
  - Stack trace excerpt (collapsible `<details>`)
  - events.jsonl tail (collapsible)

POSTMORTEM が存在しない run は skip。

### 8. Results (`results/index.md`)

入力: `06_RESULTS.md`

レンダリング: そのまま (集約 metric 表、figure link)。

### 9. Review (`review/index.md`)

入力: `08_REVIEW.md`

レンダリング: そのまま (reviewer-likely-questions + Lessons learned)。

### 10. Paper (`paper/index.md`)

入力: `paper/DRAFT.md` (v0.13.0+) + `paper/refs.bib`

レンダリング:
- DRAFT.md をそのまま (Abstract / Intro / Method / Experiments / Discussion)
- bibtex inline 表示 (`~\cite{key}` を visible なリンクに変換)
- agent-managed marker (`<!-- agent-managed:Phase=N -->`) を `!!! note "Phase N で更新"` で可視化

不在時: section skip (v0.13.0 以前 project)。

### 11. Tags (`tags.md`、auto-gen by mkdocs-material)

mkdocs-material tags plugin が **自動生成**。ユーザーは触らない。

各 entry の frontmatter `tags:` 配下が集約され、tag → entry の逆引き表が生成される:
- Controlled tags (Failure / Outcome / Process / Phase) ごとにグループ化
- 自由 tags は別 section で全件表示

## 不在ファイルの auto skip rule

build pipeline (step 1 mkdocs.yml auto-gen) で:
1. `.research/<slug>/` 配下を scan
2. 存在する file のみ nav に追加
3. 不在 file は対応 nav entry を omit

例 (v0.13.0 以前 project、paper/ なし):
```yaml
nav:
  - Home: index.md
  - Survey: survey/index.md
  - Ideas:
      - Adopted: ideas/adopted.md
      # rejected.md 不在 → skip
  - Plan: plan/index.md
  - Runs: ...
  # Lab Notebook 不在 → skip
  # Postmortems 不在 → skip
  - Results: results/index.md
  - Review: review/index.md
  # Paper 不在 → skip
```

mkdocs strict mode で broken link 検出される設定なので、不在 file を nav に書くと build fail。

## per-run / per-postmortem の auto-list

`06_RUNS/<id>/` ディレクトリを Glob:
```bash
for run_dir in "${SLUG_DIR}/06_RUNS/"*/; do
    run_id=$(basename "$run_dir")
    # nav.Runs.<run_id> を追加
    # POSTMORTEM.md があれば nav.Postmortems.<run_id> も追加
done
```

run_id は YYYYMMDD-HHMMSS-sha-hash 形式 (research.experiment.run の SoT)、
nav 表示は短縮 (例: `r_a3f2`):
```yaml
- Runs:
    - All runs: runs/index.md
    - "r_a3f2 (failed)": runs/20260513-104523-a3f2c8d-r1.md
    - "r_b1c8 (success)": runs/20260513-114523-b1c8e9d-r2.md
```

## 多言語対応 (v0.17.0)

source MD は日本語 / 英語混在 (auto-research workflow が language-agnostic)。
mkdocs-material search plugin の `lang:` で `[ja, en]` 両方を index。

専用 i18n (`mkdocs-material[i18n]` plugin) は v0.18+ で対応予定。

## アンチパターン

- ❌ nav に絶対 path (mkdocs は relative path 前提)
- ❌ section を 1 level に flatten (10+ top-level で UX 低下)
- ❌ 不在 file を nav に書いて strict mode で build fail
- ❌ per-run page を `runs/<id>/index.md` (深い path、URL が長い → `runs/<id>.md` で OK)

## 関連

- mkdocs.yml template: `mkdocs_config_template.yml.md`
- build pipeline: `viz_pipeline.md`
- per-run page (Chart.js embed): `chart_embedding.md`
- Phase progress bar: `phase_progress_template.md`
- sortable table: `metric_table_template.md`
- 元 MD schemas: `skills/auto-research/references/data_lineage.md`
