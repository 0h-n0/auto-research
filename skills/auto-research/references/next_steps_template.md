# Next-Step Trailer (Single Source of Truth)

全 `/auto-research:research-*` コマンドが完走時に出力する **next-step trailer** の仕様。
コマンド本文では本文書を参照し、フォーマットを再記述しない。

`phase_state_machine.md` が phase 遷移の SoT、本文書は **「どのコマンドを次に勧めるか」** の SoT。

---

## 1. 出力フォーマット (literal)

コマンドの最終出力末尾に **必ず**、以下の形式で 1 ブロックを出す:

```
─────────────────────────────────────
[Phase {N}/8] {bar}  {gate_marker}

→ 推奨: /auto-research:research-{cmd} {slug_or_args}
  ({phase_name})

  代替:
   ・ /auto-research:research-status {slug}   {alt_1_label}
   ・ /auto-research:research-{prev_cmd} {slug}   {alt_2_label}
─────────────────────────────────────
```

### フィールド定義

| placeholder | 計算方法 |
|---|---|
| `{N}` | `STATE.json.current_phase` (1-8 の整数)。STATE.json 不在なら `0` |
| `{bar}` | `●` × `N` + `○` × `(8 - N)`。N=0 のとき `○○○○○○○○`、N=8 のとき `●●●●●●●●` |
| `{gate_marker}` | `STATE.json.last_gate_passed` が `G1`/`G2`/`G3`/`G4` なら `G{n} ✓`。`G0` または不在なら空文字 |
| `{cmd}` | 推奨コマンド名 (下記マッピング表) |
| `{slug_or_args}` | アクティブな `project_slug`、または新規プロジェクトなら `"<topic>"` placeholder |
| `{phase_name}` | 推奨先 phase の名前 (Topic Framing / Literature Survey / ... / Self-Review) |
| `{prev_cmd}` | 代替: 1 つ前または rollback 先コマンド |
| `{alt_*_label}` | 「進捗確認」「{phase_name} やり直し」など、後述の表に従う |

罫線は U+2500 (`─`) を 37 個。

### 完了プロジェクト (G4 通過、`completed_at` セット)

```
─────────────────────────────────────
[Phase 8/8] ●●●●●●●●  G4 ✓  ✓ COMPLETED

→ 次のテーマへ: /auto-research:research-start "<新しいトピック>"

  代替:
   ・ /auto-research:research-status   完了プロジェクト一覧
─────────────────────────────────────
```

### STATE.json 不在 (新規ユーザー)

```
─────────────────────────────────────
[Phase 0/8] ○○○○○○○○

→ 推奨: /auto-research:research-start "<研究テーマ>"
  (Topic Framing — Phase 1 を開始)

  代替:
   ・ /auto-research:research-status   既存プロジェクト一覧
─────────────────────────────────────
```

---

## 2. STATE.json → 推奨マッピング (主要パス)

`completed_at == null` かつ rollback 中でない通常進行ケース:

| current_phase | last_gate_passed | 推奨コマンド | phase_name | 代替 1 | 代替 2 |
|---|---|---|---|---|---|
| 1 | G0 | `research-start` | Topic Framing (G1 通過まで) | `research-status` | — |
| 2 | G1 | `research-design` | Gap & Ideation (G2 まで) | `research-status` | `research-start --resume <slug>` |
| 3 | G1 | `research-design` | Gap & Ideation (G2 まで) | `research-status` | Phase 2 やり直し (再サーベイ) |
| 4 | G2 | `research-design` | Experiment Design (G3 まで) | `research-status` | Phase 3 やり直し (アイディア再選) |
| 5 | G3 | `research-experiment` | Scaffold + Baseline TDD | `research-status` | `research-design` (G3 やり直し) |
| 6 | G3 | `research-experiment` | Run & Analysis 継続 | `research-status` | Phase 5 やり直し (実装修正) |
| 7 | G3 | `research-write` | Paper Drafting | `research-status` | `research-experiment` (追加 ablation) |
| 8 | G3 | `research-review` | Self-Review (G4 まで) | `research-status` | Phase 7 やり直し (ドラフト修正) |
| 8 | G4 | (完了表示) | — | `research-status` | — |

**代替欄の `Phase X やり直し`** は、対応するコマンドを再実行する旨を `phase_state_machine.md` の rollback edges に従って案内する。具体的なコマンド名は次の通り:

- 「Phase 2 やり直し」→ `/auto-research:research-start --resume <slug>` (Phase 2 から再開)
- 「Phase 3 やり直し」→ `/auto-research:research-design <slug>` (Phase 3 から再実行)
- 「Phase 5 やり直し」→ `/auto-research:research-experiment <slug>` (Phase 5 から再実行)
- 「Phase 7 やり直し」→ `/auto-research:research-write <slug>` (Phase 7 から再実行)

---

## 3. 特殊状態の分岐

### 3.1 Sanity 失敗 (Phase 6 → 5 へロールバック中)

`STATE.json.rollbacks` 末尾が `{from_phase: 6, to_phase: 5, reason: "sanity ..."}`:

```
─────────────────────────────────────
[Phase 5/8] ●●●●●○○○  G3 ✓  ⚠ rolled back from Phase 6

→ 推奨: /auto-research:research-experiment <slug>
  (Scaffold + Baseline TDD やり直し — sanity 失敗を修正)

  代替:
   ・ /auto-research:research-status <slug>   失敗 run の詳細
   ・ /auto-research:research-design <slug>   G3 やり直し (設計に問題)
─────────────────────────────────────
```

### 3.2 G4 で致命的問題 (Phase 4 / 6 へロールバック)

`rollbacks` 末尾が `{from_phase: 8, to_phase: 4 | 6}`:

- 推奨: 該当 phase のコマンド (`research-design` または `research-experiment`)
- 進捗バー: rollback 後の `current_phase` を反映
- gate_marker: 末尾に `⚠ rolled back from G4`

### 3.3 複数 active project

`.research/*/STATE.json` が 2 件以上で `completed_at == null`:

- `research-status` 自体は一覧表示するので trailer は標準形式 (推奨は次のフェーズ)
- 他のコマンド (start/design/experiment/write/review) は引数 `<slug>` 未指定なら `slug` 解決を促す:

```
⚠ active project が {N} 件あります。<slug> を指定してください:
   ・ attention-sink-llama-long-ctx (Phase 4)
   ・ mmlu-prompt-eval-2026 (Phase 7)

→ 推奨: /auto-research:research-status   一覧と現状確認
─────────────────────────────────────
```

### 3.4 失敗 run のみ (Phase 6 で全 STATUS=failed)

succeeded run が 1 つもない場合:

- 推奨: `research-experiment <slug>` 再実行
- 代替: `research-status <slug>` で失敗詳細
- gate_marker に `⚠ all runs failed` を追記

### 3.5 失敗 run 含む混在 (Phase 6 で一部 STATUS=failed、v0.14.0+)

`research.lab.notebook` が POSTMORTEM 下書きを生成済み (auto-dispatch、§3.5 の dispatch 表参照)。
trailer は **POSTMORTEM の存在と reproduce 手順を必ず提示**:

```
─────────────────────────────────────
[Phase 6/8] ●●●●●●○○  G3 ✓  ⚠ {M} run failed

→ POSTMORTEM 下書き生成済: `06_RUNS/{run_id}/POSTMORTEM.md`
  Hypothesis 3 件 draft、§4 Decision / §5 Lessons 節は要 user polish
→ Reproduce: `bash 06_RUNS/{run_id}/reproduce.sh`
→ Reproducibility checklist: {ok}/7 ✓ (詳細 POSTMORTEM §6)

  代替:
   ・ POSTMORTEM.md を polish して /auto-research:research-experiment <slug> で再 run
   ・ /auto-research:research-status <slug>   全 run 状態確認
─────────────────────────────────────
```

- gate_marker に `⚠ {M} run failed` を追記 (M は failed run 数)
- 複数 failed runs があれば最も新しい 1 件を提示 (全件 list は research-status へ誘導)

---

## 4. 実装ガイド (各コマンドが行うこと)

各コマンドは本文の処理完了後、最後の出力直前で:

1. **STATE.json 読み込み**
   ```bash
   cat .research/<slug>/STATE.json
   ```
   または `Read` ツール。複数 active で slug 未確定なら `.research/*/STATE.json` を Glob。

2. **進捗バー組み立て**
   ```python
   bar = "●" * current_phase + "○" * (8 - current_phase)
   gate_marker = f"G{n} ✓" if last_gate_passed != "G0" else ""
   ```

3. **推奨/代替の決定** — 上記マッピング表 (§2) と特殊状態 (§3) のうち最初に該当するもの

4. **literal 出力** (§1 のフォーマット)

5. **本文との分離** — trailer の前に必ず空行 1 個。`─` 罫線は cosmetic、コードブロック内ではなく素のテキストで出力。

---

## 5. 表示の不変条件 (NEVER do)

- 進捗バーで `●` を 8 個超または 0 個未満出さない
- `last_gate_passed = "G0"` で `G0 ✓` を出さない (空欄)
- `completed_at` が set のとき推奨に進捗系コマンドを入れない
- trailer をコードブロック (` ``` `) の中に入れない (出力フォーマットの破綻)
- 罫線文字を `-` や `=` に変えない (U+2500 固定)
- trailer をスキップしない (どのコマンドでも必須出力)
