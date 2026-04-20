"""Replicate Table 5 of Raz (2025) — SHI → Farmers' social learning.

Two panels:
    Panel A: Fertilizer adoption growth (1910 → 1930)
    Panel B: Wheat share of farmland growth (1880 → 1930)

Both outcomes are first-differenced across agricultural-census rounds and
inverse-hyperbolic-sine (IHS) transformed per the paper's footnote 9
(Burbidge et al. 1988) to handle right-skewed distributions with zeros.

Three specifications per panel:
    (1) State FE only
    (2) + geo-climatic controls
    (3) + smooth-location polynomial (preferred)
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd

from _common import format_row, load_panel, run_main_spec

GEOCLIMATIC = [
    "mean_elevation_m", "mean_slope_deg",
    "mean_annual_temp_c", "mean_annual_precip_mm",
    "mean_flow_accum", "river_density",
]
SMOOTH_LOC = ["centroid_lat", "centroid_lon", "lat_sq", "lon_sq", "lat_x_lon"]


def ihs(x: pd.Series) -> pd.Series:
    """Inverse hyperbolic sine transform (Burbidge, Magee & Robb 1988)."""
    return np.log(x + np.sqrt(x ** 2 + 1))


def build_growth_panel(
    panel: pd.DataFrame, value_col: str, anchor_year: int,
) -> pd.DataFrame:
    """Average first-difference of `value_col` across ag-census years,
    IHS-transformed, attached to `anchor_year` cross-section."""
    sub = panel[panel[value_col].notna()][["gisjoin", "year", value_col]]
    sub = sub.sort_values(["gisjoin", "year"])
    sub["diff"] = sub.groupby("gisjoin")[value_col].diff()
    sub = sub.dropna(subset=["diff"])
    avg = sub.groupby("gisjoin", as_index=False)["diff"].mean()
    avg["growth_ihs"] = ihs(avg["diff"])
    cross = panel[panel["year"] == anchor_year].drop(columns=[value_col])
    return cross.merge(avg[["gisjoin", "growth_ihs"]], on="gisjoin", how="left")


def run_panel(
    panel: pd.DataFrame, value_col: str, anchor_year: int, panel_label: str,
) -> list:
    print(f"\n--- {panel_label} ---")
    d = build_growth_panel(panel, value_col, anchor_year)
    rows = []
    specs = [
        ("(1) state FE", []),
        ("(2) + geo-climatic", GEOCLIMATIC),
        ("(3) + smooth loc (preferred)", GEOCLIMATIC + SMOOTH_LOC),
    ]
    for label, ctrls in specs:
        res = run_main_spec(
            d, "growth_ihs", ctrls=ctrls, state_by_year_fe=False,
        )
        print(f"  {label}: {format_row(res)}")
        rows.append((label, res))
    return rows


def main() -> None:
    panel = load_panel()

    print("=" * 60)
    print("Table 5: SHI → Farmers' social learning")
    print("=" * 60)
    print("Outcomes IHS-transformed per Burbidge et al. (1988); see paper fn. 9")

    panel_a = run_panel(
        panel, "share_farms_reporting_fert", anchor_year=1920,
        panel_label="Panel A: Fertilizer adoption growth (1910–1930)",
    )
    panel_b = run_panel(
        panel, "wheat_share_of_farmland", anchor_year=1880,
        panel_label="Panel B: Wheat share of farmland growth (1880–1930)",
    )

    out_dir = Path(__file__).parent.parent / "figures"
    out_dir.mkdir(exist_ok=True)
    with open(out_dir / "table5_shi_farmers.txt", "w") as f:
        for label, rows in [
            ("Panel A: Fertilizer growth (IHS)", panel_a),
            ("Panel B: Wheat share growth (IHS)", panel_b),
        ]:
            f.write(f"=== {label} ===\n")
            for spec_label, res in rows:
                f.write(f"--- {spec_label} ---\n")
                f.write(str(res.summary().tables[1]))
                f.write("\n\n")
    print(f"\n  full output written to figures/table5_shi_farmers.txt")


if __name__ == "__main__":
    main()
