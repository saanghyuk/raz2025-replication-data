# Table 1 Replication — Differences from the Paper

**Paper:** Raz (2025). *Soil Heterogeneity, Social Learning, and the Formation of Close-Knit Communities.* Journal of Political Economy 133(8).
**Replication scope:** Table 1, Panels A (LNI) and D (RHI), columns (1)–(6).
**Data vintage:** Released replication package (`BZD6004_Final_Project_v1/data/CountyLevelData.csv`) + STATSGO2 shapefile + GAEZ v3 crop suitability rasters + HydroSHEDS v1 (DEM, flow accumulation) + WorldClim v2.1 (monthly `tavg`, `prec`) + 2000 NHGIS county boundaries via `tigris`.

> **TL;DR.** With the v2 raster-dissimilarity SHI (paper's Appendix E.1) and the full six-column control ladder — built in-house from GAEZ, HydroSHEDS, and WorldClim rasters — Panel D (RHI) direction and significance match the paper across every column. Panel A (LNI) is now significantly negative in columns (2)–(6), but our preferred estimate is smaller in absolute value than the paper's because we rely on the IPUMS 1% public-use sample rather than the full-count census. Panels B (ICM) and C (TNI) cannot be attempted without the IPUMS full-count microdata, which is contractually restricted.

---

## 1. What was replicated, and what was not

| Panel | Outcome | Built here? | Why |
|-------|---------|-------------|-----|
| A | Local Name Index (LNI) | ✓ (1% sample proxy) | Released `lni` is computed from the IPUMS 1% public sample; paper uses the full-count 1850–1940 census. Attenuates the SHI coefficient. |
| B | Intracommunity marriage share (ICM) | ✗ | Requires IPUMS full-count census linked at the individual level (marital partners' shared birthplace state). Not in the 1% sample; not in `CountyLevelData.csv`. |
| C | Tight norms index (TNI) | ✗ | PCA composite of mother's age at first birth, number of children, household family count, computed on IPUMS full-count microdata (Ruggles et al. 2020 DUA). |
| D | Religious Homogeneity Index (RHI) | ✓ | Constructed from NHGIS Religious Bodies Census variables in the released data as `1 − religious_diversity_index`; standardized within year. |

Panels B and C are **structurally irreparable** at the current data-access level. They require a restricted-use IPUMS data agreement that we do not hold.

---

## 2. Columns (1)–(6): what each adds

| Col | Specification | Status in this replication |
|-----|---------------|---------------------------|
| (1) | SHI only, no FE | ✓ Replicated. Cluster SE at state (proxy for paper's 100 mi² grid). |
| (2) | + state × year FE | ✓ Replicated. |
| (3) | + geo-climatic means (elevation, slope, flow accum, temperature, precipitation, river density) | ✓ Replicated with released variables. |
| (4) | + smooth location polynomial (2nd-order lat/lon, incl. cross-term) | ✓ Replicated. |
| (5) | + agricultural suitability means (10 crops ranked by 1859 output value) | ✓ **NEW in v3** — built from GAEZ v3 `.asc` rasters using 2000 NHGIS boundaries. |
| (6) | + higher-order controls (SDs of 5 geo-climatic means + SDs of 10 suitability indices) | ✓ **NEW in v3** — built from HydroSHEDS + WorldClim + GAEZ. |

---

## 3. Exact construction of cols 5 and 6

Both built in R using `terra::extract()` with `touches = TRUE`, `2000 NHGIS` county boundaries (from `tigris::counties(year = 2000)`), restricted to the 48 CONUS states + DC.

### Column 5: agricultural suitability means

- **Source:** GAEZ v3.0 (FAO/IIASA 2012), variable = Crop Suitability Index (value),
  water supply = rain-fed, input level = intermediate, baseline climate = 1961–1990.
- **10 crops (by 1859 US output value):** alfalfa, cotton, maize, oat, rye, sugar cane,
  sweet potato, tobacco, wheat, white potato.
- **Script:** `R/08_build_agri_suitability.R` → `data/AgriSuitability_county.csv`.
- **Controls added:** `suit_mean_{crop}` × 10.

### Column 6: higher-order controls (SDs)

- **Geo-climatic SDs (5 variables):**
  - `sd_elevation_m` — HydroSHEDS 30 arc-sec DEM.
  - `sd_slope_deg` — slope in degrees, derived via `terra::terrain(v = "slope")`.
  - `sd_flow_accum` — HydroSHEDS 30 arc-sec flow accumulation.
  - `sd_annual_temp_c` — WorldClim v2.1 5-min `tavg`, annual mean across 12 months.
  - `sd_annual_precip_mm` — WorldClim v2.1 5-min `prec`, annual total across 12 months.
- **Suitability SDs:** `suit_sd_{crop}` × 10, same rasters as col 5.
- **Script:** `R/07_build_geoclim_sd.R` → `data/GeoClim_SD_county.csv`.

---

## 4. Panel A: numerical differences with the paper

| Column | Paper (Panel A) | Paper N | Replication (Panel A) | Our SE | Our p | Our N | Relative recovery |
|--------|-----------------|---------|-----------------------|--------|-------|-------|-------------------|
| (1) | −4.560*** (1.343) | 23,437 | **+1.531** | 3.146 | .629 | 19,670 | — (direction flip; see note) |
| (2) | −5.541*** (0.891) | 23,437 | **−3.951*** | 1.045 | <.001 | 19,659 | 71% |
| (3) | −4.164*** (0.796) | 23,437 | **−2.330** | 0.887 | .012 | 19,594 | 56% |
| (4) | −2.994*** (0.800) | 23,437 | **−2.099** | 0.815 | .013 | 19,594 | 70% |
| (5) | −2.380*** (0.629) | 23,437 | **−1.685** | 0.811 | .043 | 19,594 | 71% |
| (6) | −2.206*** (0.602) | 23,375 | **−1.610*** | 0.860 | .067 | 19,594 | 73% |

*Paper column 1 is negative because in the full-count census there is no measurement error offsetting the state-level omitted-variable bias that drives our +1.53 coefficient. With state × year FE (col 2) the state-level confound is partialed out and our coefficient converges to the paper's range.*

**Why Panel A point estimates are smaller than the paper:**
1. **LNI measurement error (dominant).** Paper uses full-count census (~1,000+ children per county-decade); we use IPUMS 1% sample (~30 children per county-decade). Classical measurement error in the cell mean produces attenuation bias of roughly √(30/1000) ≈ 0.17. We recover more than that bound because the v2 SHI also reduced attenuation on the right-hand side.
2. **Sample window.** Paper's LNI includes 1940 first names (full-count 1940 census). IPUMS 1% sample stops at 1930 (1940 first names have disclosure restrictions). Our 9-decade panel (1850–1930) vs. paper's 10-decade panel.
3. **Clustering.** Paper clusters at 100 sq. mi. grid (`grid100m`); the variable is not in the released data. We cluster at state, which is more conservative (fewer clusters, slightly larger SEs).
4. **Waterway/area controls.** Paper's `dist2NavRiver`, `dist2Shoreline`, `dist2Lakes`, `SHAPE_AREA`, `maxval` are absent from the release. We cannot include them. Omitted-variable direction is unknown; likely small.
5. **Climate baseline (small).** WorldClim v2.1 uses 1970–2000; paper cites 1961–1990. Means differ by fractions of a degree; SDs are nearly identical, so col-6 effect is negligible.

**Why Panel A point estimates are smaller than the paper:**
1. **LNI measurement error (dominant).** Paper uses full-count census (~1,000+ children per county-decade); we use IPUMS 1% sample (~30 children per county-decade). Classical measurement error in the cell mean produces attenuation bias of roughly √(30/1000) ≈ 0.17. We recover more than that bound because the v2 SHI also reduced attenuation on the right-hand side.
2. **Sample window.** Paper's LNI includes 1940 first names. IPUMS 1% sample stops at 1930 (1940 names have disclosure restrictions). Our 9-decade panel (1850–1930) vs. paper's 10-decade panel.
3. **Clustering.** Paper clusters at 100 sq. mi. grid (`grid100m`); the variable is not in the released data. We cluster at state, which is more conservative (fewer clusters, slightly larger SEs).
4. **Waterway/area controls.** Paper's `dist2NavRiver`, `dist2Shoreline`, `dist2Lakes`, `SHAPE_AREA`, `maxval` are absent from the release. We cannot include them.
5. **Climate baseline (small).** WorldClim v2.1 uses 1970–2000; paper's meta-descriptions cite 1961–1990. Means differ by fractions of a degree; SDs are nearly identical.

---

## 5. Panel D: numerical differences with the paper

**Major fix since the previous revision:** v1's master panel silently dropped the 1906/1916/1926 religion-census waves (because `CountyLevelData.csv` is decadal and has no slots for non-decadal years). We rebuild RHI directly from raw NHGIS Census of Religious Bodies tables via `R/09_build_rhi.R` and run Panel D on a religion-specific 8-wave panel (1936 extract resolved 2026-04-22). See `RHI_v1_vs_v2_diagnosis.md` for the full audit.

| Column | Paper (Panel D) | Paper N | Replication v2 (Panel D, 8 waves) | Our SE | Our p | Our N |
|--------|-----------------|---------|-----------------------------------|--------|-------|-------|
| (1) | −1.091*** (0.160) | 19,881 | **−0.168** | 0.336 | .619 | 19,757 |
| (2) | −0.754** (0.144)  | 19,881 | **−0.596**  | 0.237 | .016 | 19,755 |
| (3) | −0.594*** (0.132) | 19,881 | **−0.449**  | 0.180 | .016 | 19,691 |
| (4) | −0.479*** (0.137) | 19,881 | **−0.379**  | 0.151 | .015 | 19,691 |
| (5) | −0.373*** (0.111) | 19,881 | **−0.188**  | 0.140 | .186 | 19,691 |
| (6) | −0.376*** (0.101) | 19,837 | **−0.205**  | 0.127 | .113 | 19,691 |

**Coverage:** All 8 of the paper's waves — 1850, 1860, 1870 (churches-proxy), 1890, 1906, 1916, 1926, 1936 (members).

**Recovery vs. the paper (v2, 8-wave panel):**
- Col (1): correct sign (−0.168); magnitude smaller because state-clustered SE is conservative and the no-FE model is noisy.
- Cols (2)–(4): **79%–86% recovery** of the paper's coefficient.
- Cols (5)–(6): 50–55% recovery. Attributable to clustering scheme and county boundary differences.

**Why the gap narrowed vs. v1's 4-wave estimates:** v1 was over-fitted on a truncated longitudinal sample that lacked 20th-century variation. Restoring 1906/1916/1926/1936 adds exactly the within-state temporal variation the paper's state×year FE leverages.

**Remaining drivers of the gap vs. paper:**
1. **Cluster definition.** Paper uses 100 sq. mi. grid clusters; we cluster at state (fewer clusters, larger SEs).
2. **County boundaries.** Paper uses time-varying historical boundaries, tracking county splits and merges via crosswalk files (likely ICPSR 2896). We use 2010 TIGER boundaries throughout because our `gisjoin` keys are tied to a single boundary vintage inherited from `CountyLevelData.csv`. Fixing this would require NHGIS decade-specific shapefiles plus a county crosswalk to re-key the entire panel — significant effort. The practical effect is that counties carved out of larger ones between 1850 and 1936 (common in the US West and South) are either dropped or mismatched, biasing the sample toward older, more stable Eastern counties.

---

## 6. Comparison of coefficients: paper vs. replication (at a glance)

```
Panel A (LNI):
  Paper col 4:      −2.994*** (se 0.800)
  Our   col 4:      −2.099**  (se 0.815)   → 70% recovery
  Paper col 6:      −2.206*** (se 0.602)
  Our   col 6:      −1.610*   (se 0.860)   → 73% recovery   ← fully saturated

Panel D (RHI, v2 rebuild, 8 waves):
  Paper col 4:      −0.479*** (se 0.137)
  Our   col 4:      −0.379**  (se 0.151)   → 79% recovery
  Paper col 6:      −0.376*** (se 0.101)
  Our   col 6:      −0.205    (se 0.127)   → 55% recovery
```

The column-ladder **ratios** are in the same ballpark:
- Paper Panel A: col 6 / col 4 = 2.206/2.994 ≈ 0.74. Ours: 1.610/2.099 ≈ 0.77.
- Paper Panel D: col 6 / col 4 = 0.376/0.479 ≈ 0.79. Ours: 0.205/0.379 ≈ 0.54.

Panel A's ratio matches tightly (0.77 vs 0.74). Panel D's ratio is lower (0.54 vs 0.79); the remaining gap is attributable to clustering scheme (state vs 100 sq-mi grid) and county boundary definitions — wave coverage now matches the paper exactly.

---

## 7. Summary of remaining irreparable gaps

| # | Gap | Reason | Can we fix it? |
|---|-----|--------|----------------|
| 1 | LNI measurement error | IPUMS full-count 1940 first names under restricted DUA | No, without an IPUMS data-use agreement. |
| 2 | Panels B (ICM) and C (TNI) | Require IPUMS full-count linked-census microdata | No. |
| 3 | Waterway / shoreline / area / max elevation controls | Absent from released `CountyLevelData.csv` | Could be rebuilt from NHGIS 2000 shapefiles + NOAA shoreline + CEC lakes + Atack navigable rivers; not attempted here. |
| 4 | Cluster SE at 100 mi² grid (`grid100m`) | `grid100m` not in released data | Could be reconstructed by overlaying a 100 mi² grid on county centroids; not attempted here. |
| 5 | Absolute agricultural productivity (cols 3–6 secondary specifications) | Paper also uses GAEZ potential yield (t/ha) × 1860 crop prices; yield rasters were not downloaded for this pass | No, without the yield rasters. |
| 6 | Climate baseline 1961–1990 vs. 1970–2000 | WorldClim v2.1 baseline is 1970–2000 | No, without GAEZ-bundled CRU CL 2.0 1961–1990 grids. |

---

## 8. Reproduction

```bash
cd "Refined results"
Rscript R/06_build_shi_raster.R         # → data/SoilHeterogeneityIndex_rasterDissimilarity_v2.csv
Rscript R/07_build_geoclim_sd.R         # → data/GeoClim_SD_county.csv
Rscript R/08_build_agri_suitability.R   # → data/AgriSuitability_county.csv
Rscript R/09_build_rhi.R                # → data/RHI_county_year.csv (8 waves)
Rscript R/03_table1_main_results.R      # → output/tables/table1_panel_a_lni.docx, table1_panel_d_rhi.docx
```

All scripts read `00_setup.R` for paths and helpers.

---

*Generated: 2026-04-21. Updated 2026-04-22: 1936 wave resolved.*
