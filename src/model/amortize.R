# amortize.R — Translate rate effects into household cost impacts
#
# Takes the fiscal contribution (in basis points) and computes
# the change in annual loan payments for each loan type.

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
      auto           = "auto_5yr",
      small_business = "small_business_5yr"
    )

    pt <- passthrough[[pt_name]] %||% 1.0

    # Rate change for this loan type (in basis points)
    rate_change_bps <- list(
      preferred = fiscal$rate_effect$preferred * pt,
      low       = fiscal$rate_effect$low * pt,
      high      = fiscal$rate_effect$high * pt
    )

    # Compute cost impacts for each elasticity scenario
    scenarios <- list()
    for (scenario in c("preferred", "low", "high")) {
      bps <- rate_change_bps[[scenario]]
      baseline_rate <- loan$baseline_rate_pct
      new_rate <- baseline_rate + bps / 100

      baseline_annual <- amortize_annual_payment(
        loan$principal, baseline_rate, loan$term_months
      )
      new_annual <- amortize_annual_payment(
        loan$principal, new_rate, loan$term_months
      )

      baseline_total <- amortize_total_cost(
        loan$principal, baseline_rate, loan$term_months
      )
      new_total <- amortize_total_cost(
        loan$principal, new_rate, loan$term_months
      )

      scenarios[[scenario]] <- list(
        rate_change_bps  = bps,
        rate_change_pp   = bps / 100,
        baseline_rate    = baseline_rate,
        new_rate         = new_rate,
        baseline_annual  = baseline_annual,
        new_annual       = new_annual,
        annual_impact    = new_annual - baseline_annual,
        baseline_total   = baseline_total,
        new_total        = new_total,
        lifetime_impact  = new_total - baseline_total
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
    message(sprintf("    Rate: %.2f%% -> %.2f%% (%+.0f bp)",
                    pref$baseline_rate, pref$new_rate, pref$rate_change_bps))
    message(sprintf("    Annual payment: $%s -> $%s (%s$%s/year)",
                    format_dollars(pref$baseline_annual),
                    format_dollars(pref$new_annual),
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
        loan_type        = c$label,
        scenario         = scenario,
        principal        = c$principal,
        term_months      = c$term_months,
        passthrough      = c$passthrough,
        baseline_rate    = s$baseline_rate,
        new_rate         = s$new_rate,
        rate_change_bps  = s$rate_change_bps,
        baseline_annual  = round(s$baseline_annual, 0),
        new_annual       = round(s$new_annual, 0),
        annual_impact    = round(s$annual_impact, 0),
        lifetime_impact  = round(s$lifetime_impact, 0),
        stringsAsFactors = FALSE
      )
    }
  }

  do.call(rbind, rows)
}
