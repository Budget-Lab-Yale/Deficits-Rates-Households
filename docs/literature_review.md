# Literature Review: Deficits, Interest Rates, and Household Costs

This document reviews the empirical literature underlying the
Deficits-Rates-Households pipeline. Part I covers the fiscal elasticity —
how government debt affects long-term interest rates. Part II covers
pass-through — how Treasury yield changes translate to consumer lending
rates. Part III documents the loan parameters used in the household cost
calculation.

---

# Part I: Government Debt and Long-Term Interest Rates

Recent empirical estimates of the elasticity of long-term interest rates with respect to government debt-to-GDP ratios. The consensus range is approximately 2–4 basis points per percentage point of debt/GDP, with newer causal-identification studies finding values at the upper end or above.

## High-Level Takeaway

The findings cluster into three groups. **At the lower end (~2 bp)**, CBO's own estimate (Neveu & Schafer 2024) and a bounded-rationality model (Gust & Skaperdas 2024) use the traditional Laubach levels regression or argue that markets discount far-future debt. **At the center (2–3 bp)**, the IMF (Furceri et al. 2025) and Dallas Fed (Plante et al. 2025) extend Laubach with longer samples and improved econometrics; Plante et al. show that the levels regression has nonstationarity issues and their first-difference fix lands at ~3 bp, while Auerbach & Gale (2025, NBER) adopt 3 bp as their working assumption, suggesting this is becoming the applied consensus. **At the upper end (4.6–5.8 bp)**, Ehrlich et al. (2025) and Salmon (2025) use tighter causal identification and find substantially larger effects; Ehrlich et al. argue the extra effect beyond ~3.5 bp comes from convenience yield erosion as Treasury scarcity declines with growing debt.

The Furceri et al. finding on time variation is particularly notable: the debt-rate elasticity appears to be increasing as fiscal positions worsen, which means the 2 bp estimate from a sample including the fiscally prudent late-1990s/early-2000s may understate the current-environment elasticity. Our preferred estimate of 3 bp/pp (range 2–4) is well-supported and close to the emerging consensus. If anything, the newer causal-identification papers suggest it may be slightly conservative.

---

## Laubach (2009) — Foundational

**Thomas Laubach.** "New Evidence on the Interest Rate Effects of Budget Deficits and Debt." *Journal of the European Economic Association*, 7(4), June 2009.

Regresses forward long-term interest rates on CBO projections of debt/GDP and deficits/GDP, finding approximately 3–4 bp per pp of projected debt/GDP. The use of projections rather than contemporaneous values addresses the endogeneity problem that deficits rise in recessions when rates fall. This paper established the framework that most subsequent work extends.

---

## Neveu & Schafer (2024) — CBO's Updated Estimate

**Andre Neveu, Chad Schafer.** "Revisiting the Relationship Between Debt and Long-Term Interest Rates." CBO Working Paper 2024-05, December 2024. [Link](https://www.cbo.gov/publication/60314)

Extends the CBO's earlier approach (Gamber & Seliski 2019) through 2023, yielding ~2 bp per pp of debt/GDP. Recursive regressions show the estimate has been stable over recent history. CBO revised their operational parameter down from 2.5 to 2.0 bp based on this work. Their theoretical model-based range spans 0.0 to 3.6 bp.

---

## Gust & Skaperdas (2024) — Bounded Rationality

**Christopher Gust, Arsenios Skaperdas.** "Government Debt, Limited Foresight, and Longer-term Interest Rates." FEDS Working Paper 2024-027, May 2024. [Link](https://www.federalreserve.gov/econres/feds/government-debt-limited-foresight-and-longer-term-interest-rates.htm)

Embeds Woodford's bounded-rationality framework into a model of government debt supply and term premia. Finds that limited foresight substantially attenuates the estimated effect of government debt on yields relative to rational expectations benchmarks. Suggests that standard Laubach-type estimates may overstate the contemporaneous yield impact if market participants do not fully internalize far-future debt projections.

---

## Cotton (2024) — High-Frequency Deficit Identification

**Christopher D. Cotton.** "Debt, Deficits, and Interest Rates." *Economica*, 91(363), July 2024, pp. 911–943. [Link](https://onlinelibrary.wiley.com/doi/10.1111/ecca.12521)

Uses high-frequency identification around Monthly Treasury Statements and CBO/OMB forecast releases to isolate the causal effect of deficit surprises on yields. Finds 8.1 bp per pp of deficit/GDP on the 10-year nominal Treasury rate, with the effect operating primarily through higher term premia. Translating from deficit to debt elasticity (assuming deficits cumulate to roughly 3–4x additional debt), the implied debt/GDP elasticity is broadly consistent with the 2–3 bp range.

---

## Plante, Richter & Zubairy (2025) — First-Difference Laubach

**Michael Plante, Alexander Richter, Sarah Zubairy.** "Revisiting the Interest Rate Effects of Federal Debt." Dallas Fed Working Paper 2513 / NBER Working Paper 34018, April 2025 (revised July 2025). [Link](https://www.dallasfed.org/research/papers/2025/wp2513)

Extends the Laubach framework through 2025 and identifies a nonstationarity problem in the levels regression that has become more pronounced with the extended sample. A first-difference specification yields ~3 bp per pp of debt/GDP (5-year-ahead, 5-year Treasury rate) and 13–14 bp per pp of primary deficit/GDP. Approximately three-quarters of the interest rate increase is attributable to higher term premia rather than expected short rates. The authors note their estimate is more than 60% higher than CBO's current 2 bp parameter.

---

## Furceri, Goncalves & Li (2025) — IMF, Time-Varying Effects

**Davide Furceri, Carlos Goncalves, Hongchi Li.** "The Impact of Debt and Deficits on Long-Term Interest Rates in the US." IMF Working Paper 2025/142, July 2025. [Link](https://www.imf.org/en/Publications/WP/Issues/2025/07/11/The-Impact-of-Debt-and-Deficits-on-Long-Term-Interest-Rates-in-the-US-568444)

Extends the Laubach approach over a 50-year sample (1976–2025), finding 2–3 bp per pp of debt/GDP and 20–30 bp per pp of primary deficit/GDP. Effects on term premia are of similar magnitude to effects on overall rates, suggesting fiscal risk compensation is the primary channel. The key contribution is demonstrating that the relationship is time-varying: it was near zero during the period of relative fiscal prudence around 2000 and has been strengthening as fiscal positions deteriorate. This suggests the elasticity may be increasing in the current environment.

---

## Ehrlich, Kay & Thapar (2025) — Causal RD Design

**Gabriel Ehrlich, Owen Kay, Aditi Thapar.** "Public Debt Levels and Real Interest Rates: Causal Evidence from Parliamentary Elections." Dallas Fed Working Paper 2539, November 2025. [Link](https://www.dallasfed.org/research/papers/2025/wp2539)

Uses a cross-country regression discontinuity design around close parliamentary elections as a source of exogenous variation in debt. Finds 5.8 bp per pp of debt/GDP on long-term real interest rates — at the high end of the literature. The authors argue that the traditional crowding-out channel can explain at most 3.5 bp, so the remainder likely stems from lower convenience yields as debt supply grows and Treasuries lose their scarcity-driven premium.

---

## Salmon (2025) — Mercatus, Updated Quarterly Data

**Jack Salmon.** "The Impact of Public Debt on Interest Rates." Mercatus Center Policy Brief, May 2025. [Link](https://www.mercatus.org/research/policy-briefs/impact-public-debt-interest-rates)

Quarterly VAR/OLS using 1985–2024 data yields a baseline estimate of 4.6 bp per pp of debt/GDP, rising to 5.5–6.1 bp with robustness adjustments. Controls for short-term rates, inflation, growth expectations, demographics, and foreign holdings. Argues CBO's 2 bp parameter is 2–3 bp too low, implying nominal 10-year yields of 4.9–5.5% by 2055 rather than CBO's projected 3.8%.

---

## Gomez-Cram, Kung & Lustig (2025) — Event Study, Term Premia

**Roberto Gomez-Cram, Howard Kung, Hanno Lustig.** "Can U.S. Treasury Markets Add and Subtract?" NBER Working Paper 33604, March 2025. [Link](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=5190791)

High-frequency event study around CBO cost estimate releases and legislative events. Finds that after large deficit-increasing proposals, roughly 60% of the rise in long-term nominal yields is attributable to increases in term premia. Confirms that fiscal news moves yields through risk compensation rather than expected policy rates alone.

---

## Bi, Phillot & Zubairy (2025) — Treasury Supply Shocks

**Huixin Bi, Maxime Phillot, Sarah Zubairy.** "Higher Treasury Supply Is Likely to Put Upward Pressure on Interest Rates." KC Fed Economic Bulletin, November 2025. [Link](https://www.kansascityfed.org/research/economic-bulletin/higher-treasury-supply-is-likely-to-put-upward-pressure-on-interest-rates/)

Uses high-frequency identification around Treasury auction announcements (1998–2025). A supply shock that increases debt/GDP by 1% raises 10-year yields by 1.3 bp on impact, peaking at ~2.5 bp a few days later. Effects are strongest at the 5- and 10-year maturities and increase both the long-run equilibrium real rate and inflation expectations, especially during periods of rapid debt growth.

---

## Auerbach & Gale (2025) — Applied Fiscal Projection

**Alan J. Auerbach, William G. Gale.** "Then and Now: A Look Back and Ahead at the Federal Budget." NBER Working Paper 34455, 2025. Forthcoming in *Tax Policy and the Economy*, vol. 40. [Link](https://www.nber.org/papers/w34455)

Not a new econometric estimate, but adopts ~3 bp per pp as the working assumption for a 30-year fiscal projection. Under this assumption and current policy (including OBBBA), debt/GDP reaches 233% by 2054 (vs. 199% without the feedback effect). Signals that 3 bp is becoming the applied consensus for fiscal sustainability analysis.

---

## Elasticity Summary

| Paper | Year | bp/pp (debt/GDP) | Method |
|-------|------|-------------------|--------|
| Laubach | 2009 | 3–4 | Projections regression |
| Neveu & Schafer | 2024 | ~2 | Extended Laubach (CBO) |
| Gust & Skaperdas | 2024 | <2 | Bounded rationality model |
| Cotton | 2024 | ~2–3 (implied) | HF deficit surprises |
| Plante, Richter & Zubairy | 2025 | ~3 | First-difference Laubach |
| Furceri, Goncalves & Li | 2025 | 2–3 | 50-year sample, time-varying |
| Ehrlich, Kay & Thapar | 2025 | 5.8 | Cross-country RD |
| Salmon | 2025 | 4.6–6.1 | Quarterly VAR |
| Bi, Phillot & Zubairy | 2025 | ~2.5 (HF peak) | Auction supply shocks |
| Auerbach & Gale | 2025 | ~3 (assumed) | Applied projection |

**Pipeline value:** 3.0 bp/pp preferred (range 2.0–4.0). See `config/coefficients.yaml`.

---

# Part II: Treasury Yield Pass-Through to Consumer Rates

This part summarizes the empirical and institutional relationships between
Treasury yields and consumer lending rates (mortgages, auto loans, small business
loans), with a focus on rules of thumb and pass-through elasticities relevant to
the pipeline.

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

Since the pipeline's elasticity (3 bp/pp) is calibrated to the 10-year
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

Since the pipeline's fiscal effect operates primarily through the
**term premium** (~75%), and the term premium does not directly affect the
fed funds rate or prime, only the **expected short-rate channel** (~25%) passes
through to prime-linked lending:

- Term premium channel (75% of fiscal effect) -> affects long-term fixed rates,
  largely **bypasses** prime-linked lending
- Expected short-rate channel (25%) -> affects prime only if/when the Fed
  actually changes policy rates

This makes the pipeline's 0.25 pass-through **well-motivated
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

## Pass-Through Summary

| Consumer Rate | Treasury Benchmark | Spread | Pass-Through from 10yr Fiscal Effect | Pipeline Value |
|--------------|:------------------:|:------:|:------------------------------------:|:---------------------:|
| 30yr mortgage | 10yr Treasury | ~170 bp | **~1.0** | 1.00 |
| Auto loan (48-mo bank) | 5yr Treasury | ~300 bp | **~0.50-0.75** | 0.50 |
| Small business (prime-linked) | Fed funds + 3% | varies | **~0.25** | 0.25 |
| SBA 504 (CDC portion) | 5yr/10yr Treasury | ~200 bp | **~0.75-1.0** | not modeled |

The pipeline values are within the supported range for all three loan
types. The auto pass-through (0.50) is at the lower end of the empirical range
(0.50-0.75), reflecting the dampening role of nonbank lenders (~55% of auto
origination) documented by Elliott et al. (2022).

### Cross-Check: S&P Global US Macro Model (USMM 2024)

The USMM sectoral equation listing (September 2024) provides structural
equations that relate Treasury yields to consumer lending rates. These offer
an independent cross-check of the pipeline's reduced-form pass-through
coefficients.

The USMM does not use the 5y5y forward rate (`RMF5Y5Y`) as an input to
consumer rates. The 5y5y is a derived output of the zero-coupon yield curve:

```
RMF5Y5Y = 200 * (((1 + RS10Y/200)^20 / (1 + RS5Y/200)^10)^0.1 - 1)
```

Consumer rates are instead keyed off `RT10Y` (10yr constant-maturity Treasury)
and `RMFF` (federal funds rate) directly. Given a 1 bp fiscal-policy shock to
the 10yr yield, with the assumption that 25% passes through to the federal
funds rate (consistent with the pipeline's term-premium/expected-short-rate
decomposition), the USMM equations imply:

**30-Year Mortgage Rate** (`RMMTG30CON`):

```
RMMTG30CON = RT10Y + 1.91 - 0.090*(RT10Y - RMFFEF) + [spread adjustments]

dRMMTG30CON = 1 - 0.090*(1 - 0.25) = 0.93 bp
```

The long-run mortgage spread is ~191 bp over the 10yr, with a small adjustment
for yield curve slope (-0.090 coefficient), on/off-the-run spread, and rate
volatility. The error-correction speed is 0.928 (fast convergence).

**Prime Lending Rate** (`RMPRIME`):

```
RMPRIME = max(RMFF - 0.25, 0) + 3.25    [≈ RMFF + 3.00 away from ZLB]

dRMPRIME = 0.25 bp
```

Purely mechanical: fed funds + 300 bp, with a floor at 3.25% for the zero
lower bound.

**5-Year Treasury** (`RT5Y`, benchmark for auto loans):

```
RT5Y = -0.158 - 0.070*RMFFEF + 0.572*RT10Y + 0.520*RT2Y

dRT5Y = -0.070*(0.25) + 0.572*(1) + 0.520*(dRT2Y)
```

The 5yr yield depends on the 10yr, fed funds, and the 2yr rate. Assuming the
term premium component (75% of the fiscal shock) decays roughly linearly
toward shorter maturities (so the 2yr picks up ~20% of the term premium plus
the full expected-short-rate component): dRT2Y ≈ 0.40 bp, giving
dRT5Y ≈ **0.76 bp** (range 0.68-0.81 depending on RT2Y assumptions).

**Comparison with pipeline values:**

| Rate | USMM implied pass-through | Pipeline value | Notes |
|------|:---:|:---:|-------|
| Mortgage | 0.93 | 1.00 | Pipeline rounds up; USMM's slope adjustment slightly dampens |
| Prime/SMB | 0.25 | 0.25 | Exact match |
| 5yr Treasury | ~0.76 | -- | Not directly used in pipeline |
| Auto loan | -- | 0.50 | Pipeline's 0.50 = 5yr Treasury pass-through (~0.76) dampened by nonbank lending (~55% share) |

The USMM equations confirm the pipeline's pass-through structure: mortgage
tracks the 10yr nearly 1:1, prime tracks fed funds mechanically, and the 5yr
Treasury (auto benchmark) gets a dampened share of the 10yr shock. The gap
between the USMM's 5yr Treasury pass-through (~0.76) and the pipeline's auto
pass-through (0.50) is consistent with the intermediation friction from
nonbank auto lenders documented by Elliott et al. (2022).

*Source: S&P Global Market Intelligence, "US Macro Model (USMM) Sectoral
Equation Listing," September 2024.*

---

# Part III: Loan Parameters (Late November 2025 Vintage)

This section documents the principal amounts, loan terms, and observed baseline
rates used in the household cost calculation. All rates and data are targeted
to **late November 2025**, approximately matching CBO's data cutoff for
the February 2026 Budget and Economic Outlook.

### 30-Year Fixed Mortgage

| Parameter | Value | Source |
|-----------|-------|--------|
| Median existing-home sale price | $412,300 | FRED HOSMEDUSM052N, Sep 2025 (latest monthly available) |
| Down payment | 20% | Convention |
| **Principal** | **$329,840** | Derived ($412,300 x 0.80) |
| Term | 360 months | Standard |
| **Observed rate** | **6.23%** | Freddie Mac PMMS (FRED MORTGAGE30US), Nov 26 2025 |

Previous vintage (2024): median $412,500, principal $330,000, rate 6.72%.

The November 2025 rate (6.23%) is lower than the 2024 average (6.72%)
following the Fed's 50 bp of rate cuts through November (Sep 17 and Oct 30).

### New Auto Loan

| Parameter | Value | Source |
|-----------|-------|--------|
| **Average amount financed** | **$42,332** | Experian State of the Automotive Finance Market, Q3 2025 |
| Term | 67 months | Experian (unchanged from 2024) |
| **Observed rate (48-mo, commercial bank)** | **7.51%** | FRED TERMCBAUTO48NS, Q3 2025 (Aug 2025 observation) |

Previous vintage (2024): principal $41,086 (Lending Tree), rate 7.10%.

Note: The FRED series DTCTLVNANM (average amount financed at auto finance
companies) was discontinued in January 2011. Experian's quarterly report is
now the standard industry source for per-loan averages. The commercial bank
48-month rate (TERMCBAUTO48NS) *rose* from 7.10% to 7.51% despite Fed cuts,
consistent with auto rates tracking the 5-year Treasury rather than fed funds
(Cox Automotive, 2025).

### Small Business Loan

| Parameter | Value | Source |
|-----------|-------|--------|
| **Average loan balance** | **$663,000** | B2BReview/SBA (2024; no 2025 update available) |
| Term | 60 months | Standard for bank term loans |
| **Observed rate (prime)** | **7.00%** | FRED DPRIME, Nov 2025 |

Previous vintage (2024): same principal, rate 7.50%.

The prime rate fell 50 bp from 7.50% to 7.00% via two 25 bp Fed cuts
(Sep 17, Oct 30 2025). In late November 2025, the December 11 cut (to 6.75%)
had not yet occurred. The $663,000 average loan balance from B2BReview
aggregates across SBA 7(a), conventional bank term loans, and lines of credit.
SBA 7(a) loans alone averaged $452K in FY2025 (iBusiness Funding, citing
SBA data).

### Data Vintage Summary

All data targeted to late November 2025 (CBO data cutoff for Feb 2026 report).

| Product | Principal Source | Principal Vintage | Rate Source | Rate Date |
|---------|-----------------|:-----------------:|-------------|:---------:|
| Mortgage | FRED HOSMEDUSM052N | Sep 2025 | Freddie Mac PMMS (FRED) | Nov 26, 2025 |
| Auto | Experian | Q3 2025 | FRED TERMCBAUTO48NS | Q3 2025 (Aug) |
| Small business | B2BReview/SBA | 2024 | FRED DPRIME | Nov 2025 |

---

# References

- Plante, Richter & Zubairy (2025). "[Revisiting the Interest Rate Effects of Federal Debt](https://www.dallasfed.org/research/papers/2025/wp2513)." Dallas Fed Working Paper 2513 / NBER Working Paper 34018.
- Laubach (2009). "[New Evidence on the Interest Rate Effects of Budget Deficits and Debt](https://www.federalreserve.gov/econres/feds/new-evidence-on-the-interest-rate-effects-of-budget-deficits-and-debt.htm)." Journal of the European Economic Association 7(4): 858-885. Also FEDS 2009-12.
- Neveu & Schafer (2024). "[Revisiting the Relationship Between Debt and Long-Term Interest Rates](https://www.cbo.gov/publication/60314)." CBO Working Paper 2024-05.
- Furceri, Goncalves & Li (2025). "[The Impact of Debt and Deficits on Long-Term Interest Rates in the US](https://www.imf.org/en/publications/wp/issues/2025/07/11/the-impact-of-debt-and-deficits-on-long-term-interest-rates-in-the-us-568444)." IMF Working Paper 2025/142.
- Ehrlich, Kay & Thapar (2025). "[Public Debt Levels and Real Interest Rates](https://www.dallasfed.org/research/papers/2025/wp2539)." Dallas Fed Working Paper 2539.
- Salmon (2025). "[The Impact of Public Debt on Interest Rates](https://www.mercatus.org/research/policy-briefs/impact-public-debt-interest-rates)." Mercatus Center Policy Brief.
- Gomez-Cram, Kung & Lustig (2025). "[Can U.S. Treasury Markets Add and Subtract?](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=5190791)" NBER Working Paper 33604.
- Bi, Phillot & Zubairy (2025). "[Higher Treasury Supply Is Likely to Put Upward Pressure on Interest Rates](https://www.kansascityfed.org/research/economic-bulletin/higher-treasury-supply-is-likely-to-put-upward-pressure-on-interest-rates/)." KC Fed Economic Bulletin.
- Auerbach & Gale (2025). "[Then and Now: A Look Back and Ahead at the Federal Budget](https://www.nber.org/papers/w34455)." NBER Working Paper 34455.
- Hanson, Lucca & Wright (2021). "[Rate-Amplifying Demand and the Excess Sensitivity of Long-Term Rates](https://academic.oup.com/qje/article-abstract/136/3/1719/6219101)." Quarterly Journal of Economics 136(3): 1719-1781.
- Elliott, Meisenzahl, Peydro & Turner (2022). "[Nonbanks, Banks, and Monetary Policy: U.S. Loan-Level Evidence since the 1990s](https://www.chicagofed.org/publications/working-papers/2022/2022-27)." Chicago Fed Working Paper 2022-27.
- Krishnamurthy & Vissing-Jorgensen (2011). "[The Effects of Quantitative Easing on Interest Rates](https://www.brookings.edu/wp-content/uploads/2016/07/2011b_bpea_krishnamurthy.pdf)." Brookings Papers on Economic Activity 42(2): 215-287.
- Minneapolis Fed (2025). "[What Drives Consumer Interest Rates?](https://www.minneapolisfed.org/article/2025/what-drives-consumer-interest-rates)"
- Fannie Mae Research. "[What Determines the Rate on a 30-Year Mortgage?](https://www.fanniemae.com/research-and-insights/publications/housing-insights/rate-30-year-mortgage)"
- Richmond Fed (2023). "[Mortgage Spreads and the Yield Curve](https://www.richmondfed.org/publications/research/economic_brief/2023/eb_23-27)." Economic Brief 23-27.
- Dallas Fed (April 2023). "[Interest Rate Volatility Contributed to Higher Mortgage Rates in 2022](https://www.dallasfed.org/research/economics/2023/0404)."
- Boyarchenko, Fuster & Lucca (2014, rev. 2018). "[Understanding Mortgage Spreads](https://www.newyorkfed.org/research/staff_reports/sr674.html)." NY Fed Staff Report 674.
- SBA. [Terms, Conditions & Eligibility (7(a) program)](https://www.sba.gov/partners/lenders/7a-loan-program/terms-conditions-eligibility).
- Cox Automotive. [Dealertrack Credit Availability Index](https://www.coxautoinc.com/market-insights/dealertrack-credit-availability-index/) (monthly).
- Cotton (2024). "[Debt, Deficits, and Interest Rates](https://onlinelibrary.wiley.com/doi/10.1111/ecca.12521)." Economica 91(363): 911-943.
- Gust & Skaperdas (2024). "[Government Debt, Limited Foresight, and Longer-term Interest Rates](https://www.federalreserve.gov/econres/feds/government-debt-limited-foresight-and-longer-term-interest-rates.htm)." FEDS Working Paper 2024-027.
