# Deficits, Rates, and Household Costs

A pipeline that applies published Laubach-framework elasticities to CBO
projection vintages to track how enacted legislation contributes to projected
federal debt, Treasury yields, and household borrowing costs (mortgages, auto
loans, small business loans).

This is **not** a regression re-estimation. It applies a coefficient of
**2 bp per 1 pp change in projected debt/GDP** (10-year horizon) from the
literature, then translates rate effects into dollar-cost impacts on household
loans.

**Preferred coefficient:** 2.0 bp/pp — Neveu & Schafer (2024, CBO WP 2024-05).
Range: 1.5–3.0 bp/pp.

## Prerequisites

- **R** >= 4.1
- **renv** (will be bootstrapped automatically on first run)
- **Writable sibling archive directory** at `../Data` by default

## Quick Start

```bash
# 1. Clone the repo
git clone <repo-url>
cd Deficits-Rates-Households

# 2. Create the required parallel archive directory
mkdir -p ../Data

# 3. Restore R package dependencies
Rscript -e 'renv::restore()'

# 4. Download required CBO Excel files (see next section)

# 5. Run the pipeline
Rscript src/main.R
```

`renv` activation is intentionally automatic. On a fresh machine, the first
`Rscript` call can appear paused for 10-30 seconds while the project library is
activated or bootstrapped. The repo now prints a startup message before that
happens so it is clear the process is working.

## Required Archive Directory

This pipeline requires a writable archive root parallel to the repo. The
default configuration expects this layout:

```text
parent/
├── Data/
└── Deficits-Rates-Households/
```

The default `config/runtime.yaml` value is `data_root: "../Data"`. Each run
writes an archived vintage folder there in addition to regenerating `output/`.
If your org wants the archive elsewhere, update `data_root` to another writable
path before running the pipeline.

## Required CBO Data Files

The pipeline builds 21 vintages from CSV data (`input/eval_csv/`) checked into
the repo. The latest vintage (currently 2026-02) is appended from CBO Excel
files that must be downloaded separately.

**Download from:** <https://www.cbo.gov/data/budget-economic-data>

### Budget Projections

Under section **#2 — 10-Year Budget Projections**, download the Excel file and
place it in `input/budget_projections/`:

```
input/budget_projections/51118-2026-02-Budget-Projections.xlsx
```

The filename must follow the CBO convention: `51118-YYYY-MM-Budget-Projections.xlsx`.

### Economic Projections

Under section **#4 — 10-Year Economic Projections**, download the Excel file
and place it in `input/economic_projections/`:

```
input/economic_projections/51135-2026-02-Economic-Projections.xlsx
```

The filename must follow the CBO convention: `51135-YYYY-MM-Economic-Projections.xlsx`.

> **Note:** The pipeline needs at minimum the latest vintage file in each
> directory. Historical vintages (2015-08 through 2025-01) are already covered
> by the CSV data and do not require Excel files — but having them present
> allows the `excel_legacy` mode and GDP vintage auto-generation to work.

If the required Excel files are missing, the pipeline will stop early with an
error message naming the specific files needed.

## Configuration

### `config/runtime.yaml`

Controls data source mode, projection horizon, archive location, and file paths.

| Setting | Default | Description |
|---------|---------|-------------|
| `cbo_data_source` | `eval_csv_primary` | `eval_csv_primary` (22 vintages from CSV + Excel append) or `excel_legacy` (20 vintages from Excel only) |
| `projection_horizon` | `10` | Fiscal-year window length |
| `append_latest_excel` | `true` | Whether to append the latest CBO vintage from Excel |
| `latest_excel_append_vintage` | `2026-02-01` | Date of the latest Excel vintage to append |
| `data_root` | `../Data` | Required writable archive root, typically a sibling `Data/` directory |

### `config/coefficients.yaml`

Published elasticities and loan parameters — not re-estimated.

| Parameter | Value | Source |
|-----------|-------|--------|
| Preferred elasticity | 2.0 bp/pp | Neveu & Schafer (2024) |
| Low bound | 1.5 bp/pp | Furceri, Goncalves & Li (2025) |
| High bound | 3.0 bp/pp | Plante, Richter & Zubairy (2025) |
| Term premium share | 75% | Plante et al. (2025) |

## Output

All output is written to `output/` (gitignored, regenerated on each run):

| File | Description |
|------|-------------|
| `summary.md` | Narrative summary with key results |
| `projection_vintage_panel.csv` | Full panel of harmonized vintage-level data |
| `household_cost_impacts.csv` | Dollar-cost impacts by loan type |
| `historical_contributions.csv` | Per-vintage and cumulative rate-effect history |
| `legislative_delta.png` | Per-vintage legislative debt/GDP contribution chart |
| `cumulative_legislative.png` | Cumulative legislative debt/GDP chart |
| `cumulative_rate_effect.png` | Cumulative Treasury-rate effect chart |
| `historical_contributions_since_2015.png` | Two-panel historical chart for the since-2015 scenario |
| `historical_contributions_since_2022.png` | Two-panel historical chart for the since-2022 scenario |
| `household_impacts.png` | Household cost impact visualization |
| `interest_cost_impacts_table.docx` | Formatted Word table of cost impacts |

## Project Structure

```
Deficits-Rates-Households/
├── config/
│   ├── runtime.yaml            # Pipeline configuration
│   └── coefficients.yaml       # Published elasticities and loan parameters
├── input/
│   ├── eval_csv/               # CBO eval-projections CSV data (checked in)
│   │   ├── baselines.csv
│   │   ├── baseline_changes.csv
│   │   ├── budget_vintage_calendar.csv
│   │   └── cbo_gdp_vintages.csv
│   ├── budget_projections/     # CBO Budget Projections Excel (gitignored)
│   └── economic_projections/   # CBO Economic Projections Excel (gitignored)
├── src/
│   ├── main.R                  # Entry point
│   ├── data/
│   │   ├── parse_cbo_eval_csv.R  # CSV-primary data ingestion
│   │   ├── parse_cbo_excel.R   # Legacy Excel parser
│   │   └── build_dataset.R     # Panel construction
│   ├── model/
│   │   ├── fiscal_contribution.R  # Elasticity application
│   │   └── amortize.R          # Loan cost computation
│   ├── output/
│   │   └── generate_output.R   # Charts, tables, summary
│   └── utils/
│       └── helpers.R           # Config, formatting, utilities
├── output/                     # Generated results (gitignored)
├── renv.lock                   # Package dependency lockfile
├── renv/
│   ├── activate.R              # renv bootstrap script
│   └── settings.json
└── .Rprofile                   # Activates renv on R startup
```

## Pipeline Steps

1. **Parse CBO Data** — build fiscal-policy decomposition from CSV + Excel append
2. **Build Panel** — harmonize vintages to consistent 10-year windows, compute debt/GDP
3. **Compute Fiscal Contribution** — apply elasticity to cumulative legislative debt changes
4. **Compute Household Costs** — translate rate effects through pass-through coefficients to loan costs
5. **Generate Output** — charts, tables, and markdown summary
6. **Archive** — copy key outputs and manifests to the required vintage directory under `data_root`

## Update Cadence

Follows CBO projection releases (~2x per year, typically January and June).
When a new CBO vintage is released:

1. Download the new Budget and Economic Projections Excel files
2. Update `latest_excel_append_vintage` in `config/runtime.yaml`
3. Add a `DECOMP_LOOKUP` entry in `src/data/parse_cbo_excel.R` for the new vintage
4. Run the pipeline

Once the CBO eval-projections CSV repository is updated to include the new
vintage, the Excel append is no longer needed and the CSV data becomes the
primary source.

## References

- Neveu, A. R. & Schafer, J. (2024). "The Effect of Federal Debt on Long-Term Interest Rates." CBO Working Paper 2024-05.
- Plante, M., Richter, A. & Zubairy, S. (2025). "Federal Debt and the Real Interest Rate." Dallas Fed Working Paper 2513.
- Furceri, D., Goncalves, C. E. & Li, B. G. (2025). "The Effects of Public Debt on Interest Rates." IMF Working Paper 2025/142.
- Laubach, T. (2009). "New Evidence on the Interest Rate Effects of Budget Deficits and Debt." *Journal of the European Economic Association*.
