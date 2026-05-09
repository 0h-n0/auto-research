"""tests/test_data.py — Red phase の失敗テスト。

ml-engineer agent が Green phase で実装するまでこれは **必ず失敗する**。
これは TDD の意図的な設計であり、scaffold 直後は失敗が正常。
"""

from __future__ import annotations

import pytest


def test_load_dataset_returns_dataset_dict():
    """load_dataset() が DatasetDict を返し train/val/test を含むこと。"""
    from {pkg_name}.data import load_dataset

    ds = load_dataset()
    assert hasattr(ds, "keys"), "DatasetDict-like object が返ること"
    assert {"train", "validation", "test"}.issubset(set(ds.keys())) or "test" in ds


def test_dataset_has_expected_columns():
    """期待されるカラムが含まれること。"""
    from {pkg_name}.data import load_dataset

    ds = load_dataset()
    sample = ds["test"][0]
    assert "input" in sample or "prompt" in sample or "question" in sample


def test_load_dataset_size_within_budget():
    """dataset サイズが compute_budget 内に収まること (max_examples が効く)."""
    from {pkg_name}.data import load_dataset

    ds = load_dataset(max_examples=100)
    assert len(ds["test"]) <= 100


@pytest.mark.gpu
def test_data_to_device():
    """GPU が利用可能なら tensor を .to(device) できること."""
    import torch

    if not torch.cuda.is_available():
        pytest.skip("GPU not available")

    from {pkg_name}.data import collate_batch

    batch = collate_batch([{"input_ids": [1, 2, 3]}, {"input_ids": [4, 5, 6]}])
    batch = {k: v.to("cuda") for k, v in batch.items()}
    assert batch["input_ids"].device.type == "cuda"
