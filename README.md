# Deficits, Rates, and Household Costs

Applies published Laubach-framework elasticities to CBO projection vintages to track how
fiscal policy contributes to projected federal debt, Treasury yields, and household borrowing costs.

This is **not** a regression re-estimation. It applies the 3 bp/pp coefficient from
Plante, Richter & Zubairy (2025, Dallas Fed WP 2513) to changes in CBO's projected
debt/GDP, then translates rate effects into mortgage, auto, and small business loan
cost impacts.

The core panel harmonizes each vintage to an exact 10-year window (`t` to `t+9`)
before converting to debt/GDP.

## Usage

```bash
Rscript src/main.R
```

Or with a custom config:

```bash
Rscript src/main.R config/runtime.yaml
```

## Structure

```
config/           Runtime parameters and published elasticities
src/
  data/           CBO GitHub, FRED, and CBO Excel data pipelines
  model/          Fiscal contribution and amortization logic
  output/         Tables, charts, and markdown summary
  utils/          Config loading, vintage directories, helpers
output/           Generated results (gitignored)
```

## Data Sources

The pipeline supports two data modes, controlled by `cbo_data_source` in `config/runtime.yaml`:

- **`eval_csv_primary`** (default): Uses CBO eval-projections CSVs (`baseline_changes.csv`
  for legislative decomposition, `baselines.csv` for debt levels) as the primary source.
  The latest CBO vintage is appended from Excel when it has not yet appeared in the CSV set.
  This mode produces 22 vintages (2015-08 to 2026-02), including zero-legislation vintages
  (May 2019, May 2023) that the legacy Excel parser skipped.
- **`excel_legacy`**: Parses all historical CBO Budget Projections Excel files directly
  (20 vintages, skipping May 2019 and May 2023).

Additional sources:
- **CBO Economic Projections**: projected nominal GDP denominator (CSV or Excel by mode)
- **FRED** (consumer rates): MORTGAGE30US, TERMCBAUTO48NS, DPRIME for context

By default, network fetches are disabled in `config/runtime.yaml`; set `fetch.*=true`
to refresh external sources. Enabled fetches are fail-fast.

## Key Coefficient

3 basis points per 1 percentage point change in projected debt/GDP (10-year horizon).
Range: 2-4 bp/pp. Source: Plante, Richter & Zubairy (2025).

~75% of the effect flows through the term premium.

## Update Cadence

Follows CBO projection releases (~2x per year, typically January and June).

## References

- Plante, Richter & Zubairy (2025). Dallas Fed Working Paper 2513.
- Laubach (2009). "New Evidence on the Interest Rate Effects of Budget Deficits and Debt."
- Furceri et al. (2025). IMF Working Paper 2025/142.
- Neveu & Schafer (2024). CBO Working Paper 2024-05.
