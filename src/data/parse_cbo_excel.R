# parse_cbo_excel.R — Parse CBO Budget and Economic Projections Excel files
#
# Budget Projections (51118-*): Extracts projected debt/GDP ratios directly
#   from CBO's Table B-3 / Table 1-3 / Table 1-2 (naming varies by vintage).
#   These are the authoritative values.
#
# Economic Projections (51135-*): Extracts projected nominal GDP in billions
#   from the "3. Fiscal Year" sheet. Used for validation and as a vintaged
#   denominator if computing debt/GDP from GitHub debt data.
#
# Handles two layout eras:
#   Pre-2023: 3 label columns (A-C), data starts col D, year headers are integers
#   2023+:    2 label columns (A-B), data starts col B, "Actual, YYYY" in first data cell
#
# Also handles: trailing spaces in sheet names, varying table numbering
# (Table 1-2, 1-3, B-3, Table 2, Table 3), and the 2023-12 short-range special file.

library(readxl)
library(dplyr)

# ===========================================================================
# Public API
# ===========================================================================

parse_cbo_excel_files <- function(config) {
  # Parse Budget, Economic, and Legislative Decomposition data. Returns a list with:
  #   $budget_vintages: debt/GDP by (vintage_date, year)
  #   $econ_vintages:   nominal GDP by (vintage_date, year)
  #   $decomp_vintages: legislative deficit decomposition by vintage
  #   $dependencies:    provenance records

  if (isTRUE(config$parse_budget_validation %||% FALSE)) {
    budget_result <- parse_budget_projections_dir(config)
  } else {
    budget_result <- list(
      vintages = data.frame(),
      dependencies = make_dependency_row(
        dependency_class = "skipped",
        required = FALSE,
        status = "skipped",
        source = "CBO Excel",
        series = "Budget Projections debt/GDP validation",
        url = config$cbo_budget_dir,
        interface = config$interface,
        version = config$version,
        vintage = format(Sys.time(), "%Y%m%d_%H%M%S"),
        notes = "Skipped by runtime config (parse_budget_validation=false)"
      )
    )
  }
  econ_result   <- parse_econ_projections_dir(config)
  decomp_result <- parse_legislative_decomposition(config)

  list(
    budget_vintages = budget_result$vintages,
    econ_vintages   = econ_result$vintages,
    decomp_vintages = decomp_result$vintages,
    dependencies    = rbind(budget_result$dependencies,
                            econ_result$dependencies,
                            decomp_result$dependencies)
  )
}


save_cbo_excel <- function(cbo_excel, output_dir) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  if (!is.null(cbo_excel$budget_vintages) && nrow(cbo_excel$budget_vintages) > 0) {
    write.csv(cbo_excel$budget_vintages,
              file.path(output_dir, "cbo_excel_debt_gdp.csv"), row.names = FALSE)
  }

  if (!is.null(cbo_excel$econ_vintages) && nrow(cbo_excel$econ_vintages) > 0) {
    write.csv(cbo_excel$econ_vintages,
              file.path(output_dir, "cbo_excel_gdp.csv"), row.names = FALSE)
  }

  if (!is.null(cbo_excel$decomp_vintages) && nrow(cbo_excel$decomp_vintages) > 0) {
    write.csv(cbo_excel$decomp_vintages,
              file.path(output_dir, "cbo_legislative_decomp.csv"), row.names = FALSE)
  }

  append_dependencies(output_dir, cbo_excel$dependencies)
  invisible(output_dir)
}


# ===========================================================================
# Budget Projections (Debt / GDP)
# ===========================================================================

parse_budget_projections_dir <- function(config) {
  budget_dir <- resolve_path(config$cbo_budget_dir %||% config$cbo_excel_dir)

  if (!dir.exists(budget_dir)) {
    message(sprintf("  Budget Projections directory not found: %s", budget_dir))
    return(empty_result())
  }

  xlsx_files <- list.files(budget_dir, pattern = "51118.*\\.xls(x?)$",
                           full.names = TRUE, ignore.case = TRUE)

  if (length(xlsx_files) == 0) {
    message("  No Budget Projections files found (pattern: 51118*.xls[x])")
    return(empty_result())
  }

  message(sprintf("  Found %d Budget Projections file(s)", length(xlsx_files)))

  all_vintages <- list()
  deps <- empty_deps()

  for (xlsx_path in xlsx_files) {
    fname <- basename(xlsx_path)
    vintage_date <- extract_vintage_from_filename(fname)
    if (is.na(vintage_date)) {
      message(sprintf("  %s: cannot parse vintage date; skipping", fname))
      next
    }

    message(sprintf("  Parsing budget: %s (%s)", fname, format(vintage_date, "%b %Y")))

    parsed <- parse_one_budget_file(xlsx_path, vintage_date)
    if (!is.null(parsed) && nrow(parsed) > 0) {
      all_vintages[[fname]] <- parsed
      message(sprintf("    -> %d years, debt/GDP: %.1f%% to %.1f%%",
                      nrow(parsed),
                      min(parsed$debt_gdp_pct, na.rm = TRUE),
                      max(parsed$debt_gdp_pct, na.rm = TRUE)))
    } else {
      message(sprintf("    -> FAILED to parse"))
    }

    deps <- rbind(deps, make_dependency_row(
      dependency_class = "local_file",
      required = FALSE,
      status = "ok",
      source = "CBO Excel",
      series = sprintf("Budget Projections (%s)", format(vintage_date, "%b %Y")),
      url = xlsx_path,
      interface = config$interface,
      version = config$version,
      vintage = format(vintage_date, "%Y-%m"),
      notes = "Budget debt/GDP validation file"
    ))
  }

  if (length(all_vintages) == 0) {
    message("  WARNING: No Budget Projections files parsed successfully")
    return(list(vintages = data.frame(), dependencies = deps))
  }

  vintages <- do.call(rbind, all_vintages)
  rownames(vintages) <- NULL
  vintages <- vintages[order(vintages$vintage_date, vintages$year), ]

  message(sprintf("  Budget total: %d vintage-year pairs across %d vintages",
                  nrow(vintages), length(unique(vintages$vintage_date))))

  list(vintages = vintages, dependencies = deps)
}


parse_one_budget_file <- function(xlsx_path, vintage_date) {
  sheets <- tryCatch(excel_sheets(xlsx_path), error = function(e) character(0))
  if (length(sheets) == 0) return(NULL)

  # ---- Find the debt sheet ----
  # Strategy: search for a sheet whose early rows contain "Projections of Federal Debt"
  # Prefer sheets WITHOUT trailing spaces (compact format, fewer header rows)
  target_sheet <- find_debt_sheet(xlsx_path, sheets)
  if (is.null(target_sheet)) {
    message(sprintf("    No debt sheet found. Sheets: %s",
                    paste(sheets, collapse = ", ")))
    return(NULL)
  }

  message(sprintf("    Using sheet: '%s'", target_sheet))

  # ---- Read sheet ----
  raw <- tryCatch(
    read_excel(xlsx_path, sheet = target_sheet, col_names = FALSE),
    error = function(e) NULL
  )
  if (is.null(raw)) return(NULL)

  nr <- nrow(raw)
  nc <- ncol(raw)

  # ---- Find year header row ----
  year_info <- find_year_row(raw, max_scan = min(15, nr))
  if (is.null(year_info)) {
    message("    Cannot find year header row")
    return(NULL)
  }

  years     <- year_info$years
  year_cols <- year_info$cols
  year_row  <- year_info$row
  message(sprintf("    Year row: %d, cols %d-%d, years %d-%d",
                  year_row, min(year_cols), max(year_cols),
                  min(years), max(years)))

  # ---- Find debt/GDP row ----
  # Scan downward from year row for "percentage of GDP" or "as a percentage of gdp"
  # There may be multiple such rows (beginning-of-year vs end-of-year debt).
  # We want the one after "End of the Year" / "end of the year".
  debt_gdp_row <- find_debt_gdp_row(raw, year_row, nr, nc)
  if (is.null(debt_gdp_row)) {
    message("    Cannot find debt/GDP row")
    return(NULL)
  }

  message(sprintf("    Debt/GDP row: %d", debt_gdp_row))

  # ---- Extract values ----
  values <- suppressWarnings(
    as.numeric(as.character(unlist(raw[debt_gdp_row, year_cols])))
  )

  result <- data.frame(
    vintage_date = vintage_date,
    year         = years,
    debt_gdp_pct = values,
    source       = "CBO Excel",
    stringsAsFactors = FALSE
  )
  result[!is.na(result$debt_gdp_pct), ]
}


find_debt_sheet <- function(xlsx_path, sheets) {
  # Select debt/GDP sheets using structure (year row + %GDP row), not
  # debt-related figure text in headers.
  preferred_patterns <- c(
    "^table b-3$", "^table 1-2$", "^table 1-3$", "^table 1-4$",
    "^table 1-5$", "^table 1-6$", "^table 1-7$", "^table 2$",
    "^table 3$", "^table 4-4$", "^table 5$"
  )

  inspect_sheet <- function(sheet_name) {
    raw <- tryCatch(
      read_excel(xlsx_path, sheet = sheet_name, col_names = FALSE, n_max = 120),
      error = function(e) NULL
    )
    if (is.null(raw) || nrow(raw) == 0) return(NULL)

    nr <- nrow(raw)
    nc <- ncol(raw)
    top10 <- tolower(paste(unlist(raw[1:min(10, nr), ]), collapse = " "))
    top40 <- tolower(paste(unlist(raw[1:min(40, nr), ]), collapse = " "))

    year_info <- find_year_row(raw, max_scan = min(20, nr))
    has_year <- !is.null(year_info)
    has_pct <- FALSE
    n_pct_values <- 0
    if (has_year) {
      pct_row <- find_debt_gdp_row(raw, year_info$row, nr, nc)
      has_pct <- !is.null(pct_row)
      if (has_pct) {
        pct_vals <- suppressWarnings(
          as.numeric(as.character(unlist(raw[pct_row, year_info$cols])))
        )
        n_pct_values <- sum(!is.na(pct_vals))
      }
    }

    sheet_trim <- trimws(sheet_name)
    sheet_lc <- tolower(sheet_trim)
    has_debt_text <- grepl("projections of federal debt|federal debt held|debt held by the public",
                           top40)

    score <- 0
    if (has_year) score <- score + 2
    if (has_pct) score <- score + 5
    if (n_pct_values >= 5) score <- score + 2
    if (has_pct && n_pct_values == 0) score <- score - 6
    if (has_debt_text) score <- score + 2
    if (grepl("^table\\s", sheet_lc)) score <- score + 1
    if (grepl("figure", sheet_lc)) score <- score - 6
    if (grepl("summary figure", sheet_lc)) score <- score - 4
    if (grepl("summary table", sheet_lc)) score <- score - 2
    if (grepl("supp|supplement|box|^contents?$|^content$", sheet_lc)) score <- score - 2
    if (grepl("changes in cbo", top10)) score <- score - 4

    is_preferred <- any(vapply(preferred_patterns, function(p) {
      grepl(p, sheet_lc)
    }, logical(1)))
    if (is_preferred) score <- score + 2

    list(
      sheet = sheet_name,
      score = score,
      has_year = has_year,
      has_pct = has_pct,
      n_pct_values = n_pct_values,
      has_debt_text = has_debt_text
    )
  }

  diagnostics <- lapply(sheets, inspect_sheet)
  diagnostics <- Filter(Negate(is.null), diagnostics)
  if (length(diagnostics) == 0) return(NULL)

  # First choice: structural debt/GDP candidates.
  candidates <- Filter(function(x) {
    x$has_year && x$has_pct && x$n_pct_values >= 5
  }, diagnostics)

  # Fallback: year row + debt text.
  if (length(candidates) == 0) {
    candidates <- Filter(function(x) x$has_year && x$has_debt_text, diagnostics)
  }
  if (length(candidates) == 0) {
    candidates <- Filter(function(x) x$has_year && x$has_pct, diagnostics)
  }
  if (length(candidates) == 0) return(NULL)

  scores <- vapply(candidates, `[[`, numeric(1), "score")
  best_idx <- which(scores == max(scores))
  if (length(best_idx) > 1) {
    # Tie-break toward cleaner table names (shorter trimmed names).
    name_len <- vapply(candidates[best_idx], function(x) nchar(trimws(x$sheet)), integer(1))
    best_idx <- best_idx[which.min(name_len)]
  }

  candidates[[best_idx[1]]]$sheet
}


find_year_row <- function(raw, max_scan = 15) {
  nr <- nrow(raw)
  nc <- ncol(raw)

  for (r in 1:min(max_scan, nr)) {
    row_vals <- as.character(unlist(raw[r, ]))

    # Try pure integer years first
    yr_mask <- grepl("^(19|20)\\d{2}$", trimws(row_vals))

    # Also check for "Actual, YYYY" pattern in first data cell
    actual_mask <- grepl("^Actual,?\\s*(19|20)\\d{2}$", trimws(row_vals),
                         ignore.case = TRUE)
    if (any(actual_mask)) {
      # Extract the year from the "Actual, YYYY" cell
      actual_idx <- which(actual_mask)
      for (ai in actual_idx) {
        yr_str <- gsub(".*((19|20)\\d{2}).*", "\\1", trimws(row_vals[ai]))
        row_vals[ai] <- yr_str
        yr_mask[ai] <- TRUE
      }
    }

    if (sum(yr_mask) >= 5) {
      cols  <- which(yr_mask)
      years <- as.integer(trimws(row_vals[cols]))

      # Remove duplicate years (5-yr/10-yr total columns that just show end year)
      # Keep only the first occurrence of each year
      dups <- duplicated(years)
      if (any(dups)) {
        cols  <- cols[!dups]
        years <- years[!dups]
      }

      # Also remove years that break the consecutive sequence at the end
      # (can happen when a total column year matches a non-adjacent individual year)
      if (length(years) >= 5) {
        return(list(row = r, cols = cols, years = years))
      }
    }
  }

  NULL
}


find_debt_gdp_row <- function(raw, year_row, nr, nc) {
  # Scan downward from year_row looking for "percentage of GDP" text.
  # The debt table has two sections: beginning-of-year and end-of-year.
  # We want the "as a percentage of GDP" row in the END-of-year section.
  #
  # Strategy: find all rows matching "percentage of gdp", then pick the one
  # that comes AFTER the "End of the Year" or "end of the year" marker.
  # If there's only one match, use it. If there's no "End" marker, use the last match.

  pct_rows <- integer(0)
  end_of_year_row <- NA

  for (r in (year_row + 1):min(nr, year_row + 30)) {
    row_text <- tolower(paste(as.character(unlist(raw[r, 1:min(4, nc)])), collapse = " "))

    if (grepl("end of the year|end of year", row_text)) {
      end_of_year_row <- r
    }

    if (grepl("percentage of gdp|percent of gdp|as a share of gdp", row_text)) {
      pct_rows <- c(pct_rows, r)
    }
  }

  if (length(pct_rows) == 0) return(NULL)

  # If we found the "end of year" marker, return the first pct row after it
  if (!is.na(end_of_year_row)) {
    after_end <- pct_rows[pct_rows > end_of_year_row]
    if (length(after_end) > 0) return(after_end[1])
  }

  # Otherwise return the last pct row (most likely end-of-year in a compact layout)
  # But verify it has numeric data in the year columns
  for (pr in rev(pct_rows)) {
    # Quick check: does this row have numeric values?
    test <- suppressWarnings(as.numeric(as.character(unlist(raw[pr, 2:min(6, nc)]))))
    if (any(!is.na(test) & test > 10)) return(pr)  # debt/GDP > 10% is plausible
  }

  # Fallback: first pct row
  pct_rows[1]
}


# ===========================================================================
# Economic Projections (Nominal GDP)
# ===========================================================================

parse_econ_projections_dir <- function(config) {
  econ_dir <- resolve_path(config$cbo_econ_dir)

  if (is.null(econ_dir) || !dir.exists(econ_dir)) {
    stop(sprintf("Economic Projections directory not found: %s",
                 econ_dir %||% "(not configured)"))
  }

  xlsx_files <- list.files(econ_dir, pattern = "51135.*\\.xls(x?)$",
                           full.names = TRUE, ignore.case = TRUE)

  if (length(xlsx_files) == 0) {
    stop("No Economic Projections files found (pattern: 51135*.xls[x])")
  }

  message(sprintf("  Found %d Economic Projections file(s)", length(xlsx_files)))

  all_vintages <- list()
  deps <- empty_deps()

  for (xlsx_path in xlsx_files) {
    fname <- basename(xlsx_path)
    vintage_date <- extract_vintage_from_filename(fname)
    if (is.na(vintage_date)) {
      message(sprintf("  %s: cannot parse vintage date; skipping", fname))
      next
    }

    message(sprintf("  Parsing econ: %s (%s)", fname, format(vintage_date, "%b %Y")))

    parsed <- parse_one_econ_file(xlsx_path, vintage_date)
    if (!is.null(parsed) && nrow(parsed) > 0) {
      all_vintages[[fname]] <- parsed
      message(sprintf("    -> %d years, GDP: $%.0fB to $%.0fB",
                      nrow(parsed),
                      min(parsed$gdp_bn, na.rm = TRUE),
                      max(parsed$gdp_bn, na.rm = TRUE)))
    } else {
      message(sprintf("    -> Skipped (no fiscal year GDP data)"))
    }

    deps <- rbind(deps, make_dependency_row(
      dependency_class = "local_file",
      required = TRUE,
      status = "ok",
      source = "CBO Excel",
      series = sprintf("Economic Projections (%s)", format(vintage_date, "%b %Y")),
      url = xlsx_path,
      interface = config$interface,
      version = config$version,
      vintage = format(vintage_date, "%Y-%m"),
      notes = "Economic projections source file"
    ))
  }

  if (length(all_vintages) == 0) {
    stop("No Economic Projections files parsed successfully")
  }

  vintages <- do.call(rbind, all_vintages)
  rownames(vintages) <- NULL
  vintages <- vintages[order(vintages$vintage_date, vintages$year), ]

  message(sprintf("  Econ total: %d vintage-year pairs across %d vintages",
                  nrow(vintages), length(unique(vintages$vintage_date))))

  list(vintages = vintages, dependencies = deps)
}


parse_one_econ_file <- function(xlsx_path, vintage_date) {
  sheets <- tryCatch(excel_sheets(xlsx_path), error = function(e) character(0))
  if (length(sheets) == 0) return(NULL)

  # Look for "3. Fiscal Year" sheet
  fy_sheet <- grep("fiscal year", sheets, ignore.case = TRUE, value = TRUE)
  if (length(fy_sheet) == 0) {
    # This is likely the 2023-12 special update (only has "Table 1")
    return(NULL)
  }
  fy_sheet <- fy_sheet[1]

  raw <- tryCatch(
    read_excel(xlsx_path, sheet = fy_sheet, col_names = FALSE, .name_repair = "minimal"),
    error = function(e) NULL
  )
  if (is.null(raw)) return(NULL)

  nr <- nrow(raw)
  nc <- ncol(raw)

  # ---- Find year header row ----
  year_info <- find_year_row(raw, max_scan = min(15, nr))
  if (is.null(year_info)) return(NULL)

  years     <- year_info$years
  year_cols <- year_info$cols
  year_row  <- year_info$row

  # ---- Find GDP row ----
  # Look for "Gross Domestic Product" (case-insensitive) with
  # "Billions of dollars" in the same row or adjacent column
  gdp_row <- NULL
  for (r in (year_row + 1):min(nr, year_row + 20)) {
    row_text <- tolower(paste(as.character(unlist(raw[r, 1:min(5, nc)])), collapse = " "))
    if (grepl("gross domestic product", row_text) &&
        grepl("billions of dollars", row_text)) {
      gdp_row <- r
      break
    }
  }

  if (is.null(gdp_row)) return(NULL)

  # Extract values
  values <- suppressWarnings(
    as.numeric(as.character(unlist(raw[gdp_row, year_cols])))
  )

  result <- data.frame(
    vintage_date = vintage_date,
    year         = years,
    gdp_bn       = values,
    source       = "CBO Excel",
    stringsAsFactors = FALSE
  )
  result[!is.na(result$gdp_bn), ]
}


# ===========================================================================
# Shared helpers
# ===========================================================================

extract_vintage_from_filename <- function(fname) {
  # Extract YYYY-MM from consistent naming: 51118-YYYY-MM-Budget-Projections.xlsx
  m <- regmatches(fname, regexpr("(19|20)\\d{2}-\\d{2}", fname))
  if (length(m) == 0) return(NA)
  as.Date(paste0(m[1], "-01"))
}


resolve_path <- function(path) {
  if (is.null(path)) return(NULL)
  if (!startsWith(path, "/")) {
    path <- file.path(find_repo_root(), path)
  }
  normalizePath(path, mustWork = FALSE)
}


empty_deps <- function() {
  empty_dependency_frame()
}


empty_result <- function() {
  list(vintages = data.frame(), dependencies = empty_deps())
}


# ===========================================================================
# Legislative Decomposition (Table A-1 / equivalent)
# ===========================================================================
#
# Hardcoded lookup for 2015-08 onward. Each entry specifies the exact sheet
# name, the "since" date, and whether to negate raw values to normalize to
# positive = increases the deficit.
#
# Vintages before 2015-08 are not processed (formatting too inconsistent,
# and the continuous decomposition chain only starts at 2015-08).

DECOMP_LOOKUP <- list(
  "2015-08" = list(sheet = "8. Table A-1",  since = "2015-03-01", negate = TRUE),
  "2016-01" = list(sheet = "18. Table A-1", since = "2015-08-01", negate = TRUE),
  "2016-03" = list(sheet = "Table 6",       since = "2016-01-01", negate = TRUE),
  "2016-08" = list(sheet = "Table A-1",     since = "2016-03-01", negate = TRUE),
  "2017-01" = list(sheet = "Table A-1",     since = "2016-08-01", negate = TRUE),
  "2017-06" = list(sheet = "Table 6",       since = "2017-01-01", negate = TRUE),
  "2018-04" = list(sheet = "Table A-1",     since = "2017-06-01", negate = TRUE),
  "2019-01" = list(sheet = "Table A-1",     since = "2018-04-01", negate = TRUE),
  # 2019-05: No legislative decomposition sheet in this vintage
  "2019-08" = list(sheet = "Table A-1",     since = "2019-05-01", negate = TRUE),
  "2020-01" = list(sheet = "Table A-1",     since = "2019-08-01", negate = TRUE),
  "2020-03" = list(sheet = "Table 6",       since = "2020-01-01", negate = TRUE),
  "2020-09" = list(sheet = "Table A-1",     since = "2020-03-01", negate = TRUE),
  "2021-02" = list(sheet = "Table 1-6",     since = "2020-09-01", negate = TRUE),
  "2021-07" = list(sheet = "Table A-1",     since = "2021-02-01", negate = TRUE),
  "2022-05" = list(sheet = "Table A-1",     since = "2021-07-01", negate = TRUE),
  "2023-02" = list(sheet = "Table A-1",     since = "2022-05-01", negate = TRUE),
  # 2023-05: Table 5 has only Technical Changes, no legislative data
  "2024-02" = list(sheet = "Table 3-1",     since = "2023-05-01", negate = FALSE),
  "2024-06" = list(sheet = "Table 3-1",     since = "2024-02-01", negate = FALSE),
  "2025-01" = list(sheet = "Table A-1",     since = "2024-06-01", negate = FALSE),
  "2026-02" = list(sheet = "Table 5-1",     since = "2025-01-01", negate = FALSE,
                   # Executive-action tariffs: CBO classified customs revenue from
                   # 2025 tariffs as "technical changes" since they weren't legislation.
                   # We include them as policy-driven fiscal actions.
                   include_technical_customs = TRUE)
)


parse_legislative_decomposition <- function(config) {
  budget_dir <- resolve_path(config$cbo_budget_dir %||% config$cbo_excel_dir)

  if (!dir.exists(budget_dir)) {
    stop(sprintf("Budget Projections directory not found: %s", budget_dir))
  }

  all_files <- list.files(budget_dir, pattern = "51118.*\\.xls(x?)$",
                           full.names = TRUE, ignore.case = TRUE)
  if (length(all_files) == 0) {
    stop("No Budget Projections files found (pattern: 51118*.xls[x])")
  }

  message(sprintf("  Scanning %d files for legislative decomposition (2015-08 onward)...",
                  length(all_files)))

  all_vintages <- list()
  deps <- empty_deps()

  file_meta <- data.frame(
    path = all_files,
    fname = basename(all_files),
    stringsAsFactors = FALSE
  )
  file_meta$vintage_date <- as.Date(vapply(file_meta$fname, extract_vintage_from_filename, as.Date(NA)))
  file_meta <- file_meta[!is.na(file_meta$vintage_date), ]
  file_meta$vintage_key <- format(file_meta$vintage_date, "%Y-%m")

  expected_keys <- names(DECOMP_LOOKUP)
  missing_keys <- setdiff(expected_keys, file_meta$vintage_key)
  if (length(missing_keys) > 0) {
    stop(sprintf("Missing Budget Projections files for expected decomposition vintages: %s",
                 paste(missing_keys, collapse = ", ")))
  }

  dup_keys <- unique(file_meta$vintage_key[duplicated(file_meta$vintage_key)])
  dup_expected <- dup_keys[dup_keys %in% expected_keys]
  if (length(dup_expected) > 0) {
    stop(sprintf("Multiple files found for decomposition vintages: %s",
                 paste(dup_expected, collapse = ", ")))
  }

  for (vintage_key in expected_keys) {
    lookup <- DECOMP_LOOKUP[[vintage_key]]
    row <- file_meta[file_meta$vintage_key == vintage_key, ]
    fpath <- row$path[1]
    vintage_date <- row$vintage_date[1]

    message(sprintf("  Parsing decomp: %s (sheet: '%s')", basename(fpath), lookup$sheet))
    parsed <- parse_one_decomp(fpath, lookup, vintage_date, config)

    all_vintages[[vintage_key]] <- parsed
    message(sprintf("    -> since %s, harmonized fiscal-policy horizon: $%.1fB (reported window: $%.1fB)",
                    format(parsed$since_date, "%b %Y"),
                    parsed$legislative_deficit_horizon_bn,
                    parsed$legislative_deficit_window_bn))

    deps <- rbind(deps, make_dependency_row(
      dependency_class = "local_file",
      required = TRUE,
      status = "ok",
      source = "CBO Excel Decomp",
      series = sprintf("Fiscal-policy decomposition (%s)", format(vintage_date, "%b %Y")),
      url = fpath,
      interface = config$interface,
      version = config$version,
      vintage = vintage_key,
      notes = sprintf("Sheet: %s", lookup$sheet)
    ))
  }

  vintages <- do.call(rbind, all_vintages)
  rownames(vintages) <- NULL
  vintages <- vintages[order(vintages$vintage_date), ]
  if (nrow(vintages) != length(expected_keys)) {
    stop(sprintf("Parsed %d decomposition vintages but expected %d",
                 nrow(vintages), length(expected_keys)))
  }

  message(sprintf("  Decomp total: %d vintages from %s to %s",
                  nrow(vintages),
                  format(min(vintages$vintage_date), "%b %Y"),
                  format(max(vintages$vintage_date), "%b %Y")))

  list(vintages = vintages, dependencies = deps)
}


parse_one_decomp <- function(xlsx_path, lookup, vintage_date, config) {
  # Parse a single decomposition sheet using hardcoded lookup config.
  # Returns a 1-row data.frame.

  raw <- suppressMessages(
    read_excel(xlsx_path, sheet = lookup$sheet, col_names = FALSE)
  )
  nr <- nrow(raw)
  nc <- ncol(raw)

  # ---- 1. Find year header row ----
  year_info <- find_year_row(raw, max_scan = min(15, nr))
  if (is.null(year_info)) {
    stop("Cannot find year header row in decomposition sheet")
  }

  year_row  <- year_info$row
  year_cols <- year_info$cols
  years     <- year_info$years
  horizon <- config$projection_horizon %||% 10
  start_offset <- config$window_start_offset %||% 0
  if (horizon <= 0) stop("projection_horizon must be positive")
  if (start_offset < 0) stop("window_start_offset must be >= 0")
  vintage_year <- as.integer(format(vintage_date, "%Y"))
  target_end_year <- vintage_year + start_offset + horizon - 1

  # ---- 2. Find the reported cumulative total column ----
  cumul_col <- find_cumulative_col(raw, year_row, year_cols, years, target_end_year, horizon)
  if (is.null(cumul_col)) {
    stop(sprintf("Cannot find an unambiguous reported cumulative column (horizon=%d)", horizon))
  }

  # ---- 3. Find the legislative deficit total row ----
  leg_row <- find_legislative_total_row(raw, year_row, nr, nc, cumul_col)
  if (is.null(leg_row)) {
    stop("Cannot find legislative/fiscal-policy total row")
  }

  # ---- 4. Extract reported-window value and annual values ----
  raw_window_value <- suppressWarnings(
    as.numeric(as.character(unlist(raw[leg_row, cumul_col])))
  )
  if (is.na(raw_window_value)) {
    stop(sprintf("Row %d, col %d has no numeric value", leg_row, cumul_col))
  }

  annual_raw <- suppressWarnings(
    as.numeric(as.character(unlist(raw[leg_row, year_cols])))
  )
  if (any(is.na(annual_raw))) {
    bad_years <- years[is.na(annual_raw)]
    stop(sprintf("Legislative row has NA annual values for years: %s",
                 paste(bad_years, collapse = ", ")))
  }

  # Normalize: positive = increases deficit / debt
  window_value <- if (lookup$negate) -raw_window_value else raw_window_value
  annual_values <- if (lookup$negate) -annual_raw else annual_raw

  target_years <- (vintage_year + start_offset):(vintage_year + start_offset + horizon - 1)
  idx <- match(target_years, years)
  if (any(is.na(idx))) {
    missing <- target_years[is.na(idx)]
    stop(sprintf("Missing annual columns required for harmonized %d-year window: %s",
                 horizon, paste(missing, collapse = ", ")))
  }

  # Harmonized fiscal-policy total is the exact sum over the configured horizon window.
  value_horizon <- sum(annual_values[idx])

  # ---- 5. Adjust for executive-action tariffs if flagged ----
  # Customs revenue is policy-driven in 2026 but classified by CBO as technical.
  if (isTRUE(lookup$include_technical_customs)) {
    customs_row <- find_technical_customs_row(raw, year_row, leg_row, nr, nc)
    if (is.null(customs_row)) {
      stop("include_technical_customs=TRUE but Customs duties row was not found")
    }

    customs_window <- suppressWarnings(as.numeric(as.character(unlist(raw[customs_row, cumul_col]))))
    customs_annual <- suppressWarnings(as.numeric(as.character(unlist(raw[customs_row, year_cols]))))
    if (is.na(customs_window) || any(is.na(customs_annual[idx]))) {
      stop("Failed to extract customs values for reported or harmonized window")
    }
    customs_horizon <- sum(customs_annual[idx])

    # Positive customs revenue lowers deficits, so subtract from deficit changes.
    window_value <- window_value - customs_window
    value_horizon <- value_horizon - customs_horizon
    message(sprintf("    Customs adjustment applied: reported -$%.1fB, harmonized -$%.1fB",
                    customs_window, customs_horizon))
  }

  window_label <- trimws(as.character(raw[year_row, cumul_col]))
  window_label <- gsub("[\r\n\t]+", " ", window_label)
  window_label <- gsub("\\s+", " ", window_label)
  window_label <- gsub("–|—", "-", window_label)
  window_label <- gsub("\\s*-\\s*", "-", window_label)
  range_years <- as.integer(regmatches(window_label, gregexpr("\\d{4}", window_label))[[1]])
  span <- if (length(range_years) == 2) range_years[2] - range_years[1] + 1 else NA_integer_

  data.frame(
    vintage_date = vintage_date,
    since_date = as.Date(lookup$since),
    legislative_deficit_horizon_bn = value_horizon,
    legislative_deficit_window_bn = window_value,
    harmonized_years = paste(target_years, collapse = "-"),
    reported_window_label = window_label,
    reported_window_span_years = span,
    sheet_name = lookup$sheet,
    stringsAsFactors = FALSE
  )
}


find_cumulative_col <- function(raw, year_row, year_cols, years, target_end_year, horizon = 10) {
  # Find the column containing the cumulative horizon total.
  nc <- ncol(raw)
  last_yr_col <- max(year_cols)
  candidates <- integer(0)
  scores <- numeric(0)

  for (c in (last_yr_col + 1):min(nc, last_yr_col + 5)) {
    val <- trimws(as.character(raw[year_row, c]))
    if (is.na(val) || val == "" || val == "NA") next

    # Match single-year total columns, e.g., "2020" / "2025"
    if (grepl("^(19|20)\\d{2}$", val)) {
      y <- as.integer(val)
      candidates <- c(candidates, c)
      scores <- c(scores, abs(y - target_end_year))
      next
    }

    # Match "YYYY-YYYY" range columns
    if (grepl("^\\d{4}[^0-9]+\\d{4}$", val)) {
      range_years <- as.integer(regmatches(val, gregexpr("\\d{4}", val))[[1]])
      if (length(range_years) == 2) {
        end_year <- range_years[2]
        span <- range_years[2] - range_years[1] + 1
        min_span <- max(2, horizon - 1)
        max_span <- horizon + 1
        if (span >= min_span && span <= max_span) {
          candidates <- c(candidates, c)
          scores <- c(scores, abs(end_year - target_end_year) + abs(span - horizon) * 0.01)
          next
        }
      }
    }

    if (grepl("5.year|five.year|10.year|ten.year|total|cumulative", tolower(val))) {
      candidates <- c(candidates, c)
      scores <- c(scores, 0.5)
    }
  }

  if (length(candidates) == 1) return(candidates[1])
  if (length(candidates) > 1) {
    best <- candidates[which.min(scores)]
    # Require unique best score to avoid silently choosing between similar columns
    if (sum(scores == min(scores)) == 1) return(best)
  }

  NULL
}


find_legislative_total_row <- function(raw, year_row, nr, nc, cumul_col) {
  # Search for the row with the legislative deficit total.
  # Looks for text patterns containing "legislat" combined with
  # "total", "increase", "decrease", or "deficit".
  # Returns the row number or NULL.

  label_cols <- 1:min(8, nc)

  # Single-row search
  for (r in (year_row + 1):min(nr, year_row + 120)) {
    row_text <- tolower(paste(as.character(unlist(raw[r, label_cols])), collapse = " "))
    row_text <- gsub("\\bna\\b", "", row_text)
    row_text <- gsub("\\s+", " ", trimws(row_text))

    if (!grepl("legislat", row_text)) next

    # Match summary-level legislative rows (not section headers or detail items)
    is_summary <- grepl("total legislative|from legislative changes|deficit.*legislative changes",
                        row_text)
    if (!is_summary) next

    # Verify it has a numeric value in the cumulative column
    val <- suppressWarnings(as.numeric(as.character(unlist(raw[r, cumul_col]))))
    if (!is.na(val)) return(r)
  }

  # Two-row label search (labels can span two rows)
  for (r in (year_row + 1):min(nr - 1, year_row + 120)) {
    row1 <- tolower(paste(as.character(unlist(raw[r, label_cols])), collapse = " "))
    row2 <- tolower(paste(as.character(unlist(raw[r + 1, label_cols])), collapse = " "))
    combined <- gsub("\\bna\\b", "", paste(row1, row2))
    combined <- gsub("\\s+", " ", trimws(combined))

    if (!grepl("legislat", combined)) next
    if (!grepl("total|increase|decrease|deficit", combined)) next

    # Try second row first (usually where the number is)
    val <- suppressWarnings(as.numeric(as.character(unlist(raw[r + 1, cumul_col]))))
    if (!is.na(val)) return(r + 1)

    val <- suppressWarnings(as.numeric(as.character(unlist(raw[r, cumul_col]))))
    if (!is.na(val)) return(r)
  }

  NULL
}


find_technical_customs_row <- function(raw, year_row, leg_row, nr, nc) {
  # Find "Customs duties" in the technical changes revenue section
  # (after the legislative and economic totals). Returns row index or NULL.

  label_cols <- 1:min(8, nc)

  # First, find the technical changes section by locating
  # "economic changes" summary row — technical section follows.
  tech_start <- NULL
  for (r in (leg_row + 1):min(nr, leg_row + 80)) {
    row_text <- tolower(paste(as.character(unlist(raw[r, label_cols])), collapse = " "))
    row_text <- gsub("\\bna\\b", "", row_text)
    if (grepl("deficit.*economic changes|economic changes.*deficit", row_text)) {
      tech_start <- r + 1
      break
    }
  }
  if (is.null(tech_start)) return(NULL)

  # Now find "Customs duties" in the technical section
  for (r in tech_start:min(nr, tech_start + 40)) {
    row_text <- tolower(paste(as.character(unlist(raw[r, label_cols])), collapse = " "))
    row_text <- gsub("\\bna\\b", "", row_text)
    row_text <- gsub("\\s+", " ", trimws(row_text))
    if (grepl("customs dut", row_text)) {
      return(r)
    }
  }

  NULL
}

