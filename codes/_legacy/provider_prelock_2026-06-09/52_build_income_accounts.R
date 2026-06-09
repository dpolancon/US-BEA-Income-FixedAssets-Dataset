############################################################
# 52_build_income_accounts.R — Build NF Corporate Income Accounts
#
# Extracts the full nonfinancial corporate income decomposition
# from NIPA Table 1.14 (Lines 1-40) and Table 7.11.
#
# Constructs:
#   Income side (NF corporate block, T1.14 Lines 17-40):
#     GVA_NF, CCA_NF, NVA_NF, EC_NF, Wages_NF, Supplements_NF,
#     TPI_NF, NOS_NF, NetInt_NF, BusTransfer_NF,
#     Profits_IVA_CC_NF, CorpTax_NF, PAT_IVA_CC_NF,
#     Dividends_NF, Retained_IVA_CC_NF, PBT_NF, PAT_NF,
#     Retained_NF, IVA_NF, CCAdj_NF
#
#   Total corporate block (T1.14 Lines 1-16) — Dataset 1 compat:
#     GVAcorpnipa, DEPCcorp, VAcorpnipa, ECcorp, Tcorp,
#     NOScorpnipa, Pcorpnipa
#
#   Shaikh imputed interest adjustment (T7.11):
#     CorpImpIntAdj = -BankMonIntPaid - CorpNFNetImpIntPaid
#     GVAcorp = GVAcorpnipa + CorpImpIntAdj   (Dataset 1 series)
#
#   Derived series:
#     GOS_NF = GVA_NF - EC_NF - TPI_NF
#     ProfSh_NF = NOS_NF / NVA_NF
#     WageSh_NF = EC_NF / NVA_NF
#
# Reads:
#   data/interim/bea_parsed/nipa_t1014.csv
#   data/interim/bea_parsed/nipa_t7011.csv
#
# Writes:
#   data/processed/income_accounts_NF.csv    (NF corporate block)
#   data/processed/corp_output_series.csv    (Dataset 1 compat alias)
#
# Sources: 10_config.R, 99_utils.R
############################################################

rm(list = ls())

library(dplyr)
library(readr)

source("codes/10_config.R")
source("codes/99_utils.R")


## ----------------------------------------------------------
## Load NIPA tables
## ----------------------------------------------------------

load_nipa <- function(label) {
  path <- file.path(GDP_CONFIG$INTERIM_BEA_PARSED, sprintf("%s.csv", label))
  if (!file.exists(path)) {
    stop("NIPA table not found: ", path,
         "\nRun 51_fetch_nipa_income.R first.")
  }
  readr::read_csv(path, show_col_types = FALSE)
}

t1014 <- load_nipa("nipa_t1014")
t7011 <- load_nipa("nipa_t7011")

message(sprintf("Loaded NIPA T1.14: %d rows, years %d-%d",
                nrow(t1014), min(t1014$year), max(t1014$year)))
message(sprintf("Loaded NIPA T7.11: %d rows, years %d-%d",
                nrow(t7011), min(t7011$year), max(t7011$year)))


## ----------------------------------------------------------
## Line extraction helper
## ----------------------------------------------------------

#' Extract a single line from a NIPA table by line number
#'
#' @param tbl      Long-format NIPA table
#' @param line     Line number (integer)
#' @param col_name Output column name
#' @return tibble(year, col_name)
extract_line <- function(tbl, line, col_name) {
  out <- tbl |>
    dplyr::filter(line_number == line) |>
    dplyr::select(year, !!col_name := value) |>
    dplyr::arrange(year)
  if (nrow(out) == 0) {
    stop(sprintf("Line %d not found in table (col: %s). Check BEA revision.",
                 line, col_name))
  }
  out
}

## Print all line labels once for audit
unique_lines_1014 <- t1014 |>
  dplyr::distinct(line_number, line_desc) |>
  dplyr::arrange(line_number)

cat("\n  T1.14 — all line labels:\n")
for (i in seq_len(nrow(unique_lines_1014))) {
  cat(sprintf("    Line %2d: %s\n",
              unique_lines_1014$line_number[i],
              unique_lines_1014$line_desc[i]))
}


## ----------------------------------------------------------
## §A. Total corporate block — T1.14 Lines 1-16
##     (Dataset 1 backward compatibility)
## ----------------------------------------------------------

message("\n--- §A: Total corporate block (T1.14 Lines 1-16) ---")

GVAcorpnipa <- extract_line(t1014,  1, "GVAcorpnipa")
DEPCcorp    <- extract_line(t1014,  2, "DEPCcorp")
VAcorpnipa  <- extract_line(t1014,  3, "VAcorpnipa")
ECcorp      <- extract_line(t1014,  4, "ECcorp")
Tcorp       <- extract_line(t1014,  7, "Tcorp")
NOScorpnipa <- extract_line(t1014,  8, "NOScorpnipa")
Pcorpnipa   <- extract_line(t1014, 11, "Pcorpnipa")


## ----------------------------------------------------------
## §B. NF corporate block — T1.14 Lines 17-40
##     (Dataset 2 canonical income side)
## ----------------------------------------------------------

message("\n--- §B: NF corporate block (T1.14 Lines 17-40) ---")

GVA_NF             <- extract_line(t1014, 17, "GVA_NF")
CCA_NF             <- extract_line(t1014, 18, "CCA_NF")
NVA_NF             <- extract_line(t1014, 19, "NVA_NF")
EC_NF              <- extract_line(t1014, 20, "EC_NF")
Wages_NF           <- extract_line(t1014, 21, "Wages_NF")
Supplements_NF     <- extract_line(t1014, 22, "Supplements_NF")
TPI_NF             <- extract_line(t1014, 23, "TPI_NF")
NOS_NF             <- extract_line(t1014, 24, "NOS_NF")
NetInt_NF          <- extract_line(t1014, 25, "NetInt_NF")
BusTransfer_NF     <- extract_line(t1014, 26, "BusTransfer_NF")
Profits_IVA_CC_NF  <- extract_line(t1014, 27, "Profits_IVA_CC_NF")
CorpTax_NF         <- extract_line(t1014, 28, "CorpTax_NF")
PAT_IVA_CC_NF      <- extract_line(t1014, 29, "PAT_IVA_CC_NF")
Dividends_NF       <- extract_line(t1014, 30, "Dividends_NF")
Retained_IVA_CC_NF <- extract_line(t1014, 31, "Retained_IVA_CC_NF")
PBT_NF             <- extract_line(t1014, 32, "PBT_NF")
PAT_NF             <- extract_line(t1014, 33, "PAT_NF")
Retained_NF        <- extract_line(t1014, 34, "Retained_NF")
IVA_NF             <- extract_line(t1014, 35, "IVA_NF")
CCAdj_NF           <- extract_line(t1014, 36, "CCAdj_NF")


## ----------------------------------------------------------
## §C. Imputed interest adjustment — T7.11
##     (Shaikh Appendix 6.8 — applied to total corporate only)
## ----------------------------------------------------------

message("\n--- §C: Imputed interest adjustment (T7.11) ---")

unique_lines_7011 <- t7011 |>
  dplyr::distinct(line_number, line_desc) |>
  dplyr::arrange(line_number)

cat("  T7.11 line labels (first 20):\n")
for (i in seq_len(min(20, nrow(unique_lines_7011)))) {
  cat(sprintf("    Line %2d: %s\n",
              unique_lines_7011$line_number[i],
              unique_lines_7011$line_desc[i]))
}

## Line 4: Monetary interest paid by financial corporate
BankMonIntPaid <- extract_line(t7011,  4, "BankMonIntPaid")
## Lines 49/58: NF corporate imputed interest paid/received
line_imp_paid  <- extract_line(t7011, 49, "imp_int_paid_nf")
line_imp_recv  <- extract_line(t7011, 58, "imp_int_recv_nf")

CorpNFNetImpIntPaid <- line_imp_paid |>
  dplyr::left_join(line_imp_recv, by = "year") |>
  dplyr::mutate(CorpNFNetImpIntPaid = imp_int_paid_nf - imp_int_recv_nf) |>
  dplyr::select(year, CorpNFNetImpIntPaid)


## ----------------------------------------------------------
## §D. Merge and compute all series
## ----------------------------------------------------------

message("\n--- §D: Merging and computing derived series ---")

## NF corporate master frame
df_NF <- GVA_NF |>
  dplyr::left_join(CCA_NF,             by = "year") |>
  dplyr::left_join(NVA_NF,             by = "year") |>
  dplyr::left_join(EC_NF,              by = "year") |>
  dplyr::left_join(Wages_NF,           by = "year") |>
  dplyr::left_join(Supplements_NF,     by = "year") |>
  dplyr::left_join(TPI_NF,             by = "year") |>
  dplyr::left_join(NOS_NF,             by = "year") |>
  dplyr::left_join(NetInt_NF,          by = "year") |>
  dplyr::left_join(BusTransfer_NF,     by = "year") |>
  dplyr::left_join(Profits_IVA_CC_NF,  by = "year") |>
  dplyr::left_join(CorpTax_NF,         by = "year") |>
  dplyr::left_join(PAT_IVA_CC_NF,      by = "year") |>
  dplyr::left_join(Dividends_NF,       by = "year") |>
  dplyr::left_join(Retained_IVA_CC_NF, by = "year") |>
  dplyr::left_join(PBT_NF,             by = "year") |>
  dplyr::left_join(PAT_NF,             by = "year") |>
  dplyr::left_join(Retained_NF,        by = "year") |>
  dplyr::left_join(IVA_NF,             by = "year") |>
  dplyr::left_join(CCAdj_NF,           by = "year") |>
  dplyr::arrange(year) |>
  dplyr::mutate(
    ## Derived: gross operating surplus
    GOS_NF    = GVA_NF - EC_NF - TPI_NF,
    ## Distributional shares
    ProfSh_NF = NOS_NF / NVA_NF,
    WageSh_NF = EC_NF  / NVA_NF,
    ## Retention ratio
    RetRate_NF = dplyr::if_else(
      !is.na(PAT_NF) & PAT_NF != 0,
      Retained_NF / PAT_NF,
      NA_real_
    )
  )

## Total corporate frame (Dataset 1 compat)
df_corp <- GVAcorpnipa |>
  dplyr::left_join(DEPCcorp,           by = "year") |>
  dplyr::left_join(VAcorpnipa,         by = "year") |>
  dplyr::left_join(ECcorp,             by = "year") |>
  dplyr::left_join(Tcorp,              by = "year") |>
  dplyr::left_join(NOScorpnipa,        by = "year") |>
  dplyr::left_join(Pcorpnipa,          by = "year") |>
  dplyr::left_join(BankMonIntPaid,     by = "year") |>
  dplyr::left_join(CorpNFNetImpIntPaid,by = "year") |>
  dplyr::arrange(year) |>
  dplyr::mutate(
    CorpImpIntAdj = -BankMonIntPaid - CorpNFNetImpIntPaid,
    GVAcorp       = GVAcorpnipa + CorpImpIntAdj,
    NOScorp       = NOScorpnipa + CorpImpIntAdj,
    VAcorp        = VAcorpnipa  + CorpImpIntAdj,
    Pcorp         = Pcorpnipa
  )


## ----------------------------------------------------------
## §E. Internal consistency checks
## ----------------------------------------------------------

message("\n--- §E: Internal consistency checks ---")

## NF: NVA_NF == GVA_NF - CCA_NF
df_NF <- df_NF |>
  dplyr::mutate(nva_gap = NVA_NF - (GVA_NF - CCA_NF))

nva_viol <- df_NF |> dplyr::filter(abs(nva_gap) >= 0.5)
if (nrow(nva_viol) > 0) {
  cat(sprintf("  WARNING: NVA_NF != GVA_NF - CCA_NF in %d years (max gap: %.2f)\n",
              nrow(nva_viol), max(abs(nva_viol$nva_gap))))
} else {
  message("  NVA_NF = GVA_NF - CCA_NF: PASS")
}
df_NF <- df_NF |> dplyr::select(-nva_gap)

## NF: GOS_NF == GVA_NF - EC_NF - TPI_NF  (by construction — always passes)
message("  GOS_NF = GVA_NF - EC_NF - TPI_NF: by construction")

## Total corp: GVAcorp = VAcorp + DEPCcorp
df_corp <- df_corp |>
  dplyr::mutate(gva_gap = GVAcorp - (VAcorp + DEPCcorp))
gva_viol <- df_corp |> dplyr::filter(abs(gva_gap) >= 0.5)
if (nrow(gva_viol) > 0) {
  cat(sprintf("  WARNING: GVAcorp != VAcorp + DEPCcorp in %d years\n",
              nrow(gva_viol)))
} else {
  message("  GVAcorp = VAcorp + DEPCcorp: PASS")
}
df_corp <- df_corp |> dplyr::select(-gva_gap)


## ----------------------------------------------------------
## §F. Validation vs 1947 targets
## ----------------------------------------------------------

message("\n=== INCOME ACCOUNTS VALIDATION (1947) ===")

if (1947 %in% df_NF$year) {
  v <- df_NF |> dplyr::filter(year == 1947)
  cat(sprintf("  NVA_NF_1947:  %8.1f | Rcorp benchmark: NVA/KGC ~ 0.685\n",
              v$NVA_NF))
  cat(sprintf("  GVA_NF_1947:  %8.1f\n", v$GVA_NF))
  cat(sprintf("  EC_NF_1947:   %8.1f\n", v$EC_NF))
  cat(sprintf("  NOS_NF_1947:  %8.1f\n", v$NOS_NF))
  cat(sprintf("  ProfSh_1947:  %8.4f | Target: ~0.210\n", v$ProfSh_NF))
  cat(sprintf("  WageSh_1947:  %8.4f\n", v$WageSh_NF))
}

if (1947 %in% df_corp$year) {
  vc <- df_corp |> dplyr::filter(year == 1947)
  cat(sprintf("\n  GVAcorp_1947: %8.1f | Target: 127.5\n",  vc$GVAcorp))
  cat(sprintf("  VAcorp_1947:  %8.1f | Target: 118.6\n",  vc$VAcorp))
  cat(sprintf("  NOScorp_1947: %8.1f | Target: 24.9\n",   vc$NOScorp))
}


## ----------------------------------------------------------
## §G. Write outputs
## ----------------------------------------------------------

## Primary: full NF corporate income decomposition
out_path_NF <- file.path(GDP_CONFIG$PROCESSED, "income_accounts_NF.csv")
safe_write_csv(df_NF, out_path_NF)
message(sprintf("\nWritten: %s (%d rows, years %d-%d, %d columns)",
                out_path_NF, nrow(df_NF),
                min(df_NF$year), max(df_NF$year), ncol(df_NF)))

## Alias: Dataset 1 backward compatibility
out_path_corp <- file.path(GDP_CONFIG$PROCESSED, "corp_output_series.csv")
safe_write_csv(df_corp, out_path_corp)
message(sprintf("Written: %s (%d rows, years %d-%d) [D1 alias]",
                out_path_corp, nrow(df_corp),
                min(df_corp$year), max(df_corp$year)))

message("  Next: 53_build_gpim_kstock.R")
