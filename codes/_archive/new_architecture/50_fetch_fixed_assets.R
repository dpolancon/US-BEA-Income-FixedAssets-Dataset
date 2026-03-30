############################################################
# 50_fetch_fixed_assets.R — Fetch BEA Fixed Assets Tables
#
# Downloads BEA FixedAssets dataset tables for all accounts
# needed to construct productive capital stocks under GPIM:
#
#   Section 6 (Private FA by Legal Form):
#     FAAt601 — Current-Cost Net Stock
#     FAAt602 — Chain-Type QI Net Stock
#     FAAt603 — Historical-Cost Net Stock
#     FAAt604 — Current-Cost Depreciation
#     FAAt607 — Investment in Private FA
#
#   Section 7 (Government FA):
#     FAAt701 — Current-Cost Net Stock
#     FAAt702 — Chain-Type QI Net Stock
#     FAAt705 — Investment in Government FA
#
# Writes to:
#   data/interim/bea_parsed/fa_private_*.csv   (Section 6)
#   data/interim/bea_parsed/fa_govt_*.csv      (Section 7)
#
# NIPA income accounts and FRED Py deflator are fetched by:
#   51_fetch_nipa_income.R
#
# Requires: bea.R (or beaR), dplyr, readr
# Sources:  10_config.R, 99_utils.R, 97_kstock_helpers.R
############################################################

rm(list = ls())

library(dplyr)
library(readr)

source("codes/10_config.R")
source("codes/99_utils.R")
source("codes/97_kstock_helpers.R")

ensure_dirs(GDP_CONFIG)

## ----------------------------------------------------------
## Configuration
## ----------------------------------------------------------

force_refetch <- FALSE   # Set TRUE to re-download existing files

## BEA FixedAssets — Section 6: Private FA by Legal Form
## Provides NF corporate, Financial corporate, Noncorporate
FA_PRIVATE_TABLES <- list(
  fa_private_net_cc    = "FAAt601",   # Table 6.1: Current-Cost Net Stock
  fa_private_net_chain = "FAAt602",   # Table 6.2: Chain-Type QI Net Stock
  fa_private_net_hist  = "FAAt603",   # Table 6.3: Historical-Cost Net Stock
  fa_private_dep_cc    = "FAAt604",   # Table 6.4: Current-Cost Depreciation
  fa_private_inv_cc    = "FAAt607"    # Table 6.7: Investment in Private FA
)

## BEA FixedAssets — Section 7: Government FA
## Provides government transportation infrastructure (highways,
## air transport, land transport) — complementary productive capital
FA_GOVT_TABLES <- list(
  fa_govt_net_cc    = "FAAt701",   # Table 7.1: Current-Cost Net Stock
  fa_govt_net_chain = "FAAt702",   # Table 7.2: Chain-Type QI Net Stock
  fa_govt_inv_cc    = "FAAt705"    # Table 7.5: Investment in Government FA
)

## All tables to fetch
ALL_FA_TABLES <- c(FA_PRIVATE_TABLES, FA_GOVT_TABLES)


## ----------------------------------------------------------
## BEA API fetch (FixedAssets dataset only)
## ----------------------------------------------------------

#' Fetch a BEA FixedAssets table via API
#'
#' @param table_name  BEA table name (e.g., "FAAt601")
#' @param api_key     BEA API key
#' @return Data frame, or NULL on failure
fetch_bea_fixed_assets <- function(table_name, api_key) {

  if (!requireNamespace("bea.R", quietly = TRUE)) {
    if (!requireNamespace("beaR", quietly = TRUE)) {
      stop("Neither bea.R nor beaR available. Install with: ",
           "install.packages('bea.R')")
    }
  }

  message(sprintf("  Fetching %s from BEA FixedAssets API...", table_name))

  specs <- list(
    UserID      = api_key,
    Method      = "GetData",
    datasetname = "FixedAssets",
    TableName   = table_name,
    Frequency   = "A",
    Year        = "ALL"
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
    stop(sprintf("BEA API FAILED for %s: %s", table_name, e$message))
  })
}


## ----------------------------------------------------------
## Line verification (account-neutral)
## ----------------------------------------------------------

#' Verify that a parsed BEA table contains expected line descriptions
#'
#' @param parsed       Long-format tibble with line_desc column
#' @param expected_pat Character vector of regex patterns to match
#' @param label        Table label for messages
#' @param require_all  If TRUE, all patterns must match; else any
verify_expected_lines <- function(parsed, expected_pat, label,
                                   require_all = FALSE) {

  unique_lines <- parsed |>
    dplyr::distinct(line_number, line_desc) |>
    dplyr::arrange(line_number)

  cat(sprintf("\n  --- %s: First 10 line labels ---\n", label))
  head_lines <- head(unique_lines, 10)
  for (i in seq_len(nrow(head_lines))) {
    cat(sprintf("    Line %2d: %s\n",
                head_lines$line_number[i],
                head_lines$line_desc[i]))
  }

  matches <- sapply(expected_pat, function(pat) {
    any(grepl(pat, unique_lines$line_desc, ignore.case = TRUE))
  })

  if (require_all && !all(matches)) {
    stop(sprintf(
      "DISAMBIGUATION ERROR: Table %s missing expected lines.\n",
      label,
      "Missing patterns: %s\n",
      "Got lines: %s",
      paste(expected_pat[!matches], collapse = "; "),
      paste(head(unique_lines$line_desc, 5), collapse = "; ")
    ))
  } else if (!any(matches)) {
    stop(sprintf(
      "DISAMBIGUATION ERROR: Table %s contains no expected lines.\n",
      label,
      "Expected any of: %s\n",
      "Got lines: %s",
      paste(expected_pat, collapse = "; "),
      paste(head(unique_lines$line_desc, 5), collapse = "; ")
    ))
  }

  found <- unique_lines |>
    dplyr::filter(Reduce(`|`, lapply(expected_pat, function(p)
      grepl(p, line_desc, ignore.case = TRUE))))
  cat(sprintf("  Expected line(s) found: %s\n",
              paste(sprintf("Line %d: %s",
                            found$line_number, found$line_desc),
                    collapse = "; ")))
}

## Expected patterns by table family
EXPECTED_PRIVATE <- c("Nonfinancial", "Financial", "Corporate")
EXPECTED_GOVT    <- c("Government", "Federal", "State and local")


## ----------------------------------------------------------
## Main: Fetch all FixedAssets tables
## ----------------------------------------------------------

log_file <- file.path(GDP_CONFIG$INTERIM_LOGS, "fetch_fixed_assets_log.txt")
dir.create(dirname(log_file), showWarnings = FALSE, recursive = TRUE)
log_conn <- file(log_file, open = "wt")

cat(sprintf("BEA Fixed Assets Fetch — %s\n", now_stamp()), file = log_conn)
cat(sprintf("Tables: %d private (Section 6) + %d government (Section 7)\n",
            length(FA_PRIVATE_TABLES), length(FA_GOVT_TABLES)),
    file = log_conn)

results <- list()

for (tbl_label in names(ALL_FA_TABLES)) {

  tbl_name  <- ALL_FA_TABLES[[tbl_label]]
  is_govt   <- tbl_label %in% names(FA_GOVT_TABLES)
  out_path  <- file.path(GDP_CONFIG$INTERIM_BEA_PARSED,
                          sprintf("%s.csv", tbl_label))

  ## Skip if already exists and not forcing refetch
  if (!force_refetch && file.exists(out_path)) {
    message(sprintf("\n[%s] Skipping %s — already exists: %s",
                    now_stamp(), tbl_label, out_path))
    cat(sprintf("SKIP: %s (exists)\n", tbl_label), file = log_conn)
    results[[tbl_label]] <- readr::read_csv(out_path, show_col_types = FALSE)
    next
  }

  message(sprintf("\n[%s] Processing %s (%s)...",
                  now_stamp(), tbl_label, tbl_name))

  ## Fetch
  raw_resp <- fetch_bea_fixed_assets(tbl_name, GDP_CONFIG$BEA_API_KEY)

  if (is.null(raw_resp)) {
    msg <- sprintf("FAILED: %s (%s) — no data", tbl_label, tbl_name)
    message(msg)
    cat(msg, "\n", file = log_conn)
    stop(msg)
  }

  ## Parse to long format
  parsed <- parse_bea_api_response(raw_resp)

  ## Verify expected lines (account-neutral)
  expected <- if (is_govt) EXPECTED_GOVT else EXPECTED_PRIVATE
  verify_expected_lines(parsed, expected, tbl_label)

  ## Add metadata
  parsed <- parsed |>
    dplyr::mutate(
      table_label = tbl_label,
      table_name  = tbl_name,
      section     = if (is_govt) "govt" else "private",
      source      = "API"
    )

  ## Write
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
## Summary
## ----------------------------------------------------------

n_private <- sum(names(results) %in% names(FA_PRIVATE_TABLES))
n_govt    <- sum(names(results) %in% names(FA_GOVT_TABLES))

cat(sprintf("\nFetch complete: %d private + %d government tables — %s\n",
            n_private, n_govt, now_stamp()),
    file = log_conn)
close(log_conn)

message("\n=== BEA Fixed Assets fetch complete ===")
message(sprintf("  Section 6 (Private FA): %d tables", n_private))
message(sprintf("  Section 7 (Government FA): %d tables", n_govt))
message(sprintf("  Parsed data: %s", GDP_CONFIG$INTERIM_BEA_PARSED))
message(sprintf("  Log: %s", log_file))
message("  Next: 51_fetch_nipa_income.R")
