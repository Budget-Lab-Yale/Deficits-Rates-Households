# fiscal_contribution.R — Apply published elasticities to compute fiscal rate effects
#
# Core formula:
#   Δ(rate) = Δ(projected debt/GDP) × elasticity (bp per pp)
#
# Decomposition:
#   ~75% through term premium (Plante et al. 2025)
#   ~25% through expected short-term rates
#
# Pass-through to consumer rates varies by loan type.

compute_fiscal_contribution <- function(panel, coefs) {

  message("Computing fiscal contribution to interest rates...")

  # Get the two most recent vintages with valid deltas
  valid <- panel[!is.na(panel$delta_debt_gdp), ]
  if (nrow(valid) == 0) {
    stop("No valid delta(debt/GDP) values in the panel")
  }

  latest <- tail(valid, 1)
  delta_debt_gdp <- latest$delta_debt_gdp  # in percentage points

  # Elasticities
  elasticity   <- coefs$elasticity
  tp_share     <- coefs$term_premium_share
  passthrough  <- coefs$passthrough

  # Compute rate effects (in basis points)
  rate_effect <- list(
    preferred = delta_debt_gdp * elasticity$preferred,
    low       = delta_debt_gdp * elasticity$low,
    high      = delta_debt_gdp * elasticity$high
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
    vintage_from   = latest$prev_vintage,
    vintage_to     = latest$vintage_date,
    horizon_year   = latest$horizon_year,
    delta_debt_gdp = delta_debt_gdp,
    debt_gdp_from  = latest$prev_debt_gdp,
    debt_gdp_to    = latest$debt_gdp_pct,
    elasticity     = elasticity,
    rate_effect    = rate_effect,
    tp_effect      = tp_effect,
    exp_rate_effect = exp_rate_effect,
    consumer_rates = consumer_rates,
    passthrough    = passthrough,
    tp_share       = tp_share
  )

  # Print summary
  message(sprintf("\n  Projection vintage: %s -> %s",
                  format(result$vintage_from, "%b %Y"),
                  format(result$vintage_to, "%b %Y")))
  message(sprintf("  Horizon year: %d", result$horizon_year))
  message(sprintf("  Debt/GDP: %.1f%% -> %.1f%% (%+.1f pp)",
                  result$debt_gdp_from, result$debt_gdp_to, delta_debt_gdp))
  message(sprintf("  Rate effect (preferred): %+.0f bp (range: %+.0f to %+.0f)",
                  rate_effect$preferred, rate_effect$low, rate_effect$high))
  message(sprintf("    Term premium: %+.0f bp", tp_effect$preferred))
  message(sprintf("    Expected short rate: %+.0f bp", exp_rate_effect$preferred))

  for (loan_name in names(consumer_rates)) {
    cr <- consumer_rates[[loan_name]]
    message(sprintf("  %s: %+.0f bp (passthrough: %.0f%%)",
                    loan_name, cr$preferred, passthrough[[loan_name]] * 100))
  }

  result
}


# Compute the full historical time series of fiscal contributions
compute_historical_contributions <- function(panel, coefs) {
  # For each vintage pair in the panel, compute the rate effect.
  # Returns data.frame with vintage dates and cumulative fiscal contribution.

  valid <- panel[!is.na(panel$delta_debt_gdp), ]
  if (nrow(valid) == 0) return(NULL)

  elasticity <- coefs$elasticity$preferred

  contributions <- valid %>%
    mutate(
      rate_effect_bp = delta_debt_gdp * elasticity,
      cumulative_bp  = cumsum(rate_effect_bp)
    ) %>%
    select(vintage_date, horizon_year, debt_gdp_pct, delta_debt_gdp,
           rate_effect_bp, cumulative_bp)

  contributions
}
