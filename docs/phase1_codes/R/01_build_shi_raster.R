# =============================================================================
# 06_build_shi_raster.R
# Construct the Soil Heterogeneity Index (SHI) following Raz (2025) Appendix E.1.
#
# Author's algorithm:
#   1. Rasterize STATSGO2 polygons to a 500 m grid (each cell = soil map unit)
#   2. For each cell i with code k:
#         SHI_cell = 1 - (# neighbors in 51x51 window with code k) /
#                        (# valid neighbors in 51x51 window)
#      Window = 25 cells in each cardinal direction (12.5 km radius).
#   3. Aggregate cell-level SHI to the county level by taking the mean.
#
# v1's SHI used a within-county area-share HHI complement (1 - sum s_j^2),
# which measures a global composition statistic, not local spatial
# dissimilarity. This script replaces v1's SHI with the correct raster-
# dissimilarity index.
#
# Output: Refined results/data/SoilHeterogeneityIndex_rasterDissimilarity_v2.csv
#
# Runtime: ~15-30 minutes depending on hardware (one-time computation).
# =============================================================================

suppressPackageStartupMessages({
  library(sf)
  library(terra)
  library(dplyr)
  library(tigris)
})

options(tigris_use_cache = TRUE)

PROJ_ROOT <- "/Users/ruihuaguo/Presentation_claude/Replication_project"
SHP_PATH  <- file.path(PROJ_ROOT, "raw data/statsgo2/wss_gsmsoil_US_2016/spatial/gsmsoilmu_a_us.shp")
OUT_DIR   <- file.path(PROJ_ROOT, "Refined results/data")
OUT_CSV   <- file.path(OUT_DIR, "SoilHeterogeneityIndex_rasterDissimilarity_v2.csv")
OUT_TIF   <- file.path(OUT_DIR, "shi_cell_500m.tif")

dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

log_step <- function(...) {
  cat(format(Sys.time(), "[%H:%M:%S]"), ..., "\n", sep = " ")
}

# -----------------------------------------------------------------------------
# Step A. Load STATSGO2 and clip to CONUS
# -----------------------------------------------------------------------------
log_step("A. Loading STATSGO2 shapefile ...")
soil <- st_read(SHP_PATH, quiet = TRUE)
log_step("   polygons loaded:", nrow(soil), "| unique MUKEY:", length(unique(soil$MUKEY)))

log_step("A. Clipping to CONUS bounding box (WGS84) ...")
conus_bbox <- st_bbox(c(xmin = -125, xmax = -66, ymin = 24, ymax = 50),
                      crs = st_crs(soil))
sf_use_s2(FALSE)
soil_conus <- st_crop(soil, conus_bbox)
sf_use_s2(TRUE)
log_step("   polygons after CONUS crop:", nrow(soil_conus))

log_step("A. Reprojecting to EPSG:5070 (NAD83 Albers) ...")
soil_prj <- st_transform(soil_conus, 5070)

log_step("A. Encoding MUKEY as integer factor ...")
soil_prj$mukey_int <- as.integer(factor(soil_prj$MUKEY))
n_types <- length(unique(soil_prj$mukey_int))
log_step("   integer codes assigned. N types in CONUS:", n_types)

# -----------------------------------------------------------------------------
# Step B. Build 500 m CONUS template raster
# -----------------------------------------------------------------------------
log_step("B. Building 500 m template raster for CONUS ...")
template <- terra::rast(
  xmin = -2400000, xmax =  2300000,
  ymin =   270000, ymax =  3170000,
  resolution = 500,
  crs = "EPSG:5070"
)
log_step("   template dims (rows x cols):", nrow(template), "x", ncol(template),
         " total cells:", formatC(ncell(template), big.mark = ",", format = "d"))

# -----------------------------------------------------------------------------
# Step C. Rasterize soil polygons
# -----------------------------------------------------------------------------
log_step("C. Rasterizing STATSGO2 polygons to 500 m grid ...")
soil_vect <- terra::vect(soil_prj)
soil_rast <- terra::rasterize(soil_vect, template,
                              field = "mukey_int",
                              background = NA,
                              touches = FALSE)
log_step("   rasterization complete.")

# Free the vector to reclaim memory
rm(soil, soil_conus, soil_prj, soil_vect); gc(verbose = FALSE)

# -----------------------------------------------------------------------------
# Step D. Shift-based focal computation (51x51 window)
# -----------------------------------------------------------------------------
log_step("D. Extracting raster matrix ...")
soil_mat <- as.matrix(soil_rast, wide = TRUE)
M <- nrow(soil_mat); N <- ncol(soil_mat)
log_step("   matrix:", M, "x", N,
         " valid cells:", formatC(sum(!is.na(soil_mat)), big.mark = ",", format = "d"))

half_w <- 25L   # 25 cells each direction -> 51x51 window
n_shifts_total <- (2 * half_w + 1)^2 - 1
log_step("D. Running shift loop. Window = 51x51 (", n_shifts_total, " non-center shifts).")

valid_mat   <- !is.na(soil_mat)
same_count  <- matrix(0L, M, N)
total_count <- matrix(0L, M, N)

t0 <- Sys.time()
shift_idx <- 0L

for (di in -half_w:half_w) {
  for (dj in -half_w:half_w) {
    if (di == 0L && dj == 0L) next
    shift_idx <- shift_idx + 1L

    sr_lo <- max(1L, 1L - di); sr_hi <- min(M, M - di)
    sc_lo <- max(1L, 1L - dj); sc_hi <- min(N, N - dj)
    dr_lo <- sr_lo + di;       dr_hi <- sr_hi + di
    dc_lo <- sc_lo + dj;       dc_hi <- sc_hi + dj

    src <- soil_mat[sr_lo:sr_hi, sc_lo:sc_hi]
    dst <- soil_mat[dr_lo:dr_hi, dc_lo:dc_hi]
    bv  <- valid_mat[sr_lo:sr_hi, sc_lo:sc_hi] &
           valid_mat[dr_lo:dr_hi, dc_lo:dc_hi]

    same <- bv & (src == dst)
    same[is.na(same)] <- FALSE

    # Logical matrices add cleanly into integer matrices (TRUE=1, FALSE=0)
    same_count[sr_lo:sr_hi, sc_lo:sc_hi]  <- same_count[sr_lo:sr_hi, sc_lo:sc_hi]  + same
    total_count[sr_lo:sr_hi, sc_lo:sc_hi] <- total_count[sr_lo:sr_hi, sc_lo:sc_hi] + bv

    rm(src, dst, bv, same)

    if (shift_idx %% 200L == 0L) {
      elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
      remaining <- elapsed / shift_idx * (n_shifts_total - shift_idx)
      log_step(sprintf("   shift %4d / %4d  elapsed %6.1fs  eta %6.1fs",
                       shift_idx, n_shifts_total, elapsed, remaining))
      gc(verbose = FALSE)
    }
  }
}

log_step("D. Focal loop done. Computing SHI at cell level ...")
shi_mat <- ifelse(total_count > 0L,
                  1 - same_count / total_count,
                  NA_real_)
# Preserve NA where the center cell itself is invalid
shi_mat[!valid_mat] <- NA_real_

rm(same_count, total_count, valid_mat, soil_mat); gc(verbose = FALSE)

# Repack into a terra raster
shi_rast <- terra::rast(template)
terra::values(shi_rast) <- as.vector(t(shi_mat))
names(shi_rast) <- "shi_raster"

log_step("D. Writing cell-level SHI raster to disk ...")
terra::writeRaster(shi_rast, OUT_TIF, overwrite = TRUE,
                   datatype = "FLT4S", gdal = c("COMPRESS=LZW"))

cell_mean <- mean(terra::values(shi_rast), na.rm = TRUE)
cell_sd   <- sd(terra::values(shi_rast),   na.rm = TRUE)
log_step(sprintf("   cell-level SHI:  mean = %.4f  sd = %.4f", cell_mean, cell_sd))

rm(shi_mat); gc(verbose = FALSE)

# -----------------------------------------------------------------------------
# Step E. Aggregate cell SHI to county level
# -----------------------------------------------------------------------------
log_step("E. Downloading 2000 county boundaries via tigris ...")
# Use 2000 NHGIS boundaries to match the gisjoin codes in CountyLevelData.csv,
# which uses NHGIS harmonized geographies keyed to 2000 census definitions.
non_conus <- c("02","15","60","66","69","72","78")  # AK, HI, territories
counties_sf <- tigris::counties(cb = TRUE, resolution = "5m",
                                year = 2000, progress_bar = FALSE) |>
  dplyr::filter(!STATEFP %in% non_conus) |>
  sf::st_transform(5070)

log_step("   counties:", nrow(counties_sf))

log_step("E. Extracting mean SHI per county ...")
counties_vect <- terra::vect(counties_sf)
ext <- terra::extract(shi_rast, counties_vect,
                      fun = mean, na.rm = TRUE,
                      touches = TRUE, ID = TRUE)
cnt <- terra::extract(shi_rast, counties_vect,
                      fun = function(x) sum(!is.na(x)),
                      touches = TRUE, ID = TRUE)

counties_sf$shi_raster <- ext[, 2]
counties_sf$n_cells    <- cnt[, 2]

log_step("E. Building output table ...")
out <- counties_sf |>
  sf::st_drop_geometry() |>
  dplyr::mutate(
    gisjoin = paste0("G", STATEFP, "0", COUNTYFP, "0"),
    geoid   = paste0(STATEFP, COUNTYFP)
  ) |>
  dplyr::select(gisjoin, geoid, STATEFP, COUNTYFP,
                shi_raster, n_cells)

log_step("   counties with non-NA SHI:", sum(!is.na(out$shi_raster)),
         "/", nrow(out))
log_step(sprintf("   county-level SHI:  mean = %.4f  sd = %.4f",
                 mean(out$shi_raster, na.rm = TRUE),
                 sd(out$shi_raster,   na.rm = TRUE)))

write.csv(out, OUT_CSV, row.names = FALSE)
log_step("   wrote:", OUT_CSV)

log_step("DONE.")
