# {title}

**Authors:** {authors}
**Affiliation:** {affiliation}
**Contact:** {email}

## Abstract

{200-250 words. Structured: motivation → method → key result → implication.}

## 1. Introduction

{Motivation, contributions (3-4 bullets), research questions (RQ1, RQ2, ...).}

## 2. Related Work

{From 02_SURVEY/MATRIX.md. Group by sub-area, contrast with ours in 1-2 sentences.}

## 3. Method

{From 04_EXPERIMENT_PLAN.md. Notation, key equations, algorithmic description.}

## 4. Experiments

### 4.1 Setup
- Datasets: {table}
- Models: {table}
- Metrics: {primary + secondary}
- Statistical test: {paired bootstrap, B=10000, etc.}

### 4.2 Baselines
{Description and pointers to references.}

### 4.3 Ablation Matrix
{Factors and levels, recreated from 04_EXPERIMENT_PLAN.md}

## 5. Results

{From 06_RESULTS.md. Main table + per-factor figures.}

## 6. Discussion

{3 key findings, alternative explanations considered, scope of conclusions.}

## 7. Limitations

- Compute scope: {GPU-h, models tried}
- Generalization: {to other languages / domains / tasks}
- Threats to validity: {selection bias, evaluation set choice}

## 8. AI Use Disclosure

This work used Claude (Anthropic, model: claude-opus-4-7) for:
- (1) literature triage and gap analysis (Phases 2-3)
- (2) ablation design (Phase 4)
- (3) section drafting (Phase 7)
- (4) self-review (Phase 8)

All experimental results, statistical claims, and the final theoretical contribution were verified manually by the human author(s). The authors take full responsibility for the correctness of the work.

## References

{See `refs.bib`.}
