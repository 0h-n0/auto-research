# 03_REJECTED_IDEAS.md template

`research.lab.notebook` が `.research/<slug>/03_REJECTED_IDEAS.md` を生成 / 追記するときの SoT。

> Phase 3 G2 で選ばれなかった idea も **完全な形で残す**。
> 「合わない」と短く片付けず、reason + future revisit conditions まで記録することで、
> 将来の pivot / 比較研究で再考できるようにする。

## 雛形全文

```markdown
# Rejected Ideas — <slug>

<!-- agent-managed:Phase=3 -->

> Phase 3 G2 で adopted されなかった idea を保存する stash。
> 各 idea は full body (03_IDEAS.md と同 schema) + rejection reason + future revisit conditions を持つ。
> 将来の pivot / 比較研究 / "alternative approach" 議論で再考可能。

---

## Adopted (reference, not rejected)

- **A**: <title> — selected at Phase 3 G2 (2026-05-11)
  - See `03_IDEAS.md` for full body
  - Core hypothesis: <H1>

---

## Rejected ideas

### B. <Idea title>

**Status**: rejected at Phase 3 G2 (2026-05-11)

**Core hypothesis**: <full hypothesis statement, falsifiable claim>

**Approach summary**: <1-3 sentence、何をするか>

**Why considered**: <なぜ candidates に上がったか、03_GAP_ANALYSIS の seed 情報>

**Why rejected**:
- <reason 1: e.g., "compute budget 不足。GPU 4×A100 が要件、本プロジェクトは 1×A100">
- <reason 2: e.g., "MATRIX.md の prior work と差分が小さい (Hong+24 と 80% overlap)">
- <reason 3: 任意>

**Comparison vs adopted (A)**:
- A の方が <strength of A>
- B の弱み: <weakness of B>

**Future revisit conditions**:
- 例: "もし A が baseline 改善 < 5% なら B の direction を再考"
- 例: "compute budget が増えたら (4×A100 確保できれば) B を実装"
- 例: "別 project (cross-domain) で B 単体を検証する価値あり"

**Related papers**: <MATRIX.md row pointers、e.g., `02_SURVEY/MATRIX.md#paper-2403-07974`>

**Resources to keep**:
- 検討時の note: `02_SURVEY/notes/<related_paper_id>.md`
- (任意) draft 実装: `code/experimental/idea_B/` (もし試作したなら)

---

### C. <Idea title>

**Status**: rejected at Phase 3 G2 (2026-05-11)

(同じ schema)

---

## Pivot history (任意)

> Project の途中で adopted idea が rejected idea に置き換わった場合の記録。

### 2026-05-15: A → B pivot

**Trigger**: <例: "A の baseline 改善が 2% でも threshold (5%) 未達。Phase 8 G4 で reviewer 指摘">

**Decision**: A を archive、B を new adopted として Phase 4 から再 start

**What carries over from A**:
- Survey results (02_SURVEY/MATRIX.md は流用)
- Some baselines (code/baselines/ の一部)

**What is reset**:
- 03_IDEAS.md (A → B に書き換え、A は本ファイルに移動)
- 04_EXPERIMENT_PLAN.md (B 用に書き直し)
```

## 必須節 (lint check)

各 rejected idea に以下の見出しが揃っているか確認:

1. `**Status**: rejected at Phase N (date)`
2. `**Core hypothesis**:`
3. `**Why rejected**:`
4. `**Future revisit conditions**:`

## 動作 (research.lab.notebook が自動生成)

Phase 3 G2 通過時 (`STATE.json.G2 = pass`) に invoke:

1. `03_IDEAS.md` を読み、adopted idea (1 つ) と rejected ideas (0 個以上) を分離
2. `03_REJECTED_IDEAS.md` 既存なら append、無ければ skeleton から生成
3. 各 rejected idea について:
   - 03_IDEAS.md の full body をコピー (要約しない)
   - "Why rejected" は user に問い、不明なら `<TODO: reason>` placeholder
   - "Future revisit conditions" も user 入力推奨、不明なら `<TODO: revisit conditions>`
4. LAB_NOTEBOOK.md に Phase 3 entry を追加 (rejected idea のサマリと link)

## Idempotency

- 同じ idea ID (B / C) が既に `03_REJECTED_IDEAS.md` にあれば skip + log
- agent-managed marker (`<!-- agent-managed:Phase=3 -->`) を user が削除していれば全体保護モード
- 個別 rejected idea section の本文を user 編集していれば該当 section のみ保護

## Pivot 時の挙動

Phase 4+ で adopted idea を pivot する場合:
1. 元 adopted (A) を本ファイルの "Rejected ideas" 節に move
2. 新 adopted (B) を `03_IDEAS.md` に書き、本ファイルの B section から remove
3. "Pivot history" 節に move 記録を追加
4. LAB_NOTEBOOK.md にも Pivot entry

## Anti-patterns

- ❌ rejected idea を 1 行 ("B: 合わなかった") で済ます
- ❌ "Future revisit conditions" を空欄 (再考トリガが消える)
- ❌ "Why rejected" に "A の方が良いから" としか書かない (具体的な比較が必要)
- ❌ pivot 時に元 adopted を削除 (history が消える、本ファイルに必ず move)
- ❌ rejected idea の draft 実装 (code) を `code/experimental/` から消す (将来再考時に資産)

## 肥大化対策

100 idea が rejected されるような長期 project では本ファイルが 1000+ 行になる。対策:
- "Future revisit conditions" を必須にすることで自然な絞り込み (条件不明なら本当に捨てる候補)
- Phase 8 review で "archive されるべき rejected idea" を user に聞く (将来 v0.15+ feature)
- search 用に各 idea section の anchor (`#B`, `#C`) を一定 (renumber しない)

## ファイル構造の SemVer

`03_REJECTED_IDEAS.md` は `.research/<slug>/` 直下、Phase 3 で生成、Phase 8 まで持続。
v0.14.0 で導入、後方互換 (本ファイルが無くても Phase 1-8 動作)。

## 関連

- 元 schema: `skills/auto-research/references/file_schemas.md` (03_IDEAS.md schema を流用)
- LAB_NOTEBOOK の Phase 3 entry: `lab_notebook_skeleton.md` § Phase 3 entry
- Phase 8 で archive 候補を提示: `skills/research-gap-finder/SKILL.md` reviewer mode (将来)
