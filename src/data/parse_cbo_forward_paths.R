# parse_cbo_forward_paths.R — Extract CBO forward debt/GDP/rate paths and
# estimate effective repricing speed (k) for the debt-interest recursion.
#
# This module is independent of the historical legislative decomposition.
# It reads the latest CBO Budget and Economic Projections Excel files and
# extracts: debt path, net interest, nominal GDP, and interest rates over
# the projection window.
#
# The repricing speed k is estimated from CBO's own projected path of
# average interest rates converging toward market rates.  It is NOT a
# literal WAM; it is the effective speed at which the federal debt stock
# reprices, as implied by CBO's baseline projections.
#
# Output:
#   cbo_forward_paths.csv      — one row per fiscal_year
#   cbo_forward_paths_meta.csv — one row with k estimate and metadata

library(readxl)
library(dplyr)

# ===========================================================================
# Public API
# ===========================================================================

parse_cbo_forward_paths <- function(config) {
  # Main entry point.  Parses the latest CBO vintage only (forward-looking).
  # Returns a list with:
  #   $paths — data.frame (one row per fiscal_year)
  #   $meta  — data.frame (one row with k estimate)

  budget_dir <- resolve_path(config$cbo_budget_dir %||% config$cbo_excel_dir)
  econ_dir   <- resolve_path(config$cbo_econ_dir)

  if (!dir.exists(budget_dir)) stop("Budget dir not found: ", budget_dir)
  if (!dir.exists(econ_dir))   stop("Econ dir not found: ", econ_dir)

  # Find latest budget and econ files by vintage date
  budget_file <- find_latest_cbo_file(budget_dir, "51118")
  econ_file   <- find_latest_cbo_file(econ_dir, "51135")

  message(sprintf("  Forward paths: budget=%s, econ=%s",
                  basename(budget_file$path), basename(econ_file$path)))

  # Parse budget (debt + net interest)
  budget_df <- extract_budget_forward_series(budget_file$path, budget_file$vintage)

  # Parse econ (GDP + interest rates)
  econ_df <- extract_econ_forward_series(econ_file$path, econ_file$vintage)

  if (is.null(budget_df)) stop("Failed to parse budget forward series")
  if (is.null(econ_df))   stop("Failed to parse econ forward series")

  # Merge on fiscal year
  paths <- merge(budget_df, econ_df, by = "fiscal_year", all.x = TRUE)
  paths$budget_vintage_date <- budget_file$vintage
  paths$econ_vintage_date   <- econ_file$vintage

  # Compute implied average interest rate
  paths$avg_debt_bn <- (paths$debt_begin_bn + paths$debt_end_bn) / 2
  paths$avg_interest_rate_pct <- ifelse(
    paths$avg_debt_bn > 0,
    paths$net_interest_bn / paths$avg_debt_bn * 100,
    NA_real_
  )

  # Estimate k
  k_est <- estimate_effective_repricing_k(paths, anchor = "ten_year")
  k_est$budget_vintage_date <- budget_file$vintage
  k_est$econ_vintage_date   <- econ_file$vintage

  message(sprintf("  k_effective = %.4f (R² = %.3f, method: %s, n = %d)",
                  k_est$k_effective, k_est$k_r_squared,
                  k_est$k_method, k_est$k_n_obs))

  # Clean up column order
  path_cols <- c("budget_vintage_date", "econ_vintage_date", "fiscal_year",
                 "nominal_gdp_bn", "debt_begin_bn", "debt_end_bn",
                 "debt_change_deficit_bn", "debt_change_other_bn",
                 "net_interest_bn", "avg_interest_rate_pct",
                 "rate_3m_pct", "rate_10y_pct")
  paths <- paths[, intersect(path_cols, names(paths))]

  list(paths = paths, meta = k_est)
}


# ===========================================================================
# Find latest CBO file by vintage date
# ===========================================================================

find_latest_cbo_file <- function(dir_path, prefix) {
  files <- list.files(dir_path, pattern = paste0(prefix, ".*\\.xlsx?$"),
                      full.names = TRUE, ignore.case = TRUE)
  if (length(files) == 0) stop("No files found with prefix ", prefix, " in ", dir_path)

  vintages <- as.Date(vapply(basename(files), function(f) {
    as.character(extract_vintage_from_filename(f))
  }, character(1)))
  valid <- !is.na(vintages)
  if (!any(valid)) stop("No parseable vintage dates in ", dir_path)

  idx <- which(vintages == max(vintages[valid]) & valid)[1]
  list(path = files[idx], vintage = vintages[idx])
}


# ===========================================================================
# Budget Projections: debt and net interest
# ===========================================================================

extract_budget_forward_series <- function(xlsx_path, vintage_date) {
  sheets <- excel_sheets(xlsx_path)

  debt_df <- extract_debt_table(xlsx_path, sheets)
  interest_df <- extract_net_interest(xlsx_path, sheets)

  if (is.null(debt_df) || is.null(interest_df)) return(NULL)

  merged <- merge(debt_df, interest_df, by = "fiscal_year", all = TRUE)
  merged$budget_vintage_date <- vintage_date
  merged
}


extract_debt_table <- function(xlsx_path, sheets) {
  sheet <- grep("Table 1-3", sheets, value = TRUE, ignore.case = TRUE)
  if (length(sheet) == 0) return(NULL)
  sheet <- sheet[1]

  raw <- suppressMessages(read_excel(xlsx_path, sheet = sheet, col_names = FALSE))
  nr <- nrow(raw)
  nc <- ncol(raw)

  year_info <- find_year_row(raw)
  if (is.null(year_info)) return(NULL)

  years     <- year_info$years
  year_cols <- year_info$cols

  # Search for key rows by label
  debt_begin_row <- NULL
  debt_end_bn_row <- NULL
  deficit_row    <- NULL
  other_row      <- NULL

  for (r in (year_info$row + 1):min(nr, year_info$row + 30)) {
    label <- tolower(paste(as.character(unlist(raw[r, 1:min(4, nc)])), collapse = " "))
    label <- gsub("\\bna\\b", "", label)
    label <- gsub("\\s+", " ", trimws(label))

    if (grepl("beginning of the year|beginning of year", label) &&
        grepl("debt held", label)) {
      debt_begin_row <- r
    }
    # "end of the year" section — the "billions of dollars" row has the data
    if (grepl("billions of dollars", label) && !is.null(debt_begin_row) &&
        is.null(debt_end_bn_row) && r > debt_begin_row + 3) {
      debt_end_bn_row <- r
    }
    if (grepl("resulting from the deficit", label)) {
      deficit_row <- r
    }
    if (grepl("resulting from other means", label)) {
      other_row <- r
    }
  }

  if (is.null(debt_begin_row)) return(NULL)

  extract_row <- function(row_idx) {
    if (is.null(row_idx)) return(rep(NA_real_, length(years)))
    suppressWarnings(as.numeric(as.character(unlist(raw[row_idx, year_cols]))))
  }

  data.frame(
    fiscal_year            = years,
    debt_begin_bn          = extract_row(debt_begin_row),
    debt_end_bn            = extract_row(debt_end_bn_row),
    debt_change_deficit_bn = extract_row(deficit_row),
    debt_change_other_bn   = extract_row(other_row),
    stringsAsFactors       = FALSE
  )
}


extract_net_interest <- function(xlsx_path, sheets) {
  sheet <- grep("Table 1-1", sheets, value = TRUE, ignore.case = TRUE)
  if (length(sheet) == 0) return(NULL)
  sheet <- sheet[1]

  raw <- suppressMessages(read_excel(xlsx_path, sheet = sheet, col_names = FALSE))
  nr <- nrow(raw)
  nc <- ncol(raw)

  year_info <- find_year_row(raw)
  if (is.null(year_info)) return(NULL)

  years     <- year_info$years
  year_cols <- year_info$cols

  # Find "Net interest" row in billions (values > 100, not % of GDP)
  net_int_row <- NULL
  for (r in (year_info$row + 1):min(nr, year_info$row + 50)) {
    label <- tolower(paste(as.character(unlist(raw[r, 1:min(3, nc)])), collapse = " "))
    label <- gsub("\\bna\\b", "", label)
    label <- gsub("\\s+", " ", trimws(label))

    if (grepl("^net interest\\b", label)) {
      test_val <- suppressWarnings(
        as.numeric(as.character(unlist(raw[r, year_cols[1]])))
      )
      if (!is.na(test_val) && test_val > 100) {
        net_int_row <- r
        break
      }
    }
  }

  if (is.null(net_int_row)) return(NULL)

  vals <- suppressWarnings(
    as.numeric(as.character(unlist(raw[net_int_row, year_cols])))
  )

  data.frame(
    fiscal_year     = years,
    net_interest_bn = vals,
    stringsAsFactors = FALSE
  )
}


# ===========================================================================
# Economic Projections: GDP and interest rates
# ===========================================================================

extract_econ_forward_series <- function(xlsx_path, vintage_date) {
  sheets <- excel_sheets(xlsx_path)
  fy_sheet <- grep("fiscal year", sheets, ignore.case = TRUE, value = TRUE)
  if (length(fy_sheet) == 0) return(NULL)
  fy_sheet <- fy_sheet[1]

  raw <- suppressMessages(read_excel(xlsx_path, sheet = fy_sheet, col_names = FALSE))
  nr <- nrow(raw)
  nc <- ncol(raw)

  year_info <- find_year_row(raw)
  if (is.null(year_info)) return(NULL)

  years     <- year_info$years
  year_cols <- year_info$cols

  # Find GDP row
  gdp_row <- NULL
  for (r in (year_info$row + 1):min(nr, year_info$row + 20)) {
    row_text <- tolower(paste(as.character(unlist(raw[r, 1:min(5, nc)])), collapse = " "))
    if (grepl("gross domestic product", row_text) &&
        grepl("billions of dollars", row_text)) {
      gdp_row <- r
      break
    }
  }

  # Find interest rate rows.  In recent vintages (2024+) the pattern is:
  #   "Interest rates" (section header)
  #   "10-Year Treasury note"   or  "10-year Treasury note"
  #   "3-Month Treasury bill"   or  "3-month Treasury bill"
  # We search the full sheet since these rows are often far down.
  rate_10y_row <- NULL
  rate_3m_row  <- NULL
  in_interest_section <- FALSE

  for (r in 1:nr) {
    label <- trimws(as.character(raw[r, 1]))
    if (is.na(label)) next
    ll <- tolower(label)

    if (grepl("^interest rate", ll)) {
      in_interest_section <- TRUE
      next
    }

    if (in_interest_section) {
      if (grepl("10.year treasury note", ll) && is.null(rate_10y_row)) {
        # Verify it has "Percent" in col 2 (to distinguish from other mentions)
        unit <- tolower(trimws(as.character(raw[r, 2])))
        if (!is.na(unit) && grepl("percent", unit)) {
          rate_10y_row <- r
        }
      }
      if (grepl("3.month treasury bill", ll) && is.null(rate_3m_row)) {
        unit <- tolower(trimws(as.character(raw[r, 2])))
        if (!is.na(unit) && grepl("percent", unit)) {
          rate_3m_row <- r
        }
      }
    }
  }

  extract_row <- function(row_idx) {
    if (is.null(row_idx)) return(rep(NA_real_, length(years)))
    suppressWarnings(as.numeric(as.character(unlist(raw[row_idx, year_cols]))))
  }

  result <- data.frame(
    econ_vintage_date = vintage_date,
    fiscal_year       = years,
    nominal_gdp_bn    = extract_row(gdp_row),
    rate_10y_pct      = extract_row(rate_10y_row),
    rate_3m_pct       = extract_row(rate_3m_row),
    stringsAsFactors  = FALSE
  )

  n_rates <- sum(!is.na(result$rate_10y_pct))
  message(sprintf("    Econ %s: %d years, GDP: $%.0fB-$%.0fB, 10y rates: %d values",
                  format(vintage_date), nrow(result),
                  min(result$nominal_gdp_bn, na.rm = TRUE),
                  max(result$nominal_gdp_bn, na.rm = TRUE),
                  n_rates))

  result
}


# ===========================================================================
# Estimate effective repricing speed (k)
# ===========================================================================

estimate_effective_repricing_k <- function(forward_panel, anchor = "ten_year") {
  # Estimate k from:  delta_avg_rate_t = k * (anchor_rate_t - avg_rate_{t-1})
  #
  # This is a partial-adjustment model.  k is the fraction of the gap between
  # the market rate and the government's average borrowing cost that closes
  # each year.  It reflects the effective repricing speed of the federal debt
  # stock as implied by CBO's own baseline projections.
  #
  # Returns a 1-row data.frame with k estimate and metadata.

  df <- forward_panel[order(forward_panel$fiscal_year), ]

  if (anchor == "ten_year") {
    anchor_col <- "rate_10y_pct"
  } else {
    stop("Unsupported anchor: ", anchor)
  }

  # Filter to rows with all needed values
  df <- df[!is.na(df$avg_interest_rate_pct) & !is.na(df[[anchor_col]]), ]
  if (nrow(df) < 3) {
    return(data.frame(
      k_effective      = NA_real_,
      k_anchor         = anchor,
      k_method         = "insufficient_data",
      k_fit_start_year = NA_integer_,
      k_fit_end_year   = NA_integer_,
      k_n_obs          = 0L,
      k_r_squared      = NA_real_,
      stringsAsFactors = FALSE
    ))
  }

  # Build regression variables
  n <- nrow(df)
  delta_avg   <- diff(df$avg_interest_rate_pct)       # ravg_t - ravg_{t-1}
  anchor_rate <- df[[anchor_col]][2:n]                 # anchor_t
  lag_avg     <- df$avg_interest_rate_pct[1:(n - 1)]  # ravg_{t-1}
  gap         <- anchor_rate - lag_avg                 # anchor_t - ravg_{t-1}

  # OLS: delta_avg = k * gap  (no intercept — pure partial-adjustment)
  fit <- lm(delta_avg ~ 0 + gap)
  k_est <- coef(fit)[["gap"]]
  r2 <- summary(fit)$r.squared

  data.frame(
    k_effective      = round(k_est, 4),
    k_anchor         = anchor,
    k_method         = "ols_partial_adjustment",
    k_fit_start_year = df$fiscal_year[2],
    k_fit_end_year   = df$fiscal_year[n],
    k_n_obs          = length(delta_avg),
    k_r_squared      = round(r2, 4),
    stringsAsFactors = FALSE
  )
}


# ===========================================================================
# Save outputs
# ===========================================================================

save_cbo_forward_paths <- function(forward_obj, output_dir) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  write.csv(forward_obj$paths,
            file.path(output_dir, "cbo_forward_paths.csv"),
            row.names = FALSE)
  write.csv(forward_obj$meta,
            file.path(output_dir, "cbo_forward_paths_meta.csv"),
            row.names = FALSE)

  message(sprintf("  Saved forward paths (%d years) and meta to %s",
                  nrow(forward_obj$paths), output_dir))

  invisible(output_dir)
}
