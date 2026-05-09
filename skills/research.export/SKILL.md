---
name: research.export
description: >
  プロジェクトを公開・共有用の bundle に変換する skill。`scripts/export_project.sh` の上位互換で、
  events.jsonl の PII redaction (prompt 全文の hash 化)、manifest.json (commit SHA / 依存 / モデル ID)、
  schema validation を含む。Zenodo / HF Hub / Slack 共有等の前段。
  Use when: paper の公開時、論文 reviewer に再現用 bundle を渡すとき、または
  project を別マシンに移行するとき。
---

# `research.export`

`auto-research` プロジェクトを共有可能 bundle に変換する skill。

## 入力 / 出力

入力:
- `<slug>` (`.research/<slug>/` が存在)
- (任意) `<output_dir>` (デフォルトはカレントディレクトリ)
- (任意) `--include-checkpoints` フラグ (デフォルトは exclude)
- (任意) `--include-cache` フラグ (デフォルトは exclude)

出力:
- `<output_dir>/<slug>_export_<YYYYMMDD>_<commit_sha[:7]>.tar.gz`
- bundle 内には `MANIFEST.json` と `INTEGRITY.txt` (ファイル一覧 + sha256) を含める

## 既存 `scripts/export_project.sh` との違い

| 機能 | shell script | この skill |
|------|--------------|-----------|
| 基本 tar.gz 作成 | yes | yes |
| バイナリ exclude (checkpoint, cache) | yes | yes |
| **MANIFEST.json 生成** | no | **yes** |
| **events.jsonl の PII redaction (prompt hash 化)** | no | **yes** |
| **schema validation** | no | **yes (state.schema.json で STATE.json を検証)** |
| **integrity hash** | no | **yes (各ファイル sha256)** |

shell script は引き続き utility として残す。skill は **publication grade** の bundle 用。

## ワークフロー

### 1. プロジェクト存在確認

```
.research/<slug>/STATE.json が存在しなければエラー
.research/<slug>/STATE.json を read し、tests/schemas/state.schema.json で validate
```

無い / invalid なら明確に error メッセージ。

### 2. PII redaction

`.research/<slug>/06_RUNS/*/events.jsonl` を全て scan:

| 元フィールド | 処理 |
|-------------|------|
| `prompt`, `input_text`, `output_text` | 削除して `prompt_sha256` (16 文字 hex 先頭) で置換 |
| `error_stack` のうちパス部分 (`/home/<user>/...`) | `<HOME>/...` に置換 |
| 環境変数値 (もし events に含まれていれば) | 削除 |

redaction 後の events.jsonl は `events.jsonl.redacted` という別ファイルとしてバンドル内に置き、生 `events.jsonl` はバンドルに含めない。

### 3. MANIFEST.json 生成

bundle root に `MANIFEST.json` を作る:

```json
{
  "schema_version": 1,
  "project_slug": "llm-eval-mmlu-baseline",
  "exported_at": "2026-05-09T15:00:00Z",
  "exporter_version": "auto-research 0.4.0",
  "git": {
    "sha": "abc1234567890",
    "dirty": false,
    "remote": "git@github.com:0h-n0/auto-research.git"
  },
  "project_state": {
    "current_phase": 4,
    "last_gate_passed": "G3",
    "completed_at": null
  },
  "deps": {
    "python_version": "3.11.7",
    "key_packages": {
      "torch": "2.5.0",
      "transformers": "4.45.1",
      "lm-eval": "0.4.7"
    }
  },
  "redaction": {
    "fields_redacted": ["events.jsonl::prompt", "events.jsonl::input_text"],
    "n_lines_redacted": 432
  },
  "exclusions": ["checkpoints/", "cache/", "data/", "*.pt", "*.safetensors"],
  "license": "MIT (research artifacts), see paper/ai_disclosure for AI-author note"
}
```

### 4. INTEGRITY.txt

bundle 内全ファイルの sha256:

```
sha256:abc1234... STATE.json
sha256:def5678... 01_BRIEF.md
sha256:ghi9012... 02_SURVEY/papers.jsonl
...
```

### 5. tar.gz 作成

```bash
tar czf <slug>_export_<date>_<sha7>.tar.gz \
  --exclude=checkpoints \
  --exclude=cache \
  --exclude=data \
  --exclude='*.pt' \
  --exclude='*.safetensors' \
  --exclude='__pycache__' \
  --exclude='.venv' \
  -C .research <slug>
```

### 6. PII reminder + verification

skill 完了時に:

```
✓ Bundle: <slug>_export_<date>_<sha7>.tar.gz (XX MB)
✓ MANIFEST.json + INTEGRITY.txt 同梱
✓ events.jsonl: 432 lines redacted (prompts -> sha256 hash)

⚠ 公開前の最終確認:
  1. tar tzf <bundle>.tar.gz でバイナリが含まれていないことを確認
  2. MANIFEST.json の git.sha が公開リポジトリで参照可能か
  3. paper/ai_disclosure 節を読み返す
```

## 実装ガイド

skill 本体 (Claude が実行する流れ):

1. 引数解析 + STATE.json validation
2. PII redaction を Python (`uv run python` 必要なし、`jq` で十分):

   ```bash
   for f in .research/<slug>/06_RUNS/*/events.jsonl; do
     jq -c '
       . as $orig
       | (.prompt // "" | @sh) as $prompt
       | if .prompt then del(.prompt) | .prompt_sha256 = ($prompt | @base64) else . end
     ' "$f" > "${f}.redacted"
   done
   ```

   (`@base64` は便宜的。実装時は sha256 を計算する別 step。詳細は `references/redact.sh.txt` 参照)

3. MANIFEST.json 組み立て:
   ```bash
   git_sha=$(git rev-parse HEAD)
   git_remote=$(git config --get remote.origin.url || echo "")
   ...
   ```

4. INTEGRITY.txt:
   ```bash
   find .research/<slug> -type f -not -path '*/checkpoints/*' \
     -not -path '*/cache/*' -not -path '*/__pycache__/*' \
     -exec sha256sum {} +
   ```

5. tar gzip
6. **next-step trailer 必須出力**

### `references/redact.sh.txt`

PII redaction シェルスクリプト雛形。実装時に rename して使う。

## 失敗モード

- `.research/<slug>/` 不在 → error
- STATE.json schema invalid → error (修正を促す)
- jq 未インストール → error (apt install jq を案内)
- bundle が異常に小さい/大きい (1 KB 未満 or 1 GB 超) → warning + 内容確認を促す
- redaction で 全 events.jsonl が空になった → warning (元データに PII が無かった可能性)

## Phase 連携

- Phase 8 G4 通過後の **publication 公開** タイミングで dispatch される想定
- G4 通過前の途中 export も可能だが、`MANIFEST.json` の `project_state` で Phase が 8 未満であることが残る

## next-step trailer

skill 完了時の trailer 推奨:

```
─────────────────────────────────────
[Phase {N}/8] {bar}  G4 ✓  ✓ EXPORTED

→ 推奨: bundle を Zenodo / HF Hub / GitHub Release にアップロード
  bundle: <slug>_export_<date>_<sha7>.tar.gz

  代替:
   ・ /auto-research:research-status <slug>   project 状態確認
   ・ tar tzf <bundle>      内容確認
─────────────────────────────────────
```
