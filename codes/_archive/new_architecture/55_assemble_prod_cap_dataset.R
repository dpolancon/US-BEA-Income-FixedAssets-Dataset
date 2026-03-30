############################################################
# 55_assemble_prod_cap_dataset.R — Assemble Dataset 1
#
# Merges all productive capital series into the canonical
# Dataset 1 CSV for the ARDL estimation pipeline.
#
# Primary deliverable:
#   data/processed/prod_cap_dataset_d1.csv
#
# Backward-compatibility alias (for 20-26 estimation scripts):
#   data/processed/corporate_sector_dataset.csv
#
# This file must contain all series needed to run
# 20_S0_shaikh_faithful.R through 26_S0_redesign.R with:
#   CONFIG$y_nom  = "GVAcorp"  or  "VAcorp"
#   CONFIG$k_nom  = "KGCcorp"
#   CONFIG$p_index = "Py"
#
# Also contains the NF corporate series for Dataset 2
# robustness checks:
#   NVA_NF, KGCcorp (→ R_NVA_KGC), GOS_NF, NOS_NF
#
# Reads:
#   data/processed/income_accounts_NF.csv
#   data/processed/corp_output_series.csv
#   data/processed/corp_kstock_series.csv
#   data/processed/utilization_ratios.csv
#   data/interim/gdp_components/gdp_deflator_fred.csv  (primary)
#     OR data/processed/gdp_us_1925_2024.csv           (fallback)
#
# Writes:
#   data/processed/prod_cap_dataset_d1.csv
#   data/processed/corporate_sector_dataset.csv  (alias)
#
# Sources: 10_config.R, 99_utils.R
############################################################

rm(list = ls())

library(dplyr)
library(readr)

source("codes/10_config.R")
source("codes/99_utils.R")


## ----------------------------------------------------------
## Load component datasets
## ----------------------------------------------------------

load_processed <- function(filename, required = TRUE, required_by = NULL) {
  path <- file.path(GDP_CONFIG$PROCESSED, filename)
  if (!file.exists(path)) {
    path2 <- file.path(GDP_CONFIG$INTERIM_GDP, filename)
    if (file.exists(path2)) return(readr::read_csv(path2, show_col_types = FALSE))
    if (required) {
      msg <- paste0("Required file not found: ", path)
      if (!is.null(required_by)) msg <- paste0(msg, "\nRun ", required_by, " first.")
      stop(msg)
    }
    return(NULL)
  }
  readr::read_csv(path, show_col_types = FALSE)
}

income_NF  <- load_processed("income_accounts_NF.csv",   required_by = "52_build_income_accounts.R")
corp_out   <- load_processed("corp_output_series.csv",    required_by = "52_build_income_accounts.R")
corp_k     <- load_processed("corp_kstock_series.csv",    required_by = "53_build_gpim_kstock.R")
ratios     <- load_processed("utilization_ratios.csv",    required_by = "54_build_utilization_ratios.R")

message(sprintf("income_accounts_NF:    %d rows, years %d-%d",
                nrow(income_NF), min(income_NF$year), max(income_NF$year)))
message(sprintf("corp_output_series:    %d rows, years %d-%d",
                nrow(corp_out), min(corp_out$year), max(corp_out$year)))
message(sprintf("corp_kstock_series:    %d rows, years %d-%d",
                nrow(corp_k), min(corp_k$year), max(corp_k$year)))
message(sprintf("utilization_ratios:    %d rows, years %d-%d",
                nrow(ratios), min(ratios$year), max(ratios$year)))


## ----------------------------------------------------------
## Load GDP deflator (Py)
## ----------------------------------------------------------

message("\n--- Loading GDP deflator (Py) ---")

fred_path <- file.path(GDP_CONFIG$INTERIM_GDP, "gdp_deflator_fred.csv")
gdp_path  <- file.path(GDP_CONFIG$PROCESSED, "gdp_us_1925_2024.csv")

if (file.exists(fred_path)) {
  py_df <- readr::read_csv(fred_path, show_col_types = FALSE)
  if (!"Py" %in% names(py_df)) {
    if ("gdp_deflator" %in% names(py_df)) py_df <- py_df |> dplyr::rename(Py = gdp_deflator)
    else if ("value"   %in% names(py_df)) py_df <- py_df |> dplyr::rename(Py = value)
  }
  message(sprintf("  Loaded FRED GDP deflator: %d rows", nrow(py_df)))
} else if (file.exists(gdp_path)) {
  gdp_df <- readr::read_csv(gdp_path, show_col_types = FALSE)
  py_df  <- if ("gdp_deflator" %in% names(gdp_df)) {
    gdp_df |> dplyr::select(year, Py = gdp_deflator)
  } else {
    gdp_df |> dplyr::select(year, Py)
  }
  message(sprintf("  Loaded Py from 40-series fallback: %d rows", nrow(py_df)))
} else {
  stop("No GDP deflator found.\n",
       "  Expected: ", fred_path, "\n  Or: ", gdp_path,
       "\n  Run 51_fetch_nipa_income.R first.")
}

py_df <- py_df |> dplyr::select(year, Py) |> dplyr::arrange(year)
message(sprintf("  Py(1947) = %.3f | Py(2017) = %.3f",
                py_df$Py[py_df$year == 1947],
                py_df$Py[py_df$year == 2017]))


## ----------------------------------------------------------
## Merge all components
## ----------------------------------------------------------

message("\n--- Assembling productive capital dataset (D1) ---")

df <- corp_out |>
  dplyr::select(year, GVAcorp, VAcorp, DEPCcorp, NOScorp, ECcorp, Pcorp,
                GVAcorpnipa, VAcorpnipa, NOScorpnipa, Pcorpnipa, Tcorp,
                CorpImpIntAdj) |>
  dplyr::inner_join(
    corp_k |> dplyr::select(year, KGCcorp, KNCcorp, KNCcorpbea, KNRcorpbea,
                              IGCcorpbea, DEPCcorpbea, dcorpstar, dcorp_WL, pKN),
    by = "year"
  ) |>
  dplyr::left_join(
    ratios |> dplyr::select(year, exploit_rate, profit_share, rcorp,
                              R_obs, R_net, R_NVA_KGC, R_GVA_KGC),
    by = "year"
  ) |>
  dplyr::left_join(
    income_NF |> dplyr::select(year, NVA_NF, GVA_NF, GOS_NF, NOS_NF,
                                  EC_NF, ProfSh_NF, WageSh_NF),
    by = "year"
  ) |>
  dplyr::left_join(py_df, by = "year") |>
  dplyr::arrange(year) |>
  dplyr::mutate(uK = NA_real_)   # filled by ARDL estimation run

message(sprintf("  Assembled: %d rows, %d columns, years %d-%d",
                nrow(df), ncol(df), min(df$year), max(df$year)))


## ----------------------------------------------------------
## Identity checks
## ----------------------------------------------------------

message("\n--- Identity checks ---")

df <- df |>
  dplyr::mutate(gva_gap = GVAcorp - (VAcorp + DEPCcorp))

gva_viol <- df |> dplyr::filter(abs(gva_gap) >= 0.5)
if (nrow(gva_viol) > 0) {
  cat(sprintf("  WARNING: GVAcorp != VAcorp + DEPCcorp in %d years\n",
              nrow(gva_viol)))
} else {
  message("  GVAcorp = VAcorp + DEPCcorp: PASS")
}
df <- df |> dplyr::select(-gva_gap)


## ----------------------------------------------------------
## Required columns check
## ----------------------------------------------------------

REQUIRED_COLS <- c(
  "year", "GVAcorp", "VAcorp", "DEPCcorp", "NOScorp", "ECcorp",
  "Pcorp", "KGCcorp", "KNCcorp", "Py", "pKN",
  "exploit_rate", "profit_share", "rcorp", "uK",
  "NVA_NF", "R_NVA_KGC"
)

missing_cols <- setdiff(REQUIRED_COLS, names(df))
if (length(missing_cols) > 0) {
  stop("Missing required columns: ", paste(missing_cols, collapse = ", "))
}
message(sprintf("  All %d required columns present", length(REQUIRED_COLS)))


## ----------------------------------------------------------
## Final verification
## ----------------------------------------------------------

cat("\n=== PRODUCTIVE CAPITAL DATASET VERIFICATION ===\n")

if (1947 %in% df$year) {
  v <- df |> dplyr::filter(year == 1947)
  cat(sprintf("GVAcorp_1947:   %8.1f | Target: 127.5\n",   v$GVAcorp))
  cat(sprintf("NVA_NF_1947:    %8.1f | Rcorp benchmark input\n", v$NVA_NF))
  cat(sprintf("KGCcorp_1947:   %8.1f | Canonical: ~170,580 Mn\n", v$KGCcorp))
  cat(sprintf("KNCcorp_1947:   %8.1f | ADJ3 target: ~92,457 Mn\n", v$KNCcorp))
  cat(sprintf("R_NVA_KGC_1947: %8.4f | Rcorp benchmark: ~0.685\n", v$R_NVA_KGC))
  cat(sprintf("R_GVA_KGC_1947: %8.4f | Shaikh: ~0.747\n",  v$R_GVA_KGC))
  cat(sprintf("Py_1947:        %8.3f | Should be ~11.43 (2017=100)\n", v$Py))
  cat(sprintf("pKN_1947:       %8.2f | Canonical: 11.69\n", v$pKN))
  cat(sprintf("exploit_1947:   %8.4f | Target: ~0.303\n",   v$exploit_rate))
}

cat(sprintf("Year range:  %d-%d\n", min(df$year), max(df$year)))
cat(sprintf("Columns:     %d\n",    ncol(df)))

## OLS theta pre-screen
df_w <- df |>
  dplyr::filter(year >= 1947, year <= 2011, !is.na(Py), Py > 0) |>
  dplyr::mutate(
    lnY_GVA  = log(GVAcorp / (Py / 100)),
    lnY_NVA  = log(NVA_NF  / (Py / 100)),
    lnK      = log(KGCcorp / (Py / 100))
  ) |>
  dplyr::filter(is.finite(lnY_GVA), is.finite(lnK))

if (nrow(df_w) > 10) {
  theta_GVA <- cov(df_w$lnY_GVA, df_w$lnK) / var(df_w$lnK)
  theta_NVA <- cov(df_w$lnY_NVA, df_w$lnK) / var(df_w$lnK)
  cat(sprintf("\nOLS theta (GVA, 1947-2011): %.4f | Shaikh target: 0.661\n", theta_GVA))
  cat(sprintf("OLS theta (NVA, 1947-2011): %.4f | Canonical benchmark: 0.775\n", theta_NVA))
}


## ----------------------------------------------------------
## Write outputs
## ----------------------------------------------------------

## Primary deliverable
primary_path <- file.path(GDP_CONFIG$PROCESSED, "prod_cap_dataset_d1.csv")
safe_write_csv(df, primary_path)
cat(sprintf("\n=== Written: %s ===\n", primary_path))
cat(sprintf("  %d rows, %d columns, years %d-%d\n",
            nrow(df), ncol(df), min(df$year), max(df$year)))

## Backward-compatibility alias for 20-26 estimation scripts
alias_path <- file.path(GDP_CONFIG$PROCESSED, "corporate_sector_dataset.csv")
file.copy(primary_path, alias_path, overwrite = TRUE)
cat(sprintf("  Alias: %s\n", alias_path))
cat("  Ready for: Rscript codes/20_S0_shaikh_faithful.R\n")

message("  Next: 56_run_d1_pipeline.R  (or 57_extend_to_present.R)")
