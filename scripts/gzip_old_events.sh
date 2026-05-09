#!/usr/bin/env bash
# scripts/gzip_old_events.sh — N 日経過した events.jsonl を gzip 圧縮 (デフォルト 90 日)
#
# Usage:
#   bash scripts/gzip_old_events.sh <slug> [--apply] [--days N]
#
# Options:
#   --apply      実際に gzip (デフォルトは dry-run)
#   --days N     何日経過したものを対象にするか (default: 90)
#
# 動作:
#   .research/<slug>/06_RUNS/<run_id>/events.jsonl の mtime を見て、
#   N 日経過 + まだ gzip されていない (`*.gz` でない) ものを `events.jsonl.gz` に圧縮。
#   元 `events.jsonl` は削除 (gzip --rm 相当)。
#
# 詳細: skills/auto-research/references/data_lineage.md の "events.jsonl の retention" 節

set -euo pipefail

SLUG=""
DAYS=90
APPLY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY=1; shift ;;
    --days) DAYS="$2"; shift 2 ;;
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
  echo "Usage: $0 <slug> [--apply] [--days N]" >&2
  exit 2
fi

PROJECT_DIR=".research/${SLUG}"
if [[ ! -d "${PROJECT_DIR}" ]]; then
  echo "ERROR: ${PROJECT_DIR} not found" >&2
  exit 1
fi

if ! command -v gzip >/dev/null 2>&1; then
  echo "ERROR: gzip is required" >&2
  exit 2
fi

MODE="DRY-RUN"
[[ ${APPLY} -eq 1 ]] && MODE="APPLY"

echo "=== auto-research events.jsonl gzip ==="
echo "Project:     ${SLUG}"
echo "Mode:        ${MODE}"
echo "Threshold:   ${DAYS} days"
echo ""

TOTAL_BYTES=0
TOTAL_COUNT=0
GZIPPED_COUNT=0
GZIPPED_BYTES=0

while IFS= read -r events_file; do
  [[ -f "${events_file}" ]] || continue
  age_days=$(( ( $(date +%s) - $(stat -c %Y "${events_file}") ) / 86400 ))
  size_bytes=$(stat -c %s "${events_file}")
  size_human=$(du -h "${events_file}" | cut -f1)
  run_id=$(basename "$(dirname "${events_file}")")
  TOTAL_BYTES=$((TOTAL_BYTES + size_bytes))
  TOTAL_COUNT=$((TOTAL_COUNT + 1))

  if [[ ${age_days} -lt ${DAYS} ]]; then
    printf '  %-40s  %8s   KEEP    (age=%dd)\n' "${run_id}" "${size_human}" "${age_days}"
    continue
  fi

  GZIPPED_COUNT=$((GZIPPED_COUNT + 1))
  GZIPPED_BYTES=$((GZIPPED_BYTES + size_bytes))

  if [[ ${APPLY} -eq 1 ]]; then
    if gzip "${events_file}"; then
      gz_size=$(du -h "${events_file}.gz" 2>/dev/null | cut -f1 || echo "?")
      printf '  %-40s  %8s → %8s   GZIPPED\n' "${run_id}" "${size_human}" "${gz_size}"
    else
      printf '  %-40s  %8s   ✗ FAILED\n' "${run_id}" "${size_human}" >&2
    fi
  else
    printf '  %-40s  %8s   would-gzip  (age=%dd)\n' "${run_id}" "${size_human}" "${age_days}"
  fi
done < <(find "${PROJECT_DIR}/06_RUNS" -mindepth 2 -maxdepth 2 -type f -name 'events.jsonl' 2>/dev/null)

echo ""
echo "── Summary ──"
echo "Found events.jsonl:   ${TOTAL_COUNT}"
echo "Total raw size:       $(numfmt --to=iec-i --suffix=B ${TOTAL_BYTES} 2>/dev/null || echo "${TOTAL_BYTES}B")"
echo "Targeted for gzip:    ${GZIPPED_COUNT}"
echo "Approx. raw saved:    $(numfmt --to=iec-i --suffix=B ${GZIPPED_BYTES} 2>/dev/null || echo "${GZIPPED_BYTES}B")"
echo "                      (gzip 圧縮率は内容次第、通常 5-10x)"

if [[ ${APPLY} -eq 0 && ${GZIPPED_COUNT} -gt 0 ]]; then
  echo ""
  echo "→ Re-run with --apply to actually gzip."
fi
