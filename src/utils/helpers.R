# helpers.R — Shared utility functions for the Deficits-Rates-Households pipeline

library(yaml)

# ---- Null-coalescing operator ----

`%||%` <- function(a, b) if (!is.null(a)) a else b

# ---- Configuration ----

read_config <- function(path = NULL) {
  if (is.null(path)) {
    path <- file.path(find_repo_root(), "config", "runtime.yaml")
  }
  yaml::read_yaml(path)
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
  path
}

# ---- Dependency Tracking ----

write_dependencies_csv <- function(dir, deps_df) {
  write.csv(deps_df, file.path(dir, "dependencies.csv"), row.names = FALSE)
}

append_dependencies <- function(dir, new_deps) {
  deps_path <- file.path(dir, "dependencies.csv")
  if (file.exists(deps_path)) {
    existing <- read.csv(deps_path, stringsAsFactors = FALSE)
    combined <- rbind(existing, new_deps)
  } else {
    combined <- new_deps
  }
  write.csv(combined, deps_path, row.names = FALSE)
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
