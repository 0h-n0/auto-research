# Daily Summary Entry template (任意、Light touch)

LAB_NOTEBOOK の event-driven entries (Phase 3 / 4 / 5 / 6 / 8) を補完する **日次 entry** の雛形。
完全フリーフォームではなく、書きやすさのため **4 prompt の Light touch schema** で構造化。

> **目的**: Phase event 駆動だけでは捉えられない「日々の小さな気づき / stuck / 翌日の意図」を
> 記録する。研究の中断・再開時に「昨日どこまで考えたか」が分かる。
> 紙 lab notebook の伝統的な日次記録文化を Light touch で再現。

## 設計方針

- **完全 optional**: 毎日書く必要なし、書きたい日だけ
- **manual invoke**: agent auto-dispatch しない、user が `/auto-research:lessons-search` の用に手動で挿入
- **Light touch 4 prompt**: 完全 freeform でなく書きやすい構造 (decision_journal_template の Light touch 哲学を踏襲)
- **Phase 横断**: Phase 1-8 のいつでも書ける、Phase event entry とは独立

## Template

```markdown
### YYYY-MM-DD [Daily summary]

- **Today's stuck**: <30 分以上 stuck だったこと、1-2 文。無ければ "N/A">
- **Today's insight**: <その日の小さな気づき、1-2 文。無ければ "N/A">
- **Tomorrow's plan**: <翌日着手すること、1 行>
- **Mood / energy** (任意): <1-5 scale or freeform>

Tags: `#daily-summary` <その日の主活動の自由 tag>
```

各 field は **1-2 文** が目安、長くなりそうなら別の Phase event entry を立てる。

## 例

### 進捗良好の日

```markdown
### 2026-05-13 [Daily summary]

- **Today's stuck**: N/A (smooth progress)
- **Today's insight**: r_a3f2 の OOM は activation memory が主因と判明 (batch 8 で再 run pending)
- **Tomorrow's plan**: r_b1c8 (batch 8 + grad_accum 2) 起動、結果出たら Phase 6 metacognition
- **Mood / energy**: 4/5

Tags: `#daily-summary` `#phase-6` `#oom` `#progress`
```

### Stuck の日

```markdown
### 2026-05-15 [Daily summary]

- **Today's stuck**: lm-eval-harness の prompt template が docs 通りに動かない (3h で進展なし)
- **Today's insight**: harness の version 違いで template 構文が変更されている可能性、issue を search 必要
- **Tomorrow's plan**: GitHub Issues 確認 + 別 version で再現試行、ダメなら attention-analyst agent dispatch
- **Mood / energy**: 2/5

Tags: `#daily-summary` `#stuck` `#phase-5`
```

### 思考整理の日 (no implementation)

```markdown
### 2026-05-17 [Daily summary]

- **Today's stuck**: N/A
- **Today's insight**: Phase 6 metacognition で発覚した "3B では decoding が dominant" は
  別 RQ として Phase 4 に戻る価値あり (現プロジェクトの scope 内で実験追加すべきか考え中)
- **Tomorrow's plan**: advisor との 1on1 で scope 拡張 / 別 project 化を相談
- **Mood / energy**: 3/5 (excited about findings, uncertain about path)

Tags: `#daily-summary` `#insight` `#pivot-consideration`
```

## なぜ 4 prompt なのか

完全フリーフォームは:
- 書く敷居が高い (何を書けばいいか分からない)
- 後で読む時 navigation 困難
- 検索 / tag 化しにくい

Light touch 4 prompt は:
- 質問形式で書き始めやすい
- 各 field 1-2 文の制約で書きすぎ防止
- "Today's stuck / insight / plan" の 3 軸で daily 進捗を機械的に追える
- Mood / energy は wellbeing track の試行 (optional)

## Daily entry と Phase event entry の使い分け

| 種類 | 適用場面 |
|------|---------|
| **Daily summary** | 日々の進捗 / stuck / 気づきの蓄積 (Phase event なし) |
| Phase 3 entry (auto) | G2 通過時、idea selection の記録 |
| Phase 4 entry (auto、v0.15.0+) | G3 通過時、実験設計の記録 |
| Phase 5 entry (manual) | TDD Red 30 分 stuck で記録 |
| Phase 6 entry (auto) | run 完了時、success / failed run の記録 |
| Phase 6 metacognition (auto、v0.15.0+) | run 結果 vs 予測の照合 |
| Phase 8 entry (auto) | Review 完了時、top lessons 統合 |

Daily entry は Phase event entry と **重複してもよい** (例: Phase 6 run 完了日に daily summary も)。
独立した粒度: daily は時系列の連続性、event は思考の transition。

## Anti-pattern

- ❌ 毎日強制で書く (任意のはず、書きたくない日は書かない)
- ❌ Phase event entry を Daily entry で代替 (Phase event は別途残す)
- ❌ Today's stuck に "minor confusion" レベルを書く (30 分以上の stuck のみ)
- ❌ Tomorrow's plan に 5 項目以上 (1 行、最重要 1 項目)
- ❌ Mood / energy に詳細を書く (Light touch、1-5 or 1 文)
- ❌ 過去日付の Daily entry を埋める (contemporaneous recording 違反、その日書けなければ skip)

## Phase 8 review との連携

Phase 8 で `08_REVIEW.md` Lessons learned 節を統合する際、lab.notebook は **Daily entries も走査** して generalizable insights を抽出 (v0.16.0+):

- "Today's insight" 列を集約して frequent pattern 検出
- "Today's stuck" 列で stuck pattern 抽出 (どんな状況で stuck しがちか)
- Phase 8 lessons の **micro-level supplement** として活用

## Tag 推奨

Daily entry の tags は以下を推奨:

| tag | 適用 |
|-----|------|
| `#daily-summary` | 必須 (auto-marker) |
| `#stuck` | "Today's stuck" が N/A でない時 |
| `#insight` | "Today's insight" が valuable な時 |
| `#progress` | smooth progress な日 |
| `#pivot-consideration` | scope / direction の再検討 |
| `#peer-discussion` | advisor / collaborator 議論を含む |
| `#phase-N` | その日の主活動が特定 Phase 内 |

自由 tag (project specific、`#llama-3b` 等) も併用可。

## Phase × Phase event との関係

| Phase | event-driven entry | Daily entry |
|-------|-------------------|------------|
| 1 (Brief) | (lab.notebook no-op) | OK (initial thinking 記録) |
| 2 (Survey) | (lab.notebook no-op) | OK (paper-by-paper progress) |
| 3 (Idea) | auto | OK (補完) |
| 4 (Plan) | auto (v0.15.0+) | OK (補完) |
| 5 (TDD) | manual (stuck 30min) | OK (細かい stuck も) |
| 6 (Run) | auto | OK (run 待ち時間) |
| 7 (Paper) | (lab.notebook no-op) | OK (write-up progress) |
| 8 (Review) | auto | OK (review thinking) |

Phase 1 / 2 / 7 (lab.notebook event 不在 Phase) でも Daily entry で notebook 連続性を保てる。

## 関連

- Light touch design philosophy: `decision_journal_template.md`
- Phase event entries: `lab_notebook_skeleton.md`
- Tag taxonomy: `tag_taxonomy.md` (`#daily-summary` は controlled vocabulary に追加要検討、v0.17+)
- Phase 8 review との統合 (将来 feature): `phase_notebook_map.md` § Phase 8
