# =============================================================================
# 05_robustness_extensions.R
# Replication of Raz (2025)
#
# Purpose: Robustness checks for Table 1 results and one extension analysis.
#
# Robustness checks:
#   (a) Sensitivity to state FE vs state x year FE
#   (b) Drop one geo-climatic control at a time (leave-one-out)
#   (c) Alternative SE clustering: county vs state
#
# Extension:
#   Heterogeneous treatment by wheat-belt vs non-wheat-belt counties.
#   Motivation: paper's Prediction 3 (social learning channel strongest
#   where farming dominates and crops are most sensitive to soil type).
#   If the SHI -> LNI effect operates through agricultural social learning,
#   it should be stronger in counties where wheat farming was central
#   (wheat is highly sensitive to local soil conditions).
#
# Output: output/tables/table_robustness.docx
#         output/figures/figure_robustness_coefplot.png
# =============================================================================

source("/Users/ruihuaguo/Presentation_claude/Replication_project/Refined results/R/00_setup.R", local = FALSE)

panel <- load_panel()

# Subset to rows with LNI and full controls available
analysis <- panel |> drop_na(lni, shi, all_of(CONTROLS_FULL))
cat(sprintf("Analysis sample (LNI + full controls): %d county-year obs.\n", nrow(analysis)))

# ---- Robustness (a): FE specification sensitivity ---------------------------
cat("\n--- Robustness (a): Fixed effects specification ---\n")

# Preferred from Table 1
m_preferred  <- run_ols(analysis, "lni", CONTROLS_FULL,
                        fe_str = "state^year", cluster_var = "state")
# State FE only (no year interactions)
m_state_only <- run_ols(analysis, "lni", CONTROLS_FULL,
                        fe_str = "state", cluster_var = "state")
# No FE (baseline)
m_no_fe      <- run_ols(analysis, "lni", CONTROLS_FULL,
                        fe_str = "", cluster_var = "state")

for (nm in c("preferred (state x year FE)",
             "state FE only",
             "no FE")) {
  m <- list(m_preferred, m_state_only, m_no_fe)[[
    match(nm, c("preferred (state x year FE)", "state FE only", "no FE"))
  ]]
  cat(sprintf("  %-30s SHI = %+.4f (SE = %.4f, p = %.3f)\n",
              nm, coef(m)["shi"], se(m)["shi"], pvalue(m)["shi"]))
}

# ---- Robustness (b): Leave-one-out controls ---------------------------------
cat("\n--- Robustness (b): Drop one geo-climatic control at a time ---\n")

loo_models <- list()
loo_labels <- c()

for (drop_ctrl in GEOCLIMATIC) {
  ctrls_loo <- c(setdiff(GEOCLIMATIC, drop_ctrl), SMOOTH_LOC)
  m_loo <- tryCatch(
    run_ols(analysis, "lni", ctrls_loo,
            fe_str = "state^year", cluster_var = "state"),
    error = function(e) NULL
  )
  if (!is.null(m_loo)) {
    label <- paste("Drop:", drop_ctrl)
    loo_models[[label]] <- m_loo
    loo_labels <- c(loo_labels, label)
    cat(sprintf("  drop %-25s SHI = %+.4f (SE = %.4f, p = %.3f)\n",
                drop_ctrl, coef(m_loo)["shi"], se(m_loo)["shi"], pvalue(m_loo)["shi"]))
  }
}

# ---- Robustness (c): SE clustering ------------------------------------------
cat("\n--- Robustness (c): Standard error clustering ---\n")

# State-level clustering (baseline)
m_state_cl <- run_ols(analysis, "lni", CONTROLS_FULL,
                      fe_str = "state^year", cluster_var = "state")
# County-level clustering (more conservative)
m_county_cl <- run_ols(analysis, "lni", CONTROLS_FULL,
                       fe_str = "state^year", cluster_var = "gisjoin")

cat(sprintf("  Cluster at state:   SHI = %+.4f (SE = %.4f, p = %.3f)\n",
            coef(m_state_cl)["shi"], se(m_state_cl)["shi"], pvalue(m_state_cl)["shi"]))
cat(sprintf("  Cluster at county:  SHI = %+.4f (SE = %.4f, p = %.3f)\n",
            coef(m_county_cl)["shi"], se(m_county_cl)["shi"], pvalue(m_county_cl)["shi"]))

# ---- Extension: Wheat-belt heterogeneity ------------------------------------
cat("\n--- Extension: Wheat-belt heterogeneous effects ---\n")
cat("Hypothesis: SHI -> LNI effect stronger in wheat-belt counties\n")
cat("(wheat cultivation is highly soil-type sensitive, so social learning\n")
cat(" about wheat farming was especially valuable — and SHI especially limiting).\n\n")

# Define wheat belt as counties above median wheat share (any year with data)
median_wheat <- median(analysis$wheat_share_of_farmland, na.rm = TRUE)
analysis <- analysis |>
  mutate(wheat_belt = if_else(wheat_share_of_farmland > median_wheat &
                                !is.na(wheat_share_of_farmland),
                              "Wheat Belt", "Non-Wheat Belt"))

cat(sprintf("Median wheat share of farmland: %.4f\n", median_wheat))
cat(sprintf("Wheat-belt county-year obs:     %d\n",
            sum(analysis$wheat_belt == "Wheat Belt", na.rm = TRUE)))
cat(sprintf("Non-wheat-belt obs:             %d\n",
            sum(analysis$wheat_belt == "Non-Wheat Belt", na.rm = TRUE)))

m_wheat    <- tryCatch(
  run_ols(analysis |> filter(wheat_belt == "Wheat Belt"),
          "lni", CONTROLS_FULL,
          fe_str = "state^year", cluster_var = "state"),
  error = function(e) { cat("Wheat-belt model error:", e$message, "\n"); NULL }
)
m_nonwheat <- tryCatch(
  run_ols(analysis |> filter(wheat_belt == "Non-Wheat Belt"),
          "lni", CONTROLS_FULL,
          fe_str = "state^year", cluster_var = "state"),
  error = function(e) { cat("Non-wheat-belt model error:", e$message, "\n"); NULL }
)

if (!is.null(m_wheat) && !is.null(m_nonwheat)) {
  cat(sprintf("  Wheat belt:     SHI = %+.4f (SE = %.4f, p = %.3f, N = %d)\n",
              coef(m_wheat)["shi"], se(m_wheat)["shi"],
              pvalue(m_wheat)["shi"], nobs(m_wheat)))
  cat(sprintf("  Non-wheat belt: SHI = %+.4f (SE = %.4f, p = %.3f, N = %d)\n",
              coef(m_nonwheat)["shi"], se(m_nonwheat)["shi"],
              pvalue(m_nonwheat)["shi"], nobs(m_nonwheat)))
  cat("\nInterpretation: if the social learning mechanism is operative,\n")
  cat("we expect a more negative SHI coefficient in wheat-belt counties.\n")
}

# ---- Coefficient plot (extension) -------------------------------------------
if (!is.null(m_wheat) && !is.null(m_nonwheat)) {
  ext_results <- bind_rows(
    tibble(
      group = "Wheat Belt",
      est   = coef(m_wheat)["shi"],
      lo    = confint(m_wheat)["shi", 1],
      hi    = confint(m_wheat)["shi", 2]
    ),
    tibble(
      group = "Non-Wheat Belt",
      est   = coef(m_nonwheat)["shi"],
      lo    = confint(m_nonwheat)["shi", 1],
      hi    = confint(m_nonwheat)["shi", 2]
    )
  )

  p_ext <- ggplot(ext_results, aes(x = group, y = est, ymin = lo, ymax = hi)) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "grey50") +
    geom_errorbar(width = 0.15, color = "navy", linewidth = 0.8) +
    geom_point(size = 3, color = "navy") +
    labs(
      title   = "Extension: SHI Effect on LNI by Agricultural Region",
      subtitle = "Preferred specification (state x year FE + full controls). 95% CI shown.",
      x       = NULL,
      y       = "SHI Coefficient (OLS)",
      caption = paste(
        "Notes: Wheat-belt counties defined as those above the median wheat share of farmland.",
        "Hypothesis: SHI -> LNI effect should be stronger in wheat-belt counties",
        "because wheat cultivation is more sensitive to soil-type heterogeneity,",
        "making social learning about wheat farming more valuable."
      )
    ) +
    theme_classic(base_family = "serif", base_size = 11) +
    theme(
      plot.caption = element_text(size = 8, hjust = 0, color = "grey40"),
      plot.title   = element_text(face = "bold")
    )

  out_fig <- file.path(OUT_FIGS, "figure_extension_wheatbelt.png")
  ggsave(out_fig, plot = p_ext, width = 6, height = 4.5, dpi = 180, bg = "white")
  message("Saved: ", out_fig)
}

# ---- Export robustness Word table -------------------------------------------
rob_models <- c(
  list(
    "Preferred\n(State x Year FE)" = m_preferred,
    "State FE Only"                = m_state_only,
    "No FE"                        = m_no_fe,
    "Cluster: County"              = m_county_cl
  ),
  loo_models
)

notes_rob <- paste(
  "Notes: Each column reports the SHI coefficient from OLS estimation of equation (1)",
  "with LNI as the dependent variable.",
  "Preferred specification: state x year FE + full geo-climatic + smooth location controls,",
  "SE clustered at state (proxy for paper's grid clusters).",
  "Leave-one-out columns drop one geo-climatic control at a time from the preferred spec.",
  "'Cluster: County' uses county-level clustered SE in the preferred spec.",
  "* p<0.10, ** p<0.05, *** p<0.01."
)

ms_rob <- modelsummary(
  rob_models,
  output   = "flextable",
  stars    = c("*" = 0.10, "**" = 0.05, "***" = 0.01),
  coef_map = c("shi" = "Soil Heterogeneity Index"),
  gof_map  = list(
    list(raw = "nobs",      clean = "Observations", fmt = 0),
    list(raw = "r.squared", clean = "R\u00b2",      fmt = 3)
  ),
  title = "Robustness Checks: SHI Effect on LNI",
  notes = notes_rob
) |>
  bold(part = "header") |>
  bg(i = seq(2, 4, 2), bg = "#F2F2F2", part = "body") |>
  fontsize(size = 9, part = "all") |>
  font(fontname = "Times New Roman", part = "all") |>
  autofit()

out_rob <- file.path(OUT_TABS, "table_robustness.docx")
doc_rob <- read_docx() |> body_add_flextable(ms_rob)
print(doc_rob, target = out_rob)
message("Saved: ", out_rob)

cat("\nRobustness analysis complete.\n")
