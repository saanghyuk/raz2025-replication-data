# SHI Construction: Diagnosis of v1 and Reconstruction (v2)

**Date:** 2026-04-21
**Paper:** Raz (2025) "Soil Heterogeneity, Social Learning, and the Formation of Close-Knit Communities," JPE 133(8), §III + Appendix E.1
**Raw data:** USDA STATSGO2 Digital General Soil Map — `raw data/statsgo2/wss_gsmsoil_US_2016/spatial/gsmsoilmu_a_us.shp` (450 MB, 81,770 polygons, 9,562 unique map-unit keys)

---

## 1. The paper's algorithm (Appendix E.1)

The author constructs the Soil Heterogeneity Index (SHI) in three steps.

**Step 1 — Rasterization.** Convert the STATSGO2 polygon map into a raster of 500 m × 500 m cells. Each cell is stamped with the integer code of the soil map unit (MUKEY) of the polygon it falls in (Appendix Figure E.1).

**Step 2 — Cell-level neighbor dissimilarity.** For every cell, look at its "considered area": a square window extending 25 cells in each cardinal direction (a 51 × 51 window = 2,600 neighboring cells, 12.5 km radius, covering ~half the mean US county area in 2000). The cell-level SHI is the fraction of those 2,600 neighbors whose soil map unit *differs* from the center cell's:

$$\mathrm{SHI}^{\text{cell}}_{i} \;=\; 1 \;-\; \frac{\#\{\text{neighbors}\in\text{window}(i):\,\text{MUKEY}(j)=\text{MUKEY}(i)\}}{\#\{\text{valid neighbors}\in\text{window}(i)\}}.$$

**Step 3 — County aggregation.** The county-level SHI is the arithmetic mean of cell-level SHI over all 500 m cells whose center falls inside the county boundary.

The index is a local spatial dissimilarity measure: it rises when neighboring farmers are on different soil map units, regardless of how many soil types exist in the county as a whole.

---

## 2. What v1 did instead

v1 (`BZD6004_Final_Project_v1/notebooks/replication.ipynb` §3 and `data/SoilHeterogeneityIndex.csv`) computes a completely different statistic:

$$\mathrm{SHI}^{\text{v1}}_{c} \;=\; 1 \;-\; \sum_{j} s_{j,c}^{2},$$

where $s_{j,c}$ is the **area share** of soil type $j$ inside county $c$. This is the Herfindahl–Hirschman Index (HHI) complement applied to within-county area shares. The v1 CSV reports, for each county: `n_soil_types`, `hhi`, `shi` = 1 − hhi.

v1's own README (and notebook cell 5) explicitly acknowledged the gap:

> "The paper computes SHI using a raster-based neighbor dissimilarity method (Appendix E.1). Our approach uses within-county area shares instead, which captures the same intuition but may differ in exact values."

That acknowledgement is too generous: the two indices capture *conceptually different* properties of the soil distribution.

---

## 3. Diagnosed problems

| # | Problem | What v1 did | What the paper requires |
|---|---------|-------------|--------------------------|
| 1 | **Wrong formula** | HHI complement on county-wide area shares | Mean of cell-level *neighbor dissimilarity* inside a 12.5 km window |
| 2 | **No rasterization** | Works directly with polygon area fractions — no grid cells exist | Step 1 of the paper's algorithm is to rasterize the polygons to 500 m cells |
| 3 | **No spatial windowing** | Index is county-wide; any geographic structure inside the county is lost | Window = 25 cells in each direction; captures whether *neighbors* (not the whole county) face different soil |

### Why the two indices differ conceptually

Consider two counties, each with the same set of soil types in the same area shares:

- County A: the soil types are arranged in wide bands — large homogeneous tracts that change only near the county border.
- County B: the soil types are interleaved as a fine mosaic at the 1 km scale.

v1's HHI-SHI is **identical** for A and B because the area shares are identical. The paper's raster-SHI is **much lower** for A (most cells see only their own soil type within 12.5 km) and **much higher** for B (most cells see many different soil types within 12.5 km). Since the paper's causal mechanism is "neighboring farmers facing different soil cannot usefully share advice," County B is the heterogeneous one — and only the raster-SHI reflects that.

**Conclusion.** v1's SHI does not measure the object the paper's theory is about. It must be rebuilt.

---

## 4. Reconstruction (v2)

Script: `Refined results/R/06_build_shi_raster.R`.

Toolchain: R `sf` 1.1.0 (shapefile I/O + reprojection), R `terra` 1.9.11 (rasterization + county zonal stats), base-R matrix arithmetic (shift-based focal computation — `terra::focal` with a custom R function was benchmarked as too slow for a 51 × 51 window on 54 M cells).

### Procedure

1. Load `gsmsoilmu_a_us.shp`; clip to CONUS bounding box (lon −125 to −66, lat 24 to 50), which removes Alaska, Hawaii, and territories. **75,315** polygons remain (of 81,770).
2. Reproject to EPSG:5070 (NAD83 Contiguous USA Albers Equal Area) — the projection used by every agency that publishes national-scale thematic rasters. Distances are preserved well enough at continental scale that 500 m means 500 m everywhere.
3. Encode the 9,193 CONUS-remaining MUKEY values as integer codes 1..9193.
4. Build a 500 m template raster covering the CONUS bounding box in EPSG:5070 (9,400 columns × 5,800 rows = **54,520,000 cells**).
5. Rasterize the polygons onto that template using `terra::rasterize` with `field = mukey_int`. **~31.2 M cells** receive a valid code (the remainder are ocean / outside-CONUS).
6. Apply the shift-based focal computation: for every offset `(di, dj)` in `−25:25 × −25:25` (2,600 non-center pairs), compare the raster to itself shifted by `(di, dj)`, accumulate `same_count` (both valid + same MUKEY) and `total_count` (both valid) into 54-M-element integer matrices. After the loop, `SHI_cell = 1 − same_count / total_count` at every valid cell.
7. Download 2010 TIGER/Line county boundaries via `tigris`; project to EPSG:5070; zonal mean of the cell-level SHI into each county using `terra::extract`.
8. Emit `shi_raster` and supporting columns (GEOID, gisjoin, n_cells) as CSV.

### Output

- Cell-level raster: `Refined results/data/shi_cell_500m.tif` (LZW-compressed float32)
- County table: `Refined results/data/SoilHeterogeneityIndex_rasterDissimilarity_v2.csv`

---

## 5. Comparison of v1 vs v2

| Statistic | v1 (area-share HHI) | v2 (raster dissimilarity) |
|-----------|---------------------|----------------------------|
| N counties with valid SHI | 3,100 | 3,109 |
| Mean | 0.7477 | 0.6351 |
| SD   | 0.1412 | 0.1096 |
| Min  | 0.0000 | 0.0223 |
| Max  | 0.9759 | 0.9350 |
| Overlap counties (both non-NA) | — | 3,085 |
| Pearson correlation (v1, v2)   | — | 0.6800 |
| Spearman correlation (v1, v2)  | — | 0.6104 |

(Cell-level v2 raster, before county averaging: mean = 0.6294, sd = 0.2120 across 31.24 M valid cells.)

### Interpretation

The two indices are built on different objects. HHI counts how uniform the mix of soil types is in a county as a whole; raster dissimilarity counts how often a farmer's 12.5 km radius contains multiple soil types. A high v1-SHI can coincide with either a high or a low v2-SHI depending on whether the multiple soil types are segregated (low v2) or interleaved (high v2).

The observed Pearson r = 0.68 (Spearman ρ = 0.61) is consistent with that view: the two measures move together in the *direction* of "more diverse soil" but they rank counties differently because they weight different spatial structure. v1 has a fatter left tail (minimum = 0.0000, where a county is dominated by a single soil type) while v2's minimum is 0.0223 (even the most homogeneous county has occasional cell-level differences near the boundary). v2 is also tighter (SD 0.11 vs 0.14) and has a lower mean (0.64 vs 0.75), reflecting that local 12.5 km windows are more homogeneous than county-wide compositions — exactly the property the paper's mechanism relies on.

---

## 6. Downstream changes

- `R/02_figure1_shi_map.R` now loads `shi_raster` from the v2 CSV and drops the old `shi` column from `CountyLevelData.csv`. All visual parameters (10-bin quantile classification, warm sequential palette, border styling, compass, scale bar, dimensions) are unchanged per the task brief.
- `CountyLevelData.csv` is NOT modified. The v2 SHI is kept in a separate file so the existing regression scripts (`03_table1_main_results.R`, `04_table5_mechanisms.R`, `05_robustness_extensions.R`) continue to work on v1's `shi` column unless a subsequent task rewires them.
- Replacing v1's SHI with v2 in the regressions is a natural next step but is out of scope for this task.
