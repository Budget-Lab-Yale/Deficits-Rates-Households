# build_dataset.R — Build legislative decomposition panel
#
# Uses CBO Table A-1 (or equivalent) legislative deficit components
# and CBO Economic Projections GDP to compute legislative delta(debt/GDP).
#
# Output: data.frame with harmonized horizon-window fiscal-policy increments:
#   vintage_date, since_date, legislative_deficit_5yr_bn, projected_gdp_bn,
#   legislative_delta_debt_gdp, cumulative_* scenario columns

library(dplyr)

build_dataset <- function(cbo_excel, config) {

  horizon <- config$projection_horizon %||% 10
  start_offset <- config$window_start_offset %||% 0
  max_lag <- config$max_econ_lag_days %||% 365
  message("Building fiscal-policy decomposition panel...")

  decomp <- cbo_excel$decomp_vintages
  econ   <- cbo_excel$econ_vintages

  if (is.null(decomp) || nrow(decomp) == 0) {
    stop("No legislative decomposition data available")
  }
  if (is.null(econ) || nrow(econ) == 0) {
    stop("No Economic Projections GDP data available")
  }

  # ---- 1. For each decomposition vintage, find GDP at the horizon year ----

  decomp$vintage_year <- as.integer(format(decomp$vintage_date, "%Y"))
  decomp$horizon_year <- decomp$vintage_year + start_offset + horizon - 1

  # Match each decomp vintage to the latest econ vintage on/before the
  # decomposition date, within max_lag days (no look-ahead matching).
  decomp$projected_gdp_bn <- NA_real_
  decomp$econ_vintage_used <- as.Date(NA)

  for (i in seq_len(nrow(decomp))) {
    vd <- decomp$vintage_date[i]
    hy <- decomp$horizon_year[i]

    # Find most recent available econ vintage at or before vd.
    econ_vintages <- unique(econ$vintage_date)
    eligible <- econ_vintages[econ_vintages <= vd]
    if (length(eligible) == 0) {
      stop(sprintf("No econ vintage on or before decomposition vintage %s",
                   format(vd, "%Y-%m-%d")))
    }
    econ_vd <- max(eligible)
    lag_days <- as.numeric(difftime(vd, econ_vd, units = "days"))
    if (lag_days > max_lag) {
      stop(sprintf("No econ vintage within %d days of %s (closest prior: %s, %d days)",
                   max_lag, format(vd, "%Y-%m-%d"), format(econ_vd, "%Y-%m-%d"), lag_days))
    }

    gdp_match <- econ[econ$vintage_date == econ_vd & econ$year == hy, ]
    if (nrow(gdp_match) == 0) {
      stop(sprintf("No GDP value at horizon year %d in econ vintage %s",
                   hy, format(econ_vd, "%Y-%m-%d")))
    }
    decomp$projected_gdp_bn[i] <- gdp_match$gdp_bn[1]
    decomp$econ_vintage_used[i] <- econ_vd
  }

  # ---- 2. Compute legislative delta(debt/GDP) in percentage points ----

  # legislative_deficit_5yr_bn is already positive = increases deficit (more debt)
  # Divide by projected GDP to get approximate pp of GDP
  decomp$legislative_delta_debt_gdp <- (decomp$legislative_deficit_5yr_bn /
                                         decomp$projected_gdp_bn) * 100

  if (any(is.na(decomp$legislative_delta_debt_gdp))) {
    stop("Encountered NA legislative_delta_debt_gdp after harmonized computation")
  }

  # Use all parsed vintages; strict checks above guarantee completeness.
  panel <- decomp
  panel <- panel[order(panel$vintage_date), ]

  if (nrow(panel) == 0) {
    stop("No valid legislative decomposition + GDP pairs found")
  }

  message(sprintf("  Panel: %d vintages with fiscal-policy delta(debt/GDP)",
                  nrow(panel)))

  # ---- 3. Compute cumulative sums for each scenario ----

  scenarios <- config$scenarios
  if (is.null(scenarios)) {
    # Default scenarios
    scenarios <- list(
      since_2015 = list(start_vintage = "2015-08-01", label = "Since 2015"),
      since_2022 = list(start_vintage = "2022-05-01", label = "Since 2022")
    )
  }

  for (scenario_name in names(scenarios)) {
    start_date <- as.Date(scenarios[[scenario_name]]$start_vintage)
    col_name <- paste0("cumulative_", gsub("^since_", "since_", scenario_name))
    panel[[col_name]] <- NA_real_

    in_window <- panel$vintage_date >= start_date
    if (any(in_window)) {
      panel[[col_name]][in_window] <- cumsum(
        panel$legislative_delta_debt_gdp[in_window]
      )
    } else {
      stop(sprintf("Scenario '%s' has no vintages at/after start date %s",
                   scenario_name, start_date))
    }
  }

  # ---- 4. Report summary ----

  latest <- tail(panel, 1)
  message(sprintf("  Latest vintage: %s (since %s)",
                  format(latest$vintage_date, "%b %Y"),
                  format(latest$since_date, "%b %Y")))
  message(sprintf("  Latest harmonized fiscal-policy deficit (%dyr window): $%.1fB",
                  horizon,
                  latest$legislative_deficit_5yr_bn))
  message(sprintf("  Latest fiscal-policy delta(debt/GDP): %+.2f pp",
                  latest$legislative_delta_debt_gdp))

  for (scenario_name in names(scenarios)) {
    col_name <- paste0("cumulative_", gsub("^since_", "since_", scenario_name))
    latest_cum <- tail(panel[!is.na(panel[[col_name]]), ], 1)
    if (nrow(latest_cum) > 0) {
      message(sprintf("  Cumulative %s: %+.2f pp",
                      scenarios[[scenario_name]]$label,
                      latest_cum[[col_name]]))
    }
  }

  # Select and order output columns
  base_cols <- c(
    "vintage_date", "since_date", "horizon_year",
    "legislative_deficit_5yr_bn", "legislative_deficit_window_bn",
    "harmonized_years", "reported_window_label", "reported_window_span_years",
    "projected_gdp_bn", "econ_vintage_used", "legislative_delta_debt_gdp",
    "sheet_name"
  )
  cumulative_cols <- grep("^cumulative_", names(panel), value = TRUE)
  out_cols <- c(base_cols, cumulative_cols)
  out_cols <- out_cols[out_cols %in% names(panel)]
  panel <- panel[, out_cols]

  panel
}


save_dataset <- function(panel, output_dir) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  write.csv(panel, file.path(output_dir, "projection_vintage_panel.csv"),
            row.names = FALSE)
  message(sprintf("  Saved panel to %s",
                  file.path(output_dir, "projection_vintage_panel.csv")))
  invisible(output_dir)
}
