# Intervention Protocols

Mechanistic interpretability の介入プロトコル別レシピ。`analysis/<slug>.py` 雛形として使う。

---

## 1. Logit Lens

**目的**: 各層の residual stream から unembed を直接適用し、next-token 予測がどう形成されるかを観察。

**最小スクリプト**:

```python
import torch
from transformer_lens import HookedTransformer

model = HookedTransformer.from_pretrained("meta-llama/Llama-3.2-3B", device="cuda", dtype=torch.bfloat16)
tokens = model.to_tokens(["The capital of France is"])
_, cache = model.run_with_cache(tokens)

# 各層の resid_post を unembed に通す
unembed = model.W_U  # (d_model, d_vocab)
ranks = []
for layer in range(model.cfg.n_layers):
    resid = cache[f"blocks.{layer}.hook_resid_post"][:, -1, :]  # last token
    logits = resid @ unembed
    target = model.to_single_token(" Paris")
    rank = (logits.argsort(dim=-1, descending=True) == target).nonzero()[:, 1].item()
    ranks.append(rank)

print(ranks)
```

**注意**: layer norm を `fold_ln=False` で読み込むと unembed 適用前に正規化が必要。

---

## 2. Attention Pattern

**目的**: 特定 head の attention pattern を可視化し、どのトークンに attend しているか観察。

**最小スクリプト**:

```python
import circuitsvis as cv

attn_pattern = cache["blocks.5.attn.hook_pattern"]  # (batch, head, q, k)
str_tokens = model.to_str_tokens(tokens[0])

html = cv.attention.attention_patterns(
    tokens=str_tokens,
    attention=attn_pattern[0],  # batch=0
)
with open("results/probe/attn_layer5.html", "w") as f:
    f.write(str(html))
```

**注意**: pattern を眺めるだけでは因果性は分からない。activation patching と組み合わせる。

---

## 3. Activation Patching

**目的**: clean prompt の活性で corrupted prompt の活性を置き換え、特定コンポーネントの因果的役割を検証。

**最小スクリプト** (head L5H3 が IOI タスクの "previous token" を担うか検証):

```python
clean = model.to_tokens("When Mary and John went to the store, John gave a drink to")
corrupted = model.to_tokens("When Alice and Bob went to the store, Alice gave a drink to")

_, clean_cache = model.run_with_cache(clean)

def patch_head(activation, hook, layer, head):
    activation[:, head, :, :] = clean_cache[hook.name][:, head, :, :]
    return activation

from functools import partial
import torch

original_logits = model(corrupted)
patched_logits = model.run_with_hooks(
    corrupted,
    fwd_hooks=[(f"blocks.5.attn.hook_pattern", partial(patch_head, layer=5, head=3))],
)

target = model.to_single_token(" John")
delta = patched_logits[:, -1, target] - original_logits[:, -1, target]
print(f"Patching effect: {delta.item():.4f}")
```

**強い証拠の条件**:
- N >= 64 prompts × 3 seeds
- shuffled-control (clean のラベルをランダム置換) で同じ介入をしても効果が消えること

---

## 4. Path Patching

**目的**: head A → head B の経路だけに介入し、間接効果を測る (Wang et al., 2023)。

実装は activation patching より複雑。`transformer_lens` の `path_patching` ヘルパーまたは Anthropic の `circuit_analysis` を参照。

---

## 5. Probing Classifier

**目的**: 表現 (residual stream / mlp 出力) に特定情報がエンコードされているかを線形分類器で検証。

**最小スクリプト**:

```python
from sklearn.linear_model import LogisticRegressionCV
import numpy as np

X = []  # (N, d_model) — 各 prompt の最終 token の resid_post
y = []  # ラベル (例: 文の感情極性)

for prompt, label in zip(prompts, labels):
    tokens = model.to_tokens(prompt)
    _, cache = model.run_with_cache(tokens)
    resid = cache["blocks.10.hook_resid_post"][0, -1, :].cpu().numpy()
    X.append(resid)
    y.append(label)

X = np.stack(X)
y = np.array(y)

clf = LogisticRegressionCV(cv=5, max_iter=1000)
clf.fit(X, y)
print(f"5-fold CV acc: {clf.score(X, y):.3f}")
```

**注意**:
- 線形分類器の精度高 → 「線形に分離可能 (encoded)」、 但し「使われている」は別問題 (causal でない)
- random label control (shuffle) で同等精度なら overfit / leakage を疑う

---

## 6. SAE Feature Lookup

**目的**: 重ね合わせ (superposition) を解いた単義特徴を抽出し、neuron-level の解釈を超える。

`sae-lens` または Anthropic 公開 SAE を使うのが現実的。詳細は本スキルの範囲外、`sae-lens` README 参照。

---

## 共通の出力フォーマット

各 intervention 完了時に `results/probe/<probe_id>.json` に書き出す:

```json
{
  "probe_id": "activation_patching_l5h3_ioi",
  "intervention": "activation_patching",
  "hypothesis": "Head L5H3 carries the previous-token information for IOI task",
  "model_id": "meta-llama/Llama-3.2-3B",
  "n_examples": 128,
  "seeds": [0, 1, 2],
  "primary_metric": "logit_diff_drop_pct",
  "values_per_seed": [0.42, 0.38, 0.45],
  "mean": 0.417,
  "ci_95": [0.36, 0.47],
  "shuffled_control_mean": 0.02,
  "alternative_explanations_not_ruled_out": [
    "L5H3 may also encode token position, not just previous token",
    "Effect may be driven by a small subset of templates"
  ]
}
```

`alternative_explanations_not_ruled_out` は常に 2 つ以上残す。
