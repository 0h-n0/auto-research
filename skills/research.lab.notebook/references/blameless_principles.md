# Blameless Postmortem Principles

`research.lab.notebook` の POSTMORTEM / LAB_NOTEBOOK / Lessons DB 全てに適用される **blameless 文化**
の SoT。Google SRE book "Postmortem Culture: Learning from Failure" (Beyer et al., 2016) 由来。

> **核心原則**: POSTMORTEM の目的は、**人を責めることではなく、システム / プロセス / ツール
> の改善** にある。失敗の原因は人ではなく、人が誤りやすい設計を許した仕組みに帰属する。

## なぜ blameless か

非 blameless な postmortem 文化では:
- 人が責められることを恐れて失敗を隠す
- 結果、再発する (システム改善の機会喪失)
- 心理的安全性が下がり、リスキーな試行が減る (科学研究では致命的)

Blameless 文化では:
- 失敗の事実を率直に共有できる
- システム / プロセスの欠陥に注目が向かう
- 同じ失敗が組織として再発しない (institutional memory)

> "We seek to understand the agent's actions in light of the situation rather than punishing those involved."
> — *Site Reliability Engineering* (引用 ≤2 文、`responsible_research.md` 準拠)

## Anti-pattern (NG な書き方)

POSTMORTEM / LAB_NOTEBOOK / Lessons DB の summary で **避けるべき表現**:

| Anti-pattern | 例 | なぜ NG |
|--------------|-----|---------|
| 人を主語にした失敗帰属 | "X さんが Y を間違えた" | 個人攻撃、システム改善に繋がらない |
| 後知恵 (hindsight) | "should have known", "should have caught" | 当時の情報での判断を不当に低く評価 |
| 自明性の主張 | "obvious mistake", "trivial bug" | 防げなかった理由 (システム欠陥) を見落とす |
| 責任者特定 | "誰が責任者か" | blame culture を強化、防御的になる |
| 道徳的非難 | "lazy", "careless", "incompetent" | 人格攻撃、信頼関係を破壊 |
| 受動的諦め | "なるべくしてなった" | システム改善の意欲を削ぐ |

## Pre-pattern (推奨される書き方)

| Pre-pattern | 例 | なぜ良い |
|-------------|-----|---------|
| システム / プロセスを主語に | "the system allowed Y to happen unnoticed" | 改善対象 (system) が明確 |
| プロセス欠陥の指摘 | "the process did not catch Y at review time" | プロセス改善の hint |
| 検証不足の認識 | "Y was not validated by any test" | test 追加で再発防止 |
| 文脈考慮 | "with hindsight, Y was a reasonable interpretation given the available info" | 公正な評価 |
| 構造的制約 | "the tool's UI made Z error-prone" | tool 改善の方向 |
| 学習指向 | "we learned that A → B; next time we will check C" | 前向き、generalizable |

## 適用範囲

本 principles は以下に適用される:

1. **POSTMORTEM.md** (Phase 6) — 冒頭 callout で参照
2. **LAB_NOTEBOOK.md** の Phase 6 metacognition entry — "What I missed" 節
3. **Lessons DB** (`~/.research-lessons.json`) の `summary` field
4. **08_REVIEW.md** (Phase 8) — Lessons learned 節
5. **03_REJECTED_IDEAS.md** の "Why rejected" 節 (idea を選ばなかった理由が blameless)

## 例: blameless 書き換え

### POSTMORTEM §4 Decision

❌ Bad:
```markdown
## 4. Decision
- Action: 私は最初から batch=8 にすべきだった、明らかなミス。
```

✅ Good:
```markdown
## 4. Decision
- Action: batch 16 → 8、grad_accum 1 → 2 で effective batch 維持
- Why: H1 (memory 不足) が最有力、effective batch 維持で結果不変仮定
- システム改善: Phase 4 設計時に GPU memory budget の事前計算を強制 (将来 feature)
```

### POSTMORTEM §5 Lessons

❌ Bad:
```markdown
## 5. Lessons & generalizable insight
- 注意不足だった、次は気をつける。
```

✅ Good:
```markdown
## 5. Lessons & generalizable insight
- 3B model + 4096 seq_len + batch 16 で activation memory が 40GB GPU を超えるパターンを検出
- Future check: Phase 4 で `compute_budget_calculator(model_params, seq_len, batch)` を導入
  すべき (現状 manual estimate に依存)
- Generalizable insight: small model でも seq_len と batch の積が dominant memory factor
```

### Phase 6 metacognition "What I missed"

❌ Bad:
```markdown
**What I missed**: 私は format dominance を信じすぎた、思い込みだった。
```

✅ Good:
```markdown
**What I missed**: format dominance 仮定 (Phase 3 assumption #2) は、prior work 5 本の
平均改善が +2.5pp という根拠で reasonable だったが、3B model でのみ decoding setting が
prevailing とわかった。assumption #2 は 7B+ では成立する (PARTIALLY CONFIRMED)。
将来の Phase 3 では model size dimension を assumption に含めるべき。
```

## Blameless ≠ Responsibility-free ではない

Blameless は **責任不在** ではない。明示すべきは:
- **Process owner**: 「このプロセスを改善する責任は誰か」
- **Action item assignee**: 「次の action を誰が実施するか」
- **Timeline**: 「いつまでに改善するか」

これは team の accountability であり、個人の blame ではない。

## Self-blame も避ける

研究者個人の lab notebook であっても、**self-blame 表現を避ける**:

❌ "I was stupid", "I should have known", "I'm bad at X"
✅ "the available information at the time supported decision X; with the new data
    point Y, the picture changes"

self-blame は productivity を下げ、risk-taking を抑制する。本 principles は team / org
のみならず、自己反省 (Phase 8 review) にも適用。

## Blameless callout (POSTMORTEM 冒頭)

POSTMORTEM template の冒頭に強制挿入される callout:

```markdown
> **Blameless principle**: 失敗の原因はシステム / プロセス / ツールに帰属する。
> 個人の判断は「その判断時に得られた情報で reasonable だったか」の文脈で記述。
> 詳細: `skills/research.lab.notebook/references/blameless_principles.md`
```

callout を user が削除しても、再 invoke で復活 (agent-managed marker で hard-coded)。

## 自動 enforcement の限界

自然言語の blame check は LLM が必要 (regex では不十分)。v0.15.0 では:
- guideline + anti-pattern 例で start
- agent draft 時に上記 anti-pattern を avoid (system prompt 等で強制)
- user polish 時に anti-pattern が混入しても warning なし (現状)

将来 (v0.17+) で:
- LLM-based blame language detector を Phase 8 review で適用
- POSTMORTEM の §4 / §5 を自動 review、blame language flagging

## 適用しない場合 (例外)

以下のケースで blameless が不適切な場合がある (本 plugin の scope 外):
- 法的 / 規制 compliance の調査 (responsibility 特定が要件)
- Misconduct investigation (data fabrication、plagiarism)
- 重大なセキュリティ違反 (PII 漏洩、credential 流出)

これらは人事 / legal の領域、本 skill では扱わない。

## 関連

- POSTMORTEM 冒頭 callout: `postmortem_template.md`
- 引用ルール ≤2 文: `skills/auto-research/references/responsible_research.md`
- LAB_NOTEBOOK の "What I missed" 節: `decision_journal_template.md`
- Lessons DB summary: `lessons_db_schema.md`

## 参考

Beyer, B. et al. (2016). *Site Reliability Engineering: How Google Runs Production Systems*.
Chapter "Postmortem Culture: Learning from Failure". O'Reilly.
(引用 ≤2 文に従う。本書は本 principles の理論的基盤)
