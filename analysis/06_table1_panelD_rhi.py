"""Replicate Table 1, Panel D of Raz (2025) — SHI → Religious Homogeneity.

The paper's RHI is the Herfindahl–Hirschman Index of denomination shares
(homogeneity, not diversity), z-scored within year. Our master panel
ships `religious_diversity_index = 1 - HHI`, so we recover RHI by

    RHI = 1 - religious_diversity_index

then standardize within year. Religious Bodies Census coverage in the
public NHGIS extract spans 1850, 1860, 1870, and 1890.

Four specifications, mirroring the paper's Table 1 layout:
    (1) No controls
    (2) + state-by-year FE
    (3) + geo-climatic controls
    (4) + smooth-location polynomial (preferred)
"""

from __future__ import annotations

from pathlib import Path

import pandas as pd
import statsmodels.api as sm

from _common import format_row, load_panel, run_main_spec

GEOCLIMATIC = [
    "mean_elevation_m", "mean_slope_deg",
    "mean_annual_temp_c", "mean_annual_precip_mm",
    "mean_flow_accum", "river_density",
]
SMOOTH_LOC = ["centroid_lat", "centroid_lon", "lat_sq", "lon_sq", "lat_x_lon"]


def build_rhi_panel(panel: pd.DataFrame) -> pd.DataFrame:
    d = panel.dropna(subset=["religious_diversity_index"]).copy()
    d["rhi_raw"] = 1.0 - d["religious_diversity_index"]
    d["rhi"] = d.groupby("year")["rhi_raw"].transform(
        lambda x: (x - x.mean()) / x.std(ddof=0)
    )
    return d


def main() -> None:
    panel = load_panel()
    d = build_rhi_panel(panel)

    print("=" * 60)
    print("Table 1 Panel D: SHI → RHI (religious homogeneity)")
    print("=" * 60)
    print(f"Coverage: {sorted(d['year'].unique())}, n={len(d):,}")

    out_rows = []

    bivariate = d.dropna(subset=["shi", "rhi", "state"])
    X0 = sm.add_constant(bivariate[["shi"]])
    res0 = sm.OLS(bivariate["rhi"], X0).fit(
        cov_type="cluster", cov_kwds={"groups": bivariate["state"]}
    )
    print(f"  (1) no controls: {format_row(res0)}")
    out_rows.append(("(1) no controls", res0))

    for label, ctrls in [
        ("(2) + state-by-year FE", []),
        ("(3) + geo-climatic", GEOCLIMATIC),
        ("(4) + smooth loc (preferred)", GEOCLIMATIC + SMOOTH_LOC),
    ]:
        res = run_main_spec(d, "rhi", ctrls=ctrls, state_by_year_fe=True)
        print(f"  {label}: {format_row(res)}")
        out_rows.append((label, res))

    out_dir = Path(__file__).parent.parent / "figures"
    out_dir.mkdir(exist_ok=True)
    with open(out_dir / "table1_panelD_rhi.txt", "w") as f:
        for label, res in out_rows:
            f.write(f"=== {label} ===\n")
            f.write(str(res.summary().tables[1]))
            f.write("\n\n")
    print(f"\n  full output written to figures/table1_panelD_rhi.txt")


if __name__ == "__main__":
    main()
