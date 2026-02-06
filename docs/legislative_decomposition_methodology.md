# Legislative Fiscal Contribution to Interest Rates: Methodology

This document describes how the pipeline isolates the legislative component of
federal deficit changes and translates it into estimated effects on Treasury yields
and household borrowing costs.

## Approach

We extract the **legislative component** of CBO's deficit decomposition from each
Budget and Economic Outlook vintage. CBO decomposes changes in its baseline deficit
projections into three categories:

- **Legislative changes** -- new laws enacted since the prior baseline
- **Economic changes** -- revised macroeconomic assumptions
- **Technical changes** -- re-estimates, data revisions, modeling updates

By isolating only the legislative component, we measure how much of the change in
projected deficits is attributable to deliberate policy choices (tax cuts, spending
bills, etc.) rather than economic conditions or technical revisions.

We then apply the published Laubach-framework elasticity (3 basis points per
percentage point of projected debt/GDP, from Plante, Richter & Zubairy 2025,
Dallas Fed WP 2513) to translate cumulative legislative deficit changes into
estimated effects on long-term Treasury rates.

## Data Sources

- **CBO Budget Projections** (42 Excel files, 2007-2025) -- legislative decomposition tables
- **CBO Economic Projections** (22 Excel files, 2014-2025) -- projected nominal GDP
- **FRED** -- current consumer rate levels (mortgage, auto, prime)

## Vintage Coverage

We use 19 CBO projection vintages from August 2015 through January 2025, forming
a continuous chain. Each vintage reports the 5-year cumulative legislative deficit
change (in billions) since the immediately preceding CBO baseline.

Two mid-cycle updates (May 2019, May 2023) did not include a legislative
decomposition and are skipped; the subsequent full vintage bridges the gap.

| Vintage | Since | Legislative 5yr Deficit ($B) | Key Legislation |
|---------|-------|----------------------------:|-----------------|
| Aug 2015 | Mar 2015 | +76.0 | Misc. appropriations |
| Jan 2016 | Aug 2015 | +486.6 | Omnibus spending, tax extenders (Dec 2015) |
| Mar 2016 | Jan 2016 | -0.1 | Negligible; mid-cycle update |
| Aug 2016 | Mar 2016 | -0.4 | Negligible |
| Jan 2017 | Aug 2016 | +57.5 | 21st Century Cures Act, continuing resolutions |
| Jun 2017 | Jan 2017 | +119.4 | FY2017 omnibus |
| Apr 2018 | Jun 2017 | **+1,707.7** | **Tax Cuts and Jobs Act** + Bipartisan Budget Act of 2018 |
| Jan 2019 | Apr 2018 | -231.7 | Partial offset from revised TCJA scoring |
| Aug 2019 | May 2019 | +817.4 | Bipartisan Budget Act of 2019 (spending caps deal) |
| Jan 2020 | Aug 2019 | +198.0 | Further Consolidated Appropriations Act |
| Mar 2020 | Jan 2020 | +31.4 | Pre-COVID baseline update |
| Sep 2020 | Mar 2020 | +366.6 | CARES Act and other COVID relief |
| Feb 2021 | Sep 2020 | +1,151.4 | Consolidated Appropriations Act 2021 + Dec 2020 COVID relief |
| Jul 2021 | Feb 2021 | **+826.8** | **American Rescue Plan Act** |
| May 2022 | Jul 2021 | +754.6 | Infrastructure Investment and Jobs Act + FY2022 legislation |
| Feb 2023 | May 2022 | +647.2 | Inflation Reduction Act + CHIPS Act + other |
| Feb 2024 | May 2023 | **-993.0** | **Fiscal Responsibility Act** (deficit reduction) |
| Jun 2024 | Feb 2024 | +648.4 | FY2024 appropriations + supplemental aid |
| Jan 2025 | Jun 2024 | +124.6 | Continuing resolutions, minor legislation |

**Cumulative:** +$5,981B in 5-year legislative deficits across all 19 vintages.

Positive values indicate legislation that **increased** projected deficits (tax cuts
or spending increases). Negative values indicate deficit reduction (spending cuts or
revenue increases).

## Pipeline Steps

1. **Parse decomposition:** From each CBO Budget Projections file, extract the
   5-year cumulative legislative deficit change ($B) from the relevant table.

2. **GDP denominator:** Match each vintage to the nearest CBO Economic Projections
   file and extract projected nominal GDP at the 5-year horizon.

3. **Legislative delta(debt/GDP):** Divide the legislative deficit by projected GDP
   to get the legislative contribution in percentage points of GDP.

4. **Cumulative sum:** Chain the per-vintage deltas into a running total (two
   scenarios: since Aug 2015 and since May 2022).

5. **Rate effect:** Multiply cumulative delta(debt/GDP) by the Laubach-framework
   elasticity (3 bp per pp; range 2-4 bp/pp).

6. **Decompose:** Split into term premium (~75%) and expected short rate (~25%).

7. **Consumer pass-through:** Apply pass-through rates to consumer loan benchmarks
   (mortgage 100%, auto 75%, small business 25%).

8. **Household costs:** Translate rate changes into dollar impacts via standard
   amortization.

## Current Results (January 2025 Vintage)

### Rate Effects

| Scenario | Cumulative delta(debt/GDP) | 10yr Rate Effect | Range |
|----------|---------------------------:|:----------------:|:-----:|
| Since 2015 | +25.81 pp | **+77 bp** | +52 to +103 bp |
| Since 2022 | +3.82 pp | **+11 bp** | +8 to +15 bp |

### Household Cost Impacts (Since 2015 Scenario)

| Loan Type | Rate Change | Annual Impact | Lifetime Impact |
|-----------|:-----------:|--------------:|----------------:|
| 30-year fixed mortgage ($400K) | +77 bp | +$2,068/yr | +$62,029 |
| 48-month auto loan ($35K) | +58 bp | +$137/yr | +$767 |
| 5-year small business ($750K) | +19 bp | +$733/yr | +$3,664 |

## Analytical Considerations

### What the Cumulative Sum Represents

The cumulative sum chains together incremental legislative changes across
consecutive CBO baselines. Each vintage reports only what changed since the
previous baseline -- not a re-tally of all prior legislation. If the TCJA was
already incorporated into the April 2018 baseline, the January 2019 vintage
captures only *new* legislation enacted after April 2018.

This is a reasonable measure of cumulative legislative fiscal impulse, but has
some caveats:

### Scoring Revisions vs. New Legislation

CBO sometimes revises its estimate of a prior law's budgetary impact. These
revisions appear in the "legislative" column even though no new law was enacted.
For example, if CBO revises its estimate of TCJA revenue losses upward, that
revision contributes to the legislative delta in the subsequent vintage. CBO
distinguishes these from "technical re-estimates" in some vintages but not all.
This could modestly overstate the contribution of new legislation.

### Variable Window Lengths

Most 5-year totals cover exactly 5 fiscal years (e.g., FY2025-2029), but some
vintages -- particularly in the 2020-2021 era -- use a 6-year window (e.g.,
FY2020-2025). The column header in the Excel file indicates the actual range.
This introduces a slight inconsistency when comparing magnitudes across vintages.

### GDP Denominator Timing

Each decomposition vintage is matched to the nearest CBO Economic Projections
file for the GDP denominator. Most matches are exact or within 2-3 months.
GDP projections at the 5-year horizon are relatively stable across a few months,
so small timing gaps are unlikely to be material.

### Mid-Cycle Gaps

Two mid-cycle updates (May 2019, May 2023) lacked legislative data. In both cases,
the next full vintage covers "since" the gap vintage's date, so the chain remains
continuous. The longer window may obscure the precise timing of individual
legislative actions but does not miss any legislation.

### Elasticity Uncertainty

The 3 bp/pp elasticity is a central estimate from the literature. The range of
2-4 bp/pp spans estimates from Neveu & Schafer (2024, CBO WP) at the low end to
upper-bound estimates. All results should be interpreted with this uncertainty band.

## References

- Plante, Richter & Zubairy (2025). "Fiscal Policy and Long-Term Interest Rates."
  Dallas Fed Working Paper 2513.
- Laubach (2009). "New Evidence on the Interest Rate Effects of Budget Deficits and
  Debt." FEDS 2009-12.
- Neveu & Schafer (2024). CBO Working Paper 2024-05.
- Furceri et al. (2025). IMF Working Paper 2025/142.
