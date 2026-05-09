#!/usr/bin/env bash
# scripts/find_cheap_gpu.sh — research.compute.shop の軽量 CLI shortcut
#
# Usage examples:
#   bash scripts/find_cheap_gpu.sh A100-80GB-SXM 1 24
#   bash scripts/find_cheap_gpu.sh H100-80GB-SXM 4 168 --prefer-spot --max 6.0
#   bash scripts/find_cheap_gpu.sh A100-80GB-SXM 1 24 --include-academic --slug attention-sink-llama
#
# Positional args: <gpu_type> <gpu_count> <hours>
# Flags:
#   --prefer-spot           Use spot price when available
#   --max <USD/h>           Filter out providers above this unit price
#   --no-free               Exclude free-tier options
#   --include-academic      Include academic grants (NSF ACCESS / GCP TRC etc.)
#   --region <token>        Add region preference (repeatable: us, jp, eu, ...)
#   --slug <slug>           Save COMPUTE_PROCUREMENT.md to .research/<slug>/
#   --catalog <path>        Override default catalog
#
# 詳細仕様は skills/research.compute.shop/SKILL.md / references/recommendation_logic.md

set -euo pipefail

if [[ $# -lt 3 ]]; then
  grep '^#' "$0" | sed 's/^# \{0,1\}//'
  exit 0
fi

GPU_TYPE="$1"
GPU_COUNT="$2"
HOURS="$3"
shift 3

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CATALOG="${ROOT}/skills/research.compute.shop/references/gpu_providers.json"
COMPUTE_SHOP="${ROOT}/skills/research.compute.shop/references/compute_shop.py.txt"

EXTRA_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefer-spot) EXTRA_ARGS+=(--prefer-spot); shift ;;
    --max) EXTRA_ARGS+=(--max-usd-per-hour "$2"); shift 2 ;;
    --no-free) EXTRA_ARGS+=(--no-free); shift ;;
    --include-academic) EXTRA_ARGS+=(--include-academic); shift ;;
    --region) EXTRA_ARGS+=(--region "$2"); shift 2 ;;
    --slug) EXTRA_ARGS+=(--slug "$2"); shift 2 ;;
    --catalog) CATALOG="$2"; shift 2 ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)
      echo "ERROR: unknown arg: $1" >&2; exit 2 ;;
  esac
done

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 required" >&2
  exit 2
fi

if [[ ! -f "${COMPUTE_SHOP}" ]]; then
  echo "ERROR: compute_shop.py.txt not found at ${COMPUTE_SHOP}" >&2
  exit 1
fi

if [[ ! -f "${CATALOG}" ]]; then
  echo "ERROR: catalog not found at ${CATALOG}" >&2
  exit 1
fi

python3 "${COMPUTE_SHOP}" \
  --gpu-type "${GPU_TYPE}" \
  --gpu-count "${GPU_COUNT}" \
  --hours "${HOURS}" \
  --catalog "${CATALOG}" \
  "${EXTRA_ARGS[@]}"
