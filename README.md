# Replication: Soil Heterogeneity, Social Learning, and Close-Knit Communities

> Raz, I. T. (2025). *Soil Heterogeneity, Social Learning, and the Formation of Close-Knit Communities.* **Journal of Political Economy**, 133(8), 2643-2691.

NUS BZD6004 Applied Econometrics II, Semester 2, 2025-2026.

---

## Preview

![SHI Map](figures/figure1_shi_map.png)
![SHI vs Fertilizer](figures/shi_vs_fertilizer_1920.png)
![Trends](figures/variable_trends.png)

---

## Quick start

```python
import pandas as pd
panel = pd.read_parquet("data/CountyLevelData.parquet")  # 1.9 MB
```

Or open `notebooks/replication.ipynb` for the full walkthrough with explanations.

---

## Replication results

All regressions use state FE + geo-climatic controls unless noted otherwise. Standard errors clustered or HC1 robust.

### Table 1 — SHI → Community outcomes (cross-sectional with full controls)

Controls include sustainability indices + higher-order controls (SDs). RHI uses all 7 available years (1850, 1860, 1870, 1890, 1906, 1916, 1926).

| Panel | Outcome | SHI coef | p-value | n | Paper expects | Match? |
|---|---|---|---|---|---|---|
| **B** | RHI (religious homogeneity) | **−0.062***  | 0.000 | **16,682** | negative | **yes** |
| **B** | ICM (marriage homogeneity) | −0.007 | 0.544 | 6,835 | negative | direction yes, not sig. |
| **C** | TNI (tight norms) | +0.728*** | 0.000 | 3,438 | negative | **no** (note 1) |

### Table 2 — SHI → Communal identity and farming (cross-sectional)

| Panel | Outcome | SHI coef | p-value | n | Paper expects | Match? |
|---|---|---|---|---|---|---|
| **A** | Share farmers (full count) | **−0.103***  | 0.000 | 9,273 | — | SHI reduces farming share |
| **B** | LNI (1% sample) | **−1.032*** | 0.059 | 19,517 | negative | **yes** (note 2) |
| **C** | ICM | −0.007 | 0.544 | 6,835 | negative | direction yes |
| **D** | Ag Diversity | **+0.062***  | 0.000 | 14,078 | positive | **yes** |
| **D** | Farm size Gini | +0.030*** | 0.000 | 21,125 | — | — |
| **D** | BPD (full count) | +0.023 | 0.173 | 9,270 | — | — |

### Table 2 Panel A — Farming experience (county-level Census Linking, non-consecutive)

Using Census Linking Project crosswalks + HISTID to track individuals across censuses. Sample: white native household heads who moved to a different county.

| Crosswalk | Linked movers | SHI → Farmer at t2 | p-value |
|---|---|---|---|
| 1850→1880 | 406,325 | +0.047*** | 0.000 |
| **1870→1880** | **312,946** | **+0.054***  | **0.000** |
| 1880→1910 | 728,790 | +0.144*** | 0.000 |

### Table 2 — Individual-level regression (consecutive crosswalks, Jiayi's spec)

Regression: outcome_i = β·SHI_d + ε_i. Census Linking with consecutive decade crosswalks. County-level movers (not state-only). SE clustered at destination county.

**Panel A: Premigration farming experience**

| Crosswalk | SHI coef | p-value | n |
|---|---|---|---|
| 1850→1860 | −0.042 | 0.476 | 249,817 |
| 1860→1870 | −0.012 | 0.803 | 465,537 |
| 1870→1880 | +0.047 | 0.393 | 581,708 |

Not significant at individual level. The paper uses origin-destination-state-year FE and the exact raster-based SHI which may yield stronger identification.

**Panel C: Individual-level ICM (spouse same birthplace)**

| Crosswalk | SHI coef | p-value | n |
|---|---|---|---|
| 1870→1880 | **−0.088*** | 0.078 | 536,497 |

SHI reduces the probability of marrying someone from the same birthplace — direction matches the paper.

**Panel C alternative: Children-based migration identification**

851,151 single-mover families identified (children with exactly 2 different birth states, indicating exactly one move). This sample is ready for further regression analysis without requiring Census Linking crosswalks.



### Table 4 — Long-run migration (Census Linking, 40 years)

| Crosswalk | Linked movers | SHI → Farmer at t2 | SHI → Same BPL couple |
|---|---|---|---|
| **1860→1900** | **445,644** | **+0.035***  | **+0.003**  |

### Table 5 — SHI → Fertilizer and wheat adoption (Jiayi's regression-ready data)

Using Jiayi's data with all controls + grid clusters + sustainability indices.

| Outcome | SHI25 coef | p-value | n | Paper expects | Match? |
|---|---|---|---|---|---|
| **Fertilizer growth** | **−0.646***  | 0.002 | 8,933 | negative | **yes** |
| **Wheat share growth** | **−0.387**  | 0.017 | 19,431 | negative | **yes** |
| Fertilizer share (level) | +0.139*** | 0.000 | 9,170 | — | level, not growth |
| Wheat share (level) | +0.018** | 0.031 | 21,091 | — | level, not growth |

---

## Notes on results

1. **TNI direction mismatch (+0.73 vs expected negative):** Our SHI uses within-county area-share HHI, not the paper's 500m raster neighbor-dissimilarity method. The TNI relationship appears sensitive to the SHI measurement method. Ryan is reconstructing the exact raster-based SHI.

2. **LNI attenuation (−1.03 vs paper's −2.49):** We use a 1% census sample; the paper uses full count. The 1% sample introduces measurement error in county-level LNI, causing classical attenuation bias (coefficients shrink toward zero). Direction matches.

3. **Fertilizer level vs growth:** The positive coefficient on fertilizer share (level) but negative on growth rate is not contradictory — the paper's test of the social learning channel uses the growth rate, not the level.

4. **Census Linking farming result (+0.05):** Movers to heterogeneous-soil counties are slightly more likely to be farming at destination. This reflects selection (farmers are drawn to areas with diverse agricultural opportunities), not a causal effect of SHI on becoming a farmer.

---

## Master panel: CountyLevelData (38 columns)

27,989 rows = ~3,100 counties × 9 census decades (1850-1940). Available as `.parquet` (1.9 MB) and `.csv` (11 MB).

### Core variables
| Column | Description | Source | Years |
|---|---|---|---|
| `shi` | Soil Heterogeneity Index | STATSGO2 | all |
| `lni_1pct` | Local Name Index (1% sample) | IPUMS 1% | 1850-1930 |
| `tni_z` | Tight Norms Index (z-scored) | IPUMS full count | 1900, 1910, 1940 |
| `icm_rate` | Intra-Community Marriage rate | IPUMS full count | 1880-1940 |
| `share_farmers_fc` | Share farmer households | IPUMS full count | 1850-1940 |
| `bpd_fc` | Birth Place Diversity | IPUMS full count | 1850-1940 |
| `divorce_ratio` | Divorce/marriage ratio (SFT) | IPUMS full count | 1850-1940 |
| `elderly_alone_share` | Elderly living alone (SFT) | IPUMS full count | 1850-1940 |

### Controls
| Column | Source |
|---|---|
| `mean_elevation_m`, `mean_slope_deg` | HydroSHEDS |
| `mean_annual_temp_c`, `mean_annual_precip_mm` | WorldClim 2.1 |
| `mean_flow_accum`, `river_density` | HydroSHEDS |
| `centroid_lat/lon`, `lat_sq`, `lon_sq`, `lat_x_lon` | Smooth location polynomial |

### Time-varying (NHGIS)
| Column | Years | Source |
|---|---|---|
| `share_farms_reporting_fert` | 1910-1930 | NHGIS Ag Census |
| `wheat_share_of_farmland` | 1880-1935 | NHGIS Ag Census |
| `ag_diversity_index` | 1880-1935 | NHGIS Ag Census |
| `religious_diversity_index` | 1850-1926 | NHGIS Religious Bodies |
| `farm_size_gini` | 1860-1940 | NHGIS Ag Census |
| `slave_share` | 1850-1860 | NHGIS Pop Census |

---

## Data sources

| Source | URL | Used for |
|---|---|---|
| [IPUMS NHGIS](https://www.nhgis.org/) | nhgis.org | County boundaries + historical tabular data |
| [IPUMS USA](https://usa.ipums.org/) | usa.ipums.org | Full-count census (TNI, ICM, farmers, SFT, BPD) + 1% sample (LNI) |
| [USDA STATSGO2](https://www.nrcs.usda.gov/) | nrcs.usda.gov | Soil polygons → SHI |
| [HydroSHEDS v1](https://www.hydrosheds.org/) | hydrosheds.org | Elevation, slope, flow accumulation, river density |
| [WorldClim v2.1](https://www.worldclim.org/) | worldclim.org | Temperature, precipitation |
| [MIT Election Lab](https://electionlab.mit.edu/) | electionlab.mit.edu | County presidential returns |
| [Census Linking Project](https://censuslinkingproject.org/) | censuslinkingproject.org | Individual linkage across censuses (HISTID) |

---

## How data was merged

1. **County skeleton**: NHGIS 1940 shapefile (3,108 counties) × 9 decades
2. **SHI** (time-invariant): STATSGO2 soil polygons → spatial overlay with county boundaries → area-share HHI
3. **Geo-climatic controls** (time-invariant): Zonal statistics from HydroSHEDS DEM + WorldClim rasters
4. **Smooth location** (time-invariant): County centroid lat/lon + polynomial terms
5. **NHGIS variables** (time-varying): Agricultural census, religious bodies, population census → left-join by `gisjoin × year`
6. **IPUMS full count** (usa_00006, 664M rows): DuckDB queries on 17 GB parquet → TNI, ICM, farmer share, SFT, BPD → left-join by `gisjoin × year`
7. **LNI** (time-varying): IPUMS 1% samples, 870k children, 1850-1930 → county-mean LNI → left-join
8. **Census Linking**: Crosswalk CSVs + HISTID merge for individual-level linked analysis (Tables 2A, 4)
9. **County join key**: `GISJOIN = G + STATEFIP(2 digits) + 0 + COUNTYICP/10(3 digits) + 0`

---

## What we could not replicate

| What | Why |
|---|---|
| LNI for 1940 | IPUMS does not release 1940 names in any public sample (contractual restriction) |
| Exact SHI values | We use area-share HHI; paper uses 500m raster neighbor dissimilarity. Ryan is working on the exact version. |
| Learning potential index (Table 5) | Author-constructed index not yet available from public sources |
| Exact coefficient magnitudes | 1% sample for LNI → attenuation bias; simplified SHI → different scale |

---

---

## Teammate contributions

| File | From | Description |
|---|---|---|
| `FertilizerData_Jiayi.csv` | Jiayi | Regression-ready Table 5 data (76 cols: all SHI variants, controls, grid clusters) |
| `WheatShareData_Jiayi.csv` | Jiayi | Regression-ready Table 5 Panel B (74 cols) |
| `sustainability_index/` | Jiayi | Crop sustainability indices (10 crops) |
| `nhgis0003_ds74_1936_county.csv` | Vicky | 1936 Religious Bodies Census |
| `linked_1850_1880_movers.parquet` | — | Census Linking output: 406k linked movers (parquet, 20 MB) |
| `docs/` | Jiayi/Vicky | Variable construction guides (TNI, ICM, RHI, SHI methodology) |

---

## File structure

```
├── README.md
├── requirements.txt
├── notebooks/
│   └── replication.ipynb               ← main analysis notebook
├── data/
│   ├── CountyLevelData.parquet (.csv)  ← master panel (38 cols, 1.9 MB)
│   ├── FertilizerData_Jiayi.csv        ← regression-ready (76 cols)
│   ├── WheatShareData_Jiayi.csv        ← regression-ready (74 cols)
│   ├── linked_1850_1880_movers.parquet     ← Census Linking output
│   ├── ipums006_*.parquet (.csv)       ← TNI, ICM, farmers, SFT, BPD
│   ├── LNI_by_county.parquet (.csv)    ← LNI (1% sample)
│   ├── sustainability_index/           ← crop sustainability rasters
│   └── [other CSVs + parquets]
├── analysis/                           ← standalone regression scripts
├── figures/                            ← pre-rendered plots + regression output txt
└── docs/                               ← variable construction methodology guides
```

All Parquet files have matching CSVs. Parquet is 5-7x smaller and loads faster; CSV works in Excel, R, and Stata.
