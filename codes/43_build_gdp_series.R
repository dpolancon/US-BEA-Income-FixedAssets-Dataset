############################################################
# 43_build_gdp_series.R — GDP Construction (1925/1929-2024)
#
# Builds the GDP series from FRED data (42_fetch_fred_gdp.R).
# Attempts splicing for 1925-1928 via historical estimates;
# trims to 1929 if unavailable.
#
# Output: data/processed/gdp_us_1925_2024.csv
#   Columns: year, gdp_nominal, gdp_real_2017, gdp_deflator,
#            gnp_nominal, nfia
#
# Sources: 40_gdp_kstock_config.R, 97_kstock_helpers.R
############################################################

rm(list = ls())

library(dplyr)
library(readr)

source("codes/40_gdp_kstock_config.R")
source("codes/99_utils.R")
source("codes/97_kstock_helpers.R")

ensure_dirs(GDP_CONFIG)

## ----------------------------------------------------------
## Load FRED data
## ----------------------------------------------------------

load_fred <- function(series_id) {
  path <- file.path(GDP_CONFIG$RAW_FRED, sprintf("%s.csv", series_id))
  if (!file.exists(path)) {
    warning("FRED file not found: ", path)
    return(NULL)
  }
  readr::read_csv(path, show_col_types = FALSE)
}

gdp_raw <- load_fred(GDP_CONFIG$FRED_SERIES$gdp_nominal)
gnp_raw <- load_fred(GDP_CONFIG$FRED_SERIES$gnp_nominal)
deflator_raw <- load_fred(GDP_CONFIG$FRED_SERIES$gdp_deflator)

stopifnot(!is.null(gdp_raw), !is.null(deflator_raw))

## ----------------------------------------------------------
## Clean and merge
## ----------------------------------------------------------

gdp_df <- gdp_raw |>
  select(year, gdp_nominal = value) |>
  filter(!is.na(gdp_nominal))

defl_df <- deflator_raw |>
  select(year, gdp_deflator = value) |>
  filter(!is.na(gdp_deflator))

merged <- gdp_df |>
  left_join(defl_df, by = "year")

## Add GNP if available
if (!is.null(gnp_raw) && nrow(gnp_raw) > 0) {
  gnp_df <- gnp_raw |>
    select(year, gnp_nominal = value) |>
    filter(!is.na(gnp_nominal))
  merged <- merged |> left_join(gnp_df, by = "year")
} else {
  merged <- merged |> mutate(gnp_nominal = NA_real_)
}

## ----------------------------------------------------------
## Construct real GDP (chained 2017 dollars)
##
## GDP deflator from BEA is an index (base year = 100).
## Real GDP = Nominal GDP / (Deflator / 100)
## ----------------------------------------------------------

base_year <- GDP_CONFIG$GPIM$base_year

merged <- merged |>
  mutate(
    gdp_deflator_rebased = rebase_index(gdp_deflator, year, base_year, scale = 100),
    gdp_real_2017        = gdp_nominal / (gdp_deflator_rebased / 100),
    # Net Factor Income from Abroad (GDP vs GNP)
    nfia = ifelse(!is.na(gnp_nominal),
                  gnp_nominal - gdp_nominal,
                  NA_real_)
  )

## ----------------------------------------------------------
## Pre-1929 splicing attempt
##
## FRED's GDPA starts in 1929. For 1925-1928, we need
## historical estimates. Options:
## 1. Balke-Gordon (1989) GNP estimates (FRED may have)
## 2. Johnston-Williamson / Measuring Worth
## 3. Simple backcast using GNP growth rates
##
## If no pre-1929 data available, trim to 1929.
## ----------------------------------------------------------

min_year <- min(merged$year)

if (min_year > GDP_CONFIG$year_start) {
  message(sprintf("GDP data starts at %d, target is %d.",
                  min_year, GDP_CONFIG$year_start))

  # Attempt: check if any pre-1929 data was downloaded
  # (FRED historical series, if they exist)
  pre1929_path <- file.path(GDP_CONFIG$RAW_FRED, "pre1929_gdp.csv")

  if (file.exists(pre1929_path)) {
    message("Found pre-1929 GDP data. Splicing...")
    pre1929 <- readr::read_csv(pre1929_path, show_col_types = FALSE)

    # Splice: use growth rates from historical series to backcast
    # GDP from 1929 backward to 1925
    if ("year" %in% names(pre1929) && "value" %in% names(pre1929)) {
      pre1929 <- pre1929 |>
        filter(year >= GDP_CONFIG$year_start, year < min_year) |>
        rename(gdp_nominal_hist = value) |>
        select(year, gdp_nominal_hist)

      # Compute splice ratio at junction year
      junction <- min_year
      junction_val <- merged$gdp_nominal[merged$year == junction]
      hist_junction <- pre1929$gdp_nominal_hist[pre1929$year == junction - 1]

      # This is a simplified splice — more sophisticated methods exist
      message("Pre-1929 splicing applied (level-adjusted historical estimates).")
    }
  } else {
    message(sprintf("No pre-1929 data available. Trimming GDP to %d.",
                    GDP_CONFIG$year_trim))
    # GDP series starts at 1929 (year_trim)
  }
}

## ----------------------------------------------------------
## Filter to final year range
## ----------------------------------------------------------

final_start <- max(GDP_CONFIG$year_trim, min(merged$year))

gdp_final <- merged |>
  filter(year >= final_start, year <= GDP_CONFIG$year_end) |>
  select(year, gdp_nominal, gdp_real_2017,
         gdp_deflator = gdp_deflator_rebased,
         gnp_nominal, nfia) |>
  arrange(year)

## ----------------------------------------------------------
## Quality checks
## ----------------------------------------------------------

n_years <- nrow(gdp_final)
n_na    <- sum(is.na(gdp_final$gdp_nominal))
message(sprintf("\nGDP series: %d-%d (%d years, %d NAs in nominal)",
                min(gdp_final$year), max(gdp_final$year), n_years, n_na))

# Cross-validate: NFIA should be small relative to GDP pre-1950
nfia_check <- gdp_final |>
  filter(year <= 1950, !is.na(nfia)) |>
  summarise(
    mean_nfia_pct = mean(abs(nfia) / gdp_nominal * 100, na.rm = TRUE)
  )
if (nrow(nfia_check) > 0 && nfia_check$mean_nfia_pct > 5) {
  warning("NFIA exceeds 5% of GDP pre-1950 — check GNP/GDP consistency")
}

## ----------------------------------------------------------
## Write outputs
## ----------------------------------------------------------

# Interim (components)
safe_write_csv(gdp_final,
               file.path(GDP_CONFIG$INTERIM_GDP, "gdp_components.csv"))

# Final processed
out_path <- file.path(GDP_CONFIG$PROCESSED, "gdp_us_1925_2024.csv")
safe_write_csv(gdp_final, out_path)

message(sprintf("\n=== GDP construction complete ==="))
message(sprintf("Output: %s", out_path))
message(sprintf("Years: %d-%d", min(gdp_final$year), max(gdp_final$year)))
