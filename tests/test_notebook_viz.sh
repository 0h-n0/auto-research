#!/usr/bin/env bash
# tests/test_notebook_viz.sh — research.notebook.viz (v0.17.0+) の静的チェック
#
# 1. SKILL.md + 6 references files exist
# 2. mkdocs_config_template.yml.md に必須要素
#    (theme: material / plugins: search,tags / extra_javascript: chart.js / dark mode palette)
# 3. viz_pipeline.md に 5 ステップ + uvx mkdocs-material
# 4. chart_embedding.md に events.jsonl + Chart.js + canvas
# 5. nav_structure.md に 10 sections (Home/Survey/Ideas/Plan/Runs/Lab Notebook/Postmortems/Results/Review/Paper)
# 6. phase_progress_template.md に Phase 1-8 + Gate G1-G4 + CSS class
# 7. metric_table_template.md に sortable + status icon mapping
# 8. commands/notebook-viz.md の frontmatter + --serve mode + uvx 確認
# 9. data_lineage.md に viz/ retention rule (v0.17.0+ 節)
# 10. auto-research SKILL.md に notebook.viz の言及
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL_DIR="${ROOT}/skills/research.notebook.viz"
REFS="${SKILL_DIR}/references"
CMD="${ROOT}/commands/notebook-viz.md"
AUTO_SKILL="${ROOT}/skills/auto-research/SKILL.md"
DATA_LINEAGE="${ROOT}/skills/auto-research/references/data_lineage.md"

PASS=0
FAIL=0

# 1. ファイル存在
for f in \
  "${SKILL_DIR}/SKILL.md" \
  "${REFS}/mkdocs_config_template.yml.md" \
  "${REFS}/viz_pipeline.md" \
  "${REFS}/chart_embedding.md" \
  "${REFS}/nav_structure.md" \
  "${REFS}/phase_progress_template.md" \
  "${REFS}/metric_table_template.md"
do
  if [[ -f "$f" ]]; then
    PASS=$((PASS+1))
  else
    echo "✗ missing: $f" >&2; FAIL=$((FAIL+1))
  fi
done

# 2. mkdocs_config_template.yml.md 必須要素
MK_CONFIG="${REFS}/mkdocs_config_template.yml.md"
for marker in "name: material" "search" "tags" "chart.js" "palette" "admonition" "attr_list"
do
  if grep -qF "${marker}" "${MK_CONFIG}"; then
    PASS=$((PASS+1))
  else
    echo "✗ mkdocs_config_template.yml.md missing: ${marker}" >&2
    FAIL=$((FAIL+1))
  fi
done

# 3. viz_pipeline.md の 5 ステップ
PIPELINE="${REFS}/viz_pipeline.md"
for step in "Step 1" "Step 2" "Step 3" "Step 4" "Step 5"
do
  if grep -qF "${step}" "${PIPELINE}"; then
    PASS=$((PASS+1))
  else
    echo "✗ viz_pipeline.md missing: ${step}" >&2
    FAIL=$((FAIL+1))
  fi
done

# 3.5. viz_pipeline.md に uvx + mkdocs-material 言及
for marker in "uvx" "mkdocs-material" "mkdocs build"
do
  if grep -qF "${marker}" "${PIPELINE}"; then
    PASS=$((PASS+1))
  else
    echo "✗ viz_pipeline.md missing: ${marker}" >&2
    FAIL=$((FAIL+1))
  fi
done

# 4. chart_embedding.md 必須要素
CHART="${REFS}/chart_embedding.md"
for marker in "events.jsonl" "Chart.js" "canvas" "loss" "step"
do
  if grep -qF "${marker}" "${CHART}"; then
    PASS=$((PASS+1))
  else
    echo "✗ chart_embedding.md missing: ${marker}" >&2
    FAIL=$((FAIL+1))
  fi
done

# 5. nav_structure.md の 10 sections
NAV="${REFS}/nav_structure.md"
for section in "Home" "Survey" "Ideas" "Plan" "Runs" "Lab Notebook" "Postmortems" "Results" "Review" "Paper"
do
  if grep -qF "${section}" "${NAV}"; then
    PASS=$((PASS+1))
  else
    echo "✗ nav_structure.md missing section: ${section}" >&2
    FAIL=$((FAIL+1))
  fi
done

# 6. phase_progress_template.md の Phase 1-8 + Gates
PHASE="${REFS}/phase_progress_template.md"
for marker in "Phase 1" "Phase 8" "G1" "G4" "phase-progress" "current_phase"
do
  if grep -qF "${marker}" "${PHASE}"; then
    PASS=$((PASS+1))
  else
    echo "✗ phase_progress_template.md missing: ${marker}" >&2
    FAIL=$((FAIL+1))
  fi
done

# 6.5. phase_progress_template.md に done/current/pending CSS class
for cls in "done" "current" "pending"
do
  if grep -qF ".phase.${cls}" "${PHASE}"; then
    PASS=$((PASS+1))
  else
    echo "✗ phase_progress_template.md missing CSS class: .phase.${cls}" >&2
    FAIL=$((FAIL+1))
  fi
done

# 7. metric_table_template.md 必須要素
MT="${REFS}/metric_table_template.md"
for marker in "sortable" "succeeded" "failed" "06_RESULTS" "MATRIX" "06_RUNS/INDEX"
do
  if grep -qF "${marker}" "${MT}"; then
    PASS=$((PASS+1))
  else
    echo "✗ metric_table_template.md missing: ${marker}" >&2
    FAIL=$((FAIL+1))
  fi
done

# 8. commands/notebook-viz.md の frontmatter + 内容
if [[ -f "${CMD}" ]]; then
  PASS=$((PASS+1))
  for fm in "description:" "argument-hint:" "allowed-tools:"
  do
    if grep -qF "${fm}" "${CMD}"; then
      PASS=$((PASS+1))
    else
      echo "✗ commands/notebook-viz.md missing frontmatter: ${fm}" >&2
      FAIL=$((FAIL+1))
    fi
  done
  for content in "uvx" "mkdocs" "viz/index.html"
  do
    if grep -qF "${content}" "${CMD}"; then
      PASS=$((PASS+1))
    else
      echo "✗ commands/notebook-viz.md missing content: ${content}" >&2
      FAIL=$((FAIL+1))
    fi
  done
  # --serve は -F でも flag 解釈されるので別途 grep
  if grep -qF -- "--serve" "${CMD}"; then
    PASS=$((PASS+1))
  else
    echo "✗ commands/notebook-viz.md missing content: --serve" >&2
    FAIL=$((FAIL+1))
  fi
else
  echo "✗ missing: commands/notebook-viz.md" >&2
  FAIL=$((FAIL+1))
fi

# 9. data_lineage.md に viz/ retention rule
if grep -qF 'Generated artifacts (v0.17.0+)' "${DATA_LINEAGE}" && grep -qF '.research/*/viz/' "${DATA_LINEAGE}"; then
  PASS=$((PASS+1))
else
  echo "✗ data_lineage.md missing viz/ retention rule (v0.17.0+ section)" >&2
  FAIL=$((FAIL+1))
fi

# 10. auto-research SKILL.md に notebook.viz の言及
for marker in "research.notebook.viz" "notebook-viz" "v0.17.0"
do
  if grep -qF "${marker}" "${AUTO_SKILL}"; then
    PASS=$((PASS+1))
  else
    echo "✗ auto-research SKILL.md missing reference: ${marker}" >&2
    FAIL=$((FAIL+1))
  fi
done

# 11. SKILL.md 自身に Chart.js + mkdocs-material + uvx の主要要素
SKILL_MD="${SKILL_DIR}/SKILL.md"
for marker in "MkDocs material" "Chart.js" "uvx" "mkdocs-material" "Phase progress" "tag plugin"
do
  if grep -qF "${marker}" "${SKILL_MD}"; then
    PASS=$((PASS+1))
  else
    echo "✗ SKILL.md missing: ${marker}" >&2
    FAIL=$((FAIL+1))
  fi
done

echo ""
echo "test_notebook_viz.sh: ${PASS} pass / ${FAIL} fail"

if (( FAIL > 0 )); then
  exit 1
fi
exit 0
