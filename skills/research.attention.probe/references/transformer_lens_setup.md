# TransformerLens / nnsight セットアップガイド

## モデルサイズによる使い分け

| モデルサイズ | 推奨ライブラリ | 理由 |
|-------------|---------------|------|
| ≤ 7B | `transformer_lens` (HookedTransformer) | フル介入が可能、ローカル GPU |
| 8B - 70B | `nnsight` (LanguageModel + remote tracer) | リモートトレーシング、メモリ削減 |
| > 70B (API only) | API + activation 抽出は不可 (logit lens のみ可能で介入不可) | 機構解釈は限定的 |

## TransformerLens 最小スニペット

```python
from transformer_lens import HookedTransformer
import torch

model = HookedTransformer.from_pretrained(
    "meta-llama/Llama-3.2-3B",
    device="cuda",
    dtype=torch.bfloat16,
    fold_ln=False,
    center_writing_weights=False,
    center_unembed=False,
)

# トークナイザ込み
tokens = model.to_tokens("The capital of France is")
logits, cache = model.run_with_cache(tokens)

# cache.keys() の主要キー:
#   - "blocks.{layer}.hook_resid_pre"
#   - "blocks.{layer}.attn.hook_pattern"
#   - "blocks.{layer}.mlp.hook_post"
#   - "blocks.{layer}.attn.hook_result"  # per-head
```

## nnsight 最小スニペット (>7B)

```python
from nnsight import LanguageModel

model = LanguageModel("meta-llama/Llama-3.1-8B-Instruct", device_map="auto")

with model.trace("The capital of France is") as tracer:
    layer_5_resid = model.model.layers[5].output[0].save()
    attn_5 = model.model.layers[5].self_attn.output[0].save()

print(layer_5_resid.shape)
```

## 活性キャッシュの実装

```python
import hashlib
import json
from pathlib import Path

import torch

CACHE_DIR = Path("cache/activations")
CACHE_DIR.mkdir(parents=True, exist_ok=True)

def cache_key(model_id: str, prompts: list[str], hook_points: list[str]) -> str:
    payload = json.dumps(
        {"model": model_id, "prompts": prompts, "hooks": hook_points},
        sort_keys=True,
    )
    return hashlib.sha256(payload.encode()).hexdigest()

def cached_run(model, prompts, hook_points):
    key = cache_key(model.cfg.model_name, prompts, hook_points)
    cache_path = CACHE_DIR / f"{key}.pt"
    if cache_path.exists():
        return torch.load(cache_path, weights_only=False)

    cache = {}
    for prompt in prompts:
        tokens = model.to_tokens(prompt)
        _, c = model.run_with_cache(tokens, names_filter=hook_points)
        for k, v in c.items():
            cache.setdefault(k, []).append(v.cpu())
    torch.save(cache, cache_path)
    return cache
```

## 注意点

- `fold_ln=False` を使うと layer norm の解釈が直感的 (折りたたまない)
- bf16 での介入は数値誤差注意。critical な実験では fp32 で検証
- HookedTransformer の `attn.hook_pattern` は `(batch, head, q, k)` 形状
- nnsight は eager 実行と trace context の挙動が混在しやすい — `.save()` 忘れに注意
