# =============================================================================
# 00_setup.R
# Replication of Raz (2025) "Soil Heterogeneity, Social Learning, and the
# Formation of Close-Knit Communities" — Journal of Political Economy 133(8)
#
# Purpose: Load packages, define paths, and define shared helper functions
#          used by all analysis scripts.
# =============================================================================

# ---- Packages ----------------------------------------------------------------
required_packages <- c(
  "tidyverse",    # data manipulation and ggplot2
  "fixest",       # OLS/2SLS with fixed effects and clustered SE
  "modelsummary", # publication-quality regression tables
  "flextable",    # Word-compatible table formatting
  "officer",      # export .docx files
  "sf",           # spatial data handling
  "tigris",       # US county shapefiles
  "scales",       # scale helpers for ggplot2
  "broom",        # tidy model outputs
  "classInt",     # quantile bin classification for choropleth maps
  "ggspatial"     # compass rose and scale bar annotations
)

for (pkg in required_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    install.packages(pkg, repos = "https://cloud.r-project.org")
  }
  library(pkg, character.only = TRUE)
}

# ---- Paths -------------------------------------------------------------------
# Absolute project root — works in both RStudio and Rscript.
PROJ_ROOT   <- "/Users/ruihuaguo/Presentation_claude/Replication_project"
DATA_DIR    <- file.path(PROJ_ROOT, "BZD6004_Final_Project_v1", "data")
OUT_FIGS    <- file.path(PROJ_ROOT, "Refined results", "output", "figures")
OUT_TABS    <- file.path(PROJ_ROOT, "Refined results", "output", "tables")
SHI_V2_PATH     <- file.path(PROJ_ROOT, "Refined results", "data",
                              "SoilHeterogeneityIndex_rasterDissimilarity_v2.csv")
GEOCLIM_SD_PATH <- file.path(PROJ_ROOT, "Refined results", "data",
                              "GeoClim_SD_county.csv")
AGRI_SUIT_PATH  <- file.path(PROJ_ROOT, "Refined results", "data",
                              "AgriSuitability_county.csv")
# Religious Homogeneity Index, rebuilt from raw NHGIS Census of Religious
# Bodies tables (see R/04_build_rhi.R). All 8 waves 1850-1936.
RHI_PATH        <- file.path(PROJ_ROOT, "Refined results", "data",
                              "RHI_county_year.csv")

# Learning Potential (gains5 / WheatDiff) from GAEZ v4 rasters + NHGIS 1930.
# Built by R/05_build_learning_potential.R. Used in Table 5 columns 2-7.
LP_PATH    <- file.path(PROJ_ROOT, "Refined results", "data",
                        "LearningPotential_county.csv")

# Fertilizer and wheat panel datasets from the released replication package.
FERT_PATH  <- file.path(PROJ_ROOT, "Refined results", "data",
                        "FertilizersData.csv")
WHEAT_PATH <- file.path(PROJ_ROOT, "Refined results", "data",
                        "WheatShareData.csv")

# Ensure output directories exist
dir.create(OUT_FIGS, showWarnings = FALSE, recursive = TRUE)
dir.create(OUT_TABS, showWarnings = FALSE, recursive = TRUE)

# ---- Data loading ------------------------------------------------------------
load_panel <- function() {
  path <- file.path(DATA_DIR, "CountyLevelData.csv")
  stopifnot(file.exists(path))
  d <- read_csv(path, show_col_types = FALSE)
  d <- d |>
    mutate(
      state    = as.character(as.integer(state)),
      year     = as.integer(year),
      gisjoin  = as.character(gisjoin)
    )
  # Replace v1 area-share HHI complement with v2 raster-dissimilarity SHI
  # (paper's Appendix E.1: 500 m grid, 51x51 window, county mean)
  stopifnot(file.exists(SHI_V2_PATH))
  shi_v2 <- read_csv(SHI_V2_PATH, show_col_types = FALSE) |>
    select(gisjoin, shi_v2 = shi_raster)
  d <- d |>
    select(-shi) |>
    left_join(shi_v2, by = "gisjoin") |>
    rename(shi = shi_v2)

  # Merge newly built county-level controls for Table 1 columns 5 and 6.
  # These files are produced by R/02_build_geoclim_sd.R and
  # R/03_build_agri_suitability.R (2000 NHGIS county boundaries).
  if (file.exists(GEOCLIM_SD_PATH)) {
    geoclim_sd <- read_csv(GEOCLIM_SD_PATH, show_col_types = FALSE)
    d <- left_join(d, geoclim_sd, by = "gisjoin")
  } else {
    warning("GeoClim_SD_county.csv not found — col 6 will not be available.")
  }
  if (file.exists(AGRI_SUIT_PATH)) {
    agri_suit <- read_csv(AGRI_SUIT_PATH, show_col_types = FALSE)
    d <- left_join(d, agri_suit, by = "gisjoin")
  } else {
    warning("AgriSuitability_county.csv not found — cols 5-6 will not be available.")
  }
  return(d)
}

# ---- RHI-specific panel loader ----------------------------------------------
# The master panel from v1 is decadal (1850, 1860, ..., 1940). The paper's
# RHI is observed at non-decadal religion census waves (1890, 1906, 1916,
# 1926, 1936). To run Panel D with all available waves, build a religion-
# specific panel:  RHI table x time-invariant county controls (SHI v2,
# geoclimatic means, suitability means, their SDs). All Panel-D controls
# ARE time-invariant at the county level in CountyLevelData.csv — verified.
#
# MARK-1936: this function requires no change when the 1936 wave is added;
# just rerun R/04_build_rhi.R after adding the 1936 entry to WAVE_SPECS.
load_panel_rhi <- function() {
  stopifnot(file.exists(RHI_PATH))
  rhi <- read_csv(RHI_PATH, show_col_types = FALSE) |>
    mutate(gisjoin = as.character(gisjoin),
           year    = as.integer(year))

  # Time-invariant county features come from the decadal master panel.
  # Use the earliest observation per county (all rows identical by gisjoin
  # for these columns — verified in setup probe).
  base <- suppressWarnings(load_panel())
  tinv_cols <- unique(c("state", "gisjoin", "shi",
                        GEOCLIMATIC, SMOOTH_LOC,
                        CONTROLS_SUIT_MEAN, CONTROLS_HIGHER_SD))
  tinv_cols <- intersect(tinv_cols, names(base))
  tinv <- base |>
    arrange(gisjoin, year) |>
    group_by(gisjoin) |>
    summarise(across(all_of(setdiff(tinv_cols, "gisjoin")), first),
              .groups = "drop")

  rhi |>
    left_join(tinv, by = "gisjoin") |>
    mutate(state = as.character(state))
}

# ---- Control variable sets ---------------------------------------------------
# Geo-climatic controls (available in data)
GEOCLIMATIC <- c(
  "mean_elevation_m", "mean_slope_deg",
  "mean_annual_temp_c", "mean_annual_precip_mm",
  "mean_flow_accum", "river_density"
)

# Smooth location polynomial (2nd-order lat/lon)
SMOOTH_LOC <- c("centroid_lat", "centroid_lon", "lat_sq", "lon_sq", "lat_x_lon")

# Full control set (preferred specification, cols 3-4)
CONTROLS_FULL <- c(GEOCLIMATIC, SMOOTH_LOC)

# Agricultural suitability means — 10 crops ranked by 1859 output value
# (col 5, paper Appendix E.3). GAEZ v3, rain-fed, intermediate inputs.
CROP_KEYS <- c("alfalfa", "cotton", "maize", "oat", "rye",
               "sugarcane", "sweet_potato", "tobacco", "wheat", "white_potato")
CONTROLS_SUIT_MEAN <- paste0("suit_mean_", CROP_KEYS)

# Higher-order controls (col 6): SDs of the geo-climatic variables plus
# the SDs of the 10 suitability indices. Paper Appendix E.3.
GEOCLIM_SD <- c("sd_elevation_m", "sd_slope_deg", "sd_flow_accum",
                "sd_annual_temp_c", "sd_annual_precip_mm")
CONTROLS_SUIT_SD   <- paste0("suit_sd_", CROP_KEYS)
CONTROLS_HIGHER_SD <- c(GEOCLIM_SD, CONTROLS_SUIT_SD)

# ---- OLS helper --------------------------------------------------------------
# Wraps fixest::feols() with a consistent interface.
# fe_str:      fixest FE specification string, e.g. "state^year" or ""
# cluster_var: string naming the clustering variable
run_ols <- function(data, y, controls = character(0),
                    fe_str = "state^year", cluster_var = "gisjoin") {

  # Drop rows with missing y, shi, or any controls
  needed <- unique(c(y, "shi", controls, cluster_var))
  d <- data |> drop_na(any_of(needed))

  if (nrow(d) == 0) stop("No observations after dropping NAs.")

  # Build RHS: shi + controls
  rhs_vars <- paste(c("shi", controls), collapse = " + ")

  # Build formula
  if (nchar(fe_str) > 0) {
    fml_str <- paste0(y, " ~ ", rhs_vars, " | ", fe_str)
  } else {
    fml_str <- paste0(y, " ~ ", rhs_vars)
  }
  fml <- as.formula(fml_str)

  # Cluster SE
  feols(fml, data = d, cluster = as.formula(paste0("~", cluster_var)),
        warn = FALSE, notes = FALSE)
}

# ---- Word table export helper ------------------------------------------------
# Takes a named list of fixest models and exports a formatted .docx table.
export_word_table <- function(models, path, title = "", notes = "") {
  ms <- modelsummary(
    models,
    output      = "flextable",
    stars       = c("*" = 0.10, "**" = 0.05, "***" = 0.01),
    coef_map    = c("shi" = "Soil Heterogeneity Index"),
    gof_map     = list(
      list(raw = "nobs",      clean = "Observations",  fmt = 0),
      list(raw = "r.squared", clean = "R\u00b2",       fmt = 3)
    ),
    title = title,
    notes = notes
  )
  # Style: zebra rows, bold header
  ms <- ms |>
    bold(part = "header") |>
    bg(i = seq(2, nrow(ms$body$dataset), 2), bg = "#F2F2F2", part = "body") |>
    fontsize(size = 10, part = "all") |>
    font(fontname = "Times New Roman", part = "all") |>
    autofit()

  doc <- read_docx() |>
    body_add_flextable(ms)
  print(doc, target = path)
  message("  Exported: ", path)
}

# Restore fixest::pvalue which is masked by scales::pvalue
pvalue <- fixest::pvalue

message("00_setup.R loaded. Paths, packages, and helpers ready.")
