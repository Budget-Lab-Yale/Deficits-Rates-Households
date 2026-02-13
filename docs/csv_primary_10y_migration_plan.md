# CSV-Primary + 10-Year Horizon Migration Plan

Date: 2026-02-12

## Objectives

1. Make CBO `eval-projections` CSV data the primary source for fiscal-policy decomposition history.
2. Parse only the latest Excel vintage (currently 2026-02) for data not yet in the CSV set.
3. Move methodology to a 10-year congressional window and 10-year Treasury response framing.

## Confirmed Method Choices

1. Horizon window definition: fiscal years `t` through `t+9`.
2. Sample window for chained results: start at `2015-08` (to align with prior work).
3. Zero-legislation vintages: keep them explicitly in the chain with increment `0`.
4. GDP denominator handling: use existing GDP-vintage table path for the 2015+ sample; append latest GDP from 2026 Excel when needed.

## Data Inputs

Primary:
- `Data/CBO Reports/Projections Evaluation Data/baseline_changes.csv`
- `Data/CBO Reports/Projections Evaluation Data/baselines.csv`

Excel append (latest only):
- `Data/CBO Reports/Budget Projections/51118-2026-02-Budget-Projections.xlsx`
- `Data/CBO Reports/Economic Projections/51135-2026-02-Economic-Projections.xlsx`

GDP vintage table:
- Existing `cbo_excel_gdp.csv`-style table for CBO economic vintages.

## Implementation Steps

1. Add CSV ingestion module:
- Parse legislative deficit changes from `baseline_changes.csv`.
- Restrict to `component=deficit`, `category=Total`, `change_category=Legislative`.
- Build per-vintage harmonized sums for `t..t+9` and normalize sign to:
  positive = higher deficits/higher debt.

2. Build vintage calendar and chain logic:
- Use 2015-08 onward budget-vintage calendar.
- Keep vintages with no legislative entries as explicit zeros (not dropped).
- Preserve `since_date` chaining semantics.

3. Append latest Excel vintage (2026-02):
- Parse fiscal-policy row from latest budget Excel.
- Apply one-time customs-duty technical adjustment for 2026 policy-intent treatment.
- Parse latest economic Excel and append GDP vintage rows if missing.

4. GDP denominator matching:
- Match each decomp vintage to latest economic vintage on/before that date.
- Use GDP at horizon year `t+9`.
- Fail loudly on missing vintage, lag breach, or missing horizon-year GDP.

5. Config + defaults:
- Set `projection_horizon: 10`.
- Set window start offset default to `0` (for `t..t+9`).
- Add config paths for CSV inputs and GDP-vintage table.

6. Output and docs updates:
- Update summary/method language from 5-year (`t+1..t+5`) to 10-year (`t..t+9`).
- Keep 10-year Treasury framing throughout labels.

7. Validation:
- Hard-fail checks on required columns, duplicate vintages, and horizon completeness.
- Spot-check selected vintages against source CSV/Excel and prior outputs.

## Expected Result

Pipeline runs with CSV-primary historical decomposition, latest Excel append for 2026, 10-year debt/GDP horizon (`t..t+9`), and 10-year Treasury response framing.
