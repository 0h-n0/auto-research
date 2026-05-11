---
description: "MD ファイルを SoT として残しつつ、MkDocs material で `.research/<slug>/viz/` に視覚化された HTML site をビルド。events.jsonl は Chart.js で time-series chart、LAB_NOTEBOOK の Tags は tag plugin で逆引き、STATE.json は Phase progress bar 化。(v0.17.0+)"
argument-hint: "<slug> [--serve] (--serve で mkdocs serve を background 起動、localhost:8000 で preview)"
allowed-tools: [Read, Bash, Glob, Write]
---

Visual Notebook builder。`research.notebook.viz` skill を invoke して MkDocs material で
`.research/<slug>/viz/` を build する slash command (v0.17.0+)。

## 実行手順

### 1. 引数 parse

```bash
SLUG="${1:-}"
SERVE_MODE=false
for arg in "$@"; do
    case "$arg" in
        --serve) SERVE_MODE=true ;;
    esac
done
test -n "$SLUG" || { echo "Usage: /auto-research:notebook-viz <slug> [--serve]"; exit 1; }
SLUG_DIR=".research/${SLUG}"
test -d "$SLUG_DIR" || { echo "Project not found: ${SLUG_DIR}"; exit 1; }
test -f "${SLUG_DIR}/STATE.json" || { echo "STATE.json missing in ${SLUG_DIR}"; exit 1; }
```

### 2. uvx 存在確認

```bash
command -v uvx >/dev/null 2>&1 || {
    echo "ERROR: uv (≥0.4) が install されていません。"
    echo "  curl -LsSf https://astral.sh/uv/install.sh | sh"
    exit 1
}
```

### 3. `research.notebook.viz` skill を invoke

skill の build pipeline (5 ステップ、`viz_pipeline.md` 準拠) を実行:

1. **mkdocs.yml auto-gen** → `viz-src/mkdocs.yml` (`mkdocs_config_template.yml.md` 準拠)
2. **MD copy + 加工** → `viz-src/docs/`
   - LAB_NOTEBOOK Tags → mkdocs frontmatter tags 変換
   - events.jsonl → Chart.js `<canvas>` + JSON embed (per-run page)
   - STATE.json → Phase progress bar inject (全 page header)
   - 06_RUNS/INDEX → sortable table (`{: .sortable}`)
3. **uvx mkdocs build**:
   ```bash
   cd "${SLUG_DIR}/viz-src"
   uvx --from "mkdocs-material[recommended]>=9.5.0,<10" mkdocs build --clean --strict
   ```
4. **viz/ 完成** (`mkdocs build --site-dir ../viz` で `${SLUG_DIR}/viz/` に出力)
5. **`--serve` mode**: `mkdocs serve --dev-addr localhost:8000` を background 起動

### 4. 出力検証

```bash
test -f "${SLUG_DIR}/viz/index.html" || { echo "build failed: viz/index.html not generated"; exit 1; }
test -d "${SLUG_DIR}/viz/search" && echo "✓ search index" || echo "⚠ search index missing"
test -d "${SLUG_DIR}/viz/tags" && echo "✓ tags index" || echo "⚠ tags missing (LAB_NOTEBOOK 不在?)"
echo "✓ build complete: ${SLUG_DIR}/viz/index.html"
```

### 5. 結果表示 + next-step trailer

```
✓ Visual notebook built at .research/<slug>/viz/

  Open in browser:
    file://$(realpath ${SLUG_DIR}/viz/index.html)

  Or preview with live-reload:
    /auto-research:notebook-viz <slug> --serve  # localhost:8000

─────────────────────────────────────
[Phase N/8] ●●●●●○○○  G? ✓  🎨 visual notebook built

→ .research/<slug>/viz/index.html (10 sections + tag index + search)

  代替:
   ・ /auto-research:notebook-viz <slug> --serve   localhost:8000 で preview
   ・ open .research/<slug>/viz/index.html         browser で直接確認
─────────────────────────────────────
```

## 使用例

```text
# 基本: build
> /auto-research:notebook-viz attention-sink-llama-long-ctx

# preview (--serve で localhost:8000)
> /auto-research:notebook-viz attention-sink-llama-long-ctx --serve

# 完了後 browser で開く (--serve なし)
> open .research/attention-sink-llama-long-ctx/viz/index.html
```

## 依存

- **`uvx`** (uv 0.4+): `mkdocs-material` を都度 install (固定 install 不要)
- **`jq`**: events.jsonl / STATE.json パース (既存依存)
- **CDN**: `https://cdn.jsdelivr.net/npm/chart.js` (build 自体は offline OK、chart 描画に network 必要)

## Build 時間目安

| 規模 | 時間 |
|------|------|
| 初回 (`uvx mkdocs-material` install 含む) | ~30 秒 |
| 2 回目以降 (cache 利用) | ~5 秒 (小) ~15 秒 (中) ~30 秒 (大) |

## artifact retention

`.research/<slug>/viz/` および `viz-src/` は **generated artifact** (git track 不要)。
`.gitignore` 推奨:
```
.research/*/viz/
.research/*/viz-src/
```

詳細: `skills/auto-research/references/data_lineage.md`。

## トラブルシューティング

- **`uvx` not found**: `curl -LsSf https://astral.sh/uv/install.sh | sh` で uv install
- **mkdocs build fails with broken link**: 元 MD 内の link が壊れている。`--strict` を外して再 build (v0.17.0 では strict 固定、v0.18+ で flag 化検討)
- **Chart が表示されない**: network 接続を確認 (Chart.js は CDN load)、offline mode は v0.18+
- **tag index が空**: LAB_NOTEBOOK.md の `Tags:` 行が正しい形式か確認 (`#tag-name` バックティック囲み)

## 関連

- skill SoT: `skills/research.notebook.viz/SKILL.md`
- build pipeline: `skills/research.notebook.viz/references/viz_pipeline.md`
- mkdocs.yml template: `skills/research.notebook.viz/references/mkdocs_config_template.yml.md`
- Chart.js embedding: `skills/research.notebook.viz/references/chart_embedding.md`
- Phase progress bar: `skills/research.notebook.viz/references/phase_progress_template.md`
- artifact retention: `skills/auto-research/references/data_lineage.md`
