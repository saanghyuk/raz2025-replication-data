# Learning Potential (Wheat) — Data Construction

## Overview

The Learning Potential (Wheat) index measures the county-level agro-climatic **potential crop yield difference between low and high inputs for wheat only**. Unlike the fertilizer learning potential (`gains5`) which averages across five crops weighted by acreage, this is a **single-crop measure** focused exclusively on wheat yield responsiveness to input intensity. It captures how much a wheat-farming county could gain from adopting higher-input practices.

---

## Data Sources

| Data | Provider | Access |
|---|---|---|
| Historical county boundaries | Manson et al. (2020) — **NHGIS** (nhgis.org) | Free, registration required |
| Wheat agro-climatic potential yield rasters | **FAO / IIASA GAEZ** (2020) (gaez.fao.org) | Free, registration required |

---

## Key Differences from Fertilizer Learning Potential

| | Learning Potential (Fertilizer) | Learning Potential (Wheat) |
|---|---|---|
| Crops | 5 (maize, wheat, cotton, oat, fodder) | **Wheat only** |
| Weighting | Acreage-weighted average across crops | No weighting needed |
| Standardization | Z-score standardized | Raw yield difference |
| Output variable | `gains5` / `high.gains5` | `WheatDiff` / `high.gains` |
| Used in | `FertilizerData.csv` | `WheatShareData.csv` |

---

## Step-by-Step Construction

### Step 1: Download GAEZ Wheat Yield Rasters

From the [FAO/IIASA GAEZ v4 portal](https://gaez.fao.org), download **two** potential yield rasters for wheat:

| Raster | Input Level | Description |
|---|---|---|
| `whea_high.tif` | High input | Yield under high-input / irrigation conditions |
| `whea_low.tif` | Low input | Yield under low-input / rainfed conditions |

Settings:
- **Crop**: Wheat (`whea`)
- **Time period**: 1961–1990 (historical climate baseline)
- **Water supply**: Irrigation, available water content = **200 mm/m**
- **Input levels**: Download separately for **low input** and **high input**

---

### Step 2: Compute the Yield Difference Raster

Compute a pixel-level yield difference raster:

$$\Delta Y_{\text{wheat}} = Y_{\text{wheat}}^{\text{high input}} - Y_{\text{wheat}}^{\text{low input}}$$

```python
import rasterio
import numpy as np

with rasterio.open("whea_high.tif") as h, rasterio.open("whea_low.tif") as l:
    high = h.read(1).astype(float)
    low  = l.read(1).astype(float)
    diff = high - low
    profile = h.profile

# Save difference raster
with rasterio.open("whea_diff.tif", "w", **profile) as dst:
    dst.write(diff, 1)
```

> **Note**: Unlike the fertilizer variant, the paper description does not mention standardizing the wheat difference to z-scores before aggregation — the raw yield difference (in kg/ha or tonnes/ha) is used directly.

---

### Step 3: Download Historical County Boundaries from NHGIS

From [nhgis.org](https://nhgis.org), download **GIS shapefiles** for U.S. county boundaries for each relevant census decade (1850–1940). Use contemporary U.S. county borders as specified in the paper.

---

### Step 4: Zonal Statistics — Aggregate to County Level

For each county $c$, compute the mean wheat yield difference over all pixels within the county boundary:

$$\text{WheatDiff}_c = \text{mean of } \Delta Y_{\text{wheat}} \text{ within county } c$$

```python
from rasterstats import zonal_stats
import geopandas as gpd

counties = gpd.read_file("county_borders.shp")

stats = zonal_stats(counties, "whea_diff.tif", stats=["mean"])
counties["WheatDiff"] = [s["mean"] for s in stats]
```

---

### Step 5: Repeat for Each Decade

Repeat Step 4 using the county boundary shapefile for each relevant census decade (1850, 1860, …, 1940), keeping the same GAEZ rasters throughout (the 1961–1990 climate baseline is time-invariant).

```python
decades = [1850, 1860, 1870, 1880, 1890, 1900, 1910, 1920, 1930, 1940]
results = []

for decade in decades:
    counties = gpd.read_file(f"county_{decade}.shp")
    stats = zonal_stats(counties, "whea_diff.tif", stats=["mean"])
    counties["WheatDiff"] = [s["mean"] for s in stats]
    counties["YEAR"] = decade
    results.append(counties[["GISJOIN", "YEAR", "WheatDiff"]])

panel = pd.concat(results, ignore_index=True)
```

---

### Step 6: Binarize into High / Low Learning Potential

Split counties at the **median** of `WheatDiff`:

$$\text{high.gains}_c = \mathbf{1}[\text{WheatDiff}_c > \text{median}(\text{WheatDiff})]$$

```python
panel["high_gains"] = (panel["WheatDiff"] > panel["WheatDiff"].median()).astype(int)
```

---

## Output Variables

| Variable | Description |
|---|---|
| `WheatDiff` | Continuous: county-level mean wheat yield difference (high input − low input) |
| `high.gains` | Binary: 1 if `WheatDiff` above median, 0 otherwise |

These variables are stored in **`WheatShareData.csv`** alongside the outcome variable (`g_shareWheat`) and controls.

---

## Notes

- The GAEZ rasters reflect **1961–1990 agro-climatic conditions** and are treated as a time-invariant measure of each county's intrinsic wheat yield responsiveness — the underlying assumption is that relative yield potential across counties is stable over time.
- Using **wheat only** (rather than a multi-crop average) makes this measure directly relevant to the outcome variable `g_shareWheat` (growth in wheat acreage share), providing a tighter mechanism test.
- The **irrigation condition** (200 mm/m available water content) in the high-input scenario represents the maximum achievable yield under optimal water management, giving a clean upper bound on learning potential.
- Historical county boundaries from NHGIS are essential because U.S. county borders changed significantly between 1850 and 1940.

---

## References

- Manson, S., et al. (2020). IPUMS National Historical Geographic Information System. Version 15.0. Minneapolis: University of Minnesota. https://nhgis.org
- FAO and IIASA (2020). Global Agro-Ecological Zones (GAEZ v4). https://gaez.fao.org
