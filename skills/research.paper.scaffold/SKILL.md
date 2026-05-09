---
name: research.paper.scaffold
description: >
  Phase 2 (literature survey) 完了後から呼べる早期論文骨子 builder。
  単一の living document `paper/DRAFT.md` を Phase 進行に合わせて上書き拡張し、
  Abstract (hypothesis-driven) と Introduction (引用付き) を実験前から書き始める運用を可能にする。
  Phase 7 の `research.paper.draft` (既存) はこの DRAFT.md を入力として最終仕上げを担当する。
  Use when: Phase 2 完了後 (MATRIX.md 揃った時点) の自動 dispatch、または
  「実験前に論文骨子を作りたい」と明示的に要求されたとき。
---

# `research.paper.scaffold`

Phase 2 から論文骨子を育てる skill。論文 (特に Abstract と Introduction) を実験前から書く実践を支援。

## なぜ早期に書くか

熟練研究者の暗黙知:
- **Hypothesis-driven Abstract** を Phase 3 で書くと、検証すべき仮説が明確になり Phase 4 の実験設計が引き締まる
- **Related Work** を Phase 2 で書くと、自分の貢献位置が明示され Idea の novelty を Phase 3 で正確にスコアできる
- **Method skeleton** を Phase 4 で書くと、reviewer 視点での「足りない比較」「弱い検定」が早期に見える

## 設計の核

1. **単一 living document**: `paper/DRAFT.md` を Phase ごとに上書き拡張 (separate files にしない)
2. **Phase 進行 ↔ section 充足**: STATE.json の `current_phase` から「どこまで埋めるか」を判定
3. **TBD 明示**: 未充足 section は「(filled at Phase X)」コメント付きで残す
4. **idempotent**: 同じ Phase で再 invoke しても output は (timestamp 以外) 同じ
5. **agent-managed marker**: 各 section に `<!-- agent-managed:Phase=N -->` を入れ、人手編集を保護

## 入力 / 出力

入力 (自動検知):
- `.research/<slug>/STATE.json` (current_phase / focus_area / paper_format)
- `.research/<slug>/01_BRIEF.md` (motivation, success criteria)
- `.research/<slug>/02_SURVEY/MATRIX.md` + `papers.jsonl` + `notes/*.md` (Related Work + bibtex)
- `.research/<slug>/03_IDEAS.md` (G2 通過時、contribution)
- `.research/<slug>/04_EXPERIMENT_PLAN.md` (G3 通過時、Method)
- `.research/<slug>/06_RESULTS.md` (Phase 6 後、結果挿入)

出力:
- `.research/<slug>/paper/DRAFT.md` (新規 or 更新、living document)
- `.research/<slug>/paper/refs.bib` (新規 or 追記、最小 bibtex)

`paper/sections/` は **作らない** (Phase 7 で paper.draft が DRAFT.md から分割)。

## Phase × section 充足 (SoT)

詳細は `references/phase_section_map.md`。要約:

| Phase done | Abstract | Intro: motivation | Intro: relwork | Intro: contrib | Method | Setup | Results | Discussion |
|-----------|----------|------|--------|--------|--------|-------|---------|-----------|
| 1 (Brief) | (本 skill 未 invoke) | | | | | | | |
| 2 (Survey) | [Background], [Implication] | ✓ | ✓ (from MATRIX) | TBD | TBD | TBD | TBD | TBD |
| 3 (Idea) | + [Method], [Hypothesis] | ✓ | ✓ | ✓ | TBD | TBD | TBD | TBD |
| 4 (Plan) | (同上) | ✓ | ✓ | ✓ | ✓ | ✓ | TBD | TBD |
| 6 (Run) | + [Result] (Hypothesis 置換) | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ (preliminary) | TBD |
| 7 (paper.draft) | 全章 polish + LaTeX 化 + DOI 補完 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

## DRAFT.md の構造

`references/draft_md_skeleton.md` に full template。section 並びは:

```markdown
# {title from BRIEF or "TBD: working title"}

<!-- auto-research scaffold v0.13.0+ -->

## Abstract
<!-- agent-managed:Phase={current_phase} -->
{hypothesis-driven, see references/abstract_template.md}

## 1. Introduction
### 1.1 Motivation        (Phase 1+)
### 1.2 Related Work      (Phase 2+, MATRIX-derived)
### 1.3 Contributions     (Phase 3+, IDEAS-derived)

## 2. Method              (Phase 4+, EXPERIMENT_PLAN-derived)
## 3. Experiments
### 3.1 Setup             (Phase 4+)
### 3.2 Baselines         (Phase 4+)
### 3.3 Results           (Phase 6+, RESULTS-derived)

## 4. Discussion          (Phase 7、TBD)
## 5. Limitations         (Phase 7、TBD)
## 6. AI Use Disclosure   (固定)
## References             (refs.bib への link)
```

## Hypothesis-driven Abstract (核機能)

`references/abstract_template.md` 準拠。Phase 2 時点で既にこの 4 ブロック構造を作る:

```markdown
[Background] {LLM evaluation の何が問題か、1-2 文}

[Method] {我々が提案する手法、3-5 文}

[Hypothesis (Phase 6 で検証予定)]
{baseline B に対し metric M で +Δ 以上を予測}

[Implication (検証成立時)]
{もし成立すれば、これは ... を意味する、1-2 文}
```

Phase 6 完了後、`[Hypothesis (Phase 6 で検証予定)]` を `[Result]` に置換 (実値で更新)。

## Related Work paragraph (Phase 2+)

`references/related_work_template.md` 準拠。MATRIX.md の行から sub-area グループ化 + 各 paper の note (`02_SURVEY/notes/<id>.md`) の Method / Claim フィールドから 1-2 文要約 + inline citation。

例:

```markdown
### 1.2 Related Work

**Format effect on LLM evaluation**: Hong et al.~\cite{hong2024chat} report that prompt format choice introduces 2-5pt variance in MMLU scores across four models. Liu et al.~\cite{liu2024robustness} extend this to perturbation analysis, showing few-shot ordering alone contributes >1pt variance. We build on these findings to propose a unified protocol covering format, order, and decoding.

**Compute-aware evaluation**: Wang et al.~\cite{wang2024decoding} demonstrate that decoding settings dominate variance on BIG-bench Hard. Patel et al.~\cite{patel2024sample} show that subset selection introduces 1-3pt variance. Our work integrates these axes into a single 4-factor protocol.

**Position of our work**: While prior work studies these axes in isolation, we are the first to ...
```

## Citation handling

`references/refs_bib_growth.md` 準拠。

**Phase 2 (paper.scaffold 初回)**: `02_SURVEY/papers.jsonl` の各 paper に対し最小 bibtex:

```bibtex
@misc{hong2024chat,
  author = {Hong, Doe and Smith, Jane and ...},
  title  = {Chat Template Effects on LLM Evaluation},
  year   = {2024},
  eprint = {2403.07974},
  archiveprefix = {arXiv},
  primaryclass  = {cs.CL},
  url    = {https://arxiv.org/abs/2403.07974}
}
```

**Phase 7 (paper.draft が引き継ぐ)**: Semantic Scholar MCP で `journal` / `doi` を補完 (既存 v0.4.0+ 機能)。

**bibtex キー命名**: `{firstauthor_lastname}{year}{firstword_of_title_lowercase}`。
衝突時は title 2 単語目を追加 (例: `liu2024robustness` vs `liu2024perturbation`)。

## ワークフロー (毎回 invoke 時)

1. **存在 check**: `.research/<slug>/STATE.json` を Read。なければエラー。
2. **既存 DRAFT.md 読み込み**: あれば既存 sections の `<!-- agent-managed:Phase=N -->` marker を保持
3. **STATE.json 解析**: `current_phase` で各 section の更新可能性を判定
4. **section ごと処理**:
   - 既存 section に `<!-- agent-managed -->` marker あり: agent 編集 OK → rewrite (idempotent)
   - marker なし or 削除済み: 人手編集中とみなし skip + warning
   - marker は今 Phase まで: rewrite + marker 更新
5. **Related Work 更新** (Phase 2+): MATRIX.md / notes/*.md から sub-area グループ + paragraphs
6. **refs.bib 更新**: 既存キーと衝突しないよう新規分のみ append
7. **DRAFT.md 書き出し**: 順序固定、各 section に充足度コメント
8. **next-step trailer 出力** (`next_steps_template.md` 準拠) + paper N% 充足を表示

## 安全機構

- **agent-managed marker 保護**: 人手編集 (marker 削除) を尊重、上書きしない + warning
- **bibtex キー衝突**: 既存 entry と diff、衝突時は fallback rule で新キー
- **AI Use Disclosure 必須**: `references/responsible_research.md` 由来の節は常に DRAFT.md 末尾に挿入
- **引用 ≤ 2 文ルール**: notes から要約引用、verbatim copy 禁止 (responsible_research.md 準拠)

## 失敗モード

| failure | 検出 | 回復 |
|---------|------|------|
| MATRIX.md がまだ存在しない | filesystem check | 「Phase 2 を先に完了してください」エラー |
| papers.jsonl エントリが 0 件 | jq filter | warning + Related Work を TBD で残す (後でユーザー追加可) |
| 03_IDEAS.md に adopted_idea_id 不在 | jq filter | warning + Contributions を generic placeholder で残す |
| bibtex キー衝突が解消できない (3 重以上) | キー uniqueness check | suffix `_a`, `_b` で対応 |
| 人手編集 marker なしの section 多数 | grep | 全 section skip + 「DRAFT.md は既に手動管理されています」と user 確認 |

## 関連ドキュメント

- `references/draft_md_skeleton.md` — 初期 DRAFT.md 雛形 (TBD マーカー入り、SoT)
- `references/abstract_template.md` — hypothesis-driven Abstract の 4 ブロック構造仕様
- `references/introduction_template.md` — Intro の motivation / gap / contribution 構造
- `references/related_work_template.md` — MATRIX.md → paragraph 生成ルール
- `references/refs_bib_growth.md` — citation 命名規則 / Phase ごとの充実度
- `references/phase_section_map.md` — Phase × section 充足表 (本 SKILL の運用 SoT)
- 連携先: `skills/research.paper.draft/SKILL.md` (Phase 7、DRAFT.md を polish)
- 上流参照: `skills/research.literature.matrix/SKILL.md` (MATRIX 形式)、
  `skills/auto-research/references/responsible_research.md` (AI Use Disclosure)

## next-step trailer

```
─────────────────────────────────────
[Phase {N}/8] {bar}  {gate_marker}  📝 paper draft seeded ({P}%)

→ paper/DRAFT.md を生成・更新 ({P}% 充足、Phase {next_paper_phase} で次の section が入る)
  ・ Abstract: hypothesis-driven, [Background] / [Method] / [Hypothesis] / [Implication]
  ・ Introduction: motivation + Related Work ({K} papers cited) + contribution
  ・ Method / Experiments / Discussion: ステータスは DRAFT.md 内コメント参照

  代替:
   ・ /auto-research:research-{next_command} <slug>   次 Phase へ進む
   ・ paper/DRAFT.md を手編集   (agent-managed marker を消すと scaffold は触らない)
─────────────────────────────────────
```

## Phase 連携

- **自動 dispatch**: `auto-research` SKILL.md の Phase 2/3/4/6 末尾で本 skill を呼ぶ
- **手動 dispatch**: `> "research.paper.scaffold で <slug> を更新"` でいつでも (idempotent)
- **Phase 7 連携**: `research.paper.draft` が DRAFT.md を read、sections/ に分割 → 章ごと並列ドラフト → LaTeX 化 + DOI 補完

## 後方互換

- 既存 v0.1.0+ プロジェクトでは paper.scaffold を呼ばないままでも従来挙動 (Phase 7 で paper.draft が単独動作)
- DRAFT.md がない状態で paper.draft を呼んだ場合は既存挙動 (paper_skeleton.{md,tex} から開始)
- DRAFT.md がある状態で paper.draft を呼んだ場合は **DRAFT.md を入力**として section 並列ドラフト
