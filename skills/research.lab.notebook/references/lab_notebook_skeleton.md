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
```

### 2. Phase 5 entry (TDD Red、manual invoke、任意)

```markdown
### 2026-05-12 [Phase 5 TDD Red] <test failure 1-line summary>

- **Test**: `<file>::<test_name>`
- **Failure**: <error message 1-2 行>
- **Hypothesis**: <なぜ失敗したと考えたか、1 文>
- **Verified by**: <green にした方法、1 文>
- **Lesson**: <一般化可能な学び、1-2 文>
- **Stuck duration**: <分単位、目安>
```

### 3. Phase 6 entry (run 完了時、auto-dispatch)

成功 run:
```markdown
### 2026-05-13 [Phase 6 RUN] r_b1c8 SUCCESS — val_loss 2.13 (target 2.20 ✓)

- **Config**: `06_RUNS/r_b1c8/config.yaml`
- **Key insight**: <results.md ハイライト 1-2 文>
- **Builds on**: <prior failed run があれば: r_a3f2 の hypothesis 確認>
```

失敗 run:
```markdown
### 2026-05-13 [Phase 6 RUN] r_a3f2 FAILED — OOM at step 1240

→ See [POSTMORTEM](06_RUNS/r_a3f2/POSTMORTEM.md) for hypothesis space + decision
**Quick**: batch 16 で OOM 推定。次 r_b1c8 で batch 8 + grad_accum 2 を試す。
**Reproduce**: `bash 06_RUNS/r_a3f2/reproduce.sh`
```

### 4. Phase 8 entry (Review 完了時、auto-dispatch)

```markdown
### 2026-05-14 [Phase 8 G4] Review summary — top 3 lessons

1. **Lesson 1**: <generalizable insight、1-2 文>
   (sourced from r_a3f2 POSTMORTEM §5)
2. **Lesson 2**: <...>
3. **Lesson 3**: <...>

**Cross-link**: [`08_REVIEW.md`](08_REVIEW.md) に統合済み
**Future revisit**: `03_REJECTED_IDEAS.md` で B / C が将来 candidate (条件: <...>)
```

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
