# helpers.R — Shared utility functions for the Deficits-Rates-Households pipeline

library(yaml)

# ---- Null-coalescing operator ----

`%||%` <- function(a, b) if (!is.null(a)) a else b

# ---- Configuration ----

read_config <- function(path = NULL) {
  if (is.null(path)) {
    path <- file.path(find_repo_root(), "config", "runtime.yaml")
  }
  apply_config_defaults(yaml::read_yaml(path))
}

read_coefficients <- function(path = NULL) {
  if (is.null(path)) {
    path <- file.path(find_repo_root(), "config", "coefficients.yaml")
  }
  yaml::read_yaml(path)
}

find_repo_root <- function() {
  candidates <- c(
    getwd(),
    if (exists(".repo_root")) .repo_root else NULL
  )
  for (d in candidates) {
    if (file.exists(file.path(d, "Deficits-Rates-Households.Rproj"))) return(d)
    parent <- dirname(d)
    if (file.exists(file.path(parent, "Deficits-Rates-Households.Rproj"))) return(parent)
  }
  getwd()
}

apply_config_defaults <- function(config) {
  config$projection_horizon <- config$projection_horizon %||% 10
  config$window_start_offset <- config$window_start_offset %||% 0
  config$max_econ_lag_days <- config$max_econ_lag_days %||% 365
  config$cbo_data_source <- config$cbo_data_source %||% "eval_csv_primary"
  config$append_latest_excel <- isTRUE(config$append_latest_excel %||% TRUE)
  config$csv_sample_start_vintage <- config$csv_sample_start_vintage %||% "2015-08-01"
  config$latest_excel_append_vintage <- config$latest_excel_append_vintage %||% "2026-02-01"

  if (is.null(config$scenarios)) {
    config$scenarios <- list(
      since_2015 = list(start_vintage = "2015-08-01", label = "Since 2015"),
      since_2022 = list(start_vintage = "2022-05-01", label = "Since 2022")
    )
  }

  config
}

# ---- Data Path Management (Budget Lab convention) ----

get_data_path <- function(config, interface = NULL, version = NULL, vintage = NULL) {
  root <- config$data_root
  if (!startsWith(root, "/")) {
    root <- file.path(find_repo_root(), root)
  }
  iface <- interface %||% config$interface
  ver   <- version %||% config$version
  vint  <- vintage %||% format(Sys.time(), "%Y%m%d_%H%M%S")

  file.path(root, iface, ver, vint)
}

create_vintage_dir <- function(config, ...) {
  path <- get_data_path(config, ...)
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(path)) {
    warning(sprintf("Could not create data archive directory: %s — archiving will be skipped.", path))
    return(NULL)
  }
  path
}

# ---- Manifest ----

write_manifest <- function(dir, config, vintage_counts) {
  lines <- c(
    sprintf("Pipeline run: %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
    sprintf("Data source:  %s", config$cbo_data_source %||% "excel_legacy"),
    sprintf("Horizon:      %d years", config$projection_horizon %||% 10),
    "",
    "Vintage counts:"
  )
  for (nm in names(vintage_counts)) {
    lines <- c(lines, sprintf("  %s: %d", nm, vintage_counts[[nm]]))
  }
  writeLines(lines, file.path(dir, "manifest.txt"))
}

# ---- Amortization Math ----

amortize_annual_payment <- function(principal, annual_rate_pct, term_months) {
  # Compute annual payment (principal + interest) for a fixed-rate amortizing loan.
  if (annual_rate_pct <= 0) return(principal * 12 / term_months)

  r <- annual_rate_pct / 100 / 12  # Monthly rate
  n <- term_months
  monthly_payment <- principal * r * (1 + r)^n / ((1 + r)^n - 1)
  monthly_payment * 12
}

amortize_total_cost <- function(principal, annual_rate_pct, term_months) {
  # Compute total cost over the life of the loan.
  if (annual_rate_pct <= 0) return(principal)

  r <- annual_rate_pct / 100 / 12
  n <- term_months
  monthly_payment <- principal * r * (1 + r)^n / ((1 + r)^n - 1)
  monthly_payment * n
}

# ---- Formatting ----

format_dollars <- function(x) {
  formatC(round(x), format = "f", big.mark = ",", digits = 0)
}

format_bps <- function(x) {
  sprintf("%+.0f bp", x)
}

format_pp <- function(x) {
  sprintf("%+.1f pp", x)
}
