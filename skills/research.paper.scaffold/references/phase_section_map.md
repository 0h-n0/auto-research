# Phase × Section 充足表 (SoT)

`research.paper.scaffold` の運用 SoT。各 Phase 完了時にどの section を書く / refine / touch しないかの mapping。

## 表

| Phase done | Abstract | Intro 1.1 Motivation | Intro 1.2 Related Work | Intro 1.3 Contributions | §2 Method | §3.1 Setup | §3.2 Baselines | §3.3 Results | §4 Discussion | §5 Limitations | refs.bib | 充足度 |
|-----------|----------|---------------------|----------------------|------------------------|-----------|-----------|----------------|--------------|---------------|----------------|----------|--------|
| Phase 1 (Brief 完成) | (本 skill 未 invoke) | | | | | | | | | | | 0% |
| Phase 2 (Survey 完成) | [Background] + [Implication] (placeholder) | ✓ 書く | ✓ 書く | TBD | TBD | TBD | TBD | TBD | TBD | TBD | ✓ 最小 entry | **55%** |
| Phase 3 (Idea 採択 G2) | + [Method] + [Hypothesis] | (touch しない) | (touch しない) | ✓ 書く | TBD | TBD | TBD | TBD | TBD | TBD | (新規 paper があれば追加) | **70%** |
| Phase 4 (Plan G3) | (touch しない) | (touch しない) | (touch しない) | (touch しない) | ✓ 書く | ✓ 書く | ✓ 書く | TBD | TBD | TBD | (同上) | **85%** |
| Phase 6 (Run 完了) | [Hypothesis] → [Result] 置換 | (touch しない) | (touch しない) | (touch しない) | (touch しない) | (touch しない) | (touch しない) | ✓ preliminary 書く | TBD | TBD | (同上) | **95%** |
| Phase 7 (paper.draft) | flatten + polish | polish | polish + reorder | refine | polish + 用語統一 | polish | polish | finalize + 統計検定 format | ✓ 書く | ✓ 書く | DOI 補完 | **100%** |

## 各 Phase の動作

### Phase 2: 初回 scaffold (重要)

**入力**:
- `01_BRIEF.md`
- `02_SURVEY/MATRIX.md`
- `02_SURVEY/papers.jsonl`
- `02_SURVEY/notes/*.md`

**出力**:
- `paper/DRAFT.md` 新規作成 (`draft_md_skeleton.md` 雛形 → 部分埋め)
- `paper/refs.bib` 新規作成 (`refs_bib_growth.md` Phase 2 最小 entry)

**書く section**:
- `## Abstract` の `[Background]` (BRIEF.md `Motivation` から 2-3 文)
- `## Abstract` の `[Implication]` (BRIEF.md `Success Criteria` から、placeholder 暫定)
- `### 1.1 Motivation` (BRIEF.md + MATRIX.md カバレッジから 4 段落)
- `### 1.2 Related Work` (`related_work_template.md` 仕様)
- `## 6. AI Use Disclosure` (固定文言)
- `## References` link to refs.bib

**TBD で残す**:
- `[Method]`, `[Hypothesis]` (`<!-- filled at Phase 3 -->` コメント)
- `### 1.3 Contributions` (`<!-- filled at Phase 3 -->`)
- `## 2. Method` (`<!-- filled at Phase 4 -->`)
- `### 3.1 Setup` / `### 3.2 Baselines` (`<!-- filled at Phase 4 -->`)
- `### 3.3 Results` (`<!-- filled at Phase 6 -->`)
- `## 4. Discussion` / `## 5. Limitations` (`<!-- filled at Phase 7 -->`)

### Phase 3: Contribution + Method/Hypothesis

**入力**: `03_IDEAS.md` の `STATE.json.adopted_idea_id`

**書く section**:
- `## Abstract` の `[Method]` (採択 idea の `Proposed experiment` から 3-5 文)
- `## Abstract` の `[Hypothesis (Phase 6 で検証予定)]` (採択 idea の `Core hypothesis` から)
- `### 1.3 Contributions` (3-4 bullet、各 hypothesis 紐付け)

**Touch しない**:
- `### 1.1 Motivation` (Phase 2 で書いた、人手 polish 尊重)
- `### 1.2 Related Work` (同上)

### Phase 4: Method / Setup / Baselines

**入力**: `04_EXPERIMENT_PLAN.md`

**書く section**:
- `## 2. Method` (RQ → Hypotheses → Factor Matrix → primary/sanity metric → statistical test)
- `### 3.1 Setup` (datasets / models / decoding / prompt template / compute budget)
- `### 3.2 Baselines` (baseline list with refs)

**任意 refine**: `## Abstract` の `[Method]` を more specific に refine 可能 (人手判断)

### Phase 6: Results (preliminary)

**入力**: `06_RESULTS.md`, `06_RUNS/*/metrics.json`

**書く section**:
- `### 3.3 Results` (main table + figures linked from `06_RUNS/figures/`)
- `## Abstract` の `[Hypothesis (Phase 6 で検証予定)]` を `[Result]` に置換 (実測値 + 統計検定)

**TBD のまま**: `## 4. Discussion` / `## 5. Limitations` (Phase 7 で paper.draft が書く)

### Phase 7: paper.draft が引き継ぐ

paper.scaffold は **invoke しない**。代わりに `research.paper.draft` (既存 v0.1.0+) が:

1. `paper/DRAFT.md` を read
2. `paper/sections/` に分割 (各 section file)
3. 章ごと並列ドラフト (Discussion / Limitations を新規執筆、他は polish)
4. 用語統合パス
5. `paper/refs.bib` を Semantic Scholar MCP で DOI 補完
6. `paper_format` (`latex-neurips` / `latex-acl` / `markdown`) に従い LaTeX 化
7. AI Use Disclosure 節を必ず include

## 充足度の計算

paper.scaffold は次の式で充足度を算出し、next-step trailer に表示:

```
filled_sections = ["Abstract: Background", "Abstract: Implication", "Abstract: Method",
                   "Abstract: Hypothesis_or_Result", "1.1 Motivation", "1.2 Related Work",
                   "1.3 Contributions", "2 Method", "3.1 Setup", "3.2 Baselines",
                   "3.3 Results", "4 Discussion", "5 Limitations"]   # 13 items

current_filled = N (current_phase に応じて、上記表より)

fill_rate = current_filled / 13 * 100%
```

| Phase | filled count | rate |
|-------|--------------|------|
| 2 | 6 (BG + Imp + 1.1 + 1.2 + AI Disclosure + Refs link) | 55% (実質 7/13) |
| 3 | 9 | 70% |
| 4 | 11 | 85% |
| 6 | 12 | 95% |
| 7 | 13 | 100% |

## 安全機構: agent-managed marker

各 section の冒頭に `<!-- agent-managed:Phase=N -->` を入れる。

- 再 invoke 時、既存 marker `Phase=2` の section は Phase 2 段階の内容として保持
- Phase 3 以降で同 section を refine する場合、marker を更新
- 人手で marker を **削除** された場合は「user editing」とみなし skip + warning

## 関連

- 親 SKILL: `skills/research.paper.scaffold/SKILL.md`
- 雛形: `references/draft_md_skeleton.md`
- Abstract 仕様: `references/abstract_template.md`
- Intro 仕様: `references/introduction_template.md`
- Related Work: `references/related_work_template.md`
- bibtex: `references/refs_bib_growth.md`
- 連携先 Phase 7: `skills/research.paper.draft/SKILL.md`
