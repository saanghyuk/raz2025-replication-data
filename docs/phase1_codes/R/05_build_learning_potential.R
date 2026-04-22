# =============================================================================
# 10_build_learning_potential.R
# Build Learning Potential (gains5 and WheatDiff) from GAEZ v4 rasters and
# NHGIS 1930 crop acreage data.
#
# Paper: Raz (2025), Section VI.A.
#   Panel A (Fertilizer): gains5 = county mean of 5-crop acreage-weighted
#     standardized yield difference (high input - low input), weighted by
#     1930 crop acreage shares. Binary: high_gains5 = gains5 > median.
#   Panel B (Wheat): WheatDiff = county mean of raw wheat yield difference
#     (high - low, not standardized). Binary: high_wheat = WheatDiff > median.
#
# Crop species (Table5-diff.md):
#   Maize:  Temperate maize, 120 days   -> rasters/maize-high / maize-low
#   Wheat:  Winter wheat, 40+120 days   -> rasters/wheat-high / wheat-low
#   Cotton: Subtrop. cotton, 150 days   -> rasters/cotton-high / cotton-low
#   Oat:    Oat, 105 days               -> rasters/oat-high / oat-low
#   Fodder: Grass, Cool C3              -> rasters/fodder-high / fodder-low
#
# NHGIS 1930 acreage columns (nhgis0002_ds212_1930_county.csv):
#   Maize:  ACA5002  corn harvested for grain
#   Wheat:  ACA5006  wheat threshed, total
#   Cotton: ACBD002  cotton, lint
#   Oat:    ACA5010  oats threshed
#   Grass:  ACA9004 + ACA9005 + ACA9006  alfalfa + tame grasses + wild grasses
#
# Output: data/LearningPotential_county.csv
#   gisjoin, gains5, high_gains5, WheatDiff, high_wheat
# =============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(terra)
  library(sf)
  library(tigris)
})
options(tigris_use_cache = TRUE)

PROJ_ROOT  <- "/Users/ruihuaguo/Presentation_claude/Replication_project"
RASTER_DIR <- file.path(PROJ_ROOT, "raw data", "table5",
                        "agro-climate potential yield rasters")
NHGIS_CSV  <- file.path(PROJ_ROOT, "raw data", "table5",
                        "nhgis0002_csv", "nhgis0002_ds212_1930_county.csv")
OUT_CSV    <- file.path(PROJ_ROOT, "Refined results", "data",
                        "LearningPotential_county.csv")

# ---- County boundaries: 2000 NHGIS, CONUS, geographic CRS to match rasters -
message("Loading 2000 CONUS county boundaries...")
county_sf <- tigris::counties(cb = TRUE, resolution = "5m", year = 2000,
                               progress_bar = FALSE) |>
  dplyr::filter(!STATEFP %in% c("02","15","60","66","69","72","78")) |>
  sf::st_transform(4326)

county_sf <- county_sf |>
  dplyr::mutate(gisjoin = paste0("G", STATEFP, "0", COUNTYFP, "0"))

county_vect <- terra::vect(county_sf)
message(sprintf("  %d CONUS counties.", nrow(county_sf)))

# ---- Crop specifications -----------------------------------------------------
CROPS <- list(
  list(name = "maize",  hi = "maize-high/data.asc",  lo = "maize-low/data.asc"),
  list(name = "wheat",  hi = "wheat-high/data.asc",  lo = "wheat-low/data.asc"),
  list(name = "cotton", hi = "cotton-high/data.asc", lo = "cotton-low/data.asc"),
  list(name = "oat",    hi = "oat-high/data.asc",    lo = "oat-low/data.asc"),
  list(name = "fodder", hi = "fodder-high/data.asc", lo = "fodder-low/data.asc")
)

# ---- Helper: compute diff raster from one crop pair -------------------------
make_diff_rast <- function(spec, rdir, standardize = TRUE) {
  ph <- terra::rast(file.path(rdir, spec$hi))
  pl <- terra::rast(file.path(rdir, spec$lo))
  d  <- ph - pl
  # terra reads NODATA_value = -9 from ASC header → NA; propagated by arithmetic.
  # Values exactly equal to 0 are valid (no potential gain).
  if (standardize) {
    mu <- terra::global(d, "mean", na.rm = TRUE)[[1]]
    sg <- terra::global(d, "sd",   na.rm = TRUE)[[1]]
    d  <- (d - mu) / sg
  }
  d
}

# ---- Build standardized diff rasters (for gains5) ---------------------------
message("Building standardized yield-diff rasters for 5 crops...")
std_rasts <- vector("list", length(CROPS))
names(std_rasts) <- sapply(CROPS, `[[`, "name")
for (sp in CROPS) {
  message("  ", sp$name, " ...")
  std_rasts[[sp$name]] <- make_diff_rast(sp, RASTER_DIR, standardize = TRUE)
}

# ---- Build raw wheat diff raster (for WheatDiff, Panel B) -------------------
message("Building raw wheat diff raster (Panel B)...")
wheat_raw_rast <- make_diff_rast(CROPS[[2]], RASTER_DIR, standardize = FALSE)

# ---- Extract county means from each raster -----------------------------------
message("Extracting county-level means (this takes a few minutes)...")
county_means <- tibble(gisjoin = county_sf$gisjoin)

for (nm in names(std_rasts)) {
  message("  extracting std_diff_", nm, " ...")
  ex <- terra::extract(std_rasts[[nm]], county_vect,
                       fun = mean, na.rm = TRUE, touches = TRUE)
  county_means[[paste0("std_diff_", nm)]] <- ex[, 2]
}

message("  extracting wheat_raw_diff ...")
ex_wheat <- terra::extract(wheat_raw_rast, county_vect,
                           fun = mean, na.rm = TRUE, touches = TRUE)
county_means[["wheat_raw_diff"]] <- ex_wheat[, 2]

# ---- Load NHGIS 1930 crop acreage -------------------------------------------
message("Loading NHGIS 1930 crop acreage...")
nhgis <- read_csv(NHGIS_CSV, show_col_types = FALSE) |>
  dplyr::select(
    gisjoin   = GISJOIN,
    ac_maize  = ACA5002,
    ac_wheat  = ACA5006,
    ac_cotton = ACBD002,
    ac_oat    = ACA5010,
    ac_alf    = ACA9004,
    ac_tame   = ACA9005,
    ac_wild   = ACA9006
  ) |>
  dplyr::mutate(
    # Fodder proxy: alfalfa + tame grasses + wild grasses
    ac_fodder = coalesce(ac_alf, 0L) + coalesce(ac_tame, 0L) +
                coalesce(ac_wild, 0L),
    across(c(ac_maize, ac_wheat, ac_cotton, ac_oat), ~ coalesce(., 0L))
  )

message(sprintf("  %d counties in NHGIS 1930.", nrow(nhgis)))

# ---- Merge raster means + acreage, compute gains5 ---------------------------
message("Computing gains5 and high_gains5...")
dat <- county_means |>
  dplyr::left_join(nhgis, by = "gisjoin") |>
  dplyr::mutate(
    ac_total5 = ac_maize + ac_wheat + ac_cotton + ac_oat + ac_fodder,
    # Shares — set to NA if county has no acreage data
    w_maize  = if_else(ac_total5 > 0, ac_maize  / ac_total5, NA_real_),
    w_wheat  = if_else(ac_total5 > 0, ac_wheat  / ac_total5, NA_real_),
    w_cotton = if_else(ac_total5 > 0, ac_cotton / ac_total5, NA_real_),
    w_oat    = if_else(ac_total5 > 0, ac_oat    / ac_total5, NA_real_),
    w_fodder = if_else(ac_total5 > 0, ac_fodder / ac_total5, NA_real_),
    # gains5: acreage-weighted mean of standardized diffs
    gains5 = w_maize  * std_diff_maize  +
             w_wheat  * std_diff_wheat  +
             w_cotton * std_diff_cotton +
             w_oat    * std_diff_oat    +
             w_fodder * std_diff_fodder,
    # Binary: above median (computed over counties with non-NA gains5)
    high_gains5 = as.integer(gains5 > median(gains5, na.rm = TRUE)),
    # Wheat-only measure for Panel B
    WheatDiff  = wheat_raw_diff,
    high_wheat = as.integer(WheatDiff > median(WheatDiff, na.rm = TRUE))
  )

# ---- Save -------------------------------------------------------------------
out <- dat |>
  dplyr::select(gisjoin, gains5, high_gains5, WheatDiff, high_wheat)

dir.create(dirname(OUT_CSV), showWarnings = FALSE, recursive = TRUE)
write_csv(out, OUT_CSV)

message("\nWritten: ", OUT_CSV)
message("Total rows:          ", nrow(out))
message("Non-NA gains5:       ", sum(!is.na(out$gains5)))
message("high_gains5 = 1:     ", sum(out$high_gains5, na.rm = TRUE))
message("Non-NA WheatDiff:    ", sum(!is.na(out$WheatDiff)))
message("high_wheat = 1:      ", sum(out$high_wheat,  na.rm = TRUE))

cat("\nGains5 summary:\n"); print(summary(out$gains5))
cat("\nWheatDiff summary:\n"); print(summary(out$WheatDiff))
cat("\n[DONE] 10_build_learning_potential.R\n")
