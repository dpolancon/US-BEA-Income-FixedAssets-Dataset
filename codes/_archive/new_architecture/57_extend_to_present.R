############################################################
# 57_extend_to_present.R — Extend corporate sector dataset
#
# Fetches current BEA/FRED data and runs GPIM recursion
# from the 1947 anchor to extend the sealed dataset to present.
#
# Output:  data/processed/prod_cap_dataset_d1_ext.csv
# NEVER overwrites: data/processed/prod_cap_dataset_d1.csv
#
# Requires: BEA_API_KEY and FRED_API_KEY in .Renviron
############################################################

## §0. Source existing helpers --------------------------------

source(here::here("codes", "97_kstock_helpers.R"))
source(here::here("codes", "99_utils.R"))
source(here::here("codes", "10_config.R"))

## §1. API key validation ------------------------------------

bea_key  <- Sys.getenv("BEA_API_KEY")
fred_key <- Sys.getenv("FRED_API_KEY")
if (nchar(bea_key) == 0)  stop("BEA_API_KEY not set in .Renviron")
if (nchar(fred_key) == 0) stop("FRED_API_KEY not set in .Renviron")

## §2. Install missing packages silently ---------------------

pkgs <- c("httr", "dplyr", "readr", "fredr", "lubridate", "here")
for (p in pkgs) if (!requireNamespace(p, quietly = TRUE)) install.packages(p)

library(dplyr)
library(readr)

## §3. Fetch BEA/FRED data -----------------------------------

## Fetch log
log_dir <- here::here("output", "data_extension")
dir.create(log_dir, showWarnings = FALSE, recursive = TRUE)
log_file <- file.path(log_dir,
                      sprintf("fetch_log_%s.txt", format(Sys.Date(), "%Y%m%d")))
log_lines <- character()
log_msg <- function(msg) {
  cat(msg, "\n")
  log_lines <<- c(log_lines, paste0(now_stamp(), " | ", msg))
}

log_msg("=== BEA/FRED DATA EXTENSION FETCH ===")
log_msg(sprintf("BEA_API_KEY: %s...%s",
                substr(bea_key, 1, 4), substr(bea_key, nchar(bea_key) - 3, nchar(bea_key))))

## --- BEA NIPA Table 1.14 (Corporate GVA) ---
nipa_t1014 <- tryCatch({
  log_msg("Fetching NIPA T1.14 (T11400)...")
  res <- bea_get(dataset = "NIPA", tablename = "T11400",
                 frequency = "A", year = "X", api_key = bea_key)
  log_msg(sprintf("  T1.14: %d rows fetched", nrow(res)))
  res
}, error = function(e) {
  log_msg(sprintf("  T1.14 FAILED: %s", e$message))
  NULL
})

## --- BEA NIPA Table 7.11 (Interest Paid/Received) ---
nipa_t7011 <- tryCatch({
  log_msg("Fetching NIPA T7.11 (T71100)...")
  res <- bea_get(dataset = "NIPA", tablename = "T71100",
                 frequency = "A", year = "X", api_key = bea_key)
  log_msg(sprintf("  T7.11: %d rows fetched", nrow(res)))
  res
}, error = function(e) {
  log_msg(sprintf("  T7.11 FAILED: %s", e$message))
  NULL
})

## --- BEA NIPA Table 1.1.9 (GDP Implicit Price Deflator) ---
nipa_t10109 <- tryCatch({
  log_msg("Fetching NIPA T1.1.9 (T10109)...")
  res <- bea_get(dataset = "NIPA", tablename = "T10109",
                 frequency = "A", year = "X", api_key = bea_key)
  log_msg(sprintf("  T1.1.9: %d rows fetched", nrow(res)))
  res
}, error = function(e) {
  log_msg(sprintf("  T1.1.9 FAILED: %s", e$message))
  NULL
})

## --- BEA Fixed Assets Table 1.1 (Price Index) ---
fa_t101 <- tryCatch({
  log_msg("Fetching FA Table 1.1 (FAAt101)...")
  res <- bea_get(dataset = "FixedAssets", tablename = "FAAt101",
                 frequency = "A", year = "X", api_key = bea_key)
  log_msg(sprintf("  FA 1.1: %d rows fetched", nrow(res)))
  res
}, error = function(e) {
  log_msg(sprintf("  FA 1.1 FAILED: %s", e$message))
  NULL
})

## --- BEA Fixed Assets Table 6.4 (Corporate Depreciation) ---
fa_t604 <- tryCatch({
  log_msg("Fetching FA Table 6.4 (FAAt604)...")
  res <- bea_get(dataset = "FixedAssets", tablename = "FAAt604",
                 frequency = "A", year = "X", api_key = bea_key)
  log_msg(sprintf("  FA 6.4: %d rows fetched", nrow(res)))
  res
}, error = function(e) {
  log_msg(sprintf("  FA 6.4 FAILED: %s", e$message))
  NULL
})

## --- BEA Fixed Assets Tables 6.1 & 6.2 (Net Stock CC & Chain QI) ---
fa_t601 <- tryCatch({
  log_msg("Fetching FA Table 6.1 (FAAt601)...")
  res <- bea_get(dataset = "FixedAssets", tablename = "FAAt601",
                 frequency = "A", year = "X", api_key = bea_key)
  log_msg(sprintf("  FA 6.1: %d rows fetched", nrow(res)))
  res
}, error = function(e) {
  log_msg(sprintf("  FA 6.1 FAILED: %s", e$message))
  NULL
})

fa_t602 <- tryCatch({
  log_msg("Fetching FA Table 6.2 (FAAt602)...")
  res <- bea_get(dataset = "FixedAssets", tablename = "FAAt602",
                 frequency = "A", year = "X", api_key = bea_key)
  log_msg(sprintf("  FA 6.2: %d rows fetched", nrow(res)))
  res
}, error = function(e) {
  log_msg(sprintf("  FA 6.2 FAILED: %s", e$message))
  NULL
})

## --- BEA Fixed Assets Table 6.7 (Corporate Investment) ---
fa_t607 <- tryCatch({
  log_msg("Fetching FA Table 6.7 (FAAt607)...")
  res <- bea_get(dataset = "FixedAssets", tablename = "FAAt607",
                 frequency = "A", year = "X", api_key = bea_key)
  log_msg(sprintf("  FA 6.7: %d rows fetched", nrow(res)))
  res
}, error = function(e) {
  log_msg(sprintf("  FA 6.7 FAILED: %s", e$message))
  NULL
})

## --- FRED: Nonfinancial corporate inventories ---
fred_inv <- tryCatch({
  log_msg("Fetching FRED FL105015205.A (inventories)...")
  fredr::fredr_set_key(fred_key)
  res <- fredr::fredr(series_id = "FL105015205.A",
                      observation_start = as.Date("1947-01-01"),
                      frequency = "a")
  log_msg(sprintf("  FRED inventories: %d rows fetched", nrow(res)))
  res
}, error = function(e) {
  log_msg(sprintf("  FRED inventories FAILED: %s", e$message))
  NULL
})

## Write fetch log
writeLines(log_lines, log_file)
log_msg(sprintf("Fetch log written: %s", log_file))


## §4-5. Extract NIPA series ---------------------------------

## Helper: extract a single line from a BEA NIPA response
extract_bea_line <- function(df, line_num, varname) {
  if (is.null(df)) return(NULL)
  sub <- df |>
    filter(as.integer(LineNumber) == line_num) |>
    mutate(year = as.integer(TimePeriod),
           !!varname := DataValue) |>
    select(year, all_of(varname)) |>
    arrange(year)
  if (nrow(sub) == 0) {
    warning(sprintf("No data for line %d (%s)", line_num, varname))
    return(NULL)
  }
  sub
}

## NIPA Table 1.14
GVAcorpnipa <- extract_bea_line(nipa_t1014, 1, "GVAcorpnipa")
DEPCcorp    <- extract_bea_line(nipa_t1014, 2, "DEPCcorp")
VAcorpnipa  <- extract_bea_line(nipa_t1014, 3, "VAcorpnipa")
ECcorp      <- extract_bea_line(nipa_t1014, 4, "ECcorp")
Tcorp       <- extract_bea_line(nipa_t1014, 7, "Tcorp")
NOScorpnipa <- extract_bea_line(nipa_t1014, 8, "NOScorpnipa")
Pcorpnipa   <- extract_bea_line(nipa_t1014, 11, "Pcorpnipa")

## NIPA Table 7.11 — use ACTUAL line numbers from sealed pipeline (49, 58)
## (Comments in 52_build_income_accounts.R say 74/53, code uses 49/58)
BankMonIntPaid  <- extract_bea_line(nipa_t7011, 4, "BankMonIntPaid")
imp_int_paid_nf <- extract_bea_line(nipa_t7011, 49, "imp_int_paid_nf")
imp_int_recv_nf <- extract_bea_line(nipa_t7011, 58, "imp_int_recv_nf")

## Print T7.11 line labels for verification
if (!is.null(nipa_t7011)) {
  cat("\n--- T7.11 line labels (verification) ---\n")
  line_labels <- nipa_t7011 |>
    distinct(LineNumber, LineDescription) |>
    filter(as.integer(LineNumber) %in% c(4, 49, 58)) |>
    arrange(as.integer(LineNumber))
  for (i in seq_len(nrow(line_labels))) {
    cat(sprintf("  Line %s: %s\n", line_labels$LineNumber[i],
                line_labels$LineDescription[i]))
  }
}

## Build CorpNFNetImpIntPaid
CorpNFNetImpIntPaid <- NULL
if (!is.null(imp_int_paid_nf) && !is.null(imp_int_recv_nf)) {
  CorpNFNetImpIntPaid <- imp_int_paid_nf |>
    left_join(imp_int_recv_nf, by = "year") |>
    mutate(CorpNFNetImpIntPaid = imp_int_paid_nf - imp_int_recv_nf) |>
    select(year, CorpNFNetImpIntPaid)
}

## NIPA Table 1.1.9 — Py (GDP implicit price deflator, Line 1)
Py_raw <- extract_bea_line(nipa_t10109, 1, "Py")


## §6. Construct output series --------------------------------

cat("\n=== CONSTRUCTING OUTPUT SERIES ===\n")

## Merge NIPA series
nipa_list <- list(GVAcorpnipa, DEPCcorp, VAcorpnipa, ECcorp, Tcorp,
                  NOScorpnipa, Pcorpnipa, BankMonIntPaid,
                  CorpNFNetImpIntPaid, Py_raw)
nipa_list <- nipa_list[!sapply(nipa_list, is.null)]

df_nipa <- Reduce(function(x, y) left_join(x, y, by = "year"), nipa_list) |>
  arrange(year)

## Imputed interest adjustment (replicating 52_build_income_accounts.R logic)
df_nipa <- df_nipa |>
  mutate(
    CorpImpIntAdj = -BankMonIntPaid - CorpNFNetImpIntPaid,
    GVAcorp  = GVAcorpnipa + CorpImpIntAdj,
    NOScorp  = NOScorpnipa + CorpImpIntAdj,
    VAcorp   = (GVAcorpnipa - DEPCcorp) + CorpImpIntAdj,
    Pcorp    = Pcorpnipa  # No adjustment (matches sealed pipeline)
  )


## §6b. Extract Fixed Assets series ---------------------------

## Helper: extract corporate line from FA table
## FA tables use "LineNumber" for line identification
extract_fa_corp <- function(df, line_num, varname) {
  if (is.null(df)) return(NULL)
  sub <- df |>
    filter(as.integer(LineNumber) == line_num) |>
    mutate(year = as.integer(TimePeriod),
           !!varname := DataValue) |>
    select(year, all_of(varname)) |>
    arrange(year)
  if (nrow(sub) == 0) {
    warning(sprintf("FA: No data for line %d (%s)", line_num, varname))
    return(NULL)
  }
  sub
}

## FA Table 6.1: Current-cost net stock (corporate nonresidential, line 2)
KNCcorpbea <- extract_fa_corp(fa_t601, 2, "KNCcorpbea")

## FA Table 6.2: Chain-type QI net stock (corporate nonresidential, line 2)
KNRIndxcorpbea <- extract_fa_corp(fa_t602, 2, "KNRIndxcorpbea")

## FA Table 6.4: Current-cost depreciation (corporate, line 2)
DEPCcorpbea <- extract_fa_corp(fa_t604, 2, "DEPCcorpbea")

## FA Table 6.7: Investment (corporate nonresidential, line 2)
IGCcorpbea <- extract_fa_corp(fa_t607, 2, "IGCcorpbea")

## Merge FA series
fa_list <- list(KNCcorpbea, KNRIndxcorpbea, DEPCcorpbea, IGCcorpbea)
fa_list <- fa_list[!sapply(fa_list, is.null)]

if (length(fa_list) > 0) {
  df_fa <- Reduce(function(x, y) left_join(x, y, by = "year"), fa_list) |>
    arrange(year)
} else {
  stop("No Fixed Assets data fetched — cannot build capital stock extension")
}

## Convert chain QI index to real levels (replicating 52 logic)
## Need a base-year value: use 2005 from current-cost / (index/100)
base_year <- 2005
if (base_year %in% df_fa$year) {
  base_2005_val <- df_fa$KNCcorpbea[df_fa$year == base_year]
} else {
  base_2005_val <- NA_real_
  warning("Base year 2005 not in FA data — using KNCcorpbea/KNRIndxcorpbea for pKN")
}

df_fa <- df_fa |>
  mutate(
    KNRcorpbea = if (!is.na(base_2005_val)) {
      KNRIndxcorpbea * base_2005_val / 100
    } else {
      NA_real_
    },
    pKN = (KNCcorpbea / KNRcorpbea) * 100
  )


## §7. Depletion rates ----------------------------------------

cat("\n=== DEPLETION RATES ===\n")

## Compute dcorpstar from fresh BEA data (replicating 52 logic, eq. 6)
df_fa <- df_fa |>
  mutate(
    KNRcorpbea_lag = dplyr::lag(KNRcorpbea),
    dcorpstar = DEPCcorpbea / ((pKN / 100) * KNRcorpbea_lag),
    ## Whelan-Liu approximation for comparison
    KNCcorpbea_lag = dplyr::lag(KNCcorpbea),
    dcorp_WL = DEPCcorpbea / KNCcorpbea_lag
  )

cat(sprintf("  dcorpstar mean (1950+): %.4f\n",
            mean(df_fa$dcorpstar[df_fa$year >= 1950], na.rm = TRUE)))
cat(sprintf("  dcorp_WL  mean (1950+): %.4f\n",
            mean(df_fa$dcorp_WL[df_fa$year >= 1950], na.rm = TRUE)))

## Load canonical CSV for sealed-period comparison
canonical_path <- here::here(CONFIG$data_shaikh)
if (file.exists(canonical_path)) {
  canonical <- read_csv(canonical_path, show_col_types = FALSE)
  cat(sprintf("  Canonical CSV loaded: %d rows, years %d-%d\n",
              nrow(canonical), min(canonical$year, na.rm = TRUE),
              max(canonical$year, na.rm = TRUE)))
} else {
  warning(sprintf("Canonical CSV not found: %s", canonical_path))
  canonical <- NULL
}

## Note: No asset-type depletion rates in canonical CSV.
## For the extension we use dcorpstar computed from current BEA data throughout.
## This is consistent with the sealed pipeline (53_build_gpim_kstock.R ADJ1=TRUE).
## No stub file needed — dcorpstar is computable from BEA data directly.


## §8. GPIM recursion -----------------------------------------

cat("\n=== GPIM RECURSION ===\n")

## Constants (matching sealed pipeline)
K0 <- 170.58                 # canonical 1947 anchor
IRS_BEA_RATIO_1947 <- 0.793  # from 52:60
RET_CORP <- 1 / 35           # 0.02857, from 52:57

## Filter to 1947+ and prepare
df_ext <- df_nipa |>
  inner_join(df_fa |> select(year, KNCcorpbea, KNRcorpbea, IGCcorpbea,
                              DEPCcorpbea, dcorpstar, dcorp_WL, pKN),
             by = "year") |>
  filter(year >= 1947) |>
  arrange(year)

## Depletion rate vector — fill initial NA with mean
dep_rate_vec <- df_ext$dcorpstar
first_valid <- min(which(!is.na(dep_rate_vec)))
if (first_valid > 1) {
  dep_rate_vec[1:(first_valid - 1)] <- mean(dep_rate_vec, na.rm = TRUE)
}

## Real investment
df_ext <- df_ext |>
  mutate(IG_R_net = IGCcorpbea / (pKN / 100))

## Initial net stock (real): replicate sealed pipeline logic
K_net_R_0 <- df_ext$KNRcorpbea[1] * IRS_BEA_RATIO_1947
cat(sprintf("  K_net_R_0 (real, 1947): %.2f\n", K_net_R_0))

## Net stock GPIM recursion
KNR_gpim <- gpim_accumulate_real(df_ext$IG_R_net, dep_rate_vec, K_net_R_0)

df_ext <- df_ext |>
  mutate(
    KNRcorp = KNR_gpim,
    KNCcorp = KNRcorp * (pKN / 100)
  )

## Gross stock GPIM recursion
avg_dep <- mean(dep_rate_vec, na.rm = TRUE)
gross_result <- gpim_build_gross_real(
  IG_R       = df_ext$IG_R_net,
  ret        = RET_CORP,
  K_net_R_0  = K_net_R_0,
  dep_rate   = avg_dep
)

df_ext <- df_ext |>
  mutate(
    KGRcorp = gross_result$K_gross_R,
    KGCcorp = KGRcorp * (pKN / 100)
  )

cat(sprintf("  KGCcorp(1947): %.1f | Target: ~170.6\n",
            df_ext$KGCcorp[df_ext$year == 1947]))
cat(sprintf("  KNCcorp(1947): %.1f | Target: ~77.8\n",
            df_ext$KNCcorp[df_ext$year == 1947]))

## Add inventories POST-RECURSION (from FRED if available)
if (!is.null(fred_inv)) {
  inv_df <- fred_inv |>
    mutate(year = as.integer(format(date, "%Y")),
           INVcorp = value) |>
    select(year, INVcorp)
  df_ext <- df_ext |>
    left_join(inv_df, by = "year") |>
    mutate(
      KTCcorp = KGCcorp + dplyr::coalesce(INVcorp, 0)
    )
  cat(sprintf("  Inventories added post-recursion (%d years with data)\n",
              sum(!is.na(df_ext$INVcorp))))
} else {
  df_ext <- df_ext |>
    mutate(INVcorp = NA_real_, KTCcorp = KGCcorp)
  cat("  Inventories: FRED fetch failed — set to NA\n")
}


## §8b. Exploitation rates ------------------------------------

df_ext <- df_ext |>
  mutate(
    exploit_rate = NOScorp / ECcorp,
    profit_share = Pcorp / VAcorp,
    rcorp        = Pcorp / dplyr::lag(KNCcorp),
    R_obs        = GVAcorp / KGCcorp,
    R_net        = GVAcorp / KNCcorp
  )


## §9. Splice check at 2011 -----------------------------------

cat("\n=== SPLICE CHECK AT 2011 ===\n")

sealed <- read_csv(here::here(CONFIG$data_corp), show_col_types = FALSE)

K_sealed_2011 <- sealed$KGCcorp[sealed$year == 2011]
K_ext_2011    <- df_ext$KGCcorp[df_ext$year == 2011]
V_sealed_2011 <- sealed$VAcorp[sealed$year == 2011]
V_ext_2011    <- df_ext$VAcorp[df_ext$year == 2011]

pct_K <- abs(K_ext_2011 - K_sealed_2011) / K_sealed_2011 * 100
pct_V <- abs(V_ext_2011 - V_sealed_2011) / V_sealed_2011 * 100

cat(sprintf("Splice check KGCcorp @ 2011: %.2f%%\n", pct_K))
cat(sprintf("Splice check VAcorp  @ 2011: %.2f%%\n", pct_V))

if (pct_K > 3 || pct_V > 2) {
  warning("SPLICE TOLERANCE EXCEEDED — review before using for estimation")
}

## Additional splice checks
splice_vars <- c("GVAcorp", "NOScorp", "KNCcorp", "Py", "pKN",
                 "exploit_rate", "profit_share")
for (v in splice_vars) {
  if (v %in% names(sealed) && v %in% names(df_ext)) {
    s_val <- sealed[[v]][sealed$year == 2011]
    e_val <- df_ext[[v]][df_ext$year == 2011]
    if (length(s_val) == 1 && length(e_val) == 1 && !is.na(s_val) && !is.na(e_val)) {
      pct <- abs(e_val - s_val) / abs(s_val) * 100
      status <- if (pct < 1) "PASS" else if (pct < 3) "FLAG" else "FAIL"
      cat(sprintf("  %s %s @ 2011: sealed=%.2f  ext=%.2f  dev=%.2f%%\n",
                  status, v, s_val, e_val, pct))
    }
  }
}


## §10. Transformed variables ----------------------------------

df_ext <- df_ext |>
  mutate(
    y_ext = log(VAcorp  / Py),
    k_ext = log(KGCcorp / Py)
  )


## §11. Output -------------------------------------------------

cat("\n=== WRITING OUTPUT ===\n")

## Assemble final columns (matching sealed dataset structure + extension extras)
out_df <- df_ext |>
  mutate(
    vintage = "current",
    uK = NA_real_
  ) |>
  select(
    year, VAcorp, GVAcorp, DEPCcorp, NOScorp, ECcorp, Pcorp,
    GVAcorpnipa, VAcorpnipa, NOScorpnipa, Pcorpnipa, Tcorp, CorpImpIntAdj,
    KGCcorp, KNCcorp, KNCcorpbea, KNRcorpbea, IGCcorpbea, DEPCcorpbea,
    dcorpstar, dcorp_WL, pKN,
    exploit_rate, profit_share, rcorp, R_obs, R_net,
    Py, uK,
    y_ext, k_ext, vintage
  )

out_path <- here::here("data", "processed", "prod_cap_dataset_d1_ext.csv")

## Safety check: NEVER overwrite the sealed dataset
sealed_path <- here::here(CONFIG$data_corp)
if (normalizePath(out_path, mustWork = FALSE) ==
    normalizePath(sealed_path, mustWork = FALSE)) {
  stop("CRITICAL ERROR: out_path matches sealed dataset path — aborting")
}

safe_write_csv(out_df, out_path)

cat(sprintf("Written: %s\n", out_path))
cat(sprintf("  %d rows, %d columns\n", nrow(out_df), ncol(out_df)))
cat(sprintf("  Year range: %d-%d\n", min(out_df$year), max(out_df$year)))


## §12. Session info -------------------------------------------

cat("\n=== SESSION INFO ===\n")
sessionInfo()
cat(sprintf("Script completed: %s\n", Sys.time()))

## Write final fetch log
log_msg(sprintf("Extension dataset written: %s (%d rows, %d-%d)",
                out_path, nrow(out_df), min(out_df$year), max(out_df$year)))
writeLines(log_lines, log_file)
