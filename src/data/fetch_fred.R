# fetch_fred.R — Fetch FRED series for consumer rate context
#
# GDP denominator now comes from CBO Economic Projections Excel files,
# so NGDPPOT and ALFRED are no longer needed here.

library(fredr)
library(dplyr)
library(lubridate)

fetch_fred_data <- function(config) {
  fredr_set_key(config$fred_api_key)

  series_list <- list(
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

    # For quarterly series, keep as-is
    if (name == "TERMCBAUTO48NS") {
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


save_fred_data <- function(fred_results, output_dir) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  for (name in names(fred_results$data)) {
    fpath <- file.path(output_dir, paste0("fred_", tolower(name), ".csv"))
    write.csv(fred_results$data[[name]], fpath, row.names = FALSE)
  }

  append_dependencies(output_dir, fred_results$dependencies)
  invisible(output_dir)
}
