# Tag Taxonomy (Hybrid: controlled vocabulary + free tags)

`research.lab.notebook` が LAB_NOTEBOOK / POSTMORTEM の各 entry に付与する Tag system の SoT。
Hybrid 設計で **controlled vocabulary 28 個 + 自由 tag** を許容。
ELN guidelines の FAIR (Findable) 原則を Light touch で実装。

## 設計方針

- **Hybrid**: controlled vocabulary は INDEX.md でグループ化、自由 tag は別節で全件列挙
- **覚えやすさ**: controlled は 28 個 (4 カテゴリ × 5-8 tag)、20 未満で不便、40+ で覚えきれない
- **進化可能性**: 頻出する自由 tag は将来 controlled に「昇格」 (v1.0+ 機能)
- **agent draft + user 編集可**: agent が context から推測、user は append 可能

## Controlled vocabulary (28 tags、4 カテゴリ + 補助 2)

### 1. Failure type (7 tags)

実験 / 実装の失敗モードを示す。POSTMORTEM の Hypothesis space §3 と対応:

| tag | 適用 |
|-----|------|
| `#oom` | OutOfMemoryError、CUDA out of memory |
| `#nan` | NaN / Inf in loss、数値発散 |
| `#shape-mismatch` | tensor shape mismatch、size mismatch |
| `#timeout` | wall-clock 超過、SIGKILL、OOM-killer |
| `#import-error` | ImportError、ModuleNotFoundError、deps 不整合 |
| `#data-bug` | data preprocessing バグ、tokenizer 不整合 |
| `#convergence-issue` | training divergence、loss plateau、grad explosion |

### 2. Outcome (5 tags)

仮説検証の結果を示す:

| tag | 適用 |
|-----|------|
| `#hypothesis-confirmed` | Phase 6 で予測通り、verdict CONFIRMED |
| `#hypothesis-rejected` | Phase 6 で反証、verdict REFUTED |
| `#ruled-out` | hypothesis 自体が無効化された |
| `#inconclusive` | 結果が決定的でない (n 不足 / noise 大) |
| `#assumption-reversed` | 事前 assumption が逆方向に判明 |

### 3. Process (6 tags)

意思決定 / 思考プロセスを示す:

| tag | 適用 |
|-----|------|
| `#pivot` | adopted idea を rejected → 別 idea へ pivot |
| `#stuck` | 30 分以上の解決困難 (Phase 5 / 6 で発生) |
| `#insight` | 突発的な気づき、仮説生成イベント |
| `#peer-discussion` | 共同研究者 / advisor との議論で得た示唆 |
| `#decision-adopted` | Phase 3-4 で adopted な意思決定 |
| `#decision-rejected` | Phase 3 G2 で rejected idea (03_REJECTED_IDEAS への link) |

### 4. Phase marker (5 tags、auto)

各 entry がどの Phase で生成されたか:

| tag | 適用 |
|-----|------|
| `#phase-3` | Phase 3 G2 通過後 entry (auto) |
| `#phase-4` | Phase 4 G3 通過後 entry (auto、v0.15.0+) |
| `#phase-5` | Phase 5 TDD Red 中 entry (manual) |
| `#phase-6` | Phase 6 run 完了後 entry (auto) |
| `#phase-8` | Phase 8 review 完了後 entry (auto) |

(Phase 1 / 2 / 7 は no-op、tag 不要)

### 5. Confidence (補助 3 tags、Decision journal 用)

Decision journal の Confidence 値と対応:

| tag | 意味 |
|-----|------|
| `#confidence-low` | 低 (validation pending、unknowns 多) |
| `#confidence-medium` | 中 (prior work で類似結果) |
| `#confidence-high` | 高 (内部 pilot pass、強い prior) |

### 6. Metacognition (補助 4 tags、Phase 6 metacognition entry 用)

| tag | 意味 |
|-----|------|
| `#metacognition` | Phase 6 metacognition entry 自動付与 |
| `#predicted-vs-actual` | 予測と実測の比較を含む entry |
| `#surprise-low` | Surprise score 1-2 |
| `#surprise-high` | Surprise score 4-5 |

## 自由 tag

controlled に該当しないものは自由に `#anything` で付与可:

例:
- domain specific: `#attention-sink`, `#mmlu-only`, `#chain-of-thought`
- model specific: `#llama-3b`, `#qwen-7b`, `#phi-mini`
- approach specific: `#lora`, `#qlora`, `#sft`
- dataset specific: `#mmlu`, `#bigbench-hard`, `#humaneval`

INDEX.md 上は `## Free tags` 節で別管理。

## Tag injection rules (agent 動作)

各 dispatch (Phase 3 / 4 / 5 / 6 / 8) で entry 末尾に `Tags:` 行を agent が draft:

1. **Phase auto-marker** は強制 (`#phase-N`)
2. **Outcome tag** は context 依存 (Phase 6 で 06_RESULTS.md から判定)
3. **Failure type tag** は POSTMORTEM の Hypothesis space §3 verdict から (LIKELY な error pattern)
4. **Process tag** は LAB_NOTEBOOK の前後 entry から推測 (e.g., 直前 entry が pivot 言及なら `#pivot`)
5. **Confidence tag** は Decision journal block の Confidence 値から auto-変換
6. **Metacognition tag** は entry 種別から auto (Phase 6 metacognition entry なら `#metacognition`)
7. **自由 tag** は agent が project metadata から推測 (slug、focus_area、model)、user 追加可能

## Tag 形式仕様

- 小文字、ハイフン区切り (`#hypothesis-confirmed`、NOT `#HypothesisConfirmed`)
- スペース不可
- 1 entry あたり 3-7 tags 推奨 (1 個未満 / 8 個以上は warning)
- entry 末尾の `Tags:` 行は **1 行**、複数行に渡らない
- code block (`` ` ``) で囲む

例 entry 末尾:
```markdown
Tags: `#phase-6` `#oom` `#hypothesis-rejected` `#assumption-reversed` `#llama-3b`
```

## INDEX.md 自動生成 rule

`LAB_NOTEBOOK_INDEX.md` は Phase 6 / 8 dispatch 時に再生成:

```markdown
# Lab Notebook Index — <slug>

<!-- agent-managed:lab.notebook v0.15.0 -->

> 自動生成 (Phase 6 / 8 で更新)。LAB_NOTEBOOK.md の各 entry を tag で逆引き。
> 人手編集禁止 (再生成で上書きされる)。

## Controlled tags

### Failure type

#### #oom (3 entries)
- 2026-05-13 [Phase 6 RUN] r_a3f2 — OOM at step 1240 → POSTMORTEM
- 2026-05-14 [Phase 6 RUN] r_e9f1 — OOM at gradient accumulation
- 2026-05-15 [Phase 6 RUN] r_h2j7 — OOM, batch 8

#### #nan (1 entry)
- 2026-05-16 [Phase 6 RUN] r_k4l8 — NaN at step 178

(他 controlled tag を同様にグループ化)

## Free tags

### #attention-sink
- 2026-05-11 [Phase 3 G2] Idea A selected (focus on attention sink)

### #llama-3b
- 2026-05-13 [Phase 6 metacognition] format dominance reversed at 3B
```

## アンチパターン

- ❌ controlled tag を勝手に作る (taxonomy 不整合) → 自由 tag で対応
- ❌ 自由 tag に大文字スペース付き (`#Attention Sink`) → 小文字ハイフンで
- ❌ 1 entry に 10+ tags (cluttered) → 3-7 推奨
- ❌ Phase auto-marker を欠落 (`#phase-N` 必須)
- ❌ INDEX.md を手動編集 (再生成で消える)

## 拡張ガイドライン (v0.16+)

新しい controlled tag を追加する場合:
1. 自由 tag として 5+ entries で使われた実績があること (頻出性)
2. 4 カテゴリ (Failure / Outcome / Process / Phase) のいずれかに収まること
3. 既存 tag と orthogonal (重複なし)
4. CHANGELOG に追加経緯を記録

## 関連

- INDEX.md 構造: `lab_notebook_skeleton.md` § INDEX
- Decision journal block の Confidence tag: `decision_journal_template.md`
- POSTMORTEM の Failure type tag: `postmortem_template.md` + `hypothesis_table_rules.md`
- Phase auto-marker injection: `phase_notebook_map.md`
