# generate_output.R — Tables, charts, and markdown summary
#
# Updated for legislative decomposition with two cumulative scenarios.

library(ggplot2)
library(dplyr)
library(patchwork)
library(flextable)
library(officer)

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
      plot_cumulative_rate_effect(historical, config, output_dir)
      plot_historical_contributions(historical, config, output_dir)
    }
    plot_household_impacts(costs_table, config, output_dir)
  }, error = function(e) {
    message(sprintf("  WARNING: Chart generation failed: %s", e$message))
  })

  # ---- 5. Markdown summary ----
  generate_markdown_summary(fiscal, costs, costs_table, panel, config, output_dir)

  # ---- 6. Publication workbook ----
  write_interest_cost_impacts_workbook(fiscal, costs, costs_table, output_dir)

  message(sprintf("  All output written to %s", output_dir))
}


# ---- Charts ----

plot_legislative_delta <- function(panel, config, output_dir) {
  # Bar chart of per-vintage legislative delta(debt/GDP)
  horizon <- config$projection_horizon %||% 10
  p <- ggplot(panel, aes(x = vintage_date, y = legislative_delta_debt_gdp)) +
    geom_col(fill = "#E08214", width = 50) +
    geom_hline(yintercept = 0, color = "grey30", linewidth = 0.3) +
    labs(
      title = "Legislative Contribution to Debt/GDP per CBO Vintage",
      subtitle = sprintf("%d-year cumulative fiscal-policy deficit \u00f7 projected GDP", horizon),
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

  # Label the endpoint of each series
  endpoints <- do.call(rbind, lapply(plot_data, function(d) tail(d, 1)))

  p <- ggplot(combined, aes(x = vintage_date, y = cumulative, color = scenario)) +
    geom_line(linewidth = 0.8) +
    geom_point(size = 2) +
    geom_hline(yintercept = 0, color = "grey30", linewidth = 0.3) +
    geom_text(
      data = endpoints,
      aes(label = sprintf("%+.1f pp", cumulative)),
      hjust = -0.15, vjust = 0.4, size = 3.8, fontface = "bold", show.legend = FALSE
    ) +
    scale_color_manual(values = c("Since 2015" = "#2166AC",
                                   "Since 2022" = "#E08214"),
                       name = NULL) +
    scale_x_date(expand = expansion(mult = c(0.02, 0.12))) +
    labs(
      title = "Cumulative Legislative Contribution to Debt/GDP",
      subtitle = "Cumulative change in projected debt/GDP attributable to enacted legislation",
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


plot_cumulative_rate_effect <- function(historical, config, output_dir) {
  # Combined line chart: cumulative rate effect (bp) for all scenarios

  scenarios <- config$scenarios
  if (is.null(scenarios)) {
    scenarios <- list(
      since_2015 = list(start_vintage = "2015-08-01", label = "Since 2015"),
      since_2022 = list(start_vintage = "2022-05-01", label = "Since 2022")
    )
  }

  plot_data <- list()

  for (scenario_name in names(scenarios)) {
    label <- scenarios[[scenario_name]]$label
    start <- as.Date(scenarios[[scenario_name]]$start_vintage)
    scen_data <- historical[historical$scenario == scenario_name, ]
    if (nrow(scen_data) == 0) next

    pts <- scen_data[, c("vintage_date", "cumulative_bp")]
    pts$scenario <- label

    # Anchor at 0 before the first vintage
    prior <- historical$vintage_date[historical$vintage_date < start]
    anchor_date <- if (length(prior) > 0) max(prior) else start
    anchor <- data.frame(vintage_date = anchor_date, cumulative_bp = 0,
                         scenario = label, stringsAsFactors = FALSE)
    pts <- rbind(anchor, pts)
    plot_data[[scenario_name]] <- pts
  }

  if (length(plot_data) == 0) return(invisible(NULL))

  combined <- do.call(rbind, plot_data)

  # Label the endpoint of each series
  endpoints <- do.call(rbind, lapply(plot_data, function(d) tail(d, 1)))

  p <- ggplot(combined, aes(x = vintage_date, y = cumulative_bp, color = scenario)) +
    geom_line(linewidth = 0.9) +
    geom_point(size = 2) +
    geom_hline(yintercept = 0, color = "grey30", linewidth = 0.3) +
    geom_text(
      data = endpoints,
      aes(label = sprintf("%+.0f bp", cumulative_bp)),
      hjust = -0.15, vjust = 0.4, size = 3.8, fontface = "bold", show.legend = FALSE
    ) +
    scale_color_manual(values = c("Since 2015" = "#2166AC",
                                   "Since 2022" = "#E08214"),
                       name = NULL) +
    scale_x_date(expand = expansion(mult = c(0.02, 0.12))) +
    labs(
      title = "Cumulative Legislative Contribution to Long-Term Treasury Rates",
      subtitle = "Legislative effect on 10-year Treasury yields at 3 bp per pp of projected debt/GDP",
      x = "CBO projection vintage",
      y = "Cumulative rate effect (bp)"
    ) +
    theme_minimal(base_size = 12) +
    theme(
      plot.title = element_text(face = "bold"),
      panel.grid.minor = element_blank(),
      legend.position = "top"
    )

  ggsave(file.path(output_dir, "cumulative_rate_effect.png"), plot = p,
         width = config$chart_width %||% 10,
         height = config$chart_height %||% 6,
         dpi = config$chart_dpi %||% 300, bg = "white")
  message("  Saved cumulative_rate_effect.png")
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
        subtitle = "Per-vintage legislative \u0394(debt/GDP) \u00d7 3 bp/pp estimated sensitivity",
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
  # with lifetime cost annotation above each bar
  pref <- costs_table[costs_table$scenario == "preferred", ]
  pref$loan_type <- factor(pref$loan_type,
                           levels = pref$loan_type[order(-abs(pref$annual_impact))])

  p <- ggplot(pref, aes(x = loan_type, y = annual_impact)) +
    geom_col(fill = "#2166AC", width = 0.55) +
    geom_text(
      aes(label = sprintf("$%s/yr", format_dollars(abs(annual_impact)))),
      vjust = -3.0, size = 3.8, color = "grey40"
    ) +
    geom_text(
      aes(label = sprintf("$%s over life of loan", format_dollars(abs(lifetime_impact)))),
      vjust = -1.3, size = 4.0, fontface = "bold", color = "grey20"
    ) +
    scale_y_continuous(
      labels = function(x) sprintf("$%s", format_dollars(x)),
      expand = expansion(mult = c(0, 0.35))
    ) +
    labs(
      title = "Household Cost Impact of Legislative Fiscal Policy",
      subtitle = "Cumulative legislative contribution since 2015 (preferred estimate: 3 bp/pp)",
      x = NULL,
      y = "Additional annual payment"
    ) +
    theme_minimal(base_size = 13) +
    theme(
      plot.title = element_text(face = "bold", size = 14),
      plot.subtitle = element_text(color = "grey40", size = 10.5),
      panel.grid.minor = element_blank(),
      panel.grid.major.x = element_blank(),
      axis.text.x = element_text(size = 11)
    )

  ggsave(file.path(output_dir, "household_impacts.png"), plot = p,
         width = config$chart_width %||% 10,
         height = config$chart_height %||% 6,
         dpi = config$chart_dpi %||% 300, bg = "white")
  message("  Saved household_impacts.png")
}


# ---- Markdown Summary ----

generate_markdown_summary <- function(fiscal, costs, costs_table, panel, config, output_dir) {
  horizon <- config$projection_horizon %||% 10
  start_offset <- config$window_start_offset %||% 0
  window_start <- if (start_offset == 0) "t" else sprintf("t+%d", start_offset)
  window_end <- sprintf("t+%d", start_offset + horizon - 1)
  source_mode <- config$cbo_data_source %||% "excel_legacy"
  data_source_line <- if (identical(source_mode, "eval_csv_primary")) {
    "- **Fiscal-policy decomposition:** CBO eval-projections CSVs + latest Excel append"
  } else {
    "- **Fiscal-policy decomposition:** CBO Budget Projections Excel files"
  }

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
    "## Household Cost Impacts (Preferred Estimate: 3 bp/pp)",
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
    "| Estimated Sensitivity | Source | 10yr Effect | Mortgage Annual |",
    "|----------------------|--------|-------------|----------------|"
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
    sprintf("2. Harmonizes each vintage to an exact %d-year window (%s through %s),", horizon, window_start, window_end),
    "   then divides by projected GDP to get fiscal-policy delta(debt/GDP) in pp",
    "3. Chains these across consecutive CBO vintages into cumulative series",
    "4. Multiplies by the estimated sensitivity (3 bp per pp, range 2-4)",
    "5. Decomposes into term premium (~75%) and expected short rate (~25%) channels",
    "6. Applies pass-through rates to consumer loan rates",
    "7. Translates into dollar cost impacts via standard amortization",
    "",
    "Note: The 2026-02 vintage includes a one-time policy-intent adjustment adding",
    "customs-duty effects that CBO classified as technical and economic changes.",
    "",
    "### Data Sources",
    "",
    sprintf("- **Decomposition vintages:** %d CBO projection vintages",
            nrow(panel)),
    data_source_line,
    "- **GDP denominator:** CBO GDP vintage table (+ latest Economic Projections Excel append)",
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


# ---- Publication Workbook ----

compute_impacts_for_bps <- function(loan_cost, rate_change_bps) {
  principal <- loan_cost$principal
  term_months <- loan_cost$term_months
  observed_rate <- loan_cost$scenarios$preferred$observed_rate
  counterfactual_rate <- observed_rate - rate_change_bps / 100

  observed_annual <- amortize_annual_payment(principal, observed_rate, term_months)
  counterfactual_annual <- amortize_annual_payment(principal, counterfactual_rate, term_months)
  observed_total <- amortize_total_cost(principal, observed_rate, term_months)
  counterfactual_total <- amortize_total_cost(principal, counterfactual_rate, term_months)

  list(
    rate_pp = rate_change_bps / 100,
    annual_impact = observed_annual - counterfactual_annual,
    lifetime_impact = observed_total - counterfactual_total
  )
}


build_interest_cost_table_rows <- function(fiscal, costs) {
  if (is.null(fiscal$since_2015) || is.null(fiscal$since_2022)) {
    stop("Interest-cost workbook requires both since_2015 and since_2022 scenarios")
  }

  rate_2015 <- fiscal$since_2015$consumer_rates
  rate_2022 <- fiscal$since_2022$consumer_rates

  m_2015 <- compute_impacts_for_bps(costs$mortgage, rate_2015$mortgage_30yr$preferred)
  m_2022 <- compute_impacts_for_bps(costs$mortgage, rate_2022$mortgage_30yr$preferred)

  sb_2015 <- compute_impacts_for_bps(costs$small_business, rate_2015$small_business$preferred)
  sb_2022 <- compute_impacts_for_bps(costs$small_business, rate_2022$small_business$preferred)

  a_2015 <- compute_impacts_for_bps(costs$auto, rate_2015$auto$preferred)
  a_2022 <- compute_impacts_for_bps(costs$auto, rate_2022$auto$preferred)

  mortgage_principal <- costs$mortgage$principal
  mortgage_sale_price <- round(mortgage_principal / 0.8, 0)

  rows <- data.frame(
    label = c(
      costs$mortgage$label,
      "Median sale price (Q3 2025)",
      "Less 20% down",
      "Fiscal-policy rate effect (percentage point)",
      "Annual interest cost effect",
      "Cumulative lifetime cost effect",
      "",
      costs$small_business$label,
      "Average loan balance (2024)",
      "Fiscal-policy rate effect (percentage point)",
      "Annual interest cost effect",
      "Cumulative lifetime cost effect",
      "",
      costs$auto$label,
      "Average new auto loan principal (Q3 2025)",
      "Fiscal-policy rate effect (percentage point)",
      "Annual interest cost effect",
      "Cumulative lifetime cost effect",
      ""
    ),
    since_2015 = c(
      NA, mortgage_sale_price, mortgage_principal,
      m_2015$rate_pp, round(m_2015$annual_impact, 0), round(m_2015$lifetime_impact, 0),
      NA,
      NA, costs$small_business$principal,
      sb_2015$rate_pp, round(sb_2015$annual_impact, 0), round(sb_2015$lifetime_impact, 0),
      NA,
      NA, costs$auto$principal,
      a_2015$rate_pp, round(a_2015$annual_impact, 0), round(a_2015$lifetime_impact, 0),
      NA
    ),
    since_2022 = c(
      NA, mortgage_sale_price, mortgage_principal,
      m_2022$rate_pp, round(m_2022$annual_impact, 0), round(m_2022$lifetime_impact, 0),
      NA,
      NA, costs$small_business$principal,
      sb_2022$rate_pp, round(sb_2022$annual_impact, 0), round(sb_2022$lifetime_impact, 0),
      NA,
      NA, costs$auto$principal,
      a_2022$rate_pp, round(a_2022$annual_impact, 0), round(a_2022$lifetime_impact, 0),
      NA
    ),
    row_type = c(
      "section_header", "principal", "principal", "rate", "cost", "cost",
      "blank",
      "section_header", "principal", "rate", "cost", "cost",
      "blank",
      "section_header", "principal", "rate", "cost", "cost",
      "blank"
    ),
    stringsAsFactors = FALSE
  )

  rows
}


write_interest_cost_impacts_workbook <- function(fiscal, costs, costs_table, output_dir) {
  rows <- build_interest_cost_table_rows(fiscal, costs)
  output_path <- file.path(output_dir, "interest_cost_impacts_table.docx")

  if (!requireNamespace("flextable", quietly = TRUE)) {
    stop("Package 'flextable' is required to write interest_cost_impacts_table.docx")
  }

  ft_costs <- build_costs_flextable(rows)
  ft_sensitivity <- build_sensitivity_flextable(fiscal, costs, costs_table)

  # Write both tables to a single docx
  doc <- officer::read_docx()
  doc <- officer::body_add_par(doc, "Cumulative Interest Cost Impacts of Fiscal Policy",
                               style = "heading 2")
  doc <- flextable::body_add_flextable(doc, ft_costs)
  doc <- officer::body_add_par(doc, "")
  doc <- officer::body_add_par(doc, "Sensitivity", style = "heading 2")
  doc <- flextable::body_add_flextable(doc, ft_sensitivity)
  print(doc, target = output_path)

  message(sprintf("  Saved %s", basename(output_path)))
}


# Shared table styling helpers
style_tbl_footer <- function(ft) {
  ft <- flextable::fontsize(ft, size = 8, part = "footer")
  ft <- flextable::color(ft, color = "#666666", part = "footer")
  ft
}

tbl_attribution <- "Table: The Budget Lab | Source: NAR, Experian, B2BReview/SBA, Freddie Mac, FRED, The Budget Lab analysis"


build_costs_flextable <- function(rows) {
  # Build display data.frame (drop blank/spacer rows)
  display <- rows[rows$row_type != "blank", ]

  fmt_val <- function(val, row_type) {
    if (is.na(val)) return("")
    if (row_type == "rate") return(sprintf("%.2f", val))
    paste0("$", formatC(round(val), format = "f", digits = 0, big.mark = ","))
  }

  display$col_2015 <- mapply(fmt_val, display$since_2015, display$row_type)
  display$col_2022 <- mapply(fmt_val, display$since_2022, display$row_type)

  # Clear values for section headers
  display$col_2015[display$row_type == "section_header"] <- ""
  display$col_2022[display$row_type == "section_header"] <- ""

  # Indent detail rows
  display$label[display$row_type != "section_header"] <-
    paste0("  ", display$label[display$row_type != "section_header"])

  tbl_data <- data.frame(
    label = display$label,
    since_2015 = display$col_2015,
    since_2022 = display$col_2022,
    stringsAsFactors = FALSE
  )

  ft <- flextable::flextable(tbl_data)

  ft <- flextable::set_header_labels(ft,
    label = "",
    since_2015 = "Cumulative since 2015",
    since_2022 = "Cumulative since 2022"
  )

  # Typography
  ft <- flextable::font(ft, fontname = "Calibri", part = "all")
  ft <- flextable::fontsize(ft, size = 10, part = "all")

  # Header styling
  ft <- flextable::bold(ft, part = "header")
  ft <- flextable::align(ft, j = 2:3, align = "center", part = "all")
  ft <- flextable::bg(ft, bg = "#F2F2F2", part = "header")

  # Section headers: bold
  section_rows <- which(display$row_type == "section_header")
  if (length(section_rows) > 0) {
    ft <- flextable::bold(ft, i = section_rows, j = 1)
  }

  # Cost rows: bold
  cost_rows <- which(display$row_type == "cost")
  if (length(cost_rows) > 0) {
    ft <- flextable::bold(ft, i = cost_rows)
  }

  # Borders
  thin_border <- officer::fp_border(color = "#999999", width = 0.5)
  thick_border <- officer::fp_border(color = "#333333", width = 1.0)
  no_border <- officer::fp_border(color = "transparent", width = 0)

  ft <- flextable::hline_top(ft, border = thick_border, part = "header")
  ft <- flextable::hline_bottom(ft, border = thin_border, part = "header")
  ft <- flextable::hline_bottom(ft, border = thick_border, part = "body")

  for (sr in section_rows) {
    if (sr > 1) {
      ft <- flextable::hline(ft, i = sr - 1, border = thin_border)
    }
  }

  ft <- flextable::border(ft, border.left = no_border, border.right = no_border,
                          part = "all")

  # Column widths
  ft <- flextable::width(ft, j = 1, width = 3.5)
  ft <- flextable::width(ft, j = 2:3, width = 1.5)

  # Padding
  ft <- flextable::padding(ft, padding.top = 2, padding.bottom = 2, part = "body")

  # Footer
  note <- paste0(
    "Rate effects computed as cumulative legislative change in projected debt-to-GDP ",
    "multiplied by 3 basis points per percentage point (Plante, Richter & Zubairy 2025), ",
    "scaled by product-specific pass-through coefficients. ",
    "Mortgage pass-through: 100%. Auto: 50%. Small business: 25%. ",
    "All loan parameters as of late November 2025."
  )
  ft <- flextable::add_footer_lines(ft, values = note)
  ft <- flextable::add_footer_lines(ft, values = tbl_attribution)
  ft <- style_tbl_footer(ft)

  ft
}


build_sensitivity_flextable <- function(fiscal, costs, costs_table) {
  primary <- fiscal[["since_2015"]] %||% fiscal[[1]]
  mortgage_label <- if (!is.null(costs$mortgage)) costs$mortgage$label else costs[[1]]$label

  fmt_d <- function(x) paste0("$", formatC(round(x), format = "f", digits = 0, big.mark = ","))

  sens_rows <- list()
  for (scenario in c("low", "preferred", "high")) {
    el <- primary$elasticity[[scenario]]
    re <- primary$rate_effect[[scenario]]
    mortgage <- costs_table[costs_table$scenario == scenario &
                            costs_table$loan_type == mortgage_label, ]
    ma <- if (nrow(mortgage) > 0) round(mortgage$annual_impact[1], 0) else NA
    ml <- if (nrow(mortgage) > 0) round(mortgage$lifetime_impact[1], 0) else NA
    src <- switch(scenario,
      low = "Neveu & Schafer (2024)",
      preferred = "Plante, Richter & Zubairy (2025)",
      high = "Upper bound from Laubach (2009)"
    )
    sens_rows[[length(sens_rows) + 1]] <- data.frame(
      sensitivity = sprintf("%.0f bp/pp", el),
      source = src,
      treasury_effect = sprintf("%+.0f bp", re),
      annual_mortgage = if (!is.na(ma)) paste0(fmt_d(ma), "/yr") else "N/A",
      lifetime_mortgage = if (!is.na(ml)) fmt_d(ml) else "N/A",
      stringsAsFactors = FALSE
    )
  }

  sens_data <- do.call(rbind, sens_rows)

  ft <- flextable::flextable(sens_data)

  ft <- flextable::set_header_labels(ft,
    sensitivity = "Estimated\nSensitivity",
    source = "Source",
    treasury_effect = "Long-Term Treasury\nRate Effect",
    annual_mortgage = "Annual Mortgage\nCost",
    lifetime_mortgage = "Lifetime Mortgage\nCost"
  )

  # Typography
  ft <- flextable::font(ft, fontname = "Calibri", part = "all")
  ft <- flextable::fontsize(ft, size = 10, part = "all")

  # Header
  ft <- flextable::bold(ft, part = "header")
  ft <- flextable::bg(ft, bg = "#F2F2F2", part = "header")
  ft <- flextable::align(ft, j = 1, align = "center", part = "all")
  ft <- flextable::align(ft, j = 3:5, align = "center", part = "all")

  # Bold the preferred row
  ft <- flextable::bold(ft, i = 2)

  # Borders
  thin_border <- officer::fp_border(color = "#999999", width = 0.5)
  thick_border <- officer::fp_border(color = "#333333", width = 1.0)
  no_border <- officer::fp_border(color = "transparent", width = 0)

  ft <- flextable::hline_top(ft, border = thick_border, part = "header")
  ft <- flextable::hline_bottom(ft, border = thin_border, part = "header")
  ft <- flextable::hline_bottom(ft, border = thick_border, part = "body")
  ft <- flextable::border(ft, border.left = no_border, border.right = no_border,
                          part = "all")

  # Column widths
  ft <- flextable::width(ft, j = 1, width = 1.0)
  ft <- flextable::width(ft, j = 2, width = 2.2)
  ft <- flextable::width(ft, j = 3, width = 1.2)
  ft <- flextable::width(ft, j = 4, width = 1.2)
  ft <- flextable::width(ft, j = 5, width = 1.2)

  # Padding
  ft <- flextable::padding(ft, padding.top = 2, padding.bottom = 2, part = "body")

  # Footer
  ft <- flextable::add_footer_lines(ft,
    values = paste0(
      "Based on cumulative legislative debt impacts since 2015. Preferred estimate bolded. ",
      "The 2 and 4 bp/pp estimates are from regressions of the 5-year-ahead 5-year Treasury rate ",
      "on CBO 5-year debt/GDP forecasts; the preferred 3 bp/pp uses the 10-year Treasury and ",
      "10-year forecasts (Plante, Richter & Zubairy 2025)."))
  ft <- flextable::add_footer_lines(ft, values = tbl_attribution)
  ft <- style_tbl_footer(ft)

  ft
}
