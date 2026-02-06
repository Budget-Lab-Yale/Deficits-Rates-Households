# build_dataset.R — Build legislative decomposition panel
#
# Uses CBO Table A-1 (or equivalent) legislative deficit components
# and CBO Economic Projections GDP to compute legislative delta(debt/GDP).
#
# Output: data.frame with columns:
#   vintage_date, since_date, legislative_deficit_5yr_bn, projected_gdp_bn,
#   legislative_delta_debt_gdp, cumulative_since_2015, cumulative_since_2022

library(dplyr)

build_dataset <- function(cbo_excel, config) {

  horizon <- config$projection_horizon %||% 5
  message("Building legislative decomposition panel...")

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
  decomp$horizon_year <- decomp$vintage_year + horizon

  # Match each decomp vintage to the nearest econ vintage (within 180 days)
  decomp$projected_gdp_bn <- NA_real_
  decomp$econ_vintage_used <- as.Date(NA)

  for (i in seq_len(nrow(decomp))) {
    vd <- decomp$vintage_date[i]
    hy <- decomp$horizon_year[i]

    # Find closest econ vintage
    econ_vintages <- unique(econ$vintage_date)
    date_diffs <- abs(as.numeric(difftime(econ_vintages, vd, units = "days")))
    closest_idx <- which.min(date_diffs)

    if (length(closest_idx) == 0 || date_diffs[closest_idx] > 180) {
      message(sprintf("  WARNING: No econ vintage within 180 days of %s",
                      format(vd, "%b %Y")))
      next
    }

    econ_vd <- econ_vintages[closest_idx]
    gdp_match <- econ[econ$vintage_date == econ_vd & econ$year == hy, ]

    if (nrow(gdp_match) > 0) {
      decomp$projected_gdp_bn[i] <- gdp_match$gdp_bn[1]
      decomp$econ_vintage_used[i] <- econ_vd
    } else {
      # Try horizon_year +/- 1 if exact year not available
      gdp_near <- econ[econ$vintage_date == econ_vd &
                        abs(econ$year - hy) <= 1, ]
      if (nrow(gdp_near) > 0) {
        # Use the closest year
        gdp_near <- gdp_near[which.min(abs(gdp_near$year - hy)), ]
        decomp$projected_gdp_bn[i] <- gdp_near$gdp_bn[1]
        decomp$econ_vintage_used[i] <- econ_vd
        message(sprintf("  Note: Using GDP for %d (not %d) from %s econ vintage",
                        gdp_near$year, hy, format(econ_vd, "%b %Y")))
      } else {
        message(sprintf("  WARNING: No GDP at horizon year %d from %s econ vintage",
                        hy, format(econ_vd, "%b %Y")))
      }
    }
  }

  # ---- 2. Compute legislative delta(debt/GDP) in percentage points ----

  # legislative_deficit_5yr_bn is already positive = increases deficit (more debt)
  # Divide by projected GDP to get approximate pp of GDP
  decomp$legislative_delta_debt_gdp <- (decomp$legislative_deficit_5yr_bn /
                                         decomp$projected_gdp_bn) * 100

  # Filter to vintages with valid data
  panel <- decomp[!is.na(decomp$legislative_delta_debt_gdp), ]
  panel <- panel[order(panel$vintage_date), ]

  if (nrow(panel) == 0) {
    stop("No valid legislative decomposition + GDP pairs found")
  }

  message(sprintf("  Panel: %d vintages with legislative delta(debt/GDP)",
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

  panel$cumulative_since_2015 <- NA_real_
  panel$cumulative_since_2022 <- NA_real_

  for (scenario_name in names(scenarios)) {
    start_date <- as.Date(scenarios[[scenario_name]]$start_vintage)
    col_name <- paste0("cumulative_", gsub("^since_", "since_", scenario_name))

    in_window <- panel$vintage_date >= start_date
    if (any(in_window)) {
      panel[[col_name]][in_window] <- cumsum(
        panel$legislative_delta_debt_gdp[in_window]
      )
    }
  }

  # ---- 4. Report summary ----

  latest <- tail(panel, 1)
  message(sprintf("  Latest vintage: %s (since %s)",
                  format(latest$vintage_date, "%b %Y"),
                  format(latest$since_date, "%b %Y")))
  message(sprintf("  Latest legislative deficit 5yr: $%.1fB",
                  latest$legislative_deficit_5yr_bn))
  message(sprintf("  Latest legislative delta(debt/GDP): %+.2f pp",
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
  out_cols <- c("vintage_date", "since_date", "horizon_year",
                "legislative_deficit_5yr_bn", "projected_gdp_bn",
                "econ_vintage_used", "legislative_delta_debt_gdp",
                "cumulative_since_2015", "cumulative_since_2022",
                "sheet_name")
  # Only include columns that exist
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
