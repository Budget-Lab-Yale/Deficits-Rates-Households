# Deficits, Rates, and Household Costs

Applies published Laubach-framework elasticities to CBO projection vintages to track how
changes in projected federal debt contribute to Treasury yields and household borrowing costs.

This is **not** a regression re-estimation. It applies the 3 bp/pp coefficient from
Plante, Richter & Zubairy (2025, Dallas Fed WP 2513) to changes in CBO's projected
debt/GDP, then translates rate effects into mortgage, auto, and small business loan
cost impacts.

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

- **CBO GitHub** (`baselines.csv`): 41 projection vintages (1984-2025), debt in billions
- **FRED** (`NGDPPOT`): Nominal potential GDP for debt/GDP denominator
- **CBO Excel** (Budget Projections): Authoritative debt/GDP ratios for recent vintages
- **FRED** (consumer rates): MORTGAGE30US, TERMCBAUTO48NS, DPRIME for context

## Key Coefficient

3 basis points per 1 percentage point change in projected debt/GDP (5-year horizon).
Range: 2-4 bp/pp. Source: Plante, Richter & Zubairy (2025).

~75% of the effect flows through the term premium.

## Update Cadence

Follows CBO projection releases (~2x per year, typically January and June).

## References

- Plante, Richter & Zubairy (2025). Dallas Fed Working Paper 2513.
- Laubach (2009). "New Evidence on the Interest Rate Effects of Budget Deficits and Debt."
- Furceri et al. (2025). IMF Working Paper 2025/142.
- Neveu & Schafer (2024). CBO Working Paper 2024-05.
