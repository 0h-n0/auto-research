#!/usr/bin/env bash
# tests/test_paper_scaffold.sh — research.paper.scaffold (v0.13.0+) の静的チェック
#
# 1. SKILL.md + 6 references files exist
# 2. draft_md_skeleton.md の section header 完全性 (Abstract / Intro / Method / Experiments /
#    Discussion / Limitations / AI Use Disclosure / References)
# 3. abstract_template.md に 4 ブロックマーカー
#    ([Background] / [Method] / [Hypothesis] / [Implication])
# 4. phase_section_map.md に Phase 2/3/4/6/7 行
# 5. introduction_template.md に 3 sub-section header (1.1 Motivation / 1.2 Related Work /
#    1.3 Contributions)
# 6. refs_bib_growth.md に key 命名規則明記 (firstauthor + year + firstword)
# 7. related_work_template.md に "Position of our work" の言及
# 8. responsible_research との連携 (引用 ≤ 2 文ルール) が明記
# 9. paper.draft が DRAFT.md detection を持つ
# 10. auto-research SKILL.md に Phase 2/3/4/6 で paper.scaffold 呼び出し言及
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL_DIR="${ROOT}/skills/research.paper.scaffold"
REFS="${SKILL_DIR}/references"

PASS=0
FAIL=0

# 1. ファイル存在
for f in \
  "${SKILL_DIR}/SKILL.md" \
  "${REFS}/draft_md_skeleton.md" \
  "${REFS}/abstract_template.md" \
  "${REFS}/introduction_template.md" \
  "${REFS}/related_work_template.md" \
  "${REFS}/refs_bib_growth.md" \
  "${REFS}/phase_section_map.md"
do
  if [[ -f "$f" ]]; then
    PASS=$((PASS+1))
  else
    echo "✗ missing: $f" >&2; FAIL=$((FAIL+1))
  fi
done

# 2. draft_md_skeleton.md section headers
SKELETON="${REFS}/draft_md_skeleton.md"
for header in "## Abstract" "## 1. Introduction" "### 1.1 Motivation" \
              "### 1.2 Related Work" "### 1.3 Contributions" \
              "## 2. Method" "## 3. Experiments" "### 3.1 Setup" \
              "### 3.2 Baselines" "### 3.3 Results" \
              "## 4. Discussion" "## 5. Limitations" \
              "## 6. AI Use Disclosure" "## References"
do
  if grep -qF "${header}" "${SKELETON}"; then
    PASS=$((PASS+1))
  else
    echo "✗ draft_md_skeleton.md missing header: ${header}" >&2
    FAIL=$((FAIL+1))
  fi
done

# 3. abstract_template.md の 4 マーカー
ABSTRACT="${REFS}/abstract_template.md"
for marker in "\\[Background\\]" "\\[Method\\]" "\\[Hypothesis" "\\[Implication"; do
  if grep -qE "${marker}" "${ABSTRACT}"; then
    PASS=$((PASS+1))
  else
    echo "✗ abstract_template.md missing marker: ${marker}" >&2
    FAIL=$((FAIL+1))
  fi
done

# 4. phase_section_map.md に Phase 2/3/4/6/7 行
SECTION_MAP="${REFS}/phase_section_map.md"
for phase in 2 3 4 6 7; do
  if grep -qE "Phase ${phase}" "${SECTION_MAP}"; then
    PASS=$((PASS+1))
  else
    echo "✗ phase_section_map.md missing Phase ${phase}" >&2
    FAIL=$((FAIL+1))
  fi
done

# 5. introduction_template.md に 3 sub-section header
INTRO="${REFS}/introduction_template.md"
for sub in "1.1 Motivation" "1.2 Related Work" "1.3 Contributions"; do
  if grep -qF "${sub}" "${INTRO}"; then
    PASS=$((PASS+1))
  else
    echo "✗ introduction_template.md missing: ${sub}" >&2
    FAIL=$((FAIL+1))
  fi
done

# 6. refs_bib_growth.md に key 命名規則
BIB_GROWTH="${REFS}/refs_bib_growth.md"
if grep -qF "first_author_lastname" "${BIB_GROWTH}" && \
   grep -qF "first_word_of_title" "${BIB_GROWTH}"; then
  PASS=$((PASS+1))
else
  echo "✗ refs_bib_growth.md missing bibtex key naming convention" >&2
  FAIL=$((FAIL+1))
fi

# 7. related_work_template.md に Position 言及
RW="${REFS}/related_work_template.md"
if grep -qF "Position of our work" "${RW}"; then
  PASS=$((PASS+1))
else
  echo "✗ related_work_template.md missing 'Position of our work' synthesis" >&2
  FAIL=$((FAIL+1))
fi

# 8. responsible_research との連携 (引用 ≤ 2 文ルール)
if grep -qF "responsible_research" "${SKILL_DIR}/SKILL.md"; then
  PASS=$((PASS+1))
else
  echo "✗ SKILL.md missing responsible_research cross-reference" >&2
  FAIL=$((FAIL+1))
fi

# 9. paper.draft (Phase 7 既存) が DRAFT.md detection を持つ
DRAFT_SKILL="${ROOT}/skills/research.paper.draft/SKILL.md"
if grep -qF "paper/DRAFT.md" "${DRAFT_SKILL}" && \
   grep -qF "v0.13.0" "${DRAFT_SKILL}"; then
  PASS=$((PASS+1))
else
  echo "✗ research.paper.draft/SKILL.md missing v0.13.0+ DRAFT.md detection" >&2
  FAIL=$((FAIL+1))
fi

# 10. auto-research SKILL.md に Phase 2/3/4/6 で paper.scaffold dispatch
AUTO_SKILL="${ROOT}/skills/auto-research/SKILL.md"
SCAFFOLD_REFS=$(grep -c "research.paper.scaffold" "${AUTO_SKILL}" || true)
if [[ ${SCAFFOLD_REFS} -ge 3 ]]; then
  # Expected to appear in Phase 2 / 3 / 4 / 6 sections (≥ 3 mentions for safety)
  PASS=$((PASS+1))
else
  echo "✗ auto-research/SKILL.md does not invoke paper.scaffold across phases (${SCAFFOLD_REFS} mentions)" >&2
  FAIL=$((FAIL+1))
fi

# 11. SKILL.md に Phase 2 が earliest invoke phase であることが明記
if grep -qF "Phase 2 完了" "${SKILL_DIR}/SKILL.md" || grep -qF "Phase 2 後" "${SKILL_DIR}/SKILL.md"; then
  PASS=$((PASS+1))
else
  echo "✗ paper.scaffold SKILL.md does not state Phase 2 as earliest invoke" >&2
  FAIL=$((FAIL+1))
fi

echo "paper_scaffold test: ${PASS} pass / ${FAIL} fail"
[[ ${FAIL} -eq 0 ]] && exit 0 || exit 1
