# Table 5 Replication: Process and Differences from Paper

**Paper:** Raz (2025), "Soil Heterogeneity, Social Learning, and the Formation
of Close-Knit Communities," *Journal of Political Economy* 133(8).

**Prepared:** 2026-04-22

---

## 1. What the Paper's Table 5 Shows

Table 5 of Raz (2025) tests whether SHI reduced farmers' agricultural
social learning by estimating a panel regression of the form:

```
IHS(Δ outcome_ct) = α + β SHI_c + γ High_LP_c + δ (SHI_c × High_LP_c) + X_c'ζ + λ_st + ε_ct
```

where `outcome` is either the share of farms reporting fertilizer expenditures
(Panel A) or wheat's share of farmland (Panel B), `Δ` denotes the
period-over-period first-difference, IHS is the inverse hyperbolic sine, and
`λ_st` are state×year fixed effects. Standard errors are clustered at the
`grid100m` level. Seven columns per panel:

| Col | Key variable | Sample |
|-----|-------------|--------|
| (1) | SHI | Full |
| (2) | High LP (no SHI) | Full |
| (3) | SHI + High LP | Full |
| (4) | SHI | High LP counties |
| (5) | SHI | Low LP counties |
| (6) | SHI + High LP + SHI×High LP | Full |
| (7) | LP ~ SHI (falsification) | Cross-section |

---

## 2. Learning Potential Construction

### 2.1 Panel A: gains5 (fertilizer panel)

**Algorithm:**
1. Download GAEZ v4 potential yield rasters: one high-input and one low-input
   raster per crop (ASC format, 500 m resolution, WGS84).
2. Compute raw difference raster: `diff = yield_high - yield_low`.
3. Standardize each difference raster to z-scores (global CONUS mean and SD).
4. Extract county-level means via `terra::extract()` using 2000 TIGER county
   boundaries (CONUS only, 3,109 counties).
5. Load NHGIS 1930 county crop acreage (file: `nhgis0002_ds212_1930_county.csv`).
6. Compute acreage-weighted mean of five standardized diffs → `gains5`.
7. Binarize at CONUS median → `high_gains5`.

**Crop species chosen (most common commercial variety for each genus):**

| Crop | Species | GAEZ subfolders |
|------|---------|----------------|
| Maize | Temperate maize, 120 days | `maize-high/`, `maize-low/` |
| Wheat | Winter wheat, 40+120 days | `wheat-high/`, `wheat-low/` |
| Cotton | Subtrop. cotton, 150 days | `cotton-high/`, `cotton-low/` |
| Oat | Oat, 105 days | `oat-high/`, `oat-low/` |
| Fodder | Grass, Cool C3 | `fodder-high/`, `fodder-low/` |

**Fodder acreage proxy:** ACA9004 (alfalfa) + ACA9005 (tame grasses) + ACA9006
(wild grasses) from NHGIS 1930.

**Output summary (3,109 CONUS counties):**
- Non-NA gains5: 3,068 counties (some have zero acreage in all 5 crops)
- gains5 range: −0.69 to 3.86 (median 2.01)
- high_gains5 = 1: 1,534 counties

### 2.2 Panel B: WheatDiff (wheat share panel)

Same GAEZ rasters but only the wheat pair, and the difference is **not**
standardized (raw kg/ha). County mean of the raw wheat diff → `WheatDiff`,
binarized at CONUS median → `high_wheat`.

- WheatDiff range: 0 to 7.65 (median 6.36)
- high_wheat = 1: 1,554 counties

---

## 3. Our Results vs. Paper

### Panel A: Fertilizer Adoption Growth

| Col | Key variable | Our estimate | Paper estimate | Significant? |
|-----|-------------|-------------|----------------|-------------|
| (1) | SHI | +0.023 (p=.091) | −0.771*** | No / Yes |
| (2) | High LP | −0.011 (p=.217) | — | No |
| (3) | SHI | +0.023 (p=.088) | — | No |
| (4) | SHI [High LP] | +0.025 (p=.141) | — | No |
| (5) | SHI [Low LP] | +0.014 (p=.354) | — | No |
| (6) | SHI | +0.008 (p=.640) | — | No |
| (6) | SHI×High LP | +0.028 (p=.281) | — | No |
| (7) | SHI→gains5 | +0.085 (p=.422) | — | No |

Observations: **5,912** (ours) vs **8,983** (paper).

### Panel B: Wheat Share Growth

| Col | Key variable | Our estimate | Paper estimate | Significant? |
|-----|-------------|-------------|----------------|-------------|
| (1) | SHI | −0.004 (p=.366) | −0.600*** | No / Yes |
| (2) | High LP | +0.002 (p=.597) | — | No |
| (3) | SHI | −0.004 (p=.347) | — | No |
| (4) | SHI [High LP] | −0.004 (p=.523) | — | No |
| (5) | SHI [Low LP] | +0.001 (p=.621) | — | No |
| (6) | SHI | −0.001 (p=.666) | — | No |
| (6) | SHI×High LP | −0.005 (p=.581) | — | No |
| (7) | SHI→WheatDiff | −0.690 (p=.211) | — | No |

Observations: **16,391** (ours) vs **19,531** (paper).

---

## 4. Reasons for Differences

### 4.1 Missing 1925 fertilizer wave (primary source for Panel A)

The released `FertilizersData.csv` contains observations for 1910, 1920, and
1930 only. The paper's N = 8,983 ≈ 2,994 counties × 3 periods implies a 1925
agricultural census round in the author's data. Our N = 5,912 corresponds to
approximately 2,956 counties × 2 periods (1920, 1930). This one-third reduction
in observations also changes which period-over-period changes are captured:
- Our periods: 1910→1920, 1920→1930
- Paper's likely: 1910→1920, 1920→1925, 1925→1930

The 1920→1930 aggregate likely has a different relationship with SHI than the
two sub-periods (1920→1925, 1925→1930), which may explain the sign reversal.

### 4.2 Crop species ambiguity

The paper does not specify which GAEZ v4 sub-species to use for each crop. We
selected the most common commercial variety (see Section 2.1), but the paper
may have used different sub-species. For example, there are multiple wheat
species at different growing periods (spring wheat, winter wheat at 35+105d,
40+120d, etc.). This creates measurement error in the `gains5` index that would
attenuate coefficients in columns (2)--(6).

### 4.3 County boundary matching

We use 2000 TIGER county boundaries for both the raster extraction (in
`10_build_learning_potential.R`) and the master panel (from
`CountyLevelData.csv`, which uses 2000 NHGIS boundaries). Historical census
data may cover different county configurations; the paper may use
contemporaneous boundaries for each census year. This explains the Panel B
N gap (16,391 vs 19,531, approximately 450 counties per period missing).

### 4.4 Missing controls

Waterway density, county area, and distance-to-market variables present in the
paper's specification (noted in Table 1 replication analysis) are absent from
the released replication package and excluded from our regressions.

### 4.5 Clustering level

The paper clusters at `grid100m` (approximately 100 km grid cells), yielding
many more clusters than our state-level clustering (48 states). With state
clustering and numerous state×year FE parameters, fixest reports non-positive-
semi-definite VCOV warnings for several fertilizer subsample regressions.
The auto-corrected SEs should be treated with caution, particularly for
columns (4) and (5).

---

## 5. What We Can and Cannot Verify

| Element | Status | Notes |
|---------|--------|-------|
| IHS panel regression structure | ✓ Matches | state×year FE, period-level FD |
| gains5 construction (algorithm) | ✓ Implemented | crop species may differ |
| WheatDiff construction | ✓ Implemented | same caveat |
| Panel B sign (SHI negative) | ✓ Correct direction | |
| Panel A sign (SHI negative) | ✗ Wrong sign | +0.023 vs paper's −0.771*** |
| Magnitudes | ✗ Much smaller | 40–200× smaller than paper |
| Statistical significance | ✗ None | all p > .08 |
| Panel A N = 8,983 | ✗ Not replicable | missing 1925 wave |
| Panel B N = 19,531 | ~ Partial | 84% coverage |
| Col (7) falsification direction | ✓ Near zero | no SHI → LP correlation |

---

## 6. Files

| File | Purpose |
|------|---------|
| `R/10_build_learning_potential.R` | Build `gains5`, `high_gains5`, `WheatDiff`, `high_wheat` from GAEZ v4 rasters + NHGIS 1930 |
| `data/LearningPotential_county.csv` | County-level LP variables (3,109 rows) |
| `R/04_table5_mechanisms.R` | All 7 columns, both panels, Word export |
| `output/tables/table5_mechanisms.docx` | Formatted regression table |
| `Report/Report.tex` | Narrative and LaTeX tables in Section 4.5 |
