# mkdocs.yml auto-gen template (SoT)

`research.notebook.viz` が `.research/<slug>/viz-src/mkdocs.yml` を auto-generate する template。
MkDocs material の標準仕様に従い、theme / plugins / nav / extra_javascript を fixed config + slug-specific 部分で構成。

> **目的**: project 毎に customize 必要な箇所 (site_name / nav / repo_url) は input 由来で、
> theme / plugins は共通仕様で一貫性を保つ。

## 完成 template (auto-gen 結果)

```yaml
site_name: "Research Notebook — <SLUG>"
site_description: "<01_BRIEF.md の Topic 1 行>"
site_url: ""   # local only、deploy 時に override
docs_dir: docs
site_dir: ../viz   # .research/<slug>/viz/

theme:
  name: material
  features:
    - navigation.instant       # SPA-like fast nav
    - navigation.tracking      # URL update on scroll
    - navigation.sections      # top-level grouping
    - navigation.expand
    - navigation.top           # back-to-top button
    - search.suggest
    - search.highlight
    - content.code.copy        # copy code button
    - content.tabs.link        # synced tabs
    - toc.follow
  palette:
    # dark / light switcher
    - media: "(prefers-color-scheme: light)"
      scheme: default
      primary: indigo
      accent: indigo
      toggle:
        icon: material/brightness-7
        name: Switch to dark mode
    - media: "(prefers-color-scheme: dark)"
      scheme: slate
      primary: indigo
      accent: indigo
      toggle:
        icon: material/brightness-4
        name: Switch to light mode
  icon:
    repo: fontawesome/brands/github

markdown_extensions:
  - admonition          # !!! note / warning / tip 等
  - pymdownx.details    # collapsible
  - pymdownx.superfences  # fenced code + diagrams
  - pymdownx.highlight:
      anchor_linenums: true
  - pymdownx.inlinehilite
  - pymdownx.snippets
  - pymdownx.tabbed:
      alternate_style: true
  - pymdownx.tasklist:
      custom_checkbox: true
  - tables              # sortable table base
  - attr_list           # {: .class} attribute
  - md_in_html          # html block 内 markdown
  - footnotes
  - toc:
      permalink: true

plugins:
  - search:
      lang:
        - ja
        - en
  - tags:
      tags_file: tags.md   # tag index page

extra_javascript:
  - https://cdn.jsdelivr.net/npm/chart.js   # time-series chart
  - assets/phase-progress.js               # custom: STATE.json → progress bar
  - assets/run-metrics.js                  # custom: events.jsonl → Chart.js init

extra_css:
  - assets/phase-progress.css              # progress bar style
  - assets/tag-colors.css                  # controlled tag 色分け

nav:
  # 動的 generation、不在 file は skip
  - Home: index.md                          # 01_BRIEF.md 由来
  - Survey: survey/index.md                 # 02_SURVEY/MATRIX.md
  - Ideas:
      - Adopted: ideas/adopted.md           # 03_IDEAS.md
      - Rejected: ideas/rejected.md         # 03_REJECTED_IDEAS.md
  - Plan: plan/index.md                     # 04_EXPERIMENT_PLAN.md
  - Runs:
      - All runs: runs/index.md             # 06_RUNS/INDEX.md
      - <per-run pages auto-list>           # 06_RUNS/<id>/
  - Lab Notebook: lab-notebook/index.md     # LAB_NOTEBOOK.md
  - Postmortems:
      - <per-failure pages auto-list>       # 06_RUNS/<id>/POSTMORTEM.md
  - Results: results/index.md               # 06_RESULTS.md
  - Review: review/index.md                 # 08_REVIEW.md
  - Paper: paper/index.md                   # paper/DRAFT.md
  - Tags: tags.md                           # mkdocs-material tags plugin auto-gen
```

## 必須要素 (test で確認)

| 要素 | 必須行 |
|------|--------|
| theme | `name: material` |
| search | `plugins:` 配下 `search:` |
| tag plugin | `plugins:` 配下 `tags:` |
| Chart.js | `extra_javascript:` 配下 `chart.js` URL |
| Phase progress | `extra_javascript:` 配下 `phase-progress.js`、`extra_css:` 配下 `phase-progress.css` |
| dark mode switcher | `palette:` の 2 entries (light / dark) |
| admonition | `markdown_extensions:` 配下 `admonition` |
| sortable table | `tables` + `attr_list` + `pymdownx.superfences` |

## site_name 生成 rule

`01_BRIEF.md` の Topic を抽出し:
```yaml
site_name: "Research Notebook — {Topic from 01_BRIEF.md or slug}"
```

不在時は slug をそのまま使う:
```yaml
site_name: "Research Notebook — {slug}"
```

## nav 動的 generation

build pipeline (`viz_pipeline.md` 参照) で:
1. `.research/<slug>/` 配下を scan
2. 存在する MD ファイルだけ nav に追加
3. `06_RUNS/<id>/` の per-run page を auto-list
4. POSTMORTEM.md 存在の failed run のみ Postmortems 配下に追加

不在ファイルは nav から auto skip (broken link なし)。

## tag plugin の動作

`Tags: #oom #hypothesis-rejected` を MD 内に書くと、mkdocs-material tags plugin が:
- 各 entry の frontmatter に `tags: [oom, hypothesis-rejected]` を要求
- `tags.md` を auto-gen し、tag → entry の逆引き表を生成

build pipeline で `Tags: #oom` → frontmatter `tags: [oom]` に **変換** する処理を入れる
(`viz_pipeline.md` step 2 参照)。

## extra_css / extra_javascript の中身

`viz-src/docs/assets/` に bundle される custom asset:

- **`phase-progress.css`**: Phase 1-8 progress bar の style (done = green / current = blue / pending = gray)
- **`phase-progress.js`**: 各 page header に Phase progress bar を inject する script (STATE.json embed の data-* attribute から読む)
- **`run-metrics.js`**: per-run page の `<canvas>` を Chart.js で初期化 (data-* attribute から JSON parse)
- **`tag-colors.css`**: controlled tag (#oom / #hypothesis-confirmed 等) の色分け

詳細仕様は `phase_progress_template.md`、`chart_embedding.md`。

## customization (v0.18+)

`viz-src/mkdocs.override.yml` で部分 override 可能 (v0.18+ feature):
- repo_url の設定 (GitHub URL)
- google analytics
- 追加 plugins
- 自前 theme partial

v0.17.0 では auto-gen のみ、override 非対応。

## 関連

- build pipeline: `viz_pipeline.md`
- nav 構造の SoT: `nav_structure.md`
- Phase progress 仕様: `phase_progress_template.md`
- Chart.js embedding: `chart_embedding.md`
- mkdocs-material 公式 docs: https://squidfunk.github.io/mkdocs-material/
