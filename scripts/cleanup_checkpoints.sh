#!/usr/bin/env bash
# scripts/cleanup_checkpoints.sh — 古い checkpoint を retention policy に従って削除
#
# Usage: bash scripts/cleanup_checkpoints.sh <slug> [--apply] [--days <N>] [--keep-best]
#
# Options:
#   --apply      実際に削除 (デフォルトは dry-run)
#   --days <N>   何日経過したものを対象にするか (default: 30)
#   --keep-best  primary metric が最大の succeeded run の checkpoint は保持
#
# Default は **dry-run** (出力のみ)。誤削除を防ぐため。
#
# Retention 方針 (詳細: skills/auto-research/references/data_lineage.md):
#  - failed run の checkpoint: 30 日経過で削除候補
#  - succeeded だが best でない run の checkpoint: 30 日経過で削除候補
#  - succeeded かつ best run の checkpoint: 永続 (`--keep-best` で除外)

set -euo pipefail

SLUG=""
DAYS=30
APPLY=0
KEEP_BEST=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY=1; shift ;;
    --days) DAYS="$2"; shift 2 ;;
    --keep-best) KEEP_BEST=1; shift ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      if [[ -z "${SLUG}" ]]; then
        SLUG="$1"; shift
      else
        echo "ERROR: unexpected arg: $1" >&2; exit 2
      fi
      ;;
  esac
done

if [[ -z "${SLUG}" ]]; then
  echo "Usage: $0 <slug> [--apply] [--days N] [--keep-best]" >&2
  exit 2
fi

PROJECT_DIR=".research/${SLUG}"
if [[ ! -d "${PROJECT_DIR}" ]]; then
  echo "ERROR: ${PROJECT_DIR} not found" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required" >&2
  exit 2
fi

MODE="DRY-RUN"
[[ ${APPLY} -eq 1 ]] && MODE="APPLY"

echo "=== auto-research checkpoint cleanup ==="
echo "Project:       ${SLUG}"
echo "Mode:          ${MODE}"
echo "Retention:     ${DAYS} days"
echo "Keep best:     $( [[ ${KEEP_BEST} -eq 1 ]] && echo yes || echo no )"
echo ""

# Identify best run (largest primary.value among STATUS=succeeded)
BEST_RUN_ID=""
if [[ ${KEEP_BEST} -eq 1 ]]; then
  declare -A SUCCEEDED_RUNS=()
  for run_dir in "${PROJECT_DIR}/06_RUNS"/*/; do
    [[ -d "${run_dir}" ]] || continue
    status_file="${run_dir}STATUS"
    metrics_file="${run_dir}metrics.json"
    if [[ -f "${status_file}" && -f "${metrics_file}" ]]; then
      status=$(cat "${status_file}")
      if [[ "${status}" == "succeeded" ]]; then
        val=$(jq -r '.primary.value // 0' "${metrics_file}" 2>/dev/null || echo 0)
        run_id=$(basename "${run_dir%/}")
        SUCCEEDED_RUNS["${run_id}"]="${val}"
      fi
    fi
  done
  best_val="-9999"
  for run_id in "${!SUCCEEDED_RUNS[@]}"; do
    val="${SUCCEEDED_RUNS[$run_id]}"
    if awk "BEGIN {exit !(${val} > ${best_val})}"; then
      best_val="${val}"
      BEST_RUN_ID="${run_id}"
    fi
  done
  [[ -n "${BEST_RUN_ID}" ]] && echo "Best run: ${BEST_RUN_ID} (primary=${best_val})" || echo "Best run: (none — no succeeded runs)"
  echo ""
fi

# Find checkpoints
TOTAL_BYTES=0
TOTAL_COUNT=0
DELETED_COUNT=0
DELETED_BYTES=0

while IFS= read -r ckpt_dir; do
  [[ -d "${ckpt_dir}" ]] || continue
  run_id=$(basename "$(dirname "${ckpt_dir}")")
  age_days=$(( ( $(date +%s) - $(stat -c %Y "${ckpt_dir}") ) / 86400 ))
  size_bytes=$(du -sb "${ckpt_dir}" | cut -f1)
  size_human=$(du -sh "${ckpt_dir}" | cut -f1)
  TOTAL_BYTES=$((TOTAL_BYTES + size_bytes))
  TOTAL_COUNT=$((TOTAL_COUNT + 1))

  # Should keep?
  KEEP_REASON=""
  if [[ ${age_days} -lt ${DAYS} ]]; then
    KEEP_REASON="not yet ${DAYS}d old (age=${age_days}d)"
  elif [[ ${KEEP_BEST} -eq 1 && "${run_id}" == "${BEST_RUN_ID}" ]]; then
    KEEP_REASON="best run"
  fi

  if [[ -n "${KEEP_REASON}" ]]; then
    printf '  %-40s  %8s   KEEP    (%s)\n' "${run_id}" "${size_human}" "${KEEP_REASON}"
  else
    DELETED_COUNT=$((DELETED_COUNT + 1))
    DELETED_BYTES=$((DELETED_BYTES + size_bytes))
    if [[ ${APPLY} -eq 1 ]]; then
      printf '  %-40s  %8s   DELETE\n' "${run_id}" "${size_human}"
      rm -rf "${ckpt_dir}"
    else
      printf '  %-40s  %8s   would-delete\n' "${run_id}" "${size_human}"
    fi
  fi
done < <(find "${PROJECT_DIR}/06_RUNS" -mindepth 2 -maxdepth 2 -type d -name 'checkpoints' 2>/dev/null)

echo ""
echo "── Summary ──"
echo "Found checkpoints:   ${TOTAL_COUNT}"
echo "Total size:          $(numfmt --to=iec-i --suffix=B ${TOTAL_BYTES} 2>/dev/null || echo "${TOTAL_BYTES}B")"
echo "Targeted for delete: ${DELETED_COUNT}"
echo "Reclaimable:         $(numfmt --to=iec-i --suffix=B ${DELETED_BYTES} 2>/dev/null || echo "${DELETED_BYTES}B")"

if [[ ${APPLY} -eq 0 && ${DELETED_COUNT} -gt 0 ]]; then
  echo ""
  echo "→ Re-run with --apply to actually delete."
fi
