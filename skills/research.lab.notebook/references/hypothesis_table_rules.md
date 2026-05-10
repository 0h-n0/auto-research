# Hypothesis space draft rules

`research.lab.notebook` が POSTMORTEM の §3 Hypothesis space を **events.jsonl + error.txt から
auto-draft** するときの heuristic SoT。

## 出力契約

agent は **最低 3 件 / 最大 5 件** の Hypothesis を draft し、各々に:
- **Statement** (1 文、何が原因と推定するか)
- **Evidence** (events.jsonl の log line / config / code review への具体的 reference)
- **Verdict** 初期値 (LIKELY / UNLIKELY / RULED OUT)

を付与する。**verdict は user が確定**、agent 推定は初期値に過ぎない。

## Verdict 3 値

| Verdict | 意味 | agent が初期値に使う条件 |
|---------|------|------------------------|
| **LIKELY** | 証拠が積極的に支持、次 action の根拠になる | error pattern が明確に該当、events.jsonl に直接 evidence |
| **UNLIKELY** | 証拠が弱いが完全否定できず、保留 | 一般論として可能性はあるが直接 evidence なし |
| **RULED OUT** | 反証あり、検討から除外 | events.jsonl / code / test に積極的反証あり |

## Error pattern → H mapping

agent は `error.txt` (または events.jsonl の `error.message`) を以下の regex でパターンマッチし、
対応する H を draft の primary candidate にする。

| Error pattern (regex、case-insensitive) | 推定 H | 推定 Verdict | Evidence の典型 |
|----------------------------------------|--------|-------------|----------------|
| `OutOfMemoryError\|CUDA out of memory\|cuda.*OOM` | "GPU memory 不足 (batch / model / activation のいずれか)" | LIKELY | `events.jsonl` の `gpu_mem` フィールド、batch_size、model size config |
| `NaN\|Inf` (in loss / grad) | "数値発散 (lr 高 / fp16 underflow / 勾配爆発)" | LIKELY | events.jsonl の `loss`, `grad_norm` 時系列 |
| `AssertionError.*shape\|RuntimeError.*size mismatch\|expected.*got` | "tensor shape mismatch (config と data の不整合)" | LIKELY | error.txt の expected vs got、config.yaml の dim |
| `timeout\|TimeoutError\|SIGKILL\|Killed` | "wall-clock 超過 / OOM-killer" | LIKELY | events.jsonl duration_ms vs config.timeout、syslog OOM-killer |
| `ImportError\|ModuleNotFoundError` | "依存欠落 (uv.lock 不整合 / extras 未インストール)" | LIKELY | events.jsonl env、project pyproject の extras |
| `FileNotFoundError\|No such file` | "data path / checkpoint 指定誤り" | LIKELY | error.txt の path、config の data_dir |
| `ConnectionError\|HTTPError 5\d\d\|RemoteDisconnected` | "外部 API / data download 失敗 (再試行が必要)" | LIKELY | events.jsonl の retry attempts、network log |
| `PermissionError\|EACCES` | "ファイル権限 / mount 不整合" | LIKELY | error.txt path、container mount config |
| `ZeroDivisionError\|sqrt of negative` | "数値範囲のバグ (空 batch / 0 sample)" | LIKELY | code review (validation set 空など) |
| `KeyboardInterrupt\|Ctrl-C` | "user 手動 abort (failure ではない)" | RULED OUT (failure 扱い skip 推奨) | events.jsonl の exit reason |
| `TypeError\|AttributeError` | "API 不整合 (lib version mismatch)" | UNLIKELY | uv.lock vs code の version |
| (該当 pattern なし) | "未分類 — error.txt 全文 + events.jsonl tail から 3 候補を提示" | UNLIKELY | agent が自由 reasoning |

## 補助 H (常に追加検討)

primary H に加えて、以下の **構造的仮説** を必ず検討対象に入れる (1-2 件):

| 補助 H | Trigger | Evidence の取り方 |
|-------|---------|------------------|
| "config drift (前 run と config が違う)" | 直前 run と diff | `06_RUNS/<prev_id>/config.yaml` との diff |
| "code rev drift (前 run と git_rev が違う)" | events.jsonl.git_rev 比較 | `git diff <prev_rev> <this_rev>` |
| "data version drift" | data_lineage.md hash | dataset hash diff |
| "non-determinism (seed 不一致 or cudnn non-deterministic)" | 同 config 再実行時の挙動 | `events.jsonl.seed`、`torch.use_deterministic_algorithms` |
| "hardware drift (GPU model / driver 違い)" | events.jsonl.env diff | 前 run との env 比較 |

これらは多くの場合 **RULED OUT** (前 run と完全一致) になるが、**RULED OUT を明示的に書く**
ことで「これは要因ではない」という思考が残る。これが lab notebook の本質。

## H 数の目安

- **3 件**: 単純な error (OOM など、原因ほぼ確実)
- **4-5 件**: 複合 error / 原因不明 / 数値発散 (空間を広く張る)

5 件超は冗長 (Phase 8 review で読む際の負担)。**最大 5 件まで**。

## Evidence の書き方

✅ Good:
- `events.jsonl:line=240 gpu_mem=39.8GB` (具体的 log line + 値)
- `config.yaml:batch_size=16` (具体的 config 値)
- `code review (train.py:L120 で zero_grad 漏れ無し)` (具体的 file:line + verdict)
- `tokenizer test pass、torch.cuda.empty_cache 動作確認` (具体的 test 結果)

❌ Bad:
- "events.jsonl 見ると怪しい" (具体性なし)
- "code が変" (具体的 file:line なし)
- "memory が足りない" (数字なし)

## 例 1: OOM error (典型)

`error.txt`:
```
torch.cuda.OutOfMemoryError: CUDA out of memory.
Tried to allocate 4.50 GiB. GPU 0 has a total capacity of 39.39 GiB
of which 38.45 GiB is allocated by PyTorch.
```

`events.jsonl` 末尾 (関連 line):
```jsonl
{"event":"train.step","step":1240,"loss":2.45,"gpu_mem_gb":38.45,"ts":"..."}
{"event":"error","error.type":"OutOfMemoryError","error.message":"...","ts":"..."}
```

→ Agent draft:

```markdown
| H | Statement | Evidence | Verdict |
|---|-----------|----------|---------|
| H1 | batch_size=16 + seq_len=4096 で activation memory が 40GB に達した | `events.jsonl:step=1240 gpu_mem=38.45GB` (40GB 直前)、`config.yaml:batch_size=16, seq_len=4096` | LIKELY |
| H2 | gradient checkpointing 未使用で activation 全保持 | `config.yaml:gradient_checkpointing=false` | LIKELY |
| H3 | data leak (前 step の tensor が GC されず) | code review (train.py: del / empty_cache 呼ばれている)、prev run の同 step では発生せず | UNLIKELY |
| H4 | 補助 H: config drift | `06_RUNS/r_prev/config.yaml` と diff: batch_size 8 → 16 のみ変更 | LIKELY (config 変更が H1 を裏付け) |
| H5 | 補助 H: hardware drift | 前 run と同 GPU (A100-40GB) | RULED OUT |
```

→ user polish 後の Decision: "batch 16 → 8 + gradient_checkpointing=true で再 run" (H1 + H2 補強)。

## 例 2: NaN in loss (中程度の難易度)

`error.txt`:
```
RuntimeError: Function 'MulBackward0' returned nan values in its 0th output.
```

`events.jsonl` 末尾:
```jsonl
{"event":"train.step","step":178,"loss":4.2e-8,"grad_norm":3.2,"ts":"..."}
{"event":"train.step","step":179,"loss":2.1e-9,"grad_norm":1284.5,"ts":"..."}
{"event":"train.step","step":180,"loss":NaN,"grad_norm":NaN,"ts":"..."}
{"event":"error","error.type":"RuntimeError",...}
```

→ Agent draft:

```markdown
| H | Statement | Evidence | Verdict |
|---|-----------|----------|---------|
| H1 | lr=1e-3 が高すぎて勾配爆発 (179 step で grad_norm 1284) | `events.jsonl:step=179 grad_norm=1284.5`、前 step 3.2 から 400x | LIKELY |
| H2 | fp16 underflow (loss が 1e-8 で更に縮小して NaN) | `events.jsonl:step=178 loss=4.2e-8`、`config.yaml:precision=fp16` | LIKELY |
| H3 | data に NaN token (前処理バグ) | tokenizer unit test pass、過去 run で同 data 成功 | RULED OUT |
| H4 | 補助 H: gradient clipping 未設定 | `config.yaml:max_grad_norm=null` | LIKELY (H1 の対策に grad clip が欠落) |
```

→ Decision 例: "lr 1e-3 → 5e-4 + max_grad_norm=1.0 + precision fp16 → bf16"。

## 例 3: shape mismatch (config bug)

`error.txt`:
```
RuntimeError: The size of tensor a (4096) must match the size of tensor b (2048) at non-singleton dimension 1
```

→ Agent draft:

```markdown
| H | Statement | Evidence | Verdict |
|---|-----------|----------|---------|
| H1 | seq_len の config と data tokenizer max_len 不整合 | `config.yaml:seq_len=4096`、tokenizer config に max_len=2048 | LIKELY |
| H2 | model 側の position_embedding が 2048 まで | `config.yaml:model=llama-2-7b` (default 2048) | LIKELY |
| H3 | data preprocessing で padding 設定誤り | code review (data_loader.py:L45) | UNLIKELY |
```

## 多言語対応

H draft は **英語推奨** (paper.draft の Limitations 節への流用が容易)。
ただし日本語混在 OK (lab notebook 文化)。Evidence の log line 引用は原文ママ (英語が多い)。

## 関連

- POSTMORTEM 雛形: `postmortem_template.md`
- 再現性 checklist (Evidence の典型 source): `reproducibility_checklist.md`
- 既存 error 分類: `skills/auto-research/references/error_handling_spec.md` (Phase 6 failure mode catalog、本 mapping の根拠)
