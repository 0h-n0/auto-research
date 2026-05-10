# LAB_NOTEBOOK.md skeleton

`research.lab.notebook` が `.research/<slug>/LAB_NOTEBOOK.md` を初期化するときの雛形 (SoT)。

## 雛形全文

```markdown
# Lab Notebook — <slug>

<!-- agent-managed:lab.notebook v0.14.0 -->

> 単一 living document として、Phase 進行中の **思考変遷・選択・失敗・改善** を時系列で残す。
> Phase 横断の "なぜそうなったか" の navigator。
> 失敗の詳細は per-run `06_RUNS/<id>/POSTMORTEM.md` に分離。

## Project metadata

- **Slug**: <slug>
- **Topic**: <01_BRIEF.md の研究テーマ>
- **Started**: <ISO 8601 date>
- **Current phase**: <STATE.json.current_phase>
- **Cross-references**:
  - Brief: [`01_BRIEF.md`](01_BRIEF.md)
  - Survey: [`02_SURVEY/MATRIX.md`](02_SURVEY/MATRIX.md)
  - Rejected ideas: [`03_REJECTED_IDEAS.md`](03_REJECTED_IDEAS.md)
  - Paper draft: [`paper/DRAFT.md`](paper/DRAFT.md) (v0.13.0+)

---

## Timeline

<!-- 各 entry は時系列 (新しいものを下に append)。Phase ごとの形式は phase_notebook_map.md 参照 -->

### YYYY-MM-DD [Phase N <subtitle>] <one-line summary>

(entry body)

---
```

## 雛形の細部ルール

### 1. Phase 3 entry (G2 通過時、auto-dispatch)

```markdown
### 2026-05-11 [Phase 3 G2] Idea selection — 3 ideas considered, 1 adopted

- **Considered**: 3 ideas (詳細 `03_IDEAS.md`)
  - **A**: <title> — **selected ✓**. Core hypothesis: <H1>
  - **B**: <title> — rejected. Reason: <one-line>. → `03_REJECTED_IDEAS.md#B`
  - **C**: <title> — rejected. Reason: <one-line>. → `03_REJECTED_IDEAS.md#C`
- **Why A was selected**: <核となる選択理由、1-2 文>
- **Trade-off accepted**: <選択することで諦めた何か、1 文>
- **Dependencies / risks**: <Phase 4 設計に影響する依存>

**Decision journal (Light touch、v0.15.0+)**:
- **Predicted outcome**: <1 行、定量的 e.g., "primary metric +3-5pp on MMLU baseline">
- **Confidence**: <低 / 中 / 高> (<理由 1 行>)
- **Key assumptions** (≤3、numbered):
  1. <falsifiable claim>
  2. <...>
  3. <...>

**Provenance** (任意、v0.16.0+):
- **Inspired by**: `~\cite{<bibtex-key>}` (例: `~\cite{hong2024chat}`、MATRIX.md row #N)
- **Discussion**: <人名 initials> @ <YYYY-MM-DD>
- **External thread**: <URL>
- **AI assistant**: Claude / ChatGPT @ <YYYY-MM-DD> (任意、開示推奨)

Tags: `#phase-3` `#decision-adopted` `#confidence-{low|medium|high}` <その他>
```

詳細: `decision_journal_template.md`、`provenance_template.md`。

### 2. Phase 4 entry (G3 通過時、auto-dispatch、v0.15.0+)

```markdown
### 2026-05-12 [Phase 4 G3] Experiment design — N factors × M baselines

**Plan summary**: (`04_EXPERIMENT_PLAN.md` 1-2 文要約)

**Decision journal (Light touch)**:
- **Predicted ablation winner**: <factor 名、e.g., "format (vs order, decoding, subset)">
- **Predicted statistical significance**: <pass / fail prediction + threshold>
- **Confidence**: <低 / 中 / 高>
- **Key assumptions** (≤3):
  1. <e.g., "n=3 seeds で 95% CI が ±0.5pp 以内">
  2. <e.g., "compute budget 200 GPU-h で完走">
  3. <...>

Tags: `#phase-4` `#decision-design` `#confidence-{low|medium|high}` <factor の自由 tag>
```

### 3. Phase 5 entry (TDD Red、manual invoke、任意)

```markdown
### 2026-05-12 [Phase 5 TDD Red] <test failure 1-line summary>

- **Test**: `<file>::<test_name>`
- **Failure**: <error message 1-2 行>
- **Hypothesis**: <なぜ失敗したと考えたか、1 文>
- **Verified by**: <green にした方法、1 文>
- **Lesson**: <一般化可能な学び、1-2 文>
- **Stuck duration**: <分単位、目安>

Tags: `#phase-5` `#stuck` <error type の controlled tag、e.g., `#shape-mismatch`>
```

### 4. Phase 6 entry (run 完了時、auto-dispatch)

成功 run:
```markdown
### 2026-05-13 [Phase 6 RUN] r_b1c8 SUCCESS — val_loss 2.13 (target 2.20 ✓)

- **Config**: `06_RUNS/r_b1c8/config.yaml`
- **Key insight**: <results.md ハイライト 1-2 文>
- **Builds on**: <prior failed run があれば: r_a3f2 の hypothesis 確認>

Tags: `#phase-6` `#hypothesis-confirmed` <model / task の自由 tag>
```

失敗 run:
```markdown
### 2026-05-13 [Phase 6 RUN] r_a3f2 FAILED — OOM at step 1240

→ See [POSTMORTEM](06_RUNS/r_a3f2/POSTMORTEM.md) for hypothesis space + decision
**Quick**: batch 16 で OOM 推定。次 r_b1c8 で batch 8 + grad_accum 2 を試す。
**Reproduce**: `bash 06_RUNS/r_a3f2/reproduce.sh`

Tags: `#phase-6` `#oom` <model / task の自由 tag>
```

### 5. Phase 6 metacognition entry (auto-dispatch、v0.15.0+)

`06_RESULTS.md` 完成時に lab.notebook が **agent draft で生成**:

```markdown
### 2026-05-13 [Phase 6 metacognition] r_a3f2 + r_b1c8 — Predicted vs Actual

**Predicted vs Actual table**:

| Metric / claim | Predicted | Actual | Surprise (1-5) |
|----------------|-----------|--------|----------------|
| primary acc improvement | +3-5pp (Phase 3) | +1.2pp | 4 |
| dominant factor | format (Phase 3 assumption #2) | decoding (3B), format (8B+) | 4 |
| size invariance | hold across 3-8B (Phase 3 assumption #3) | held only at 7B+ | 3 |

**What I missed** (blameless、`blameless_principles.md` 準拠):
<1-2 文。例: "format dominance 仮定 (Phase 3 assumption #2) は prior work 5 本の平均
+2.5pp という根拠で reasonable だったが、3B model でのみ decoding setting が prevailing
とわかった。assumption #2 は 7B+ では成立する (PARTIALLY CONFIRMED)。">

**Generalizable insight**:
<Lessons DB に保存する候補。1 文。>

**Verdict** (assumption 単位):
- assumption #1 (super-additive compose): CONFIRMED
- assumption #2 (format dominant): REFUTED at 3B、PARTIALLY CONFIRMED at 7B+
- assumption #3 (size invariance): PARTIALLY CONFIRMED

Tags: `#phase-6` `#metacognition` `#predicted-vs-actual` `#hypothesis-rejected` `#assumption-reversed` `#surprise-high`
```

詳細は `decision_journal_template.md` § Phase 6 metacognition を参照。

### 6. Phase 8 entry (Review 完了時、auto-dispatch)

```markdown
### 2026-05-14 [Phase 8 G4] Review summary — top 3 lessons

1. **Lesson 1**: <generalizable insight、1-2 文>
   (sourced from r_a3f2 POSTMORTEM §5)
2. **Lesson 2**: <...>
3. **Lesson 3**: <...>

**Cross-link**: [`08_REVIEW.md`](08_REVIEW.md) に統合済み
**Future revisit**: `03_REJECTED_IDEAS.md` で B / C が将来 candidate (条件: <...>)
**Lessons DB**: `~/.research-lessons.json` に top 3 lessons append 済 (id 一覧 in `08_REVIEW.md`)

Tags: `#phase-8` `#review-summary` `#lessons-captured`
```

### 7. Daily summary entry (任意、v0.16.0+、manual invoke)

Phase event 駆動を補完する日次の任意 entry。Light touch 4-prompt schema:

```markdown
### 2026-05-13 [Daily summary]

- **Today's stuck**: <30 分以上 stuck だったこと、1-2 文。無ければ "N/A">
- **Today's insight**: <その日の小さな気づき、1-2 文。無ければ "N/A">
- **Tomorrow's plan**: <翌日着手すること、1 行>
- **Mood / energy** (任意): <1-5 scale or freeform>

Tags: `#daily-summary` <その日の主活動の自由 tag>
```

詳細: `daily_summary_template.md`。**毎日強制でない**、書きたい日だけ。

### 8. LAB_NOTEBOOK_INDEX.md (auto-gen、v0.15.0+)

Phase 6 / 8 dispatch 時に re-generation。**人手編集不可** (再生成で上書き):

```markdown
# Lab Notebook Index — <slug>

<!-- agent-managed:lab.notebook v0.15.0 -->

> 自動生成 (Phase 6 / 8 で更新)。LAB_NOTEBOOK.md の各 entry を tag で逆引き。
> 人手編集は再生成で上書きされます。

## Controlled tags

### Failure type

#### #oom (3 entries)
- 2026-05-13 [Phase 6 RUN] r_a3f2 — OOM at step 1240 → POSTMORTEM
- ...

#### #nan (1 entry)
- ...

### Outcome

#### #hypothesis-rejected (2 entries)
- 2026-05-13 [Phase 6 metacognition] format dominance assumption reversed
- ...

(他 controlled tag を同様にグループ化)

## Free tags

### #attention-sink (1 entry)
- 2026-05-11 [Phase 3 G2] Idea A selected (focus on attention sink)

### #llama-3b (2 entries)
- ...
```

詳細は `tag_taxonomy.md` § INDEX.md 自動生成 rule を参照。

## Idempotency 規則

- 同一 entry の重複検出は **`date + phase + run_id`** ハッシュで判定
- 既存 entry (marker 内) は overwrite せず skip + log
- 人手追加 entry (marker 外、または marker 削除済) は完全に保護

## Anti-patterns

- ❌ 1 entry に多数の Phase を混ぜる (1 entry = 1 イベント)
- ❌ 失敗 entry に POSTMORTEM への link を書かない (Phase 6 では必須)
- ❌ rejected idea entry で reason を「合わない」とだけ書く (具体的な比較が必要)
- ❌ 古い entry を reverse chronological にする (LAB_NOTEBOOK は **append-only**、新しいものが下)
- ❌ Phase 8 review entry に「Top N lessons」が無い (review の本質)

## ファイルサイズの目安

| Phase | 累積サイズ目安 |
|-------|--------------|
| Phase 3 後 | 〜200 行 (1 Phase 3 entry + project metadata) |
| Phase 6 後 | 〜500 行 (10-20 run entries 想定) |
| Phase 8 後 | 〜800 行 (Phase 8 review entry 統合後) |

肥大化警告は Phase 8 review で「過去 entry を archive にしますか?」を提示 (将来 feature)。

## 多言語対応

LAB_NOTEBOOK は **日本語 / 英語混在 OK** (科学者の lab notebook 文化に合わせる)。
ただし Phase 6 entry の "Quick" 行は英語推奨 (paper の Limitations 節への流用が容易)。
