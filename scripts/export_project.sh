#!/usr/bin/env bash
# scripts/export_project.sh — 共有・公開用のプロジェクト bundle を作成
#
# Usage: bash scripts/export_project.sh <slug> [<output_dir>]
#
# 作成される tar.gz: <slug>_export_<YYYYMMDD>.tar.gz
#   - 含む: brief, spec, survey, ideas, plan, runs (config/metrics/events), results, paper, figures
#   - 除外: checkpoints, cache, raw activations (data_lineage.md 参照)
#   - PII redaction: 現状は include パターン方式 (バイナリ・キャッシュは exclude)
#                     events.jsonl の prompt 全文 redaction は手動 (将来 v0.4.0 で自動化)
#
# 詳細: skills/auto-research/references/data_lineage.md

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <slug> [<output_dir>]" >&2
  exit 2
fi

SLUG="$1"
OUT_DIR="${2:-.}"
ROOT="${PWD}"
PROJECT_DIR="${ROOT}/.research/${SLUG}"

if [[ ! -d "${PROJECT_DIR}" ]]; then
  echo "ERROR: project not found: ${PROJECT_DIR}" >&2
  exit 1
fi

DATE=$(date -u +"%Y%m%d")
OUT_FILE="${OUT_DIR}/${SLUG}_export_${DATE}.tar.gz"

mkdir -p "${OUT_DIR}"

# tar の include / exclude を細かく指定:
#   include: メタデータと paper
#   exclude: checkpoint, cache, 活性, dataset
tar czf "${OUT_FILE}" \
  --exclude='*/checkpoints' \
  --exclude='*/cache' \
  --exclude='*/data' \
  --exclude='*/__pycache__' \
  --exclude='*/.pytest_cache' \
  --exclude='*/.mypy_cache' \
  --exclude='*/.ruff_cache' \
  --exclude='*/.venv' \
  --exclude='*/wandb' \
  --exclude='*/mlruns' \
  --exclude='*/outputs' \
  --exclude='*/multirun' \
  --exclude='*.pt' \
  --exclude='*.bin' \
  --exclude='*.safetensors' \
  -C "${ROOT}" ".research/${SLUG}"

SIZE=$(du -h "${OUT_FILE}" | cut -f1)
echo "✓ Created: ${OUT_FILE} (${SIZE})"
echo
echo "Contents preview:"
tar tzf "${OUT_FILE}" | head -20
echo "..."
echo "Total entries: $(tar tzf "${OUT_FILE}" | wc -l)"
echo
echo "⚠ PII reminder:"
echo "  events.jsonl の prompt 全文や API key が含まれていないか目視確認してください。"
echo "  詳細: skills/auto-research/references/responsible_research.md"
