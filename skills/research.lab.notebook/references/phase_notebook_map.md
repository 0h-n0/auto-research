# Phase × notebook 動作 SoT

`research.lab.notebook` が **どの Phase で何を実行するか** の単一情報源 (SoT)。
auto-research SKILL の dispatch 設定は本表に従う。

## 動作表

| Phase | Trigger | 起動 | 主動作 | 出力ファイル |
|-------|---------|------|--------|-------------|
| 1 (Brief) | — | (no-op) | LAB_NOTEBOOK.md は Phase 1 では作らない (内容が空でしか書けない) | — |
| 2 (Survey) | — | (no-op) | LAB_NOTEBOOK.md は Phase 2 でも作らない (Phase 3 で初期化) | — |
| 3 (Idea, G2 通過後) | `STATE.json.G2=pass` | **auto** | (1) `03_IDEAS.md` の adopted/rejected 分離 → `03_REJECTED_IDEAS.md` 生成/追記、(2) `LAB_NOTEBOOK.md` を skeleton から生成 + Phase 3 entry + **Decision journal block** (v0.15.0+) + **Tags** | `03_REJECTED_IDEAS.md`、`LAB_NOTEBOOK.md` |
| 4 (Plan, G3 通過後) | `STATE.json.G3=pass` | **auto** (v0.15.0+) | LAB_NOTEBOOK に Phase 4 entry を新規追加 (実験設計の Predicted ablation winner / Predicted significance / Confidence / Assumptions ≤3 + Tags) | `LAB_NOTEBOOK.md` |
| 5 (Scaffold + TDD) | TDD Red 30 分 stuck | **manual (任意)** | LAB_NOTEBOOK に short note (test failure + hypothesis + verified by + Tags) | `LAB_NOTEBOOK.md` |
| 6 (Run) | run 完了 (success/failed 両方) | **auto** | failed run があれば各々: POSTMORTEM 下書き (冒頭 **Blameless callout** + Tags、v0.15.0+) + `reproduce.sh` + `uv.lock` snapshot + LAB_NOTEBOOK entry + **Phase 6 metacognition entry** (Predicted vs Actual / Surprise / What I missed、v0.15.0+) + LAB_NOTEBOOK_INDEX.md re-gen | `06_RUNS/<id>/POSTMORTEM.md`、`06_RUNS/<id>/reproduce.sh`、`06_RUNS/<id>/uv.lock`、`LAB_NOTEBOOK.md`、`LAB_NOTEBOOK_INDEX.md` |
| 7 (Paper drafting) | — | (no-op) | 本 skill は invoke しない。`research.paper.draft` (v0.13.0+) が DRAFT.md の Limitations 節で LAB_NOTEBOOK Lessons を読む (loose coupling) | — |
| 8 (Review) | `08_REVIEW.md` 完成直前 | **auto** | (1) LAB_NOTEBOOK の Lessons を `08_REVIEW.md` に統合 (既存 v0.14.0)、(2) **Lessons DB** (`~/.research-lessons.json`) に top 3 lessons を append (v0.15.0+)、(3) LAB_NOTEBOOK_INDEX.md を re-gen | `08_REVIEW.md` (追記)、`~/.research-lessons.json`、`LAB_NOTEBOOK_INDEX.md` |

## 起動方法

### auto-dispatch (Phase 3 / 4 / 6 / 8)

`skills/auto-research/SKILL.md` の各 Phase 末尾に追加 (v0.14.0+ で 3/6/8、v0.15.0+ で 4 追加):

```markdown
### Phase 3 末 (G2 通過後)
... (既存 step) ...
+ research.lab.notebook を invoke (rejected ideas 保存 + LAB_NOTEBOOK Phase 3 entry + Decision journal block (v0.15.0+) + Tags)
```

```markdown
### Phase 4 末 (G3 通過後、v0.15.0+ 新規)
... (既存 step) ...
+ research.lab.notebook を invoke (LAB_NOTEBOOK Phase 4 entry + Decision journal block + Tags)
```

```markdown
### Phase 6 末 (RESULTS.md 完成後)
... (既存 step) ...
+ research.experiment.run が failed run 検出時に research.lab.notebook を auto-trigger
+ research.lab.notebook が Phase 6 metacognition entry を生成 (Predicted vs Actual + Surprise score + What I missed、v0.15.0+)
+ POSTMORTEM 冒頭に Blameless callout (v0.15.0+)
+ LAB_NOTEBOOK_INDEX.md re-gen (v0.15.0+)
```

```markdown
### Phase 8 末 (08_REVIEW.md 直前)
... (既存 step) ...
+ research.lab.notebook を invoke (Lessons 統合 + Lessons DB append (v0.15.0+) + INDEX re-gen)
```

### manual invoke (Phase 5 / その他)

ユーザーが Claude Code で:
```text
> "Use research.lab.notebook to record this TDD failure for <slug>"
```

または直接:
```text
/auto-research:research-experiment <slug>  # の最中で Red 段階で manual invoke 推奨
```

## Phase 6 の詳細フロー (本 skill の核心)

```
research.experiment.run (Phase 6)
  ↓ run 完了、STATUS=succeeded or failed を 06_RUNS/<id>/STATUS に書く
  ↓
  ├─ STATUS=succeeded
  │    ↓
  │    research.lab.notebook 起動
  │    ↓
  │    LAB_NOTEBOOK.md に Phase 6 success entry 1 行追加
  │    ↓
  │    終了
  │
  └─ STATUS=failed
       ↓
       research.experiment.run が以下を保存:
         - 06_RUNS/<id>/error.txt (stack trace、既存)
         - 06_RUNS/<id>/uv.lock (project root から copy、新規)
         - 06_RUNS/<id>/reproduce.sh (events.jsonl から構築、新規)
       ↓
       research.lab.notebook auto-trigger
       ↓
       (1) events.jsonl + error.txt を読み Hypothesis space 3-5 候補 draft
       (2) POSTMORTEM.md を `<!-- agent-managed:Phase=6 -->` 付きで生成
       (3) Reproducibility 7-tuple checklist を §6 に出力 (不在項目は warning)
       (4) LAB_NOTEBOOK.md に Phase 6 failed entry + POSTMORTEM への link
       ↓
       next-step trailer に "POSTMORTEM 下書き済み" を表示
```

## Idempotency 規則

| 操作 | 重複検出 | 動作 |
|------|---------|------|
| LAB_NOTEBOOK entry | `date + phase + run_id` ハッシュ | skip + log |
| POSTMORTEM 生成 | agent-managed marker 存在 + 同 run_id | skip + log (人手 polish 保護) |
| reproduce.sh | ファイル存在 check | skip + diff log only |
| uv.lock snapshot | ファイル存在 + content hash | skip + log |
| 03_REJECTED_IDEAS section | idea ID (B / C) の anchor | skip + log |

## next-step trailer 仕様

### Phase 3 後 (auto-dispatch 完了時)

```
─────────────────────────────────────
[Phase 3/8] ●●●○○○○○  G2 ✓  📓 lab notebook seeded

→ LAB_NOTEBOOK.md 生成 (Phase 3 entry)
→ 03_REJECTED_IDEAS.md 生成 (rejected ideas: B, C)

  代替:
   ・ /auto-research:research-experiment <slug>   Phase 4 へ進む
   ・ 03_REJECTED_IDEAS.md を polish (rejection reason / future revisit)
─────────────────────────────────────
```

### Phase 6 後 (failed run 検出時)

```
─────────────────────────────────────
[Phase 6/8] ●●●●●○○○  G3 ✓  ⚠ 1 run failed

→ POSTMORTEM 下書き生成済: `06_RUNS/r_a3f2/POSTMORTEM.md`
  Hypothesis 3 件 draft、§4 Decision / §5 Lessons 節は要 user polish
→ Reproduce: `bash 06_RUNS/r_a3f2/reproduce.sh`
→ Reproducibility checklist: 6/7 ✓ (data version hash 不在 ⚠)

  代替:
   ・ POSTMORTEM.md を polish して再 run
   ・ /auto-research:research-status <slug>  全 run 状態確認
─────────────────────────────────────
```

### Phase 8 後 (Lessons 統合済み)

```
─────────────────────────────────────
[Phase 8/8] ●●●●●●●●  G4 ✓  📓 review complete

→ 08_REVIEW.md に LAB_NOTEBOOK の top 3 lessons 統合済
→ Total POSTMORTEMs: 3 (r_a3f2, r_d8e1, r_f12c)
→ Total Lessons captured: 8 (5 generalizable, 3 project-specific)

  代替:
   ・ /auto-research:research-write <slug>   Phase 7 paper.draft 起動
   ・ research.publish で公開
─────────────────────────────────────
```

## 既存 skill との dispatch 関係

```
Phase 3 G2 通過
  └→ auto-research SKILL § 3.5 (新規)
       └→ research.lab.notebook (rejected ideas + LAB_NOTEBOOK seed)

Phase 6 run 完了
  └→ research.experiment.run (既存)
       ├→ 既存: STATUS / metrics.json / events.jsonl 保存
       ├→ 新規: reproduce.sh + uv.lock 保存
       └→ STATUS=failed → research.lab.notebook (POSTMORTEM auto-draft)

Phase 7 paper drafting
  └→ research.paper.draft (既存、v0.13.0)
       └→ DRAFT.md の Limitations 節で LAB_NOTEBOOK Lessons を素材に (loose、optional)

Phase 8 review
  └→ auto-research SKILL § 8.X (新規)
       └→ research.lab.notebook (08_REVIEW.md に Lessons 統合)
```

## 後方互換性

- 既存プロジェクト (LAB_NOTEBOOK.md 不在) で Phase 1-8 通常動作
- v0.13.0 以前の `06_RUNS/<id>/` には reproduce.sh / uv.lock が無い → best-effort で reproduce.sh だけ後付け生成 (uv.lock は recover 不能、warning 表示)
- LAB_NOTEBOOK は途中 Phase からでも開始可能 (idempotent、過去 run の entry を後付け追加)

## 関連

- LAB_NOTEBOOK 雛形: `lab_notebook_skeleton.md`
- POSTMORTEM 雛形: `postmortem_template.md`
- Hypothesis 自動 draft rule: `hypothesis_table_rules.md`
- 再現性 checklist (failed run 用): `failure_reproducibility_checklist.md` (Phase 4 broad checklist は `skills/auto-research/references/reproducibility_checklist.md`、別物)
- Rejected ideas 雛形: `rejected_ideas_template.md`
- Phase 6 で reproduce.sh + uv.lock 保存: `skills/research.experiment.run/SKILL.md` (v0.14.0+ 拡張)
- Phase 3/6/8 dispatch: `skills/auto-research/SKILL.md` (v0.14.0+ 拡張)
