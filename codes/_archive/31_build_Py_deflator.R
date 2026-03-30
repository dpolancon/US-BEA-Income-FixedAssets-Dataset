# ============================================================
# 31_build_Py_deflator.R
# Construct the common GDP deflator (Py) for the canonical CSV
#
# PROVENANCE:
#   Source: GDP Implicit Price Deflator (GDPDEF)
#   Original frequency: Quarterly
#   Vintage: 2012-01-01 (Shaikh's data was downloaded circa 2011-2012)
#   Original base: 2005 = 100
#   Rebase: 2011 = 100 (end-of-sample normalization)
#   Collapse: Annual via Q4 (last quarter of each year)
#
# WHY THIS DEFLATOR:
#   Shaikh (2016, Appendix 6.6, eq. 6.6.7) requires a COMMON deflator
#   for both output (Y) and capital (K) to preserve profit-rate
#   consistency. Separate deflators introduce a spurious relative-price
#   term. Shaikh does NOT tabulate this deflator in any published
#   appendix (confirmed: Appendices 5.3, 6.8, 14.2, 15.2, 16 checked
#   exhaustively — zero GDP deflator columns found).
#
#   The GDP implicit price deflator (BEA NIPA Table 1.1.9, Line 1)
#   is the minimal transparent choice consistent with the common-
#   deflator identification constraint. The 2012 ALFRED vintage is
#   used to match Shaikh's circa-2011 data download window.
#
# AUDIT STATUS:
#   Py is the ONLY column in Shaikh_canonical_series_v1.csv that
#   does not trace back to Shaikh's published Appendix 6.8 tables.
#   All other 33 columns are exact match or explained divergence.
#   See output/CriticalReplication/data_audit/audit3_canonical_vs_shaikh.md
#
# USAGE:
#   source("codes/31_build_Py_deflator.R")
#   Outputs: data/processed/Py_deflator_provenance.csv
#            + console verification against canonical CSV
# ============================================================

library(here)
library(dplyr)
library(readr)

cat("\n========================================\n")
cat("  Py DEFLATOR CONSTRUCTION\n")
cat("========================================\n\n")

# --- 1. Fetch ALFRED 2012-vintage GDPDEF ---
alfred_url <- paste0(
  "https://alfred.stlouisfed.org/graph/alfredgraph.csv",
  "?id=GDPDEF&vintage_date=2012-01-01"
)

cat("Fetching GDPDEF from ALFRED...\n")
cat("  URL:", alfred_url, "\n")

py_raw <- tryCatch(
  read_csv(alfred_url, show_col_types = FALSE),
  error = function(e) {
    cat("  [NETWORK ERROR] Cannot fetch from ALFRED.\n")
    cat("  Falling back to cached file if available.\n")
    cached <- here("data", "raw", "ALFRED_GDPDEF_vintage2012.csv")
    if (file.exists(cached)) {
      read_csv(cached, show_col_types = FALSE)
    } else {
      stop("No cached GDPDEF file and no network. Cannot proceed.")
    }
  }
)

cat("  Rows:", nrow(py_raw), "| Columns:", paste(names(py_raw), collapse = ", "), "\n")

# --- 2. Parse: extract year, collapse to annual (Q4) ---
gdpdef_col <- names(py_raw)[2]  # "GDPDEF_20120101" or similar

py_quarterly <- py_raw %>%
  mutate(
    date     = as.Date(observation_date),
    year     = as.integer(format(date, "%Y")),
    quarter  = as.integer(format(date, "%m")) %/% 4 + 1,
    gdpdef   = as.numeric(.data[[gdpdef_col]])
  ) %>%
  filter(is.finite(year), is.finite(gdpdef))

cat("  Quarterly obs:", nrow(py_quarterly), "\n")
cat("  Year range:", range(py_quarterly$year), "\n")

# Collapse to annual: take Q4 value (last available quarter per year)
py_annual <- py_quarterly %>%
  group_by(year) %>%
  slice_tail(n = 1) %>%
  ungroup() %>%
  select(year, gdpdef)

cat("  Annual obs:", nrow(py_annual), "\n")

# --- 3. Rebase to 2011 = 100 ---
gdpdef_2011 <- py_annual$gdpdef[py_annual$year == 2011]
cat("\n  GDPDEF[2011] (original base 2005=100):", gdpdef_2011, "\n")

py_annual <- py_annual %>%
  mutate(Py = gdpdef / gdpdef_2011 * 100)

cat("  Py[1947]:", round(py_annual$Py[py_annual$year == 1947], 5), "\n")
cat("  Py[2009]:", round(py_annual$Py[py_annual$year == 2009], 5), "\n")
cat("  Py[2011]:", round(py_annual$Py[py_annual$year == 2011], 5), "\n")

# --- 4. Cross-check against canonical CSV ---
cat("\n========================================\n")
cat("  CROSS-CHECK vs CANONICAL CSV\n")
cat("========================================\n")

canon_path <- here("data", "raw", "shaikh_data", "Shaikh_canonical_series_v1.csv")
if (file.exists(canon_path)) {
  canon <- read_csv(canon_path, show_col_types = FALSE)

  check <- merge(
    py_annual %>% select(year, Py_constructed = Py),
    canon %>% select(year, Py_canonical = Py),
    by = "year"
  )
  check <- check %>%
    filter(!is.na(Py_constructed), !is.na(Py_canonical)) %>%
    mutate(
      abs_diff = abs(Py_constructed - Py_canonical),
      pct_diff = 100 * abs_diff / Py_canonical
    )

  cat("  Overlap years:", nrow(check), "\n")
  cat("  Max abs diff:", round(max(check$abs_diff), 6), "\n")
  cat("  Max pct diff:", round(max(check$pct_diff), 6), "%\n")
  cat("  EXACT MATCH (tol=0.01):", all(check$abs_diff < 0.01), "\n")

  if (max(check$abs_diff) > 0.01) {
    cat("\n  Worst 5 years:\n")
    worst <- check %>% arrange(desc(pct_diff)) %>% head(5)
    print(worst, n = 5)

    cat("\n  NOTE: Small discrepancies likely reflect Q4-vs-annual-average\n")
    cat("  collapse method or floating-point rounding in the original build.\n")
    cat("  If discrepancies > 0.1%, try annual average instead of Q4.\n")
  }
} else {
  cat("  [Canonical CSV not found at", canon_path, "]\n")
}

# --- 5. Save provenance file ---
out_path <- here("data", "processed", "Py_deflator_provenance.csv")
dir.create(dirname(out_path), showWarnings = FALSE, recursive = TRUE)

py_out <- py_annual %>%
  select(year, gdpdef_2005base = gdpdef, Py_2011base = Py) %>%
  filter(year >= 1946, year <= 2011)

write_csv(py_out, out_path)
cat("\n  Saved:", out_path, "\n")
cat("  Rows:", nrow(py_out), "\n")

# --- 6. Cache the raw ALFRED fetch ---
cache_path <- here("data", "raw", "ALFRED_GDPDEF_vintage2012.csv")
if (!file.exists(cache_path)) {
  write_csv(py_raw, cache_path)
  cat("  Cached raw ALFRED fetch:", cache_path, "\n")
}

# --- 7. Provenance summary ---
cat("\n========================================\n")
cat("  PROVENANCE SUMMARY\n")
cat("========================================\n")
cat("  Variable: Py (common GDP deflator)\n")
cat("  Source: FRED series GDPDEF\n")
cat("  Vintage: 2012-01-01 (ALFRED)\n")
cat("  Original base: 2005 = 100\n")
cat("  Rebase: 2011 = 100\n")
cat("  Collapse: Quarterly → Annual (last quarter per year)\n")
cat("  BEA equivalent: NIPA Table 1.1.9, Line 1\n")
cat("  Shaikh documentation: NONE (not tabulated in any appendix)\n")
cat("  Canonical CSV column: Py\n")
cat("  Audit status: only CSV column without Shaikh source\n")
cat("========================================\n")
