# Chart.js embedding (events.jsonl → time-series graph)

`research.notebook.viz` の build pipeline step 2c で `06_RUNS/<id>/events.jsonl` を **Chart.js
time-series chart** として per-run page に埋め込む仕様。

> **目的**: events.jsonl の step / loss / metric の推移を line chart で可視化。
> 失敗 run も含めて学習曲線 / metric 推移を見える化する。

## 入力フォーマット (events.jsonl)

各行 1 イベント、必須 schema は `tests/schemas/events.schema.json`:

```jsonl
{"event":"run.started","level":"info","ts":"2026-05-09T10:45:23Z","run_id":"...","duration_ms":0}
{"event":"data.loaded","level":"info","ts":"...","run_id":"...","duration_ms":15234}
{"event":"step","level":"debug","ts":"...","run_id":"...","duration_ms":230,"step":100,"loss":0.42}
{"event":"step","level":"debug","ts":"...","run_id":"...","duration_ms":230,"step":200,"loss":0.31}
{"event":"eval.metric","level":"info","ts":"...","run_id":"...","duration_ms":...,"metric":"acc","value":0.671}
{"event":"run.succeeded","level":"info","ts":"...","run_id":"...","duration_ms":3600000}
```

抽出対象:
- **loss timeline**: `event=step` の `step`, `loss`
- **metric timeline**: `event=eval.metric` の `step` (events.jsonl から逆引き), `metric`, `value`
- **duration histogram**: 全 event の `duration_ms` (per step latency)

## 出力フォーマット (per-run MD page)

`viz-src/docs/runs/<run_id>.md` に以下を埋め込む:

```markdown
---
title: "Run <run_id>"
---

# Run `<run_id>`

**Status**: succeeded / failed / not_implemented
**Wall-clock**: <duration_ms から計算>
**Config**: [`config.yaml`](./config.yaml)
**Reproduce**: `bash reproduce.sh`

## Time-series

### Loss curve

<canvas id="chart-loss-{run_id_safe}" width="800" height="400"
        data-events='{"steps": [100, 200, ...], "losses": [0.42, 0.31, ...]}'
        class="chart-loss"></canvas>

### Metric curves

<canvas id="chart-metric-{run_id_safe}" width="800" height="400"
        data-events='{"metrics": [{"name":"acc","values":[{"step":1000,"value":0.671},...]}]}'
        class="chart-metric"></canvas>

## Metrics summary

| Metric | Value | 95% CI |
|--------|------:|-------:|
| acc | 0.671 | ±0.012 |
| f1 | 0.654 | ±0.011 |

## Events tail (last 50)

(POSTMORTEM 用、failed run のみ表示)
```

`data-events` attribute に JSON を埋め込み、JS 側で parse → Chart.js 描画。

## JS 実装 (`assets/run-metrics.js`)

mkdocs-material の `extra_javascript` で load される custom script:

```javascript
// .research/<slug>/viz/assets/run-metrics.js

document.addEventListener("DOMContentLoaded", () => {
  // Loss charts
  document.querySelectorAll("canvas.chart-loss").forEach(canvas => {
    const data = JSON.parse(canvas.dataset.events);
    new Chart(canvas, {
      type: "line",
      data: {
        labels: data.steps,
        datasets: [{
          label: "loss",
          data: data.losses,
          borderColor: "rgb(220, 53, 69)",  // red
          backgroundColor: "rgba(220, 53, 69, 0.1)",
          tension: 0.1,
        }],
      },
      options: {
        responsive: true,
        plugins: {
          title: { display: true, text: "Training loss" },
          legend: { position: "top" },
        },
        scales: {
          x: { title: { display: true, text: "step" } },
          y: { title: { display: true, text: "loss" }, beginAtZero: false },
        },
      },
    });
  });

  // Metric charts (multi-metric)
  document.querySelectorAll("canvas.chart-metric").forEach(canvas => {
    const data = JSON.parse(canvas.dataset.events);
    const datasets = data.metrics.map((m, i) => ({
      label: m.name,
      data: m.values.map(v => ({ x: v.step, y: v.value })),
      borderColor: ["rgb(0, 123, 255)", "rgb(40, 167, 69)", "rgb(255, 193, 7)"][i % 3],
      tension: 0.1,
    }));
    new Chart(canvas, {
      type: "line",
      data: { datasets },
      options: {
        responsive: true,
        plugins: { title: { display: true, text: "Metric curves" } },
        scales: {
          x: { type: "linear", title: { display: true, text: "step" } },
          y: { title: { display: true, text: "value" } },
        },
      },
    });
  });
});
```

## events.jsonl → JSON 抽出 (build pipeline step 2c)

bash + jq で抽出:

```bash
# Loss timeline
LOSS_JSON=$(jq -s '
  [.[] | select(.event == "step") | {step, loss}]
  | { steps: map(.step), losses: map(.loss) }
' "$EVENTS_JSONL")

# Metric timeline (multi-metric grouped by name)
METRIC_JSON=$(jq -s '
  [.[] | select(.event == "eval.metric") | {step, metric, value}]
  | group_by(.metric)
  | { metrics: map({ name: .[0].metric, values: map({step, value}) }) }
' "$EVENTS_JSONL")
```

これを HTML attribute に埋込:
```bash
echo "<canvas id=\"chart-loss-${RUN_ID_SAFE}\" data-events='${LOSS_JSON}' class=\"chart-loss\"></canvas>"
```

## CDN dependency (Chart.js)

`mkdocs_config_template.yml.md` で:
```yaml
extra_javascript:
  - https://cdn.jsdelivr.net/npm/chart.js   # v4.x latest
  - assets/run-metrics.js
```

**Offline 動作**: site 自体は build 済で `file://` で開くが、Chart.js は CDN load なので
network 必要。offline mode (Chart.js を `assets/chart.min.js` に vendor copy) は v0.18+ で追加。

## 大規模 events.jsonl の対応

10k+ events で chart が重い場合 (v0.18+ feature 候補):
- Chart.js [decimation plugin](https://www.chartjs.org/docs/latest/configuration/decimation.html)
- LTTB アルゴリズムで 1000 points にダウンサンプル
- v0.17.0 では未対応、全 events を pass (10k events は ~1MB JSON、browser OK)

## Chart 種類別の出力

| event 種類 | Chart 種類 | 例 |
|-----------|----------|-----|
| `event=step` の loss | line chart | training loss curve |
| `event=eval.metric` | multi-line chart | val_acc, val_f1, val_bpb 同時表示 |
| `event=run.*` の duration_ms | bar chart (Phase breakdown) | data.loaded / step / eval each time |
| `event=error` | annotation (赤縦線) | failure point を mark (v0.18+ で実装) |

v0.17.0 では loss + metric の 2 chart のみ実装。

## Failed run の扱い

POSTMORTEM 連携:
- failed run の events.jsonl の **失敗直前 50 events** を `<details>` ブロックで表示
- POSTMORTEM.md への link を per-run page 上部に配置
- chart は途中で切れた loss/metric を表示 (失敗 step を end として描画)

## アンチパターン

- ❌ Chart.js を inline script で各 page に書く (asset 集約で軽量化)
- ❌ events.jsonl 全 events を HTML attribute に埋込 (1MB+ で重い、step/loss/metric 抽出済データのみ)
- ❌ Chart.js v3 系を使う (mkdocs-material と相性問題、v4.x で fixed pin)
- ❌ canvas に固定 width (responsive: true で flexible に)

## 関連

- mkdocs config: `mkdocs_config_template.yml.md`
- build pipeline step 2c: `viz_pipeline.md`
- per-run page schema: `nav_structure.md` § Runs
- events.jsonl schema: `tests/schemas/events.schema.json`
- POSTMORTEM 連携: `skills/research.lab.notebook/references/postmortem_template.md`
- Chart.js 公式: https://www.chartjs.org/
