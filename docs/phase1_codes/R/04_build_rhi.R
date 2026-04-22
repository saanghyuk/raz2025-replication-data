# =============================================================================
# 09_build_rhi.R
# Build the Religious Homogeneity Index (RHI) from raw NHGIS Census of
# Religious Bodies tables.
#
# Paper: Raz (2025), Appendix E.2.
#   RHI_{c,t} = sum_j  s_{c,j,t}^2
# where s_{c,j,t} is denomination j's share of members (1890+) or churches
# (1850/60/70 proxy) in county c in year t.
#
# Why this script exists
# ----------------------
# v1 ships a pre-derived `ReligiousDiversityData.csv` containing 1 - HHI, and
# does NOT include a build script. The master panel then silently drops three
# available waves (1906/1916/1926) at merge time, and omits the 1936 wave the
# paper uses (NHGIS ds 1936_cRelig was never downloaded). This script:
#
#   1. Rebuilds the index from raw NHGIS denomination counts (source of truth)
#   2. Restores waves 1906/1916/1926 that v1's panel merge lost
#   3. Leaves a single hook (WAVE_SPECS) for the 1936 wave — add one row when
#      the NHGIS 1936_cRelig extract is available and re-run the script.
#
# Output: Refined results/data/RHI_county_year.csv
#   gisjoin, year, rhi, rhi_z, source, n_denoms, total_members
#
# TODO(1936): when the 1936 Census of Religious Bodies extract is downloaded,
# add the corresponding entry to WAVE_SPECS below (search for "MARK-1936").
# Nothing else in this script needs to change — rerun with Rscript.
# =============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
})

PROJ_ROOT <- "/Users/ruihuaguo/Presentation_claude/Replication_project"
NHGIS_DIR <- file.path(PROJ_ROOT, "raw data", "nhgis", "nhgis0003_csv")
OUT_CSV   <- file.path(PROJ_ROOT, "Refined results", "data",
                       "RHI_county_year.csv")

# ---- Wave specifications -----------------------------------------------------
# For each census wave, the paper uses either member counts (1890+) or church
# counts (1850/60/70, pre-membership proxy). The column prefix locates the
# denomination columns in each file; `exclude` drops pre-aggregated totals.
#
# MARK-1936 (append here when the NHGIS 1936 extract arrives):
#   list(
#     year = 1936,
#     file = "nhgis00NN_csv/nhgis00NN_dsXX_1936_county.csv",   # update
#     prefix = "YYY",                                          # update
#     type = "members",
#     exclude = character(0)
#   )
WAVE_SPECS <- list(
  list(year = 1850, file = "nhgis0003_ds10_1850_county.csv",
       prefix = "AET", type = "churches_proxy", exclude = character(0)),
  list(year = 1860, file = "nhgis0003_ds14_1860_county.csv",
       prefix = "AHL", type = "churches_proxy", exclude = character(0)),
  list(year = 1870, file = "nhgis0003_ds17_1870_county.csv",
       prefix = "AK5", type = "churches_proxy", exclude = character(0)),
  list(year = 1890, file = "nhgis0003_ds28_1890_county.csv",
       prefix = "AWD", type = "members",        exclude = character(0)),
  list(year = 1906, file = "nhgis0003_ds33_1906_county.csv",
       prefix = "AZ9", type = "members",        exclude = c("AZ9079")),   # "Total Protestant Churches" — rollup
  list(year = 1916, file = "nhgis0003_ds41_1916_county.csv",
       prefix = "A7G", type = "members",        exclude = character(0)),
  list(year = 1926, file = "nhgis0003_ds51_1926_county.csv",
       prefix = "BCV", type = "members",        exclude = character(0)),
  list(year = 1936, file = "nhgis0003_ds74_1936_county.csv",   # MARK-1936 resolved
       prefix = "BTV", type = "members",        exclude = character(0))
)

# ---- Helper: compute HHI for one wave ----------------------------------------
build_one_wave <- function(spec) {
  path <- file.path(NHGIS_DIR, spec$file)
  stopifnot(file.exists(path))
  dat <- read_csv(path, show_col_types = FALSE, progress = FALSE)

  denom_cols <- grep(paste0("^", spec$prefix, "[0-9]{3}$"),
                     names(dat), value = TRUE)
  denom_cols <- setdiff(denom_cols, spec$exclude)
  stopifnot(length(denom_cols) > 0)

  m <- as.matrix(dat[, denom_cols])
  m[is.na(m)] <- 0

  total <- rowSums(m)
  # Drop counties with no reported religious activity (HHI undefined).
  keep <- total > 0
  if (!any(keep)) stop("All totals zero for wave ", spec$year)

  shares <- m[keep, , drop = FALSE] / total[keep]
  hhi    <- rowSums(shares^2)

  tibble(
    gisjoin       = dat$GISJOIN[keep],
    year          = spec$year,
    rhi           = hhi,
    source        = spec$type,
    n_denoms      = length(denom_cols),
    total_members = total[keep]
  )
}

# ---- Build all waves and z-score within year ---------------------------------
message("Building RHI from ", length(WAVE_SPECS), " waves...")
waves <- lapply(WAVE_SPECS, function(s) {
  message("  ", s$year, " (", s$type, ", prefix=", s$prefix, ")")
  build_one_wave(s)
})
rhi_all <- bind_rows(waves)

rhi_all <- rhi_all |>
  group_by(year) |>
  mutate(rhi_z = as.numeric(scale(rhi))) |>
  ungroup() |>
  arrange(year, gisjoin)

# ---- Save --------------------------------------------------------------------
dir.create(dirname(OUT_CSV), showWarnings = FALSE, recursive = TRUE)
write_csv(rhi_all, OUT_CSV)

message("\nWritten: ", OUT_CSV)
message("Rows: ",         nrow(rhi_all))
message("Counties: ",     n_distinct(rhi_all$gisjoin))
message("Years: ",        paste(sort(unique(rhi_all$year)), collapse = ", "))

# ---- Summary by year ---------------------------------------------------------
summ <- rhi_all |>
  group_by(year) |>
  summarise(
    n        = n(),
    mean_rhi = mean(rhi),
    sd_rhi   = sd(rhi),
    min_rhi  = min(rhi),
    max_rhi  = max(rhi),
    .groups  = "drop"
  )
cat("\nSummary by year:\n")
print(summ, n = 20)

cat("\n[DONE] 09_build_rhi.R\n")
