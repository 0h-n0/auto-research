# Provenance trace template (思考の出処、任意)

`research.lab.notebook` の各 entry に **optional な Provenance field** を残す仕様。
研究の核は「どこから着想したか / 誰と議論したか / どの paper を読んだか」の trace。
Open Notebook Science (Bradley 2006) の "no insider information" 原則に Light touch で対応。

> **目的**: アイディア・判断・改善の **出処を可視化** することで、
> (1) 共同研究者が思考過程を追える、
> (2) 後日「なぜそう考えたか」を再構築できる、
> (3) 引用・謝辞漏れを防ぐ。

## 設計方針

- **完全 optional**: 全ての entry / POSTMORTEM で書く必要なし、空欄 OK
- **Light touch**: 3 種類の出処 (paper / discussion / URL) を **1 行ずつ** で
- **agent は推測しない**: user が手書き、agent は template に optional field 行のみ残す
- **隠さない**: AI assistant (Claude / ChatGPT) との議論も provenance に書く (responsible_research.md AI 開示と整合)

## Template

LAB_NOTEBOOK の各 entry / POSTMORTEM §1 に追加可能:

```markdown
**Provenance** (任意):
- **Inspired by**: `~\cite{<bibtex-key>}` (例: `~\cite{hong2024chat}`、MATRIX.md row #N)
- **Discussion**: <人名 / handle> @ <YYYY-MM-DD> (例: `kondo-san @ 2026-05-11`)
- **External thread**: <URL> (例: `https://news.ycombinator.com/item?id=12345`)
- **AI assistant**: Claude / ChatGPT / etc. @ <YYYY-MM-DD> (任意、開示推奨)
```

各 line は **任意** (該当なければ省略)。複数 source は `;` 区切り or 複数行で OK。

## 例

### Phase 3 idea adoption entry

```markdown
### 2026-05-11 [Phase 3 G2] Idea selection — A adopted

(...)

**Decision journal (Light touch)**:
- **Predicted outcome**: ...
- **Confidence**: 中
- **Key assumptions**: 1. ..., 2. ..., 3. ...

**Provenance** (任意):
- **Inspired by**: `~\cite{hong2024chat}` (MATRIX.md #1, "format ablation on MMLU")
- **Discussion**: advisor @ 2026-05-10 (idea A の novelty 確認)
- **AI assistant**: Claude Sonnet 4.6 @ 2026-05-11 (Related Work 草稿レビュー)

Tags: `#phase-3` `#decision-adopted` `#confidence-medium`
```

### POSTMORTEM §1 What was attempted

```markdown
## 1. What was attempted
- Goal: H1 (format dominance) を 3B model で検証
- Config: `06_RUNS/r_a3f2/config.yaml`
- Code rev: `a3f2c8d`
- Reproduce: `bash 06_RUNS/r_a3f2/reproduce.sh`

**Provenance** (任意):
- **Inspired by**: ~\cite{liu2024robustness} (perturbation studies の方法論を流用)
- **Discussion**: Slack #ml-research @ 2026-05-12 (batch size 16 が妥当か議論)
```

## なぜ各 source を分けるか

| Source | 価値 |
|--------|------|
| **Paper cite** | 引用漏れ防止、Related Work / refs.bib との整合 (paper.scaffold v0.13.0 連携) |
| **Discussion** | 共同研究者の謝辞、collaborative thinking の trace |
| **External thread** | 公開議論 (HN / Twitter / arXiv comments) の文脈、open notebook science |
| **AI assistant** | LLM-author 開示 (NeurIPS / ICLR / ACL ポリシー準拠、responsible_research.md) |

## Phase 7 paper drafting との連携 (v0.13.0+)

Provenance の **Paper cite** は `paper.scaffold` (v0.13.0) が Phase 7 で paper の
`refs.bib` と整合性 check に使える (将来 v0.17+ feature):
- LAB_NOTEBOOK の `~\cite{X}` が refs.bib に存在しないと warning
- Acknowledgment 節に `Discussion: X @ date` を集約 (acknowledgment auto-gen)

現状 v0.16.0 では **passive recording** のみ、cross-check は将来。

## Anti-pattern

- ❌ 全 entry に Provenance を書く義務感 (任意のはず)
- ❌ Provenance に "self-discovery" とだけ書く (空欄で良い、無理に埋めない)
- ❌ AI assistant の使用を隠す (open notebook science / 引用倫理違反)
- ❌ Discussion 相手の実名のみ + 連絡先付き (PII redaction 違反、initials or handle にする)
- ❌ Provenance を hindsight bias で書き換える (git history で diff 検出可能)

## Privacy / PII redaction

`responsible_research.md` 準拠で:
- Discussion 相手の実名 → initials or handle (FN, LN initial)
- 連絡先 (email / phone) は書かない
- 私的議論内容の summary は短く要点だけ
- 商業情報 (社名 / 製品名) は仮名

例: `Discussion: AB @ 2026-05-11` (実名 "Akira Bekku" → `AB`)。

## 拡張ガイドライン (v0.17+)

- 自動 cross-check: LAB_NOTEBOOK `~\cite{X}` と refs.bib の整合性 (paper.scaffold 統合)
- Acknowledgment auto-gen: Phase 7 paper.draft が provenance を集約
- AI assistant disclosure auto-aggregate (LLM-author 開示節 auto-fill)

## 関連

- 引用ルール: `skills/auto-research/references/responsible_research.md`
- bibtex 命名 (paper.scaffold v0.13.0): `skills/research.paper.scaffold/references/refs_bib_growth.md`
- LAB_NOTEBOOK 各 entry の構造: `lab_notebook_skeleton.md`
- POSTMORTEM の §1: `postmortem_template.md`
