# =============================================================================
# 03_table1_main_results.R
# Replication of Raz (2025)
#
# Purpose: Replicate Table 1 of Raz (2025) — "Soil Heterogeneity Created
#          Loose-Knit Communities."
#
# Table structure (paper):
#   6 columns × 4 panels (LNI, ICM, TNI, RHI)
#   We replicate panels A (LNI) and D (RHI) for columns 1-6.
#   Panels B (ICM) and C (TNI) require IPUMS full-count individual data
#   (contractually restricted). This is documented clearly.
#
# Columns:
#   (1) SHI only, no FE, clustered SE at state
#   (2) + state x year FE
#   (3) + geo-climatic controls
#   (4) + smooth location polynomial (preferred specification in v1)
#   (5) + agricultural suitability controls (10 crop suitability means,
#        GAEZ v3, rain-fed, intermediate inputs)
#   (6) + higher-order controls (SDs of 5 geo-climatic variables and SDs
#        of the 10 suitability indices)
#
# Key correction from v1:
#   - v1 called this "Table 2" — mislabeled (paper's Table 2 is the
#     individual-level selection analysis using Census Linking Project)
#   - v1 never ran the RHI panel despite data being available
#   - v1 sign in col (1) reversal documented here
#
# Output: output/tables/table1_lni.docx
#         output/tables/table1_rhi.docx
# =============================================================================

source("/Users/ruihuaguo/Presentation_claude/Replication_project/Refined results/R/00_setup.R", local = FALSE)

panel <- load_panel()

# ---- Helper: run 6-column sequence for one outcome --------------------------
run_six_cols <- function(data, y_var, panel_label) {
  cat(sprintf("\n--- Panel %s: SHI -> %s ---\n", panel_label, y_var))

  # (1) SHI only, no FE
  m1 <- run_ols(data, y_var, controls = character(0),
                fe_str = "", cluster_var = "gisjoin")
  cat(sprintf("  Col (1) no controls:       SHI = %+.4f (SE = %.4f, p = %.3f, N = %d)\n",
              coef(m1)["shi"], se(m1)["shi"], pvalue(m1)["shi"], nobs(m1)))

  # (2) + state x year FE only
  m2 <- run_ols(data, y_var, controls = character(0),
                fe_str = "state^year", cluster_var = "gisjoin")
  cat(sprintf("  Col (2) state x year FE:   SHI = %+.4f (SE = %.4f, p = %.3f, N = %d)\n",
              coef(m2)["shi"], se(m2)["shi"], pvalue(m2)["shi"], nobs(m2)))

  # (3) + geo-climatic controls
  m3 <- run_ols(data, y_var, controls = GEOCLIMATIC,
                fe_str = "state^year", cluster_var = "gisjoin")
  cat(sprintf("  Col (3) + geo-climatic:    SHI = %+.4f (SE = %.4f, p = %.3f, N = %d)\n",
              coef(m3)["shi"], se(m3)["shi"], pvalue(m3)["shi"], nobs(m3)))

  # (4) + smooth location polynomial
  m4 <- run_ols(data, y_var, controls = CONTROLS_FULL,
                fe_str = "state^year", cluster_var = "gisjoin")
  cat(sprintf("  Col (4) + smooth loc:      SHI = %+.4f (SE = %.4f, p = %.3f, N = %d)\n",
              coef(m4)["shi"], se(m4)["shi"], pvalue(m4)["shi"], nobs(m4)))

  # (5) + agricultural suitability means
  c5 <- c(CONTROLS_FULL, CONTROLS_SUIT_MEAN)
  m5 <- run_ols(data, y_var, controls = c5,
                fe_str = "state^year", cluster_var = "gisjoin")
  cat(sprintf("  Col (5) + agri suitability:SHI = %+.4f (SE = %.4f, p = %.3f, N = %d)\n",
              coef(m5)["shi"], se(m5)["shi"], pvalue(m5)["shi"], nobs(m5)))

  # (6) + higher-order controls (SDs)
  c6 <- c(CONTROLS_FULL, CONTROLS_SUIT_MEAN, CONTROLS_HIGHER_SD)
  m6 <- run_ols(data, y_var, controls = c6,
                fe_str = "state^year", cluster_var = "gisjoin")
  cat(sprintf("  Col (6) + higher-order SDs:SHI = %+.4f (SE = %.4f, p = %.3f, N = %d)\n",
              coef(m6)["shi"], se(m6)["shi"], pvalue(m6)["shi"], nobs(m6)))

  list(m1 = m1, m2 = m2, m3 = m3, m4 = m4, m5 = m5, m6 = m6)
}

# ---- Panel A: LNI -----------------------------------------------------------
cat("\n============================================================")
cat("\nTable 1, Panel A: SHI → Local Name Index (LNI)")
cat("\n============================================================")

n_lni <- panel |> filter(!is.na(lni)) |> nrow()
cat(sprintf("\nLNI non-missing rows: %d (years: %s)\n",
            n_lni,
            paste(sort(unique(panel$year[!is.na(panel$lni)])), collapse = ", ")))

lni_mean <- mean(panel$lni, na.rm = TRUE)
lni_sd   <- sd(panel$lni, na.rm = TRUE)
cat(sprintf("LNI: mean = %.1f, SD = %.1f\n", lni_mean, lni_sd))
cat("Note: Paper reports LNI mean = 67.8, SD = 6.3 (full-count census).\n")
cat("Our LNI uses IPUMS 1% sample — measurement error causes attenuation bias.\n")

cols_lni <- run_six_cols(panel, "lni", "A")

# ---- Panel D: RHI -----------------------------------------------------------
cat("\n============================================================")
cat("\nTable 1, Panel D: SHI → Religious Homogeneity Index (RHI)")
cat("\n============================================================")

# FIX vs. v1:
#   (a) v1 used `religious_diversity_index = 1 - HHI` (diversity form),
#       so our code inverts to homogeneity: rhi = 1 - diversity.
#   (b) v1's master panel silently dropped waves 1906/1916/1926 at merge
#       (CountyLevelData.csv is decadal: 1850..1940). The paper uses the
#       non-decadal religion census waves 1890/1906/1916/1926/1936.
#       We rebuild RHI directly from raw NHGIS tables (R/04_build_rhi.R)
#       and run Panel D on a religion-specific panel with all 7 available
#       waves (1850/60/70/1890/1906/1916/1926), time-invariant controls
#       joined from the master panel.
#   MARK-1936: add a 1936 entry to WAVE_SPECS in R/04_build_rhi.R and
#              rerun; this script picks up the extra wave automatically.
panel_rhi <- load_panel_rhi()

n_rhi <- panel_rhi |> filter(!is.na(rhi_z)) |> nrow()
cat(sprintf("\nRHI non-missing rows: %d (years: %s)\n",
            n_rhi,
            paste(sort(unique(panel_rhi$year[!is.na(panel_rhi$rhi_z)])),
                  collapse = ", ")))

cols_rhi <- run_six_cols(panel_rhi, "rhi_z", "D")

# ---- Note on missing panels -------------------------------------------------
cat("\n============================================================")
cat("\nPanels B (ICM) and C (TNI) — NOT REPLICATED")
cat("\n============================================================")
cat("\nICM (intracommunity marriage share) requires IPUMS full-count census")
cat("\n  microdata identifying married couples' shared birthplace state.")
cat("\nTNI (tight norms index) is a PCA composite of mother's age at first birth,")
cat("\n  number of children, and household family count from IPUMS full-count census.")
cat("\nBoth require full-count individual-level IPUMS data (Ruggles et al. 2020),")
cat("\n  which requires a special data agreement. We have only the 1% public sample.\n")

# ---- Export Word tables -------------------------------------------------------
notes_lni <- paste(
  "Notes: OLS estimates of equation (1). Dependent variable is the county-level",
  "average Local Name Index (LNI), constructed from IPUMS 1% census samples",
  "(years 1850-1930). LNI measures the probability that a child's first name is",
  "given locally relative to nationally. Geoclimatic controls include mean elevation,",
  "slope, temperature, precipitation, flow accumulation, and river density.",
  "Smooth location controls are a second-order polynomial in latitude and longitude.",
  "Agricultural suitability controls (col 5) are mean GAEZ v3 suitability indices",
  "(rain-fed, intermediate inputs, 1961-1990 baseline) for the 10 crops ranked",
  "highest by 1859 output value: alfalfa, cotton, maize, oat, rye, sugar cane,",
  "sweet potato, tobacco, wheat, and white potato. Higher-order controls (col 6)",
  "add the SDs of the five geo-climatic variables and the SDs of the 10 suitability",
  "indices. Standard errors clustered at the county level (gisjoin; paper clusters at 100",
  "sq. mile grid cells). Paper uses full-count census data; our 1% sample",
  "introduces measurement error attenuating the SHI coefficient toward zero.",
  "* p<0.10, ** p<0.05, *** p<0.01."
)

models_lni <- list(
  "(1)" = cols_lni$m1,
  "(2)" = cols_lni$m2,
  "(3)" = cols_lni$m3,
  "(4)" = cols_lni$m4,
  "(5)" = cols_lni$m5,
  "(6)" = cols_lni$m6
)

ms_lni <- modelsummary(
  models_lni,
  output = "flextable",
  stars  = c("*" = 0.10, "**" = 0.05, "***" = 0.01),
  coef_map = c("shi" = "Soil Heterogeneity Index"),
  gof_map  = list(
    list(raw = "nobs",      clean = "Observations", fmt = 0),
    list(raw = "r.squared", clean = "R\u00b2",      fmt = 3)
  ),
  title = paste0("Table 1, Panel A. SHI and Local Name Index",
                 " (Mean = ", round(lni_mean, 1), ", SD = ", round(lni_sd, 1), ")"),
  notes = notes_lni
) |>
  add_header_row(
    values = c("", "No FE", "State\u00d7Year FE",
               "Geoclimatic", "Smooth Loc.",
               "+ Agri Suit.", "+ Higher-order SDs"),
    colwidths = c(1, 1, 1, 1, 1, 1, 1)
  ) |>
  bold(part = "header") |>
  bg(i = seq(2, 4, 2), bg = "#F2F2F2", part = "body") |>
  fontsize(size = 10, part = "all") |>
  font(fontname = "Times New Roman", part = "all") |>
  autofit()

doc_lni <- read_docx() |> body_add_flextable(ms_lni)
out_lni <- file.path(OUT_TABS, "table1_panel_a_lni.docx")
print(doc_lni, target = out_lni)
message("Saved: ", out_lni)

# --- RHI table ---
notes_rhi <- paste(
  "Notes: OLS estimates of equation (1). Dependent variable is the county-level",
  "Religious Homogeneity Index (RHI = HHI of denominational shares; higher =",
  "more concentrated/homogeneous), standardized to z-scores within year.",
  "Rebuilt from raw NHGIS Census of Religious Bodies tables (Manson et al. 2020;",
  "7 waves: 1850, 1860, 1870 as churches-proxy; 1890, 1906, 1916, 1926 as member counts).",
  "Paper uses an 8th wave (1936) which is not yet available in our NHGIS extract;",
  "a hook (MARK-1936) lets us append that wave without code changes.",
  "Controls as in Panel A: geo-climatic (col 3), smooth location polynomial (col 4),",
  "agricultural suitability means for the 10 crops ranked highest by 1859 output value",
  "(col 5), and higher-order SDs of geo-climatic variables and suitability indices (col 6).",
  "Paper's preferred Panel D estimate is -0.376 (SD units).",
  "* p<0.10, ** p<0.05, *** p<0.01."
)

rhi_mean <- mean(panel_rhi$rhi_z, na.rm = TRUE)
rhi_sd   <- sd(panel_rhi$rhi_z, na.rm = TRUE)

models_rhi <- list(
  "(1)" = cols_rhi$m1,
  "(2)" = cols_rhi$m2,
  "(3)" = cols_rhi$m3,
  "(4)" = cols_rhi$m4,
  "(5)" = cols_rhi$m5,
  "(6)" = cols_rhi$m6
)

ms_rhi <- modelsummary(
  models_rhi,
  output = "flextable",
  stars  = c("*" = 0.10, "**" = 0.05, "***" = 0.01),
  coef_map = c("shi" = "Soil Heterogeneity Index"),
  gof_map  = list(
    list(raw = "nobs",      clean = "Observations", fmt = 0),
    list(raw = "r.squared", clean = "R\u00b2",      fmt = 3)
  ),
  title = "Table 1, Panel D. SHI and Religious Homogeneity Index (standardized, Mean = 0, SD = 1)",
  notes = notes_rhi
) |>
  add_header_row(
    values = c("", "No FE", "State\u00d7Year FE",
               "Geoclimatic", "Smooth Loc.",
               "+ Agri Suit.", "+ Higher-order SDs"),
    colwidths = c(1, 1, 1, 1, 1, 1, 1)
  ) |>
  bold(part = "header") |>
  bg(i = seq(2, 4, 2), bg = "#F2F2F2", part = "body") |>
  fontsize(size = 10, part = "all") |>
  font(fontname = "Times New Roman", part = "all") |>
  autofit()

doc_rhi <- read_docx() |> body_add_flextable(ms_rhi)
out_rhi <- file.path(OUT_TABS, "table1_panel_d_rhi.docx")
print(doc_rhi, target = out_rhi)
message("Saved: ", out_rhi)

cat("\nTable 1 complete. Two Word tables exported.\n")
