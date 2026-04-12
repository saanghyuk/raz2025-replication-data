"""Replicate Table 4 of Raz (2025) — SHI → Agricultural Diversity.

No IPUMS dependency. Runs on our existing CountyLevelData.csv.
"""

from __future__ import annotations

from _common import CONTROL_COLS_FULL, format_row, load_panel, run_main_spec

GEOCLIMATIC = [
    "mean_elevation_m", "mean_slope_deg",
    "mean_annual_temp_c", "mean_annual_precip_mm",
]
SMOOTH_LOC = ["centroid_lat", "centroid_lon", "lat_sq", "lon_sq", "lat_x_lon"]


def main() -> None:
    panel = load_panel()
    if "ag_diversity_index" not in panel.columns:
        print("ag_diversity_index column missing")
        return

    print("=" * 60)
    print("Table 4: SHI → Agricultural Diversity")
    print("=" * 60)

    col1 = run_main_spec(
        panel, "ag_diversity_index",
        ctrls=[], state_by_year_fe=False,
    )
    print("(1) no controls:                  ", format_row(col1))

    col2 = run_main_spec(
        panel, "ag_diversity_index",
        ctrls=[], state_by_year_fe=True,
    )
    print("(2) + state-by-year FE:           ", format_row(col2))

    col3 = run_main_spec(
        panel, "ag_diversity_index",
        ctrls=GEOCLIMATIC, state_by_year_fe=True,
    )
    print("(3) + geo-climatic controls:      ", format_row(col3))

    col4 = run_main_spec(
        panel, "ag_diversity_index",
        ctrls=GEOCLIMATIC + SMOOTH_LOC, state_by_year_fe=True,
    )
    print("(4) + smooth location (preferred):", format_row(col4))

    from pathlib import Path
    out_dir = Path(__file__).parent.parent / "figures"
    out_dir.mkdir(exist_ok=True)
    with open(out_dir / "table4_shi_ag_diversity.txt", "w") as f:
        for lbl, res in [
            ("(1) no controls", col1),
            ("(2) + state-by-year FE", col2),
            ("(3) + geo-climatic controls", col3),
            ("(4) + smooth location (preferred)", col4),
        ]:
            f.write(f"=== {lbl} ===\n")
            f.write(str(res.summary().tables[1]))
            f.write("\n\n")


if __name__ == "__main__":
    main()
