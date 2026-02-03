# fetch_fred.R — Fetch FRED series for GDP denominator and consumer rate context

library(fredr)
library(dplyr)
library(lubridate)

fetch_fred_data <- function(config) {
  fredr_set_key(config$fred_api_key)

  series_list <- list(
    NGDPPOT = list(
      id   = "NGDPPOT",
      desc = "Nominal Potential GDP (CBO estimate), quarterly SAAR, billions",
      use  = "Denominator for debt/GDP from GitHub data"
    ),
    THREEFYTP10 = list(
      id   = "THREEFYTP10",
      desc = "10-Year Treasury Term Premium (ACM model)",
      use  = "Validate term premium channel"
    ),
    MORTGAGE30US = list(
      id   = "MORTGAGE30US",
      desc = "30-Year Fixed Rate Mortgage Average",
      use  = "Current consumer rate context"
    ),
    TERMCBAUTO48NS = list(
      id   = "TERMCBAUTO48NS",
      desc = "48-Month New Auto Loan Rate",
      use  = "Current consumer rate context"
    ),
    DPRIME = list(
      id   = "DPRIME",
      desc = "Prime Rate",
      use  = "Small business loan benchmark"
    )
  )

  results <- list()
  deps <- data.frame(
    source = character(), series = character(),
    url = character(), retrieved_at = character(),
    stringsAsFactors = FALSE
  )

  for (name in names(series_list)) {
    s <- series_list[[name]]
    message(sprintf("  Fetching FRED: %s (%s)", s$id, s$desc))

    raw <- tryCatch({
      fredr(
        series_id = s$id,
        observation_start = as.Date("1980-01-01"),
        frequency = NULL
      ) %>%
        select(date, value) %>%
        filter(!is.na(value))
    }, error = function(e) {
      warning(sprintf("Failed to fetch %s: %s", s$id, e$message))
      NULL
    })

    if (is.null(raw) || nrow(raw) == 0) {
      message(sprintf("    WARNING: No data for %s", s$id))
      next
    }

    # For daily/weekly series, aggregate to monthly averages
    if (name %in% c("MORTGAGE30US", "DPRIME", "THREEFYTP10")) {
      raw <- raw %>%
        mutate(date = floor_date(date, "month")) %>%
        group_by(date) %>%
        summarise(value = mean(value, na.rm = TRUE), .groups = "drop")
    }

    # For quarterly series, keep as-is (will be interpolated later)
    if (name %in% c("NGDPPOT", "TERMCBAUTO48NS")) {
      raw <- raw %>%
        mutate(date = floor_date(date, "month"))
    }

    results[[name]] <- raw

    deps <- rbind(deps, data.frame(
      source = "FRED",
      series = s$id,
      url = paste0("https://fred.stlouisfed.org/series/", s$id),
      retrieved_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
      stringsAsFactors = FALSE
    ))
  }

  list(data = results, dependencies = deps)
}


# ===========================================================================
# ALFRED: Vintaged NGDPPOT for pre-Excel CBO projection vintages
# ===========================================================================

fetch_alfred_ngdppot <- function(config, vintage_dates) {
  # Fetch the NGDPPOT series as it existed at each CBO projection vintage date.
  # Uses FRED's real-time data (ALFRED) via the realtime_start/realtime_end params.
  #
  # Args:
  #   config: runtime config with fred_api_key
  #   vintage_dates: vector of Date objects (CBO projection vintage dates)
  #
  # Returns:
  #   data.frame with columns: vintage_date, year, ngdppot (billions, SAAR)

  fredr_set_key(config$fred_api_key)

  all_results <- list()
  deps <- data.frame(
    source = character(), series = character(),
    url = character(), retrieved_at = character(),
    stringsAsFactors = FALSE
  )

  for (vd in vintage_dates) {
    vd <- as.Date(vd, origin = "1970-01-01")
    message(sprintf("  Fetching ALFRED NGDPPOT as of %s...", format(vd, "%Y-%m-%d")))

    raw <- tryCatch({
      fredr(
        series_id = "NGDPPOT",
        observation_start = as.Date("1980-01-01"),
        realtime_start = vd,
        realtime_end = vd,
        frequency = NULL
      ) %>%
        select(date, value) %>%
        filter(!is.na(value))
    }, error = function(e) {
      warning(sprintf("ALFRED NGDPPOT as of %s failed: %s",
                      format(vd, "%Y-%m-%d"), e$message))
      NULL
    })

    if (is.null(raw) || nrow(raw) == 0) {
      message(sprintf("    WARNING: No NGDPPOT data for vintage %s", format(vd, "%Y-%m-%d")))
      next
    }

    # Aggregate quarterly to annual
    raw$year <- as.integer(format(raw$date, "%Y"))
    annual <- raw %>%
      group_by(year) %>%
      summarise(ngdppot = mean(value, na.rm = TRUE), .groups = "drop") %>%
      arrange(year)

    # Extend forward using last growth rate (CBO's NGDPPOT is a projection itself)
    if (nrow(annual) >= 2) {
      last_two <- tail(annual, 2)
      growth_rate <- last_two$ngdppot[2] / last_two$ngdppot[1]
      last_year <- max(annual$year)
      last_val  <- tail(annual$ngdppot, 1)

      future <- data.frame(
        year = (last_year + 1):(last_year + 15),
        ngdppot = last_val * growth_rate^(1:15)
      )
      annual <- rbind(annual, future)
    }

    annual$vintage_date <- vd
    all_results[[format(vd)]] <- annual

    message(sprintf("    %d years of NGDPPOT (%d to %d)",
                    nrow(annual), min(annual$year), max(annual$year)))
  }

  if (length(all_results) > 0) {
    deps <- rbind(deps, data.frame(
      source = "FRED/ALFRED",
      series = sprintf("NGDPPOT (vintaged, %d dates)", length(all_results)),
      url = "https://fred.stlouisfed.org/series/NGDPPOT",
      retrieved_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
      stringsAsFactors = FALSE
    ))
  }

  result_df <- if (length(all_results) > 0) {
    do.call(rbind, all_results)
  } else {
    data.frame(vintage_date = as.Date(character()), year = integer(),
               ngdppot = numeric(), stringsAsFactors = FALSE)
  }
  rownames(result_df) <- NULL

  list(data = result_df, dependencies = deps)
}


save_fred_data <- function(fred_results, output_dir) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  for (name in names(fred_results$data)) {
    fpath <- file.path(output_dir, paste0("fred_", tolower(name), ".csv"))
    write.csv(fred_results$data[[name]], fpath, row.names = FALSE)
  }

  append_dependencies(output_dir, fred_results$dependencies)
  invisible(output_dir)
}
