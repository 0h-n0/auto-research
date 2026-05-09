#!/usr/bin/env bash
# scripts/cross_compare.sh — 複数 .research/<slug>/ の primary metric を 1 表に集約
#
# Usage: bash scripts/cross_compare.sh <slug1> <slug2> [<slug3> ...]
# Output: stdout に markdown 表
#
# 各 slug の `.research/<slug>/06_RUNS/*/metrics.json` から primary metric を
# 抽出し、slug × run_id × metric の 1 表に並べる。

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <slug1> [<slug2> ...]" >&2
  echo "" >&2
  echo "Example: $0 attention-sink-llama mmlu-prompt-eval-2026" >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq not installed" >&2; exit 2
fi

ROOT="${PWD}"

# Header
echo "# Cross-project Comparison"
echo
echo "Generated: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
echo
echo "| project | run_id | status | primary metric | value | n |"
echo "|---------|--------|--------|----------------|-------|---|"

found=0
missing=()
for slug in "$@"; do
  PROJECT_DIR="${ROOT}/.research/${slug}"
  if [[ ! -d "${PROJECT_DIR}" ]]; then
    missing+=("${slug}")
    continue
  fi
  for run_dir in "${PROJECT_DIR}/06_RUNS"/*/; do
    [[ -d "${run_dir}" ]] || continue
    run_id=$(basename "${run_dir%/}")
    [[ "${run_id}" == "INDEX.md" ]] && continue

    status_file="${run_dir}STATUS"
    metrics_file="${run_dir}metrics.json"
    status=$( [[ -f "${status_file}" ]] && cat "${status_file}" || echo "unknown" )

    if [[ -f "${metrics_file}" ]]; then
      mname=$(jq -r '.primary.name // "?"' "${metrics_file}")
      mval=$(jq -r '.primary.value // "?"' "${metrics_file}")
      mn=$(jq -r '.primary.n // "?"' "${metrics_file}")
    else
      mname="—"; mval="—"; mn="—"
    fi
    echo "| ${slug} | ${run_id} | ${status} | ${mname} | ${mval} | ${mn} |"
    found=$((found+1))
  done
done

echo
echo "Total runs: ${found}"
if [[ ${#missing[@]} -gt 0 ]]; then
  echo
  echo "## Missing projects"
  for m in "${missing[@]}"; do
    echo "- ${m} (no .research/${m}/ directory)"
  done
fi
