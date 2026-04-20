"""Summary statistics for the master county-year panel.

Produces N / Mean / SD / P25 / Median / P75 for the key variables used
across Tables 1–6. Mirrors Table 2 of the team's R replication doc.
Output written to figures/summary_stats.txt and summary_stats.csv.
"""

from __future__ import annotations

from pathlib import Path

import pandas as pd

from _common import load_panel

VARS = [
    ("shi",                          "Soil Heterogeneity Index (SHI)"),
    ("lni",                          "Local Name Index (LNI)"),
    ("religious_diversity_index",    "Religious Diversity Index (RDI)"),
    ("ag_diversity_index",           "Agricultural Diversity Index"),
    ("share_farms_reporting_fert",   "Fertilizer Share"),
    ("wheat_share_of_farmland",      "Wheat Share of Farmland"),
    ("slave_share",                  "Slave Share"),
    ("farm_size_gini",               "Farm Size Gini"),
    ("birth_place_diversity",        "Birthplace Diversity Index"),
    ("mean_elevation_m",             "Mean Elevation (m)"),
    ("mean_annual_temp_c",           "Mean Annual Temperature (°C)"),
    ("mean_annual_precip_mm",        "Mean Annual Precipitation (mm)"),
]


def main() -> None:
    panel = load_panel()
    rows = []
    for col, label in VARS:
        if col not in panel.columns:
            continue
        s = panel[col].dropna()
        if s.empty:
            continue
        rows.append({
            "Variable": label,
            "N": int(s.count()),
            "Mean": round(float(s.mean()), 3),
            "SD": round(float(s.std(ddof=0)), 3),
            "P25": round(float(s.quantile(0.25)), 3),
            "Median": round(float(s.median()), 3),
            "P75": round(float(s.quantile(0.75)), 3),
        })
    df = pd.DataFrame(rows)

    print("=" * 70)
    print("Summary Statistics — County-Level Panel, 1850–1940")
    print("=" * 70)
    print(df.to_string(index=False))

    out_dir = Path(__file__).parent.parent / "figures"
    out_dir.mkdir(exist_ok=True)
    df.to_csv(out_dir / "summary_stats.csv", index=False)
    with open(out_dir / "summary_stats.txt", "w") as f:
        f.write("Summary Statistics — County-Level Panel, 1850–1940\n")
        f.write("=" * 70 + "\n")
        f.write(df.to_string(index=False))
        f.write("\n")
    print(f"\n  saved to figures/summary_stats.{{txt,csv}}")


if __name__ == "__main__":
    main()
