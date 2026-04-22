# Soil Heterogeneity Index (SHI): Construction Guide

## Overview

The Soil Heterogeneity Index (SHI) captures the **average dissimilarity of soil across neighboring farmers** at the county level. It is constructed from the Digital General Soil Map of the United States (STATSGO2) and aggregated to contemporary U.S. counties using historical boundary data.

**Key parameters:**
- Soil data: STATSGO2 (Soil Survey Staff, 2017)
- Raster resolution: 500 meters × 500 meters
- Neighborhood window: 51 × 51 cells (25 cells in each direction)
- County boundaries: Manson et al. (2020), IPUMS NHGIS
- Coverage: All contemporary U.S. counties, each decade

---

## Data Sources

### 1. Soil Data — STATSGO2
**Source:** Soil Survey Staff. (2017). *Digital General Soil Map of the United States (STATSGO2)*. USDA Natural Resources Conservation Service.

**Download:** https://www.nrcs.usda.gov/resources/data-and-reports/description-of-the-statsgo2-database

- Contains soil map unit polygon features for the continental U.S.
- Scale: 1:250,000
- Key field: **soil map unit key (mukey)** — the identifier used to distinguish soil types

### 2. County Boundaries — IPUMS NHGIS
**Source:** Manson, S., Schroeder, J., Van Riper, D., Kugler, T., & Ruggles, S. (2020). *IPUMS National Historical Geographic Information System: Version 15.0*. Minneapolis, MN: IPUMS. https://doi.org/10.18128/D050.V15.0

**Download:** https://nhgis.org

- Download county shapefiles for each decade (1850–1940)
- File format: Shapefile (.shp)

---

## Construction Steps

### Step 1: Rasterize STATSGO2

Convert the STATSGO2 soil polygon map into a raster with **500m × 500m cells**, where each cell is assigned the soil map unit ID (mukey) of the polygon it falls within.

```python
import subprocess
import os

# Input: STATSGO2 shapefile
# Output: raster where each cell = soil map unit ID (mukey)

input_shp = "gssurgo_conus.shp"       # STATSGO2 polygon shapefile
output_tif = "statsgo2_500m.tif"      # output raster

# Use GDAL to rasterize at 500m resolution
# EPSG:5070 = Albers Equal Area (appropriate for continental US in meters)
subprocess.run([
    "gdal_rasterize",
    "-a", "mukey",            # field to burn into raster
    "-tr", "500", "500",      # cell size: 500m x 500m
    "-a_nodata", "-9999",
    "-ot", "Int32",
    "-of", "GTiff",
    "-t_srs", "EPSG:5070",    # Albers Equal Area projection
    input_shp,
    output_tif
])
```

**Alternatively in R:**
```r
library(terra)
library(sf)

# Load STATSGO2 shapefile
soil <- vect("gssurgo_conus.shp")
soil <- project(soil, "EPSG:5070")

# Create 500m template raster covering continental US
template <- rast(ext(soil), resolution=500, crs="EPSG:5070")

# Rasterize using mukey field
soil_rast <- rasterize(soil, template, field="mukey")
writeRaster(soil_rast, "statsgo2_500m.tif", overwrite=TRUE)
```

---

### Step 2: Calculate Cell-Level SHI

For each 500m cell, calculate the **proportion of neighboring cells that have a different soil map unit** (i.e., a different mukey value).

The neighborhood is defined as a **51 × 51 cell square** (25 cells in each direction from the focal cell), corresponding to approximately half the mean size of U.S. counties in 2000.

```
Window size calculation:
- Mean US county area in 2000 ≈ 3,100 km²
- Half of mean county area ≈ 1,550 km²
- Side length of square with area 1,550 km² ≈ 25 km
- At 500m resolution: 25,000m / 500m = 50 cells → 25 cells each direction
- Total window: 51 × 51 cells
```

```python
import numpy as np
import rasterio
from scipy.ndimage import generic_filter

# Load rasterized soil data
with rasterio.open("statsgo2_500m.tif") as src:
    soil = src.read(1).astype(float)
    profile = src.profile
    nodata = src.nodata or -9999

soil[soil == nodata] = np.nan

def compute_shi_cell(window):
    """
    For a given window of soil mukey values,
    calculate the proportion of neighbors different from the center cell.
    """
    center = window[len(window) // 2]
    if np.isnan(center):
        return np.nan
    neighbors = window[~np.isnan(window)]
    neighbors = neighbors[neighbors != center]  # exclude center itself
    all_neighbors = window[~np.isnan(window)]
    all_neighbors = all_neighbors[np.arange(len(all_neighbors)) != len(all_neighbors)//2]
    if len(all_neighbors) == 0:
        return np.nan
    return np.sum(all_neighbors != center) / len(all_neighbors)

# Apply 51x51 sliding window
window_size = 51  # 25 cells each direction
print("Computing SHI... (this may take a while)")
shi = generic_filter(
    soil,
    compute_shi_cell,
    size=window_size,
    mode='constant',
    cval=np.nan
)

# Save SHI raster
profile.update(dtype=rasterio.float32, nodata=-9999)
shi_out = shi.astype(np.float32)
shi_out[np.isnan(shi_out)] = -9999

with rasterio.open("shi_500m.tif", "w", **profile) as dst:
    dst.write(shi_out, 1)

print("SHI raster saved: shi_500m.tif")
```

> ⚠️ **Computational note:** The 51×51 sliding window over a continental-US 500m raster is very computationally intensive. Consider processing state by state, or using a HPC cluster. The raster will have ~10 billion cells for the full continental US.

**Faster alternative using R (`terra`):**
```r
library(terra)

soil <- rast("statsgo2_500m.tif")

# focal() applies a moving window function
w <- matrix(1, nrow=51, ncol=51)  # 51x51 window of ones

# Custom focal function: proportion of neighbors with different mukey
shi_focal <- function(x) {
  center <- x[ceiling(length(x)/2)]
  if (is.na(center)) return(NA)
  neighbors <- x[-ceiling(length(x)/2)]
  neighbors <- neighbors[!is.na(neighbors)]
  if (length(neighbors) == 0) return(NA)
  sum(neighbors != center) / length(neighbors)
}

shi <- focal(soil, w=w, fun=shi_focal, na.policy="omit")
writeRaster(shi, "shi_500m.tif", overwrite=TRUE)
```

---

### Step 3: Aggregate to County Level

For each county in each decade, calculate the **mean of all grid-level SHI values** falling within the county boundary.

```python
import geopandas as gpd
from rasterstats import zonal_stats
import pandas as pd

decades = [1850, 1860, 1870, 1880, 1900, 1910, 1920, 1930, 1940]
all_results = []

for decade in decades:
    print(f"Processing {decade}...")

    # Load county boundaries for this decade
    counties = gpd.read_file(f"nhgis_county_{decade}.shp")

    # Reproject to match SHI raster CRS (EPSG:5070)
    counties = counties.to_crs("EPSG:5070")

    # Compute mean SHI per county
    stats = zonal_stats(
        counties,
        "shi_500m.tif",
        stats=["mean", "count"],
        nodata=-9999
    )

    df = counties[["GISJOIN"]].copy()
    df["decade"] = decade
    df["SHI"] = [s["mean"] for s in stats]
    df["n_cells"] = [s["count"] for s in stats]
    all_results.append(df)

# Combine all decades
panel = pd.concat(all_results, ignore_index=True)
panel.to_csv("shi_county_panel.csv", index=False)
print("Done. Output: shi_county_panel.csv")
```

**In R:**
```r
library(terra)
library(sf)
library(exactextractr)
library(dplyr)

shi <- rast("shi_500m.tif")
decades <- c(1850, 1860, 1870, 1880, 1900, 1910, 1920, 1930, 1940)

results <- lapply(decades, function(yr) {
  counties <- st_read(paste0("nhgis_county_", yr, ".shp")) |>
    st_transform(crs(shi))
  
  data.frame(
    GISJOIN = counties$GISJOIN,
    decade  = yr,
    SHI     = exact_extract(shi, counties, "mean")
  )
})

panel <- bind_rows(results)
write.csv(panel, "shi_county_panel.csv", row.names=FALSE)
```

---

## Output Format

The final dataset is a county × decade panel:

| GISJOIN | decade | SHI | n_cells |
|---------|--------|-----|---------|
| G010010 | 1850 | 0.412 | 1823 |
| G010010 | 1860 | 0.412 | 1823 |
| G010030 | 1850 | 0.187 | 942 |
| ... | ... | ... | ... |

> **Note:** The SHI raster is time-invariant (soil data does not change across decades). Variation in county-level SHI across decades reflects changes in county boundaries only.

---

## Robustness Checks

The paper documents robustness to different neighborhood window sizes. To replicate, re-run Step 2 with alternative window sizes:

| Window size | Cells each direction | Approx. area |
|-------------|---------------------|--------------|
| 11 × 11 | 5 cells | ~8 km² |
| 31 × 31 | 15 cells | ~225 km² |
| **51 × 51** | **25 cells (baseline)** | **~625 km²** |
| 71 × 71 | 35 cells | ~1,225 km² |
| 101 × 101 | 50 cells | ~2,500 km² |

---

## Data Sources & Citations

- **Soil data:** Soil Survey Staff. (2017). *Digital General Soil Map of the United States (STATSGO2)*. USDA Natural Resources Conservation Service. https://www.nrcs.usda.gov/resources/data-and-reports/description-of-the-statsgo2-database
- **County boundaries:** Manson, S., Schroeder, J., Van Riper, D., Kugler, T., & Ruggles, S. (2020). *IPUMS National Historical Geographic Information System: Version 15.0*. Minneapolis, MN: IPUMS. https://doi.org/10.18128/D050.V15.0
