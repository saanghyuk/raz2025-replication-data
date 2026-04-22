# Replication: Soil Heterogeneity, Social Learning, and Close-Knit Communities

Replication data and analysis for:

> Raz, I. T. (2025). *Soil Heterogeneity, Social Learning, and the Formation of Close-Knit Communities.* **Journal of Political Economy**, 133(8), 2643-2691.

NUS BZD6004 Applied Econometrics II, Semester 2, 2025-2026.

---

## Preview

### County-level Soil Heterogeneity Index (Figure 1)
![SHI Map](figures/figure1_shi_map.png)

*Source: STATSGO2 soil polygons overlaid onto 1940 county boundaries.*

### SHI vs. Fertilizer adoption (1920)
![SHI vs Fertilizer](figures/shi_vs_fertilizer_1920.png)

### Variable trends across census decades
![Trends](figures/variable_trends.png)

---

## Quick start

Open the notebook for the full analysis:
```
notebooks/replication.ipynb
```

Or load the data directly:
```python
import pandas as pd
panel = pd.read_parquet("data/CountyLevelData.parquet")  # 1.9 MB
```

---

## Replication results

All regressions use state FE + geo-climatic controls + smooth location polynomial, clustered SE.

### Table 1 Panel B — Community structure measures
| Outcome | SHI coefficient | p-value | n | Paper direction | Match? |
|---|---|---|---|---|---|
| **RHI** (religious homogeneity) | **−0.122***  | 0.000 | 5,143 | negative | **yes** |
| **ICM** (marriage homogeneity) | −0.007 | 0.544 | 6,835 | negative | direction yes, not significant |

### Table 1 Panel C — Tight Norms Index
| Outcome | SHI coefficient | p-value | n | Paper direction | Match? |
|---|---|---|---|---|---|
| **TNI** (z-scored) | +0.728*** | 0.000 | 3,438 | negative | no (see note below) |

*Note: TNI direction differs from the paper. This is likely because our SHI uses within-county HHI rather than the paper's raster-based neighbor dissimilarity measure, which may affect the relationship with norm-tightness differently than with other community measures.*

### Table 2 — Main result: SHI → LNI
| Outcome | SHI coefficient | p-value | n | Paper result |
|---|---|---|---|---|
| **LNI** (1% sample) | **−1.032*** | 0.059 | 19,517 | −2.49*** |

Direction matches. Magnitude attenuated due to 1% sample (measurement error → attenuation bias). Nearly significant at 5% level.

### Table 4 — SHI → Agricultural Diversity
| Outcome | SHI coefficient | p-value | n | Paper result |
|---|---|---|---|---|
| **Ag Diversity** | **+0.062***  | 0.000 | 14,078 | positive, significant |

**Matches the paper.** Heterogeneous soil leads to more diverse crop choices.

### Additional results
| Outcome | SHI coefficient | p-value | n |
|---|---|---|---|
| Share farmers (full count) | −0.103*** | 0.000 | 9,273 |
| Farm size Gini | +0.030*** | 0.000 | 21,125 |
| BPD (full count) | +0.023 | 0.173 | 9,270 |

---

## Master panel: CountyLevelData (38 columns)

27,989 rows = ~3,100 counties × 9 census decades (1850-1940).

### Core outcome variables
| Column | Description | Source | Years |
|---|---|---|---|
| `lni_1pct` | Local Name Index (1% sample) | IPUMS 1% | 1850-1930 |
| `tni_z` | Tight Norms Index (z-scored PCA) | IPUMS full count | 1900, 1910, 1940 |
| `icm_rate` | Intra-Community Marriage rate | IPUMS full count | 1880-1940 |
| `share_farmers_fc` | Share farmer households (full count) | IPUMS full count | 1850-1940 |
| `bpd_fc` | Birth Place Diversity (full count) | IPUMS full count | 1850-1940 |
| `divorce_ratio` | Divorce/marriage ratio | IPUMS full count | 1850-1940 |
| `elderly_alone_share` | Elderly living alone | IPUMS full count | 1850-1940 |
| `mean_nchild` | Mean children per HH head | IPUMS full count | 1850-1940 |

### Independent variable
| Column | Description | Source |
|---|---|---|
| `shi` | Soil Heterogeneity Index (1 − HHI over soil types) | STATSGO2 |

### Controls
| Column | Source |
|---|---|
| `mean_elevation_m`, `mean_slope_deg` | HydroSHEDS |
| `mean_annual_temp_c`, `mean_annual_precip_mm` | WorldClim 2.1 |
| `mean_flow_accum`, `river_density` | HydroSHEDS |
| `centroid_lat/lon`, `lat_sq`, `lon_sq`, `lat_x_lon` | Smooth location polynomial |

### Other time-varying
| Column | Years | Source |
|---|---|---|
| `share_farms_reporting_fert` | 1910-1930 | NHGIS |
| `wheat_share_of_farmland` | 1880-1935 | NHGIS |
| `ag_diversity_index` | 1880-1935 | NHGIS |
| `religious_diversity_index` | 1850-1926 | NHGIS |
| `farm_size_gini` | 1860-1940 | NHGIS |
| `slave_share` | 1850-1860 | NHGIS |
| `birth_place_diversity` | 1870-1940 | NHGIS (proxy) |

---

## Data sources

| Source | URL | What we used |
|---|---|---|
| [IPUMS NHGIS](https://www.nhgis.org/) | nhgis.org | County boundaries, agricultural/population/religious census |
| [IPUMS USA](https://usa.ipums.org/) | usa.ipums.org | Full-count census (TNI, ICM, farmer share, SFT, BPD) + 1% sample (LNI) |
| [USDA STATSGO2](https://www.nrcs.usda.gov/) | nrcs.usda.gov | Soil polygons → SHI |
| [HydroSHEDS v1](https://www.hydrosheds.org/) | hydrosheds.org | Elevation, slope, flow, river density |
| [WorldClim v2.1](https://www.worldclim.org/) | worldclim.org | Temperature, precipitation |
| [MIT Election Lab](https://electionlab.mit.edu/) | electionlab.mit.edu | County presidential returns |
| [Census Linking Project](https://censuslinkingproject.org/) | censuslinkingproject.org | Cross-census individual linkage (HISTID) |

---

## How data was merged

1. **County skeleton**: 3,108 counties (NHGIS 1940 shapefile) × 9 decades = base panel
2. **SHI**: STATSGO2 soil polygons → area-share HHI per county (time-invariant)
3. **Geo-climatic controls**: Zonal statistics from HydroSHEDS + WorldClim rasters (time-invariant)
4. **Smooth location**: County centroid lat/lon + polynomial terms (time-invariant)
5. **NHGIS variables**: Fertilizer, wheat, ag diversity, religion, farm Gini, slaves (time-varying by year)
6. **IPUMS full-count** (usa_00006): TNI, ICM, farmer share, SFT, BPD — computed via DuckDB on 17 GB parquet, joined by `GISJOIN = G + STATEFIP + 0 + COUNTYICP/10 + 0`
7. **LNI**: From IPUMS 1% samples (usa_00002), 1850-1930, same GISJOIN mapping

---

## What we could not replicate

| What | Why |
|---|---|
| LNI for 1940 | IPUMS contractual restriction on names in full count and 1940 1% sample |
| Exact SHI values | We use area-share HHI; paper uses raster neighbor dissimilarity (see `docs/shi_construction.md` for the exact method) |
| Learning potential index (Table 5) | Author-constructed index; not yet available from public sources |
| Census Linking regression (Tables 2, 4, 6) | HISTID + crosswalks ready; linked DiD regression not yet implemented |

---

## Additional data from teammates

| File | From | Description |
|---|---|---|
| `FertilizerData_Jiayi.csv` | Jiayi | Regression-ready data (76 cols) with all SHI variants, controls, grid clusters |
| `WheatShareData_Jiayi.csv` | Jiayi | Regression-ready Table 5 Panel B (74 cols) |
| `sustainability_index/` | Jiayi | Crop sustainability indices for 10 crops |
| `nhgis0003_ds74_1936_county.csv` | Vicky | 1936 Religious Bodies Census |
| `docs/` | Jiayi/Vicky | Variable construction guides (TNI, ICM, RHI, SHI, etc.) |

---

## File structure

```
├── README.md
├── requirements.txt
├── notebooks/
│   └── replication.ipynb               ← main analysis notebook
├── data/
│   ├── CountyLevelData.parquet (.csv)  ← master panel (38 cols, 1.9 MB)
│   ├── ipums006_tni (.parquet/.csv)    ← TNI by county-year
│   ├── ipums006_icm (.parquet/.csv)    ← ICM by county-year
│   ├── ipums006_farmers (.parquet/.csv)← farmer share (full count)
│   ├── ipums006_sft (.parquet/.csv)    ← SFT components
│   ├── ipums006_bpd (.parquet/.csv)    ← BPD (full count)
│   ├── LNI_by_county (.parquet/.csv)   ← LNI (1% sample)
│   ├── FertilizerData_Jiayi.csv        ← Jiayi's regression-ready (76 cols)
│   ├── WheatShareData_Jiayi.csv        ← Jiayi's regression-ready (74 cols)
│   ├── sustainability_index/           ← crop sustainability rasters
│   └── [other processed CSVs + parquets]
├── analysis/                           ← standalone regression scripts
├── figures/                            ← pre-rendered plots
└── docs/                              ← variable construction guides
    ├── TNI_indicator_construction_EN.md
    ├── ICM_indicator_construction_EN.md
    ├── RHI_indicator_construction_EN.md
    ├── shi_construction.md
    ├── agri_suitability_construction.md
    ├── learning_potential_data_construction.md
    └── Replication-stepbystep_updated.docx
```

All Parquet files have matching CSVs. Parquet is smaller and faster; CSV works in Excel/R/Stata.

---

## Building from scratch

Processing scripts in `data_collection/scripts/` (numbered 01-24):
- Scripts 01-13: NHGIS + STATSGO2 + HydroSHEDS + WorldClim → county-level controls
- Script 19: IPUMS 1% sample → LNI
- Script 22: IPUMS full count (usa_00006) → parquet conversion
- Script 23: DuckDB queries → TNI, ICM, farmer share, SFT, BPD
- Script 24: Final merge → CountyLevelData
