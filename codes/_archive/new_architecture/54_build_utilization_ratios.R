############################################################
# 54_build_utilization_ratios.R — Output-Capital Ratios
#                                   and Distributional Shares
#
# Constructs all output-capital ratio specifications and
# distributional metrics used in the ARDL estimation and
# as supplementary series for the critical replication.
#
# Output-capital ratios (all four pairing specs):
#   R_GVA_KGC  = GVAcorp / KGCcorp      (gross-gross)
#   R_NVA_KGC  = NVA_NF  / KGCcorp      (net-gross — canonical)
#   R_GVA_KNC  = GVAcorp / KNCcorp      (gross-net)
#   R_NVA_KNC  = NVA_NF  / KNCcorp      (net-net)
#
# Distributional metrics (Dataset 1 series — total corporate):
#   exploit_rate = NOScorp / ECcorp      (Shaikh's e_corp)
#   profit_share = Pcorp   / VAcorp      (Profshcorp)
#   rcorp        = Pcorp   / lag(KNCcorp)(profit rate)
#
# Reads:
#   data/processed/income_accounts_NF.csv
#   data/processed/corp_output_series.csv
#   data/processed/corp_kstock_series.csv
#
# Writes:
#   data/processed/utilization_ratios.csv
#   data/processed/corp_exploitation_series.csv  (D1 alias)
#
# Sources: 10_config.R, 99_utils.R
############################################################

rm(list = ls())

library(dplyr)
library(readr)

source("codes/10_config.R")
source("codes/99_utils.R")


## ----------------------------------------------------------
## Load inputs
## ----------------------------------------------------------

load_proc <- function(filename, required_by) {
  path <- file.path(GDP_CONFIG$PROCESSED, filename)
  if (!file.exists(path)) {
    stop("Required file not found: ", path,
         "\nRun ", required_by, " first.")
  }
  readr::read_csv(path, show_col_types = FALSE)
}

income_NF  <- load_proc("income_accounts_NF.csv",      "52_build_income_accounts.R")
corp_out   <- load_proc("corp_output_series.csv",       "52_build_income_accounts.R")
corp_k     <- load_proc("corp_kstock_series.csv",       "53_build_gpim_kstock.R")

message(sprintf("Loaded income_accounts_NF:  %d rows, years %d-%d",
                nrow(income_NF), min(income_NF$year), max(income_NF$year)))
message(sprintf("Loaded corp_output_series:  %d rows, years %d-%d",
                nrow(corp_out), min(corp_out$year), max(corp_out$year)))
message(sprintf("Loaded corp_kstock_series:  %d rows, years %d-%d",
                nrow(corp_k), min(corp_k$year), max(corp_k$year)))


## ----------------------------------------------------------
## Merge all inputs
## ----------------------------------------------------------

message("\n--- Merging inputs ---")

df <- corp_k |>
  dplyr::select(year, KNCcorp, KGCcorp) |>
  dplyr::left_join(
    corp_out |> dplyr::select(year, GVAcorp, VAcorp, NOScorp, ECcorp, Pcorp),
    by = "year"
  ) |>
  dplyr::left_join(
    income_NF |> dplyr::select(year, NVA_NF, GVA_NF, GOS_NF, NOS_NF,
                                 EC_NF, ProfSh_NF, WageSh_NF),
    by = "year"
  ) |>
  dplyr::arrange(year)

message(sprintf("Merged: %d rows, years %d-%d",
                nrow(df), min(df$year), max(df$year)))


## ----------------------------------------------------------
## Output-capital ratios — all four pairing specifications
## ----------------------------------------------------------

message("\n--- Computing output-capital ratios ---")

df <- df |>
  dplyr::mutate(
    ## Gross-gross (Shaikh Dataset 1 canonical)
    R_GVA_KGC = GVAcorp / KGCcorp,

    ## Net-gross (canonical for cointegration — GPIM-consistent)
    R_NVA_KGC = NVA_NF  / KGCcorp,

    ## Gross-net
    R_GVA_KNC = GVAcorp / KNCcorp,

    ## Net-net
    R_NVA_KNC = NVA_NF  / KNCcorp,

    ## Aliases for backward compatibility with estimation scripts
    R_obs = R_GVA_KGC,    # gross-gross (used in ARDL replication)
    R_net = R_GVA_KNC     # gross-net
  )


## ----------------------------------------------------------
## Distributional metrics (total corporate — Dataset 1)
## ----------------------------------------------------------

message("\n--- Computing distributional metrics ---")

df <- df |>
  dplyr::mutate(
    ## Exploitation rate (Shaikh's e_corp = surplus / necessary labor)
    exploit_rate = NOScorp / ECcorp,

    ## Profit share
    profit_share = Pcorp / VAcorp,

    ## Profit rate: profits over lagged net stock
    rcorp = Pcorp / dplyr::lag(KNCcorp)
  )


## ----------------------------------------------------------
## Validation
## ----------------------------------------------------------

message("\n=== UTILIZATION RATIOS VALIDATION ===")

if (1947 %in% df$year) {
  v47 <- df |> dplyr::filter(year == 1947)
  cat(sprintf("  R_NVA_KGC_1947:  %.4f | Rcorp benchmark: ~0.685\n",   v47$R_NVA_KGC))
  cat(sprintf("  R_GVA_KGC_1947:  %.4f | Shaikh R_obs: 0.747\n",       v47$R_GVA_KGC))
  cat(sprintf("  R_GVA_KNC_1947:  %.4f\n",                              v47$R_GVA_KNC))
  cat(sprintf("  R_NVA_KNC_1947:  %.4f\n",                              v47$R_NVA_KNC))
  cat(sprintf("  exploit_1947:    %.4f | Target: ~0.303\n",             v47$exploit_rate))
  cat(sprintf("  profit_sh_1947:  %.4f | Target: ~0.210\n",             v47$profit_share))
}

## Period means
message("\n--- Period means (R_NVA_KGC) ---")
for (period_name in c("Full", "Fordist (pre-1974)", "Post-Fordist (1974+)")) {
  mask <- switch(period_name,
    "Full"               = rep(TRUE, nrow(df)),
    "Fordist (pre-1974)" = df$year < 1974,
    "Post-Fordist (1974+)" = df$year >= 1974
  )
  sub <- df[mask & !is.na(df$R_NVA_KGC), ]
  if (nrow(sub) > 0) {
    cat(sprintf("  %s: R_NVA_KGC = %.4f | exploit = %.4f | profit_sh = %.4f\n",
                period_name,
                mean(sub$R_NVA_KGC,    na.rm = TRUE),
                mean(sub$exploit_rate, na.rm = TRUE),
                mean(sub$profit_share, na.rm = TRUE)))
  }
}


## ----------------------------------------------------------
## Write outputs
## ----------------------------------------------------------

## Primary: all ratio specifications
ratio_cols <- c("year",
                "R_NVA_KGC", "R_GVA_KGC", "R_GVA_KNC", "R_NVA_KNC",
                "GOS_NF", "ProfSh_NF", "WageSh_NF",
                "exploit_rate", "profit_share", "rcorp",
                "R_obs", "R_net")

out_ratios <- df |>
  dplyr::select(dplyr::all_of(intersect(ratio_cols, names(df))))

out_path <- file.path(GDP_CONFIG$PROCESSED, "utilization_ratios.csv")
safe_write_csv(out_ratios, out_path)
message(sprintf("\nWritten: %s (%d rows, years %d-%d)",
                out_path, nrow(out_ratios),
                min(out_ratios$year), max(out_ratios$year)))

## Alias: Dataset 1 backward compatibility
exploit_cols <- c("year", "exploit_rate", "profit_share", "rcorp",
                  "R_obs", "R_net")
out_exploit  <- df |>
  dplyr::select(dplyr::all_of(intersect(exploit_cols, names(df))))

alias_path <- file.path(GDP_CONFIG$PROCESSED, "corp_exploitation_series.csv")
safe_write_csv(out_exploit, alias_path)
message(sprintf("Written: %s [D1 alias]", alias_path))

message("  Next: 55_assemble_prod_cap_dataset.R")
