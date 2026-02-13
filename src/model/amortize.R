# amortize.R — Translate rate effects into household cost impacts
#
# Counterfactual approach: today's observed rate includes the cumulative
# fiscal-policy effect. The counterfactual rate is what borrowers would
# face absent that fiscal impulse. The cost impact is the difference
# between observed and counterfactual payments.

compute_household_costs <- function(fiscal, coefs) {

  message("Computing household cost impacts...")

  loans <- coefs$loans
  passthrough <- coefs$passthrough

  results <- list()

  for (loan_name in names(loans)) {
    loan <- loans[[loan_name]]

    # Get the pass-through name (matching convention)
    pt_name <- switch(loan_name,
      mortgage       = "mortgage_30yr",
      auto           = "auto",
      small_business = "small_business"
    )

    pt <- passthrough[[pt_name]] %||% 1.0

    # Rate change for this loan type (in basis points)
    rate_change_bps <- list(
      preferred = fiscal$rate_effect$preferred * pt,
      low       = fiscal$rate_effect$low * pt,
      high      = fiscal$rate_effect$high * pt
    )

    # Compute cost impacts for each elasticity scenario
    # observed_rate = today's rate (from config, includes fiscal effect)
    # counterfactual_rate = observed - fiscal attribution
    # impact = observed payment - counterfactual payment
    scenarios <- list()
    for (scenario in c("preferred", "low", "high")) {
      bps <- rate_change_bps[[scenario]]
      observed_rate <- loan$baseline_rate_pct
      counterfactual_rate <- observed_rate - bps / 100

      observed_annual <- amortize_annual_payment(
        loan$principal, observed_rate, loan$term_months
      )
      counterfactual_annual <- amortize_annual_payment(
        loan$principal, counterfactual_rate, loan$term_months
      )

      observed_total <- amortize_total_cost(
        loan$principal, observed_rate, loan$term_months
      )
      counterfactual_total <- amortize_total_cost(
        loan$principal, counterfactual_rate, loan$term_months
      )

      scenarios[[scenario]] <- list(
        rate_change_bps      = bps,
        rate_change_pp       = bps / 100,
        observed_rate        = observed_rate,
        counterfactual_rate  = counterfactual_rate,
        observed_annual      = observed_annual,
        counterfactual_annual = counterfactual_annual,
        annual_impact        = observed_annual - counterfactual_annual,
        observed_total       = observed_total,
        counterfactual_total = counterfactual_total,
        lifetime_impact      = observed_total - counterfactual_total,
        # Keep old names as aliases for downstream compatibility
        baseline_rate        = observed_rate,
        new_rate             = counterfactual_rate,
        baseline_annual      = observed_annual,
        new_annual           = counterfactual_annual,
        baseline_total       = observed_total,
        new_total            = counterfactual_total
      )
    }

    results[[loan_name]] <- list(
      label       = loan$label,
      principal   = loan$principal,
      term_months = loan$term_months,
      source      = loan$source,
      passthrough = pt,
      scenarios   = scenarios
    )

    # Print preferred scenario
    pref <- scenarios$preferred
    message(sprintf("  %s:", loan$label))
    message(sprintf("    Observed rate: %.2f%% | Counterfactual (no fiscal): %.2f%% | Fiscal effect: %+.0f bp",
                    pref$observed_rate, pref$counterfactual_rate, pref$rate_change_bps))
    message(sprintf("    Annual payment: $%s vs $%s (%s$%s/year)",
                    format_dollars(pref$observed_annual),
                    format_dollars(pref$counterfactual_annual),
                    ifelse(pref$annual_impact >= 0, "+", "-"),
                    format_dollars(abs(pref$annual_impact))))
    message(sprintf("    Lifetime cost: %s$%s",
                    ifelse(pref$lifetime_impact >= 0, "+", "-"),
                    format_dollars(abs(pref$lifetime_impact))))
  }

  results
}


# Flatten household costs into a summary data.frame
household_costs_table <- function(costs) {
  rows <- list()

  for (loan_name in names(costs)) {
    c <- costs[[loan_name]]
    for (scenario in c("preferred", "low", "high")) {
      s <- c$scenarios[[scenario]]
      rows[[length(rows) + 1]] <- data.frame(
        loan_type            = c$label,
        scenario             = scenario,
        principal            = c$principal,
        term_months          = c$term_months,
        passthrough          = c$passthrough,
        observed_rate        = s$observed_rate,
        counterfactual_rate  = s$counterfactual_rate,
        rate_change_bps      = s$rate_change_bps,
        observed_annual      = round(s$observed_annual, 0),
        counterfactual_annual = round(s$counterfactual_annual, 0),
        annual_impact        = round(s$annual_impact, 0),
        lifetime_impact      = round(s$lifetime_impact, 0),
        stringsAsFactors     = FALSE
      )
    }
  }

  do.call(rbind, rows)
}
