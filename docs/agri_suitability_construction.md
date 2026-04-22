# County-Level Agricultural Suitability Index: Construction Guide

## Overview

This document describes how to construct county-level mean agricultural suitability indices for the 10 most important crops by total output value in 1859, following the methodology described in the paper.

**Key parameters:**
- Input level: Intermediate (rain-fed)
- Climate baseline: 1961–1990
- Suitability data source: FAO and IIASA (2012), GAEZ v3.0
- County boundary source: Manson et al. (2020), IPUMS NHGIS

---

## Step 1: Identify the 10 Target Crops

The 10 crops are selected based on their total output value in 1859 (from the agricultural census):

| Crop | GAEZ v3 Name |
|------|-------------|
| Alfalfa | Alfalfa |
| Cotton | Cotton |
| Maize | Maize |
| Oat | Oat |
| Rye | Rye |
| Sugarcane | Sugar cane |
| Sweet potato | Sweet potato |
| Tobacco | Tobacco |
| Wheat | Wheat |
| White potato | White potato |

**Data source for crop ranking:** IPUMS NHGIS agricultural census tables, 1860 (corresponding to 1859 output values). Download at: https://nhgis.org

---

## Step 2: Download Suitability Rasters (GAEZ v3.0)

**Source:** FAO and IIASA (2012). *Global Agro-ecological Zones (GAEZ v3.0)*. IIASA, Laxenburg, Austria and FAO, Rome, Italy.

**Portal:** https://www.gaez.iiasa.ac.at/

**Selection parameters for each crop:**

| Parameter | Value |
|-----------|-------|
| Theme | Suitability and Potential Yield → Agro-ecological suitability and productivity |
| Variable | **Crop suitability index (value)** |
| Water supply | **Rain-fed** |
| Input level | **Intermediate** |
| Time period | **Baseline (1961–1990)** |

**Download format:** ZIPped ASCII Grid (`.asc`)

Repeat for all 10 crops. You will end up with 10 `.asc` raster files, each with suitability index values ranging from 0 to 100.

---

## Step 3: Download Historical County Boundaries (NHGIS)

**Source:** Manson, S., Schroeder, J., Van Riper, D., Kugler, T., & Ruggles, S. (2020). *IPUMS National Historical Geographic Information System: Version 15.0*. Minneapolis, MN: IPUMS. https://doi.org/10.18128/D050.V15.0

**Portal:** https://nhgis.org

Download county boundary shapefiles for each decade of interest (e.g., 1850, 1860, 1870, ..., 1940). Select:
- Geographic level: **County**
- Years: each decade as needed
- File format: **Shapefile**

---

## Step 4: Compute County-Level Mean Suitability Index (GIS)

For each crop × decade combination, spatially aggregate the raster values to the county level.

### Using Python (`rasterstats`)

```python
import geopandas as gpd
from rasterstats import zonal_stats
import pandas as pd

# Load county boundaries for a given decade
counties = gpd.read_file("nhgis_county_1880.shp")

# Ensure CRS matches raster (EPSG:4326)
counties = counties.to_crs("EPSG:4326")

crops = {
    "alfalfa":      "gaez_v3/alfalfa_intermediate_rainfed_baseline.asc",
    "cotton":       "gaez_v3/cotton_intermediate_rainfed_baseline.asc",
    "maize":        "gaez_v3/maize_intermediate_rainfed_baseline.asc",
    "oat":          "gaez_v3/oat_intermediate_rainfed_baseline.asc",
    "rye":          "gaez_v3/rye_intermediate_rainfed_baseline.asc",
    "sugarcane":    "gaez_v3/sugarcane_intermediate_rainfed_baseline.asc",
    "sweet_potato": "gaez_v3/sweet_potato_intermediate_rainfed_baseline.asc",
    "tobacco":      "gaez_v3/tobacco_intermediate_rainfed_baseline.asc",
    "wheat":        "gaez_v3/wheat_intermediate_rainfed_baseline.asc",
    "white_potato": "gaez_v3/white_potato_intermediate_rainfed_baseline.asc",
}

results = counties[["GISJOIN", "geometry"]].copy()

for crop_name, raster_path in crops.items():
    stats = zonal_stats(
        counties,
        raster_path,
        stats=["mean"],
        nodata=-9999,
        all_touched=False   # only pixels whose centroid falls within polygon
    )
    results[f"suit_{crop_name}"] = [s["mean"] for s in stats]

results.drop(columns="geometry").to_csv("suitability_1880.csv", index=False)
```

### Using R (`terra` + `exactextractr`)

```r
library(terra)
library(sf)
library(exactextractr)
library(dplyr)

# Load county shapefile
counties <- st_read("nhgis_county_1880.shp") |>
  st_transform(4326)

crops <- c("alfalfa", "cotton", "maize", "oat", "rye",
           "sugarcane", "sweet_potato", "tobacco", "wheat", "white_potato")

results <- counties |> select(GISJOIN)

for (crop in crops) {
  r <- rast(paste0("gaez_v3/", crop, "_intermediate_rainfed_baseline.asc"))
  results[[paste0("suit_", crop)]] <- exact_extract(r, counties, "mean")
}

st_drop_geometry(results) |>
  write.csv("suitability_1880.csv", row.names = FALSE)
```

---

## Step 5: Repeat for Each Decade

The suitability rasters are time-invariant (based on 1961–1990 climate baseline), but county boundaries change across decades. Repeat Step 4 for each decade's shapefile to get a panel dataset.

```python
decades = [1850, 1860, 1870, 1880, 1900, 1910, 1920, 1930, 1940]

all_results = []
for decade in decades:
    counties = gpd.read_file(f"nhgis_county_{decade}.shp").to_crs("EPSG:4326")
    df = counties[["GISJOIN"]].copy()
    df["decade"] = decade
    for crop_name, raster_path in crops.items():
        stats = zonal_stats(counties, raster_path, stats=["mean"], nodata=-9999)
        df[f"suit_{crop_name}"] = [s["mean"] for s in stats]
    all_results.append(df)

panel = pd.concat(all_results, ignore_index=True)
panel.to_csv("suitability_panel.csv", index=False)
```

---

## Step 6: Output Format

The final dataset is a county × decade panel with the following structure:

| GISJOIN | decade | suit_alfalfa | suit_cotton | suit_maize | ... | suit_white_potato |
|---------|--------|-------------|-------------|-----------|-----|-------------------|
| G010010 | 1860 | 45.2 | 12.8 | 67.4 | ... | 38.1 |
| G010010 | 1870 | 45.2 | 12.8 | 67.4 | ... | 38.1 |
| ... | ... | ... | ... | ... | ... | ... |

> **Note:** Suitability values are constant across decades for the same county (rasters do not vary over time). Changes across decades within a county reflect boundary changes only.

---

## Data Sources & Citations

- **Suitability rasters:** IIASA/FAO. (2012). *Global Agro-ecological Zones (GAEZ v3.0)*. IIASA, Laxenburg, Austria and FAO, Rome, Italy. Available at: https://www.gaez.iiasa.ac.at/
- **County boundaries:** Manson, S., Schroeder, J., Van Riper, D., Kugler, T., & Ruggles, S. (2020). *IPUMS National Historical Geographic Information System: Version 15.0*. Minneapolis, MN: IPUMS. https://doi.org/10.18128/D050.V15.0
- **1859 crop output values:** IPUMS NHGIS, 1860 Agricultural Census. https://nhgis.org
