# build_dataset.R — Merge CBO data sources into projection vintage panel
#
# Data priority:
#   1. CBO Excel Budget Projections (2019+): authoritative debt/GDP directly
#   2. CBO GitHub baselines.csv + ALFRED-vintaged NGDPPOT (pre-2019): computed debt/GDP
#   3. CBO Excel Economic Projections GDP: used for validation
#
# Output: data.frame with columns:
#   vintage_date, horizon_year, debt_gdp_pct, debt_gdp_source, delta_debt_gdp

library(dplyr)

build_dataset <- function(cbo_github, fred_results, cbo_excel, config) {

  horizon <- config$projection_horizon %||% 5
  message("Building projection vintage panel...")

  # ---- 1. Excel-derived debt/GDP (authoritative, 2019+) ----

  excel_panel <- NULL
  if (!is.null(cbo_excel$budget_vintages) && nrow(cbo_excel$budget_vintages) > 0) {
    ev <- cbo_excel$budget_vintages

    # For each vintage, extract the value at the projection horizon
    ev <- ev %>%
      mutate(
        vintage_year = as.integer(format(vintage_date, "%Y")),
        years_ahead  = year - vintage_year
      )

    excel_at_horizon <- ev %>%
      filter(years_ahead == horizon) %>%
      select(vintage_date, year, debt_gdp_pct) %>%
      rename(horizon_year = year) %>%
      mutate(debt_gdp_source = "CBO Excel") %>%
      arrange(vintage_date)

    if (nrow(excel_at_horizon) > 0) {
      excel_panel <- excel_at_horizon
      message(sprintf("  Excel panel: %d vintages with debt/GDP at %d-year horizon",
                      nrow(excel_panel), horizon))
    }
  }

  # ---- 2. GitHub-derived debt/GDP with ALFRED-vintaged NGDPPOT (pre-Excel) ----

  github_panel <- NULL
  if (!is.null(cbo_github$debt_at_horizon) && nrow(cbo_github$debt_at_horizon) > 0) {

    dh <- cbo_github$debt_at_horizon
    dh$horizon_year <- as.integer(dh$horizon_year)

    # Determine which GitHub vintages are NOT covered by Excel
    if (!is.null(excel_panel) && nrow(excel_panel) > 0) {
      excel_dates <- excel_panel$vintage_date
      earliest_excel <- min(excel_dates)

      # Only process GitHub vintages that predate the Excel coverage
      pre_excel <- dh[dh$vintage_date < earliest_excel - 60, ]
      message(sprintf("  GitHub vintages before Excel coverage: %d (before %s)",
                      nrow(pre_excel), format(earliest_excel, "%b %Y")))
    } else {
      pre_excel <- dh
      message(sprintf("  GitHub vintages (no Excel available): %d", nrow(pre_excel)))
    }

    if (nrow(pre_excel) > 0) {
      # Fetch ALFRED-vintaged NGDPPOT for each pre-Excel vintage
      alfred_result <- tryCatch({
        fetch_alfred_ngdppot(config, unique(pre_excel$vintage_date))
      }, error = function(e) {
        message(sprintf("  ALFRED fetch failed: %s", e$message))
        list(data = data.frame(), dependencies = data.frame())
      })

      if (nrow(alfred_result$data) > 0) {
        # For each GitHub vintage, look up the NGDPPOT at the horizon year
        # from the matching ALFRED vintage
        pre_excel <- merge(
          pre_excel,
          alfred_result$data[, c("vintage_date", "year", "ngdppot")],
          by.x = c("vintage_date", "horizon_year"),
          by.y = c("vintage_date", "year"),
          all.x = TRUE
        )

        pre_excel$debt_gdp_pct <- (pre_excel$debt_bn / pre_excel$ngdppot) * 100

        github_panel <- pre_excel %>%
          filter(!is.na(debt_gdp_pct)) %>%
          select(vintage_date, horizon_year, debt_gdp_pct) %>%
          mutate(debt_gdp_source = "GitHub+ALFRED") %>%
          arrange(vintage_date)

        message(sprintf("  GitHub+ALFRED panel: %d vintages with debt/GDP",
                        nrow(github_panel)))
      } else {
        # Fallback: use CBO Excel Economic Projections GDP if available
        github_panel <- try_econ_gdp_fallback(pre_excel, cbo_excel, horizon)
      }
    }
  }

  # ---- 3. Validate Excel debt/GDP against Economic Projections GDP ----

  if (!is.null(excel_panel) && !is.null(cbo_excel$econ_vintages) &&
      nrow(cbo_excel$econ_vintages) > 0) {
    validate_debt_gdp(excel_panel, cbo_excel, cbo_github, horizon)
  }

  # ---- 4. Merge panels ----

  if (!is.null(github_panel) && !is.null(excel_panel)) {
    panel <- rbind(github_panel, excel_panel) %>% arrange(vintage_date)
  } else if (!is.null(excel_panel)) {
    panel <- excel_panel
  } else if (!is.null(github_panel)) {
    panel <- github_panel
  } else {
    stop("No debt/GDP data available from either Excel or GitHub+ALFRED sources")
  }

  # ---- 5. Compute deltas between consecutive vintages ----

  panel <- panel %>%
    arrange(vintage_date) %>%
    mutate(
      prev_debt_gdp  = lag(debt_gdp_pct),
      delta_debt_gdp = debt_gdp_pct - prev_debt_gdp,
      prev_vintage   = lag(vintage_date),
      months_between = as.numeric(difftime(vintage_date, prev_vintage,
                                           units = "days")) / 30.44
    )

  message(sprintf("  Final panel: %d vintages, %s to %s",
                  nrow(panel),
                  min(panel$vintage_date, na.rm = TRUE),
                  max(panel$vintage_date, na.rm = TRUE)))

  # Report the most recent delta
  latest <- tail(panel[!is.na(panel$delta_debt_gdp), ], 1)
  if (nrow(latest) > 0) {
    message(sprintf("  Latest delta: %+.1f pp (%s to %s, %d-year horizon)",
                    latest$delta_debt_gdp,
                    format(latest$prev_vintage, "%b %Y"),
                    format(latest$vintage_date, "%b %Y"),
                    horizon))
  }

  panel
}


# ---- Helpers ----

try_econ_gdp_fallback <- function(pre_excel, cbo_excel, horizon) {
  # If ALFRED fails, try using Economic Projections GDP as denominator
  if (is.null(cbo_excel$econ_vintages) || nrow(cbo_excel$econ_vintages) == 0) {
    message("  No ALFRED or Economic Projections GDP available for pre-Excel vintages")
    return(NULL)
  }

  message("  Attempting Economic Projections GDP fallback for pre-Excel vintages...")

  econ <- cbo_excel$econ_vintages
  # Match by closest vintage date
  for (i in seq_len(nrow(pre_excel))) {
    vd <- pre_excel$vintage_date[i]
    hy <- pre_excel$horizon_year[i]

    # Find closest econ vintage within 90 days
    date_diffs <- abs(as.numeric(econ$vintage_date - vd))
    close_econ <- econ[date_diffs < 90 & econ$year == hy, ]

    if (nrow(close_econ) > 0) {
      pre_excel$gdp_bn_econ[i] <- close_econ$gdp_bn[1]
    }
  }

  if ("gdp_bn_econ" %in% names(pre_excel)) {
    pre_excel$debt_gdp_pct <- (pre_excel$debt_bn / pre_excel$gdp_bn_econ) * 100

    result <- pre_excel %>%
      filter(!is.na(debt_gdp_pct)) %>%
      select(vintage_date, horizon_year, debt_gdp_pct) %>%
      mutate(debt_gdp_source = "GitHub+EconExcel") %>%
      arrange(vintage_date)

    if (nrow(result) > 0) {
      message(sprintf("  Econ GDP fallback: %d vintages", nrow(result)))
      return(result)
    }
  }

  NULL
}


validate_debt_gdp <- function(excel_panel, cbo_excel, cbo_github, horizon) {
  # Cross-check Excel debt/GDP against computed debt/GDP from
  # GitHub debt ÷ Economic Projections GDP
  econ <- cbo_excel$econ_vintages
  if (is.null(cbo_github$debt_at_horizon) ||
      nrow(cbo_github$debt_at_horizon) == 0) return(invisible(NULL))

  dh <- cbo_github$debt_at_horizon

  for (i in seq_len(nrow(excel_panel))) {
    vd <- excel_panel$vintage_date[i]
    hy <- excel_panel$horizon_year[i]
    excel_val <- excel_panel$debt_gdp_pct[i]

    # Find matching GitHub debt
    gh_match <- dh[abs(as.numeric(dh$vintage_date - vd)) < 60, ]
    if (nrow(gh_match) == 0) next
    debt_bn <- gh_match$debt_bn[1]

    # Find matching econ GDP
    econ_match <- econ[abs(as.numeric(econ$vintage_date - vd)) < 60 &
                       econ$year == hy, ]
    if (nrow(econ_match) == 0) next
    gdp_bn <- econ_match$gdp_bn[1]

    computed <- (debt_bn / gdp_bn) * 100
    diff <- excel_val - computed

    if (abs(diff) > 2.0) {
      message(sprintf("  VALIDATION WARNING: %s debt/GDP — Excel: %.1f%%, computed: %.1f%% (diff: %+.1f pp)",
                      format(vd, "%b %Y"), excel_val, computed, diff))
    }
  }

  invisible(NULL)
}


save_dataset <- function(panel, output_dir) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  write.csv(panel, file.path(output_dir, "projection_vintage_panel.csv"),
            row.names = FALSE)
  message(sprintf("  Saved panel to %s",
                  file.path(output_dir, "projection_vintage_panel.csv")))
  invisible(output_dir)
}
