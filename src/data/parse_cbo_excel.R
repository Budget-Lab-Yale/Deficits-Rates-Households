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
  # Parse both Budget and Economic Projections. Returns a list with:
  #   $budget_vintages: debt/GDP by (vintage_date, year)
  #   $econ_vintages:   nominal GDP by (vintage_date, year)
  #   $dependencies:    provenance records

  budget_result <- parse_budget_projections_dir(config)
  econ_result   <- parse_econ_projections_dir(config)

  list(
    budget_vintages = budget_result$vintages,
    econ_vintages   = econ_result$vintages,
    dependencies    = rbind(budget_result$dependencies, econ_result$dependencies)
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

  xlsx_files <- list.files(budget_dir, pattern = "51118.*\\.xlsx$",
                           full.names = TRUE, ignore.case = TRUE)

  if (length(xlsx_files) == 0) {
    message("  No Budget Projections files found (pattern: 51118*.xlsx)")
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

    deps <- rbind(deps, data.frame(
      source = "CBO Excel",
      series = sprintf("Budget Projections (%s)", format(vintage_date, "%b %Y")),
      url = xlsx_path,
      retrieved_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
      stringsAsFactors = FALSE
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
  # Priority 1: Try known sheet name patterns (prefer no trailing space)
  patterns <- c("^Table B-3$", "^Table 1-3$", "^Table 1-2$",
                "^Table 3$", "^Table 2$")
  for (pat in patterns) {
    # Exact match first (trimmed)
    trimmed <- trimws(sheets)
    matches <- sheets[grepl(pat, trimmed, ignore.case = TRUE)]
    if (length(matches) > 0) {
      # If multiple (e.g., "Table 1-3" and "Table 1-3 "), prefer no trailing space
      shortest <- matches[which.min(nchar(matches))]
      # Verify this sheet actually contains debt data
      if (verify_debt_sheet(xlsx_path, shortest)) return(shortest)
    }
  }

  # Priority 2: Scan all sheets for "Projections of Federal Debt" or
  # "Debt Held by the Public" in first 10 rows
  for (s in sheets) {
    if (verify_debt_sheet(xlsx_path, s)) return(s)
  }

  NULL
}


verify_debt_sheet <- function(xlsx_path, sheet_name) {
  raw <- tryCatch(
    read_excel(xlsx_path, sheet = sheet_name, col_names = FALSE, n_max = 10),
    error = function(e) NULL
  )
  if (is.null(raw)) return(FALSE)

  text <- tolower(paste(unlist(raw), collapse = " "))
  grepl("projections of federal debt|federal debt held|debt held by the public",
        text) && !grepl("changes in cbo", text)
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
      return(list(row = r, cols = cols, years = years))
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
    message(sprintf("  Economic Projections directory not found: %s",
                    econ_dir %||% "(not configured)"))
    return(empty_result())
  }

  xlsx_files <- list.files(econ_dir, pattern = "51135.*\\.xlsx$",
                           full.names = TRUE, ignore.case = TRUE)

  if (length(xlsx_files) == 0) {
    message("  No Economic Projections files found (pattern: 51135*.xlsx)")
    return(empty_result())
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

    deps <- rbind(deps, data.frame(
      source = "CBO Excel",
      series = sprintf("Economic Projections (%s)", format(vintage_date, "%b %Y")),
      url = xlsx_path,
      retrieved_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
      stringsAsFactors = FALSE
    ))
  }

  if (length(all_vintages) == 0) {
    message("  WARNING: No Economic Projections files parsed successfully")
    return(list(vintages = data.frame(), dependencies = deps))
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
    read_excel(xlsx_path, sheet = fy_sheet, col_names = FALSE),
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
  data.frame(
    source = character(), series = character(),
    url = character(), retrieved_at = character(),
    stringsAsFactors = FALSE
  )
}


empty_result <- function() {
  list(vintages = data.frame(), dependencies = empty_deps())
}
