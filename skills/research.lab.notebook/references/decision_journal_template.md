# Decision Journal template (Light touch)

`research.lab.notebook` が LAB_NOTEBOOK の Phase 3 / 4 entry に追加する **Decision journal block**
の SoT。Annie Duke "How to Decide" の decision journal 概念を Light touch 版で実装。

> **目的**: 結果が出る前の "予測 / 信念 / 仮定" を記録し、Phase 6 で実測と照合することで
> hindsight bias を防ぎ、メタ認知の質を高める。
> "After you make a decision, write down what you were thinking. The act of writing crystallizes
> your reasoning, and gives you something concrete to refer back to."

## Light touch 設計方針

- **3 項目だけ** (Predicted outcome / Confidence / Key assumptions ≤3)
- agent が draft、user は polish only (空でも release 可能、ただし warning)
- Phase 6 で実測との照合 entry を agent が auto-生成
- Full preregistration style (OSF / AsPredicted) は v0.16+ option

## Phase 3 entry に追加する block

```markdown
**Decision journal (Light touch)**:
- **Predicted outcome**: <1 行、定量的に書く e.g., "primary metric +3-5pp on MMLU baseline">
- **Confidence**: <低 / 中 / 高> (<理由 1 行>)
- **Key assumptions** (≤3、numbered):
  1. <falsifiable claim、Phase 6 で検証可能な形>
  2. <...>
  3. <...>

Tags: `#phase-3` `#decision-adopted` `#confidence-{low|medium|high}` <その他 controlled / 自由>
```

### 例 (Phase 3 G2 通過後)

```markdown
**Decision journal (Light touch)**:
- **Predicted outcome**: primary metric +3-5pp on MMLU baseline (3-8B model)
- **Confidence**: 中 (中央値想定、prior work 5 本の平均改善が +2.5pp)
- **Key assumptions**:
  1. 4-factor variance が super-additively compose する
  2. format が dominant variance source (>30% contribution)
  3. 3-8B model size でも同 pattern (compute 制約で 70B 不可)

Tags: `#phase-3` `#decision-adopted` `#ablation-design` `#confidence-medium`
```

## Phase 4 entry に追加する block (新規 v0.15.0+)

Phase 4 G3 通過後、04_EXPERIMENT_PLAN.md 確定時に LAB_NOTEBOOK に新規 entry:

```markdown
### YYYY-MM-DD [Phase 4 G3] Experiment design — N factors × M baselines

**Plan summary**: (04_EXPERIMENT_PLAN.md 1-2 文要約)

**Decision journal (Light touch)**:
- **Predicted ablation winner**: <factor 名、e.g., "format (vs order, decoding, subset)">
- **Predicted statistical significance**: <pass / fail prediction、threshold>
- **Confidence**: <低 / 中 / 高>
- **Key assumptions** (≤3):
  1. <e.g., "n=3 seeds で 95% CI が ±0.5pp 以内に収まる">
  2. <e.g., "compute budget 200 GPU-h で 全 cell × 3 seed 完走">
  3. <...>

Tags: `#phase-4` `#decision-design` `#confidence-{low|medium|high}` <factor の自由 tag>
```

## Phase 6 metacognition entry (新規 v0.15.0+、auto-生成)

`06_RESULTS.md` 完成時に lab.notebook が **agent draft で生成**:

```markdown
### YYYY-MM-DD [Phase 6 metacognition] r_<id> — Predicted vs Actual

**Predicted vs Actual table**:

| Metric / claim | Predicted | Actual | Surprise (1-5) |
|----------------|-----------|--------|----------------|
| primary acc improvement | +3-5pp | +1.2pp | 4 |
| dominant factor | format | decoding (3B), format (8B+) | 4 |
| size invariance | hold across 3-8B | held only at 7B+ | 3 |

**What I missed** (blameless):
<1-2 文、Phase 3-4 の assumption の中で外したもの。例:
"format dominance 仮定が誤り。3B model では prompt format より decoding setting が dominant
variance source。assumption #2 (Phase 3) が反証された。">

**Generalizable insight**:
<Lessons DB に保存する候補。1 文で書く。>

**Verdict** (assumption 単位):
- assumption #1 (super-additive compose): CONFIRMED
- assumption #2 (format dominant): REFUTED (3B では decoding が dominant)
- assumption #3 (size invariance): PARTIALLY CONFIRMED (7B+ のみ)

Tags: `#phase-6` `#metacognition` `#predicted-vs-actual` `#hypothesis-{confirmed|rejected|partially}` `#assumption-reversed` `#surprise-{low|medium|high}`
```

### Surprise score (1-5) の評価基準

| Score | 意味 | 例 |
|-------|------|-----|
| 1 | 完全に予測通り | predicted +5pp、actual +5pp |
| 2 | ほぼ予測通り (誤差 < 20%) | predicted +5pp、actual +4.2pp |
| 3 | やや予測と乖離 (20-50%) | predicted +5pp、actual +2.8pp |
| 4 | 大きく乖離 (50-100%) | predicted +5pp、actual +1.2pp or -1pp |
| 5 | 完全に予測外れ / 反対 | predicted +5pp、actual -3pp |

agent draft の根拠: `(|Predicted - Actual| / max(|Predicted|, |Actual|)) * 5` を四捨五入、
+ 方向逆転で +1。**最終 verdict は user 確定**。

## アンチパターン

- ❌ Predicted outcome に「improve」とだけ書く (定量必須)
- ❌ Key assumptions に検証不可能な信念 ("better is better") を書く
- ❌ Confidence を「不明」とする (低 / 中 / 高 のいずれかを必ず選ぶ)
- ❌ Phase 6 metacognition で Surprise score を全 1 にする (predicted を後付けで書き換えた hindsight bias)
- ❌ "What I missed" を「特になし」で済ます (1 つは必ず、無ければ Confidence 低と整合性が取れない)
- ❌ Decision block を空欄で release (warning、user polish 後に release 推奨)

## Hindsight bias 防止の運用ルール

1. **Predicted は Phase 3 / 4 の決定時点で書き、後で書き換えない** (git history で verify)
2. Phase 6 で実測が出た後に Predicted を「修正」したい誘惑が出る → agent-managed marker で保護
3. Surprise score は **「予測時に得られた情報での reasonable さ」を測る** (実測との単純差分ではない)
4. "What I missed" は blameless で書く (`blameless_principles.md` 準拠)

## なぜ Light touch にするか

Full preregistration (OSF / AsPredicted style) は:
- statistical threshold の事前宣言、効果量、多重検定補正、stop rule、analysis plan 全部
- 1 entry で 1-2 ページの記述が必要
- LLM 動画ボードプロジェクトには重い

Light touch (3 項目) は:
- 1 entry で 5-10 行
- 思考の core (予測 / 信念 / 仮定) だけ捕捉
- agent draft + user polish の負担が小さい
- Phase 6 metacognition で十分 hindsight bias を防げる

Full preregistration が必要な research (publication-grade) は v0.16+ で option として提供予定。

## 関連

- LAB_NOTEBOOK Phase 3-4 entry の構造: `lab_notebook_skeleton.md`
- Phase 6 metacognition entry: `lab_notebook_skeleton.md` § Phase 6 metacognition
- Tag taxonomy (`#decision-adopted` 等): `tag_taxonomy.md`
- Blameless で書く: `blameless_principles.md`
- Lessons DB に generalizable insight を append: `lessons_db_schema.md`
