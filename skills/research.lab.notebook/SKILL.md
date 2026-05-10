---
name: research.lab.notebook
description: >
  実験 lab notebook + 失敗 postmortem skill。Phase 3/6/8 で auto-dispatch、Phase 5 は任意 invoke。
  単一 living `LAB_NOTEBOOK.md` (時系列航海日誌) と per-failure `06_RUNS/<id>/POSTMORTEM.md`
  (再現可能な失敗カード) のハイブリッド構造で、失敗の理由・改善策・思考過程を全て記録する。
  失敗 run 検出時に `reproduce.sh` + `uv.lock` snapshot を保存し、科学的再現性を担保する。
  Phase 3 で rejected idea も `03_REJECTED_IDEAS.md` に保存し、将来の見直しを可能にする。
  Use when: Phase 3 G2 通過時 (auto)、Phase 6 で failed run 検出時 (auto)、Phase 8 review 時 (auto)、
  または「失敗を記録したい / 思考過程を残したい」と明示的に要求されたとき。
---

# `research.lab.notebook`

実験 lab notebook + 失敗 postmortem を維持する skill。「成功した結果」だけでなく
「**何を試して、なぜダメだったか、次に何を変えるか**」を体系的に残す。

## なぜ必要か

熟練研究者の暗黙知:
- 紙の lab notebook は失敗・思考変遷を時系列で残すのが本質的価値
- 失敗を再現できなければ「なぜ失敗したか」の検証が出来ない (科学の再現性原則)
- 捨てた idea も「なぜ捨てたか」を残すと将来の pivot で再考できる
- per-iteration の思考は時間が経つと忘れる (記憶ではなく記録)

現状の auto-research workflow (v0.13.0) は失敗 run の生データ (`06_RUNS/<id>/STATUS=failed`,
`events.jsonl`, `error.txt`) を保持するが、**解釈と再現スクリプトと思考連続性** が散逸している。
本 skill はこのギャップを埋める。

## 設計の核

1. **Hybrid 構造**:
   - `LAB_NOTEBOOK.md` (slug 直下、living、時系列航海日誌)
   - `06_RUNS/<run_id>/POSTMORTEM.md` (per-failure、再現可能な失敗カード)
   - `LAB_NOTEBOOK_INDEX.md` (auto-gen、tag 逆引き、v0.15.0+)
2. **双方向 link**: LAB_NOTEBOOK の Phase 6 entry → POSTMORTEM、POSTMORTEM の Cross-references → LAB_NOTEBOOK
3. **再現性 7-tuple**: code rev / config / deps (uv.lock) / seed / data hash / hardware / reproduce.sh
4. **Hypothesis space draft**: events.jsonl + error.txt から 3-5 候補を agent draft、user polish
5. **idempotent**: `<!-- agent-managed:Phase=N -->` marker で人手編集保護、再 invoke で skip
6. **Rejected ideas を捨てない**: `03_REJECTED_IDEAS.md` に reason + future revisit conditions
7. **Decision journal (v0.15.0+、Light touch)**: Phase 3 / 4 で "予測 / 信念 / 仮定" を記録、Phase 6 で実測との Predicted vs Actual を agent draft (Annie Duke 由来)
8. **Tag system (v0.15.0+、Hybrid)**: controlled vocabulary 28 個 + 自由 tag、INDEX.md で逆引き (FAIR 由来)
9. **Cross-project Lessons DB (v0.15.0+)**: `~/.research-lessons.json` で全プロジェクト横断の institutional memory
10. **Blameless culture (v0.15.0+)**: POSTMORTEM 冒頭 callout、Anti-pattern 明示 (Google SRE 由来)

## 入力 / 出力

入力 (自動検知):
- `.research/<slug>/STATE.json` (current_phase / G2 status)
- `.research/<slug>/03_IDEAS.md` (Phase 3 で adopted vs rejected)
- `.research/<slug>/06_RUNS/<id>/STATUS` (Phase 6 で failed 検知)
- `.research/<slug>/06_RUNS/<id>/events.jsonl` (Hypothesis draft の input)
- `.research/<slug>/06_RUNS/<id>/error.txt` (stack trace excerpt の input)
- `.research/<slug>/08_REVIEW.md` (Phase 8 で Lessons 統合)
- project root の `uv.lock` (Phase 6 で snapshot copy)

出力:
- `.research/<slug>/LAB_NOTEBOOK.md` (新規 or 追記、時系列)
- `.research/<slug>/03_REJECTED_IDEAS.md` (Phase 3 後、新規 or 追記)
- `.research/<slug>/06_RUNS/<id>/POSTMORTEM.md` (failed run のみ、auto-draft)
- `.research/<slug>/06_RUNS/<id>/reproduce.sh` (auto-gen、`set -euo pipefail` 必須)
- `.research/<slug>/06_RUNS/<id>/uv.lock` (project root から snapshot copy)

## Phase × 動作

詳細は `references/phase_notebook_map.md` を SoT とする。

| Phase | 起動 | 動作 |
|-------|------|------|
| 3 (G2 通過後) | auto | `IDEAS.md` の adopted vs rejected を読み、rejected idea を `03_REJECTED_IDEAS.md` に保存 + LAB_NOTEBOOK Phase 3 entry + **Decision journal block** (v0.15.0+) + **Tags** |
| 4 (G3 通過後、v0.15.0+) | auto | LAB_NOTEBOOK Phase 4 entry を新規追加 (Predicted ablation winner / Predicted significance / Confidence / Assumptions ≤3 + Tags) |
| 5 (TDD Red) | manual (任意) | LAB_NOTEBOOK に short note 追加 (test failure の hypothesis + verified by + Tags) |
| 6 (run 完了後) | auto | failed run があれば各々について POSTMORTEM 下書き (冒頭 **Blameless callout**、v0.15.0+) + reproduce.sh + uv.lock snapshot + LAB_NOTEBOOK entry。成功 run も 1 行 entry。**Phase 6 metacognition entry** (Predicted vs Actual + Surprise score + What I missed、v0.15.0+) + LAB_NOTEBOOK_INDEX.md re-gen |
| 7 (paper.draft) | — | (本 skill は invoke しない、paper.draft が DRAFT.md の Limitations 節で LAB_NOTEBOOK Lessons を読む) |
| 8 (Review) | auto | LAB_NOTEBOOK の Lessons を `08_REVIEW.md` に統合 + **Lessons DB** (`~/.research-lessons.json`) に top 3 lessons append (v0.15.0+) + INDEX re-gen |

## ファイル雛形

| ファイル | SoT |
|---------|-----|
| `LAB_NOTEBOOK.md` | `references/lab_notebook_skeleton.md` |
| `POSTMORTEM.md` (per-failure) | `references/postmortem_template.md` |
| `03_REJECTED_IDEAS.md` | `references/rejected_ideas_template.md` |
| Hypothesis space draft rule | `references/hypothesis_table_rules.md` |
| 再現性 checklist | `references/failure_reproducibility_checklist.md` |
| Phase × 動作 SoT | `references/phase_notebook_map.md` |
| **Decision journal** (Light touch、v0.15.0+) | `references/decision_journal_template.md` |
| **Tag taxonomy** (Hybrid、v0.15.0+) | `references/tag_taxonomy.md` |
| **Lessons DB schema** (v0.15.0+) | `references/lessons_db_schema.md` |
| **Blameless principles** (v0.15.0+) | `references/blameless_principles.md` |

## Hypothesis space 自動 draft (Phase 6)

`events.jsonl` + `error.txt` を読んで以下 heuristic で **3-5 候補を draft**:

| error pattern (regex) | 推定 H | 推定 verdict (初期) |
|----------------------|--------|--------------------|
| `OutOfMemoryError`, `CUDA out of memory` | "GPU memory 不足 (batch / model size)" | LIKELY |
| `NaN`, `Inf` in loss | "数値発散 (lr 高 / fp16 / 勾配爆発)" | LIKELY |
| `AssertionError` in shape | "tensor shape mismatch" | LIKELY |
| timeout / SIGKILL | "wall-clock 超過 / OOM-killer" | LIKELY |
| `ImportError`, `ModuleNotFoundError` | "依存欠落 (uv.lock 不整合)" | LIKELY |
| (その他) | error.txt 全文を読んで 3 仮説提示 | UNLIKELY |

詳細 + 例は `references/hypothesis_table_rules.md`。**verdict は agent 推定だが user が確定**
(LIKELY / UNLIKELY / RULED OUT の 3 値)。

## 再現性 7-tuple

`references/failure_reproducibility_checklist.md` で SoT 化 (Phase 4 の broad checklist `skills/auto-research/references/reproducibility_checklist.md` とは別物、failed run 再現に特化)。POSTMORTEM の §6 "Reproducing this failure"
で全項目が揃っているか agent が check:

1. **Code rev**: `events.jsonl.git_rev` (既存)
2. **Config**: `06_RUNS/<id>/config.yaml` (既存)
3. **Dependencies**: `06_RUNS/<id>/uv.lock` snapshot (本 skill で新規)
4. **Random seed**: events.jsonl 内 (既存)
5. **Data version**: `data_lineage.md` の hash (既存)
6. **Hardware**: events.jsonl の env (既存、要確認)
7. **Reproduce command**: `06_RUNS/<id>/reproduce.sh` (本 skill で新規、`set -euo pipefail` 必須)

snapshot 不在 (例: 過去 run) は warning 表示で best-effort。

## 安全機構

- **agent-managed marker**: `<!-- agent-managed:Phase=N -->` で人手編集保護 (paper.scaffold v0.13.0 と同 pattern)
- **重複防止**: LAB_NOTEBOOK は date + run_id ハッシュで entry 重複 detect
- **POSTMORTEM の必須節**: §4 (Decision) と §5 (Lessons) は agent draft 後 user polish 必須
- **reproduce.sh overwrite 禁止**: 既存なら diff log だけ残し、上書きしない

## 動作モード

invoke 時:
1. `STATE.json` 読み、current_phase 確認
2. `LAB_NOTEBOOK.md` 既存なら追記、無ければ skeleton から生成
3. **Phase 3**: `IDEAS.md` adopted/rejected 分離 → `03_REJECTED_IDEAS.md` に保存 + LAB_NOTEBOOK entry
4. **Phase 6 (failed run 検出時)**: `06_RUNS/*/STATUS` を grep → 各 failed run について:
   - events.jsonl + error.txt から Hypothesis space 3-5 候補 draft
   - `POSTMORTEM.md` を `<!-- agent-managed:Phase=6 -->` marker 付きで書く
   - events.jsonl の cmd から `reproduce.sh` を generate (`set -euo pipefail` + `uv sync --frozen`)
   - project root の `uv.lock` を `06_RUNS/<id>/uv.lock` にコピー
   - LAB_NOTEBOOK に Phase 6 entry を追加 (POSTMORTEM への link)
5. **Phase 8**: LAB_NOTEBOOK の Lessons を `08_REVIEW.md` に統合 (overwrite せず追記)

## 既存 skill との関係

| 既存 skill | 関係 |
|-----------|------|
| `research.experiment.run` | Phase 6 で `STATUS=failed` を書いた直後に lab.notebook を trigger。reproduce.sh + uv.lock snapshot copy も run 側で実施 |
| `research.experiment.scaffold` | Phase 5 TDD Red 段階で 30 分以上 stuck したら lab.notebook を invoke 推奨 (任意) |
| `research.paper.scaffold` (v0.13.0) | Phase 7 paper.draft が DRAFT.md の Limitations 節で LAB_NOTEBOOK Lessons を素材に使う (loose coupling) |
| `research.autonomous.tinker` | tinker_loop の per-iteration 思考 (events.jsonl) を tinker 終了時に lab.notebook へ集約 |
| `research-gap-finder` (reviewer) | Phase 8 で POSTMORTEM の peer review (将来 v0.17+ feature) |
| **`/auto-research:lessons-search`** (v0.15.0+) | `~/.research-lessons.json` を grep + tag filter で検索する slash command |

## next-step trailer (Phase 6 失敗時)

```
─────────────────────────────────────
[Phase 6/8] ●●●●●○○○  G3 ✓  ⚠ 1 run failed

→ POSTMORTEM 下書き生成済: `06_RUNS/r_a3f2/POSTMORTEM.md`
  (Hypothesis 3 件 draft、Decision / Lessons 節は要 polish)
→ Reproduce: `bash 06_RUNS/r_a3f2/reproduce.sh`

  代替:
   ・ POSTMORTEM.md を polish して `research-experiment <slug>` で再 run
   ・ `research-status <slug>` で全 run 状態確認
─────────────────────────────────────
```

## アンチパターン

- ❌ 失敗を「再現できないから」と Decision / Lessons なしで close
- ❌ Hypothesis space を 1 件で済ます (常に 3-5 候補で空間を張る)
- ❌ rejected idea を要約 1 行で捨てる (将来見直すための full body + reason 必要)
- ❌ reproduce.sh を `set -euo pipefail` なしで書く (silent fail で再現性破壊)
- ❌ POSTMORTEM の §3 Hypothesis を agent draft のまま release (verdict は user 確定必須)
- ❌ uv.lock snapshot を skip (deps drift で 1 ヶ月後再現不能)

## 失敗モード

| failure | 検出 | 回復 |
|---------|------|------|
| `06_RUNS/<id>/events.jsonl` 不在 | grep | warning + Hypothesis を error.txt のみから draft |
| project root に `uv.lock` 不在 (uv 未使用 project) | test | warning + reproduce.sh の `uv sync` 行を skip |
| `STATE.json.current_phase` 不明 | jq filter | manual `--phase` 引数を要求 |
| LAB_NOTEBOOK の同一 entry が既存 | hash check | skip + log |
| 過去 run (v0.13.0 以前) に reproduce.sh 後付け | best-effort | reproduce.sh 生成、uv.lock 不在 warning |

## 関連

- 雛形: `references/lab_notebook_skeleton.md`, `references/postmortem_template.md`, `references/rejected_ideas_template.md`
- ルール: `references/hypothesis_table_rules.md`, `references/failure_reproducibility_checklist.md`
- SoT: `references/phase_notebook_map.md`
- v0.15.0+ best-practice 取り込み:
  - `references/decision_journal_template.md` (Annie Duke "How to Decide" Light touch 版)
  - `references/tag_taxonomy.md` (FAIR Findable 由来、controlled + 自由 tag Hybrid)
  - `references/lessons_db_schema.md` (`~/.research-lessons.json` cross-project DB)
  - `references/blameless_principles.md` (Google SRE "Blameless Postmortems" 由来)
- 引用ルール: `skills/auto-research/references/responsible_research.md` (引用 ≤2 文、PII redaction)
- 既存 PostToolUse hook: `.claude-plugin/hooks/post-experiment-log.sh` (events.jsonl の生成元)
- 新 slash command (v0.15.0+): `commands/lessons-search.md`
