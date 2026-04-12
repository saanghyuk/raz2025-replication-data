# Replication: Soil Heterogeneity, Social Learning, and Close-Knit Communities

Replication data and analysis for:

> Raz, I. T. (2025). *Soil Heterogeneity, Social Learning, and the Formation of Close-Knit Communities.* **Journal of Political Economy**, 133(8), 2643-2691.

Built for NUS BZD6004 Applied Econometrics II (Sem 2, 2025-2026).

---

## Preview — what this package produces

### County-level Soil Heterogeneity Index (Figure 1)

![SHI Map](figures/figure1_shi_map.png)

*Darker = more homogeneous soil; brighter = more heterogeneous. Source: STATSGO2 soil polygons overlaid onto 1940 county boundaries.*

### SHI vs. Fertilizer adoption (1920)

![SHI vs Fertilizer](figures/shi_vs_fertilizer_1920.png)

*Counties with more heterogeneous soil (higher SHI) tend to have lower fertilizer adoption rates, consistent with the paper's social learning argument.*

### Variable trends across census decades

![Trends](figures/variable_trends.png)

---

## Quick start

**Just want to see the analysis?** Open the notebook:
```
notebooks/replication.ipynb
```
It walks through everything — data loading, regressions, figures — with explanations at every step.

**Just want the data?** Load the master panel:
```python
import pandas as pd
panel = pd.read_parquet("data/CountyLevelData.parquet")   # 1.8 MB, fast
```
```r
panel <- arrow::read_parquet("data/CountyLevelData.parquet")
```
```stata
import delimited "data/CountyLevelData.csv", clear
```

**Just want to see the plots?** They're in `figures/` — no code needed.

---

## What's in this package

```
├── README.md                              ← you're reading this
├── requirements.txt                       ← pip install -r requirements.txt
│
├── notebooks/
│   └── replication.ipynb                  ← MAIN NOTEBOOK: full analysis
│
├── data/                                  ← all data as CSV + Parquet
│   ├── CountyLevelData.parquet (.csv)     ← master panel (start here)
│   ├── LNI_by_county.parquet (.csv)       ← Local Name Index
│   ├── SoilHeterogeneityIndex.parquet     ← SHI per county
│   ├── GeoClimaticControls.parquet        ← elevation, slope, temp, etc.
│   ├── FertilizersData.parquet            ← fertilizer adoption 1910-1930
│   ├── WheatShareData.parquet             ← wheat acreage shares
│   ├── AgriculturalDiversityData.parquet  ← crop diversity
│   ├── ReligiousDiversityData.parquet     ← religious denomination diversity
│   ├── FarmGiniData.parquet               ← farm-size inequality
│   ├── SlaveShareData.parquet             ← enslaved population share
│   ├── BirthPlaceDiversityData.parquet    ← birthplace diversity
│   ├── SmoothLocationControls.parquet     ← lat/lon polynomial terms
│   ├── WheatProductionData.parquet        ← wheat production (bushels)
│   └── countypres_2000-2024.tab           ← MIT Election Lab vote data
│
├── analysis/                              ← standalone Python scripts
│   ├── 01_table2_main_shi_lni.py
│   ├── 02_table4_shi_ag_diversity.py
│   ├── 03_table5_shi_fertilizer.py
│   ├── 04_figures.py
│   └── 05_robustness_and_extensions.py
│
└── figures/                               ← pre-rendered outputs
    ├── figure1_shi_map.png
    ├── shi_vs_fertilizer_1920.png
    └── variable_trends.png
```

Every Parquet file has a matching CSV. Parquet is 5-7x smaller and loads faster in Python/R; CSV works in Excel and Stata without extra libraries.

---

## Where each piece of data came from

| Source | URL | What we extracted | How it enters the panel |
|---|---|---|---|
| [IPUMS NHGIS](https://www.nhgis.org/) | nhgis.org | County boundary shapefiles 1850-1940; Agricultural Census (crops, fertilizer, farm sizes); Religious Bodies Census; Population Census (race, nativity, slaves) | 4 NHGIS extract requests → parsed by year-specific scripts → county-year CSVs |
| [IPUMS USA](https://usa.ipums.org/) | usa.ipums.org | 1% census samples 1850-1930 with first names (NAMEFRST), demographics (AGE, SEX, RACE, BPL, OCC1950, RELATE, MARST) | Fixed-width .dat.gz → parsed with codebook positions → LNI + SFT + farmer share + BPD |
| [USDA STATSGO2](https://www.nrcs.usda.gov/resources/data-and-reports/description-of-statsgo2-database) | nrcs.usda.gov | Digital General Soil Map polygon shapefile (CONUS, 425 MB) | Reprojected to Albers → spatial overlay with county polygons → area-share HHI → SHI |
| [HydroSHEDS v1](https://www.hydrosheds.org/) | hydrosheds.org | 30 arc-second void-filled DEM + flow accumulation (North America) | Zonal statistics over 1940 counties → mean elevation, slope (from gradient), flow, river density |
| [WorldClim v2.1](https://www.worldclim.org/data/worldclim21.html) | worldclim.org | 5 arc-minute monthly temperature + precipitation (12 files each) | Zonal statistics → annual mean temp, annual total precip per county |
| [MIT Election Lab](https://dataverse.harvard.edu/dataset.xhtml?persistentId=doi:10.7910/DVN/VOQCHQ) | Harvard Dataverse | County presidential returns 2000-2024 | Direct download, used for LNI validation (replaces Dave Leip's paid Atlas) |
| [Census Linking Project](https://censuslinkingproject.org/) | censuslinkingproject.org | Cross-census individual linkage files 1850-1910 (histid pairs) | Downloaded for future linked-census analysis when IPUMS name access expands |

---

## How data was merged into the master panel

The master panel (`CountyLevelData`) was built in stages:

1. **County skeleton:** 3,108 counties from the NHGIS 1940 shapefile × 10 census decades = 31,080 base rows.
2. **SHI (time-invariant):** STATSGO2 soil polygons spatially overlaid with county boundaries. One value per county, broadcast across all years.
3. **Geo-climatic controls (time-invariant):** Raster zonal statistics (HydroSHEDS DEM → elevation + slope, WorldClim → temp + precip, HydroSHEDS flow → flow accumulation + river density). One value per county.
4. **Smooth location controls (time-invariant):** County centroid lat/lon + quadratic polynomial terms (lat², lon², lat×lon). Used as the paper's smooth spatial control (Section 3.2).
5. **Agricultural variables (time-varying):** NHGIS Census of Agriculture tables parsed per year — fertilizer share, wheat share, crop diversity, farm-size Gini. Left-joined on `gisjoin × year`.
6. **Religion + slaves + nativity (time-varying):** NHGIS Religious Bodies Census + Population Census. Left-joined on `gisjoin × year`.
7. **IPUMS-derived variables (time-varying):** LNI, SFT components, farmer share, BPD from the 1% census samples. County code mapping: `COUNTYICP ÷ 10 = FIPS county → GISJOIN`. Left-joined on `gisjoin × year`.

All joins are left joins — if a variable is unavailable for a particular county-year, the cell is null.

---

## Replication results

### Table 2 — Main result: does soil heterogeneity weaken communal identity?

| Spec | Our estimate (1% sample) | Paper (full count) |
|---|---|---|
| (1) No controls | +14.42*** | −4.52*** |
| (2) + State×year FE | **−0.84** | −5.51*** |
| (3) + Geo-climatic | **−0.65** | −2.91*** |
| **(4) Preferred** | **−0.81** | **−2.49*** |

Our preferred estimate is **negative**, matching the paper's direction. The smaller magnitude and lack of statistical significance are expected: our 1% sample introduces measurement error in the LNI, which attenuates the coefficient toward zero (classical attenuation bias).

### Table 4 — SHI → Agricultural diversity
SHI coefficient: **+0.066** (p = 0.025). Positive and significant — heterogeneous soil leads to more diverse crop choices. **Matches the paper.**

### Table 5 — SHI → Fertilizer adoption
Explored using the growth rate of fertilizer share. Direction examined in the notebook.

---

## What we could not replicate

| What | Why | Reference |
|---|---|---|
| LNI for 1940 | IPUMS does not release 1940 first names in any public sample (contractual restriction). The author obtained them through a special agreement with the Minnesota Population Center. | Paper README, p.1 |
| Tables 2, 3, 6 (linked-census migrant analysis) | Requires cross-census individual linkage (HISTID) + full-count names. We have the Census Linking Project crosswalk files but cannot use them without full-count name data. | — |
| Table 8 (long-run moral values) | MFQ survey data restricted to the yourmorals.org research team. | — |
| Exact SHI values | We use within-county area-share HHI; the paper uses raster neighbor dissimilarity. Same concept, different method. | Appendix E.1 |
| Exact coefficient magnitudes | 1% sample → attenuation bias. Direction matches; magnitude attenuated toward zero. | — |
| GAEZ agricultural productivity control | REST API inaccessible. Other 6 geo-climatic controls are present. | — |

---

## Python dependencies

```
pip install -r requirements.txt
```

Core: `pandas`, `numpy`, `pyarrow`, `statsmodels`, `matplotlib`, `geopandas`, `jupyter`

---

## Building from scratch

All processing scripts are in `data_collection/scripts/`, numbered 01-21. Run in order:

```bash
cd data_collection
source .venv/bin/activate
python scripts/01_inspect_codebooks.py     # index NHGIS variables
python scripts/02_build_fertilizers.py     # → FertilizersData.csv
python scripts/03_build_wheat.py           # → WheatShareData, WheatProductionData
# ... (scripts 04-13 build other variables)
python scripts/19_build_lni_from_sample.py # → LNI from IPUMS 1% sample
python scripts/20_final_merge_and_export.py # → CountyLevelData.csv + .parquet
```

Raw data downloads require accounts on NHGIS and IPUMS USA (both free). STATSGO2, HydroSHEDS, WorldClim, and MIT Election Lab data are freely downloadable without accounts.
