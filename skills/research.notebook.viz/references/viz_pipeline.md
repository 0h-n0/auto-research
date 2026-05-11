# viz build pipeline (5 ステップ SoT)

`research.notebook.viz` が `/auto-research:notebook-viz <slug>` 実行時に通る 5 ステップ pipeline。

> **目的**: source MD を **read-only で扱い**、`viz-src/` で加工 → `uvx mkdocs-material build` →
> `viz/` に static site を出力する idempotent な pipeline。

## 5 ステップ概要

```
Input:  .research/<slug>/ (各種 MD + JSON、source、read-only)
        ↓
Step 1: mkdocs.yml auto-gen      (viz-src/mkdocs.yml)
Step 2: MD copy + 加工            (viz-src/docs/)
Step 3: uvx mkdocs build         (uvx --from mkdocs-material mkdocs build)
Step 4: viz/ rename + cleanup    (.research/<slug>/viz/)
Step 5: (任意 --serve) mkdocs serve  (localhost:8000)
        ↓
Output: .research/<slug>/viz/index.html (entry)
```

## Step 1: mkdocs.yml auto-gen

`mkdocs_config_template.yml.md` の template から生成。slug-specific 部分:

- `site_name: "Research Notebook — {Topic from 01_BRIEF.md or slug}"`
- `nav:` を `.research/<slug>/` の existing files に応じて build (不在は skip)
- `site_dir: ../viz` で `.research/<slug>/viz/` に固定

実装 (bash + jq):
```bash
TOPIC=$(grep -m1 "^# " "${SLUG_DIR}/01_BRIEF.md" 2>/dev/null | sed 's/^# //' || echo "$SLUG")
cat > "${SLUG_DIR}/viz-src/mkdocs.yml" <<EOF
site_name: "Research Notebook — ${TOPIC}"
docs_dir: docs
site_dir: ../viz
...
EOF
```

詳細 template は `mkdocs_config_template.yml.md`。

## Step 2: MD copy + 加工

`.research/<slug>/viz-src/docs/` を作成、source MD を **read-only で copy + 加工**:

### 2a. 単純 copy (加工なし)

```bash
cp -r "${SLUG_DIR}/02_SURVEY"        "${VIZ_SRC}/docs/survey/"
cp "${SLUG_DIR}/04_EXPERIMENT_PLAN.md" "${VIZ_SRC}/docs/plan/index.md"
cp "${SLUG_DIR}/06_RESULTS.md"       "${VIZ_SRC}/docs/results/index.md"
cp "${SLUG_DIR}/08_REVIEW.md"        "${VIZ_SRC}/docs/review/index.md"
cp "${SLUG_DIR}/paper/DRAFT.md"      "${VIZ_SRC}/docs/paper/index.md"
```

### 2b. Tags 変換 (LAB_NOTEBOOK / POSTMORTEM)

`Tags: #oom #hypothesis-rejected` 行を **mkdocs frontmatter** に変換:

```python
# python (or bash sed) で:
# 元: "Tags: `#oom` `#hypothesis-rejected`"
# 後:
# ---
# tags:
#   - oom
#   - hypothesis-rejected
# ---
# (元 entry の冒頭に frontmatter を追加)
```

LAB_NOTEBOOK.md は **entry per file に split**:
- `LAB_NOTEBOOK.md` の各 `### 2026-MM-DD [Phase N ...] ...` を 1 ファイルに
- `viz-src/docs/lab-notebook/<date>-<phase>.md` に書く
- index page `viz-src/docs/lab-notebook/index.md` で全 entries を時系列 link

詳細: `nav_structure.md`。

### 2c. events.jsonl → Chart.js (per-run page)

各 `06_RUNS/<id>/events.jsonl` から:
1. step / loss / metric を抽出
2. JSON array に圧縮
3. per-run MD page (`viz-src/docs/runs/<id>.md`) に **Chart.js `<canvas>` + JSON data 埋め込み**

詳細: `chart_embedding.md`。

### 2d. Phase progress bar inject

各 page (or layout 共通) に STATE.json の current_phase / last_gate_passed を data-* attribute で埋込:

```html
<div id="phase-progress" data-current-phase="5" data-last-gate="G3"></div>
```

`assets/phase-progress.js` が DOM ready 時に progress bar を描画。

詳細: `phase_progress_template.md`。

### 2e. 06_RUNS/INDEX.md → sortable table

mkdocs-material の sortable table は **`tables` extension + JS なし** で OK (header click でソート、material native)。
06_RUNS/INDEX.md は markdown table のまま copy で OK、ただし header に `{: .sortable}` attribute を attr_list で追加。

詳細: `metric_table_template.md`。

### 2f. 03_IDEAS / 03_REJECTED_IDEAS

```bash
mkdir -p "${VIZ_SRC}/docs/ideas/"
cp "${SLUG_DIR}/03_IDEAS.md"          "${VIZ_SRC}/docs/ideas/adopted.md"
cp "${SLUG_DIR}/03_REJECTED_IDEAS.md" "${VIZ_SRC}/docs/ideas/rejected.md"
```

不在時は対応する nav entry を skip。

### 2g. assets/ コピー

```bash
cp -r "${SKILL_DIR}/references/assets/" "${VIZ_SRC}/docs/assets/"
```

(skill の references/ に bundled CSS / JS、または build script が inline で生成、v0.17.0 では後者)

### 2h. figures/ + analysis/ 追加 (v0.18.0+)

result-statistician と attention-analyst の出力を viz nav に組込:

```bash
# result-statistician 出力 (figures/*.pdf) を docs/results/ 配下に copy
if test -d "${SLUG_DIR}/figures"; then
    mkdir -p "${VIZ_SRC}/docs/results/figures"
    cp -r "${SLUG_DIR}/figures/." "${VIZ_SRC}/docs/results/figures/"
    # 各 figure に caption 付き <embed> を generate (results/index.md に追記)
fi

# attention-analyst 出力 (focus_area=attention のみ) を docs/analysis/ に copy
if test -d "${SLUG_DIR}/code/analysis"; then
    mkdir -p "${VIZ_SRC}/docs/analysis"
    cp -r "${SLUG_DIR}/code/analysis/." "${VIZ_SRC}/docs/analysis/"
fi
if test -d "${SLUG_DIR}/code/results/probe"; then
    mkdir -p "${VIZ_SRC}/docs/analysis/probe"
    cp -r "${SLUG_DIR}/code/results/probe/." "${VIZ_SRC}/docs/analysis/probe/"
fi
```

詳細は `nav_structure.md` §8 (Results)。

## Step 3: uvx mkdocs-material build

```bash
cd "${SLUG_DIR}/viz-src"
uvx --from "mkdocs-material[recommended]>=9.5.0,<10" mkdocs build --clean --strict
```

- `--clean`: 古い site/ を削除して clean build
- `--strict`: warnings を error 扱い (broken link 検出)
- `mkdocs-material[recommended]>=9.5.0,<10`: tags plugin + 関連 extensions 込み、9.x 系で pin

初回実行は uvx が mkdocs-material を ~/.cache/uv/tools/ に install (~30 秒)。2 回目以降は cache 利用 (~3 秒)。

build 失敗時 (broken link 等): error 表示 + viz-src/ を保持 (debug 用)。

## Step 4: viz/ rename + cleanup

`mkdocs build --site-dir ../viz` で `.research/<slug>/viz/` に直接出力済み。

`viz-src/` は debug 用に保持 (`--clean-viz-src` flag で削除可、v0.18+)。

## Step 5: --serve オプション (任意)

`/auto-research:notebook-viz <slug> --serve` の場合:

```bash
cd "${SLUG_DIR}/viz-src"
uvx --from "mkdocs-material[recommended]>=9.5.0,<10" mkdocs serve \
    --dev-addr localhost:8000 &
echo "Serving at http://localhost:8000 (Ctrl-C to stop)"
```

- background 起動推奨 (`&`)、user が Ctrl-C で停止
- live-reload 内蔵 (`viz-src/docs/` を edit すると auto-refresh)

## Idempotency

- 同 slug 再 build: `mkdocs build --clean` で既存 `viz/` を削除して再生成
- 同 events.jsonl 再パース: 同じ JSON (labels = step で fixed)
- 異なる入力 (新 run 追加) で nav が auto-extend

## Error handling

| Error | 検出 | 回復 |
|-------|------|------|
| `uvx` 不在 | `command -v uvx` | error: "uv ≥0.4 を install してください" |
| `STATE.json` 不在 | `test -f` | error: "project が initialize されていない、`/auto-research:research-start` を実行" |
| MD parse 失敗 | mkdocs strict | warning + best-effort skip (`--strict` を外す option v0.18+) |
| `mkdocs-material` install 失敗 | uvx exit code | warning + uvx cache clear 指示 |
| broken link in nav | mkdocs strict | error + missing file 名表示、user 対応 |

## 出力検証 (smoke test)

build 後:
```bash
test -f "${SLUG_DIR}/viz/index.html" || { echo "build failed"; exit 1; }
test -d "${SLUG_DIR}/viz/search" || echo "warning: search index missing"
test -d "${SLUG_DIR}/viz/tags" || echo "warning: tags index missing (LAB_NOTEBOOK 不在?)"
```

期待:
- `viz/index.html` 存在 (landing page)
- `viz/search/search_index.json` 存在 (検索 index)
- `viz/tags/index.html` 存在 (tag 逆引き、LAB_NOTEBOOK ありなら)
- `viz/assets/javascripts/bundle.*.js` 存在 (mkdocs-material native bundle)

## 関連

- mkdocs.yml template: `mkdocs_config_template.yml.md`
- nav 構造 SoT: `nav_structure.md`
- Chart.js embedding: `chart_embedding.md`
- Phase progress bar: `phase_progress_template.md`
- sortable table: `metric_table_template.md`
- slash command 実装: `commands/notebook-viz.md`
