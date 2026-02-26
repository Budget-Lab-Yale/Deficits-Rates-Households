# Interactive Household Cost Calculator — Implementation Spec

## Overview

The calculator shows how federal fiscal policy has raised borrowing costs for
three loan types. Users adjust principal amounts; rate effects are fixed outputs
from the pipeline.

## Fixed Inputs (from pipeline — not user-adjustable)

### Rate Effects (basis points on 10-year Treasury)

| Scenario | 10yr Δ (bp) | Low | High |
|----------|-------------|-----|------|
| Since 2015 | 97 | 73 | 146 |
| Since 2022 | 18 | 14 | 27 |

### Loan Parameters

| Loan | Term (months) | Observed Rate (%) | Pass-through |
|------|---------------|-------------------|--------------|
| Mortgage (30-yr) | 360 | 6.23 | 1.00 |
| Auto (5½-yr) | 67 | 7.51 | 0.50 |
| Small Business (5-yr) | 60 | 7.00 | 0.25 |

### Default Principal Amounts

| Loan | Default | Derivation |
|------|---------|------------|
| Mortgage | $329,840 | Median home price $412,300 × 80% (20% down payment) |
| Auto | $42,332 | Average new-vehicle loan balance |
| Small Business | $663,000 | Average SBA loan size |

**Sourcing detail:**

- **Mortgage:** Median existing-home sale price from FRED series HOSMEDUSM052N
  (Sep 2025 = $412,300). Convention is 20% down, so principal = $412,300 × 0.80.
  Observed rate from Freddie Mac Primary Mortgage Market Survey (PMMS),
  week of Nov 26, 2025 (FRED series MORTGAGE30US).
- **Auto:** Average new-vehicle loan amount from Experian State of the
  Automotive Finance Market, Q3 2025. Observed rate from FRED series
  TERMCBAUTO48NS (48-month new-car rate, Q3 2025). Term is 67 months
  (5½ years), matching Experian's reported average new-vehicle loan term.
- **Small Business:** Average SBA 7(a) loan size from B2BReview/SBA, 2024
  (no 2025 update available at time of writing). Observed rate is the
  prime rate from FRED series DPRIME (Nov 2025) + typical SBA spread.
  Term is 60 months (5 years), a common SBA working-capital term.

For mortgage, the UI could accept a **home value** and apply 80% internally,
or just accept the loan amount directly — implementer's choice.

## User Inputs

For each loan type, the user sets the **principal** (or home value for mortgage).
Everything else is fixed.

## Math

There is one formula. For each loan type:

### 1. Compute the rate effect for this loan

```
rate_effect_pp = (ten_year_delta_bp × passthrough) / 100
```

Example (mortgage, since 2015): `(97 × 1.00) / 100 = 0.97 pp`

### 2. Derive the counterfactual rate

The observed rate already includes the fiscal effect. The counterfactual is what
the rate would be without it:

```
counterfactual_rate = observed_rate - rate_effect_pp
```

Example: `6.23 - 0.97 = 5.26%`

### 3. Amortize both rates

Standard fixed-rate amortization. Monthly payment:

```
M = P × r(1 + r)^n / ((1 + r)^n - 1)
```

where:
- `P` = principal (user input)
- `r` = annual rate / 12 / 100 (monthly decimal rate)
- `n` = term in months

Edge case: if `r ≤ 0`, monthly payment is simply `P / n`.

### 4. Compute impacts

```
annual_payment   = M × 12
lifetime_cost    = M × n
annual_impact    = annual_observed - annual_counterfactual
lifetime_impact  = lifetime_observed - lifetime_counterfactual
```

### Pseudocode

```
function monthly_payment(principal, annual_rate_pct, term_months):
    if annual_rate_pct <= 0:
        return principal / term_months
    r = annual_rate_pct / 100 / 12
    n = term_months
    return principal * r * (1 + r)^n / ((1 + r)^n - 1)

function compute_impact(principal, observed_rate, passthrough, delta_bp, term_months):
    rate_effect    = delta_bp * passthrough / 100
    cf_rate        = observed_rate - rate_effect
    M_observed     = monthly_payment(principal, observed_rate, term_months)
    M_counterfactual = monthly_payment(principal, cf_rate, term_months)
    return {
        observed_rate:        observed_rate,
        counterfactual_rate:  cf_rate,
        rate_effect_bp:       delta_bp * passthrough,
        annual_observed:      M_observed * 12,
        annual_counterfactual: M_counterfactual * 12,
        annual_impact:        (M_observed - M_counterfactual) * 12,
        lifetime_observed:    M_observed * term_months,
        lifetime_counterfactual: M_counterfactual * term_months,
        lifetime_impact:      (M_observed - M_counterfactual) * term_months,
    }
```

## Validation

With the default principals and the "Since 2015" scenario, these results should match:

| Loan | Rate Effect | Annual Impact | Lifetime Impact |
|------|-------------|---------------|-----------------|
| Mortgage | +97 bp | +$2,439/yr | +$73,182 |
| Auto | +49 bp | +$118/yr | +$659 |
| Small Business | +24 bp | +$909/yr | +$4,546 |
