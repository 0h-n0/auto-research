# Examples

`auto-research` の使い方を **実際の `.research/<slug>/` プロジェクト構造** で示すサンプル群。
新規ユーザーは「Phase 1-4 の出力ってどんな粒度?」「STATE.json ってどう書かれる?」を一目で把握できます。

## 一覧

| slug | フェーズ | フォーカス | 解説 |
|------|---------|-----------|------|
| [`llm-eval-mmlu-baseline`](./llm-eval-mmlu-baseline/) | Phase 4 / G3 通過 | evaluation | MMLU で baseline 比較研究の典型例。Brief・Survey (5 papers)・Gap・Ideas・実験計画まで揃った状態 |

## 使い方

### 1. 内容を眺める

各 example ディレクトリは実プロジェクトと同じレイアウトです:

```
llm-eval-mmlu-baseline/
├── STATE.json            # 進行状況のスナップショット
├── 01_BRIEF.md           # Phase 1 の成果物
├── 02_SURVEY/
│   ├── papers.jsonl
│   ├── MATRIX.md
│   └── notes/<paper_id>.md
├── 03_GAP_ANALYSIS.md
├── 03_IDEAS.md
├── 04_EXPERIMENT_PLAN.md
└── ...
```

### 2. テンプレートとして再利用

新規プロジェクトを近い領域で始めるとき、example をコピーして `--resume` で続きを実行できます:

```bash
# 自分のプロジェクトに example をコピー (slug を変える)
cp -r path/to/auto-research/examples/llm-eval-mmlu-baseline \
   .research/my-eval-project

# slug を更新
sed -i 's/llm-eval-mmlu-baseline/my-eval-project/g' \
   .research/my-eval-project/STATE.json
```

その後 Claude Code で:

```text
/auto-research:research-design my-eval-project
```

を呼ぶと Phase 4 (G3 既通過なので) の内容を確認しつつ Phase 5 (実装) に進めます。

### 3. cross_compare で比較する

複数プロジェクト/example を集約:

```bash
bash scripts/cross_compare.sh llm-eval-mmlu-baseline <自分のslug>
```

(他の example が増えたら、それらも並べて評価できます)

## 例を追加するときの基準

新しい example を追加したい場合:

1. 実際にそのフェーズまで到達した状態を再現できる構造にする
2. PII / 商用論文 PDF 等を含めない (`responsible_research.md` 準拠)
3. 想定される focus_area / paper_format を明示
4. 各成果物のサイズは合理的に小さく (paper drafts は section 1 つ程度のサンプル可)
5. CHANGELOG にエントリ追加 (PATCH or MINOR は内容次第)
