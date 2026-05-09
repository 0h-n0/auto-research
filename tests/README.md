# tests/

`auto-research` プラグインの smoke / schema / regression テスト群。
v0.3.0 から導入。CI (`.github/workflows/lint.yml`) と手動実行の両方で使う。

## 構成

```
tests/
├── README.md                              # このファイル
├── run_all.sh                             # 全 test を順次実行する driver
├── fixtures/                              # 検証用 STATE.json / events.jsonl / metrics.json サンプル
│   ├── state_phase1_g0.json
│   ├── state_phase2_g1.json
│   ├── state_phase4_g3.json
│   ├── state_phase8_g4_completed.json
│   ├── state_rolled_back_phase6_to_5.json
│   ├── events_sample.jsonl
│   └── metrics_sample.json
├── schemas/                               # JSON Schema (draft 2020-12)
│   ├── state.schema.json
│   ├── events.schema.json
│   └── metrics.schema.json
├── test_state_schema.sh                   # fixtures vs state.schema.json
├── test_events_schema.sh                  # events.jsonl vs events.schema.json
├── test_metrics_schema.sh                 # metrics.json vs metrics.schema.json
├── test_hook_smoke.sh                     # post-experiment-log.sh のスモーク
├── test_init_state_idempotent.sh          # init_state.sh が冪等か
├── test_version_triple.sh                 # plugin.json + marketplace.json (×2) + CHANGELOG 一致
├── test_json_manifests.sh                 # 全 JSON manifest が syntactically valid
└── test_bash_syntax.sh                    # 全 .sh の bash -n
```

## 実行

```bash
# 全テスト
bash tests/run_all.sh

# 個別
bash tests/test_state_schema.sh
bash tests/test_hook_smoke.sh
```

## 依存

- `bash` >= 4
- `jq`
- `python3` + `jsonschema` (or `uv` で `uv run --with jsonschema python3` が使える環境)
  - jsonschema が無い場合、schema 系テストは JSON syntactic check のみで通過する (CI では必ず入れる)

## 各テストの責務

| test | 失敗時の影響 | 修正アクション |
|------|--------------|---------------|
| `state_schema` | STATE.json schema 破壊 → 既存プロジェクト全部読めなくなる | `phase_state_machine.md` SoT を見直し migration script を準備 |
| `events_schema` | events.jsonl の必須フィールド欠落 → CLAUDE.md ログ規約違反 | hook と skill 両方を確認 |
| `metrics_schema` | metrics.json 構造違反 → result-statistician の分析失敗 | run skill と統計検定の整合性を確認 |
| `hook_smoke` | hook が `uv run` を捕捉しない or 不要なコマンドを記録する | hooks/post-experiment-log.sh の matcher 確認 |
| `init_state_idempotent` | プロジェクト初期化が破壊的 → 既存 STATE.json が消える | scripts/init_state.sh の bash logic 確認 |
| `version_triple` | manifest 三箇所がズレ / CHANGELOG エントリ欠落 | RELEASING.md チェックリスト見直し |
| `json_manifests` | 構文不正 → install 失敗 | jq -e で error message を確認して修正 |
| `bash_syntax` | hook / scripts のシェルスクリプト構文エラー | bash -n で行番号を特定 |

## CI 連携

`.github/workflows/lint.yml` がプルリク・push のたびに `tests/run_all.sh` を呼びます。
ローカルで `bash tests/run_all.sh` が green になってから push するのが推奨。

## 新しいテストを追加するとき

1. `tests/test_<purpose>.sh` を作る (実行可能、`set -euo pipefail` で書く)
2. 終了コード 0 = pass、それ以外 = fail
3. 1 行の合否サマリを stdout に出す (`echo "<test name>: pass"`)
4. fixtures が必要なら `tests/fixtures/` に置く
5. `tests/README.md` の表に追加
6. `RELEASING.md` の pre-release checklist に該当項目があるか確認
