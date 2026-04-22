# =============================================================================
# 01_data_description.R
# Replication of Raz (2025)
#
# Purpose: Produce summary statistics table and document sample attrition
#          at each stage of the analysis.
# Output:  output/tables/table_summary_stats.docx
# =============================================================================

source("/Users/ruihuaguo/Presentation_claude/Replication_project/Refined results/R/00_setup.R", local = FALSE)

panel <- load_panel()

# ---- 1. Sample attrition log ------------------------------------------------
cat("\n===== Sample Attrition Log =====\n")
cat(sprintf("Total county-year rows in master panel:    %d\n", nrow(panel)))

# Counties (time-invariant unit)
cat(sprintf("Unique counties:                            %d\n",
            n_distinct(panel$gisjoin)))
cat(sprintf("Census years covered:                       %s\n",
            paste(sort(unique(panel$year)), collapse = ", ")))

n_lni <- panel |> filter(!is.na(lni)) |> nrow()
cat(sprintf("Rows with non-missing LNI:                  %d (%.1f%%)\n",
            n_lni, 100 * n_lni / nrow(panel)))

n_fert <- panel |> filter(!is.na(share_farms_reporting_fert)) |> nrow()
cat(sprintf("Rows with non-missing fertilizer share:     %d (%.1f%%)\n",
            n_fert, 100 * n_fert / nrow(panel)))

n_wheat <- panel |> filter(!is.na(wheat_share_of_farmland)) |> nrow()
cat(sprintf("Rows with non-missing wheat share:          %d (%.1f%%)\n",
            n_wheat, 100 * n_wheat / nrow(panel)))

n_rhi <- panel |> filter(!is.na(religious_diversity_index)) |> nrow()
cat(sprintf("Rows with non-missing RHI:                  %d (%.1f%%)\n",
            n_rhi, 100 * n_rhi / nrow(panel)))

n_ag <- panel |> filter(!is.na(ag_diversity_index)) |> nrow()
cat(sprintf("Rows with non-missing ag diversity index:   %d (%.1f%%)\n",
            n_ag, 100 * n_ag / nrow(panel)))

# Full preferred specification (LNI + all controls)
n_preferred <- panel |>
  drop_na(lni, shi, all_of(CONTROLS_FULL)) |>
  nrow()
cat(sprintf("Rows in preferred LNI specification:        %d (%.1f%%)\n",
            n_preferred, 100 * n_preferred / nrow(panel)))
cat("=================================\n\n")

# ---- 2. Summary statistics ---------------------------------------------------
# Variables to summarize, with clean labels
vars <- tribble(
  ~var,                        ~label,
  "shi",                       "Soil Heterogeneity Index (SHI)",
  "lni",                       "Local Name Index (LNI)",
  "religious_diversity_index", "Religious Homogeneity Index (RHI)",
  "ag_diversity_index",        "Agricultural Diversity Index",
  "share_farms_reporting_fert","Share Farms Reporting Fertilizer",
  "wheat_share_of_farmland",   "Wheat Share of Farmland",
  "slave_share",               "Slave Share (1850)",
  "farm_size_gini",            "Farm Size Gini",
  "birth_place_diversity",     "Birthplace Diversity Index",
  "mean_elevation_m",          "Mean Elevation (m)",
  "mean_annual_temp_c",        "Mean Annual Temperature (C)",
  "mean_annual_precip_mm",     "Mean Annual Precipitation (mm)"
)

compute_stats <- function(x) {
  x <- x[!is.na(x)]
  tibble(
    N      = length(x),
    Mean   = mean(x),
    SD     = sd(x),
    Min    = min(x),
    P25    = quantile(x, 0.25),
    Median = median(x),
    P75    = quantile(x, 0.75),
    Max    = max(x)
  )
}

stats_df <- vars |>
  rowwise() |>
  mutate(stats = list(compute_stats(panel[[var]]))) |>
  unnest(stats) |>
  select(-var)

# Round numeric columns
stats_df <- stats_df |>
  mutate(across(where(is.numeric), ~ round(.x, 3)))

cat("Summary statistics computed.\n")
print(stats_df, n = Inf)

# ---- 3. Export to Word -------------------------------------------------------
ft <- flextable(stats_df) |>
  set_header_labels(
    label  = "Variable",
    N      = "N",
    Mean   = "Mean",
    SD     = "Std. Dev.",
    Min    = "Min",
    P25    = "25th Pct.",
    Median = "Median",
    P75    = "75th Pct.",
    Max    = "Max"
  ) |>
  bold(part = "header") |>
  bg(i = seq(2, nrow(stats_df), 2), bg = "#F2F2F2", part = "body") |>
  fontsize(size = 10, part = "all") |>
  font(fontname = "Times New Roman", part = "all") |>
  add_header_lines("Table 0: Summary Statistics — County-Level Panel") |>
  add_footer_lines(paste(
    "Notes: County-year panel covering 1850-1940 from Raz (2025) replication data.",
    "SHI is time-invariant; all other variables may vary across census decades.",
    "LNI constructed from IPUMS 1% census samples (attenuated relative to paper's full-count measure).",
    "RHI is the Herfindahl-Hirschman Index of religious denominations (higher = more concentrated).",
    "Sources: STATSGO2 (SHI), IPUMS USA 1% sample (LNI), NHGIS Census of Agriculture",
    "(fertilizer, wheat, farm Gini), NHGIS Religious Bodies Census (RHI),",
    "HydroSHEDS/WorldClim (geo-climatic controls)."
  )) |>
  fontsize(size = 9, part = "footer") |>
  autofit()

out_path <- file.path(OUT_TABS, "table_summary_stats.docx")
doc <- read_docx() |> body_add_flextable(ft)
print(doc, target = out_path)
message("Saved: ", out_path)
