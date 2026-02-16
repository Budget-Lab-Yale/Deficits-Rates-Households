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
source(file.path(.repo_root, "src", "data", "parse_cbo_eval_csv.R"))
source(file.path(.repo_root, "src", "data", "build_dataset.R"))
source(file.path(.repo_root, "src", "model", "fiscal_contribution.R"))
source(file.path(.repo_root, "src", "model", "amortize.R"))
source(file.path(.repo_root, "src", "output", "generate_output.R"))

# ---- Parse Arguments ----

args <- commandArgs(trailingOnly = TRUE)
config_path <- if (length(args) >= 1) args[1] else NULL

# ---- Load Configuration ----

message("=== Deficits, Rates, and Household Costs: Fiscal-Policy Decomposition Tracker ===\n")

config <- read_config(config_path)
coefs  <- read_coefficients()

message(sprintf("Sensitivity (preferred): %.1f bp/pp debt/GDP", coefs$elasticity$preferred))
message(sprintf("Projection horizon:     %d years", config$projection_horizon %||% 5))
message(sprintf("CBO data source:        %s", config$cbo_data_source %||% "excel_legacy"))
message(sprintf("Fetch CBO GitHub:       %s", ifelse(config$fetch$cbo_github, "enabled", "disabled")))
message(sprintf("Fetch FRED:             %s", ifelse(config$fetch$fred, "enabled", "disabled")))
message(sprintf("Data root:              %s\n", config$data_root))

# ---- Create Output Directories ----

vintage <- format(Sys.time(), "%Y%m%d_%H%M%S")
data_dir <- create_vintage_dir(config, vintage = vintage)
output_dir <- file.path(.repo_root, config$output_dir)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

message(sprintf("Data vintage:           %s\n", data_dir))

# ---- Step 1: Fetch CBO GitHub Data (optional validation) ----

message("--- Step 1: Fetching CBO GitHub data (optional validation) ---")

if (config$fetch$cbo_github) {
  cbo_github <- fetch_cbo_github(config)
  save_cbo_github(cbo_github, data_dir)
} else {
  message("  Skipped CBO GitHub fetch (fetch.cbo_github=false).")
  append_dependencies(data_dir, make_dependency_row(
    dependency_class = "skipped",
    required = FALSE,
    status = "skipped",
    source = "CBO GitHub",
    series = "baselines.csv (Debt Held by the Public)",
    url = config$cbo_github_url,
    interface = config$interface,
    version = config$version,
    vintage = vintage,
    notes = "Fetch disabled by runtime config"
  ))
}
message("")

# ---- Step 2: Fetch FRED Data (consumer rate context) ----

message("--- Step 2: Fetching FRED data (consumer rate context) ---")

if (config$fetch$fred) {
  fred_results <- fetch_fred_data(config)
  save_fred_data(fred_results, data_dir)
} else {
  message("  Skipped FRED fetch (fetch.fred=false).")
  append_dependencies(data_dir, make_dependency_row(
    dependency_class = "skipped",
    required = FALSE,
    status = "skipped",
    source = "FRED",
    series = "THREEFYTP10,MORTGAGE30US,TERMCBAUTO48NS,DPRIME",
    url = "https://fred.stlouisfed.org/",
    interface = config$interface,
    version = config$version,
    vintage = vintage,
    notes = "Fetch disabled by runtime config"
  ))
}
message("")

# ---- Step 3: Parse CBO Data (CSV-primary or legacy Excel) ----

message("--- Step 3: Parsing CBO fiscal/GDP source data ---")

if (identical(config$cbo_data_source, "eval_csv_primary")) {
  cbo_excel <- parse_cbo_eval_primary(config)
} else {
  cbo_excel <- parse_cbo_excel_files(config)
}

save_cbo_excel(cbo_excel, data_dir)
message("")

# ---- Step 4: Build Legislative Decomposition Panel ----

message("--- Step 4: Building fiscal-policy decomposition panel ---")

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
