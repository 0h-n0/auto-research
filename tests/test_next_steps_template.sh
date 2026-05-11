#!/usr/bin/env bash
# tests/test_next_steps_template.sh — next_steps_template.md (v0.18.0+) の整合性チェック
#
# 確認項目:
# 1. trailer SoT 文書が存在
# 2. §3.5 (failed run mixed、v0.14.0+) の拡張: lessons-search hint
# 3. §3.6 (Phase 3 G2 lessons-search、v0.18.0+ 新規)
# 4. §3.7 (Phase 5 TDD stuck、v0.18.0+ 新規)
# 5. §3.8 (Phase 6 Surprise high、v0.18.0+ 新規)
# 6. §1 完了表示拡張: notebook-viz 推奨 (v0.18.0+)
# 7. auto-research SKILL.md の Phase 8 reviewer 入力拡張 (v0.18.0+)
# 8. auto-research SKILL.md の Phase 8.2 [I] 致命的問題: Phase 4 / 6 選択ロジック
# 9. auto-research SKILL.md の Phase 5.2.5 TDD stuck 言及
# 10. DISPATCH_MATRIX.md の Phase 8 reviewer input 拡張
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATE="${ROOT}/skills/auto-research/references/next_steps_template.md"
AUTO_SKILL="${ROOT}/skills/auto-research/SKILL.md"
DISPATCH="${ROOT}/agents/DISPATCH_MATRIX.md"

PASS=0
FAIL=0

# 1. 文書存在
for f in "${TEMPLATE}" "${AUTO_SKILL}" "${DISPATCH}"
do
  if [[ -f "$f" ]]; then
    PASS=$((PASS+1))
  else
    echo "✗ missing: $f" >&2; FAIL=$((FAIL+1))
  fi
done

# 2. §3.5 拡張: failed run trailer に lessons-search hint
for marker in "Similar failure in past projects" "lessons-search --tag" "lessons-search \"{error_pattern}\""
do
  if grep -qF "${marker}" "${TEMPLATE}"; then
    PASS=$((PASS+1))
  else
    echo "✗ §3.5 missing v0.18.0 hint: ${marker}" >&2
    FAIL=$((FAIL+1))
  fi
done

# 3. §3.6 (Phase 3 G2 lessons-search)
for marker in "3.6 Phase 3 G2 通過直後" "Before you proceed — past lessons" "lessons-search \"<your topic>\"" "lessons-search --phase 3" "lessons-search --tag #pivot"
do
  if grep -qF "${marker}" "${TEMPLATE}"; then
    PASS=$((PASS+1))
  else
    echo "✗ §3.6 missing marker: ${marker}" >&2
    FAIL=$((FAIL+1))
  fi
done

# 4. §3.7 (Phase 5 TDD stuck)
for marker in "3.7 Phase 5 TDD Red 30min stuck" "TDD Red stuck" "30 分以上 stuck" "Today's stuck フィールド"
do
  if grep -qF "${marker}" "${TEMPLATE}"; then
    PASS=$((PASS+1))
  else
    echo "✗ §3.7 missing marker: ${marker}" >&2
    FAIL=$((FAIL+1))
  fi
done

# 5. §3.8 (Phase 6 Surprise high)
for marker in "3.8 Phase 6 metacognition Surprise score high" "high-surprise metacognition" "Surprise score ≥ 4" "assumption 反証" "lessons-search --tag #assumption-reversed"
do
  if grep -qF "${marker}" "${TEMPLATE}"; then
    PASS=$((PASS+1))
  else
    echo "✗ §3.8 missing marker: ${marker}" >&2
    FAIL=$((FAIL+1))
  fi
done

# 6. §1 完了表示拡張: notebook-viz 推奨
for marker in "🎨 Project summary を視覚化" "notebook-viz <slug>" "notebook-viz <slug> --serve" "Cross-project recall"
do
  if grep -qF "${marker}" "${TEMPLATE}"; then
    PASS=$((PASS+1))
  else
    echo "✗ §1 完了表示拡張 missing marker: ${marker}" >&2
    FAIL=$((FAIL+1))
  fi
done

# 7. auto-research SKILL.md の Phase 8 reviewer 入力拡張
for marker in "LAB_NOTEBOOK.md (v0.14.0+)" "POSTMORTEM.md (v0.14.0+)" "03_REJECTED_IDEAS.md (v0.14.0+)" "Design integrity (v0.18.0+)"
do
  if grep -qF "${marker}" "${AUTO_SKILL}"; then
    PASS=$((PASS+1))
  else
    echo "✗ auto-research SKILL.md missing v0.18.0 reviewer input: ${marker}" >&2
    FAIL=$((FAIL+1))
  fi
done

# 8. auto-research SKILL.md の Phase 8.2 [I] 選択ロジック
for marker in "修正方向を user に問う (v0.18.0+)" "[4] Phase 4 (実験計画見直し" "[6] Phase 6 (追加 run 実施"
do
  if grep -qF "${marker}" "${AUTO_SKILL}"; then
    PASS=$((PASS+1))
  else
    echo "✗ auto-research SKILL.md missing Phase 8.2 [I] logic: ${marker}" >&2
    FAIL=$((FAIL+1))
  fi
done

# 9. auto-research SKILL.md の Phase 5.2.5 TDD stuck
for marker in "5.2.5 TDD Red 30min stuck (v0.18.0+)" "manual invoke 推奨"
do
  if grep -qF "${marker}" "${AUTO_SKILL}"; then
    PASS=$((PASS+1))
  else
    echo "✗ auto-research SKILL.md missing Phase 5.2.5: ${marker}" >&2
    FAIL=$((FAIL+1))
  fi
done

# 10. DISPATCH_MATRIX.md の Phase 8 reviewer input 拡張
for marker in "v0.18.0+ で入力拡張" "Design integrity" "v0.18.0+ 明確化"
do
  if grep -qF "${marker}" "${DISPATCH}"; then
    PASS=$((PASS+1))
  else
    echo "✗ DISPATCH_MATRIX.md missing v0.18.0 reviewer expansion: ${marker}" >&2
    FAIL=$((FAIL+1))
  fi
done

echo ""
echo "test_next_steps_template.sh: ${PASS} pass / ${FAIL} fail"

if (( FAIL > 0 )); then
  exit 1
fi
exit 0
