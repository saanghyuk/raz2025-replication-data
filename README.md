# Raz (2025) Replication Data Package

> **How to use this package (TL;DR):**
> 1. The main file is **`data/CountyLevelData.csv`** — a decennial county-year panel 1850–1940 with 30 columns. Join key: `gisjoin × year`.
> 2. The other CSVs in `data/` are the standalone intermediate files referenced by the paper's R replication code (same filenames: `FertilizersData.csv`, `WheatShareData.csv`, …). Use them directly or work from the merged panel.
> 3. The master panel is missing four IPUMS-dependent columns (`LNI`, `SFT`, `share_farmers`, full-count `birth_place_diversity`). When Jiayi's IPUMS application is approved, add those columns via a left-join on `gisjoin × year` and all the main regressions become runnable.

---

## Preview — what the notebook produces

The Jupyter notebook at `notebooks/demo_usage.ipynb` loads the data,
runs two example regressions, and produces the plots below. Everything
shown here is already pre-rendered in `figures/` so you can see it
without running anything.

### Figure 1 style — county-level Soil Heterogeneity Index across the contiguous US

![County SHI map](figures/figure1_shi_map.png)

*Source: our STATSGO2-based SHI merged onto NHGIS 1940 county polygons.
Darker = more homogeneous soils, brighter = more heterogeneous.*

### SHI vs fertilizer adoption (1920)

![SHI vs Fertilizer scatter 1920](figures/shi_vs_fertilizer_1920.png)

*Each blue dot is one county in 1920. The red line is the binned-mean of
the fertilizer share across SHI bins — visually, at the high-SHI end the
share of farms adopting fertilizer drops sharply, consistent with the
paper's social learning argument.*

### Variable trends across decades

![Variable trends](figures/variable_trends.png)

*Four key variables: fertilizer adoption (1910–1930), wheat share
(1880–1935), agricultural diversity (1880–1935), religious diversity
(1850–1926). The religious plot truncates at 1890 because the paper's
religion years include non-decennial values like 1906/1916/1926 that we
store in a separate file, not the master decennial panel.*

---

## Package contents

```
final_delivery/
├── README.md                         ← this file (start by reading it)
├── notebooks/
│   └── demo_usage.ipynb              ← walk-through: load → regress → plot
├── figures/                          ← pre-built demo outputs
│   ├── figure1_shi_map.png
│   ├── shi_vs_fertilizer_1920.png
│   ├── variable_trends.png
│   ├── table4_style_1920_regression.txt
│   └── table5_style_1920_regression.txt
└── data/
    ├── CountyLevelData.csv           ← master county-year panel (start here)
    │
    ├── SoilHeterogeneityIndex.csv    ← time-invariant
    ├── GeoClimaticControls.csv       ← time-invariant
    ├── SmoothLocationControls.csv    ← time-invariant
    │
    ├── FertilizersData.csv           ← 1910-1930 panel
    ├── WheatShareData.csv            ← 1880-1935 panel
    ├── WheatProductionData.csv       ← 1840-1935 panel
    ├── AgriculturalDiversityData.csv ← 1880-1935 panel
    ├── ReligiousDiversityData.csv    ← 1850-1926 panel
    ├── FarmGiniData.csv              ← 1860-1940 panel
    ├── BirthPlaceDiversityData.csv   ← 1870-1940 panel (proxy)
    ├── SlaveShareData.csv            ← 1850, 1860
    │
    └── countypres_2000-2024.tab      ← MIT Election Lab (Leip substitute)
```

## How to get this package (if you are not a Git person)

If you are comfortable with Git, `git clone` the repo and you're done.
If you are **not** familiar with Git at all, here is the plain-English path:

1. Open the GitHub page in a browser.
2. Click the big green **"Code"** button near the top-right of the file list.
3. Click **"Download ZIP"** in the menu that drops down.
4. Unzip the file. You now have a folder named `final_delivery-main/`
   (or similar) that contains everything described below — the data,
   the notebook, the figures, and this README.
5. From that point on you do **not** need Git or GitHub. The folder on
   your disk is a normal folder and you can open the files with any tool.

---

## How to actually use the data — five ways

### Way 1. Just open a CSV in Excel / Numbers / Google Sheets

Every file in `data/` is a standard comma-separated-values file. You can
double-click any file in `data/` and Excel (or Numbers on a Mac, or Google
Sheets after an upload) will open it. The only exception is
`countypres_2000-2024.tab`, which is tab-separated — Excel will still open
it but may ask whether the delimiter is a tab (say yes).

This is good enough if you just want to look at the data, filter by state,
or copy rows into another spreadsheet.

### Way 2. Use it from R — the paper's original language

The Raz (2025) paper is written in R and its replication scripts expect
exactly the filenames we use in `data/`. You can drop these files straight
into the paper's `./data/` folder and the R code should run (for the
non-IPUMS tables).

```r
# minimal R example
library(readr)
library(dplyr)

panel <- read_csv("data/CountyLevelData.csv")

# Table 5 style: fertilizer adoption vs soil heterogeneity
panel %>%
  filter(year == 1920) %>%
  lm(share_farms_reporting_fert ~ shi + mean_elevation_m + mean_slope_deg +
       mean_annual_temp_c + mean_annual_precip_mm + factor(state), data = .) %>%
  summary()
```

### Way 3. Use it from Stata

```stata
* Stata example
import delimited "data/CountyLevelData.csv", clear
keep if year == 1920
reg share_farms_reporting_fert shi mean_elevation_m mean_slope_deg ///
    mean_annual_temp_c mean_annual_precip_mm i.state, vce(cluster state)
```

### Way 4. Use it from Python / pandas

```python
import pandas as pd

panel = pd.read_csv("data/CountyLevelData.csv")
print(panel.shape)            # (31080, 30)

# Subset a single year
d1920 = panel[panel["year"] == 1920]

# Or load one of the standalone files directly
fert = pd.read_csv("data/FertilizersData.csv")
```

### Way 5. Open the demo notebook

If you already have Python installed, you can run the Jupyter notebook at
`notebooks/demo_usage.ipynb`. It walks through seven things in order:

1. **Load the data** — read `CountyLevelData.csv` into a DataFrame and
   print the shape + column names.
2. **SHI → Fertilizer regression** (Table 5 style) — OLS with state
   fixed effects and state-clustered standard errors, run on the 1920
   cross-section.
3. **SHI → Agricultural Diversity regression** (Table 4 style) — same
   specification, different outcome.
4. **Draw the county SHI map** — reproduces the plot shown at the top
   of this README.
5. **SHI × fertilizer scatter with binned mean** — reproduces the
   second plot above.
6. **Variable trends over time** — reproduces the four-panel plot
   above.
7. **Placeholder for IPUMS merge** — a commented-out cell showing how
   to add the `LNI`/`SFT` columns once Jiayi's IPUMS restricted
   application comes through.

To run it:

```bash
# from inside final_delivery/
pip install -r requirements.txt
jupyter notebook notebooks/demo_usage.ipynb
```

**If you don't want to run any code**, all of the notebook's output
plots are already embedded above in the "Preview" section of this
README and saved in the `figures/` folder as PNG files.

---

## What's in `figures/` (pre-built, no code needed to view)

| File | What it shows |
|---|---|
| `figure1_shi_map.png` | Replication of the paper's Figure 1 — county-level Soil Heterogeneity Index across the contiguous US. |
| `shi_vs_fertilizer_1920.png` | Scatter + binned mean of SHI vs. the 1920 share of farms reporting fertilizer purchase. Visual sanity check. |
| `variable_trends.png` | Four small plots showing the mean county value of fertilizer adoption, wheat share, ag diversity, and religious diversity across decades 1850–1940. |
| `table4_style_1920_regression.txt` | Plain-text regression output for SHI → Agricultural Diversity in 1920 with state fixed effects. |
| `table5_style_1920_regression.txt` | Plain-text regression output for SHI → Fertilizer share in 1920 with state fixed effects. |

These are demo outputs, not the paper's exact numbers — they exist so
you can see what the data can produce without running any code.

---

## Joining `countypres_2000-2024.tab` with the master panel

MIT Election Lab uses a different county identifier (`county_fips`). The
NHGIS `gisjoin` convention is `G` + 2-digit state code + 3-digit county
code + `0`. Example join in pandas:

```python
votes = pd.read_csv("data/countypres_2000-2024.tab", sep="	")
votes["gisjoin"] = (
    "G"
    + votes["county_fips"].astype(str).str.zfill(5).str[:2]
    + votes["county_fips"].astype(str).str.zfill(5).str[2:]
    + "0"
)
panel_with_votes = panel.merge(votes, on="gisjoin", how="left")
```

## Paper being replicated

Raz, I. T. (2025). *Soil Heterogeneity, Social Learning, and the Formation of Close-Knit Communities.* **Journal of Political Economy**, 133(8), 2643-2691.


Prepared by Sang Hyuk Son for the NUS BZD6004 group replication.

This package contains county-level data CSVs built from public sources.
All files key on the NHGIS `gisjoin` county identifier plus (where applicable)
`year`. Column names use snake_case.

---

## Data sources — where everything came from

| # | Source | URL | Used for |
|---|---|---|---|
| 1 | **IPUMS NHGIS** (Manson et al. 2020) | https://www.nhgis.org/ | Historical tabular county data (ag census, population, religion, slave, nativity) + county boundary shapefiles |
| 2 | **USDA NRCS STATSGO2** (Soil Survey Staff 2017) | https://www.nrcs.usda.gov/resources/data-and-reports/description-of-statsgo2-database | Soil polygons → Soil Heterogeneity Index |
| 3 | **HydroSHEDS v1** (Lehner et al. 2008) | https://www.hydrosheds.org/ | 30 arc-sec DEM, flow accumulation, flow direction (→ elevation, slope, flow, river density) |
| 4 | **WorldClim v2.1** (Fick & Hijmans 2017) | https://www.worldclim.org/data/worldclim21.html | 5 arc-min monthly temperature & precipitation |
| 5 | **MIT Election Data + Science Lab** | https://dataverse.harvard.edu/dataset.xhtml?persistentId=doi:10.7910/DVN/VOQCHQ | County-level U.S. presidential returns 2000-2024 (substitutes Dave Leip's paid Atlas) |
| 6 | **Census Linking Project** (Abramitzky, Boustan, Eriksson et al.) | https://censuslinkingproject.org/ | histid crosswalks between decennial censuses (stored separately; requires IPUMS full-count to use) |

---

## Files

---

### `CountyLevelData.csv` — master panel (start here)

**31,080 rows = 3,108 counties × 10 decennial years (1850, 1860, …, 1940).**
**30 columns.** Time-invariant columns are broadcast across all 10 years.

| Column | Type | Meaning | Source |
|---|---|---|---|
| `gisjoin` | string | NHGIS county identifier (e.g. `G0100010`) | NHGIS |
| `state`, `county` | string | State/county name | NHGIS |
| `year` | int | 1850…1940 decennial | — |
| `shi` | float | Soil Heterogeneity Index = 1 − Σ(area_share²) over soil types in county | STATSGO2 |
| `soil_hhi` | float | Σ(area_share²) (the Herfindahl itself) | STATSGO2 |
| `n_soil_types` | int | Distinct MUKEYs in the county | STATSGO2 |
| `mean_elevation_m` | float | County-mean elevation (meters) | HydroSHEDS DEM |
| `mean_slope_deg` | float | County-mean slope (degrees, from DEM gradient) | HydroSHEDS DEM |
| `mean_flow_accum` | float | County-mean flow accumulation | HydroSHEDS ACC |
| `river_density` | float | Share of cells with `flow_accum > 1000` (river-cell proxy) | HydroSHEDS ACC |
| `mean_annual_temp_c` | float | Mean of 12 monthly tavg rasters (°C) | WorldClim 2.1 |
| `mean_annual_precip_mm` | float | Sum of 12 monthly prec rasters (mm) | WorldClim 2.1 |
| `centroid_lat`, `centroid_lon` | float | 1940 county centroid in WGS84 degrees | NHGIS shapefile |
| `lat_sq`, `lon_sq`, `lat_x_lon` | float | Polynomial terms for smooth location control (Section 3.2) | derived |
| `total_farms` | int | Total farms in county (sum of size-class table) | NHGIS Ag Census |
| `share_farms_reporting_fert` | float | Farms reporting fertilizer ÷ total farms | NHGIS Ag Census |
| `fert_expenditure_dollars` | float | Total fertilizer spend (current $) | NHGIS Ag Census |
| `wheat_share_of_farmland` | float | Wheat acres ÷ land in farms acres | NHGIS Ag Census |
| `wheat_production_bu` | float | Wheat production (bushels) | NHGIS Ag Census |
| `ag_diversity_index` | float | 1 − HHI over crop acreages | NHGIS Ag Census |
| `slaves`, `total_population`, `slave_share` | int/float | 1850, 1860 only | NHGIS Pop Census |
| `religious_diversity_index` | float | 1 − HHI over denominations (1850/60/70/90/1906/16/26) | NHGIS Religious Bodies |
| `birth_place_diversity` | float | 1 − HHI over countries of birth (1870-1940; proxy) | NHGIS nativity tables |
| `farm_size_gini` | float | Gini over farm-size distribution (1860-1940) | NHGIS Ag Census |

---

### Standalone files (same data, un-merged)

Each file below is the corresponding subset of the master panel, kept separate so paper-provided R code that reads these exact filenames works as-is.

| File | Period | Rows | Key columns |
|---|---|---|---|
| **`SoilHeterogeneityIndex.csv`** | time-invariant | 3,100 | `gisjoin`, `shi`, `soil_hhi`, `n_soil_types` |
| **`GeoClimaticControls.csv`** | time-invariant | 3,108 | `gisjoin`, elevation, slope, flow, river, temp, precip |
| **`SmoothLocationControls.csv`** | time-invariant | 3,108 | `gisjoin`, `centroid_lat`, `centroid_lon`, `lat_sq`, `lon_sq`, `lat_x_lon` |
| **`FertilizersData.csv`** | 1910, 1920, 1930 | 9,207 | `share_farms_reporting_fert`, `fert_expenditure_dollars`, `fert_tons_purchased` (1930 only) |
| **`WheatShareData.csv`** | 1880-1935 | 23,728 | `wheat_acres`, `land_in_farms_acres`, `wheat_share_of_farmland` |
| **`WheatProductionData.csv`** | 1840-1935 | 27,969 | `wheat_production_bu` |
| **`AgriculturalDiversityData.csv`** | 1880-1935 | 23,728 | `ag_diversity_index`, `ag_diversity_z` (standardized within year) |
| **`SlaveShareData.csv`** | 1850, 1860 | 3,736 | `slaves`, `total_population`, `slave_share` |
| **`ReligiousDiversityData.csv`** | 1850, 60, 70, 90, 1906, 16, 26 | 17,938 | `religious_diversity_index`, `rdi_zscore`, `source` (`members` or `churches_proxy`) |
| **`FarmGiniData.csv`** | 1860-1940 | 31,249 | `total_farms`, `farm_size_gini` |
| **`BirthPlaceDiversityData.csv`** | 1870-1940 | 22,905 | `birth_place_diversity`, `source_note` (full vs foreign-born-only) |

### External

- **`countypres_2000-2024.tab`** — MIT Election Lab county-level presidential returns 2000-2024 from Harvard Dataverse DOI 10.7910/DVN/VOQCHQ. Tab-separated. 94,151 rows, 12 columns: `state`, `county_fips`, `year`, `candidate`, `party`, `candidatevotes`, `totalvotes`, etc. Replaces Dave Leip's (paid) Atlas for LNI validation in Table 1, columns 3-6 (Trump 2016 vote share and Δ[Trump − GOP]).

---

## How each variable was built (the recipe)

1. **Soil Heterogeneity Index (`shi`)** — Load STATSGO2 CONUS soil polygon shapefile. Reproject WGS84 → EPSG:5070 (CONUS Albers, meters). Overlay with 1940 county polygons. For each county, sum intersection area per soil map unit key (MUKEY). Compute `share_j = area_j / total_area` and `shi = 1 - Σ share_j²`. [script: `07_build_shi_from_statsgo2.py`]

   *Simplification vs paper.* The paper rasterizes STATSGO2 at 500m and for each cell computes the probability a random neighboring cell within a ~25 km window has a different soil type (Appendix E.1). Our version uses area shares within the county instead of neighbor-based shares. Both capture the same intuition — heterogeneous soils → lower HHI → higher SHI — but the exact numeric values differ.

2. **Geo-climatic controls** — Zonal statistics over the 1940 county polygons using `rasterstats.zonal_stats`. Elevation from HydroSHEDS 30s void-filled DEM; slope computed from DEM gradient then arctan; flow accumulation from HydroSHEDS 30s ACC; river density as the share of county cells with `flow_accum > 1000` (standard river-cell threshold); temperature and precipitation from WorldClim 2.1 5 arc-min rasters (12 monthly files averaged to annual mean / summed to annual total). [`09_build_geoclimatic_controls.py`]

3. **Smooth location polynomial** — County centroids computed in Albers (projected) then reprojected to WGS84. Columns are `centroid_lat`, `centroid_lon`, `lat²`, `lon²`, `lat × lon`. [`12_build_smooth_location.py`]

4. **Fertilizers** — For each of 1910, 1920, 1930: read NHGIS Ag Census tables. Extract the "farms reporting fertilizer" count and the total expenditure. Sum the farm-size-class columns to get total farms per county. Compute `share = farms_reporting / total_farms`. NT136 (farms-reporting count for 1930) was pulled in a follow-up extract and merged in. [`02_build_fertilizers.py`]

5. **Wheat share / production** — For each ag census year, pick the relevant NHGIS table (crop acreage for share, crop/farm production for bushels). For 1870 and 1935, wheat is split into winter/spring and we sum. Denominator for share is "Land in Farms" (varies by year). 1935 uses "Approximate Land Area" instead (NHGIS doesn't publish Land in Farms for 1935) — its share is consequently understated. [`03_build_wheat.py`]

6. **Agricultural Diversity** — For each year, read all crop acreage tables we pulled (cereal + hay/forage + vegetable + tobacco/cotton/sugar/misc). Sum to total cropland, then `1 - Σ(share²)`. 1910 merges four separate tables (NT66+NT67+NT68+NT69). [`08_build_ag_diversity.py`]

7. **Slave share** — 1850 `AE6003 / ADQ001`, 1860 `AH3003 / AG3001`. [`04_build_slave_share.py`]

8. **Religious Diversity Index** — For each year in {1850, 1860, 1870, 1890, 1906, 1916, 1926}, sum all denomination columns to get the county total, compute shares, then `1 - Σ share²`. Pre-1890 uses *church counts* by denomination (member counts weren't collected); 1890+ uses *number of members/communicants* directly. The `source` column flags which was used. [`05_build_religious_diversity.py`]

9. **Farm-size Gini** — For each year, read the NHGIS "Farms by Farm Acreage" table. Assign each size class the midpoint of its range as the average farm size (125% of the lower bound for the open-ended top class, per the paper). Build the Lorenz curve from cumulative counts and cumulative land, integrate trapezoidally, report `1 - 2 × area`. [`06_build_farm_gini.py`]

10. **Birth Place Diversity (proxy)** — For 1870 and 1880 we have full NHGIS Place-of-Birth tables (77 categories: native-state + foreign-country). BPD is `1 - Σ share²` over all 77 categories. For 1890-1940 NHGIS only publishes foreign-born-by-country, so BPD in those years is computed over the foreign-born sub-universe only — a narrower measure than the paper's (which uses IPUMS full-count individual data at household-head level). The `source_note` column records the method used per row. [`13_build_birth_place_diversity.py`]

11. **Master merge** — `10_build_county_level_data.py` does the left-joins. It starts from the time-invariant controls (SHI, geo-climatic, smooth location) broadcast across a county × decennial-year cross product, then left-joins each time-varying dataset on `gisjoin × year`. Result: `CountyLevelData.csv`.

---

## Prepared but blocked on IPUMS

The build tree also contains (not shipped in this zip because they require IPUMS full-count to be useful):

- **Census Linking Project crosswalks** for 1850-1860, 1850-1870, 1850-1880, 1850-1900, 1850-1910 and 1850-1920 (anonymous histid ↔ histid pairs).
- Once Jiayi's IPUMS application is approved, these let us construct: `SelectionFarmingData.csv`, `MigrantsNative_2.csv`, `MigrantsChildrenData.csv`, `OutMigrationData.csv`, `Migrants_2.csv`, `MigrantsNativeAllRace_2.csv`, `MigrantsNative.csv`.
- Workflow: load IPUMS full-count for both years → merge crosswalk on histid → follow paper's `MigrantsNative_2` construction in Appendix E.

## What is NOT in this package (blockers)

Variables the paper builds from IPUMS USA full-count (restricted application
in progress) — absent from `CountyLevelData.csv`:

- `LNI` — Local Name Index (main dependent variable)
- `SFT` — Strength of Family Ties
- Farmer share at county level (for Prediction 2)
- Full-count Birth Place Diversity (we have a proxy only)
- All linked-census datasets: `SelectionFarmingData.csv`, `MigrantsNative_2.csv`,
  `MigrantsChildrenData.csv`, `OutMigrationData.csv`, `Migrants_2.csv`,
  `MigrantsNativeAllRace_2.csv`, `MigrantsNative.csv`

Other gaps:
- `MFQData.csv` — yourmorals research team restricted; affects Appendix Table C.3
- GAEZ absolute agricultural productivity control (Theme 3 REST API
  inaccessible; other geoclimatic controls are present)
- Enke (2020) county communal values — author homepage link not locatable;
  mitigated by MIT Election Lab Trump vote share for LNI validation

## What this package enables

**Fully replicable without IPUMS:**
- Table 4 (SHI → Agricultural Diversity)
- Table 5 (SHI → Fertilizer adoption)
- Figure 1 (county SHI map + long-run persistence plot)
- Appendix Table A.2 (Ag Diversity)
- Appendix Table C.11 (Slave share, given pre-1864 county set)
- Appendix Tables D.13-D.18 (Fertilizer / Wheat robustness)
- Appendix Figure D.4

**Partially replicable (methodology demo at reduced power):**
- Table 1/2 equivalent using IPUMS USA 1% public sample in place of LNI

**Blocked until IPUMS restricted approved:**
- Tables 1 (main result at full precision), 3, 6-9
- Figures 2, 3
- Appendix Table C.1 (SFT)

**When IPUMS arrives, the team only needs to:**
1. Build LNI, SFT, farmer-share, and full-count BPD columns from IPUMS micro.
2. Left-join into `CountyLevelData.csv` on `gisjoin × year`.
3. Use `raw/census_linking/crosswalk_*.csv` to construct MigrantsNative,
   MigrantsChildren, etc.
4. Rerun the paper's R code — all our non-IPUMS controls are already in place.

## Reproduction

All scripts that built these files live in `data_collection/scripts/`
in the build tree (ask Son for access to that working directory — it's
not shipped in this repo because the raw inputs alone are several GB).
They run in order 01 → 15 and are idempotent; heavy geo artifacts are
cached in `processed/*.parquet` so re-runs are fast.

Build date: 2026-04-10
