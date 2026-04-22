# =============================================================================
# 07_build_geoclim_sd.R
# County-level standard deviations of geo-climatic variables (paper's "higher-
# order controls" for Table 1 column 6).
#
# Paper (Appendix E.3): Higher-order controls include the standard deviations
# of temperature, precipitation, slope, elevation, flow accumulation, and the
# agricultural suitability indexes.
#
# This script produces SDs for the five geo-climatic variables. Suitability
# SDs are handled in 08_build_agri_suitability.R.
#
# Inputs:
#   raw data/hydrosheds/hyd_na_dem_30s.tif     (elevation, 30 arc-sec)
#   raw data/hydrosheds/hyd_na_acc_30s.tif     (flow accumulation, 30 arc-sec)
#   raw data/worldclim/wc2.1_5m_tavg/*.tif     (12 monthly mean temps)
#   raw data/worldclim/wc2.1_5m_prec/*.tif     (12 monthly total precips)
#
# Output:
#   data/GeoClim_SD_county.csv  (gisjoin, sd_elevation_m, sd_slope_deg,
#                                sd_flow_accum, sd_annual_temp_c,
#                                sd_annual_precip_mm)
#
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
RAW       <- file.path(PROJ_ROOT, "raw data")
OUT_CSV   <- file.path(PROJ_ROOT, "Refined results", "data",
                       "GeoClim_SD_county.csv")

log_step <- function(...) cat(format(Sys.time(), "[%H:%M:%S]"), ..., "\n", sep=" ")

# ---- 1. Load 2000 NHGIS county boundaries ----------------------------------
log_step("1. Downloading 2000 county boundaries ...")
non_conus <- c("02","15","60","66","69","72","78")  # AK, HI, territories
counties_sf <- tigris::counties(cb = TRUE, resolution = "5m",
                                year = 2000, progress_bar = FALSE) |>
  dplyr::filter(!STATEFP %in% non_conus) |>
  dplyr::mutate(gisjoin = paste0("G", STATEFP, "0", COUNTYFP, "0")) |>
  sf::st_transform(4326)
counties_vect <- terra::vect(counties_sf)
log_step("   counties:", nrow(counties_sf))

# CONUS bounding box for cropping WorldClim (which is global)
conus_ext <- terra::ext(-125, -66, 24, 50)

# ---- 2. HydroSHEDS: DEM and derivatives ------------------------------------
log_step("2. Loading HydroSHEDS DEM ...")
dem <- terra::rast(file.path(RAW, "hydrosheds/hyd_na_dem_30s/hyd_na_dem_30s.tif"))
dem <- terra::crop(dem, conus_ext)

log_step("2a. Extracting SD of elevation per county ...")
sd_elev <- terra::extract(dem, counties_vect,
                          fun = function(x) stats::sd(x, na.rm = TRUE),
                          touches = TRUE, ID = TRUE)

log_step("2b. Deriving slope (degrees) from DEM ...")
slope <- terra::terrain(dem, v = "slope", unit = "degrees")
log_step("2c. Extracting SD of slope per county ...")
sd_slope <- terra::extract(slope, counties_vect,
                           fun = function(x) stats::sd(x, na.rm = TRUE),
                           touches = TRUE, ID = TRUE)

log_step("2d. Loading flow accumulation ...")
acc <- terra::rast(file.path(RAW, "hydrosheds/hyd_na_acc_30s/hyd_na_acc_30s.tif"))
acc <- terra::crop(acc, conus_ext)
log_step("2e. Extracting SD of flow accumulation per county ...")
sd_acc <- terra::extract(acc, counties_vect,
                         fun = function(x) stats::sd(x, na.rm = TRUE),
                         touches = TRUE, ID = TRUE)

# Free memory
rm(dem, slope, acc); gc(verbose = FALSE)

# ---- 3. WorldClim: annual temperature and precipitation -------------------
log_step("3a. Stacking 12 monthly temperature rasters ...")
tavg_files <- sort(list.files(file.path(RAW, "worldclim/wc2.1_5m_tavg"),
                              pattern = "\\.tif$", full.names = TRUE))
stopifnot(length(tavg_files) == 12)
tavg_stack <- terra::rast(tavg_files)
tavg_stack <- terra::crop(tavg_stack, conus_ext)
ann_temp   <- terra::mean(tavg_stack)   # annual mean temp per pixel
log_step("3b. Extracting SD of annual mean temperature per county ...")
sd_temp <- terra::extract(ann_temp, counties_vect,
                          fun = function(x) stats::sd(x, na.rm = TRUE),
                          touches = TRUE, ID = TRUE)

log_step("3c. Stacking 12 monthly precipitation rasters ...")
prec_files <- sort(list.files(file.path(RAW, "worldclim/wc2.1_5m_prec"),
                              pattern = "\\.tif$", full.names = TRUE))
stopifnot(length(prec_files) == 12)
prec_stack <- terra::rast(prec_files)
prec_stack <- terra::crop(prec_stack, conus_ext)
ann_prec   <- sum(prec_stack)           # annual total precip per pixel
log_step("3d. Extracting SD of annual total precipitation per county ...")
sd_prec <- terra::extract(ann_prec, counties_vect,
                          fun = function(x) stats::sd(x, na.rm = TRUE),
                          touches = TRUE, ID = TRUE)

rm(tavg_stack, prec_stack, ann_temp, ann_prec); gc(verbose = FALSE)

# ---- 4. Build output table -------------------------------------------------
log_step("4. Assembling output CSV ...")
out <- data.frame(
  gisjoin            = counties_sf$gisjoin,
  sd_elevation_m     = sd_elev[, 2],
  sd_slope_deg       = sd_slope[, 2],
  sd_flow_accum      = sd_acc[, 2],
  sd_annual_temp_c   = sd_temp[, 2],
  sd_annual_precip_mm = sd_prec[, 2]
)

log_step("   rows:", nrow(out),
         "| non-NA elevation SD:", sum(!is.na(out$sd_elevation_m)),
         "| non-NA temp SD:", sum(!is.na(out$sd_annual_temp_c)))

write.csv(out, OUT_CSV, row.names = FALSE)
log_step("   wrote:", OUT_CSV)
log_step("DONE.")
