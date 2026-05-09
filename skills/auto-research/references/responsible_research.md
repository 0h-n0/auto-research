# Responsible Research Guidelines

LLM 研究で守るべき倫理・コンプライアンス指針。Phase 全体で参照する。

## 1. 論文・PDF の取り扱い

| ソース | 再配布 | キャッシュ | 引用上限 |
|--------|--------|-----------|----------|
| arXiv (CC-BY) | OK | フルキャッシュ可 | 制限なし (要出典) |
| arXiv (non-CC) | NG | メタ + 要約のみ | ≤ 2 文 |
| 商用ジャーナル PDF | NG | キャッシュ禁止 | ≤ 2 文 |
| OpenReview public | OK | フルキャッシュ可 | 制限なし |
| 個人 blog / preprint server | 規約による | 個別判定 | ≤ 2 文 |

`02_SURVEY/notes/<paper_id>.md` には **要約 + メタデータ** のみ保存し、原文の連続コピペ ≤ 2 文を厳守する。

## 2. データセットライセンス

- `DATA_CARD.md` で license を明記
- 商用 license (例: 一部 GPT-4 出力) は research / academic 利用許諾を確認
- 派生物配布時の条件 (例: ShareAlike) を満たすこと

## 3. PII / Sensitive Content

- 学習・評価データに PII (氏名、住所、メール、電話番号、医療情報) を含めない
- 含むデータを使う場合は de-identification 手法と検証結果を記載
- ログ (`events.jsonl`) には **絶対に prompt 全文を含めない**。token id か hash のみ

## 4. AI / LLM-Author 開示

NeurIPS, ICLR, ACL など主要会議の規定に準拠:

- 論文の `paper/main.{tex,md}` の冒頭または末尾に **AI 利用開示節** を含める
- 開示すべき内容:
  - LLM がどのフェーズで使われたか (ideation / drafting / coding / review)
  - 人間の責任範囲 (最終的な claim・実験設計の検証)
  - 利用したモデル名と version

テンプレ (`research.paper.draft/references/paper_skeleton.{tex,md}` に同梱):

```markdown
## AI Use Disclosure

This work used Claude (Anthropic, model: claude-opus-4-7) for:
- (1) literature triage and gap analysis (Phases 2-3)
- (2) ablation design (Phase 4)
- (3) section drafting (Phase 7)

All experimental results, statistical claims, and the final theoretical
contribution were verified manually by the human author(s). The authors
take full responsibility for the correctness of the work.
```

## 5. Model Release / Weights

- open release する場合: HF Hub or Zenodo で DOI 付き公開を推奨
- gated release (申請制) の場合は理由を明記 (例: safety review pending)
- closed release の場合: `paper/limitations.md` に理由を必ず記載

## 6. Compute / Carbon Disclosure

主要会議は compute disclosure を推奨。`paper/` に以下を記載:

- 総 GPU-h
- GPU 種別 (例: A100 80GB)
- 推定 CO2 排出 (例: ML CO2 calculator https://mlco2.github.io/impact/)

## 7. Dual-Use / Safety

- jailbreak, attack vectors, exploit 系研究は **責任ある開示** (responsible disclosure) を遵守
- 攻撃成功例は paper に inline で書かず、Appendix またはアクセス制限付き repository へ
- 防御手法と攻撃手法はペアで提示することを推奨
