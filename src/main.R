# main.R — Entry point for Deficits-Rates-Households pipeline
#
# Applies published Laubach-framework elasticities to CBO projection vintages
# to track how changes in projected federal debt contribute to Treasury yields
# and household borrowing costs.
#
# Usage:
#   Rscript src/main.R                     # Use default config
#   Rscript src/main.R config/runtime.yaml  # Custom config path

# ---- Setup ----

.repo_root <- tryCatch({
  script_dir <- dirname(sys.frame(1)$ofile)
  normalizePath(file.path(script_dir, ".."), mustWork = FALSE)
}, error = function(e) {
  if (file.exists("Deficits-Rates-Households.Rproj")) {
    normalizePath(".")
  } else if (file.exists(file.path("..", "Deficits-Rates-Households.Rproj"))) {
    normalizePath("..")
  } else {
    getwd()
  }
})

# Source modules
source(file.path(.repo_root, "src", "utils", "helpers.R"))
source(file.path(.repo_root, "src", "data", "fetch_cbo_github.R"))
source(file.path(.repo_root, "src", "data", "fetch_fred.R"))
source(file.path(.repo_root, "src", "data", "parse_cbo_excel.R"))
source(file.path(.repo_root, "src", "data", "build_dataset.R"))
source(file.path(.repo_root, "src", "model", "fiscal_contribution.R"))
source(file.path(.repo_root, "src", "model", "amortize.R"))
source(file.path(.repo_root, "src", "output", "generate_output.R"))

# ---- Parse Arguments ----

args <- commandArgs(trailingOnly = TRUE)
config_path <- if (length(args) >= 1) args[1] else NULL

# ---- Load Configuration ----

message("=== Deficits, Rates, and Household Costs: Laubach-Framework Tracker ===\n")

config <- read_config(config_path)
coefs  <- read_coefficients()

message(sprintf("Elasticity (preferred): %.1f bp/pp debt/GDP", coefs$elasticity$preferred))
message(sprintf("Projection horizon:     %d years", config$projection_horizon %||% 5))
message(sprintf("Data root:              %s\n", config$data_root))

# ---- Create Output Directories ----

vintage <- format(Sys.time(), "%Y%m%d_%H%M%S")
data_dir <- create_vintage_dir(config, vintage = vintage)
output_dir <- file.path(.repo_root, config$output_dir)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

message(sprintf("Data vintage:           %s\n", data_dir))

# ---- Step 1: Fetch CBO GitHub Data ----

message("--- Step 1: Fetching CBO GitHub data ---")

cbo_github <- tryCatch({
  fetch_cbo_github(config)
}, error = function(e) {
  message(sprintf("  ERROR: %s", e$message))
  message("  Continuing without GitHub data...")
  list(baselines = NULL, debt_at_horizon = data.frame(), all_debt = NULL,
       dependencies = data.frame(source = character(), series = character(),
                                 url = character(), retrieved_at = character(),
                                 stringsAsFactors = FALSE))
})

save_cbo_github(cbo_github, data_dir)
message("")

# ---- Step 2: Fetch FRED Data ----

message("--- Step 2: Fetching FRED data ---")

fred_results <- fetch_fred_data(config)
save_fred_data(fred_results, data_dir)
message("")

# ---- Step 3: Parse CBO Excel Files ----

message("--- Step 3: Parsing CBO Excel files (Budget + Economic Projections) ---")

cbo_excel <- tryCatch({
  parse_cbo_excel_files(config)
}, error = function(e) {
  message(sprintf("  ERROR: %s", e$message))
  list(budget_vintages = data.frame(), econ_vintages = data.frame(),
       dependencies = data.frame(
         source = character(), series = character(),
         url = character(), retrieved_at = character(),
         stringsAsFactors = FALSE
  ))
})

save_cbo_excel(cbo_excel, data_dir)
message("")

# ---- Step 4: Build Dataset ----

message("--- Step 4: Building projection vintage panel ---")

panel <- build_dataset(cbo_github, fred_results, cbo_excel, config)
save_dataset(panel, data_dir)
message("")

# ---- Step 5: Compute Fiscal Contribution ----

message("--- Step 5: Computing fiscal contribution ---")

fiscal <- compute_fiscal_contribution(panel, coefs)
historical <- compute_historical_contributions(panel, coefs)
message("")

# ---- Step 6: Compute Household Costs ----

message("--- Step 6: Computing household cost impacts ---")

costs <- compute_household_costs(fiscal, coefs)
costs_table <- household_costs_table(costs)
message("")

# ---- Step 7: Generate Output ----

message("--- Step 7: Generating output ---")

generate_all_output(panel, fiscal, costs, costs_table, historical,
                    config, output_dir)
message("")

# ---- Step 8: Archive to Vintage Folder ----

message("--- Step 8: Archiving ---")

# Copy key outputs to the data vintage folder
archive_files <- c("household_cost_impacts.csv", "projection_vintage_panel.csv",
                   "summary.md")
for (f in archive_files) {
  src <- file.path(output_dir, f)
  if (file.exists(src)) {
    file.copy(src, file.path(data_dir, f), overwrite = TRUE)
  }
}

message(sprintf("Pipeline complete.\n  Data archive: %s\n  Output:       %s\n",
                data_dir, output_dir))

message("=== Done ===")
