"""Shared helpers for the analysis scripts.

Loads the master `CountyLevelData.csv` panel and provides a single helper
for running the paper's preferred specification:

    y ~ shi + geo-climatic controls + smooth-location polynomial
        + state-by-year FE, clustered SE at state (proxy for grid clusters)

Usage:
    from _common import load_panel, run_main_spec
    panel = load_panel()
    res = run_main_spec(panel, "lni", year=None)
    print(res.summary())
"""

from __future__ import annotations

from pathlib import Path
from typing import Iterable

import pandas as pd
import statsmodels.api as sm


HERE = Path(__file__).resolve().parent
DATA = HERE.parent / "data"
FIGS = HERE.parent / "figures"
FIGS.mkdir(exist_ok=True)

CONTROL_COLS_FULL = [
    "mean_elevation_m",
    "mean_slope_deg",
    "mean_annual_temp_c",
    "mean_annual_precip_mm",
    "mean_flow_accum",
    "river_density",
    "centroid_lat",
    "centroid_lon",
    "lat_sq",
    "lon_sq",
    "lat_x_lon",
]


def load_panel() -> pd.DataFrame:
    return pd.read_csv(DATA / "CountyLevelData.csv")


def run_main_spec(
    panel: pd.DataFrame,
    y_col: str,
    year: int | None = None,
    ctrls: Iterable[str] = CONTROL_COLS_FULL,
    cluster_col: str = "state",
    state_by_year_fe: bool = True,
) -> sm.regression.linear_model.RegressionResultsWrapper:
    """Paper Section 3.2 preferred specification.

    y = β·shi + X·Γ + state-by-year FE + ε
    SE clustered at state (proxy for Bester-Conley-Hansen grid clusters).
    """
    d = panel.copy()
    if year is not None:
        d = d[d["year"] == year]
    needed = ["shi", y_col, cluster_col, *ctrls]
    d = d.dropna(subset=needed)
    if d.empty:
        raise ValueError(f"No rows after dropping NA on {needed}")

    X_parts = [pd.Series(1.0, index=d.index, name="const"),
               d[["shi", *ctrls]]]

    if state_by_year_fe and "year" in d.columns and d["year"].nunique() > 1:
        sy = d["state"].astype(str) + "_" + d["year"].astype(str)
        X_parts.append(
            pd.get_dummies(sy, prefix="sy", drop_first=True, dtype=float)
        )
    else:
        X_parts.append(
            pd.get_dummies(d[cluster_col], prefix="st", drop_first=True,
                           dtype=float)
        )

    X = pd.concat(X_parts, axis=1)
    y = d[y_col].astype(float)
    return sm.OLS(y, X).fit(
        cov_type="cluster", cov_kwds={"groups": d[cluster_col]}
    )


def format_row(res, key: str = "shi") -> str:
    coef = res.params[key]
    se = res.bse[key]
    p = res.pvalues[key]
    n = int(res.nobs)
    stars = (
        "***" if p < 0.01 else
        "**" if p < 0.05 else
        "*" if p < 0.10 else ""
    )
    return f"{key}: {coef:+.4f}{stars} (SE={se:.4f}, p={p:.3f}, n={n:,})"
