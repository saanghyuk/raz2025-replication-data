# =============================================================================
# 02_figure1_shi_map.R
# Replication of Raz (2025), Figure 1
#
# Purpose: Produce a county-level choropleth of state-FE residualized SHI
#          whose visual matches the published Figure 1:
#            - 10-bin quantile classification (sequential, not diverging)
#            - warm sequential palette (pale yellow -> dark brown)
#            - visible light-grey county borders
#            - thick black state borders overlaid on top
#            - north compass and scale bar
#            - CONUS extent (drop AK, HI, PR, and other territories)
#
# Data source: SoilHeterogeneityIndex_rasterDissimilarity_v2.csv
#   (county means of cell-level raster dissimilarity SHI, 500 m grid, 51x51
#    window — matches Raz 2025 Appendix E.1, not v1's area-share HHI).
#   County boundaries: 2000 NHGIS (matches gisjoin keys in CountyLevelData.csv).
#
# Output: output/figures/figure1_shi_map.png  (27 x 20 cm, 200 dpi)
# =============================================================================

source("/Users/ruihuaguo/Presentation_claude/Replication_project/Refined results/R/00_setup.R", local = FALSE)

# ---- 1. Load panel (for state codes) + raster-dissimilarity SHI -------------
# The shi column in CountyLevelData.csv is v1's area-share HHI complement,
# which does not match the paper's methodology. We use the raster-based SHI
# built by R/01_build_shi_raster.R instead.
panel <- load_panel()

state_lookup <- panel |>
  group_by(gisjoin) |>
  summarise(state = first(na.omit(state)), .groups = "drop")

shi_raster_csv <- file.path(
  "/Users/ruihuaguo/Presentation_claude/Replication_project/Refined results/data",
  "SoilHeterogeneityIndex_rasterDissimilarity_v2.csv"
)
stopifnot(file.exists(shi_raster_csv))
shi_df <- read.csv(shi_raster_csv, stringsAsFactors = FALSE)

shi_county <- shi_df |>
  dplyr::select(gisjoin, shi = shi_raster, state = STATEFP) |>
  dplyr::filter(!is.na(shi), !is.na(state))

cat(sprintf("Counties with raster-SHI data: %d\n", nrow(shi_county)))

# ---- 2. Residualize SHI on state fixed effects ------------------------------
# Paper caption: "State fixed effects are partialed out to remove variation
# stemming from differences in data quality across states."
mod_state <- lm(shi ~ factor(state), data = shi_county)
shi_county <- shi_county |> mutate(shi_resid = residuals(mod_state))

cat(sprintf("SHI residual: mean = %.4f, SD = %.4f, range = [%.4f, %.4f]\n",
            mean(shi_county$shi_resid), sd(shi_county$shi_resid),
            min(shi_county$shi_resid), max(shi_county$shi_resid)))

# ---- 3. Download county and state shapefiles --------------------------------
# Use 2000 NHGIS boundaries to match the gisjoin codes in CountyLevelData.csv.
options(tigris_use_cache = TRUE)
message("Downloading US county + state shapefiles via tigris ...")

non_conus <- c("02", "15", "60", "66", "69", "72", "78")   # AK, HI, territories

counties_sf <- tigris::counties(cb = TRUE, resolution = "5m", year = 2000,
                                progress_bar = FALSE) |>
  filter(!STATEFP %in% non_conus) |>
  mutate(GEOID = paste0(STATEFP, COUNTYFP)) |>
  st_transform(crs = 5070)

states_sf <- tigris::states(cb = TRUE, resolution = "5m", year = 2000,
                            progress_bar = FALSE) |>
  filter(!STATE %in% non_conus) |>
  st_transform(crs = 5070)

# ---- 4. Merge SHI residuals ------------------------------------------------
# gisjoin format: G + state_fips(2) + "0" + county_fips(3) + "0"
shi_county <- shi_county |>
  mutate(
    state_fips  = substr(gisjoin, 2, 3),
    county_fips = substr(gisjoin, 5, 7),
    GEOID       = paste0(state_fips, county_fips)
  )

map_data <- counties_sf |>
  left_join(shi_county |> select(GEOID, shi, shi_resid), by = "GEOID")

n_matched <- sum(!is.na(map_data$shi_resid))
cat(sprintf("Counties matched to shapefile: %d / %d\n",
            n_matched, nrow(map_data)))

# ---- 5. Quantile bins (10) on residualized SHI ------------------------------
# Paper uses quantile classification with 10 bins; we replicate the discretization.
n_bins  <- 10
valid   <- !is.na(map_data$shi_resid)
breaks  <- classInt::classIntervals(map_data$shi_resid[valid],
                                    n = n_bins,
                                    style = "quantile")$brks
# Ensure strictly increasing breaks (safety for ties at 0)
breaks  <- unique(breaks)
if (length(breaks) < n_bins + 1) {
  # Fallback: widen range slightly to avoid cut() collapsing bins.
  eps <- 1e-8 * diff(range(breaks))
  breaks <- unique(breaks + seq_along(breaks) * eps)
}

map_data <- map_data |>
  mutate(
    shi_bin = cut(shi_resid,
                  breaks = breaks,
                  include.lowest = TRUE,
                  dig.lab = 3)
  )

# Bin labels: midpoint of each interval formatted to 3 decimals
bin_labels <- levels(map_data$shi_bin)

# ---- 6. Warm sequential palette (matches paper's Figure 1) ------------------
# Paper's palette from Figures.R line 102-105.
warm_palette <- c("#FFFFE5", "#FFF9CD", "#FFE79C",
                  "#FFCC66", "#FFA139", "#F17316",
                  "#E55A0A", "#BD4005", "#852F06",
                  "#662506")

# ---- 7. Plot ----------------------------------------------------------------
p <- ggplot() +
  # County fill (quantile-binned SHI residual)
  geom_sf(data = map_data,
          aes(fill = shi_bin, color = "US counties, 2000"),
          linewidth = 0.08) +
  # State borders (thick black overlay)
  geom_sf(data = states_sf,
          aes(color = "US states, 2000"),
          fill = NA,
          linewidth = 0.35) +
  scale_fill_manual(
    values = warm_palette,
    na.value = "grey85",
    labels = bin_labels,
    name   = "SHI\n(residualizing\nstate FE)",
    drop   = FALSE,
    guide  = guide_legend(
      title.position = "top",
      title.hjust    = 0,
      keyheight      = unit(4, "mm"),
      keywidth       = unit(6, "mm"),
      reverse        = TRUE,
      label.theme    = element_text(size = 7),
      title.theme    = element_text(size = 8, face = "bold")
    )
  ) +
  scale_color_manual(
    name   = "Boundaries",
    values = c("US counties, 2000" = "grey75", "US states, 2000" = "black"),
    guide  = guide_legend(
      title.position = "top",
      title.hjust    = 0,
      keyheight      = unit(4, "mm"),
      keywidth       = unit(6, "mm"),
      label.theme    = element_text(size = 7),
      title.theme    = element_text(size = 8, face = "bold"),
      override.aes   = list(fill = NA,
                            linewidth = c(0.08, 0.35))
    )
  ) +
  # Compass rose (top-right area)
  annotation_north_arrow(
    location = "tr",
    which_north = "true",
    pad_x = unit(0.4, "cm"),
    pad_y = unit(0.5, "cm"),
    style = north_arrow_fancy_orienteering(
      fill = c("white", "black"),
      line_col = "black",
      text_size = 6
    ),
    height = unit(1.3, "cm"),
    width  = unit(1.3, "cm")
  ) +
  # Scale bar (bottom-right)
  annotation_scale(
    location   = "br",
    width_hint = 0.18,
    unit_category = "imperial",
    pad_x = unit(0.4, "cm"),
    pad_y = unit(0.3, "cm"),
    text_cex = 0.7,
    height   = unit(0.2, "cm")
  ) +
  # Title rendered here for the PNG; the LaTeX figure caption carries the
  # full explanatory notes, so we deliberately omit a ggplot caption to
  # avoid truncation at the plot edge.
  labs(title = "Figure 1. County-Level Soil Heterogeneity Index") +
  theme_void(base_family = "serif") +
  theme(
    plot.title   = element_text(size = 12, face = "bold", hjust = 0.5,
                                margin = margin(b = 8)),
    legend.position      = "right",
    legend.justification = c(0, 0.5),
    legend.margin        = margin(0, 0, 0, 8),
    plot.margin          = margin(8, 8, 8, 8)
  )

# ---- 8. Save ----------------------------------------------------------------
# 27 cm x 20 cm = 10.63 in x 7.87 in (matches paper's dimensions)
out_path <- file.path(OUT_FIGS, "figure1_shi_map.png")
ggsave(out_path, plot = p,
       width = 27, height = 20, units = "cm",
       dpi = 300, bg = "white")
message("Saved: ", out_path)

out_pdf <- file.path(OUT_FIGS, "figure1_shi_map.pdf")
ggsave(out_pdf, plot = p,
       width = 27, height = 20, units = "cm",
       device = cairo_pdf, bg = "white")
message("Saved: ", out_pdf)
