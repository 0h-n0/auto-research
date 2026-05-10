---
description: "Cross-project Lessons DB (~/.research-lessons.json) を free text + tag filter で検索。過去 project の institutional memory を新 project の Phase 3 / 6 で再利用。(v0.15.0+)"
argument-hint: "<query> [--tag #foo] [--phase N] [--model 3B] (空なら全件 list、最新順)"
allowed-tools: [Read, Bash, Glob]
---

Cross-project Lessons DB 検索コマンド。`research.lab.notebook` skill v0.15.0+ で生成される
`~/.research-lessons.json` を `jq` で検索する軽量コマンド (skill 経由しない)。

## 実行手順

### 1. DB 存在確認

```bash
DB="${RESEARCH_LESSONS_DB:-$HOME/.research-lessons.json}"
test -f "$DB" || { echo "Lessons DB not found at $DB. Run a project through Phase 8 first."; exit 1; }
```

不在時は warning + exit 0 で「まだ Lessons DB が無い」を user に伝える。

### 2. 引数 parse

引数フォーマット:
- `<query>`: 自由 text、`summary` field を case-insensitive grep
- `--tag #foo`: `tags` array に `#foo` が含まれる lesson のみ
- `--phase N`: `phase == N` で filter (3 / 4 / 6 / 8)
- `--model SIZE`: `context.model_size == SIZE` で filter (例: `3B`、`7B`)
- 引数空: 全 lesson を `captured_at` desc で list (最新 20 件)

### 3. jq filter

free text + tag + phase + model の組み合わせ filter:

```bash
# 例: text="memory" + tag="#oom"
jq --arg q "memory" --arg tag "#oom" '
  .lessons[]
  | select(.summary | test($q; "i"))
  | select(.tags | contains([$tag]))
' "$DB"
```

複数条件は AND で組み合わせる。引数指定がなければ filter なし。

### 4. 出力フォーマット

各 hit について以下を 1 block 表示:

```
─────────────────────────────────────
[lesson-2026-05-13-r_a3f2-1]  source: attention-sink-llama-long-ctx (Phase 6)
captured: 2026-05-13T15:42:00Z
tags: #convergence-issue #assumption-reversed #llama-3b

summary: small LLM (3B) では prompt format より decoding setting が dominant variance source

context: domain=llm-evaluation, model_size=3B, task=MMLU
related: .research/attention-sink-llama-long-ctx/06_RUNS/r_a3f2/POSTMORTEM.md
─────────────────────────────────────
```

末尾に `Total: N hits / M total lessons` を表示。

### 5. 0 hits 時

```
No lessons matched. Try:
  /auto-research:lessons-search                       # 全件 list
  /auto-research:lessons-search --tag #oom            # tag filter
  /auto-research:lessons-search "memory"              # free text
```

## 使用例

```text
> /auto-research:lessons-search "memory"
> /auto-research:lessons-search --tag #oom
> /auto-research:lessons-search "format dominance" --phase 6
> /auto-research:lessons-search --model 3B
> /auto-research:lessons-search                            # 全件 list
```

## 関連

- DB schema: `skills/research.lab.notebook/references/lessons_db_schema.md`
- Tag taxonomy: `skills/research.lab.notebook/references/tag_taxonomy.md`
- Phase 8 で append される動作: `skills/research.lab.notebook/references/phase_notebook_map.md`

## 注意

- `~/.research-lessons.json` は user home に存在、全 auto-research project 横断で共有
- 環境変数 `RESEARCH_LESSONS_DB` で別 path を指定可能 (テスト / 共有 user)
- DB 編集は本コマンドでは行わない (read-only)。append は Phase 8 dispatch 経由のみ
- PII / credential は Phase 8 dispatch 時に redaction 済 (`responsible_research.md` 準拠)
