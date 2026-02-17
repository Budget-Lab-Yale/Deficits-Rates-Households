# CBO Budget Projections: Fiscal-Policy Decomposition Timeline

> **Note:** This document is a technical reference for the CBO Budget Projections
> Excel files used in the legacy Excel parser and for the latest-vintage Excel
> append. The production pipeline uses CBO eval-projections CSVs
> (`baseline_changes.csv`) as its primary data source; this reference supports
> auditability and the Excel append pathway.

This reference documents the CBO Budget Projections vintages used in the
fiscal-policy decomposition pipeline, the specific parsing choices made for each,
and known concerns.

## Overview

- **43 total Budget Projections files** (2007-01 to 2026-02)
- **22 vintages in CSV-primary mode** (2015-08 to 2026-02) -- continuous chain including
  zero-legislation vintages May 2019 and May 2023
- **20 vintages in Excel-legacy mode** -- same range, skipping May 2019 and May 2023
  (no legislative data in their Excel files)
- **All pre-2015 vintages excluded** -- inconsistent formats, large gaps, no GDP denominator
- **GDP denominator:** CBO Economic Projections (CSV or Excel by mode)

## Parser Approach

The pipeline uses a **hardcoded lookup table** (`DECOMP_LOOKUP` in `parse_cbo_excel.R`)
rather than a universal parser. Each vintage specifies:

- **Sheet name** -- the exact Excel sheet containing the decomposition
- **Since date** -- the prior CBO baseline this vintage compares against
- **Negate flag** -- whether to flip the sign of raw values (TRUE for pre-2024 files)

This approach was chosen because CBO changed the decomposition format at least 4 times
between 2007 and 2025, with variations in sheet names, column layouts, row labels, and
sign conventions. A universal regex-based parser proved fragile across these eras.

## Parsed Vintage Table (Reported Window Values)

All values verified against raw Excel files (spot-checked Feb 2026).

| Vintage | Sheet Used | Since Date | Raw Reported ($B) | Negate | Normalized ($B) | Notes |
|---------|-----------|------------|-------------:|--------|----------------:|-------|
| 2015-08 | `8. Table A-1` | Mar 2015 | -76.0 | Yes | **+76.0** | Rev/outlay primary axis; "Total Legislative Changes" in Memorandum |
| 2016-01 | `18. Table A-1` | Aug 2015 | -486.6 | Yes | **+486.6** | Omnibus spending, tax extenders (Dec 2015) |
| 2016-03 | `Table 6` | Jan 2016 | +0.1 | Yes | **-0.1** | Negligible; mid-cycle update |
| 2016-08 | `Table A-1` | Mar 2016 | +0.4 | Yes | **-0.4** | Negligible |
| 2017-01 | `Table A-1` | Aug 2016 | -57.5 | Yes | **+57.5** | 21st Century Cures Act, continuing resolutions |
| 2017-06 | `Table 6` | Jan 2017 | -119.4 | Yes | **+119.4** | FY2017 omnibus |
| 2018-04 | `Table A-1` | Jun 2017 | -1707.7 | Yes | **+1707.7** | **Tax Cuts and Jobs Act** (Dec 2017) + Bipartisan Budget Act of 2018 |
| 2019-01 | `Table A-1` | Apr 2018 | +231.7 | Yes | **-231.7** | Partial offset from revised TCJA scoring |
| 2019-08 | `Table A-1` | May 2019 | -817.4 | Yes | **+817.4** | Bipartisan Budget Act of 2019 (spending caps deal) |
| 2020-01 | `Table A-1` | Aug 2019 | -198.0 | Yes | **+198.0** | Further Consolidated Appropriations Act |
| 2020-03 | `Table 6` | Jan 2020 | -31.4 | Yes | **+31.4** | Pre-COVID baseline update |
| 2020-09 | `Table A-1` | Mar 2020 | -366.6 | Yes | **+366.6** | CARES Act and other COVID relief (partial; more in 2021-02) |
| 2021-02 | `Table 1-6` | Sep 2020 | -1151.4 | Yes | **+1151.4** | Consolidated Appropriations Act 2021 + COVID relief Dec 2020 |
| 2021-07 | `Table A-1` | Feb 2021 | -826.8 | Yes | **+826.8** | **American Rescue Plan Act** (Mar 2021) |
| 2022-05 | `Table A-1` | Jul 2021 | -754.6 | Yes | **+754.6** | Infrastructure Investment and Jobs Act + other FY2022 legislation |
| 2023-02 | `Table A-1` | May 2022 | -647.2 | Yes | **+647.2** | Inflation Reduction Act + CHIPS Act + other |
| 2024-02 | `Table 3-1` | May 2023 | -993.0 | No | **-993.0** | **Fiscal Responsibility Act** (debt ceiling deal, deficit reduction) |
| 2024-06 | `Table 3-1` | Feb 2024 | +648.4 | No | **+648.4** | FY2024 appropriations + supplemental aid packages |
| 2025-01 | `Table A-1` | Jun 2024 | +124.6 | No | **+124.6** | Continuing resolutions, minor legislation |
| 2026-02 | `Table 5-1` | Jan 2025 | +2285.3 | No | **+2285.3** | **2025 Reconciliation Act** (TCJA extension + tax/spending changes) |

Note: The production metric uses harmonized annual sums over exact years
`t` through `t+9`, not these reported-window totals.

## Skipped Vintages (2015+ Range)

| Vintage | Reason | Impact on Chain |
|---------|--------|-----------------|
| 2019-05 | Table 5 contains mandatory spending projections, not a deficit decomposition. No legislative data. | Gap: 2019-01 to 2019-08. The 2019-08 vintage covers changes "since May 2019" so it picks up where 2019-01 left off with minimal gap. |
| 2023-05 | Table 5 contains only Technical Changes (no legislative component). | Gap: 2023-02 to 2024-02. The 2024-02 vintage covers changes "since May 2023" which bridges this gap. |

## Sign Convention Details

CBO has used three different sign conventions across eras. The parser normalizes
all values so that **positive = increases the deficit** (more borrowing).

| Vintages | Row Label Pattern | Convention | Parser Action |
|----------|------------------|------------|---------------|
| 2015-08 | "Total Legislative Changes" + footnote "Negative = increase" | Negative raw = increases deficit | Negate (`negate=TRUE`) |
| 2016-01 to 2023-02 | "Increase (-) in the Deficit from Legislative Changes" | Negative raw = increases deficit | Negate (`negate=TRUE`) |
| 2024-02 to 2026-02 | "Increase or decrease (-) in the deficit from legislative changes" | Positive raw = increases deficit | Keep as-is (`negate=FALSE`) |

The switch from `negate=TRUE` to `negate=FALSE` occurs at the 2024-02 vintage.
This was verified by checking that the Fiscal Responsibility Act (a deficit-reduction
package) produces a negative normalized value (-$993B), which is correct.

## Sheet Name Decisions

Several vintages have multiple candidate sheets. The lookup table specifies which
sheet to use and why:

| Issue | Decision | Rationale |
|-------|----------|-----------|
| Files with both `Table 1-6` and `Table A-1` (2016-01, 2016-08, 2017-01, etc.) | Use `Table A-1` | Table A-1 has the full L/E/T decomposition; Table 1-6 may be discretionary spending |
| Files with both `Table 3-1` and `Table A-1` (2019-01, 2019-08, 2022-05) | Use `Table A-1` | Table A-1 is the canonical decomposition sheet |
| 2024-02 and 2024-06 | Use `Table 3-1` | These files' `Table 1-6` is discretionary budget authority, not a deficit decomposition. `Table 3-1` has the full L/E/T breakdown. |
| 2016-03, 2017-06, 2020-03 | Use `Table 6` | Their `Table 5` is spending projections (mandatory or discretionary), not a decomposition. `Table 6` has the "Changes in Baseline Projections of the Deficit" decomposition. |
| 2023-02 | Use `Table A-1` (not `Table 1-6 `) | The `Table 1-6` sheet has a trailing space in its name and is less reliable. `Table A-1` has the same data. |
| 2026-02 | Use `Table 5-1` | `Table 3-1` is an outlays table in this vintage. `Table 5-1` has the full L/E/T deficit decomposition ("Changes in CBO's Baseline Projections of the Deficit Since January 2025"). |

## Methodological Concerns

### 1. Potential Double-Counting via Overlapping Windows

Each vintage's 10-year legislative total covers a **different 10-year window** (e.g.,
2018-04 covers FY2018-2027, while 2019-01 covers FY2019-2028). When we chain
(sum) these incremental values, a single piece of legislation may contribute to
multiple vintages' totals.

However, this is **not double-counting** in the strict sense. Each vintage reports
only the *change* in the 10-year legislative deficit relative to the immediately
preceding baseline. If the TCJA was already in the 2018-04 baseline, the 2019-01
vintage's legislative component only captures *new* legislation enacted between
April 2018 and January 2019 (e.g., revised scoring, new laws). The CBO explicitly
decomposes changes into "what changed since last time."

**Where this can overstate the true impact:** If CBO revises its scoring of a
prior law (e.g., re-estimates TCJA revenue effects), that revision appears in the
"legislative" column of the new vintage even though no new legislation was enacted.
CBO distinguishes between "legislative changes" and "technical re-estimates of
legislative changes" in some vintages but not all.

### 2. Variable Window Lengths

Not all reported totals cover the same number of fiscal years. Some vintages
(especially 2020-2021 era) use a 6-year window. The parser harmonizes each
vintage by summing annual values for exact years `t..t+9`.

### 3. GDP Denominator Matching

Each decomposition vintage is matched to the latest CBO Economic Projections
file on or before that vintage (no look-ahead matching), subject to a maximum lag.

### 4. Mid-Cycle Gaps

Two vintages (2019-05, 2023-05) lack legislative data. In both cases, the next
full vintage covers "since" the gap vintage's date, so the chain remains continuous.
However, the longer window may obscure the timing of individual legislative actions.

### 5. 2026 Policy-Intent Adjustment

For the 2026-02 vintage only, the parser applies a one-time adjustment that includes
customs-duty effects classified by CBO as technical changes, treating them as
fiscal-policy-driven for this tracker.

### 6. Pre-2015 Exclusion

Vintages before 2015-08 are excluded because:
- Format variations are much more extreme (7+ different sheet naming conventions)
- Large gaps exist (2009-2010: 19 months with no decomposition)
- Some vintages lack the L/E/T breakdown entirely (2013-05)
- No CBO Economic Projections files exist before 2014-08 for the GDP denominator
- The 2015-08 starting point aligns with the post-sequestration fiscal policy era

## Pre-2015 Inventory (Not Used)

For reference, the pre-2015 files and their decomposition availability:

| Vintage | Has Decomp | Sheet | Notes |
|---------|-----------|-------|-------|
| 2007-01 | Yes | `Changes` | Memorandum format, .xls |
| 2007-08 | Yes | `Baseline_Changes_Since_March_07` | .xls |
| 2008-01 | Yes | `Changes Since Aug. 07` | .xlsx |
| 2008-09 | Yes | `TabA-1` | .xls |
| 2009-01 | **No** | -- | File read error |
| 2009-03 | **No** | -- | Non-standard sheets |
| 2009-08 | **No** | -- | No decomposition |
| 2010-01 | **No** | -- | No Table 1-6 |
| 2010-08 | Yes | `Table 1-6` | .xls |
| 2011-01 | Yes | `Table 1-6` | .xls |
| 2011-08 | Yes | `Table 1-6` | .xlsx |
| 2012-01 | Yes | `Table 1-6` | .xls |
| 2012-03 | **No** | -- | No standard decomp |
| 2012-08 | Yes | `Table 1-6` | .xlsx |
| 2013-02 | Yes | `Table 1-6` | .xls |
| 2013-05 | Yes | `Table 6` | **No L/E/T split** |
| 2014-02 | Yes | `Table 3-1` | .xlsx |
| 2014-04 | Yes | `Table 5` | .xlsx |
| 2014-08 | **No** | -- | No decomposition |
| 2015-01 | Yes | `6. Table 3-1` | .xlsx |
| 2015-03 | Yes | `5. Table 5` | .xlsx |
