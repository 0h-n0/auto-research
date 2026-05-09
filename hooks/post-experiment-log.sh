#!/usr/bin/env bash
# auto-research PostToolUse hook
#
# `uv run *` 系の Bash コマンド完了時に、最新の `.research/<slug>/06_RUNS/<run_id>/`
# に events.jsonl を 1 行追記して再現性メタを残す。
#
# Hook の入力は stdin に JSON で渡される (Claude Code 公式仕様):
#   {"tool_name":"Bash","tool_input":{"command":"...","description":"..."},
#    "tool_response":{"output":"...","exit_code":0,"duration_ms":1234}}
#
# 失敗しても Claude Code 本体の動作は止めない (exit 0 でフィルタ通過扱い)

set -uo pipefail

# stdin から JSON を読み取る (空のときは何もしない)
HOOK_INPUT=$(cat 2>/dev/null || true)
if [[ -z "${HOOK_INPUT}" ]]; then
  exit 0
fi

# jq が無ければ何もしない
if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

TOOL_NAME=$(echo "${HOOK_INPUT}" | jq -r '.tool_name // empty')
if [[ "${TOOL_NAME}" != "Bash" ]]; then
  exit 0
fi

CMD=$(echo "${HOOK_INPUT}" | jq -r '.tool_input.command // empty')

# uv run のみ対象 (research 実験コマンド以外は記録しない)
if [[ ! "${CMD}" =~ (^|[[:space:]&;])uv[[:space:]]+run[[:space:]] ]]; then
  exit 0
fi

# 最新 active project を STATE.json から特定
LATEST_STATE=$(ls -1t .research/*/STATE.json 2>/dev/null | head -n1)
if [[ -z "${LATEST_STATE}" ]]; then
  exit 0
fi
SLUG=$(jq -r '.project_slug // empty' "${LATEST_STATE}")
if [[ -z "${SLUG}" ]]; then
  exit 0
fi

# 最新 run ディレクトリを特定 (なければ "preflight" として記録先を作る)
RUN_DIR=$(ls -1td ".research/${SLUG}/06_RUNS"/*/ 2>/dev/null | head -n1)
if [[ -z "${RUN_DIR}" ]]; then
  RUN_DIR=".research/${SLUG}/06_RUNS/preflight"
  mkdir -p "${RUN_DIR}"
fi

EVENTS_FILE="${RUN_DIR%/}/events.jsonl"

# 取り出すフィールド
EXIT_CODE=$(echo "${HOOK_INPUT}" | jq -r '.tool_response.exit_code // 0')
DURATION_MS=$(echo "${HOOK_INPUT}" | jq -r '.tool_response.duration_ms // 0')
TOOL_OUTPUT=$(echo "${HOOK_INPUT}" | jq -r '.tool_response.output // ""')

# stdout の末尾 200 行のみ (ログ巨大化防止)
STDOUT_TAIL=$(printf '%s' "${TOOL_OUTPUT}" | tail -n 200)

GIT_REV="unknown"
if command -v git >/dev/null 2>&1; then
  GIT_REV=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
fi

TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# 1 行 JSON を append (jq -c で確実にエスケープ)
jq -nc \
  --arg event "tool.bash.uv_run" \
  --arg level "$( [[ "${EXIT_CODE}" -eq 0 ]] && echo info || echo error )" \
  --arg ts "${TS}" \
  --arg run_id "$(basename "${RUN_DIR%/}")" \
  --argjson duration_ms "${DURATION_MS}" \
  --argjson exit_code "${EXIT_CODE}" \
  --arg cmd "${CMD}" \
  --arg git_rev "${GIT_REV}" \
  --arg stdout_tail "${STDOUT_TAIL}" \
  '{event:$event, level:$level, ts:$ts, run_id:$run_id,
    duration_ms:$duration_ms, exit_code:$exit_code,
    cmd:$cmd, git_rev:$git_rev, stdout_tail:$stdout_tail}' \
  >> "${EVENTS_FILE}" 2>/dev/null || true

exit 0
