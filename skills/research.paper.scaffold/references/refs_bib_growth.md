# refs.bib growth rules

`research.paper.scaffold` が `paper/refs.bib` を Phase 2 から Phase 7 まで段階的に育てるルール (SoT)。

## Phase ごとの bibtex 充実度

| Phase | scaffold が書く field | 備考 |
|-------|----------------------|------|
| **Phase 2** (paper.scaffold 初回) | `author`, `title`, `year`, `eprint`, `archiveprefix=arXiv`, `primaryclass`, `url` | `02_SURVEY/papers.jsonl` から |
| Phase 3-6 (paper.scaffold 再 invoke) | (同上、新規 paper 追加時のみ) | Related Work 拡張時に MATRIX に追加 paper があれば |
| **Phase 7** (paper.draft 担当) | + `journal` / `booktitle`, `pages`, `volume`, `doi`, `publisher` | Semantic Scholar MCP で補完 (既存 v0.4.0+ 機能) |

## キー命名規則

```
{first_author_lastname_lowercase}{year}{first_word_of_title_lowercase}
```

### 命名手順

1. `02_SURVEY/papers.jsonl` の `authors_short` から first author の姓を抽出
   - 例: `"Hong et al."` → `hong`
   - "et al." を取り除き、小文字化
2. `year` field
3. `title` の最初の意味語 (a / an / the / on / for を skip)
   - 例: `"Chat Template Effects on LLM Evaluation"` → `chat`
   - 例: `"On the Robustness of MMLU"` → `robustness` (on は skip)
4. 連結: `hong2024chat`, `liu2024robustness`

### 衝突解消 (collision)

同一キーに複数 paper が当たる場合 (例: 2024 年に Liu 姓の異なる paper):

1. **第 2 単語を追加**: `liu2024robustness` → `liu2024robustnessmmlu`
2. それでも衝突なら **suffix `_a`, `_b`**: `liu2024robustness_a`, `liu2024robustness_b`
3. キー uniqueness check は `paper/refs.bib` 全体に対して実施

## bibtex entry の形式 (Phase 2 minimum)

```bibtex
@misc{hong2024chat,
  author = {Hong, Doe and Smith, Jane and ... and Roe, John},
  title  = {Chat Template Effects on LLM Evaluation},
  year   = {2024},
  eprint = {2403.07974},
  archiveprefix = {arXiv},
  primaryclass  = {cs.CL},
  url    = {https://arxiv.org/abs/2403.07974}
}
```

`author` field は full author list を入力する。`papers.jsonl.authors_short` (`"Hong et al."`) は表示用、bibtex には full list を入れる。
full list は note (`02_SURVEY/notes/<id>.md`) の `- authors:` field から取得。複数著者は `and` で区切る。

## bibtex entry の形式 (Phase 7 polished、paper.draft 担当)

Semantic Scholar MCP で取得した metadata を merge:

```bibtex
@inproceedings{hong2024chat,
  author    = {Hong, Doe and Smith, Jane and ... and Roe, John},
  title     = {Chat Template Effects on LLM Evaluation},
  year      = {2024},
  booktitle = {Proceedings of the 62nd Annual Meeting of the Association for Computational Linguistics},
  pages     = {1234--1245},
  doi       = {10.18653/v1/2024.acl-long.123},
  publisher = {Association for Computational Linguistics},
  url       = {https://aclanthology.org/2024.acl-long.123}
}
```

`@misc` → `@inproceedings` / `@article` への昇格は paper.draft が実施。

## 重複防止

paper.scaffold 再 invoke 時:

1. 既存 `paper/refs.bib` をパースし、現存キーを set に保持
2. 新規 paper の bibtex キーを上記ルールで生成
3. キーが既に set に入っていれば **skip** (詳細フィールドが充実してれば agent-managed marker で再生成判定)
4. 入っていなければ append

## bibtex source 別の優先度

`02_SURVEY/papers.jsonl` の paper:
- arxiv ID あり → `@misc` with `eprint`
- venue 公式版がある (note に明記、`venue: NeurIPS24` 等) → 既に `@inproceedings` で書く

将来 (v0.14.0+):
- crossref API で DOI lookup を Phase 2 で前倒し可能 (現在は Phase 7 で Semantic Scholar 経由)

## アンチパターン

- ❌ 同じ paper を arxiv 版と venue 版で別 entry にして両方 cite (重複引用)
- ❌ key を `author2024` で省略 (title 単語必須、衝突確率高い)
- ❌ author field を first author + "et al." だけで済ませる (full list が必須)
- ❌ 商用ジャーナル PDF を url field に直 link (`responsible_research.md` 準拠で arxiv preprint URL を優先)

## 関連

- 入力: `skills/research.literature.matrix/references/paper_note_schema.md` の `authors` field
- DOI 補完: `skills/research.paper.draft/SKILL.md` (Phase 7、Semantic Scholar MCP)
- 引用ルール: `skills/auto-research/references/responsible_research.md`
