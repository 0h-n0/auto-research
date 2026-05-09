#!/usr/bin/env bash
# tests/test_init_state_idempotent.sh — init_state.sh を 2 回実行しても破壊しない
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INIT="${ROOT}/scripts/init_state.sh"
TMP=$(mktemp -d)
trap 'rm -rf "${TMP}"' EXIT
cd "${TMP}"

# 1 回目: 新規作成
bash "${INIT}" idempotent-smoke >/dev/null
[[ -f .research/idempotent-smoke/STATE.json ]] || { echo "✗ STATE.json not created" >&2; exit 1; }
[[ -d .research/idempotent-smoke/02_SURVEY/notes ]] || { echo "✗ 02_SURVEY/notes not created" >&2; exit 1; }
[[ -d .research/idempotent-smoke/06_RUNS ]] || { echo "✗ 06_RUNS not created" >&2; exit 1; }
[[ -d .research/idempotent-smoke/paper/sections ]] || { echo "✗ paper/sections not created" >&2; exit 1; }
SLUG_BEFORE=$(jq -r '.project_slug' .research/idempotent-smoke/STATE.json)
CREATED_BEFORE=$(jq -r '.created_at' .research/idempotent-smoke/STATE.json)
[[ "${SLUG_BEFORE}" == "idempotent-smoke" ]] || { echo "✗ project_slug mismatch" >&2; exit 1; }

sleep 1  # updated_at の差分を見るため

# 2 回目: 既存に対して再実行
bash "${INIT}" idempotent-smoke >/dev/null
SLUG_AFTER=$(jq -r '.project_slug' .research/idempotent-smoke/STATE.json)
CREATED_AFTER=$(jq -r '.created_at' .research/idempotent-smoke/STATE.json)
UPDATED_AFTER=$(jq -r '.updated_at' .research/idempotent-smoke/STATE.json)
[[ "${SLUG_AFTER}" == "${SLUG_BEFORE}" ]] || { echo "✗ slug should not change" >&2; exit 1; }
[[ "${CREATED_AFTER}" == "${CREATED_BEFORE}" ]] || { echo "✗ created_at should not change" >&2; exit 1; }
[[ "${UPDATED_AFTER}" != "${CREATED_BEFORE}" ]] || { echo "✗ updated_at should be refreshed" >&2; exit 1; }

# 3. 不正 slug
if bash "${INIT}" "Bad_Slug!" >/dev/null 2>&1; then
  echo "✗ invalid slug was accepted" >&2; exit 1
fi

echo "init_state idempotency test: pass"
