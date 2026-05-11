# Phase progress bar template (STATE.json → HTML/CSS)

`research.notebook.viz` の build pipeline step 2d で `STATE.json` の current_phase / last_gate_passed
を全 page header の **Phase 1-8 progress bar** として inject する仕様。

> **目的**: どの page を見ても「project が今 Phase N、Gate G? まで通過」が一目で分かる。
> 8-phase / 4-gate workflow の進捗を navigation aid として常時可視化。

## STATE.json schema 復習

`tests/schemas/state.schema.json` 準拠:

```json
{
  "project_slug": "attention-sink-llama-long-ctx",
  "created_at": "2026-05-09T10:00:00Z",
  "current_phase": 5,
  "last_gate_passed": "G3",
  "adopted_idea_id": 2,
  "active_run_ids": [],
  "paper_format": "latex-neurips",
  "focus_area": "attention",
  "compute_budget_gpu_h": 200,
  "completed_at": null
}
```

抽出対象:
- `current_phase` (1-8)
- `last_gate_passed` ("G0" / "G1" / "G2" / "G3" / "G4")
- `completed_at` (null = ongoing, ISO string = completed)

## HTML 構造

各 page の冒頭 (mkdocs-material の `header` 直下 or `article` 上部) に inject:

```html
<div class="phase-progress" data-current="5" data-last-gate="G3" data-completed="false">
  <span class="phase done" data-phase="1">1<br/>Brief</span>
  <span class="phase done gate-passed" data-phase="2" data-gate="G1">2<br/>Survey<br/><small>G1 ✓</small></span>
  <span class="phase done gate-passed" data-phase="3" data-gate="G2">3<br/>Idea<br/><small>G2 ✓</small></span>
  <span class="phase done gate-passed" data-phase="4" data-gate="G3">4<br/>Plan<br/><small>G3 ✓</small></span>
  <span class="phase current" data-phase="5">5<br/>Scaffold</span>
  <span class="phase pending" data-phase="6">6<br/>Run</span>
  <span class="phase pending" data-phase="7">7<br/>Paper</span>
  <span class="phase pending" data-phase="8" data-gate="G4">8<br/>Review</span>
</div>
```

state class:
- `done`: `data-phase <= current_phase - 1` の Phase
- `current`: `data-phase == current_phase` の Phase
- `pending`: `data-phase > current_phase` の Phase
- `gate-passed`: 該当 Phase で Gate を通過 (G1=2, G2=3, G3=4, G4=8)
- 全完了 (`completed_at != null`): 全 Phase に `done` + Phase 8 に `final` class

## CSS (`assets/phase-progress.css`)

```css
/* container */
.phase-progress {
  display: flex;
  justify-content: space-between;
  margin: 1rem 0 2rem 0;
  padding: 0.5rem;
  background: var(--md-default-bg-color--light, #f5f5f5);
  border-radius: 4px;
  font-size: 0.85rem;
  text-align: center;
}

/* phase cell common */
.phase-progress .phase {
  flex: 1;
  padding: 0.5rem 0.25rem;
  margin: 0 2px;
  border-radius: 4px;
  border-left: 3px solid transparent;
  line-height: 1.3;
  color: var(--md-default-fg-color, #333);
}

/* done = green */
.phase-progress .phase.done {
  background: #d4edda;
  color: #155724;
  border-left-color: #28a745;
}

/* current = blue (highlight) */
.phase-progress .phase.current {
  background: #cce5ff;
  color: #004085;
  border-left-color: #007bff;
  font-weight: bold;
  box-shadow: 0 2px 4px rgba(0, 123, 255, 0.2);
}

/* pending = gray */
.phase-progress .phase.pending {
  background: var(--md-default-bg-color, #fff);
  color: #999;
  border-left-color: #ddd;
}

/* gate passed marker */
.phase-progress .phase.gate-passed small {
  color: #28a745;
  font-weight: bold;
  display: block;
  margin-top: 2px;
}

/* dark mode adaptation */
@media (prefers-color-scheme: dark) {
  .phase-progress {
    background: var(--md-default-bg-color--lighter, #2a2a2a);
  }
  .phase-progress .phase.done { background: #1e3a23; color: #a3d9a5; }
  .phase-progress .phase.current { background: #1e3a5f; color: #a3c9f9; }
  .phase-progress .phase.pending { background: #1a1a1a; color: #666; }
}

/* completed project (all Phase done) */
.phase-progress[data-completed="true"] .phase {
  background: #d1ecf1;
  border-left-color: #17a2b8;
}
.phase-progress[data-completed="true"] .phase[data-phase="8"] {
  background: #c3e6cb;
  border-left-color: #28a745;
  font-weight: bold;
}
```

## JS (`assets/phase-progress.js`)

`mkdocs_config_template.yml.md` で `extra_javascript:` 配下に登録。
通常は **静的 HTML で十分** (build pipeline で server side で組み立て済) で JS は不要だが、
将来 progress bar を動的に更新する場合の hook 用に skeleton を置く:

```javascript
// assets/phase-progress.js
// Note: v0.17.0 では HTML 直書きで全部完結、JS は no-op skeleton。
// 将来 (v0.18+): STATE.json を fetch して live update する hook を実装予定。

document.addEventListener("DOMContentLoaded", () => {
  // No-op currently. Phase progress bar is server-side rendered at build time.
  // Future: live reload via STATE.json fetch (--serve mode).
});
```

## Build pipeline step 2d (inject 実装)

bash + jq + sed で:

```bash
# 1. STATE.json から current_phase / last_gate_passed 抽出
CURRENT_PHASE=$(jq -r '.current_phase' "${SLUG_DIR}/STATE.json")
LAST_GATE=$(jq -r '.last_gate_passed' "${SLUG_DIR}/STATE.json")
COMPLETED=$(jq -r 'if .completed_at then "true" else "false" end' "${SLUG_DIR}/STATE.json")

# 2. Phase progress bar HTML を生成
PHASE_BAR=$(cat <<EOF
<div class="phase-progress" data-current="${CURRENT_PHASE}" data-last-gate="${LAST_GATE}" data-completed="${COMPLETED}">
EOF
)
# (Phase 1-8 を loop で span 生成)

# 3. 各 docs/*.md の H1 直下に PHASE_BAR を挿入
for md in $(find "${VIZ_SRC}/docs" -name "*.md"); do
    # H1 行の直後に PHASE_BAR を sed で insert
    sed -i "0,/^# /{//a\\
${PHASE_BAR_ESCAPED}
}" "$md"
done
```

実装の詳細は build pipeline (`viz_pipeline.md`) を参照。

## Gate marker mapping

Phase ↔ Gate の対応:

| Phase | Gate | mark 条件 |
|-------|------|----------|
| 1 (Brief) | G1 | `last_gate_passed >= G1` |
| 3 (Idea) | G2 | `last_gate_passed >= G2` |
| 4 (Plan) | G3 | `last_gate_passed >= G3` |
| 8 (Review) | G4 | `last_gate_passed == G4` |

JS or bash で `last_gate_passed` を parse して該当 Phase に `gate-passed` class を付与。

## Completed project の特別表示

`STATE.json.completed_at != null`:
- 全 Phase に `done` class
- Phase 8 に追加で `final` highlight
- progress bar 全体に `data-completed="true"` で teal 色強調

## アンチパターン

- ❌ progress bar を per-page で JS 描画 (静的 HTML で十分、JS は no-op で軽量)
- ❌ Phase 名を多言語化 (v0.17.0 では英語固定 = "Brief / Survey / Idea / Plan / Scaffold / Run / Paper / Review")
- ❌ Gate marker を別行 (1 cell 内に `<small>` で compact 表示)
- ❌ progress bar を `<table>` (CSS flex で軽量)

## アクセシビリティ

- 各 `.phase` span に `aria-label="Phase N: <name>"` を追加 (build pipeline で append)
- 色だけでなく **アイコン (✓ / ●)** で done / current を区別
- `data-current` attribute で screen reader が parse 可能

## 関連

- mkdocs.yml の extra_css / extra_javascript 登録: `mkdocs_config_template.yml.md`
- build pipeline step 2d: `viz_pipeline.md`
- nav 構造: `nav_structure.md`
- STATE.json schema: `tests/schemas/state.schema.json`
- 8-phase / 4-gate workflow SoT: `skills/auto-research/SKILL.md`
