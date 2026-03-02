# Interactive Household Cost Calculator — Implementation Spec

## Overview

The calculator shows how federal fiscal policy has raised borrowing costs for
three loan types. Users adjust principal amounts; rate effects are fixed outputs
from the pipeline.

## Fixed Inputs (from pipeline — not user-adjustable)

The calculator's central scenario uses a debt-to-rates sensitivity of `2 bp/pp`
from Neveu & Schafer (2024). The displayed low and high values use `1.5 bp/pp`
(Furceri et al. 2025) and `3 bp/pp` (Plante et al. 2025), respectively.

### Rate Effects (basis points on 10-year Treasury)

| Scenario | Central (2 bp/pp) | Low (1.5 bp/pp) | High (3 bp/pp) |
|----------|-------------------|-----------------|----------------|
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

We could also allow users to choose the **sensitivity assumption**. For the
basic calculator, that is probably unnecessary if the UI already lets users pick
among the fixed scenario outputs (central, low, high). We can also just fix the
sensitivity to the central value (2) and not expose this functionality.

## Developer Variable Map

Use the variable names below in the implementation so they line up with the
writeup's terminology.

| Writeup term | Suggested variable | What it means | Values |
|--------------|--------------------|---------------|--------|
| 10-year Treasury rate effect | `scenario_treasury_delta_bp` | Scenario-level increase in the 10-year Treasury rate, before loan-specific pass-through | Since 2015: central `97`, low `73`, high `146`; Since 2022: central `18`, low `14`, high `27` |
| Pass-through | `loan_rate_passthrough` | Share of the Treasury effect that reaches the specific loan product | Mortgage `1.00`, Auto `0.50`, Small Business `0.25` |
| Observed Rate (%) | `observed_rate_pct` | Current market rate shown to the user for the product | Mortgage `6.23`, Auto `7.51`, Small Business `7.00` |
| Term (months) | `term_months` | Loan term used in amortization | Mortgage `360`, Auto `67`, Small Business `60` |
| Principal | `principal_dollars` | User-entered loan amount | Defaults: Mortgage `329840`, Auto `42332`, Small Business `663000` |
| Fiscal-policy rate effect (bp) | `loan_rate_effect_bp` | Loan-specific rate effect after applying pass-through | `scenario_treasury_delta_bp × loan_rate_passthrough` |
| Fiscal-policy rate effect (pp) | `loan_rate_effect_pp` | Same loan-specific rate effect, converted from basis points to percentage points | `loan_rate_effect_bp / 100` |
| Counterfactual rate | `counterfactual_rate_pct` | Product rate absent the fiscal-policy effect | `observed_rate_pct - loan_rate_effect_pp` |

The key implementation point is that the writeup's "rate effect" is a
two-step concept:

1. Start with the scenario-wide Treasury effect: `scenario_treasury_delta_bp`
2. Apply product pass-through: `loan_rate_effect_bp = scenario_treasury_delta_bp × loan_rate_passthrough`

## Math

For each loan type:

### 1. Compute the loan-specific rate effect

```
loan_rate_effect_bp = scenario_treasury_delta_bp × loan_rate_passthrough
loan_rate_effect_pp = loan_rate_effect_bp / 100
```

Example (mortgage, since 2015 central): `(97 × 1.00) / 100 = 0.97 pp`

### 2. Derive the counterfactual rate

The observed rate already includes the fiscal effect. The counterfactual is what
the rate would be without it:

```
counterfactual_rate_pct = observed_rate_pct - loan_rate_effect_pp
```

Example: `6.23 - 0.97 = 5.26%`

### 3. Amortize both rates

Standard fixed-rate amortization. Monthly payment:

```
M = P × r(1 + r)^n / ((1 + r)^n - 1)
```

where:
- `P` = `principal_dollars`
- `r` = annual rate / 12 / 100 (monthly decimal rate)
- `n` = term in months

Edge case: if `r ≤ 0`, monthly payment is simply `P / n`.

### 4. Compute impacts

```
observed_annual_payment        = observed_monthly_payment × 12
counterfactual_annual_payment  = counterfactual_monthly_payment × 12
observed_lifetime_cost         = observed_monthly_payment × n
counterfactual_lifetime_cost   = counterfactual_monthly_payment × n
annual_payment_impact          = observed_annual_payment - counterfactual_annual_payment
lifetime_cost_impact           = observed_lifetime_cost - counterfactual_lifetime_cost
```

### Pseudocode

```
function monthly_payment(principal_dollars, annual_rate_pct, term_months):
    if annual_rate_pct <= 0:
        return principal_dollars / term_months
    r = annual_rate_pct / 100 / 12
    n = term_months
    return principal_dollars * r * (1 + r)^n / ((1 + r)^n - 1)

function compute_loan_impact(
    principal_dollars,
    observed_rate_pct,
    loan_rate_passthrough,
    scenario_treasury_delta_bp,
    term_months
):
    loan_rate_effect_bp = scenario_treasury_delta_bp * loan_rate_passthrough
    loan_rate_effect_pp = loan_rate_effect_bp / 100
    counterfactual_rate_pct = observed_rate_pct - loan_rate_effect_pp

    observed_monthly_payment = monthly_payment(
        principal_dollars,
        observed_rate_pct,
        term_months
    )
    counterfactual_monthly_payment = monthly_payment(
        principal_dollars,
        counterfactual_rate_pct,
        term_months
    )

    return {
        observed_rate_pct: observed_rate_pct,
        counterfactual_rate_pct: counterfactual_rate_pct,
        loan_rate_effect_bp: loan_rate_effect_bp,
        loan_rate_effect_pp: loan_rate_effect_pp,
        observed_annual_payment: observed_monthly_payment * 12,
        counterfactual_annual_payment: counterfactual_monthly_payment * 12,
        annual_payment_impact:
            (observed_monthly_payment - counterfactual_monthly_payment) * 12,
        observed_lifetime_cost: observed_monthly_payment * term_months,
        counterfactual_lifetime_cost:
            counterfactual_monthly_payment * term_months,
        lifetime_cost_impact:
            (observed_monthly_payment - counterfactual_monthly_payment) * term_months,
    }
```

## Validation

With the default principals, these test cases should match exactly:

| Loan | Scenario | Sensitivity | Rate Effect | Annual Impact | Lifetime Impact |
|------|----------|-------------|-------------|---------------|-----------------|
| Mortgage | Since 2015 | Central (2 bp/pp) | +97 bp | +$2,439/yr | +$73,182 |
| Auto | Since 2015 | Central (2 bp/pp) | +49 bp | +$118/yr | +$659 |
| Small Business | Since 2015 | Central (2 bp/pp) | +24 bp | +$909/yr | +$4,546 |
| Mortgage | Since 2022 | Central (2 bp/pp) | +18 bp | +$464/yr | +$13,912 |
| Auto | Since 2022 | Central (2 bp/pp) | +9 bp | +$22/yr | +$123 |
| Small Business | Since 2022 | Central (2 bp/pp) | +5 bp | +$170/yr | +$849 |
| Mortgage | Since 2015 | Low (1.5 bp/pp) | +73 bp | +$1,840/yr | +$55,214 |
| Mortgage | Since 2015 | High (3 bp/pp) | +146 bp | +$3,614/yr | +$108,430 |

With non-default principals, these additional test cases should also match:

| Loan | Principal | Scenario | Sensitivity | Rate Effect | Annual Impact | Lifetime Impact |
|------|-----------|----------|-------------|-------------|---------------|-----------------|
| Mortgage | $500,000 | Since 2015 | Central (2 bp/pp) | +97 bp | +$3,696/yr | +$110,869 |
| Auto | $30,000 | Since 2015 | Central (2 bp/pp) | +49 bp | +$84/yr | +$467 |
| Small Business | $1,000,000 | Since 2015 | Central (2 bp/pp) | +24 bp | +$1,371/yr | +$6,853 |
| Mortgage | $250,000 | Since 2022 | Central (2 bp/pp) | +18 bp | +$349/yr | +$10,483 |
| Auto | $25,000 | Since 2022 | Central (2 bp/pp) | +9 bp | +$13/yr | +$72 |
| Small Business | $500,000 | Since 2022 | Central (2 bp/pp) | +5 bp | +$127/yr | +$637 |
