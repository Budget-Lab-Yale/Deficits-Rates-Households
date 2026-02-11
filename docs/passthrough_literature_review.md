# Treasury Yield Pass-Through to Consumer Rates: Literature Review

This document summarizes the empirical and institutional relationships between
Treasury yields and consumer lending rates (mortgages, auto loans, small business
loans), with a focus on rules of thumb and pass-through elasticities relevant to
the Laubach-framework pipeline.

## 1. 30-Year Mortgage Rates

### Benchmark: 10-Year Treasury

The 30-year fixed mortgage rate is benchmarked to the **10-year Treasury yield**.
Although the mortgage has a 30-year contractual term, its effective duration is
much shorter (4-7 years for MBS, ~7 years at the loan level) because borrowers
prepay, refinance, or sell. The 10-year Treasury provides the closest duration
match among liquid benchmarks.

### Spread: ~170 bp (normal), volatile in practice

| Metric | Value | Source |
|--------|-------|--------|
| Long-run mean spread (post-GFC) | ~170 bp | First American, FRED |
| 21-year mean (2004-2024) | ~185 bp | Regression analysis |
| Normal range | 150-250 bp | -- |
| QE-era compression | ~120-140 bp | Fannie Mae |
| 2022-2024 widening | 250-300+ bp | Wolf Street, Richmond Fed |

The spread is **not stable** -- it varies with interest rate volatility (MOVE
index), Fed MBS purchase/runoff activity, and yield curve shape.

**Spread decomposition (Fannie Mae):**
- **Primary-secondary spread** (lender margin, g-fees): ~50 bp pre-GFC, ~100 bp post-GFC
- **Secondary spread** (MBS yield over Treasury): ~70 bp during QE, ~140 bp during QT

### Pass-through elasticity: ~1:1

The long-run pass-through from 10-year Treasury yields to mortgage rates is
approximately **1:1**:

- Regression beta = **1.022** (R-squared = 0.89, 2004-2024 data)
- Correlation = **0.94** in levels
- Freddie Mac: 98% of weekly variation explained by 10yr Treasury movements
- Fed FEDS 2012-22: coefficient on long swap rate "close to one"

Short-run pass-through is noisier (spread variation, MBS convexity effects),
but for the purpose of translating a long-run fiscal effect on Treasury yields
into mortgage rate effects, **1:1 is well-supported**.

### Key nuance: spread may widen under fiscal stress

The fiscal forces that raise Treasury yields (higher term premium from debt
supply concerns) could simultaneously widen the MBS-Treasury spread via higher
rate volatility. This means the *total* mortgage rate response could exceed the
1:1 Treasury pass-through during episodes of fiscal stress. Conversely,
spread compression during calm periods could offset some of the effect.

### Sources

- First American Economics: "Mind the Gap" (post-GFC average ~170 bp)
- Fannie Mae Research: "What Determines the Rate on a 30-Year Mortgage?"
- Richmond Fed Economic Brief 2023-27 (yield curve slope and mortgage spreads)
- Dallas Fed (April 2023): interest rate volatility and mortgage spread widening
- NY Fed Staff Report 674: understanding mortgage spreads
- Freddie Mac PMMS Survey methodology
- Hanson, Lucca & Wright (QJE 2021): rate amplification via mortgage refinancing
- BIS Working Paper 532: MBS duration (~4-7 years)

---

## 2. Auto Loan Rates

### Benchmark: 5-Year Treasury

Auto lenders use the **5-year Treasury yield** as their primary benchmark,
matching the average new auto loan term of ~65 months (Minneapolis Fed, 2025).
The Cox Automotive Dealertrack Credit Availability Index explicitly tracks the
auto-rate-to-5yr-Treasury spread as a core metric.

### Spread: ~300 bp for prime bank loans

| Metric | Value | Source |
|--------|-------|--------|
| Prime bank 48-mo new auto over 5yr Treasury | ~300-320 bp | FRED TERMCBAUTO48NS vs DGS5 |
| All-market auto loans over 5yr Treasury | 650-715 bp | Cox Automotive Dealertrack |
| Prime AAA auto ABS over Treasuries | 45-70 bp | JPMorgan, MetLife |

The wide gap between prime bank rates (~300 bp spread) and all-market rates
(~680 bp spread) reflects the inclusion of subprime borrowers, longer terms,
used vehicles, and non-bank lenders in the latter.

### Pass-through from 10-year fiscal effect: ~0.50-0.75

Since the Laubach-framework elasticity (3 bp/pp) is calibrated to the 10-year
rate, converting to an auto loan effect requires accounting for the shorter
duration benchmark:

- **Term premium at 5yr is smaller than at 10yr**, dampening the fiscal effect
- **Nonbank lenders** (~55% of auto origination) weaken monetary policy
  transmission (Chicago Fed WP 2022-27)
- **ABS funding channel** introduces intermediation that can amplify or dampen
  Treasury movements depending on credit market conditions
- OBBBA macro model output suggests auto rates moved ~50% as much as mortgage
  rates, implying a pass-through closer to 0.50

**Reasonable range: 0.50 to 0.75** (relative to 10-year fiscal effect).

### Key finding: auto rates track 5yr Treasury, not fed funds

Cox Automotive documented that auto loan rates *rose* in 2025 even as the Fed
cut the federal funds rate, because the 5-year Treasury yield moved
independently. This confirms that auto rates are a term-structure product,
not a short-rate product.

### Sources

- Minneapolis Fed (2025): "What Drives Consumer Interest Rates?"
- Cox Automotive Dealertrack Credit Availability Index (monthly reports)
- Chicago Fed WP 2022-27 (Elliott et al.): nonbank lending and monetary policy
- OCC Working Paper 2020-03: auto loan yield curve puzzle
- Fed Board FEDS 2024-056: prepayments in auto loans
- MetLife Investment Management: prime auto ABS market
- NAIC Auto ABS Primer

---

## 3. Prime Rate and Small Business Loans

### Prime rate: mechanical function of fed funds rate

The prime rate is set at a **fixed 300 bp spread** over the federal funds rate
target. This convention has held essentially without exception since the early
1990s. Changes occur within one business day of FOMC decisions.

- Current (Feb 2026): fed funds upper bound = 3.75%, prime = 6.75%
- Published by WSJ based on survey of 30 largest banks
- Source: FRED DPRIME, San Francisco Fed

**The prime rate has no direct relationship to longer-term Treasury yields.**
It responds to fiscal policy only insofar as fiscal conditions eventually
change the Fed's policy rate.

### Small business loan markups over prime

Most small business lending is variable-rate and priced off prime:

| Product | Typical Rate | Spread Over Prime |
|---------|:----------:|:-----------------:|
| SBA 7(a), >$350K | Prime + 3.0% max | +3.0% |
| SBA 7(a), $250-350K | Prime + 4.5% max | +4.5% |
| SBA 7(a), $50-250K | Prime + 6.0% max | +6.0% |
| SBA Express | Prime + 4.5-6.5% | +4.5-6.5% |
| Bank line of credit | ~Prime + 1.75-3.0% | +1.75-3.0% |
| Conventional term loan | 6-11.5% | ~+2-5% |

**Exception:** SBA 504 loans (CDC portion) are benchmarked to the **5-year or
10-year Treasury**, not prime. These have near-1:1 Treasury pass-through.

### Pass-through from fiscal effect to prime-linked lending: ~25%

Since the Laubach-framework fiscal effect operates primarily through the
**term premium** (~75%), and the term premium does not directly affect the
fed funds rate or prime, only the **expected short-rate channel** (~25%) passes
through to prime-linked lending:

- Term premium channel (75% of fiscal effect) -> affects long-term fixed rates,
  largely **bypasses** prime-linked lending
- Expected short-rate channel (25%) -> affects prime only if/when the Fed
  actually changes policy rates

This makes the pipeline's current 0.25 pass-through **well-motivated
economically** for variable-rate prime-linked small business products.

**Caveat:** If fiscal concerns eventually force the Fed to raise (or not cut)
the policy rate, the full fiscal effect could eventually reach prime-linked
rates -- but with a long and uncertain lag that the contemporaneous 0.25
coefficient does not capture.

### Sources

- SBA: Terms, Conditions & Eligibility (7(a) program)
- San Francisco Fed: "What is the prime rate?"
- AIIB Working Paper (2019): deficit-to-GDP and private loan spreads (+10 bp per 1 pp)
- Barclays Private Bank (2024): term premium and lending rate transmission
- CEPR VoxEU: loan pricing and monetary policy transmission in the euro area
- Dallas Fed (2023): "Gazing at r-star" (5y5y as proxy for neutral rate)
- TBAC Q4 2023: decomposition of 5y5y forward rate movements

---

## Summary: Pass-Through Parameters

| Consumer Rate | Treasury Benchmark | Spread | Pass-Through from 10yr Fiscal Effect | Current Pipeline Value |
|--------------|:------------------:|:------:|:------------------------------------:|:---------------------:|
| 30yr mortgage | 10yr Treasury | ~170 bp | **~1.0** | 1.00 |
| Auto loan (48-mo bank) | 5yr Treasury | ~300 bp | **~0.50-0.75** | 0.75 |
| Small business (prime-linked) | Fed funds + 3% | varies | **~0.25** | 0.25 |
| SBA 504 (CDC portion) | 5yr/10yr Treasury | ~200 bp | **~0.75-1.0** | not modeled |

The current pipeline values are within the supported range for all three loan
types, though the auto pass-through (0.75) is at the upper end of the
empirical range (0.50-0.75).

## References

- Plante, Richter & Zubairy (2025). Dallas Fed WP 2513.
- Laubach (2009). FEDS 2009-12.
- Neveu & Schafer (2024). CBO Working Paper 2024-05.
- Furceri, Goncalves & Li (2025). IMF WP 2025/142.
- Hanson, Lucca & Wright (2021). QJE 136(3).
- Elliott, Meisenzahl, Peydro & Turner (2022). Chicago Fed WP 2022-27.
- Krishnamurthy & Vissing-Jorgensen (2011). Brookings Papers.
- Minneapolis Fed (2025). "What Drives Consumer Interest Rates?"
- Fannie Mae Research. "What Determines the Rate on a 30-Year Mortgage?"
- Richmond Fed Economic Brief 2023-27.
- Dallas Fed (April 2023). Interest rate volatility and mortgage spreads.
- NY Fed Staff Report 674. Understanding mortgage spreads.
- SBA. Terms, Conditions & Eligibility (7(a) program).
- Cox Automotive. Dealertrack Credit Availability Index (monthly).
