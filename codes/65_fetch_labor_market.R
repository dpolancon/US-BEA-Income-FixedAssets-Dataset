############################################################
# 65_fetch_labor_market.R — Fetch Unemployment & Labor Market
#
# Fetches and assembles labor market series for 1929-2024:
#
# From FRED:
#   UNRATE              — Civilian unemployment rate (1948+)
#   M0892AUSM156SNBR    — NBER unemployment rate (1929-04 to 1942-06, SA)
#   M0892BUSM156SNBR    — NBER unemployment rate (1940-01 to 1946-12, SA)
#   M0892CUSM156NNBR    — NBER unemployment rate (1947-01 to 1948-12, NSA)
#   UEMPMEAN            — Average weeks unemployed (1948+)
#   UEMP27OV            — Long-term unemployed 27+ weeks (1948+)
#   PAYEMS              — Total nonfarm payrolls (1939+)
#
# Splice logic:
#   urate = NBER A→B→C for 1929-1947, UNRATE for 1948-2024
#   Methodological break at 1948: NBER uses pop 14+, CPS uses 16+
#
# Note: BEA NIPA Table 6.x employment by legal form is NOT
# available via the BEA API. Table 6.4D (by industry) only
# starts 1998. Use FRED PAYEMS (nonfarm) as best available.
#
# Writes:
#   data/processed/US_labor_market_1929_2024.csv
#
# Requires: fredr, dplyr, readr
############################################################

rm(list = ls())

library(dplyr)
library(readr)

source("codes/99_utils.R")


## ----------------------------------------------------------
## API keys
## ----------------------------------------------------------

FRED_KEY <- Sys.getenv("FRED_API_KEY",
                       unset = "fc67199ea06d765ef79b3011dcf75c45")

PROCESSED <- "data/processed"


## ----------------------------------------------------------
## FRED fetch helper (with retry)
## ----------------------------------------------------------

fetch_fred <- function(series_id, start = "1925-01-01", end = "2024-12-31",
                       freq = "a", max_retries = 4L) {

  if (!requireNamespace("fredr", quietly = TRUE)) {
    stop("fredr package required. Install with: install.packages('fredr')")
  }
  fredr::fredr_set_key(FRED_KEY)

  wait_secs <- 2
  for (attempt in seq_len(max_retries)) {
    result <- tryCatch({
      message(sprintf("  Fetching FRED %s (attempt %d)...", series_id, attempt))

      obs <- fredr::fredr(
        series_id         = series_id,
        observation_start = as.Date(start),
        observation_end   = as.Date(end),
        frequency         = freq
      )

      if (is.null(obs) || nrow(obs) == 0) {
        message(sprintf("  Empty response for %s", series_id))
        return(NULL)
      }

      obs |>
        dplyr::transmute(
          year  = as.integer(format(.data$date, "%Y")),
          month = as.integer(format(.data$date, "%m")),
          value = .data$value
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

## Annual aggregation helper (mean of monthly values)
annual_mean <- function(monthly_df, col_name) {
  monthly_df |>
    dplyr::group_by(year) |>
    dplyr::summarise(!!col_name := mean(value, na.rm = TRUE),
                     .groups = "drop")
}


## ===========================================================
## STEP 1: Fetch FRED series
## ===========================================================

message("\n=== STEP 1: FRED Series ===")

## --- Modern unemployment rate (1948+, annual) ---
unrate <- fetch_fred("UNRATE", freq = "a") |>
  dplyr::select(year, value) |>
  dplyr::rename(unrate_modern = value)
message(sprintf("  UNRATE: %d obs, %d-%d",
                nrow(unrate), min(unrate$year), max(unrate$year)))

## --- NBER Macrohistory: three sub-series (monthly) ---
## A: 1929-04 to 1942-06 (SA)
nber_a <- fetch_fred("M0892AUSM156SNBR",
                     start = "1929-01-01", end = "1950-12-31",
                     freq = "m")
message(sprintf("  NBER-A: %d monthly obs", nrow(nber_a)))

## B: 1940-01 to 1946-12 (SA)
nber_b <- fetch_fred("M0892BUSM156SNBR",
                     start = "1940-01-01", end = "1950-12-31",
                     freq = "m")
message(sprintf("  NBER-B: %d monthly obs", nrow(nber_b)))

## C: 1947-01 to 1948-12 (NSA)
nber_c <- fetch_fred("M0892CUSM156NNBR",
                     start = "1947-01-01", end = "1950-12-31",
                     freq = "m")
message(sprintf("  NBER-C: %d monthly obs", nrow(nber_c)))

## Splice NBER monthly: A → B → C (prefer later series at overlaps)
nber_monthly <- dplyr::bind_rows(
  nber_a |> dplyr::mutate(source = "NBER-A"),
  nber_b |> dplyr::mutate(source = "NBER-B"),
  nber_c |> dplyr::mutate(source = "NBER-C")
) |>
  dplyr::arrange(year, month, source) |>
  ## At overlaps, keep the later sub-series (B over A, C over B)
  dplyr::group_by(year, month) |>
  dplyr::slice_tail(n = 1) |>
  dplyr::ungroup()

## Aggregate to annual mean
nber_annual <- nber_monthly |>
  annual_mean("unrate_nber")
message(sprintf("  NBER spliced annual: %d obs, %d-%d",
                nrow(nber_annual), min(nber_annual$year), max(nber_annual$year)))

## --- Duration series (1948+, annual) ---
uempmean <- fetch_fred("UEMPMEAN", freq = "a") |>
  dplyr::select(year, value) |>
  dplyr::rename(mean_weeks_unemp = value)
message(sprintf("  UEMPMEAN: %d obs, %d-%d",
                nrow(uempmean), min(uempmean$year), max(uempmean$year)))

uemp27 <- fetch_fred("UEMP27OV", freq = "a") |>
  dplyr::select(year, value) |>
  dplyr::rename(long_term_unemp_27w = value)
message(sprintf("  UEMP27OV: %d obs, %d-%d",
                nrow(uemp27), min(uemp27$year), max(uemp27$year)))

## --- Nonfarm payrolls (1939+, annual) ---
payems <- fetch_fred("PAYEMS", freq = "a") |>
  dplyr::select(year, value) |>
  dplyr::rename(nonfarm_payrolls = value)
message(sprintf("  PAYEMS: %d obs, %d-%d",
                nrow(payems), min(payems$year), max(payems$year)))


## ===========================================================
## STEP 2: Splice unemployment rate
## ===========================================================

message("\n=== STEP 2: Splice Unemployment Rate ===")

## Build year frame 1929-2024
yr_frame <- tibble::tibble(year = 1929L:2024L)

splice <- yr_frame |>
  dplyr::left_join(nber_annual, by = "year") |>
  dplyr::left_join(unrate, by = "year") |>
  dplyr::mutate(
    ## Prefer UNRATE from 1948+; use NBER for 1929-1947
    urate = dplyr::case_when(
      !is.na(unrate_modern)  ~ unrate_modern,
      !is.na(unrate_nber)    ~ unrate_nber,
      TRUE                   ~ NA_real_
    ),
    urate_source = dplyr::case_when(
      !is.na(unrate_modern)  ~ "UNRATE",
      !is.na(unrate_nber)    ~ "NBER",
      TRUE                   ~ NA_character_
    )
  ) |>
  dplyr::select(year, urate, urate_source)

## Report
n_nber <- sum(splice$urate_source == "NBER", na.rm = TRUE)
n_cps  <- sum(splice$urate_source == "UNRATE", na.rm = TRUE)
n_na   <- sum(is.na(splice$urate))
message(sprintf("  Spliced: %d NBER + %d UNRATE + %d NA = %d total",
                n_nber, n_cps, n_na, nrow(splice)))

gap_years <- splice$year[is.na(splice$urate)]
if (length(gap_years) > 0) {
  message(sprintf("  WARNING: gap years with no urate: %s",
                  paste(gap_years, collapse = ", ")))
}


## ===========================================================
## STEP 3: Assemble final dataset
## ===========================================================

message("\n=== STEP 3: Assemble ===")

df <- splice |>
  dplyr::left_join(uempmean, by = "year") |>
  dplyr::left_join(uemp27, by = "year") |>
  dplyr::left_join(payems, by = "year") |>
  dplyr::arrange(year)


## ----------------------------------------------------------
## Verification
## ----------------------------------------------------------

message("\n=== Verification ===")

if (1933 %in% df$year) {
  v33 <- df$urate[df$year == 1933]
  cat(sprintf("  urate(1933) = %.1f%% | Expected ~24.9%% (Depression peak)\n", v33))
}

if (2020 %in% df$year) {
  v20 <- df$urate[df$year == 2020]
  cat(sprintf("  urate(2020) = %.1f%% | Expected ~8.1%% (COVID annual avg)\n", v20))
}

if (2010 %in% df$year && "mean_weeks_unemp" %in% names(df)) {
  v10 <- df$mean_weeks_unemp[df$year == 2010]
  cat(sprintf("  mean_weeks(2010) = %.1f | Expected ~33-35 weeks\n", v10))
}

cat(sprintf("\n  Year range: %d-%d (%d obs)\n", min(df$year), max(df$year), nrow(df)))
cat(sprintf("  Columns: %s\n", paste(names(df), collapse = ", ")))

for (col in setdiff(names(df), c("year", "urate_source"))) {
  n_avail <- sum(!is.na(df[[col]]))
  if (n_avail > 0) {
    yr_min <- min(df$year[!is.na(df[[col]])], na.rm = TRUE)
    yr_max <- max(df$year[!is.na(df[[col]])], na.rm = TRUE)
    cat(sprintf("  %-22s: %d obs, %d-%d\n", col, n_avail, yr_min, yr_max))
  } else {
    cat(sprintf("  %-22s: 0 obs (all NA)\n", col))
  }
}

cat("\n  Spot values:\n")
for (yr in c(1929, 1933, 1942, 1945, 1947, 1948, 1980, 2007, 2020, 2024)) {
  if (yr %in% df$year) {
    v <- df |> dplyr::filter(year == yr)
    if (!is.na(v$urate)) {
      cat(sprintf("  %d: urate=%5.1f%% (%s)", yr, v$urate, v$urate_source))
    } else {
      cat(sprintf("  %d: urate=   NA", yr))
    }
    if ("mean_weeks_unemp" %in% names(v) && !is.na(v$mean_weeks_unemp)) {
      cat(sprintf(" | weeks=%.1f", v$mean_weeks_unemp))
    }
    if ("nonfarm_payrolls" %in% names(v) && !is.na(v$nonfarm_payrolls)) {
      cat(sprintf(" | payrolls=%.0f", v$nonfarm_payrolls))
    }
    cat("\n")
  }
}


## ----------------------------------------------------------
## Write output
## ----------------------------------------------------------

out_path <- file.path(PROCESSED, "US_labor_market_1929_2024.csv")
safe_write_csv(df, out_path)

cat(sprintf("\n=== Written: %s ===\n", out_path))
cat(sprintf("  %d rows, %d columns, years %d-%d\n",
            nrow(df), ncol(df), min(df$year), max(df$year)))

message("\nColumns:")
message("  urate              — unemployment rate (%, spliced NBER A+B+C → UNRATE)")
message("  urate_source       — provenance: 'NBER' (1929-1947) or 'UNRATE' (1948+)")
message("  mean_weeks_unemp   — average weeks unemployed (1948+)")
message("  long_term_unemp_27w — unemployed 27+ weeks, thousands (1948+)")
message("  nonfarm_payrolls   — total nonfarm employment, thousands (1939+)")
message("\nNote: BEA NIPA employment by legal form (NF corporate)")
message("  is NOT available via the BEA API. Table 6.4D (by industry)")
message("  starts 1998 only. PAYEMS is best available long-run proxy.")
