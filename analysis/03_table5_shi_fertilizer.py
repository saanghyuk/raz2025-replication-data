"""Replicate Table 5 of Raz (2025) — SHI → Fertilizer adoption (growth rate).

Paper uses the growth rate of the share of farms using fertilizers. We
approximate by taking first-difference of `share_farms_reporting_fert`
between adjacent ag census years (1910→1920, 1920→1930), then averaging.

Falls back to level regression at 1920 if growth cannot be computed.
"""

from __future__ import annotations

import pandas as pd

from _common import format_row, load_panel, run_main_spec

GEOCLIMATIC = [
    "mean_elevation_m", "mean_slope_deg",
    "mean_annual_temp_c", "mean_annual_precip_mm",
    "mean_flow_accum", "river_density",
]
SMOOTH_LOC = ["centroid_lat", "centroid_lon", "lat_sq", "lon_sq", "lat_x_lon"]


def build_growth_panel(panel: pd.DataFrame) -> pd.DataFrame:
    """Compute growth of share_farms_reporting_fert across ag census years."""
    fert = panel[panel["share_farms_reporting_fert"].notna()].copy()
    fert = fert[["gisjoin", "year", "share_farms_reporting_fert"]]
    fert = fert.sort_values(["gisjoin", "year"])
    fert["growth"] = fert.groupby("gisjoin")[
        "share_farms_reporting_fert"
    ].diff()
    fert = fert.dropna(subset=["growth"])
    # Average growth per county (or use latest period)
    avg = fert.groupby("gisjoin", as_index=False)["growth"].mean()
    # Attach to 1920 cross-section for SHI + controls
    d = panel[panel["year"] == 1920].drop(columns=["share_farms_reporting_fert"])
    d = d.merge(avg, on="gisjoin", how="left")
    return d


def main() -> None:
    panel = load_panel()
    growth_panel = build_growth_panel(panel)

    print("=" * 60)
    print("Table 5: SHI → Fertilizer adoption growth")
    print("=" * 60)

    for i, ctrls in enumerate([
        [],
        GEOCLIMATIC,
        GEOCLIMATIC + SMOOTH_LOC,
    ], start=1):
        res = run_main_spec(
            growth_panel, "growth", ctrls=ctrls,
            state_by_year_fe=False,  # single cross-section
        )
        lbl = [
            "(1) no controls",
            "(2) geo-climatic",
            "(3) geo-climatic + smooth loc (preferred)",
        ][i - 1]
        print(f"  {lbl}: {format_row(res)}")


if __name__ == "__main__":
    main()
