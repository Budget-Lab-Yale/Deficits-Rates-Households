# generate_output.R — Tables, charts, and markdown summary
#
# Updated for legislative decomposition with two cumulative scenarios.

library(ggplot2)
library(dplyr)
library(patchwork)

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

  # ---- 3. Historical contributions CSV ----
  if (!is.null(historical) && nrow(historical) > 0) {
    write.csv(historical, file.path(output_dir, "historical_contributions.csv"),
              row.names = FALSE)
  }

  # ---- 4. Charts ----
  tryCatch({
    plot_legislative_delta(panel, config, output_dir)
    plot_cumulative_legislative(panel, config, output_dir)
    if (!is.null(historical) && nrow(historical) > 0) {
      plot_historical_contributions(historical, config, output_dir)
    }
    plot_household_impacts(costs_table, config, output_dir)
  }, error = function(e) {
    message(sprintf("  WARNING: Chart generation failed: %s", e$message))
  })

  # ---- 5. Markdown summary ----
  generate_markdown_summary(fiscal, costs, costs_table, panel, output_dir)

  message(sprintf("  All output written to %s", output_dir))
}


# ---- Charts ----

plot_legislative_delta <- function(panel, config, output_dir) {
  # Bar chart of per-vintage legislative delta(debt/GDP)
  p <- ggplot(panel, aes(x = vintage_date, y = legislative_delta_debt_gdp)) +
    geom_col(fill = "#E08214", width = 50) +
    geom_hline(yintercept = 0, color = "grey30", linewidth = 0.3) +
    labs(
      title = "Legislative Contribution to Debt/GDP per CBO Vintage",
      subtitle = "5-year cumulative legislative deficit \u00f7 projected GDP",
      x = "CBO projection vintage",
      y = "Legislative \u0394(debt/GDP) (pp)"
    ) +
    theme_minimal(base_size = 12) +
    theme(
      plot.title = element_text(face = "bold"),
      panel.grid.minor = element_blank(),
      panel.grid.major.x = element_blank()
    )

  ggsave(file.path(output_dir, "legislative_delta.png"), plot = p,
         width = config$chart_width %||% 10,
         height = config$chart_height %||% 6,
         dpi = config$chart_dpi %||% 300, bg = "white")
  message("  Saved legislative_delta.png")
}


plot_cumulative_legislative <- function(panel, config, output_dir) {
  # Line chart showing cumulative legislative delta(debt/GDP) for both scenarios

  scenarios <- config$scenarios
  if (is.null(scenarios)) {
    scenarios <- list(
      since_2015 = list(start_vintage = "2015-08-01", label = "Since 2015"),
      since_2022 = list(start_vintage = "2022-05-01", label = "Since 2022")
    )
  }

  plot_data <- list()

  if (any(!is.na(panel$cumulative_since_2015))) {
    d2015 <- panel[!is.na(panel$cumulative_since_2015), ]
    d2015$scenario <- "Since 2015"
    d2015$cumulative <- d2015$cumulative_since_2015
    pts <- d2015[, c("vintage_date", "scenario", "cumulative")]
    # Anchor at 0 on the last vintage before the scenario window
    # (or the first vintage's since_date if no prior vintage in panel)
    start <- as.Date(scenarios$since_2015$start_vintage)
    prior <- panel$vintage_date[panel$vintage_date < start]
    anchor_date <- if (length(prior) > 0) max(prior) else as.Date(d2015$since_date[1])
    anchor <- data.frame(vintage_date = anchor_date, scenario = "Since 2015", cumulative = 0)
    pts <- rbind(anchor, pts)
    plot_data[["2015"]] <- pts
  }

  if (any(!is.na(panel$cumulative_since_2022))) {
    d2022 <- panel[!is.na(panel$cumulative_since_2022), ]
    d2022$scenario <- "Since 2022"
    d2022$cumulative <- d2022$cumulative_since_2022
    pts <- d2022[, c("vintage_date", "scenario", "cumulative")]
    start <- as.Date(scenarios$since_2022$start_vintage)
    prior <- panel$vintage_date[panel$vintage_date < start]
    if (length(prior) > 0) {
      anchor <- data.frame(vintage_date = max(prior), scenario = "Since 2022", cumulative = 0)
      pts <- rbind(anchor, pts)
    }
    plot_data[["2022"]] <- pts
  }

  if (length(plot_data) == 0) return(invisible(NULL))

  combined <- do.call(rbind, plot_data)

  p <- ggplot(combined, aes(x = vintage_date, y = cumulative, color = scenario)) +
    geom_line(linewidth = 0.8) +
    geom_point(size = 2) +
    geom_hline(yintercept = 0, color = "grey30", linewidth = 0.3) +
    scale_color_manual(values = c("Since 2015" = "#2166AC",
                                   "Since 2022" = "#E08214"),
                       name = NULL) +
    labs(
      title = "Cumulative Legislative Contribution to Debt/GDP",
      subtitle = "Chained CBO decomposition vintages",
      x = "CBO projection vintage",
      y = "Cumulative legislative \u0394(debt/GDP) (pp)"
    ) +
    theme_minimal(base_size = 12) +
    theme(
      plot.title = element_text(face = "bold"),
      panel.grid.minor = element_blank(),
      legend.position = "top"
    )

  ggsave(file.path(output_dir, "cumulative_legislative.png"), plot = p,
         width = config$chart_width %||% 10,
         height = config$chart_height %||% 6,
         dpi = config$chart_dpi %||% 300, bg = "white")
  message("  Saved cumulative_legislative.png")
}


plot_historical_contributions <- function(historical, config, output_dir) {
  # Two-panel chart: per-vintage rate effect bars + cumulative rate line
  # Faceted by scenario

  scenarios <- unique(historical$scenario_label)

  for (scen in scenarios) {
    scen_data <- historical[historical$scenario_label == scen, ]
    safe_name <- tolower(gsub("\\s+", "_", scen))

    # Shared x-axis limits
    x_range <- range(scen_data$vintage_date, na.rm = TRUE)
    x_limits <- c(x_range[1] - 60, x_range[2] + 60)

    # Build month gridlines
    year_range <- as.integer(format(x_limits, "%Y"))
    all_months <- seq(as.Date(sprintf("%d-01-01", year_range[1])),
                      as.Date(sprintf("%d-12-01", year_range[2])), by = "1 month")
    month_num <- as.integer(format(all_months, "%m"))
    jan_dates     <- all_months[month_num == 1]
    quarter_dates <- all_months[month_num %in% c(4, 7, 10)]
    other_dates   <- all_months[!month_num %in% c(1, 4, 7, 10)]
    jan_dates <- jan_dates[jan_dates >= x_limits[1] & jan_dates <= x_limits[2]]
    quarter_dates <- quarter_dates[quarter_dates >= x_limits[1] & quarter_dates <= x_limits[2]]
    other_dates <- other_dates[other_dates >= x_limits[1] & other_dates <= x_limits[2]]

    shared_x <- scale_x_date(limits = x_limits,
                              breaks = jan_dates, date_labels = "%Y")

    grid_layers <- list(
      geom_vline(xintercept = other_dates,
                 color = "grey90", linewidth = 0.2),
      geom_vline(xintercept = quarter_dates,
                 color = "grey75", linewidth = 0.3),
      geom_vline(xintercept = jan_dates,
                 color = "grey60", linewidth = 0.4)
    )

    # Top panel: per-vintage rate effects
    p_bars <- ggplot(scen_data, aes(x = vintage_date, y = rate_effect_bp)) +
      grid_layers +
      geom_col(fill = "#E08214", width = 25) +
      geom_hline(yintercept = 0, color = "grey30", linewidth = 0.3) +
      shared_x +
      labs(
        title = sprintf("Legislative Fiscal Contribution to Long-Term Rates (%s)", scen),
        subtitle = "Per-vintage legislative \u0394(debt/GDP) \u00d7 3 bp/pp elasticity",
        x = NULL,
        y = "bp (per vintage)"
      ) +
      theme_minimal(base_size = 12) +
      theme(
        plot.title = element_text(face = "bold"),
        panel.grid.minor = element_blank(),
        panel.grid.major.x = element_blank()
      )

    # Bottom panel: cumulative rate effect
    p_cum <- ggplot(scen_data, aes(x = vintage_date, y = cumulative_bp)) +
      grid_layers +
      geom_line(color = "#2166AC", linewidth = 0.8) +
      geom_point(color = "#2166AC", size = 1.5) +
      geom_hline(yintercept = 0, color = "grey30", linewidth = 0.3) +
      shared_x +
      labs(
        subtitle = sprintf("Cumulative legislative rate effect %s", tolower(scen)),
        x = "CBO projection vintage",
        y = "Cumulative bp"
      ) +
      theme_minimal(base_size = 12) +
      theme(
        panel.grid.minor = element_blank(),
        panel.grid.major.x = element_blank()
      )

    # Stack with patchwork
    p_combined <- p_bars / p_cum + plot_layout(heights = c(1, 1))

    fname <- sprintf("historical_contributions_%s.png", safe_name)
    ggsave(file.path(output_dir, fname),
           plot = p_combined,
           width = config$chart_width %||% 10,
           height = (config$chart_height %||% 6) * 1.4,
           dpi = config$chart_dpi %||% 300, bg = "white")
    message(sprintf("  Saved %s", fname))
  }
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
      title = "Annual Household Cost Impact of Legislative Fiscal Policy",
      subtitle = "Cumulative legislative contribution (preferred elasticity: 3 bp/pp)",
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


# ---- Markdown Summary ----

generate_markdown_summary <- function(fiscal, costs, costs_table, panel, output_dir) {

  lines <- c(
    "# Fiscal-Policy Contribution to Interest Rates",
    "",
    sprintf("*Generated: %s*", format(Sys.time(), "%Y-%m-%d %H:%M")),
    ""
  )

  # Summary for each scenario
  for (scenario_name in names(fiscal)) {
    f <- fiscal[[scenario_name]]

    lines <- c(lines,
      sprintf("## %s", f$scenario_label),
      "",
      sprintf("- **Scenario:** Cumulative fiscal-policy impact %s (%d vintages)",
              tolower(f$scenario_label), f$n_vintages),
      sprintf("- **Cumulative fiscal-policy \\u0394(debt/GDP):** %+.2f pp",
              f$cumulative_delta),
      sprintf("- **Estimated contribution to long-term Treasury rates:** %+.0f bp (range: %+.0f to %+.0f)",
              f$rate_effect$preferred, f$rate_effect$low, f$rate_effect$high),
      sprintf("- **Term premium component (~75%%):** %+.0f bp",
              f$tp_effect$preferred),
      sprintf("- **Expected short rate component (~25%%):** %+.0f bp",
              f$exp_rate_effect$preferred),
      ""
    )

    lines <- c(lines,
      "### Pass-Through to Consumer Rates",
      "",
      "| Consumer Rate | Rate Effect | Pass-Through |",
      "|--------------|-------------|-------------|"
    )

    for (loan_name in names(f$consumer_rates)) {
      cr <- f$consumer_rates[[loan_name]]
      pt <- f$passthrough[[loan_name]]
      lines <- c(lines, sprintf("| %s | %+.0f bp | %.0f%% |",
                                loan_name, cr$preferred, pt * 100))
    }

    lines <- c(lines, "")
  }

  # Household costs (primary scenario)
  lines <- c(lines,
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

  # Sensitivity table
  primary <- fiscal[["since_2015"]] %||% fiscal[[1]]

  lines <- c(lines,
    "",
    "## Sensitivity",
    "",
    "| Elasticity | Source | 10yr Effect | Mortgage Annual |",
    "|-----------|--------|-------------|----------------|"
  )

  for (scenario in c("low", "preferred", "high")) {
    el <- primary$elasticity[[scenario]]
    re <- primary$rate_effect[[scenario]]
    mortgage_label <- if (!is.null(costs$mortgage)) costs$mortgage$label else costs[[1]]$label
    mortgage <- costs_table[costs_table$scenario == scenario &
                            costs_table$loan_type == mortgage_label, ]
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

  # Methodology
  lines <- c(lines,
    "",
    "## Methodology",
    "",
    "This tracker applies published coefficients from the Laubach (2009) framework,",
    "updated by Plante, Richter & Zubairy (2025, Dallas Fed WP 2513). It is NOT a",
    "regression re-estimation. The approach:",
    "",
    "1. From each CBO projection vintage, extracts the **fiscal-policy component** of",
    "   CBO's deficit decomposition (legislative plus documented policy-intent adjustments)",
    "2. Harmonizes each vintage to an exact 5-year window (t+1 through t+5),",
    "   then divides by projected GDP to get fiscal-policy delta(debt/GDP) in pp",
    "3. Chains these across consecutive CBO vintages into cumulative series",
    "4. Multiplies by the published elasticity (3 bp per pp, range 2-4)",
    "5. Decomposes into term premium (~75%) and expected short rate (~25%) channels",
    "6. Applies pass-through rates to consumer loan rates",
    "7. Translates into dollar cost impacts via standard amortization",
    "",
    "Note: The 2026-02 vintage includes a one-time policy-intent adjustment adding",
    "customs-duty effects that CBO classified as technical changes.",
    "",
    "### Data Sources",
    "",
    sprintf("- **Decomposition vintages:** %d CBO Budget Projections files parsed",
            nrow(panel)),
    "- **GDP denominator:** CBO Economic Projections Excel files",
    "- **Consumer rates:** FRED (MORTGAGE30US, TERMCBAUTO48NS, DPRIME)",
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
