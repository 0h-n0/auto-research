# ALCOA+ Correction Guideline

紙 lab notebook の伝統的な修正ルール (ALCOA+) を markdown / git workflow に適用するガイドライン。
NIH IRP "Keeping Lab Notebooks: Basic Principles & Best Practices" 由来。

> **原則**: "Correct mistakes, but never remove them. The appropriate way to correct
> a mistake is to strike out the information with a single line and initial by the line."
> — NIH IRP Lab Notebook Best Practices (引用 ≤2 文、`responsible_research.md` 準拠)

## ALCOA+ とは

ELN guidelines で必須とされる data integrity 原則:

- **A**ttributable (誰が記録したか)
- **L**egible (読めるか)
- **C**ontemporaneous (記録時刻と同期しているか)
- **O**riginal (最初の記録か)
- **A**ccurate (正確か)
- **+** Complete / Consistent / Enduring / Available

本ガイドは特に **Original** + **Enduring** に対応 ("間違いを残しつつ訂正する" 文化)。

## 設計方針

- **ガイドラインのみ、強制せず**: lint check で `~~` の出現を許可するだけ
- **markdown + git history で実装**: pure markdown 表記 + git で時系列 backup
- **user manual**: agent dispatch では使わない、user が手書きで適用

## markdown における correction rule

### 1. 削除 (取り消し線)

`~~text~~` で取り消し線 (markdown 標準):

```markdown
The result was ~~3.14~~ (corrected 2026-05-15 by AB).
```

レンダリング: The result was ~~3.14~~ (corrected 2026-05-15 by AB).

### 2. 追加 (新規挿入)

`<ins>text</ins>` で挿入 (HTML、ほとんどの markdown renderer で動作):

```markdown
The corrected value is <ins>2.71</ins>.
```

レンダリング: The corrected value is <ins>2.71</ins>.

### 3. 両方 (置換)

`~~old~~ <ins>new</ins>` で削除と新規挿入を併記:

```markdown
The result was ~~3.14~~ <ins>2.71</ins>. (corrected 2026-05-15 by AB, reason: math error)
```

### 4. 注釈の付与

修正には **理由 + 修正者の initials + 日付** を付ける (ALCOA+ Attributable):

```markdown
~~old value~~ <ins>new value</ins> (corrected YYYY-MM-DD by <initials>, reason: <one-liner>)
```

## Git history との関係

ALCOA+ "Original" / "Permanent" は **git history で担保**:
- `git log` で時系列を遡れる (誰が何を変更したかも commit author で見える)
- `git diff <commit1> <commit2>` で diff
- markdown 上の `~~strike~~` は **可読性** のためのアノテーション (人が読んで時系列把握)

つまり:
- **Git**: 改ざん不可な永続記録 (legal integrity 担保)
- **markdown `~~`**: 人間可読な navigation aid

両者を併用することで paper notebook の伝統と digital advantages を両立。

## 適用範囲

本 guideline は **任意適用**、以下の場面で推奨:

| 場面 | 適用 |
|------|------|
| LAB_NOTEBOOK の手書き correction | ✅ |
| POSTMORTEM の §4 Decision を後日修正 | ✅ |
| 03_REJECTED_IDEAS.md の Future revisit conditions 更新 | ✅ |
| Decision journal Predicted outcome (Phase 3-4) を後で書き換え | ❌ (hindsight bias 防止のため agent-managed marker で保護、書き換えない) |
| 06_RESULTS.md の数値結果 | ❌ (data の事後修正は分析 pipeline で行う) |
| 04_EXPERIMENT_PLAN.md の RQ 変更 | ❌ (CHANGELOG.md の rollback log で別途記録) |

## 例 1: POSTMORTEM の Decision 修正

最初の draft:
```markdown
## 4. Decision
- Action: batch 16 → 8 で再 run
```

後日 (再 run 結果から修正):
```markdown
## 4. Decision
- Action: ~~batch 16 → 8 で再 run~~ <ins>batch 16 → 8 + grad_accum 1 → 2 で
  effective batch 維持して再 run</ins> (corrected 2026-05-16 by AB, reason:
  effective batch size を維持しないと結果不変仮定が崩れる)
```

人が読んでも「最初こう考えたが、後から effective batch 維持の必要性に気づいた」と分かる。
git diff でも自動 trace 可能。

## 例 2: Future revisit conditions 更新

最初:
```markdown
**Future revisit conditions**: もし A が baseline 改善 < 5% なら B を再考
```

後日 (実測から更新):
```markdown
**Future revisit conditions**: もし A が baseline 改善 ~~< 5%~~ <ins>< 3% (実測値踏まえ
threshold 引き下げ)</ins> なら B を再考 (updated 2026-05-20 by AB)
```

## Anti-pattern (NG)

- ❌ 元の text を **削除** (`git rm` も含む) — ALCOA+ Original 違反
- ❌ correction を **コメントアウト** (`<!-- ... -->`) — 可読性低下、navigation aid にならない
- ❌ Decision journal の Predicted outcome を後で書き換え — hindsight bias の温床
- ❌ correction 注釈を省略 (`~~old~~` だけ、理由 / initials / 日付なし) — Attributable 違反
- ❌ 数値結果を `~~strike~~` で表現 — data 修正は分析 pipeline で別途、notebook は思考の trace

## Pre-pattern (OK)

- ✅ 思考の修正 (Decision の action / Lessons の generalize / Future revisit の条件)
- ✅ POSTMORTEM の §5 Lessons を後日 generalize する (専門誌での再現研究結果を踏まえ)
- ✅ rejected idea の reason 強化 (新しい paper で B の弱点が確証された)
- ✅ correction には必ず **理由 + initials + 日付** をセット

## Initials / 表記揺れ防止

複数 contributor がいる project では:
- 各 contributor の initials を `01_BRIEF.md` の Contributors 節に記載
- `~~old~~ <ins>new</ins> (by AB)` の `AB` は Contributors 表と照合
- AI assistant の修正は `(by Claude)` / `(by ChatGPT)` で明示 (LLM 開示)

## 自動 enforcement は不要

`~~strike~~` の使用を強制する lint は **入れない** 方針:
- 強制すると user が correction を避けるようになる
- git history が真の SoT (markdown は人間可読 aid のみ)
- 適用は **教育 + ガイドライン** で十分

## なぜこれが重要か

紙 lab notebook の最大の科学的価値:
1. **改ざん耐性**: 取り消し線で残すことで、後から「最初こう思っていた」の証拠が残る
2. **学習資産**: 後輩研究者が "なぜ修正したか" を読んで学べる
3. **再現性 audit**: peer review / reproducibility check で "事後改変" 疑惑を払拭

markdown + git は **紙の優位性を保ちつつ navigation を強化** する。本 guideline はその橋渡し。

## 関連

- 紙 lab notebook 伝統: NIH IRP "Keeping Lab Notebooks: Basic Principles & Best Practices" (引用元)
- 引用 ≤2 文ルール: `skills/auto-research/references/responsible_research.md`
- Decision journal の Predicted 保護: `decision_journal_template.md` (`~~strike~~` 適用外、agent-managed marker で保護)
- CHANGELOG.md の rollback 記録: `skills/auto-research/SKILL.md` §"失敗モードと回復"

## 参考

NIH Office of Intramural Research (2024). *Keeping Lab Notebooks: Basic Principles & Best Practices*.
https://oir.nih.gov/system/files/media/file/2024-07/best_practices-keeping_eln-pi_0.pdf
(引用 ≤2 文に従う、本ガイドの理論的基盤)
