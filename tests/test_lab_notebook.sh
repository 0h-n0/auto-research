#!/usr/bin/env bash
# tests/test_lab_notebook.sh — research.lab.notebook (v0.14.0+) の静的チェック
#
# 1. SKILL.md + 6 references files exist
# 2. postmortem_template.md に 6 必須節
#    (1. What attempted / 2. What happened / 3. Hypothesis space / 4. Decision /
#     5. Lessons / 6. Reproducing this failure)
# 3. lab_notebook_skeleton.md に Phase 3/5/6/8 entry の例が含まれる
# 4. failure_reproducibility_checklist.md に 7-tuple 全項目
#    (Code rev / Config / Dependencies / Random seed / Data version / Hardware / Reproduce command)
#    (Phase 4 の broad reproducibility_checklist.md とは別物)
# 5. hypothesis_table_rules.md に LIKELY / UNLIKELY / RULED OUT の 3 verdict
#    かつ最低 5 つの error pattern → H mapping
# 6. phase_notebook_map.md に Phase 3/5/6/8 行
# 7. rejected_ideas_template.md に必須節 (Status / Core hypothesis / Why rejected /
#    Future revisit conditions)
# 8. SKILL.md に reproduce.sh の `set -euo pipefail` 言及
# 9. auto-research SKILL.md の Phase 3/6/8 で lab.notebook が dispatch される
# 10. research.experiment.run SKILL.md に reproduce.sh + uv.lock + lab.notebook の言及
# 11. agent-managed marker 言及 (人手編集保護、paper.scaffold v0.13.0 と同 pattern)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL_DIR="${ROOT}/skills/research.lab.notebook"
REFS="${SKILL_DIR}/references"
AUTO_SKILL="${ROOT}/skills/auto-research/SKILL.md"
RUN_SKILL="${ROOT}/skills/research.experiment.run/SKILL.md"
TRAILER_REF="${ROOT}/skills/auto-research/references/next_steps_template.md"

PASS=0
FAIL=0

# 1. ファイル存在
for f in \
  "${SKILL_DIR}/SKILL.md" \
  "${REFS}/lab_notebook_skeleton.md" \
  "${REFS}/postmortem_template.md" \
  "${REFS}/hypothesis_table_rules.md" \
  "${REFS}/failure_reproducibility_checklist.md" \
  "${REFS}/rejected_ideas_template.md" \
  "${REFS}/phase_notebook_map.md"
do
  if [[ -f "$f" ]]; then
    PASS=$((PASS+1))
  else
    echo "✗ missing: $f" >&2; FAIL=$((FAIL+1))
  fi
done

# 2. postmortem_template.md の 6 必須節
PM="${REFS}/postmortem_template.md"
for header in "## 1. What was attempted" \
              "## 2. What happened" \
              "## 3. Hypothesis space" \
              "## 4. Decision" \
              "## 5. Lessons" \
              "## 6. Reproducing this failure"
do
  if grep -qF "${header}" "${PM}"; then
    PASS=$((PASS+1))
  else
    echo "✗ postmortem_template.md missing required section: ${header}" >&2
    FAIL=$((FAIL+1))
  fi
done

# 3. lab_notebook_skeleton.md の Phase entry 例
SKEL="${REFS}/lab_notebook_skeleton.md"
for phase_marker in "Phase 3" "Phase 5" "Phase 6" "Phase 8"
do
  if grep -qF "${phase_marker}" "${SKEL}"; then
    PASS=$((PASS+1))
  else
    echo "✗ lab_notebook_skeleton.md missing entry example for: ${phase_marker}" >&2
    FAIL=$((FAIL+1))
  fi
done

# 4. failure_reproducibility_checklist.md の 7-tuple
CHECKLIST="${REFS}/failure_reproducibility_checklist.md"
for item in "Code rev" "Config" "Dependencies" "Random seed" \
            "Data version" "Hardware" "Reproduce command"
do
  if grep -qF "${item}" "${CHECKLIST}"; then
    PASS=$((PASS+1))
  else
    echo "✗ failure_reproducibility_checklist.md missing 7-tuple item: ${item}" >&2
    FAIL=$((FAIL+1))
  fi
done

# 4.5. failure_reproducibility_checklist.md に set -euo pipefail 言及
if grep -qF 'set -euo pipefail' "${CHECKLIST}"; then
  PASS=$((PASS+1))
else
  echo "✗ failure_reproducibility_checklist.md missing 'set -euo pipefail' requirement" >&2
  FAIL=$((FAIL+1))
fi

# 5. hypothesis_table_rules.md の 3 verdict
RULES="${REFS}/hypothesis_table_rules.md"
for verdict in "LIKELY" "UNLIKELY" "RULED OUT"
do
  if grep -qF "${verdict}" "${RULES}"; then
    PASS=$((PASS+1))
  else
    echo "✗ hypothesis_table_rules.md missing verdict: ${verdict}" >&2
    FAIL=$((FAIL+1))
  fi
done

# 5.5. hypothesis_table_rules.md に最低 5 つの error pattern → H mapping
# pattern として OutOfMemoryError / NaN / AssertionError / timeout / ImportError を確認
for pattern in "OutOfMemoryError" "NaN" "AssertionError" "timeout" "ImportError"
do
  if grep -qF "${pattern}" "${RULES}"; then
    PASS=$((PASS+1))
  else
    echo "✗ hypothesis_table_rules.md missing error pattern: ${pattern}" >&2
    FAIL=$((FAIL+1))
  fi
done

# 6. phase_notebook_map.md に Phase 3/5/6/8 行
MAP="${REFS}/phase_notebook_map.md"
for phase in "Phase 3" "Phase 5" "Phase 6" "Phase 8"
do
  # マッピング表の行として | Phase N | のような形式 or "Phase N" 言及があるか
  if grep -qE "Phase ${phase##* }" "${MAP}"; then
    PASS=$((PASS+1))
  else
    echo "✗ phase_notebook_map.md missing row for ${phase}" >&2
    FAIL=$((FAIL+1))
  fi
done

# 7. rejected_ideas_template.md の必須節
REJ="${REFS}/rejected_ideas_template.md"
for marker in "Status" "Core hypothesis" "Why rejected" "Future revisit conditions"
do
  if grep -qF "${marker}" "${REJ}"; then
    PASS=$((PASS+1))
  else
    echo "✗ rejected_ideas_template.md missing required marker: ${marker}" >&2
    FAIL=$((FAIL+1))
  fi
done

# 8. SKILL.md の reproduce.sh + set -euo pipefail 言及
SKILL_MD="${SKILL_DIR}/SKILL.md"
if grep -qF 'set -euo pipefail' "${SKILL_MD}"; then
  PASS=$((PASS+1))
else
  echo "✗ SKILL.md missing 'set -euo pipefail' requirement for reproduce.sh" >&2
  FAIL=$((FAIL+1))
fi

# 9. auto-research SKILL.md の Phase 3/6/8 で lab.notebook dispatch
for context in "3.5 Lab notebook" "6.5 失敗 run" "8.1.5 Lessons 統合"
do
  if grep -qF "${context}" "${AUTO_SKILL}"; then
    PASS=$((PASS+1))
  else
    echo "✗ auto-research SKILL.md missing dispatch section: ${context}" >&2
    FAIL=$((FAIL+1))
  fi
done

# 9.5. auto-research SKILL.md に research.lab.notebook 言及 (3 dispatch points)
notebook_count=$(grep -cF 'research.lab.notebook' "${AUTO_SKILL}" || true)
if (( notebook_count >= 3 )); then
  PASS=$((PASS+1))
else
  echo "✗ auto-research SKILL.md should reference research.lab.notebook ≥3 times, got ${notebook_count}" >&2
  FAIL=$((FAIL+1))
fi

# 10. research.experiment.run SKILL.md に reproduce.sh + uv.lock + lab.notebook 言及
for ref in "reproduce.sh" "uv.lock" "research.lab.notebook"
do
  if grep -qF "${ref}" "${RUN_SKILL}"; then
    PASS=$((PASS+1))
  else
    echo "✗ research.experiment.run SKILL.md missing reference: ${ref}" >&2
    FAIL=$((FAIL+1))
  fi
done

# 11. agent-managed marker 言及 (paper.scaffold v0.13.0 と同 pattern)
if grep -qF 'agent-managed' "${SKILL_MD}"; then
  PASS=$((PASS+1))
else
  echo "✗ SKILL.md missing 'agent-managed' marker reference" >&2
  FAIL=$((FAIL+1))
fi

# 12. trailer template に Phase 6 failed の lab.notebook 言及 (3.5 節)
if grep -qF 'POSTMORTEM' "${TRAILER_REF}"; then
  PASS=$((PASS+1))
else
  echo "✗ next_steps_template.md missing POSTMORTEM trailer (3.5)" >&2
  FAIL=$((FAIL+1))
fi

# ===== v0.15.0+ checks (Decision journal / Tags / Lessons DB / Blameless) =====

# 13. 4 new reference files exist
for f in \
  "${REFS}/decision_journal_template.md" \
  "${REFS}/tag_taxonomy.md" \
  "${REFS}/lessons_db_schema.md" \
  "${REFS}/blameless_principles.md"
do
  if [[ -f "$f" ]]; then
    PASS=$((PASS+1))
  else
    echo "✗ missing v0.15.0 reference: $f" >&2; FAIL=$((FAIL+1))
  fi
done

# 14. decision_journal_template.md required headings
DJ="${REFS}/decision_journal_template.md"
for marker in "Predicted outcome" "Confidence" "Key assumptions" "Surprise score"
do
  if grep -qF "${marker}" "${DJ}"; then
    PASS=$((PASS+1))
  else
    echo "✗ decision_journal_template.md missing required marker: ${marker}" >&2
    FAIL=$((FAIL+1))
  fi
done

# 15. tag_taxonomy.md: 4 categories + minimum tag counts
TT="${REFS}/tag_taxonomy.md"
for category in "Failure type" "Outcome" "Process" "Phase marker"
do
  if grep -qF "${category}" "${TT}"; then
    PASS=$((PASS+1))
  else
    echo "✗ tag_taxonomy.md missing category: ${category}" >&2
    FAIL=$((FAIL+1))
  fi
done

# 15.5. tag_taxonomy.md must have at least 5 controlled tags from each major category
for tag in "#oom" "#hypothesis-confirmed" "#pivot" "#phase-3"
do
  if grep -qF "${tag}" "${TT}"; then
    PASS=$((PASS+1))
  else
    echo "✗ tag_taxonomy.md missing controlled tag: ${tag}" >&2
    FAIL=$((FAIL+1))
  fi
done

# 16. lessons_db_schema.md: required JSON fields
LDB="${REFS}/lessons_db_schema.md"
for field in "id" "source_slug" "phase" "captured_at" "summary" "tags" "generalizable"
do
  if grep -qF "\"${field}\"" "${LDB}"; then
    PASS=$((PASS+1))
  else
    echo "✗ lessons_db_schema.md missing JSON field: \"${field}\"" >&2
    FAIL=$((FAIL+1))
  fi
done

# 16.5. lessons_db_schema.md: atomic write + ~/.research-lessons.json reference
if grep -qF '~/.research-lessons.json' "${LDB}" && grep -qF 'atomic' "${LDB}"; then
  PASS=$((PASS+1))
else
  echo "✗ lessons_db_schema.md missing atomic write or ~/.research-lessons.json reference" >&2
  FAIL=$((FAIL+1))
fi

# 17. blameless_principles.md: Anti-pattern + Pre-pattern + Google SRE reference
BP="${REFS}/blameless_principles.md"
for marker in "Anti-pattern" "Pre-pattern" "Google SRE"
do
  if grep -qF "${marker}" "${BP}"; then
    PASS=$((PASS+1))
  else
    echo "✗ blameless_principles.md missing marker: ${marker}" >&2
    FAIL=$((FAIL+1))
  fi
done

# 18. lab_notebook_skeleton.md: Phase 4 entry example + Decision journal block + Tags
SKEL="${REFS}/lab_notebook_skeleton.md"
for marker in "Phase 4 G3" "Decision journal" "Phase 6 metacognition" "Tags:" "LAB_NOTEBOOK_INDEX.md"
do
  if grep -qF "${marker}" "${SKEL}"; then
    PASS=$((PASS+1))
  else
    echo "✗ lab_notebook_skeleton.md missing v0.15.0 marker: ${marker}" >&2
    FAIL=$((FAIL+1))
  fi
done

# 19. postmortem_template.md: Blameless callout + Tags
for marker in "Blameless principle" "Tags:"
do
  if grep -qF "${marker}" "${PM}"; then
    PASS=$((PASS+1))
  else
    echo "✗ postmortem_template.md missing v0.15.0 marker: ${marker}" >&2
    FAIL=$((FAIL+1))
  fi
done

# 20. phase_notebook_map.md: Phase 4 dispatch + metacognition + Lessons DB
for marker in "Phase 4 末" "Phase 6 metacognition" "Lessons DB" "LAB_NOTEBOOK_INDEX.md"
do
  if grep -qF "${marker}" "${MAP}"; then
    PASS=$((PASS+1))
  else
    echo "✗ phase_notebook_map.md missing v0.15.0 marker: ${marker}" >&2
    FAIL=$((FAIL+1))
  fi
done

# 21. auto-research SKILL.md: Phase 4.5 dispatch + metacognition + Lessons DB
for marker in "4.5 Lab notebook" "Phase 6 metacognition" "Lessons DB"
do
  if grep -qF "${marker}" "${AUTO_SKILL}"; then
    PASS=$((PASS+1))
  else
    echo "✗ auto-research SKILL.md missing v0.15.0 marker: ${marker}" >&2
    FAIL=$((FAIL+1))
  fi
done

# 22. lessons-search command exists with required frontmatter
LS_CMD="${ROOT}/commands/lessons-search.md"
if [[ -f "${LS_CMD}" ]]; then
  PASS=$((PASS+1))
  for fm in "description:" "argument-hint:" "allowed-tools:"
  do
    if grep -qF "${fm}" "${LS_CMD}"; then
      PASS=$((PASS+1))
    else
      echo "✗ commands/lessons-search.md missing frontmatter: ${fm}" >&2
      FAIL=$((FAIL+1))
    fi
  done
else
  echo "✗ missing: commands/lessons-search.md" >&2
  FAIL=$((FAIL+1))
fi

echo ""
echo "test_lab_notebook.sh: ${PASS} pass / ${FAIL} fail"

if (( FAIL > 0 )); then
  exit 1
fi
exit 0
