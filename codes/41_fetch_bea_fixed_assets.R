############################################################
# 41_fetch_bea_fixed_assets.R — Download BEA Fixed Assets
#
# Strategy: API-first (bea.R), CSV fallback.
# Downloads Tables 4.1-4.7 (private) and 6.1-6.4 (govt).
# Parses into standardized long format and writes to:
#   data/raw/bea/         (raw downloads)
#   data/interim/bea_parsed/  (standardized long format)
#
# Requires: bea.R (or beaR), dplyr, readr
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
## BEA API fetch function
## ----------------------------------------------------------

#' Fetch a single BEA Fixed Assets table via API
#'
#' @param table_name BEA table name (e.g., "FAAt401")
#' @param api_key BEA API key
#' @param year "ALL" or specific years
#' @return Data frame from BEA, or NULL on failure
fetch_bea_table_api <- function(table_name, api_key, year = "ALL") {

  # Check if bea.R is available
  if (!requireNamespace("bea.R", quietly = TRUE)) {
    message("  bea.R package not available. Trying beaR...")
    if (!requireNamespace("beaR", quietly = TRUE)) {
      message("  Neither bea.R nor beaR available. Falling back to CSV.")
      return(NULL)
    }
  }

  tryCatch({
    message(sprintf("  Fetching %s from BEA API...", table_name))

    specs <- list(
      UserID    = api_key,
      Method    = "GetData",
      datasetname = "FixedAssets",
      TableName = table_name,
      Frequency = "A",
      Year      = year
    )

    if (requireNamespace("bea.R", quietly = TRUE)) {
      resp <- bea.R::beaGet(specs, asWide = FALSE)
    } else {
      resp <- beaR::beaGet(specs, asWide = FALSE)
    }

    if (is.null(resp) || nrow(resp) == 0) {
      message(sprintf("  Empty response for %s", table_name))
      return(NULL)
    }

    message(sprintf("  Got %d rows for %s", nrow(resp), table_name))
    resp

  }, error = function(e) {
    message(sprintf("  API error for %s: %s", table_name, e$message))
    NULL
  })
}


## ----------------------------------------------------------
## CSV fallback function
## ----------------------------------------------------------

#' Read a BEA table from locally downloaded CSV
#'
#' Expected file naming: FAT_X_Y.csv (e.g., FAT_4_1.csv)
#'
#' @param table_name BEA table name (e.g., "FAAt401")
#' @param raw_dir    Directory containing CSV files
#' @return Parsed long-format tibble, or NULL
fetch_bea_table_csv <- function(table_name, raw_dir) {

  # Convert FAAt401 -> FAT_4_1.csv
  tnum <- gsub("FAAt", "", table_name)
  # Split into table.subtable: "401" -> "4_01", "407" -> "4_07"
  major <- substr(tnum, 1, 1)
  minor <- substr(tnum, 2, nchar(tnum))
  # Remove leading zeros from minor
  minor <- as.integer(minor)
  csv_name <- sprintf("FAT_%s_%d.csv", major, minor)
  csv_path <- file.path(raw_dir, csv_name)

  if (!file.exists(csv_path)) {
    # Try alternative naming
    csv_name2 <- sprintf("Table_%s.%d.csv", major, minor)
    csv_path2 <- file.path(raw_dir, csv_name2)
    if (file.exists(csv_path2)) {
      csv_path <- csv_path2
    } else {
      message(sprintf("  CSV not found: %s or %s", csv_path, csv_path2))
      return(NULL)
    }
  }

  message(sprintf("  Reading CSV: %s", csv_path))
  tryCatch(
    read_bea_csv(csv_path),
    error = function(e) {
      message(sprintf("  CSV parse error: %s", e$message))
      NULL
    }
  )
}


## ----------------------------------------------------------
## Main fetch loop
## ----------------------------------------------------------

log_file <- file.path(GDP_CONFIG$INTERIM_LOGS, "fetch_bea_log.txt")
log_conn <- file(log_file, open = "wt")

cat(sprintf("BEA Fixed Assets Fetch — %s\n", now_stamp()), file = log_conn)
cat(sprintf("API Key: %s...%s\n",
            substr(GDP_CONFIG$BEA_API_KEY, 1, 8),
            substr(GDP_CONFIG$BEA_API_KEY,
                   nchar(GDP_CONFIG$BEA_API_KEY) - 3,
                   nchar(GDP_CONFIG$BEA_API_KEY))),
    file = log_conn)

results <- list()

for (tbl_label in names(GDP_CONFIG$BEA_TABLES)) {
  tbl_name <- GDP_CONFIG$BEA_TABLES[[tbl_label]]
  message(sprintf("\n[%s] Processing %s (%s)...", now_stamp(), tbl_label, tbl_name))

  ## Try API first
  raw_resp <- fetch_bea_table_api(tbl_name, GDP_CONFIG$BEA_API_KEY)

  if (!is.null(raw_resp)) {
    ## Parse API response
    parsed <- parse_bea_api_response(raw_resp)
    source_method <- "API"
  } else {
    ## Fallback to CSV
    parsed <- fetch_bea_table_csv(tbl_name, GDP_CONFIG$RAW_BEA)
    source_method <- "CSV"
  }

  if (is.null(parsed) || nrow(parsed) == 0) {
    msg <- sprintf("FAILED: %s (%s) — no data from API or CSV", tbl_label, tbl_name)
    message(msg)
    cat(msg, "\n", file = log_conn)
    next
  }

  ## Add metadata
  parsed <- parsed |>
    mutate(table_label = tbl_label,
           table_name  = tbl_name,
           source      = source_method)

  ## Filter to year range
  parsed <- parsed |>
    filter(year >= GDP_CONFIG$year_start,
           year <= GDP_CONFIG$year_end)

  ## Write raw download
  raw_path <- file.path(GDP_CONFIG$RAW_BEA,
                         sprintf("%s_raw.csv", tbl_label))
  safe_write_csv(parsed, raw_path)

  ## Write parsed long-format
  parsed_path <- file.path(GDP_CONFIG$INTERIM_BEA_PARSED,
                            sprintf("%s.csv", tbl_label))
  safe_write_csv(parsed, parsed_path)

  ## Log
  msg <- sprintf("OK: %s (%s) via %s — %d rows, years %d-%d",
                 tbl_label, tbl_name, source_method,
                 nrow(parsed),
                 min(parsed$year), max(parsed$year))
  message(msg)
  cat(msg, "\n", file = log_conn)

  ## Log data quality
  log_data_quality(parsed, tbl_label)

  results[[tbl_label]] <- parsed
}

## ----------------------------------------------------------
## Summary
## ----------------------------------------------------------

cat(sprintf("\nFetch complete: %d/%d tables retrieved — %s\n",
            length(results), length(GDP_CONFIG$BEA_TABLES), now_stamp()),
    file = log_conn)
close(log_conn)

message(sprintf("\n=== BEA fetch complete: %d/%d tables ===",
                length(results), length(GDP_CONFIG$BEA_TABLES)))
message(sprintf("Raw data: %s", GDP_CONFIG$RAW_BEA))
message(sprintf("Parsed data: %s", GDP_CONFIG$INTERIM_BEA_PARSED))
message(sprintf("Log: %s", log_file))
