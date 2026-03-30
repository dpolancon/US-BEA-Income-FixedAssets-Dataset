############################################################
# 42_fetch_fred_gdp.R — Download FRED GDP/GNP/Deflator
#
# Downloads: GDPA, GNPA, A191RD3A086NBEA via fredr.
# Writes to: data/raw/fred/
#
# Requires: fredr, dplyr, readr
# Sources:  40_gdp_kstock_config.R, 97_kstock_helpers.R
############################################################

rm(list = ls())

library(dplyr)
library(readr)

source("codes/40_gdp_kstock_config.R")
source("codes/99_utils.R")
source("codes/97_kstock_helpers.R")

ensure_dirs(GDP_CONFIG)

## ----------------------------------------------------------
## FRED API setup
## ----------------------------------------------------------

if (!requireNamespace("fredr", quietly = TRUE)) {
  stop("fredr package required. Install with: install.packages('fredr')")
}

fredr::fredr_set_key(GDP_CONFIG$FRED_API_KEY)

## ----------------------------------------------------------
## Fetch function with retry logic
## ----------------------------------------------------------

#' Fetch a FRED series with exponential backoff retry
#'
#' @param series_id FRED series ID
#' @param start_date Start date string
#' @param end_date   End date string
#' @param max_retries Maximum retries
#' @return tibble(date, year, value, series_id) or NULL
fetch_fred_series <- function(series_id,
                               start_date = "1925-01-01",
                               end_date   = "2024-12-31",
                               max_retries = 4L) {
  wait_secs <- 2

  for (attempt in seq_len(max_retries)) {
    result <- tryCatch({
      message(sprintf("  Fetching %s (attempt %d)...", series_id, attempt))

      obs <- fredr::fredr(
        series_id         = series_id,
        observation_start = as.Date(start_date),
        observation_end   = as.Date(end_date),
        frequency         = "a"  # annual
      )

      if (is.null(obs) || nrow(obs) == 0) {
        message(sprintf("  Empty response for %s", series_id))
        return(NULL)
      }

      obs |>
        dplyr::transmute(
          date      = .data$date,
          year      = as.integer(format(.data$date, "%Y")),
          value     = .data$value,
          series_id = series_id
        )

    }, error = function(e) {
      message(sprintf("  Error fetching %s: %s", series_id, e$message))
      NULL
    })

    if (!is.null(result)) return(result)

    # Exponential backoff on failure
    if (attempt < max_retries) {
      message(sprintf("  Retrying in %d seconds...", wait_secs))
      Sys.sleep(wait_secs)
      wait_secs <- wait_secs * 2
    }
  }

  message(sprintf("  FAILED: %s after %d attempts", series_id, max_retries))
  NULL
}


## ----------------------------------------------------------
## Main fetch loop
## ----------------------------------------------------------

log_file <- file.path(GDP_CONFIG$INTERIM_LOGS, "fetch_fred_log.txt")
log_conn <- file(log_file, open = "wt")

cat(sprintf("FRED GDP Fetch — %s\n", now_stamp()), file = log_conn)

results <- list()

for (label in names(GDP_CONFIG$FRED_SERIES)) {
  series_id <- GDP_CONFIG$FRED_SERIES[[label]]
  message(sprintf("\n[%s] Fetching %s (%s)...", now_stamp(), label, series_id))

  df <- fetch_fred_series(series_id)

  if (is.null(df) || nrow(df) == 0) {
    msg <- sprintf("FAILED: %s (%s)", label, series_id)
    message(msg)
    cat(msg, "\n", file = log_conn)
    next
  }

  ## Filter to year range
  df <- df |> filter(year >= GDP_CONFIG$year_start,
                      year <= GDP_CONFIG$year_end)

  ## Write CSV
  csv_path <- file.path(GDP_CONFIG$RAW_FRED,
                         sprintf("%s.csv", series_id))
  safe_write_csv(df, csv_path)

  ## Log
  msg <- sprintf("OK: %s (%s) — %d obs, years %d-%d",
                 label, series_id, nrow(df),
                 min(df$year), max(df$year))
  message(msg)
  cat(msg, "\n", file = log_conn)

  log_data_quality(df, label)
  results[[label]] <- df
}


## ----------------------------------------------------------
## Summary
## ----------------------------------------------------------

cat(sprintf("\nFetch complete: %d/%d series — %s\n",
            length(results), length(GDP_CONFIG$FRED_SERIES), now_stamp()),
    file = log_conn)
close(log_conn)

message(sprintf("\n=== FRED fetch complete: %d/%d series ===",
                length(results), length(GDP_CONFIG$FRED_SERIES)))
message(sprintf("Data: %s", GDP_CONFIG$RAW_FRED))
message(sprintf("Log: %s", log_file))
