# Learning Potential (Fertilizer) — Data Construction

## Overview

The Learning Potential index measures the county-level average standardized mean agro-climatic **potential crop yield difference between low and high inputs** for the main crops in 1930. It serves as a proxy for how much a farmer could gain from switching from low-input to high-input farming practices — i.e., the incentive to learn and adopt new agricultural technologies.

---

## Data Sources

| Data | Provider | Access |
|---|---|---|
| Historical county boundaries | Manson et al. (2020) — **NHGIS** (nhgis.org) | Free, registration required |
| Agro-climatic potential yield rasters | **FAO / IIASA GAEZ** (2020) (gaez.iiasa.ac.at) | Free, registration required |
| Crop acreage shares (1930) | Manson et al. (2020) — **NHGIS** agricultural census | Free, registration required |

---

## Step-by-Step Construction

### Step 1: Download GAEZ Yield Rasters

From the [FAO/IIASA GAEZ v4 portal](https://gaez.fao.org), download **two sets** of potential yield rasters for each of the five crops:

| Crop | GAEZ Crop Code |
|---|---|
| Maize | `maiz` |
| Wheat | `whea` |
| Cotton | `cott` |
| Oat | `oats` |
| Fodder / Grass | `gras` (or equivalent) |

Settings:
- **Time period**: 1961–1990 (historical climate baseline)
- **Water supply**: Irrigation, available water content = 200 mm/m
- **Input levels**: Download separately for **low input** and **high input**

---

### Step 2: Compute Yield Difference Rasters

For each crop $k$, compute a pixel-level yield difference raster:

$$\Delta Y_k = Y_k^{\text{high input}} - Y_k^{\text{low input}}$$

Then standardize each difference raster to z-scores:

$$\Delta \tilde{Y}_k = \frac{\Delta Y_k - \mu_k}{\sigma_k}$$

```python
import rasterio
import numpy as np

with rasterio.open("maiz_high.tif") as h, rasterio.open("maiz_low.tif") as l:
    diff = h.read(1).astype(float) - l.read(1).astype(float)

# Standardize
diff_std = (diff - np.nanmean(diff)) / np.nanstd(diff)
```

---

### Step 3: Download Historical County Boundaries from NHGIS

From [nhgis.org](https://nhgis.org), download **GIS shapefiles** for U.S. county boundaries for each relevant decade (1850–1940). Use the boundaries corresponding to the **contemporary period** of interest (the paper uses contemporary U.S. county borders for the zonal statistics).

---

### Step 4: Zonal Statistics — Aggregate Rasters to County Level

For each crop $k$ and each county $c$, compute the mean standardized yield difference over all pixels within the county boundary:

$$\overline{\Delta \tilde{Y}}_{ck} = \text{mean of } \Delta \tilde{Y}_k \text{ within county } c$$

```python
from rasterstats import zonal_stats
import geopandas as gpd

counties = gpd.read_file("county_1930.shp")

for crop in ["maiz", "whea", "cott", "oats", "gras"]:
    stats = zonal_stats(counties, f"{crop}_diff_std.tif", stats=["mean"])
    counties[f"diff_{crop}"] = [s["mean"] for s in stats]
```

---

### Step 5: Weighted Average Across Crops

Weight each crop's yield difference by its **acreage share in 1930** (from NHGIS agricultural census data):

$$\text{gains5}_c = \sum_{k=1}^{5} w_{ck} \cdot \overline{\Delta \tilde{Y}}_{ck}$$

where $w_{ck}$ is the share of county $c$'s total cropland planted with crop $k$ in 1930, and $\sum_k w_{ck} = 1$.

```python
crop_cols = ["diff_maiz", "diff_whea", "diff_cott", "diff_oats", "diff_gras"]
weight_cols = ["share_maiz", "share_whea", "share_cott", "share_oats", "share_gras"]

counties["gains5"] = sum(
    counties[w] * counties[d]
    for w, d in zip(weight_cols, crop_cols)
)
```

> **Note**: The paper also constructs a `gains3` variant using only three crops (excluding cotton and fodder), for robustness.

---

### Step 6: Binarize into High / Low Learning Potential

Split counties at the **median** of `gains5`:

$$\text{high.gains5}_c = \mathbf{1}[\text{gains5}_c > \text{median}(\text{gains5})]$$

```python
counties["high_gains5"] = (counties["gains5"] > counties["gains5"].median()).astype(int)
```

---

### Step 7: Repeat for Each Decade

Repeat Steps 3–6 using the county boundaries for each relevant census decade (1850, 1860, ..., 1940), keeping the same GAEZ rasters (1961–1990 climate baseline is fixed).

---

## Output Variables

| Variable | Description |
|---|---|
| `gains5` | Continuous learning potential index (5-crop weighted average of standardized yield differences) |
| `high.gains5` | Binary: 1 if `gains5` above median, 0 otherwise |
| `gains3` | Same as `gains5` but using only 3 crops (robustness check) |
| `high.gains` | Binary version of `gains3` |

These variables are stored in **`FertilizerData.csv`** and **`WheatShareData.csv`** alongside the outcome variables (`g_shareFertilizer`, `g_shareWheat`) and controls.

---

## Notes

- The GAEZ rasters cover the **1961–1990 climate period** and are used as a time-invariant proxy for agro-climatic potential — the assumption being that the relative yield potential across counties is stable over time.
- The use of **historical county boundaries** from NHGIS is important because U.S. county borders changed substantially between 1850 and 1940.
- The **irrigation condition** (200 mm/m available water content) in the high-input scenario captures the maximum achievable yield gain, making it a clean upper bound for learning potential.

---

## References

- Manson, S., et al. (2020). IPUMS National Historical Geographic Information System. Version 15.0. Minneapolis: University of Minnesota. https://nhgis.org
- FAO and IIASA (2020). Global Agro-Ecological Zones (GAEZ v4). https://gaez.fao.org
