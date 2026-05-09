# DATA_CARD.md (template)

> Phase 5 で `.research/<slug>/code/DATA_CARD.md` に展開する。
> Hugging Face datasets の dataset card に準拠 (https://huggingface.co/docs/datasets/dataset_card)

# {dataset name}

## Source
- URL: {hf hub / github / official}
- License: {例: CC-BY-4.0, MIT, custom}
- Citation: {bibtex 1 つ}

## Splits
| split | examples | notes |
|-------|----------|-------|
| train | N | |
| val   | N | |
| test  | N | held out, not used in any tuning |

## Preprocessing

- tokenizer: {name + version}
- max_length: {N}
- truncation: {left / right / none}
- normalization: {例: NFKC, strip whitespace}
- filter: {例: 重複除去, 言語フィルタ}

実装: `src/<pkg>/data.py` の `preprocess()` を参照。

## License Compliance

- [ ] license が research / academic 利用に適合
- [ ] 商用利用制限がある場合、本研究での利用が許諾される
- [ ] 派生物の再配布条件を満たしている

## PII / Sensitive Content

- [ ] PII (氏名 / 住所 / メール / 電話) を含むか: {yes/no/unknown}
- [ ] 含む場合: スキャン手法と除去結果を記載
- [ ] toxic / harmful content フィルタ済みか: {yes/no/手法}

## Eval Contamination Check

- [ ] pretraining corpus との n-gram overlap (n=10): {%}
- [ ] canary string 検出件数: {N}
- [ ] cutoff date 比較: {model cutoff vs dataset creation}

## Known Limitations

- {例: 英語のみ、特定ドメインに偏る、annotator agreement 不明}
