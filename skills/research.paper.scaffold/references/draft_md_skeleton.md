# {title from BRIEF.md or "TBD: working title for <slug>"}

<!-- auto-research scaffold v0.13.0+ — paper-first methodology -->
<!-- This file is a living document. paper.scaffold updates it incrementally each Phase. -->
<!-- Do not delete the agent-managed markers below unless you intend to take over manually. -->

## Abstract

<!-- agent-managed:Phase=2 (will refine through Phase 6) -->

**[Background]** *(filled at Phase 2 from 01_BRIEF.md motivation; refined at Phase 3 with adopted Idea)*

**[Method]** *(filled at Phase 3 from adopted Idea; refined at Phase 4 with experimental specifics)*

**[Hypothesis (Phase 6 で検証予定)]** *(filled at Phase 3 from Idea's falsifiable hypothesis; replaced by [Result] after Phase 6)*

**[Implication (検証成立時)]** *(filled at Phase 2 from BRIEF success_criteria; refined at Phase 3-7)*

---

## 1. Introduction

### 1.1 Motivation

<!-- agent-managed:Phase=2 -->
*(filled at Phase 2 from 01_BRIEF.md motivation paragraph)*

### 1.2 Related Work

<!-- agent-managed:Phase=2 -->
*(filled at Phase 2 from 02_SURVEY/MATRIX.md, grouped by sub-area, with inline \cite{} citations to refs.bib)*

### 1.3 Contributions

<!-- agent-managed:Phase=3 (filled at Phase 3 from adopted Idea in 03_IDEAS.md) -->
*(filled at Phase 3 — 3-4 bullet points, each tied to a hypothesis H1, H2, ...)*

---

## 2. Method

<!-- agent-managed:Phase=4 (filled at Phase 4 from 04_EXPERIMENT_PLAN.md) -->
*(filled at Phase 4 — RQ → hypotheses → factor matrix → primary/sanity metric → statistical test)*

---

## 3. Experiments

### 3.1 Setup

<!-- agent-managed:Phase=4 -->
*(filled at Phase 4 — datasets, models, decoding, prompt template, computational budget)*

### 3.2 Baselines

<!-- agent-managed:Phase=4 -->
*(filled at Phase 4 — baseline list with brief description and references to refs.bib)*

### 3.3 Results

<!-- agent-managed:Phase=6 (filled at Phase 6 from 06_RESULTS.md, preliminary; finalized at Phase 7) -->
*(filled at Phase 6 — main table with mean ± 95% CI, p-values, effect sizes; figures linked from 06_RUNS/figures/)*

---

## 4. Discussion

<!-- agent-managed:Phase=7 -->
*(filled at Phase 7 — 3 key findings, alternative explanations considered, scope of conclusions)*

---

## 5. Limitations

<!-- agent-managed:Phase=7 -->
*(filled at Phase 7 — compute scope, generalization, threats to validity)*

---

## 6. AI Use Disclosure

This work used Claude (Anthropic) and the auto-research plugin (`research.paper.scaffold` from
v0.13.0+, `research.paper.draft` from v0.1.0+) for:

- (1) literature triage and gap analysis (Phases 2-3)
- (2) ablation design (Phase 4)
- (3) section drafting and citation organization (Phases 2-7)
- (4) self-review (Phase 8)

All experimental results, statistical claims, and the final theoretical contribution were verified
manually by the human author(s). The authors take full responsibility for the correctness of the
work and the appropriateness of the cited related work.

---

## References

See `paper/refs.bib`. The bibliography is built incrementally:

- **Phase 2** (paper.scaffold initial): minimal bibtex from `02_SURVEY/papers.jsonl` (author / title / year / arXiv eprint).
- **Phase 7** (paper.draft polish): venue / DOI / pages completed via Semantic Scholar MCP (auto-research v0.4.0+).

Citation key convention: `{first_author_lastname}{year}{first_word_of_title_lowercase}`.

---

## Phase Progression Tracker

<!-- This block is updated by paper.scaffold each invocation. Do not edit manually. -->
<!-- agent-managed:tracker -->

- Last paper.scaffold run: *(timestamp)*
- Project current_phase: *(N from STATE.json)*
- DRAFT.md fill rate: *(percentage based on phase_section_map.md)*
- Next section to fill: *(filled at Phase X)*

---

*— end of DRAFT.md skeleton —*
