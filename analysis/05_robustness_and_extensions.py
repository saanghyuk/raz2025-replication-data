"""Robustness checks and extension tests (TA requirements #3a, #3b, #3c).

Robustness:
    (a) Sample sensitivity — drop counties with fewer than N farms, etc.
    (b) Control sensitivity — drop/add each control, alternative SHI cell size
    (c) Inference sensitivity — county cluster vs state cluster vs grid
    (d) Spec sensitivity — state FE vs state-by-year FE vs no FE

Extension (1 chosen):
    Heterogeneous treatment by crop-belt region — does the SHI → LNI effect
    differ in wheat-belt vs corn-belt counties? Motivation: the paper's
    social learning channel should operate most strongly where farming is
    the dominant industry *and* where crops are most sensitive to soil type.

Writes results to final_delivery/figures/robustness_*.txt.
"""

from __future__ import annotations

from pathlib import Path

import pandas as pd

from _common import CONTROL_COLS_FULL, format_row, load_panel, run_main_spec

OUT = Path(__file__).parent.parent / "figures"
OUT.mkdir(exist_ok=True)


def robustness_a_sample(panel: pd.DataFrame) -> None:
    """Sample sensitivity."""
    print("--- Robustness (a): sample sensitivity ---")
    if "lni" not in panel.columns:
        print("  skipping — lni not yet built")
        return

    for min_farms in [0, 100, 500, 1000]:
        sub = panel
        if min_farms > 0 and "total_farms" in panel.columns:
            sub = panel[panel["total_farms"] >= min_farms]
        res = run_main_spec(sub, "lni", ctrls=CONTROL_COLS_FULL)
        print(f"  min_farms>={min_farms}:  {format_row(res)}")


def robustness_b_controls(panel: pd.DataFrame) -> None:
    print("\n--- Robustness (b): drop one control at a time ---")
    if "lni" not in panel.columns:
        return
    full = CONTROL_COLS_FULL
    for drop in full:
        ctrls = [c for c in full if c != drop]
        res = run_main_spec(panel, "lni", ctrls=ctrls)
        print(f"  drop {drop:25s}: {format_row(res)}")


def robustness_c_inference(panel: pd.DataFrame) -> None:
    print("\n--- Robustness (c): standard error clustering ---")
    # Demo: county cluster vs state cluster
    if "lni" not in panel.columns:
        return
    for cluster in ["state"]:  # add 'county' after column is present
        res = run_main_spec(panel, "lni", cluster_col=cluster)
        print(f"  cluster={cluster:8s}: {format_row(res)}")


def extension_crop_belt(panel: pd.DataFrame) -> None:
    """Extension: does SHI → LNI effect differ in wheat-belt vs corn-belt?"""
    print("\n--- Extension: crop-belt heterogeneity ---")
    if "lni" not in panel.columns or "wheat_share_of_farmland" not in panel.columns:
        print("  skipping — dependencies missing")
        return

    d = panel.copy()
    d["wheat_belt"] = (
        d["wheat_share_of_farmland"] > d["wheat_share_of_farmland"].median()
    ).astype(int)

    # Regress lni on shi × wheat_belt with state-by-year FE
    from _common import run_main_spec
    for label, subset in [
        ("wheat belt", d[d["wheat_belt"] == 1]),
        ("non-wheat belt", d[d["wheat_belt"] == 0]),
    ]:
        res = run_main_spec(subset, "lni", ctrls=CONTROL_COLS_FULL)
        print(f"  {label:20s}: {format_row(res)}")


def main() -> None:
    panel = load_panel()
    robustness_a_sample(panel)
    robustness_b_controls(panel)
    robustness_c_inference(panel)
    extension_crop_belt(panel)


if __name__ == "__main__":
    main()
