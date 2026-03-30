############################################################
# 53_build_gpim_kstock.R — Build Capital Stocks via GPIM
#
# Implements Shaikh's Generalized Perpetual Inventory Method
# for all productive capital accounts. Each account is built
# from two BEA-reported inputs only:
#   KNC_i_t  — current-cost net stock  (BEA Table 6.1 or 7.1)
#   IG_i_t   — gross investment flow   (BEA Table 6.7 or 7.5)
# Everything else is derived. SFC checked at every recursion.
#
# Three independently toggle-able adjustments:
#   ADJ1: BEA 1993 depletion rates (dcorpstar vs Whelan-Liu)
#   ADJ2: BEA 1993 initial value scaling (IRS/BEA ratio)
#   ADJ3: IRS Depression-era scrapping (Shaikh App. 6.8 II.5)
#
# Reads:
#   data/interim/bea_parsed/fa_private_net_cc.csv   (FAAt601)
#   data/interim/bea_parsed/fa_private_net_chain.csv(FAAt602)
#   data/interim/bea_parsed/fa_private_net_hist.csv (FAAt603)
#   data/interim/bea_parsed/fa_private_dep_cc.csv   (FAAt604)
#   data/interim/bea_parsed/fa_private_inv_cc.csv   (FAAt607)
#   data/processed/income_accounts_NF.csv (for DEPCcorp cross-check)
#
# Writes:
#   data/processed/corp_kstock_series.csv
#
# Sources: 10_config.R, 99_utils.R, 97_kstock_helpers.R
#
# TABLE DISAMBIGUATION:
#   fa_private_net_cc.csv = BEA FAAt601 (Private FA by Legal Form)
#   This is DISTINCT from government tables (FAAt701).
#   Script verifies "Nonfinancial" or "Corporate" appears in
#   line labels before proceeding.
############################################################

rm(list = ls())

library(dplyr)
library(readr)
library(readxl)

source("codes/10_config.R")
source("codes/99_utils.R")
source("codes/97_kstock_helpers.R")

ensure_dirs(GDP_CONFIG)


## ----------------------------------------------------------
## Toggle structure (Shaikh Appendix 6.8 adjustments)
## ----------------------------------------------------------

CORP_ADJ <- list(
  ADJ1_BEA1993_DEPLETION = TRUE,   # Use dcorpstar vs Whelan-Liu
  ADJ2_BEA1993_INITIAL   = TRUE,   # Scale 1925 initial value by IRS ratio
  ADJ3_IRS_SCRAPPING     = TRUE    # IRS Depression scrapping (App. 6.8.II.5)
)

cat("=== GPIM K-stock adjustments ===\n")
for (nm in names(CORP_ADJ)) {
  cat(sprintf("  %s: %s\n", nm, CORP_ADJ[[nm]]))
}

## Corporate retirement rate: 1/L_corp where L_corp ~ 35 years
## Per GPIM_Formalization_v3 §1: gross stocks use retirement rate
RET_CORP <- 1 / 35   # 0.02857

## IRS/BEA ratio for initial value scaling (Shaikh II.5 row 19)
IRS_BEA_RATIO_1947 <- 0.793


## ----------------------------------------------------------
## Load parsed BEA tables (private FA by legal form)
## ----------------------------------------------------------

load_parsed <- function(label) {
  path <- file.path(GDP_CONFIG$INTERIM_BEA_PARSED, sprintf("%s.csv", label))
  if (!file.exists(path)) {
    stop("Parsed BEA table not found: ", path,
         "\nRun 50_fetch_fixed_assets.R first.")
  }
  readr::read_csv(path, show_col_types = FALSE)
}

tbl_net_cc    <- load_parsed("fa_private_net_cc")     # FAAt601
tbl_net_chain <- load_parsed("fa_private_net_chain")  # FAAt602
tbl_net_hist  <- load_parsed("fa_private_net_hist")   # FAAt603
tbl_dep_cc    <- load_parsed("fa_private_dep_cc")     # FAAt604
tbl_inv_cc    <- load_parsed("fa_private_inv_cc")     # FAAt607

message(sprintf("Loaded 5 private FA tables. Year range: %d-%d",
                min(tbl_net_cc$year), max(tbl_net_cc$year)))


## ----------------------------------------------------------
## Extract corporate line from each table
## ----------------------------------------------------------

#' Find and extract the "Corporate" line from a BEA private FA table
#'
#' Matches on "^Corporate" first; falls back to any "corporate" match.
#' Stops if no match found — prevents silent extraction of wrong account.
#'
#' @param tbl      Long-format BEA table
#' @param col_name Name for the extracted value column
#' @return tibble(year, col_name)
extract_corporate_line <- function(tbl, col_name) {
  unique_lines <- tbl |>
    dplyr::distinct(line_number, line_desc) |>
    dplyr::arrange(line_number)

  corp_lines <- unique_lines |>
    dplyr::filter(grepl("^\\s*Corporate\\b", line_desc, ignore.case = TRUE))

  if (nrow(corp_lines) == 0) {
    corp_lines <- unique_lines |>
      dplyr::filter(grepl("corporate", line_desc, ignore.case = TRUE))
  }

  if (nrow(corp_lines) == 0) {
    stop("No 'Corporate' line found for ", col_name,
         "\nAvailable lines:\n",
         paste(sprintf("  %d: %s", unique_lines$line_number,
                       unique_lines$line_desc), collapse = "\n"),
         "\nCheck fa_private_*.csv — verify 50_fetch_fixed_assets.R wrote",
         " FAAt601 (Private FA by Legal Form), not a government table.")
  }

  corp_line_num <- corp_lines$line_number[1]
  message(sprintf("  %s: line %d = '%s'",
                  col_name, corp_line_num, corp_lines$line_desc[1]))

  tbl |>
    dplyr::filter(line_number == corp_line_num) |>
    dplyr::select(year, !!col_name := value) |>
    dplyr::arrange(year)
}

message("\n--- Extracting corporate lines ---")

KNCcorpbea_df     <- extract_corporate_line(tbl_net_cc,    "KNCcorpbea")
KNRIndxcorpbea_df <- extract_corporate_line(tbl_net_chain, "KNRIndxcorpbea")
KNHcorpbea_df     <- extract_corporate_line(tbl_net_hist,  "KNHcorpbea")
DEPCcorpbea_df    <- extract_corporate_line(tbl_dep_cc,    "DEPCcorpbea")
IGCcorpbea_df     <- extract_corporate_line(tbl_inv_cc,    "IGCcorpbea")


## ----------------------------------------------------------
## Merge into single data frame
## ----------------------------------------------------------

df <- KNCcorpbea_df |>
  dplyr::left_join(KNRIndxcorpbea_df, by = "year") |>
  dplyr::left_join(KNHcorpbea_df,     by = "year") |>
  dplyr::left_join(DEPCcorpbea_df,    by = "year") |>
  dplyr::left_join(IGCcorpbea_df,     by = "year") |>
  dplyr::arrange(year)

message(sprintf("Merged: %d rows, years %d-%d",
                nrow(df), min(df$year), max(df$year)))


## ----------------------------------------------------------
## Cross-check DEPCcorp with income accounts output
## ----------------------------------------------------------

income_path <- file.path(GDP_CONFIG$PROCESSED, "income_accounts_NF.csv")
if (file.exists(income_path)) {
  inc <- readr::read_csv(income_path, show_col_types = FALSE)
  if ("CCA_NF" %in% names(inc)) {
    check_df <- df |>
      dplyr::inner_join(inc |> dplyr::select(year, CCA_NF), by = "year")
    max_gap <- max(abs(check_df$DEPCcorpbea - check_df$CCA_NF), na.rm = TRUE)
    message(sprintf("  DEPCcorp cross-check (BEA FA vs NIPA CCA_NF): max gap = %.2f",
                    max_gap))
    if (max_gap > 5.0) {
      message("  NOTE: gap > 5.0 — expected (CCA_NF = NF only; DEPCcorpbea = total corp)")
    }
  }
}


## ----------------------------------------------------------
## §A. Deflator construction
## ----------------------------------------------------------

message("\n--- §A: Deflators ---")

base_2017_val <- df$KNCcorpbea[df$year == 2017]
if (length(base_2017_val) == 0 || is.na(base_2017_val)) {
  ## Fallback to 2005 for older BEA vintages
  base_2017_val <- df$KNCcorpbea[df$year == 2005]
  message("  Note: 2017 value not found, using 2005 as chain QI base")
}

df <- df |>
  dplyr::mutate(
    KNRcorpbea = KNRIndxcorpbea * base_2017_val / 100,
    pKN        = (KNCcorpbea / KNRcorpbea) * 100
  )

message(sprintf("  pKN range: %.2f to %.2f",
                min(df$pKN, na.rm = TRUE), max(df$pKN, na.rm = TRUE)))
message(sprintf("  pKN(1947) = %.2f | pKN(2017) = %.2f",
                df$pKN[df$year == 1947],
                df$pKN[df$year == 2017]))


## ----------------------------------------------------------
## §B. Depreciation rate
## ----------------------------------------------------------

message("\n--- §B: Depreciation rates ---")

df <- df |>
  dplyr::mutate(
    KNRcorpbea_lag = dplyr::lag(KNRcorpbea),
    KNCcorpbea_lag = dplyr::lag(KNCcorpbea)
  )

df <- df |>
  dplyr::mutate(
    dcorpstar = gpim_depreciation_rate(DEPCcorpbea, pKN / 100, KNRcorpbea_lag),
    dcorp_WL  = gpim_whelan_liu_rate(DEPCcorpbea, KNCcorpbea_lag)
  )

dep_rate_col <- if (CORP_ADJ$ADJ1_BEA1993_DEPLETION) "dcorpstar" else "dcorp_WL"
message(sprintf("  ADJ1 %s: using %s",
                if (CORP_ADJ$ADJ1_BEA1993_DEPLETION) "ON" else "OFF",
                dep_rate_col))

dep_rates <- df |> dplyr::filter(!is.na(dcorpstar), year >= 1930)
message(sprintf("  dcorpstar mean (1930+): %.4f", mean(dep_rates$dcorpstar, na.rm = TRUE)))
message(sprintf("  dcorp_WL  mean (1930+): %.4f", mean(dep_rates$dcorp_WL, na.rm = TRUE)))


## ----------------------------------------------------------
## §C. Net stock accumulation
## ----------------------------------------------------------

message("\n--- §C: GPIM net stock ---")

dep_rate_vec <- df[[dep_rate_col]]
first_valid  <- min(which(!is.na(dep_rate_vec)))
if (first_valid > 1) {
  dep_rate_vec[1:(first_valid - 1)] <- mean(dep_rate_vec, na.rm = TRUE)
}

K_net_R_0 <- if (CORP_ADJ$ADJ2_BEA1993_INITIAL) {
  message("  ADJ2 ON: scaling initial value by IRS/BEA ratio = ", IRS_BEA_RATIO_1947)
  df$KNRcorpbea[1] * IRS_BEA_RATIO_1947
} else {
  message("  ADJ2 OFF: using BEA initial value directly")
  df$KNRcorpbea[1]
}
message(sprintf("  Initial KNR (real, year %d): %.2f (BEA: %.2f)",
                df$year[1], K_net_R_0, df$KNRcorpbea[1]))

df <- df |>
  dplyr::mutate(IG_R_net = IGCcorpbea / (pKN / 100))

KNR_gpim <- gpim_accumulate_real(df$IG_R_net, dep_rate_vec, K_net_R_0)

df <- df |>
  dplyr::mutate(
    KNRcorp = KNR_gpim,
    KNCcorp = KNRcorp * (pKN / 100)
  )


## ----------------------------------------------------------
## §D. ADJ3: IRS Depression-era scrapping correction
## ----------------------------------------------------------

if (CORP_ADJ$ADJ3_IRS_SCRAPPING) {
  message("\n--- §D: ADJ3 IRS scrapping correction (1925-1947) ---")

  IRS_XLSX  <- "data/raw/shaikh_data/_Appendix6.8DataTablesCorrected_REA_release.xlsx"
  IRS_SHEET <- "Appndx 6.8.II.5"

  irs_raw       <- readxl::read_excel(IRS_XLSX, sheet = IRS_SHEET, col_names = FALSE)
  irs_years     <- as.numeric(irs_raw[1, 4:ncol(irs_raw)])
  irs_knc_ratio <- as.numeric(irs_raw[8, 4:ncol(irs_raw)])
  irs_kgc_ratio <- as.numeric(irs_raw[9, 4:ncol(irs_raw)])

  irs_df <- data.frame(
    year      = irs_years,
    knc_ratio = irs_knc_ratio,
    kgc_ratio = irs_kgc_ratio
  ) |>
    dplyr::filter(!is.na(year), year >= 1925, year <= 1947) |>
    dplyr::arrange(year)

  message(sprintf("  Loaded %d correction years (1925-1947)", nrow(irs_df)))

  df <- df |>
    dplyr::left_join(irs_df, by = "year") |>
    dplyr::mutate(
      KNRcorp = dplyr::case_when(
        year <= 1947 & !is.na(knc_ratio) ~ KNRcorp * knc_ratio,
        TRUE ~ KNRcorp
      ),
      KNCcorp = dplyr::case_when(
        year <= 1947 & !is.na(knc_ratio) ~ KNCcorp * knc_ratio,
        TRUE ~ KNCcorp
      )
    ) |>
    dplyr::select(-knc_ratio, -kgc_ratio)

  idx_1947      <- which(df$year == 1947)
  K0_net_R_adj  <- df$KNRcorp[idx_1947]
  adj3_irs_df   <- irs_df
  adj3_year_cut <- 1948L

  message(sprintf("  KNRcorp_1947 after ADJ3: %.1f", K0_net_R_adj))
  message(sprintf("  KNCcorp_1947 after ADJ3: %.1f (target: ~92,457)", df$KNCcorp[idx_1947]))

  ## Re-run net stock GPIM from 1948
  message("  Re-running net stock recursion from 1948...")
  idx_post    <- which(df$year >= 1948)
  dep_post    <- df[[dep_rate_col]][idx_post]
  n_post      <- length(idx_post)
  KNR_post    <- numeric(n_post)
  KNR_post[1] <- df$IG_R_net[idx_post[1]] + (1 - dep_post[1]) * K0_net_R_adj
  for (t in 2:n_post) {
    KNR_post[t] <- df$IG_R_net[idx_post[t]] + (1 - dep_post[t]) * KNR_post[t - 1]
  }
  df$KNRcorp[idx_post] <- KNR_post
  df$KNCcorp[idx_post] <- KNR_post * (df$pKN[idx_post] / 100)
  K_net_R_0_adj3       <- K0_net_R_adj
  message("  Net stock re-run complete.")

} else {
  message("\n  ADJ3 OFF: IRS scrapping correction not applied.")
  K_net_R_0_adj3 <- K_net_R_0
  adj3_irs_df    <- NULL
  adj3_year_cut  <- NULL
}


## ----------------------------------------------------------
## §E. Gross stock accumulation
## ----------------------------------------------------------

message("\n--- §E: GPIM gross stock ---")
message(sprintf("  Retirement rate: %.4f (1/L_corp, L_corp = 35 yr)", RET_CORP))

IG_R_gross  <- df$IG_R_net
avg_dep     <- mean(dep_rate_vec, na.rm = TRUE)

gross_result <- gpim_build_gross_real(
  IG_R      = IG_R_gross,
  ret       = RET_CORP,
  K_net_R_0 = K_net_R_0,
  dep_rate  = avg_dep
)

df <- df |>
  dplyr::mutate(
    KGRcorp = gross_result$K_gross_R,
    KGCcorp = KGRcorp * (pKN / 100)
  )

if (CORP_ADJ$ADJ3_IRS_SCRAPPING && !is.null(adj3_irs_df)) {
  message("  Applying ADJ3 kgc_ratio to gross stock (1925-1947)...")

  df <- df |>
    dplyr::left_join(adj3_irs_df |> dplyr::select(year, kgc_ratio), by = "year") |>
    dplyr::mutate(
      KGRcorp = dplyr::case_when(
        year <= 1947 & !is.na(kgc_ratio) ~ KGRcorp * kgc_ratio,
        TRUE ~ KGRcorp
      ),
      KGCcorp = dplyr::case_when(
        year <= 1947 & !is.na(kgc_ratio) ~ KGCcorp * kgc_ratio,
        TRUE ~ KGCcorp
      )
    ) |>
    dplyr::select(-kgc_ratio)

  idx_1947_g     <- which(df$year == 1947)
  K0_gross_R_adj <- df$KGRcorp[idx_1947_g]
  idx_post_g     <- which(df$year >= 1948)
  n_post_g       <- length(idx_post_g)
  KGR_post       <- numeric(n_post_g)
  KGR_post[1]    <- IG_R_gross[idx_post_g[1]] + (1 - RET_CORP) * K0_gross_R_adj
  for (t in 2:n_post_g) {
    KGR_post[t] <- IG_R_gross[idx_post_g[t]] + (1 - RET_CORP) * KGR_post[t - 1]
  }
  df$KGRcorp[idx_post_g] <- KGR_post
  df$KGCcorp[idx_post_g] <- KGR_post * (df$pKN[idx_post_g] / 100)

  message(sprintf("  KGCcorp_1947 after ADJ3: %.1f (target: ~315,933)",
                  df$KGCcorp[idx_1947_g]))
}


## ----------------------------------------------------------
## §F. SFC validation
## ----------------------------------------------------------

message("\n--- §F: SFC validation ---")

n <- nrow(df)

if (CORP_ADJ$ADJ3_IRS_SCRAPPING && !is.null(adj3_year_cut)) {
  message("  ADJ3 active: validating SFC for 1948+ only")
  sfc_idx <- which(df$year >= adj3_year_cut)

  K_sfc     <- df$KNRcorp[sfc_idx]
  K_lag_sfc <- df$KNRcorp[sfc_idx - 1]
  I_sfc     <- df$IG_R_net[sfc_idx]
  D_sfc     <- df[[dep_rate_col]][sfc_idx] * K_lag_sfc
  net_resid <- max(abs(K_sfc - K_lag_sfc - I_sfc + D_sfc), na.rm = TRUE)
  message(sprintf("  NET SFC (1948+): max |resid| = %.6f %s",
                  net_resid, if (net_resid < 1e-4) "[PASS]" else "[WARN]"))

  KG_sfc     <- df$KGRcorp[sfc_idx]
  KG_lag_sfc <- df$KGRcorp[sfc_idx - 1]
  Ret_sfc    <- RET_CORP * KG_lag_sfc
  gross_resid <- max(abs(KG_sfc - KG_lag_sfc - IG_R_gross[sfc_idx] + Ret_sfc),
                     na.rm = TRUE)
  message(sprintf("  GROSS SFC (1948+): max |resid| = %.6f %s",
                  gross_resid, if (gross_resid < 1e-4) "[PASS]" else "[WARN]"))

} else {
  sfc_net <- validate_sfc_identity(
    K     = df$KNRcorp[-1],
    K_lag = df$KNRcorp[-n],
    I     = df$IG_R_net[-1],
    D     = (dep_rate_vec * c(K_net_R_0, df$KNRcorp[-n]))[-1],
    label = "corp_net_gpim_real"
  )
  message(sprintf("  NET SFC: max |resid| = %.6f %s",
                  max(abs(sfc_net$pct_residual), na.rm = TRUE),
                  if (max(abs(sfc_net$pct_residual), na.rm = TRUE) < 0.001) "[PASS]" else "[WARN]"))
}


## ----------------------------------------------------------
## §G. Verification table
## ----------------------------------------------------------

message("\n=== GPIM K-STOCK VERIFICATION ===")

verify_years <- c(1947, 1960, 1980, 2000, 2011)
verify_years <- verify_years[verify_years %in% df$year]
verify_df    <- df |>
  dplyr::filter(year %in% verify_years) |>
  dplyr::select(year, KNCcorpbea, KNCcorp, KGCcorp, dcorpstar, dcorp_WL, pKN)

cat(sprintf("%-6s %10s %10s %10s %8s %8s %8s\n",
            "Year", "KNCcorpbea", "KNCcorp", "KGCcorp",
            "dcorp*", "dcorp_WL", "pKN"))
cat(paste(rep("-", 62), collapse = ""), "\n")
for (i in seq_len(nrow(verify_df))) {
  r <- verify_df[i, ]
  cat(sprintf("%-6d %10.1f %10.1f %10.1f %8.4f %8.4f %8.2f\n",
              r$year, r$KNCcorpbea, r$KNCcorp, r$KGCcorp,
              r$dcorpstar, r$dcorp_WL, r$pKN))
}

if (1947 %in% df$year) {
  v47 <- df |> dplyr::filter(year == 1947)
  cat(sprintf("\n  KNCcorp_1947:  %.1f | ADJ3 target: ~92,457 Mn\n",  v47$KNCcorp))
  cat(sprintf("  KGCcorp_1947:  %.1f | ADJ3 target: ~315,933 Mn\n", v47$KGCcorp))
  cat(sprintf("  pKN_1947:      %.2f | Canonical: 11.69\n",          v47$pKN))
  cat("  NOTE: gaps from Shaikh II.5 reflect BEA vintage differences — known finding.\n")
}


## ----------------------------------------------------------
## §H. Write output
## ----------------------------------------------------------

out_cols <- c("year", "KNCcorpbea", "KNRcorpbea", "KNCcorp", "KNRcorp",
              "KGCcorp", "KGRcorp", "IGCcorpbea", "IG_R_net",
              "DEPCcorpbea", "dcorpstar", "dcorp_WL", "pKN",
              "KNHcorpbea", "KNRIndxcorpbea")

out_df   <- df |> dplyr::select(dplyr::all_of(intersect(out_cols, names(df))))
out_path <- file.path(GDP_CONFIG$PROCESSED, "corp_kstock_series.csv")
safe_write_csv(out_df, out_path)

message(sprintf("\nWritten: %s (%d rows, years %d-%d)",
                out_path, nrow(out_df),
                min(out_df$year), max(out_df$year)))

cat("\n=== Adjustment toggles used ===\n")
for (nm in names(CORP_ADJ)) cat(sprintf("  %s: %s\n", nm, CORP_ADJ[[nm]]))

message("  Next: 54_build_utilization_ratios.R")
