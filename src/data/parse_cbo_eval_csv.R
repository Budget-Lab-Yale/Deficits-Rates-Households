# parse_cbo_eval_csv.R — CSV-primary ingestion from CBO eval-projections data
#
# Primary inputs:
#   - baselines.csv
#   - baseline_changes.csv
#
# This module builds fiscal-policy decomposition vintages from CSV data,
# then appends the latest Excel vintage (e.g., 2026-02) for data not yet
# reflected in the CBO eval-projections repository.

library(dplyr)

parse_cbo_eval_primary <- function(config) {
  eval_dir <- resolve_path(config$cbo_eval_dir)
  baselines_path <- resolve_path(config$cbo_eval_baselines_csv %||%
                                   file.path(eval_dir, "baselines.csv"))
  changes_path <- resolve_path(config$cbo_eval_changes_csv %||%
                                 file.path(eval_dir, "baseline_changes.csv"))

  if (!file.exists(baselines_path)) {
    stop(sprintf("Missing baselines CSV: %s", baselines_path))
  }
  if (!file.exists(changes_path)) {
    stop(sprintf("Missing baseline changes CSV: %s", changes_path))
  }

  message(sprintf("  Reading CBO eval CSVs:\n    baselines: %s\n    changes:   %s",
                  baselines_path, changes_path))

  baselines <- read.csv(baselines_path, stringsAsFactors = FALSE)
  changes <- read.csv(changes_path, stringsAsFactors = FALSE)

  req_base <- c("baseline_date")
  req_changes <- c("component", "category", "change_category",
                   "changes_baseline_date", "projected_fiscal_year", "value")

  missing_base <- setdiff(req_base, names(baselines))
  if (length(missing_base) > 0) {
    stop(sprintf("baselines.csv missing required columns: %s",
                 paste(missing_base, collapse = ", ")))
  }
  missing_changes <- setdiff(req_changes, names(changes))
  if (length(missing_changes) > 0) {
    stop(sprintf("baseline_changes.csv missing required columns: %s",
                 paste(missing_changes, collapse = ", ")))
  }

  baselines$baseline_date <- as.Date(baselines$baseline_date)
  changes$changes_baseline_date <- as.Date(changes$changes_baseline_date)

  if (any(is.na(baselines$baseline_date))) {
    stop("Failed to parse one or more baseline_date values in baselines.csv")
  }
  if (any(is.na(changes$changes_baseline_date))) {
    stop("Failed to parse one or more changes_baseline_date values in baseline_changes.csv")
  }

  deps <- rbind(
    make_dependency_row(
      dependency_class = "local_file",
      required = TRUE,
      status = "ok",
      source = "CBO eval-projections",
      series = "baselines.csv",
      url = baselines_path,
      interface = config$interface,
      version = config$version,
      vintage = format(Sys.Date(), "%Y-%m-%d"),
      notes = sprintf("%d rows", nrow(baselines))
    ),
    make_dependency_row(
      dependency_class = "local_file",
      required = TRUE,
      status = "ok",
      source = "CBO eval-projections",
      series = "baseline_changes.csv",
      url = changes_path,
      interface = config$interface,
      version = config$version,
      vintage = format(Sys.Date(), "%Y-%m-%d"),
      notes = sprintf("%d rows", nrow(changes))
    )
  )

  # Build the 2015+ budget-vintage calendar from local Budget Projections files.
  start_vintage <- as.Date(config$csv_sample_start_vintage %||% "2015-08-01")
  if (is.na(start_vintage)) {
    stop("csv_sample_start_vintage is invalid")
  }

  latest_append_vintage <- as.Date(config$latest_excel_append_vintage %||% "2026-02-01")
  if (is.na(latest_append_vintage)) {
    stop("latest_excel_append_vintage is invalid")
  }

  all_budget_vintages <- get_budget_projection_vintages(config)
  if (length(all_budget_vintages) == 0) {
    stop("No budget projection vintages found in cbo_budget_dir")
  }

  max_csv_vintage <- max(baselines$baseline_date, na.rm = TRUE)
  calendar <- all_budget_vintages[
    all_budget_vintages >= start_vintage &
      all_budget_vintages <= max_csv_vintage
  ]

  if (length(calendar) == 0) {
    stop(sprintf("No budget vintages between %s and max CSV baseline %s",
                 format(start_vintage, "%Y-%m-%d"),
                 format(max_csv_vintage, "%Y-%m-%d")))
  }

  message(sprintf("  CSV calendar vintages: %d (%s to %s)",
                  length(calendar),
                  format(min(calendar), "%Y-%m"),
                  format(max(calendar), "%Y-%m")))

  decomp <- build_decomp_from_changes(changes, baselines, calendar, config)

  gdp_result <- load_gdp_vintages(config)
  econ <- gdp_result$vintages
  deps <- rbind(deps, gdp_result$dependencies)

  # Append latest Excel vintage (currently 2026-02), including GDP rows.
  if (isTRUE(config$append_latest_excel %||% TRUE)) {
    append <- parse_latest_excel_append(config, latest_append_vintage)

    decomp <- rbind(decomp, append$decomp)
    econ <- rbind(econ, append$econ)
    econ <- econ[order(econ$vintage_date, econ$year), ]
    econ <- econ[!duplicated(econ[, c("vintage_date", "year")], fromLast = TRUE), ]

    deps <- rbind(deps, append$dependencies)
  }

  decomp <- decomp[order(decomp$vintage_date), ]
  rownames(decomp) <- NULL

  message(sprintf("  Decomp total: %d vintages (%s to %s)",
                  nrow(decomp),
                  format(min(decomp$vintage_date), "%Y-%m"),
                  format(max(decomp$vintage_date), "%Y-%m")))

  list(
    budget_vintages = data.frame(),
    econ_vintages = econ,
    decomp_vintages = decomp,
    dependencies = deps
  )
}


build_decomp_from_changes <- function(changes, baselines, calendar, config) {
  horizon <- config$projection_horizon %||% 10
  start_offset <- config$window_start_offset %||% 0

  if (horizon <= 0) stop("projection_horizon must be positive")
  if (start_offset < 0) stop("window_start_offset must be >= 0")

  ch <- changes[
    tolower(changes$component) == "deficit" &
      tolower(changes$category) == "total" &
      tolower(changes$change_category) == "legislative",
  ]

  if (nrow(ch) == 0) {
    stop("No legislative deficit rows found in baseline_changes.csv")
  }

  ref_dates <- sort(unique(c(
    as.Date(baselines$baseline_date),
    as.Date(changes$changes_baseline_date),
    as.Date(calendar)
  )))

  rows <- vector("list", length(calendar))

  for (i in seq_along(calendar)) {
    vd <- as.Date(calendar[i])
    vy <- as.integer(format(vd, "%Y"))
    target_years <- (vy + start_offset):(vy + start_offset + horizon - 1)

    sub <- ch[ch$changes_baseline_date == vd, c("projected_fiscal_year", "value")]

    if (nrow(sub) == 0) {
      # Explicitly retain zero-legislative vintages in the chain.
      value_horizon <- 0
      source_note <- "baseline_changes.csv (explicit zero: no legislative rows)"
    } else {
      dup_years <- unique(sub$projected_fiscal_year[duplicated(sub$projected_fiscal_year)])
      if (length(dup_years) > 0) {
        stop(sprintf("Duplicate projected_fiscal_year values for %s: %s",
                     format(vd, "%Y-%m"), paste(dup_years, collapse = ", ")))
      }

      miss <- setdiff(target_years, sub$projected_fiscal_year)
      if (length(miss) > 0) {
        stop(sprintf("Missing legislative annual values for %s required years: %s",
                     format(vd, "%Y-%m"), paste(miss, collapse = ", ")))
      }

      # CSV sign convention: positive numbers reduce deficits.
      # Normalize to positive = increases deficits/debt.
      value_horizon <- -sum(sub$value[sub$projected_fiscal_year %in% target_years])
      source_note <- "baseline_changes.csv"
    }

    if (i == 1) {
      prior <- ref_dates[ref_dates < vd]
      if (length(prior) == 0) {
        stop(sprintf("Cannot infer since_date for first vintage %s", format(vd, "%Y-%m-%d")))
      }
      since_date <- as.Date(max(prior))
    } else {
      since_date <- as.Date(calendar[i - 1])
    }

    rows[[i]] <- data.frame(
      vintage_date = vd,
      since_date = since_date,
      legislative_deficit_5yr_bn = value_horizon,
      legislative_deficit_window_bn = value_horizon,
      harmonized_years = paste(target_years, collapse = "-"),
      reported_window_label = sprintf("%d-%d", min(target_years), max(target_years)),
      reported_window_span_years = horizon,
      sheet_name = source_note,
      stringsAsFactors = FALSE
    )
  }

  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out[order(out$vintage_date), ]
}


load_gdp_vintages <- function(config) {
  gdp_path <- resolve_path(config$cbo_gdp_vintage_csv)
  if (!file.exists(gdp_path)) {
    gdp_path <- find_latest_archived_gdp_table(config)
  }

  if (!file.exists(gdp_path)) {
    stop("No GDP vintage table found (cbo_gdp_vintage_csv or archived fallback)")
  }

  gdp <- read.csv(gdp_path, stringsAsFactors = FALSE)

  # Accept either canonical output names or a small alias set.
  if (!("vintage_date" %in% names(gdp))) {
    stop(sprintf("GDP table missing vintage_date column: %s", gdp_path))
  }
  if (!("year" %in% names(gdp))) {
    stop(sprintf("GDP table missing year column: %s", gdp_path))
  }
  if (!("gdp_bn" %in% names(gdp))) {
    stop(sprintf("GDP table missing gdp_bn column: %s", gdp_path))
  }

  gdp$vintage_date <- as.Date(gdp$vintage_date)
  if (any(is.na(gdp$vintage_date))) {
    stop(sprintf("GDP table contains unparsable vintage_date values: %s", gdp_path))
  }

  if (any(is.na(gdp$gdp_bn))) {
    stop(sprintf("GDP table contains NA gdp_bn values: %s", gdp_path))
  }

  dep <- make_dependency_row(
    dependency_class = "local_file",
    required = TRUE,
    status = "ok",
    source = "CBO GDP vintages",
    series = "GDP vintage table",
    url = gdp_path,
    interface = config$interface,
    version = config$version,
    vintage = format(Sys.Date(), "%Y-%m-%d"),
    notes = sprintf("%d vintage-year rows", nrow(gdp))
  )

  list(vintages = gdp, dependencies = dep)
}


find_latest_archived_gdp_table <- function(config) {
  root <- resolve_path(config$data_root)
  iface <- config$interface %||% "Deficits-Rates-Households"
  ver <- config$version %||% "v1"

  cand <- Sys.glob(file.path(root, iface, ver, "*", "cbo_excel_gdp.csv"))
  if (length(cand) == 0) return(NA_character_)

  vint <- basename(dirname(cand))
  idx <- order(vint, decreasing = TRUE)
  cand[idx][1]
}


parse_latest_excel_append <- function(config, append_vintage_date) {
  if (is.na(append_vintage_date)) {
    stop("latest_excel_append_vintage is invalid")
  }

  vintage_key <- format(append_vintage_date, "%Y-%m")
  lookup <- DECOMP_LOOKUP[[vintage_key]]
  if (is.null(lookup)) {
    stop(sprintf("DECOMP_LOOKUP missing entry for latest append vintage %s", vintage_key))
  }

  budget_file <- find_excel_file_for_vintage(
    dir_path = resolve_path(config$cbo_budget_dir),
    pattern = "51118.*\\.xls(x?)$",
    target_vintage = append_vintage_date
  )
  econ_file <- find_excel_file_for_vintage(
    dir_path = resolve_path(config$cbo_econ_dir),
    pattern = "51135.*\\.xls(x?)$",
    target_vintage = append_vintage_date
  )

  if (is.na(budget_file)) {
    stop(sprintf("Could not find budget Excel file for append vintage %s", vintage_key))
  }
  if (is.na(econ_file)) {
    stop(sprintf("Could not find economic Excel file for append vintage %s", vintage_key))
  }

  message(sprintf("  Appending latest Excel vintage %s", vintage_key))

  decomp <- parse_one_decomp(budget_file, lookup, append_vintage_date, config)
  econ <- parse_one_econ_file(econ_file, append_vintage_date)
  if (is.null(econ) || nrow(econ) == 0) {
    stop(sprintf("Failed to parse GDP rows from latest econ Excel: %s", econ_file))
  }

  deps <- rbind(
    make_dependency_row(
      dependency_class = "local_file",
      required = TRUE,
      status = "ok",
      source = "CBO Excel Decomp",
      series = sprintf("Fiscal-policy decomposition (%s)", format(append_vintage_date, "%b %Y")),
      url = budget_file,
      interface = config$interface,
      version = config$version,
      vintage = vintage_key,
      notes = sprintf("Sheet: %s", lookup$sheet)
    ),
    make_dependency_row(
      dependency_class = "local_file",
      required = TRUE,
      status = "ok",
      source = "CBO Excel",
      series = sprintf("Economic Projections (%s)", format(append_vintage_date, "%b %Y")),
      url = econ_file,
      interface = config$interface,
      version = config$version,
      vintage = vintage_key,
      notes = "Latest-vintage GDP append"
    )
  )

  list(decomp = decomp, econ = econ, dependencies = deps)
}


get_budget_projection_vintages <- function(config) {
  budget_dir <- resolve_path(config$cbo_budget_dir)
  if (!dir.exists(budget_dir)) {
    stop(sprintf("Budget Projections directory not found: %s", budget_dir))
  }

  files <- list.files(budget_dir, pattern = "51118.*\\.xls(x?)$",
                      full.names = TRUE, ignore.case = TRUE)
  if (length(files) == 0) {
    stop(sprintf("No 51118 budget projection files found in %s", budget_dir))
  }

  vint <- as.Date(vapply(basename(files), extract_vintage_from_filename, as.Date(NA)))
  vint <- sort(unique(vint[!is.na(vint)]))
  vint
}


find_excel_file_for_vintage <- function(dir_path, pattern, target_vintage) {
  if (!dir.exists(dir_path)) return(NA_character_)

  files <- list.files(dir_path, pattern = pattern,
                      full.names = TRUE, ignore.case = TRUE)
  if (length(files) == 0) return(NA_character_)

  vint <- as.Date(vapply(basename(files), extract_vintage_from_filename, as.Date(NA)))
  idx <- which(vint == target_vintage)

  if (length(idx) == 0) return(NA_character_)
  if (length(idx) > 1) {
    stop(sprintf("Multiple files found for vintage %s in %s",
                 format(target_vintage, "%Y-%m"), dir_path))
  }

  files[idx]
}
