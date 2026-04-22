# =============================================================================
# 08_build_agri_suitability.R
# County-level mean and standard deviation of agricultural suitability for
# the 10 crops most important by 1859 output value (paper Table 1 controls).
#
# Paper (p.21, Appendix E.3):
#   Agricultural suitability controls (col 5) = mean suitability for alfalfa,
#   cotton, maize, oat, rye, sugarcane, sweet potato, tobacco, wheat, white
#   potato. Input level: intermediate. Water: rain-fed. Baseline: 1961-1990
#   (GAEZ v3). Source: FAO and IIASA (2012).
#   Higher-order controls (col 6) additionally include the SDs of the 10
#   suitability indices.
#
# Inputs:
#   raw data/Sustainbility index/<crop>/data.asc   (one .asc per crop, 5 arc-min)
#
# Output:
#   data/AgriSuitability_county.csv
#     gisjoin, suit_mean_<crop> (10 cols), suit_sd_<crop> (10 cols)
#
# NODATA value in .asc = -9 (from .asc header).
# Boundaries: 2000 NHGIS via tigris (matches gisjoin keys in CountyLevelData).
# =============================================================================

suppressPackageStartupMessages({
  library(terra)
  library(sf)
  library(dplyr)
  library(tigris)
})

options(tigris_use_cache = TRUE)

PROJ_ROOT <- "/Users/ruihuaguo/Presentation_claude/Replication_project"
SUIT_DIR  <- file.path(PROJ_ROOT, "raw data", "Sustainbility index")
OUT_CSV   <- file.path(PROJ_ROOT, "Refined results", "data",
                       "AgriSuitability_county.csv")

log_step <- function(...) cat(format(Sys.time(), "[%H:%M:%S]"), ..., "\n", sep=" ")

CROPS <- c("alfalfa", "cotton", "maize", "oat", "rye",
           "sugarcane", "sweet potato", "tobacco", "wheat", "white potato")
# Column-safe short labels (for the R data.frame column names)
CROP_KEYS <- c("alfalfa", "cotton", "maize", "oat", "rye",
               "sugarcane", "sweet_potato", "tobacco", "wheat", "white_potato")

# ---- 1. Load 2000 NHGIS county boundaries ----------------------------------
log_step("1. Downloading 2000 county boundaries ...")
non_conus <- c("02","15","60","66","69","72","78")
counties_sf <- tigris::counties(cb = TRUE, resolution = "5m",
                                year = 2000, progress_bar = FALSE) |>
  dplyr::filter(!STATEFP %in% non_conus) |>
  dplyr::mutate(gisjoin = paste0("G", STATEFP, "0", COUNTYFP, "0")) |>
  sf::st_transform(4326)
counties_vect <- terra::vect(counties_sf)
log_step("   counties:", nrow(counties_sf))

# ---- 2. Loop over crops: extract mean + SD --------------------------------
out <- data.frame(gisjoin = counties_sf$gisjoin)

for (i in seq_along(CROPS)) {
  crop_dir <- CROPS[i]
  crop_key <- CROP_KEYS[i]
  asc      <- file.path(SUIT_DIR, crop_dir, "data.asc")
  stopifnot(file.exists(asc))

  log_step(sprintf("2.%02d Loading %s ...", i, crop_dir))
  r <- terra::rast(asc)
  # NODATA in .asc header is -9. Ensure any negative values are treated as NA.
  terra::NAflag(r) <- -9
  # Also mask any sentinel negatives (defensive; GAEZ suitability is 0-100).
  r <- terra::clamp(r, lower = 0, upper = 100, values = FALSE)

  # Assign CRS if missing (the .prj says WGS84)
  if (is.na(terra::crs(r, proj = TRUE)) ||
      nchar(terra::crs(r, proj = TRUE)) == 0) {
    terra::crs(r) <- "EPSG:4326"
  }

  mean_col <- terra::extract(r, counties_vect,
                             fun = function(x) mean(x, na.rm = TRUE),
                             touches = TRUE, ID = TRUE)
  sd_col   <- terra::extract(r, counties_vect,
                             fun = function(x) stats::sd(x, na.rm = TRUE),
                             touches = TRUE, ID = TRUE)

  out[[paste0("suit_mean_", crop_key)]] <- mean_col[, 2]
  out[[paste0("suit_sd_",   crop_key)]] <- sd_col[, 2]
}

log_step("3. Diagnostic counts ...")
for (crop_key in CROP_KEYS) {
  n_mean <- sum(!is.na(out[[paste0("suit_mean_", crop_key)]]))
  log_step(sprintf("   %-14s: non-NA mean = %d", crop_key, n_mean))
}

write.csv(out, OUT_CSV, row.names = FALSE)
log_step("   wrote:", OUT_CSV, " (", nrow(out), "rows,", ncol(out), "cols)")
log_step("DONE.")
