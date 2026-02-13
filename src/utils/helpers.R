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
  config$parse_budget_validation <- isTRUE(config$parse_budget_validation %||% FALSE)
  config$cbo_data_source <- config$cbo_data_source %||% "eval_csv_primary"
  config$append_latest_excel <- isTRUE(config$append_latest_excel %||% TRUE)
  config$csv_sample_start_vintage <- config$csv_sample_start_vintage %||% "2015-08-01"
  config$latest_excel_append_vintage <- config$latest_excel_append_vintage %||% "2026-02-01"

  if (is.null(config$fetch)) config$fetch <- list()
  config$fetch$cbo_github <- isTRUE(config$fetch$cbo_github %||% FALSE)
  config$fetch$fred <- isTRUE(config$fetch$fred %||% FALSE)

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
  path
}

# ---- Dependency Tracking ----

dependency_columns <- function() {
  c(
    "dependency_class",  # external_api | local_file | parser | skipped
    "required",          # TRUE if failure should stop run
    "status",            # ok | skipped | failed
    "source",
    "series",
    "url",
    "interface",
    "version",
    "vintage",
    "notes",
    "retrieved_at"
  )
}

empty_dependency_frame <- function() {
  cols <- dependency_columns()
  out <- as.data.frame(setNames(replicate(length(cols), character(0), simplify = FALSE), cols))
  out$required <- logical(0)
  out
}

make_dependency_row <- function(dependency_class, required, status,
                                source, series, url = NA_character_,
                                interface = NA_character_, version = NA_character_,
                                vintage = NA_character_, notes = NA_character_) {
  data.frame(
    dependency_class = dependency_class,
    required = required,
    status = status,
    source = source,
    series = series,
    url = url,
    interface = interface,
    version = version,
    vintage = vintage,
    notes = notes,
    retrieved_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    stringsAsFactors = FALSE
  )
}

coerce_dependencies <- function(df) {
  if (is.null(df) || nrow(df) == 0) return(empty_dependency_frame())

  cols <- dependency_columns()
  missing <- setdiff(cols, names(df))
  if (length(missing) > 0) {
    for (m in missing) {
      df[[m]] <- if (m == "required") FALSE else NA_character_
    }
  }
  df <- df[, cols]
  df$required <- as.logical(df$required)
  df$status <- as.character(df$status)
  df
}

write_dependencies_csv <- function(dir, deps_df) {
  write.csv(coerce_dependencies(deps_df), file.path(dir, "dependencies.csv"), row.names = FALSE)
}

append_dependencies <- function(dir, new_deps) {
  new_deps <- coerce_dependencies(new_deps)
  if (nrow(new_deps) == 0) return(invisible(NULL))

  deps_path <- file.path(dir, "dependencies.csv")
  if (file.exists(deps_path)) {
    existing <- coerce_dependencies(read.csv(deps_path, stringsAsFactors = FALSE))
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
