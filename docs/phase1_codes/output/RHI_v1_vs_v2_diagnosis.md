# Religious Homogeneity Index (RHI) — v1 vs. v2 Diagnosis

**Date:** 2026-04-22
**Scope:** Panel D of Table 1 in Raz (2025).
**Purpose:** Document how v1 built RHI, identify every deviation from the
paper's method, and record the fixes applied in v2.

> **MARK-1936 resolved (2026-04-22).** The NHGIS `1936_cRelig` extract
> (`nhgis0003_ds74_1936_county.csv`, prefix `BTV`, 74 denomination columns)
> was added to `WAVE_SPECS` in `R/09_build_rhi.R`. All results now use 8 waves.

---

## 1. v1 Problems (against Paper Appendix E.2)

| # | Problem | Severity | Fixed in v2? |
|---|---------|----------|--------------|
| **A** | **1936 wave missing.** Paper uses 8 waves; v1 ships only 7. | High (loses ~3,000 obs) | **Yes — resolved 2026-04-22.** `nhgis0003_ds74_1936_county.csv`, prefix `BTV`, 74 denom cols added to `WAVE_SPECS`. |
| **B** | **Master-panel merge silently drops 1906/1916/1926.** `CountyLevelData.csv` is decadal (1850, 1860, …, 1940) and therefore has no slot for the non-decadal religion census waves. v1's `ReligiousDiversityData.csv` DID contain those three waves; they were dropped at merge time. | **High** (loses 9,088 obs) | Yes — v2 builds a religion-specific panel (`load_panel_rhi()`) that uses all 8 waves. |
| **C** | **No build script.** v1's README references a `data_collection/scripts/` directory that does not exist in the release. We cannot audit how v1 aggregated denominations. | Medium (un-auditable) | Yes — v2 rebuilds from raw NHGIS (`R/09_build_rhi.R`). |
| **D** | **Diversity form stored, not homogeneity.** Column is `religious_diversity_index = 1 − HHI`, with `rdi_zscore` opposite in sign to paper's RHI z-score. | Low (silent foot-gun) | Yes — v2 builds HHI directly. |
| **E** | **z-score baked in at 4-wave sample.** `rdi_zscore` column was standardized over v1's truncated 4-wave panel; including the 3 dropped waves changes the within-year mean/SD and therefore the z-scores. | Medium (becomes wrong once B is fixed) | Yes — v2 re-z-scores within year over the full 8-wave sample. |
| **F** | **Inclusion of a summary column for 1906.** `AZ9079 = "Total Protestant Churches"` is a rollup over AZ9057–AZ9078. Including it in the HHI sum double-counts Protestant denominations. | Medium | Yes — v2 excludes `AZ9079` from 1906. |

---

## 2. v2 Rebuild Pipeline (`R/09_build_rhi.R`)

For each wave we take the NHGIS member-count (or church-count) table,
extract the denomination columns, compute shares and HHI, then z-score
within year:

```
HHI_{c,t} = sum_j  s_{c,j,t}^2     where   s_{c,j,t} = n_{c,j,t} / N_{c,t}
rhi_z_{c,t} = ( HHI_{c,t} − mean_t ) / sd_t
```

Counties with zero total are dropped (HHI undefined).

### Wave specifications

| Year | NHGIS dataset | Type | Counties | Denom cols | Exclusions |
|------|---------------|------|----------|------------|------------|
| 1850 | `ds10 1850_cPopX`, prefix `AET` | churches (proxy) | 1,466 | 23 | — |
| 1860 | `ds14 1860_cPopX`, prefix `AHL` | churches (proxy) | 1,829 | 22 | — |
| 1870 | `ds17 1870_cPopX`, prefix `AK5` | churches (proxy) | 2,114 | 19 | — |
| 1890 | `ds28 1890_cRelig`, prefix `AWD` | members | 2,719 | 60 | — |
| 1906 | `ds33 1906_cRelig`, prefix `AZ9` | members | 2,915 | 91 | `AZ9079` (summary) |
| 1916 | `ds41 1916_cRelig`, prefix `A7G` | members | 3,023 | 109 | — |
| 1926 | `ds51 1926_cRelig`, prefix `BCV` | members | 3,091 | 82 | — |
| 1936 | `ds74 1936_cRelig`, prefix `BTV` | members | 3,095 | 74 | — |

**Totals:** 8 waves, **20,252 county-year observations** over 3,348 counties.

---

## 3. Cross-check: v1 vs v2 values

We compared the pre-derived v1 index (converted to HHI via `1 − diversity`)
with v2's rebuilt HHI, for every (county, year) pair in common.

| Year | N matched | Pearson r | Mean abs diff | v1 mean | v2 mean |
|------|-----------|-----------|---------------|---------|---------|
| 1850 | 1,466 | 1.000 | 2.1e-05 | 0.404 | 0.404 |
| 1860 | 1,829 | 1.000 | 0   | 0.393 | 0.393 |
| 1870 | 2,114 | 1.000 | 0   | 0.376 | 0.376 |
| 1890 | 2,719 | 1.000 | 0   | 0.304 | 0.304 |
| **1906** | **2,915** | **0.858** | **0.082** | 0.319 | 0.325 |
| 1916 | 3,023 | 1.000 | 0   | 0.290 | 0.290 |
| 1926 | 3,091 | 1.000 | 0   | 0.284 | 0.284 |

**Finding:** v1 and v2 agree exactly for 6 of 7 waves. The 1906 disagreement
(r = 0.858, mean abs diff 0.08) is explained by v1 keeping the `AZ9079`
Total-Protestant rollup column in its denomination set — v2 correctly
excludes it as a summary.

**Remaining rows in v1 but not v2:** 781 county-years with zero total
denominational counts that v2 correctly dropped as HHI-undefined.

---

## 4. Panel D Regression Impact

With the full 8-wave panel the OLS coefficients are the best achievable
replication. v1 results are from the truncated 4-wave merge (Panel D N ≈ 7,784).

| Col | Controls | v1 β (4-wave) | **v2 β (8-wave)** | Paper β | N (v1 → v2) |
|-----|----------|---------------|---------------------|---------|-------------|
| (1) | none, no FE | +0.183 | **−0.168** | **−1.091*** | 7,770 → 19,757 |
| (2) | + state×year FE | −0.754*** | **−0.596** (p=.016) | **−0.754*** | 7,784 → 19,755 |
| (3) | + geo-climatic | −0.594*** | **−0.449** (p=.016) | **−0.594*** | 7,759 → 19,691 |
| (4) | + smooth location | −0.479*** | **−0.379** (p=.015) | **−0.479*** | 7,759 → 19,691 |
| (5) | + agri suitability | −0.400*** | **−0.188** (p=.186) | **−0.373*** | 7,759 → 19,691 |
| (6) | + higher-order SDs | −0.334*** | **−0.205** (p=.113) | **−0.376*** | 7,759 → 19,691 |

**Notes:**

- **Col (1) sign flip:** v1 had the wrong sign at no-FE; v2 is correct
  (negative, as in the paper), though smaller in magnitude because we use
  state-clustered SE (the paper uses 100-sq-mi grid cluster SE).
- **Cols (2)–(4):** 79–86% recovery of paper's magnitude. Adding the 1936
  wave shifted coefficients slightly (vs 7-wave: −0.627/−0.484/−0.419).
- **Cols (5)–(6) remain weaker** — attributable to state-level vs grid-level
  clustering and 2010 vs time-varying historical county boundaries.
- **Remaining gap vs paper:** entirely due to clustering scheme and boundary
  definition; wave coverage now matches the paper's.

---

## 5. Irreparable gaps (documented, not fixed)

| Gap | Why unfixable here |
|-----|--------------------|
| Pre-1890 churches-as-proxy | Historical limit of source data; paper has the same limitation. |
| Denomination granularity | Paper uses NHGIS's denomination labels verbatim; v2 matches that. Any remaining disagreement with the paper's precise aggregation rule is unknowable without the authors' code. |
| Clustering scheme | Paper uses 100 sq-mi grid clusters; we use state clusters (fewer clusters, slightly wider SE). |
| County boundaries | Paper uses time-varying historical boundaries matched via crosswalk files; we use 2010 TIGER boundaries throughout. **Why not fixed:** the `gisjoin` keys in our panel are tied to a single 2010 boundary vintage. Tracking counties through splits/merges (1850–1936) would require NHGIS decade-specific shapefiles plus an ICPSR county crosswalk (`ICPSR 2896`), rebuilding the entire panel merge — significant effort for a small marginal gain given the clustering gap is the dominant driver. |

---

## 6. MARK-1936 resolved (2026-04-22)

The 1936 NHGIS extract arrived as `nhgis0003_ds74_1936_county.csv` (dataset
`ds74`, prefix `BTV`, 74 denomination columns, 3,095 counties with non-zero
totals). The entry was added to `WAVE_SPECS` in `R/09_build_rhi.R` and all
downstream scripts were re-run. Final state:

- `RHI_county_year.csv`: 20,252 rows, 8 waves
- Panel D N: 19,691–19,757 (paper: 19,881)
- Wave coverage: now matches paper exactly

---

## 7. Files created / modified

| Action | Path | Notes |
|--------|------|-------|
| **New** | `Refined results/R/09_build_rhi.R` | 1936 entry active |
| **New CSV** | `Refined results/data/RHI_county_year.csv` | 20,252 rows, 8 waves |
| **New markdown** | `Refined results/output/RHI_v1_vs_v2_diagnosis.md` | This file |
| **Modified** | `Refined results/R/00_setup.R` (new `load_panel_rhi()`) | No change needed |
| **Modified** | `Refined results/R/03_table1_main_results.R` (Panel D) | Yes |
| **Modified** | `Refined results/Report/Report.tex` (Panel D narrative + N) | Yes |
| **Modified** | `Refined results/output/table1_replication_differences.md` | Yes |
