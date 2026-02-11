# fetch_cbo_github.R — Download and parse CBO baselines.csv from GitHub
#
# The CBO eval-projections repo contains baselines.csv with 41 projection vintages
# (1984-2025). Each row is a (vintage, fiscal_year) pair with projected budget
# components in billions of dollars.
#
# We extract projected "Debt Held by the Public" at the configured projection horizon
# (default: 5 years ahead) for each vintage.

library(dplyr)

fetch_cbo_github <- function(config) {
  url <- config$cbo_github_url
  message(sprintf("  Fetching CBO baselines.csv from GitHub..."))

  baselines <- tryCatch({
    read.csv(url, stringsAsFactors = FALSE)
  }, error = function(e) {
    # Fallback: try downloading to temp file first
    tmp <- tempfile(fileext = ".csv")
    tryCatch({
      download.file(url, tmp, mode = "w", quiet = TRUE)
      read.csv(tmp, stringsAsFactors = FALSE)
    }, error = function(e2) {
      stop(sprintf("Failed to download baselines.csv: %s", e2$message))
    })
  })

  message(sprintf("  baselines.csv: %d rows x %d cols", nrow(baselines), ncol(baselines)))

  # Standardize column names (CBO uses various conventions across versions)
  names(baselines) <- tolower(names(baselines))

  # Identify key columns
  # Expected: vintage (or baseline_date), fiscal_year (or year), component, value
  vintage_col <- intersect(c("vintage", "baseline_date", "baseline"), names(baselines))
  year_col    <- intersect(c("fiscal_year", "projected_fiscal_year", "year", "fiscal.year"), names(baselines))
  comp_col    <- intersect(c("component", "variable", "category"), names(baselines))
  value_col   <- intersect(c("value", "amount", "projection"), names(baselines))

  if (length(vintage_col) == 0 || length(year_col) == 0 ||
      length(comp_col) == 0 || length(value_col) == 0) {
    message(sprintf("  Available columns: %s", paste(names(baselines), collapse = ", ")))
    stop("Cannot identify required columns in baselines.csv")
  }

  # Use first match for each
  vintage_col <- vintage_col[1]
  year_col    <- year_col[1]
  comp_col    <- comp_col[1]
  value_col   <- value_col[1]

  message(sprintf("  Columns: vintage='%s', year='%s', component='%s', value='%s'",
                  vintage_col, year_col, comp_col, value_col))

  # Rename for consistency
  baselines <- baselines %>%
    rename(
      vintage   = !!vintage_col,
      year      = !!year_col,
      component = !!comp_col,
      value     = !!value_col
    )

  # Parse vintage dates
  baselines$vintage_date <- parse_vintage_date(baselines$vintage)
  if (any(is.na(baselines$vintage_date))) {
    bad <- unique(baselines$vintage[is.na(baselines$vintage_date)])
    stop(sprintf("Failed to parse %d CBO vintage date(s): %s",
                 length(bad), paste(head(bad, 10), collapse = ", ")))
  }

  # Filter to debt component
  # CBO eval-projections repo uses "debt" as the component name.
  # Older or other formats may use longer labels like "Debt Held by the Public".
  debt_rows <- tolower(baselines$component) == "debt"

  if (sum(debt_rows) == 0) {
    # Fallback: try pattern matching for longer labels
    debt_patterns <- c("debt held by the public", "federal debt held by public",
                        "debt held by public")
    debt_rows <- grepl(paste(debt_patterns, collapse = "|"),
                       tolower(baselines$component))
  }

  if (sum(debt_rows) == 0) {
    components <- unique(baselines$component)
    message(sprintf("  Available components: %s",
                    paste(head(components, 20), collapse = "; ")))
    stop("Cannot find debt component in baselines.csv")
  }

  debt <- baselines[debt_rows, ]
  message(sprintf("  Debt rows: %d across %d vintages",
                  nrow(debt), length(unique(debt$vintage))))

  # For each vintage, compute the projection horizon year and extract the value
  horizon <- config$projection_horizon %||% 5

  vintage_debt <- debt %>%
    group_by(vintage, vintage_date) %>%
    mutate(
      vintage_year = as.integer(format(vintage_date, "%Y")),
      horizon_year = vintage_year + horizon,
      years_ahead  = year - vintage_year
    ) %>%
    ungroup()

  # Extract debt at the specified horizon
  debt_at_horizon <- vintage_debt %>%
    filter(years_ahead == horizon) %>%
    select(vintage, vintage_date, year, value) %>%
    rename(debt_bn = value, horizon_year = year) %>%
    arrange(vintage_date)

  # Also extract debt at current year (year 0) for reference
  debt_current <- vintage_debt %>%
    filter(years_ahead == 0) %>%
    select(vintage, vintage_date, value) %>%
    rename(debt_current_bn = value)

  if (nrow(debt_at_horizon) > 0) {
    debt_at_horizon <- merge(debt_at_horizon, debt_current,
                             by = c("vintage", "vintage_date"), all.x = TRUE)
  }

  message(sprintf("  Debt at %d-year horizon: %d vintages (%s to %s)",
                  horizon, nrow(debt_at_horizon),
                  min(debt_at_horizon$vintage_date, na.rm = TRUE),
                  max(debt_at_horizon$vintage_date, na.rm = TRUE)))

  # Build dependency record
  deps <- make_dependency_row(
    dependency_class = "external_api",
    required = TRUE,
    status = "ok",
    source = "CBO GitHub",
    series = "baselines.csv (Debt Held by the Public)",
    url = config$cbo_github_url,
    interface = config$interface,
    version = config$version,
    vintage = format(Sys.time(), "%Y%m%d_%H%M%S"),
    notes = sprintf("%d rows, horizon=%d", nrow(baselines), horizon)
  )

  list(
    baselines = baselines,
    debt_at_horizon = debt_at_horizon,
    all_debt = debt,
    dependencies = deps
  )
}


parse_vintage_date <- function(vintage_strings) {
  # Parse CBO vintage identifiers to dates.
  # Formats seen: "January 2025", "Jan 2025", "2025-01", "01/2025", "Spring 2025"
  dates <- as.Date(rep(NA, length(vintage_strings)))

  for (i in seq_along(vintage_strings)) {
    v <- trimws(vintage_strings[i])

    # Try ISO "YYYY-MM-DD" format (baselines.csv uses this)
    d <- tryCatch(as.Date(v, format = "%Y-%m-%d"), error = function(e) NA)
    if (!is.na(d) && nchar(v) == 10) { dates[i] <- d; next }

    # Try "Month Year" format (most common)
    d <- tryCatch(as.Date(paste0("01 ", v), format = "%d %B %Y"), error = function(e) NA)
    if (!is.na(d)) { dates[i] <- d; next }

    # Try "Mon Year" abbreviation
    d <- tryCatch(as.Date(paste0("01 ", v), format = "%d %b %Y"), error = function(e) NA)
    if (!is.na(d)) { dates[i] <- d; next }

    # Try "YYYY-MM" format
    d <- tryCatch(as.Date(paste0(v, "-01")), error = function(e) NA)
    if (!is.na(d)) { dates[i] <- d; next }

    # Try "MM/YYYY" format
    parts <- strsplit(v, "/")[[1]]
    if (length(parts) == 2) {
      d <- tryCatch(as.Date(sprintf("%s-%s-01", parts[2], parts[1])),
                    error = function(e) NA)
      if (!is.na(d)) { dates[i] <- d; next }
    }

    # Season mappings
    season_map <- c(Spring = "04", Summer = "07", Fall = "10", Winter = "01")
    for (s in names(season_map)) {
      if (grepl(s, v, ignore.case = TRUE)) {
        yr <- gsub("[^0-9]", "", v)
        if (nchar(yr) == 4) {
          dates[i] <- as.Date(sprintf("%s-%s-01", yr, season_map[s]))
          break
        }
      }
    }
  }

  dates
}


save_cbo_github <- function(cbo_github, output_dir) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  write.csv(cbo_github$debt_at_horizon,
            file.path(output_dir, "cbo_debt_at_horizon.csv"), row.names = FALSE)

  if (!is.null(cbo_github$all_debt)) {
    write.csv(cbo_github$all_debt,
              file.path(output_dir, "cbo_all_debt_vintages.csv"), row.names = FALSE)
  }

  append_dependencies(output_dir, cbo_github$dependencies)
  invisible(output_dir)
}
