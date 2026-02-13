# fiscal_contribution.R — Apply published elasticities to compute fiscal rate effects
#
# Core formula:
#   Δ(rate) = cumulative legislative Δ(debt/GDP) × elasticity (bp per pp)
#
# Decomposition:
#   ~75% through term premium (Plante et al. 2025)
#   ~25% through expected short-term rates
#
# Pass-through to consumer rates varies by loan type.
#
# Two scenarios: cumulative since 2015 and cumulative since 2022.

compute_fiscal_contribution <- function(panel, coefs, config) {

  message("Computing fiscal contribution to interest rates...")

  # Get elasticities and pass-through coefficients
  elasticity   <- coefs$elasticity
  tp_share     <- coefs$term_premium_share
  passthrough  <- coefs$passthrough

  scenarios <- config$scenarios
  if (is.null(scenarios)) {
    scenarios <- list(
      since_2015 = list(start_vintage = "2015-08-01", label = "Since 2015"),
      since_2022 = list(start_vintage = "2022-05-01", label = "Since 2022")
    )
  }

  results <- list()

  for (scenario_name in names(scenarios)) {
    col_name <- paste0("cumulative_", gsub("^since_", "since_", scenario_name))
    label <- scenarios[[scenario_name]]$label

    # Get the latest cumulative value for this scenario
    valid <- panel[!is.na(panel[[col_name]]), ]
    if (nrow(valid) == 0) {
      message(sprintf("  %s: no data available", label))
      next
    }

    latest <- tail(valid, 1)
    cumulative_delta <- latest[[col_name]]

    # Compute rate effects (in basis points)
    rate_effect <- list(
      preferred = cumulative_delta * elasticity$preferred,
      low       = cumulative_delta * elasticity$low,
      high      = cumulative_delta * elasticity$high
    )

    # Decompose into term premium and expected short rate
    tp_effect <- list(
      preferred = rate_effect$preferred * tp_share,
      low       = rate_effect$low * tp_share,
      high      = rate_effect$high * tp_share
    )

    exp_rate_effect <- list(
      preferred = rate_effect$preferred * (1 - tp_share),
      low       = rate_effect$low * (1 - tp_share),
      high      = rate_effect$high * (1 - tp_share)
    )

    # Pass-through to consumer rates
    consumer_rates <- list()
    for (loan_name in names(passthrough)) {
      pt <- passthrough[[loan_name]]
      consumer_rates[[loan_name]] <- list(
        preferred = rate_effect$preferred * pt,
        low       = rate_effect$low * pt,
        high      = rate_effect$high * pt
      )
    }

    result <- list(
      scenario_name       = scenario_name,
      scenario_label      = label,
      start_vintage       = as.Date(scenarios[[scenario_name]]$start_vintage),
      latest_vintage      = latest$vintage_date,
      horizon_year        = latest$horizon_year,
      cumulative_delta    = cumulative_delta,
      n_vintages          = nrow(valid),
      elasticity          = elasticity,
      rate_effect         = rate_effect,
      tp_effect           = tp_effect,
      exp_rate_effect     = exp_rate_effect,
      consumer_rates      = consumer_rates,
      passthrough         = passthrough,
      tp_share            = tp_share
    )

    results[[scenario_name]] <- result

    # Print summary
    message(sprintf("\n  %s (cumulative over %d vintages):", label, nrow(valid)))
    message(sprintf("  Cumulative fiscal-policy Δ(debt/GDP): %+.2f pp", cumulative_delta))
    message(sprintf("  Rate effect (preferred): %+.0f bp (range: %+.0f to %+.0f)",
                    rate_effect$preferred, rate_effect$low, rate_effect$high))
    message(sprintf("    Term premium: %+.0f bp", tp_effect$preferred))
    message(sprintf("    Expected short rate: %+.0f bp", exp_rate_effect$preferred))

    for (loan_name in names(consumer_rates)) {
      cr <- consumer_rates[[loan_name]]
      message(sprintf("  %s: %+.0f bp (passthrough: %.0f%%)",
                      loan_name, cr$preferred, passthrough[[loan_name]] * 100))
    }
  }

  if (length(results) == 0) {
    stop("No fiscal contribution scenarios could be computed")
  }

  results
}


compute_historical_contributions <- function(panel, coefs, config) {
  # Compute the full time series of legislative fiscal contributions for each scenario.
  # Returns a data.frame with per-vintage and cumulative rate effects.

  elasticity <- coefs$elasticity$preferred

  scenarios <- config$scenarios
  if (is.null(scenarios)) {
    scenarios <- list(
      since_2015 = list(start_vintage = "2015-08-01", label = "Since 2015"),
      since_2022 = list(start_vintage = "2022-05-01", label = "Since 2022")
    )
  }

  all_rows <- list()

  for (scenario_name in names(scenarios)) {
    start_date <- as.Date(scenarios[[scenario_name]]$start_vintage)
    label <- scenarios[[scenario_name]]$label
    col_name <- paste0("cumulative_", gsub("^since_", "since_", scenario_name))

    valid <- panel[panel$vintage_date >= start_date &
                   !is.na(panel$legislative_delta_debt_gdp), ]
    if (nrow(valid) == 0) next

    valid <- valid[order(valid$vintage_date), ]

    contributions <- valid %>%
      mutate(
        scenario       = scenario_name,
        scenario_label = label,
        rate_effect_bp = legislative_delta_debt_gdp * elasticity,
        cumulative_bp  = cumsum(rate_effect_bp)
      ) %>%
      select(scenario, scenario_label, vintage_date, horizon_year,
             legislative_deficit_horizon_bn, legislative_delta_debt_gdp,
             rate_effect_bp, cumulative_bp)

    all_rows[[scenario_name]] <- contributions
  }

  if (length(all_rows) == 0) return(NULL)

  result <- do.call(rbind, all_rows)
  rownames(result) <- NULL
  result
}
