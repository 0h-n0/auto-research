# POSTMORTEM.md template (per-failure card)

`research.lab.notebook` が `06_RUNS/<run_id>/POSTMORTEM.md` を auto-draft するときの SoT。
**6 必須節** + 2 補助節 (§A stack trace excerpt、§B events.jsonl tail)。

## 雛形全文

```markdown
# Post-Mortem: <run_id>

<!-- agent-managed:Phase=6 -->

> Failed run の "なぜ・何を試した・次に何を変える" を再現可能な形で残すカード。
> §1-2 は事実、§3 は仮説空間 (agent draft + user polish)、§4-5 は user 確定必須、§6 は再現性 7-tuple。

## 1. What was attempted

- **Goal**: <RQ から 1 行、`04_EXPERIMENT_PLAN.md` の対応 hypothesis>
- **Config**: [`config.yaml`](config.yaml)
- **Code rev**: `<git_rev>` (events.jsonl から)
- **Started**: <ISO 8601 timestamp>
- **Reproduce**: `bash reproduce.sh`

## 2. What happened

- **Failure mode**: <e.g., "OOM at step 1240" / "NaN in loss at epoch 3" / "shape mismatch in attention head">
- **Exit code**: <events.jsonl.exit_code>
- **Wall-clock to failure**: <duration_ms>
- **Stack trace**: [`error.txt`](error.txt) (抜粋 §A)
- **Telemetry**: [`events.jsonl`](events.jsonl) 末尾 50 行 (抜粋 §B)
- **Last successful checkpoint**: <if any、e.g., "step 1200 / loss 3.42">

## 3. Hypothesis space (explored)

| H | Statement | Evidence | Verdict |
|---|-----------|----------|---------|
| H1 | <agent draft、最有力候補> | <events.jsonl の log line 引用> | LIKELY |
| H2 | <agent draft、第二候補> | <code review or other> | UNLIKELY |
| H3 | <agent draft、ベースライン仮説> | <ruled out by what> | RULED OUT |
| H4 | (任意、max 5) | | |
| H5 | (任意、max 5) | | |

> **Verdict legend**:
> - **LIKELY**: 証拠が積極的に支持、次 action の根拠になる
> - **UNLIKELY**: 証拠が弱いが完全否定できず、保留
> - **RULED OUT**: 反証あり、検討から除外
>
> Agent は最低 3 件 / 最大 5 件を draft (`hypothesis_table_rules.md` の error pattern → H mapping 参照)。
> **verdict は user が確定** (agent 推定はあくまで初期値)。

## 4. Decision

> **本節は user 必須記入** (agent draft は省略可、空欄なら lint warning)

- **Action**: <次に何を変えるか、具体的な diff>
- **Re-run as**: <new run_id (planned)、or "this hypothesis space is RULED OUT, pivot to <X>">
- **Why this should work**: <H? が最有力なら、その仮説の補強>
- **Fallback if this fails**: <2nd action、空欄可>

## 5. Lessons & generalizable insight

> **本節は user 必須記入** (科学的価値の核心)

- <この失敗から得た領域知見、bullet 1-3>
- <将来同じ失敗を避けるためのチェック>
- <Phase 8 review でこの project の "top lesson" 候補になるか>

## 6. Reproducing this failure

```bash
cd .research/<slug>/06_RUNS/<run_id>
bash reproduce.sh  # → 同じ failure を再現する
```

**Required environment**:
- CUDA: <events.jsonl.env.cuda_version>
- GPU: <events.jsonl.env.gpu_model>
- OS: <events.jsonl.env.os>
- uv: `uv.lock` 凍結済 (本ディレクトリ)

**Reproducibility 7-tuple checklist** (`reproducibility_checklist.md` 準拠):

- [x] Code rev: `<git_rev>` ✓
- [x] Config: `config.yaml` ✓
- [x] Dependencies: `uv.lock` snapshot ✓
- [x] Random seed: <seed> ✓
- [ ] Data version: <hash> (要確認、`data_lineage.md`)
- [x] Hardware: ✓
- [x] Reproduce script: `reproduce.sh` ✓

(check 漏れがあれば user に warning 表示)

---

## §A. Stack trace excerpt

```
<error.txt の頭 30 行>
...
<error.txt の末尾 30 行>
```

(完全版は [`error.txt`](error.txt))

## §B. events.jsonl tail (last 50 events)

```jsonl
<events.jsonl の末尾 50 行、JSON pretty なし>
```

## Cross-references

- **LAB_NOTEBOOK entry**: [`<date> [Phase 6 RUN] <run_id> FAILED`](../../LAB_NOTEBOOK.md)
- **Related runs**:
  - Prior failures (same lineage): <r_xxxx, r_yyyy>
  - Subsequent re-runs: <r_zzzz が H1 に基づく改善>
- **Original RQ**: `04_EXPERIMENT_PLAN.md` の RQ-N
```

## 必須節 (lint check で確認)

`tests/test_lab_notebook.sh` で以下のヘッダー存在を確認:

1. `## 1. What was attempted`
2. `## 2. What happened`
3. `## 3. Hypothesis space (explored)`
4. `## 4. Decision`
5. `## 5. Lessons & generalizable insight`
6. `## 6. Reproducing this failure`

§A / §B は補助節 (省略可、ただし agent draft では生成推奨)。

## 必須記入節 (user polish 必須)

- §4 Decision (action / re-run plan / why)
- §5 Lessons (bullet 最低 1 件)

agent は draft で `<TODO: user polish>` placeholder を入れる。release されないよう
Phase 8 review 時に POSTMORTEM の §4-5 が空でないか check (将来 lint feature)。

## Anti-patterns

- ❌ §3 Hypothesis を 1 件だけで済ます (3-5 件で仮説空間を張る)
- ❌ §3 verdict が全件 LIKELY (UNLIKELY / RULED OUT も明記して "排除した思考" を残す)
- ❌ §4 Decision を「TODO」のまま release (思考の核心が抜ける)
- ❌ §5 Lessons を空欄 (科学的価値の喪失)
- ❌ §6 reproducibility checklist を skip (再現性原則違反)
- ❌ events.jsonl から H draft せず error.txt のみ参照 (telemetry の活用不足)

## Hypothesis space の draft 例 (OOM の場合)

```markdown
| H | Statement | Evidence | Verdict |
|---|-----------|----------|---------|
| H1 | batch_size=16 で activation memory が 40GB を超過 | `events.jsonl:line=240 gpu_mem=39.8GB`、`error.txt:CUDA OOM` | LIKELY |
| H2 | gradient accumulation のバッファが累積 | code review (train.py:L120 で zero_grad 漏れ無し) | UNLIKELY |
| H3 | data leak (生 token tensor が GC されず) | tokenizer test pass、torch.cuda.empty_cache 動作確認 | RULED OUT |
```

→ Decision 例:
- Action: batch 16 → 8、grad_accum 1 → 2 で effective batch 維持
- Re-run as: r_b1c8 (planned)
- Why this should work: H1 が最有力、effective batch size 維持で結果不変仮定

## Hypothesis space の draft 例 (NaN の場合)

```markdown
| H | Statement | Evidence | Verdict |
|---|-----------|----------|---------|
| H1 | lr=1e-3 が高すぎて勾配爆発 | `events.jsonl:line=180 grad_norm=1284.5` (前 step 0.8) | LIKELY |
| H2 | fp16 underflow (loss が 1e-7 以下) | `events.jsonl:line=178 loss=4.2e-8` | LIKELY |
| H3 | data に NaN token (前処理バグ) | tokenizer test で確認、issue なし | RULED OUT |
```

## 関連

- Hypothesis 自動 draft rule: `hypothesis_table_rules.md`
- 再現性 checklist: `reproducibility_checklist.md`
- LAB_NOTEBOOK との link: `lab_notebook_skeleton.md` § Phase 6 entry
- Phase 7 paper.draft の Limitations 節での再利用: `skills/research.paper.scaffold/SKILL.md`
