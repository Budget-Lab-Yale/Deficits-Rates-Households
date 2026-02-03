# generate_output.R — Tables, charts, and markdown summary

library(ggplot2)
library(dplyr)

generate_all_output <- function(panel, fiscal, costs, costs_table,
                                 historical, config, output_dir) {

  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  # ---- 1. Summary CSV ----
  write.csv(costs_table, file.path(output_dir, "household_cost_impacts.csv"),
            row.names = FALSE)
  message(sprintf("  Saved household_cost_impacts.csv"))

  # ---- 2. Vintage panel CSV ----
  write.csv(panel, file.path(output_dir, "projection_vintage_panel.csv"),
            row.names = FALSE)

  # ---- 3. Charts ----
  tryCatch({
    plot_debt_gdp_history(panel, config, output_dir)
    plot_rate_effects(fiscal, config, output_dir)
    plot_household_impacts(costs_table, config, output_dir)
    if (!is.null(historical) && nrow(historical) > 0) {
      plot_historical_contributions(historical, config, output_dir)
    }
  }, error = function(e) {
    message(sprintf("  WARNING: Chart generation failed: %s", e$message))
  })

  # ---- 4. Markdown summary ----
  generate_markdown_summary(fiscal, costs, costs_table, output_dir)

  message(sprintf("  All output written to %s", output_dir))
}


# ---- Charts ----

plot_debt_gdp_history <- function(panel, config, output_dir) {
  p <- ggplot(panel, aes(x = vintage_date, y = debt_gdp_pct)) +
    geom_line(color = "#2166AC", linewidth = 0.8) +
    geom_point(aes(color = debt_gdp_source), size = 2) +
    scale_color_manual(values = c("GitHub+ALFRED"   = "#4393C3",
                                   "GitHub+EconExcel" = "#B35806",
                                   "CBO Excel"        = "#E08214"),
                       name = "Source") +
    labs(
      title = sprintf("CBO Projected Debt/GDP at %d-Year Horizon",
                      config$projection_horizon %||% 5),
      subtitle = "By CBO projection vintage",
      x = "Projection vintage date",
      y = "Projected debt held by public (% of GDP)"
    ) +
    theme_minimal(base_size = 12) +
    theme(
      plot.title = element_text(face = "bold"),
      panel.grid.minor = element_blank()
    )

  ggsave(file.path(output_dir, "debt_gdp_projections.png"), plot = p,
         width = config$chart_width %||% 10,
         height = config$chart_height %||% 6,
         dpi = config$chart_dpi %||% 300, bg = "white")
  message("  Saved debt_gdp_projections.png")
}


plot_rate_effects <- function(fiscal, config, output_dir) {
  # Bar chart showing rate effect decomposition
  bar_df <- data.frame(
    component = c("Total\n(10yr Treasury)", "Term\npremium", "Expected\nshort rate",
                  "Mortgage\n(30yr)", "Auto loan\n(5yr)", "Small business"),
    value = c(
      fiscal$rate_effect$preferred,
      fiscal$tp_effect$preferred,
      fiscal$exp_rate_effect$preferred,
      fiscal$consumer_rates$mortgage_30yr$preferred,
      fiscal$consumer_rates$auto_5yr$preferred,
      fiscal$consumer_rates$small_business_5yr$preferred
    ),
    group = c("Treasury", "Treasury", "Treasury",
              "Consumer", "Consumer", "Consumer"),
    stringsAsFactors = FALSE
  )
  bar_df$component <- factor(bar_df$component, levels = bar_df$component)

  p <- ggplot(bar_df, aes(x = component, y = value, fill = group)) +
    geom_col(width = 0.7) +
    geom_hline(yintercept = 0, color = "grey30") +
    geom_text(aes(label = sprintf("%+.0f", value)),
              vjust = ifelse(bar_df$value >= 0, -0.5, 1.5),
              size = 3.5) +
    scale_fill_manual(values = c("Treasury" = "#2166AC", "Consumer" = "#E08214"),
                      name = NULL) +
    labs(
      title = "Fiscal Contribution to Interest Rates",
      subtitle = sprintf("Effect of %+.1f pp change in projected debt/GDP (%s to %s)",
                          fiscal$delta_debt_gdp,
                          format(fiscal$vintage_from, "%b %Y"),
                          format(fiscal$vintage_to, "%b %Y")),
      x = NULL,
      y = "Basis points"
    ) +
    theme_minimal(base_size = 12) +
    theme(
      plot.title = element_text(face = "bold"),
      panel.grid.minor = element_blank(),
      panel.grid.major.x = element_blank(),
      axis.text.x = element_text(size = 9)
    )

  ggsave(file.path(output_dir, "rate_effects.png"), plot = p,
         width = config$chart_width %||% 10,
         height = config$chart_height %||% 6,
         dpi = config$chart_dpi %||% 300, bg = "white")
  message("  Saved rate_effects.png")
}


plot_household_impacts <- function(costs_table, config, output_dir) {
  # Bar chart of annual cost impacts (preferred scenario only)
  pref <- costs_table[costs_table$scenario == "preferred", ]

  p <- ggplot(pref, aes(x = reorder(loan_type, -abs(annual_impact)),
                         y = annual_impact)) +
    geom_col(fill = "#E08214", width = 0.6) +
    geom_text(aes(label = sprintf("$%s", format_dollars(abs(annual_impact)))),
              vjust = ifelse(pref$annual_impact >= 0, -0.5, 1.5),
              size = 4) +
    geom_hline(yintercept = 0, color = "grey30") +
    labs(
      title = "Annual Household Cost Impact of Fiscal Policy",
      subtitle = sprintf("From %+.1f pp change in projected debt/GDP (preferred elasticity: 3 bp/pp)",
                          pref$rate_change_bps[1] / (3 * pref$passthrough[1])),
      x = NULL,
      y = "Change in annual payment ($)"
    ) +
    theme_minimal(base_size = 12) +
    theme(
      plot.title = element_text(face = "bold"),
      panel.grid.minor = element_blank(),
      panel.grid.major.x = element_blank()
    )

  ggsave(file.path(output_dir, "household_impacts.png"), plot = p,
         width = config$chart_width %||% 10,
         height = config$chart_height %||% 6,
         dpi = config$chart_dpi %||% 300, bg = "white")
  message("  Saved household_impacts.png")
}


plot_historical_contributions <- function(historical, config, output_dir) {
  p <- ggplot(historical, aes(x = vintage_date, y = cumulative_bp)) +
    geom_line(color = "#2166AC", linewidth = 0.8) +
    geom_point(color = "#2166AC", size = 1.5) +
    geom_hline(yintercept = 0, color = "grey30", linewidth = 0.3) +
    geom_bar(aes(y = rate_effect_bp), stat = "identity",
             fill = "#E08214", alpha = 0.6, width = 100) +
    labs(
      title = "Cumulative Fiscal Contribution to Long-Term Rates",
      subtitle = "Bars: vintage-to-vintage effect; Line: cumulative (3 bp per pp debt/GDP)",
      x = "CBO projection vintage",
      y = "Basis points"
    ) +
    theme_minimal(base_size = 12) +
    theme(
      plot.title = element_text(face = "bold"),
      panel.grid.minor = element_blank()
    )

  ggsave(file.path(output_dir, "historical_contributions.png"), plot = p,
         width = config$chart_width %||% 10,
         height = config$chart_height %||% 6,
         dpi = config$chart_dpi %||% 300, bg = "white")
  message("  Saved historical_contributions.png")
}


# ---- Markdown Summary ----

generate_markdown_summary <- function(fiscal, costs, costs_table, output_dir) {

  lines <- c(
    sprintf("# Fiscal Contribution to Interest Rates: %s to %s",
            format(fiscal$vintage_from, "%B %Y"),
            format(fiscal$vintage_to, "%B %Y")),
    "",
    sprintf("*Generated: %s*", format(Sys.time(), "%Y-%m-%d %H:%M")),
    "",
    "## Summary",
    "",
    sprintf("- **Change in CBO %d-year projected debt/GDP:** %+.1f pp (%.1f%% to %.1f%%)",
            fiscal$horizon_year - as.integer(format(fiscal$vintage_to, "%Y")),
            fiscal$delta_debt_gdp,
            fiscal$debt_gdp_from, fiscal$debt_gdp_to),
    sprintf("- **Estimated contribution to long-term Treasury rates:** %+.0f bp (range: %+.0f to %+.0f)",
            fiscal$rate_effect$preferred,
            fiscal$rate_effect$low, fiscal$rate_effect$high),
    sprintf("- **Term premium component (~75%%):** %+.0f bp",
            fiscal$tp_effect$preferred),
    sprintf("- **Expected short rate component (~25%%):** %+.0f bp",
            fiscal$exp_rate_effect$preferred),
    "",
    "## Pass-Through to Consumer Rates",
    "",
    "| Consumer Rate | Rate Effect | Pass-Through |",
    "|--------------|-------------|-------------|"
  )

  for (loan_name in names(fiscal$consumer_rates)) {
    cr <- fiscal$consumer_rates[[loan_name]]
    pt <- fiscal$passthrough[[loan_name]]
    lines <- c(lines, sprintf("| %s | %+.0f bp | %.0f%% |",
                              loan_name, cr$preferred, pt * 100))
  }

  lines <- c(lines,
    "",
    "## Household Cost Impacts (Preferred Elasticity: 3 bp/pp)",
    "",
    "| Loan Type | Principal | Rate Change | Annual Impact | Lifetime Impact |",
    "|-----------|-----------|-------------|--------------|----------------|"
  )

  pref <- costs_table[costs_table$scenario == "preferred", ]
  for (i in seq_len(nrow(pref))) {
    r <- pref[i, ]
    lines <- c(lines, sprintf("| %s | $%s | %+.2f pp | $%s/yr | $%s |",
                              r$loan_type,
                              format_dollars(r$principal),
                              r$rate_change_bps / 100,
                              format_dollars(r$annual_impact),
                              format_dollars(r$lifetime_impact)))
  }

  lines <- c(lines,
    "",
    "## Sensitivity",
    "",
    "| Elasticity | Source | 10yr Effect | Mortgage Annual |",
    "|-----------|--------|-------------|----------------|"
  )

  for (scenario in c("low", "preferred", "high")) {
    el <- fiscal$elasticity[[scenario]]
    re <- fiscal$rate_effect[[scenario]]
    mortgage <- costs_table[costs_table$scenario == scenario &
                            costs_table$loan_type == costs[[1]]$label, ]
    ma <- if (nrow(mortgage) > 0) mortgage$annual_impact[1] else NA
    src <- switch(scenario,
      low = "Neveu & Schafer (2024)",
      preferred = "Plante et al. (2025)",
      high = "Upper bound"
    )
    lines <- c(lines, sprintf("| %.0f bp/pp | %s | %+.0f bp | $%s/yr |",
                              el, src, re,
                              if (!is.na(ma)) format_dollars(ma) else "N/A"))
  }

  lines <- c(lines,
    "",
    "## Methodology",
    "",
    "This tracker applies published coefficients from the Laubach (2009) framework,",
    "updated by Plante, Richter & Zubairy (2025, Dallas Fed WP 2513). It is NOT a",
    "regression re-estimation. The approach:",
    "",
    "1. Extracts CBO's projected debt/GDP at the 5-year horizon from each projection vintage",
    "2. Computes the change between consecutive vintages",
    "3. Multiplies by the published elasticity (3 bp per pp, range 2-4)",
    "4. Decomposes into term premium (~75%) and expected short rate (~25%) channels",
    "5. Applies pass-through rates to consumer loan rates",
    "6. Translates into dollar cost impacts via standard amortization",
    "",
    "## Sources",
    "",
    "- Plante, Richter & Zubairy (2025). Dallas Fed Working Paper 2513.",
    "- Laubach (2009). FEDS 2009-12.",
    "- Furceri et al. (2025). IMF Working Paper 2025/142.",
    "- Neveu & Schafer (2024). CBO Working Paper 2024-05.",
    "- CBO Budget and Economic Outlook projections.",
    ""
  )

  writeLines(lines, file.path(output_dir, "summary.md"))
  message("  Saved summary.md")
}
