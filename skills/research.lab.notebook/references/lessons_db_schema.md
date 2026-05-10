# Cross-project Lessons DB schema (`~/.research-lessons.json`)

`research.lab.notebook` が Phase 8 で **全プロジェクト横断の lessons** を append する DB の SoT。
ファイル位置 `~/.research-lessons.json` (user home、auto-research workflow を使う全プロジェクト共通)。

> **目的**: 個別プロジェクトで得た generalizable lesson を捨てず、新プロジェクトの Phase 3 / 6 で
> 類似 failure / pattern を検索できるようにする。Lab notebook 文化の "institutional memory" 機能。

## ファイル位置

- **Primary**: `~/.research-lessons.json`
- 環境変数 `RESEARCH_LESSONS_DB` で override 可能 (テスト / 共有 user 用)
- 不在時: lab.notebook が初期化 (schema v0.15.0)

## Schema (v0.15.0)

```json
{
  "version": "0.15.0",
  "schema_uri": "https://github.com/0h-n0/auto-research/blob/main/skills/research.lab.notebook/references/lessons_db_schema.md",
  "lessons": [
    {
      "id": "lesson-2026-05-13-r_a3f2-1",
      "source_slug": "attention-sink-llama-long-ctx",
      "source_run_id": "20260513-104523-a1b2c3d-9e8f7d",
      "phase": 6,
      "captured_at": "2026-05-13T15:42:00Z",
      "summary": "small LLM (3B) では prompt format より decoding setting が dominant variance source",
      "tags": ["#convergence-issue", "#assumption-reversed", "#llama-3b"],
      "context": {
        "domain": "llm-evaluation",
        "model_size": "3B",
        "task": "MMLU",
        "compute": "1xA100-40GB"
      },
      "generalizable": true,
      "related_postmortems": [
        ".research/attention-sink-llama-long-ctx/06_RUNS/r_a3f2/POSTMORTEM.md"
      ],
      "related_lab_notebook_entry": ".research/attention-sink-llama-long-ctx/LAB_NOTEBOOK.md#2026-05-13-phase-6-metacognition"
    }
  ]
}
```

## 必須フィールド

| field | type | description |
|-------|------|-------------|
| `id` | string | unique、形式 `lesson-{YYYY-MM-DD}-{run_id_suffix}-{index}` |
| `source_slug` | string | `.research/<slug>/` の slug |
| `phase` | integer | 8 (Phase 8 review 由来)、6 (Phase 6 metacognition 由来) |
| `captured_at` | ISO 8601 string | UTC 推奨 |
| `summary` | string | 1-2 文、blameless で書く |
| `tags` | array of string | controlled + 自由 tag (`tag_taxonomy.md` 準拠) |
| `generalizable` | boolean | true なら他 project でも参考になる |

## オプションフィールド

| field | type | description |
|-------|------|-------------|
| `source_run_id` | string | failed run 由来なら events.jsonl の run_id |
| `context` | object | domain / model / task / compute の自由オブジェクト |
| `related_postmortems` | array of path | POSTMORTEM.md への相対 path |
| `related_lab_notebook_entry` | string | LAB_NOTEBOOK.md の anchor link |

## ID 生成 rule

```
id = "lesson-" + {captured_at の date 部分} + "-" + {run_id の suffix or "phase8"} + "-" + {index}
```

例:
- `lesson-2026-05-13-r_a3f2-1` (Phase 6 metacognition 由来)
- `lesson-2026-05-14-phase8-1` (Phase 8 review 由来、run_id 不在)
- `lesson-2026-05-13-r_a3f2-2` (同 date + run_id で 2 件目の lesson)

衝突した場合 (id 既存): skip + log (idempotent)。

## Append 動作 (Phase 8 dispatch)

1. `~/.research-lessons.json` 読み込み (不在なら schema 初期化)
2. LAB_NOTEBOOK の **top 3 lessons** を抽出:
   - POSTMORTEM §5 Lessons (各 failed run の generalizable な学び)
   - Phase 6 metacognition entry の "Generalizable insight" 行
3. 各 lesson について `id` を生成、既存 id と照合
4. 新規分のみ `lessons` array に append
5. **Atomic write** (詳細は次節)

## Atomic write (同時書き込み防止)

複数プロジェクトから同時に `~/.research-lessons.json` を更新する可能性がある。簡易な atomic write:

```bash
# 1. 既存ファイル読み込み (or schema 初期化)
TMPFILE=$(mktemp ~/.research-lessons.XXXXXX.json)
jq '.lessons += [<new entries>]' ~/.research-lessons.json > "$TMPFILE"

# 2. atomic rename (POSIX で atomic 保証)
mv "$TMPFILE" ~/.research-lessons.json
```

`flock` は使わない (auto-research workflow は single user single project セッションが前提)。
真の concurrent append が必要なら v1.0+ で SQLite に移行を検討。

## Schema validation

各 lesson append 前に jq で type check:

```bash
jq -e '.id and .source_slug and .phase and .captured_at and .summary and .tags' \
   <<< "$NEW_LESSON_JSON" > /dev/null || { echo "schema validation failed"; exit 1; }
```

violating lesson は skip + warning。

## Read API (lessons-search command)

`/auto-research:lessons-search` 動作:

```bash
# 1. free text search (summary)
jq '.lessons[] | select(.summary | test("memory"; "i"))' ~/.research-lessons.json

# 2. tag filter
jq '.lessons[] | select(.tags | contains(["#oom"]))' ~/.research-lessons.json

# 3. context filter (model_size など)
jq '.lessons[] | select(.context.model_size == "3B")' ~/.research-lessons.json
```

詳細は `commands/lessons-search.md`。

## サイズ管理

100 project × 3 lesson = 300 entries は jq filter で十分高速 (~10ms)。
1000+ entries で性能劣化する場合は v0.17+ で:
- semantic search (LLM embedding)
- SQLite migration

## アンチパターン

- ❌ `~/.research-lessons.json` を直接編集 (人手編集は OK だが atomic rename 経由を推奨)
- ❌ id の衝突を ignore して duplicate append
- ❌ summary に PII / 秘密情報を書く (responsible_research.md 準拠で必ず redaction)
- ❌ generalizable=false な lesson を append (project-specific は LAB_NOTEBOOK のみで十分)
- ❌ blameless 違反の summary ("X さんがミスった" 等)

## Privacy / PII redaction

Lessons DB は **user home のローカル** にあるが、open notebook science で公開する場合がある。
agent は append 前に以下を check:
- email アドレス、URL の private token、API key を redact
- 共同研究者の実名は initials に
- 商業情報 (社名 / 製品名) は削除
- detail は `responsible_research.md` 準拠

## 既存 v0.14.0 プロジェクトからの後付け

v0.14.0 で生成された LAB_NOTEBOOK.md / POSTMORTEM.md は Phase 6 metacognition entry が
無いので、Phase 8 dispatch 時に lab.notebook が **best-effort で抽出**:
- POSTMORTEM §5 Lessons から summary を抜き出す
- 該当する `tags` を agent draft (controlled vocabulary から)
- `phase=8` で append (Phase 6 由来でなく Phase 8 由来として記録)

## 関連

- Phase 8 dispatch 動作: `phase_notebook_map.md` § Phase 8
- POSTMORTEM §5 Lessons: `postmortem_template.md`
- lessons-search command: `commands/lessons-search.md`
- Tag taxonomy: `tag_taxonomy.md`
- Privacy: `skills/auto-research/references/responsible_research.md`
