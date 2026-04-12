"""Figures 1, 2, 3 for Raz (2025) replication.

Figure 1: County-level SHI map (CONUS).
Figure 2: County-level LNI map 1940 (requires IPUMS-derived LNI column).
Figure 3: DiD event study β_b (requires linked MigrantsNative_2.csv).

All figures are written to final_delivery/figures/ as PNG.
"""

from __future__ import annotations

from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

from _common import FIGS, load_panel


def fig1_shi_map() -> None:
    import geopandas as gpd
    panel = load_panel()
    shi = panel[["gisjoin", "shi"]].drop_duplicates("gisjoin")

    # Look for the county parquet cache one directory up from delivery
    cand = [
        Path(
            "/Users/ab180/Desktop/Coursework/Semester2/BZD6004/Group/final/"
            "data_collection/processed/county_1940_albers.parquet"
        ),
        Path(__file__).parent.parent / "data" / "county_1940_albers.parquet",
    ]
    county_pq = next((p for p in cand if p.exists()), None)
    if county_pq is None:
        print("Figure 1: county parquet not found, skipping")
        return
    county = gpd.read_parquet(county_pq)
    gdf = county.merge(shi, left_on="GISJOIN", right_on="gisjoin", how="left")
    gdf = gdf.cx[-2.5e6:2.5e6, -2e6:3.5e6]

    fig, ax = plt.subplots(figsize=(12, 7))
    gdf.plot(
        column="shi", cmap="viridis", linewidth=0.1,
        edgecolor="white", legend=True,
        legend_kwds={"label": "Soil Heterogeneity Index (1 − HHI)", "shrink": 0.6},
        ax=ax, missing_kwds={"color": "#eeeeee"},
    )
    ax.set_title("Figure 1: County-level Soil Heterogeneity Index — CONUS", fontsize=13)
    ax.set_axis_off()
    fig.tight_layout()
    fig.savefig(FIGS / "figure1_shi_map.png", dpi=180, bbox_inches="tight")
    plt.close(fig)
    print("  saved figure1_shi_map.png")


def fig2_lni_map() -> None:
    panel = load_panel()
    if "lni" not in panel.columns:
        print("Figure 2: lni column not present — waiting for IPUMS pipeline")
        return
    import geopandas as gpd
    lni = panel[panel["year"] == 1940][["gisjoin", "lni"]]
    county_pq = Path(
        "/Users/ab180/Desktop/Coursework/Semester2/BZD6004/Group/final/"
        "data_collection/processed/county_1940_albers.parquet"
    )
    if not county_pq.exists():
        print("Figure 2: county parquet missing")
        return
    county = gpd.read_parquet(county_pq)
    gdf = county.merge(lni, left_on="GISJOIN", right_on="gisjoin", how="left")
    gdf = gdf.cx[-2.5e6:2.5e6, -2e6:3.5e6]

    fig, ax = plt.subplots(figsize=(12, 7))
    gdf.plot(
        column="lni", cmap="magma", linewidth=0.1,
        edgecolor="white", legend=True,
        legend_kwds={"label": "Local Name Index (1940)", "shrink": 0.6},
        ax=ax, missing_kwds={"color": "#eeeeee"},
    )
    ax.set_title("Figure 2: County-level Local Name Index 1940 — CONUS", fontsize=13)
    ax.set_axis_off()
    fig.tight_layout()
    fig.savefig(FIGS / "figure2_lni_map.png", dpi=180, bbox_inches="tight")
    plt.close(fig)
    print("  saved figure2_lni_map.png")


def fig3_event_study() -> None:
    mn2_path = (
        Path(__file__).parent.parent / "data" / "MigrantsNative_2.csv"
    )
    if not mn2_path.exists():
        print("Figure 3: MigrantsNative_2.csv not built — waiting for linked census")
        return

    import statsmodels.api as sm
    d = pd.read_csv(mn2_path)
    # Expected columns (from paper's Section 5):
    #   lni, birth_year_rel (−5..7+), shi_destination, family_id,
    #   child_gender, child_birth_order, cohort_fe
    if "birth_year_rel" not in d.columns:
        print("Figure 3: expected columns not in MigrantsNative_2")
        return

    # Simplified event-study: regress lni on interactions of
    # (birth_year_rel dummies) × SHI, family FE, cluster by county
    d["birth_year_rel_c"] = d["birth_year_rel"].clip(-5, 7).astype(int)
    rel_dummies = pd.get_dummies(d["birth_year_rel_c"], prefix="b", dtype=float)
    interactions = rel_dummies.multiply(d["shi_destination"], axis=0)
    interactions.columns = [f"{c}_x_shi" for c in interactions.columns]
    fam_dummies = pd.get_dummies(d["family_id"], prefix="f", drop_first=True,
                                 dtype=float)
    X = pd.concat(
        [pd.Series(1.0, index=d.index, name="const"),
         rel_dummies, interactions, fam_dummies],
        axis=1,
    )
    y = d["lni"].astype(float)
    res = sm.OLS(y, X).fit(cov_type="cluster",
                           cov_kwds={"groups": d["county_id"]})

    # Extract β_b coefficients
    rows = []
    for b in sorted(d["birth_year_rel_c"].unique()):
        key = f"b_{b}_x_shi"
        if key in res.params.index:
            rows.append(
                {"b": b, "beta": res.params[key],
                 "lo": res.conf_int().loc[key, 0],
                 "hi": res.conf_int().loc[key, 1]}
            )
    r = pd.DataFrame(rows)
    fig, ax = plt.subplots(figsize=(8, 5))
    ax.errorbar(r["b"], r["beta"], yerr=[r["beta"] - r["lo"], r["hi"] - r["beta"]],
                fmt="o-", color="navy")
    ax.axhline(0, color="gray", lw=0.8)
    ax.axvline(-0.5, color="crimson", lw=1, linestyle="--", label="move year")
    ax.set_xlabel("Birth year relative to move")
    ax.set_ylabel("β_b (LNI × SHI destination)")
    ax.set_title("Figure 3: Event study of LNI around family's move")
    ax.legend()
    fig.tight_layout()
    fig.savefig(FIGS / "figure3_event_study.png", dpi=180)
    plt.close(fig)
    print("  saved figure3_event_study.png")


def main() -> None:
    fig1_shi_map()
    fig2_lni_map()
    fig3_event_study()


if __name__ == "__main__":
    main()
