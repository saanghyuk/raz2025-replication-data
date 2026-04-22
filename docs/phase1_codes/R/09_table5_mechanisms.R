# =============================================================================
# 04_table5_mechanisms.R
# Replication of Raz (2025) Table 5 — Soil Heterogeneity Limits Social Learning
#
# Panel A: SHI -> IHS growth in fertilizer adoption (1910-1930)
# Panel B: SHI -> IHS growth in wheat share of farmland (1880-1935)
#
# Outcome: inverse hyperbolic sine of the period-over-period first-difference.
#   Paper footnote 9: "growth rates in this section are right-skewed variables
#   that include zeros and negative values, I use the inverse hyperbolic sine."
#
# All 7 columns per panel:
#   (1) SHI + state x year FE + geoclimatic + smooth location (full sample)
#   (2) High LP + state x year FE + controls (no SHI) - LP main effect
#   (3) SHI + High LP + controls (full sample)
#   (4) SHI + controls, subsample: High LP counties
#   (5) SHI + controls, subsample: Low LP counties
#   (6) SHI + High LP + SHI x High LP interaction + controls (full sample)
#   (7) Falsification (cross-section): LP ~ SHI + state FE + controls
#
# Panel A uses high_gains5 (5-crop weighted LP) as the LP indicator.
# Panel B uses high_wheat  (wheat-only LP)      as the LP indicator.
#
# Output: output/tables/table5_mechanisms.docx
# =============================================================================

source(
  "/Users/ruihuaguo/Presentation_claude/Replication_project/Refined results/R/00_setup.R",
  local = FALSE
)

ihs <- function(x) log(x + sqrt(x^2 + 1))

# ---- Time-invariant county controls -----------------------------------------
# Collapse the decadal panel to one row per county; SHI + geo + location.
message("Building time-invariant county feature table...")
base <- load_panel()
tinv <- base |>
  arrange(gisjoin, year) |>
  group_by(gisjoin) |>
  summarise(
    state = first(state),
    shi   = first(shi),
    across(all_of(c(GEOCLIMATIC, SMOOTH_LOC,
                    CONTROLS_SUIT_MEAN, CONTROLS_HIGHER_SD)),
           first),
    .groups = "drop"
  )

# Merge learning potential
stopifnot(file.exists(LP_PATH))
lp <- read_csv(LP_PATH, show_col_types = FALSE) |>
  mutate(gisjoin = as.character(gisjoin))

tinv <- tinv |> left_join(lp, by = "gisjoin")

message(sprintf("  Counties with gains5:    %d", sum(!is.na(tinv$gains5))))
message(sprintf("  Counties with WheatDiff: %d", sum(!is.na(tinv$WheatDiff))))

# ---- Helper: OLS with custom key variable -----------------------------------
# Extends run_ols() to allow a key variable other than SHI.
run_ols_var <- function(data, y, key_var, controls = character(0),
                        fe_str = "state^year", cluster_var = "gisjoin") {
  needed <- unique(c(y, key_var, controls, cluster_var))
  d <- data |> drop_na(any_of(needed))
  if (nrow(d) == 0) stop("No obs after dropping NAs for: ", key_var)
  rhs <- paste(c(key_var, controls), collapse = " + ")
  fml_str <- if (nchar(fe_str) > 0)
    paste0(y, " ~ ", rhs, " | ", fe_str)
  else
    paste0(y, " ~ ", rhs)
  feols(as.formula(fml_str), data = d,
        cluster = as.formula(paste0("~", cluster_var)),
        warn = FALSE, notes = FALSE)
}

# ---- Helper: print one coefficient from a model ----------------------------
print_coef <- function(col_idx, m, key) {
  cn <- names(coef(m))
  if (key %in% cn) {
    cat(sprintf("  Col (%d): %-30s = %+.4f  SE=%.4f  p=%.3f  N=%d\n",
                col_idx, key,
                coef(m)[key], se(m)[key], pvalue(m)[key], nobs(m)))
  } else {
    cat(sprintf("  Col (%d): key '%s' not in model (coefs: %s)\n",
                col_idx, key, paste(cn[seq_len(min(4,length(cn)))],
                                    collapse=", ")))
  }
}

# =============================================================================
# PANEL A: Fertilizer Adoption
# =============================================================================
cat("\n============================================================\n")
cat("Table 5, Panel A: SHI -> Fertilizer Adoption Growth\n")
cat("============================================================\n")

stopifnot(file.exists(FERT_PATH))
fert_raw <- read_csv(FERT_PATH, show_col_types = FALSE) |>
  mutate(gisjoin = as.character(gisjoin),
         year    = as.integer(year)) |>
  arrange(gisjoin, year) |>
  group_by(gisjoin) |>
  mutate(
    delta_fert = share_farms_reporting_fert - lag(share_farms_reporting_fert)
  ) |>
  filter(!is.na(delta_fert)) |>
  mutate(ihs_fert = ihs(delta_fert)) |>
  ungroup() |>
  select(gisjoin, year, ihs_fert)

cat(sprintf("  Growth periods: %s\n",
            paste(sort(unique(fert_raw$year)), collapse=", ")))
cat(sprintf("  County-period obs (raw): %d\n", nrow(fert_raw)))

fert_panel <- fert_raw |>
  left_join(tinv, by = "gisjoin") |>
  drop_na(ihs_fert, shi, state)

cat(sprintf("  After merging controls: %d obs\n", nrow(fert_panel)))

# Col 1: SHI only (no LP)
fert_m1 <- run_ols(fert_panel, "ihs_fert",
                   controls    = CONTROLS_FULL,
                   fe_str      = "state^year",
                   cluster_var = "gisjoin")

# Col 2: High LP only (no SHI)
fert_m2 <- run_ols_var(fert_panel, "ihs_fert",
                       key_var     = "high_gains5",
                       controls    = CONTROLS_FULL,
                       fe_str      = "state^year",
                       cluster_var = "gisjoin")

# Col 3: SHI + High LP
fert_m3 <- run_ols(fert_panel, "ihs_fert",
                   controls    = c("high_gains5", CONTROLS_FULL),
                   fe_str      = "state^year",
                   cluster_var = "gisjoin")

# Cols 4-5: Subsample by LP
fert_panel_hi <- fert_panel |> filter(high_gains5 == 1)
fert_panel_lo <- fert_panel |> filter(high_gains5 == 0)

fert_m4 <- run_ols(fert_panel_hi, "ihs_fert",
                   controls    = CONTROLS_FULL,
                   fe_str      = "state^year",
                   cluster_var = "gisjoin")
fert_m5 <- run_ols(fert_panel_lo, "ihs_fert",
                   controls    = CONTROLS_FULL,
                   fe_str      = "state^year",
                   cluster_var = "gisjoin")

# Col 6: SHI x High LP interaction
fert_m6_data <- fert_panel |>
  drop_na(ihs_fert, shi, high_gains5, state)
fert_m6 <- feols(
  as.formula(paste0(
    "ihs_fert ~ shi * high_gains5 + ",
    paste(CONTROLS_FULL, collapse = " + "),
    " | state^year"
  )),
  data    = fert_m6_data,
  cluster = ~gisjoin, warn = FALSE, notes = FALSE
)

# Col 7: Falsification — gains5 ~ SHI (cross-sectional, one obs per county → state clustering)
tinv_cs7a <- tinv |> drop_na(gains5, shi, state)
fert_m7 <- feols(
  as.formula(paste0(
    "gains5 ~ shi + ",
    paste(CONTROLS_FULL, collapse = " + "),
    " | state"
  )),
  data    = tinv_cs7a,
  cluster = ~state, warn = FALSE, notes = FALSE
)

cat("\nCoefficients:\n")
print_coef(1, fert_m1, "shi")
print_coef(2, fert_m2, "high_gains5")
print_coef(3, fert_m3, "shi")
print_coef(4, fert_m4, "shi")
print_coef(5, fert_m5, "shi")
print_coef(6, fert_m6, "shi")
if ("shi:high_gains5" %in% names(coef(fert_m6)))
  print_coef(6, fert_m6, "shi:high_gains5")
print_coef(7, fert_m7, "shi")

# =============================================================================
# PANEL B: Wheat Share Growth
# =============================================================================
cat("\n============================================================\n")
cat("Table 5, Panel B: SHI -> Wheat Share Growth\n")
cat("============================================================\n")

stopifnot(file.exists(WHEAT_PATH))
wheat_raw <- read_csv(WHEAT_PATH, show_col_types = FALSE) |>
  mutate(gisjoin = as.character(gisjoin),
         year    = as.integer(year)) |>
  arrange(gisjoin, year) |>
  group_by(gisjoin) |>
  mutate(
    delta_wheat = wheat_share_of_farmland - lag(wheat_share_of_farmland)
  ) |>
  filter(!is.na(delta_wheat)) |>
  mutate(ihs_wheat = ihs(delta_wheat)) |>
  ungroup() |>
  select(gisjoin, year, ihs_wheat)

cat(sprintf("  Growth periods: %s\n",
            paste(sort(unique(wheat_raw$year)), collapse=", ")))
cat(sprintf("  County-period obs (raw): %d\n", nrow(wheat_raw)))

wheat_panel <- wheat_raw |>
  left_join(tinv, by = "gisjoin") |>
  drop_na(ihs_wheat, shi, state)

cat(sprintf("  After merging controls: %d obs\n", nrow(wheat_panel)))

# Col 1
wheat_m1 <- run_ols(wheat_panel, "ihs_wheat",
                    controls    = CONTROLS_FULL,
                    fe_str      = "state^year",
                    cluster_var = "gisjoin")

# Col 2: High wheat LP only (no SHI)
wheat_m2 <- run_ols_var(wheat_panel, "ihs_wheat",
                        key_var     = "high_wheat",
                        controls    = CONTROLS_FULL,
                        fe_str      = "state^year",
                        cluster_var = "gisjoin")

# Col 3: SHI + High wheat LP
wheat_m3 <- run_ols(wheat_panel, "ihs_wheat",
                    controls    = c("high_wheat", CONTROLS_FULL),
                    fe_str      = "state^year",
                    cluster_var = "gisjoin")

# Cols 4-5: Subsample
wheat_panel_hi <- wheat_panel |> filter(high_wheat == 1)
wheat_panel_lo <- wheat_panel |> filter(high_wheat == 0)

wheat_m4 <- run_ols(wheat_panel_hi, "ihs_wheat",
                    controls    = CONTROLS_FULL,
                    fe_str      = "state^year",
                    cluster_var = "gisjoin")
wheat_m5 <- run_ols(wheat_panel_lo, "ihs_wheat",
                    controls    = CONTROLS_FULL,
                    fe_str      = "state^year",
                    cluster_var = "gisjoin")

# Col 6: SHI x High wheat interaction
wheat_m6_data <- wheat_panel |>
  drop_na(ihs_wheat, shi, high_wheat, state)
wheat_m6 <- feols(
  as.formula(paste0(
    "ihs_wheat ~ shi * high_wheat + ",
    paste(CONTROLS_FULL, collapse = " + "),
    " | state^year"
  )),
  data    = wheat_m6_data,
  cluster = ~gisjoin, warn = FALSE, notes = FALSE
)

# Col 7: Falsification — WheatDiff ~ SHI (cross-sectional, one obs per county → state clustering)
tinv_cs7b <- tinv |> drop_na(WheatDiff, shi, state)
wheat_m7 <- feols(
  as.formula(paste0(
    "WheatDiff ~ shi + ",
    paste(CONTROLS_FULL, collapse = " + "),
    " | state"
  )),
  data    = tinv_cs7b,
  cluster = ~state, warn = FALSE, notes = FALSE
)

cat("\nCoefficients:\n")
print_coef(1, wheat_m1, "shi")
print_coef(2, wheat_m2, "high_wheat")
print_coef(3, wheat_m3, "shi")
print_coef(4, wheat_m4, "shi")
print_coef(5, wheat_m5, "shi")
print_coef(6, wheat_m6, "shi")
if ("shi:high_wheat" %in% names(coef(wheat_m6)))
  print_coef(6, wheat_m6, "shi:high_wheat")
print_coef(7, wheat_m7, "shi")

# =============================================================================
# Export to Word
# =============================================================================
notes_t5 <- paste0(
  "Notes: OLS estimates of equation (1). ",
  "Panel A: dependent variable is the IHS of the period-over-period change in ",
  "the share of farms reporting fertilizer expenditures (1910-1930); panel has ",
  "two growth periods (end-year 1920 and 1930). ",
  "Panel B: dependent variable is the IHS of the period-over-period change in ",
  "wheat's share of farmland (1880-1935); panel has seven growth periods. ",
  "Cols (1)-(3) and (6) use the full sample; (4) and (5) subset to High or Low ",
  "learning potential counties; (7) is a cross-sectional falsification regression ",
  "with gains5 (Panel A) or WheatDiff (Panel B) as the dependent variable. ",
  "High learning potential = 1 for counties above the median of the acreage-weighted ",
  "standardized yield-difference index (gains5, Panel A) or the raw wheat yield ",
  "difference (WheatDiff, Panel B), both built from GAEZ v4 rasters (crop species: ",
  "Temperate maize 120d / Winter wheat 40+120d / Subtrop. cotton 150d / Oat 105d / ",
  "Grass Cool C3; acreage weights from NHGIS 1930). ",
  "State x year FE in cols (1)-(6); state FE in col (7). ",
  "Geoclimatic and smooth location controls throughout. ",
  "SE clustered at county level (cols 1-6); state level in col (7) cross-section. * p<0.10, ** p<0.05, *** p<0.01."
)

coef_map_a <- c(
  "shi"           = "Soil Heterogeneity Index",
  "high_gains5"   = "High learning potential",
  "shi:high_gains5" = "SHI x High learning potential"
)
coef_map_b <- c(
  "shi"          = "Soil Heterogeneity Index",
  "high_wheat"   = "High learning potential",
  "shi:high_wheat" = "SHI x High learning potential"
)

models_a <- list(
  "(1)"      = fert_m1, "(2)"      = fert_m2, "(3)"      = fert_m3,
  "(4) Hi"   = fert_m4, "(5) Lo"   = fert_m5, "(6)"      = fert_m6,
  "(7) LP~SHI" = fert_m7
)
models_b <- list(
  "(1)"      = wheat_m1, "(2)"      = wheat_m2, "(3)"      = wheat_m3,
  "(4) Hi"   = wheat_m4, "(5) Lo"   = wheat_m5, "(6)"      = wheat_m6,
  "(7) LP~SHI" = wheat_m7
)

ms_a <- modelsummary(
  models_a,
  output   = "flextable",
  stars    = c("*"=0.10, "**"=0.05, "***"=0.01),
  coef_map = coef_map_a,
  gof_map  = list(
    list(raw="nobs",      clean="Observations", fmt=0),
    list(raw="r.squared", clean="R\u00b2",      fmt=3)
  ),
  title = "Table 5, Panel A. Soil Heterogeneity and Fertilizer Adoption Growth"
) |>
  bold(part="header") |>
  bg(i=c(2, 4, 6), bg="#F2F2F2", part="body") |>
  fontsize(size=10, part="all") |>
  font(fontname="Times New Roman", part="all") |>
  autofit()

ms_b <- modelsummary(
  models_b,
  output   = "flextable",
  stars    = c("*"=0.10, "**"=0.05, "***"=0.01),
  coef_map = coef_map_b,
  gof_map  = list(
    list(raw="nobs",      clean="Observations", fmt=0),
    list(raw="r.squared", clean="R\u00b2",      fmt=3)
  ),
  title = "Table 5, Panel B. Soil Heterogeneity and Wheat Share Growth",
  notes = notes_t5
) |>
  bold(part="header") |>
  bg(i=c(2, 4, 6), bg="#F2F2F2", part="body") |>
  fontsize(size=10, part="all") |>
  font(fontname="Times New Roman", part="all") |>
  autofit()

out_path <- file.path(OUT_TABS, "table5_mechanisms.docx")
doc <- read_docx() |>
  body_add_par("Table 5. Soil Heterogeneity Limits Farmers' Social Learning",
               style = "heading 1") |>
  body_add_par("Panel A: Fertilizer Adoption Growth", style = "heading 2") |>
  body_add_flextable(ms_a) |>
  body_add_par("") |>
  body_add_par("Panel B: Wheat Share Growth", style = "heading 2") |>
  body_add_flextable(ms_b)
print(doc, target = out_path)
message("Saved: ", out_path)
cat("\nTable 5 complete. All 7 columns for both panels.\n")
