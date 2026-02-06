# main.R — Entry point for Deficits-Rates-Households pipeline
#
# Applies published Laubach-framework elasticities to CBO legislative
# decomposition vintages to track how enacted legislation contributes
# to Treasury yields and household borrowing costs.
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

message("=== Deficits, Rates, and Household Costs: Legislative Decomposition Tracker ===\n")

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

# ---- Step 1: Fetch CBO GitHub Data (optional validation) ----

message("--- Step 1: Fetching CBO GitHub data (optional validation) ---")

cbo_github <- tryCatch({
  fetch_cbo_github(config)
}, error = function(e) {
  message(sprintf("  NOTE: %s", e$message))
  message("  Continuing without GitHub data (not needed for legislative decomposition)...")
  list(baselines = NULL, debt_at_horizon = data.frame(), all_debt = NULL,
       dependencies = data.frame(source = character(), series = character(),
                                 url = character(), retrieved_at = character(),
                                 stringsAsFactors = FALSE))
})

save_cbo_github(cbo_github, data_dir)
message("")

# ---- Step 2: Fetch FRED Data (consumer rate context) ----

message("--- Step 2: Fetching FRED data (consumer rate context) ---")

fred_results <- fetch_fred_data(config)
save_fred_data(fred_results, data_dir)
message("")

# ---- Step 3: Parse CBO Excel Files (Budget + Economic + Decomposition) ----

message("--- Step 3: Parsing CBO Excel files (Budget, Economic, & Decomposition) ---")

cbo_excel <- tryCatch({
  parse_cbo_excel_files(config)
}, error = function(e) {
  message(sprintf("  ERROR: %s", e$message))
  list(budget_vintages = data.frame(), econ_vintages = data.frame(),
       decomp_vintages = data.frame(),
       dependencies = data.frame(
         source = character(), series = character(),
         url = character(), retrieved_at = character(),
         stringsAsFactors = FALSE
  ))
})

save_cbo_excel(cbo_excel, data_dir)
message("")

# ---- Step 4: Build Legislative Decomposition Panel ----

message("--- Step 4: Building legislative decomposition panel ---")

panel <- build_dataset(cbo_excel, config)
save_dataset(panel, data_dir)
message("")

# ---- Step 5: Compute Fiscal Contribution (Two Scenarios) ----

message("--- Step 5: Computing fiscal contribution ---")

fiscal <- compute_fiscal_contribution(panel, coefs, config)
historical <- compute_historical_contributions(panel, coefs, config)
message("")

# ---- Step 6: Compute Household Costs ----

message("--- Step 6: Computing household cost impacts ---")

# Use the "since_2015" scenario as the primary for household costs
primary_scenario <- fiscal[["since_2015"]] %||% fiscal[[1]]
costs <- compute_household_costs(primary_scenario, coefs)
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
