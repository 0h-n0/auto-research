#!/usr/bin/env bash
# auto-research プロジェクト初期化スクリプト
#
# Usage: bash ${CLAUDE_PLUGIN_ROOT}/scripts/init_state.sh <slug>
#
# `.research/<slug>/` ディレクトリツリーと初期 STATE.json を作る。
# 既存ディレクトリがあれば touch のみで何もしない (べき等)。

set -euo pipefail

SLUG="${1:?Usage: init_state.sh <slug>}"

# slug validation: ^[a-z][a-z0-9-]{2,48}$
if ! [[ "${SLUG}" =~ ^[a-z][a-z0-9-]{2,48}$ ]]; then
  echo "ERROR: invalid slug '${SLUG}' (must match ^[a-z][a-z0-9-]{2,48}$)" >&2
  exit 2
fi

ROOT=".research/${SLUG}"
mkdir -p \
  "${ROOT}/02_SURVEY/notes" \
  "${ROOT}/06_RUNS" \
  "${ROOT}/paper/sections" \
  "${ROOT}/paper/figures" \
  "${ROOT}/figures"

STATE_FILE="${ROOT}/STATE.json"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

if [[ -f "${STATE_FILE}" ]]; then
  # 既存: updated_at だけ更新
  if command -v jq >/dev/null 2>&1; then
    tmp=$(mktemp)
    jq --arg ts "${NOW}" '.updated_at = $ts' "${STATE_FILE}" > "${tmp}" \
      && mv "${tmp}" "${STATE_FILE}"
  fi
  echo "Project '${SLUG}' already exists at ${ROOT}/ (updated_at refreshed)"
  exit 0
fi

# 新規 STATE.json
cat > "${STATE_FILE}" <<JSON
{
  "schema_version": 1,
  "project_slug": "${SLUG}",
  "created_at": "${NOW}",
  "updated_at": "${NOW}",
  "current_phase": 1,
  "last_gate_passed": "G0",
  "focus_area": null,
  "paper_format": null,
  "time_budget_days": null,
  "compute_budget_gpu_h": null,
  "adopted_idea_id": null,
  "active_run_ids": [],
  "completed_at": null,
  "rollbacks": []
}
JSON

# CHANGELOG.md 初期化
cat > "${ROOT}/CHANGELOG.md" <<MD
# CHANGELOG (project: ${SLUG})

${NOW}: project created (Phase 1)
MD

echo "Initialized project '${SLUG}' at ${ROOT}/"
