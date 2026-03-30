############################################################
# 51_fetch_nipa_income.R — Fetch NIPA Income Accounts
#                            + FRED GDP Deflator
#
# Downloads:
#   BEA NIPA T1.14 (T11400) — Nonfinancial corporate income
#     decomposition, Lines 1-40 (total + NF corporate block)
#   BEA NIPA T7.11 (T71100) — Interest paid/received
#     (for Shaikh imputed interest adjustment on Dataset 1)
#   FRED: A191RD3A086NBEA — GDP implicit price deflator (Py)
#
# Writes to:
#   data/interim/bea_parsed/nipa_t1014.csv
#   data/interim/bea_parsed/nipa_t7011.csv
#   data/interim/gdp_components/gdp_deflator_fred.csv
#
# BEA Fixed Assets tables are fetched by:
#   50_fetch_fixed_assets.R
#
# Requires: bea.R (or beaR), fredr, dplyr, readr
# Sources:  10_config.R, 99_utils.R
############################################################

rm(list = ls())

library(dplyr)
library(readr)

source("codes/10_config.R")
source("codes/99_utils.R")

ensure_dirs(GDP_CONFIG)

## ----------------------------------------------------------
## Configuration
## ----------------------------------------------------------

force_refetch <- FALSE   # Set TRUE to re-download existing files

## BEA NIPA tables
## T1.14 is the primary income decomposition for both
## total corporate and nonfinancial corporate (Lines 1-40).
## Lines 17-40 are the NF corporate block used in Dataset 2.
NIPA_TABLES <- list(
  nipa_t1014 = "T11400",   # Table 1.14: Corporate GVA + NF corporate
  nipa_t7011 = "T71100"    # Table 7.11: Interest Paid/Received
)

## FRED series
FRED_DEFLATOR <- "A191RD3A086NBEA"  # GDP implicit price deflator (2017=100)


## ----------------------------------------------------------
## BEA NIPA API fetch
## ----------------------------------------------------------

#' Fetch a BEA NIPA table via API
#'
#' @param table_name  BEA NIPA table name (e.g., "T11400")
#' @param api_key     BEA API key
#' @return Data frame, or NULL on failure
fetch_bea_nipa <- function(table_name, api_key) {

  if (!requireNamespace("bea.R", quietly = TRUE)) {
    if (!requireNamespace("beaR", quietly = TRUE)) {
      stop("Neither bea.R nor beaR available. Install with: ",
           "install.packages('bea.R')")
    }
  }

  message(sprintf("  Fetching %s from BEA NIPA API...", table_name))

  specs <- list(
    UserID      = api_key,
    Method      = "GetData",
    datasetname = "NIPA",
    TableName   = table_name,
    Frequency   = "A",
    Year        = "X"
  )

  tryCatch({
    resp <- if (requireNamespace("bea.R", quietly = TRUE)) {
      bea.R::beaGet(specs, asWide = FALSE)
    } else {
      beaR::beaGet(specs, asWide = FALSE)
    }

    if (is.null(resp) || nrow(resp) == 0) {
      message(sprintf("  Empty response for %s", table_name))
      return(NULL)
    }

    message(sprintf("  Got %d rows for %s", nrow(resp), table_name))
    resp

  }, error = function(e) {
    stop(sprintf("BEA NIPA API FAILED for %s: %s", table_name, e$message))
  })
}


## ----------------------------------------------------------
## FRED fetch
## ----------------------------------------------------------

#' Fetch the GDP implicit price deflator from FRED
#'
#' Series: A191RD3A086NBEA (2017=100, annual)
#' Coverage: 1929-present (pre-1929 years will be NA)
#'
#' @param series_id  FRED series identifier
#' @param api_key    FRED API key
#' @param max_retries Integer, number of retry attempts
#' @return Data frame with columns year, Py
fetch_fred_deflator <- function(series_id, api_key, max_retries = 4L) {

  if (!requireNamespace("fredr", quietly = TRUE)) {
    stop("fredr package required. Install with: install.packages('fredr')")
  }
  fredr::fredr_set_key(api_key)

  wait_secs <- 2

  for (attempt in seq_len(max_retries)) {
    result <- tryCatch({
      message(sprintf("  Fetching FRED %s (attempt %d)...",
                      series_id, attempt))

      obs <- fredr::fredr(
        series_id         = series_id,
        observation_start = as.Date("1925-01-01"),
        observation_end   = as.Date("2024-12-31"),
        frequency         = "a"
      )

      if (is.null(obs) || nrow(obs) == 0) {
        message(sprintf("  Empty response for %s", series_id))
        return(NULL)
      }

      obs |>
        dplyr::transmute(
          year = as.integer(format(.data$date, "%Y")),
          Py   = .data$value
        )

    }, error = function(e) {
      message(sprintf("  Error on attempt %d: %s", attempt, e$message))
      NULL
    })

    if (!is.null(result)) return(result)

    if (attempt < max_retries) {
      message(sprintf("  Retrying in %d seconds...", wait_secs))
      Sys.sleep(wait_secs)
      wait_secs <- wait_secs * 2
    }
  }

  stop(sprintf("FRED FAILED: %s after %d attempts", series_id, max_retries))
}


## ----------------------------------------------------------
## NF corporate line verification
## ----------------------------------------------------------

#' Print and verify T1.14 contains the NF corporate block
#'
#' Lines 17-40 = Nonfinancial corporate business.
#' Lines 1-16  = Total corporate business.
#' Verified by checking for "Nonfinancial corporate" in line_desc.
verify_nipa_t1014 <- function(parsed) {

  unique_lines <- parsed |>
    dplyr::distinct(line_number, line_desc) |>
    dplyr::arrange(line_number)

  cat("\n  --- T1.14: Line labels (first 20) ---\n")
  head_lines <- head(unique_lines, 20)
  for (i in seq_len(nrow(head_lines))) {
    cat(sprintf("    Line %2d: %s\n",
                head_lines$line_number[i],
                head_lines$line_desc[i]))
  }

  has_nf <- any(grepl("nonfinancial corporate",
                       unique_lines$line_desc, ignore.case = TRUE))

  if (!has_nf) {
    stop(paste(
      "DISAMBIGUATION ERROR: NIPA T1.14 does not contain",
      "'Nonfinancial corporate' lines.",
      "Expected Lines 17-40 for NF corporate income decomposition.",
      "Check BEA revision or TableName parameter."
    ))
  }

  nf_lines <- unique_lines |>
    dplyr::filter(grepl("nonfinancial", line_desc, ignore.case = TRUE))
  cat(sprintf("  NF corporate line(s): %s\n",
              paste(sprintf("L%d", nf_lines$line_number), collapse = ", ")))
}


## ----------------------------------------------------------
## Main: Fetch NIPA tables
## ----------------------------------------------------------

log_file <- file.path(GDP_CONFIG$INTERIM_LOGS, "fetch_nipa_income_log.txt")
dir.create(dirname(log_file), showWarnings = FALSE, recursive = TRUE)
log_conn <- file(log_file, open = "wt")

cat(sprintf("NIPA Income + FRED Deflator Fetch — %s\n", now_stamp()),
    file = log_conn)

results <- list()

message(sprintf("\n[%s] === Fetching NIPA tables ===", now_stamp()))

for (tbl_label in names(NIPA_TABLES)) {

  tbl_name <- NIPA_TABLES[[tbl_label]]
  out_path <- file.path(GDP_CONFIG$INTERIM_BEA_PARSED,
                         sprintf("%s.csv", tbl_label))

  if (!force_refetch && file.exists(out_path)) {
    message(sprintf("\n[%s] Skipping %s — already exists", now_stamp(), tbl_label))
    cat(sprintf("SKIP: %s (exists)\n", tbl_label), file = log_conn)
    results[[tbl_label]] <- readr::read_csv(out_path, show_col_types = FALSE)
    next
  }

  message(sprintf("\n[%s] Processing %s (%s)...",
                  now_stamp(), tbl_label, tbl_name))

  raw_resp <- fetch_bea_nipa(tbl_name, GDP_CONFIG$BEA_API_KEY)

  if (is.null(raw_resp)) {
    msg <- sprintf("FAILED: %s (%s)", tbl_label, tbl_name)
    message(msg)
    cat(msg, "\n", file = log_conn)
    stop(msg)
  }

  parsed <- parse_bea_api_response(raw_resp)

  ## Verify T1.14 contains NF corporate block
  if (tbl_label == "nipa_t1014") {
    verify_nipa_t1014(parsed)
  }

  parsed <- parsed |>
    dplyr::mutate(
      table_label = tbl_label,
      table_name  = tbl_name,
      source      = "API"
    )

  safe_write_csv(parsed, out_path)

  msg <- sprintf("OK: %s (%s) — %d rows, years %d-%d",
                 tbl_label, tbl_name, nrow(parsed),
                 min(parsed$year), max(parsed$year))
  message(msg)
  cat(msg, "\n", file = log_conn)

  log_data_quality(parsed, tbl_label)
  results[[tbl_label]] <- parsed
}


## ----------------------------------------------------------
## Main: Fetch FRED GDP deflator (Py)
## ----------------------------------------------------------

message(sprintf("\n[%s] === Fetching FRED GDP deflator ===", now_stamp()))

fred_out_dir  <- GDP_CONFIG$INTERIM_GDP
dir.create(fred_out_dir, showWarnings = FALSE, recursive = TRUE)
fred_out_path <- file.path(fred_out_dir, "gdp_deflator_fred.csv")

if (!force_refetch && file.exists(fred_out_path)) {
  message(sprintf("Skipping FRED deflator — already exists: %s",
                  fred_out_path))
  cat("SKIP: FRED GDP deflator (exists)\n", file = log_conn)
} else {

  fred_df <- fetch_fred_deflator(FRED_DEFLATOR, GDP_CONFIG$FRED_API_KEY)

  if (!is.null(fred_df) && nrow(fred_df) > 0) {

    ## Note: FRED A191RD3A086NBEA starts in 1929.
    ## Years 1925-1928 will be NA — acceptable since GPIM capital
    ## stock construction does not require Py for those years.
    ## Estimation objects (k_Py, y_t) only start from 1947.
    n_na <- sum(is.na(fred_df$Py))
    if (n_na > 0) {
      message(sprintf("  Note: %d years with NA Py (pre-1929 expected)", n_na))
    }

    safe_write_csv(fred_df, fred_out_path)

    py_1947 <- fred_df$Py[fred_df$year == 1947]
    msg <- sprintf(
      "OK: FRED Py (2017=100) — %d obs, years %d-%d, Py_1947=%.3f",
      nrow(fred_df), min(fred_df$year, na.rm = TRUE),
      max(fred_df$year, na.rm = TRUE),
      ifelse(length(py_1947) > 0, py_1947, NA_real_)
    )
    message(msg)
    cat(msg, "\n", file = log_conn)

  } else {
    stop("FRED GDP deflator fetch FAILED")
  }
}


## ----------------------------------------------------------
## Summary
## ----------------------------------------------------------

cat(sprintf("\nFetch complete: %d NIPA tables + FRED Py — %s\n",
            length(results), now_stamp()),
    file = log_conn)
close(log_conn)

message("\n=== NIPA income + FRED deflator fetch complete ===")
message(sprintf("  NIPA tables: %d", length(NIPA_TABLES)))
message(sprintf("  FRED deflator: %s (2017=100)", FRED_DEFLATOR))
message(sprintf("  Parsed data: %s", GDP_CONFIG$INTERIM_BEA_PARSED))
message(sprintf("  Log: %s", log_file))
message("  Next: 52_build_income_accounts.R")
