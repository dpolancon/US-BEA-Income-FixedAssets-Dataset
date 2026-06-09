############################################################
# 56_assemble_NF_kstock_distribution.R
#
# Assembles sector-coherent NF corporate dataset:
# income distribution (gross basis) + GPIM capital stocks,
# all rebased to 2024 prices.
#
# Abstracts from taxes (TPI excluded): two-class split only.
#   GVA_NF = EC_NF + GOS_NF + TPI_NF
#   Wsh_NF = EC_NF / GVA_NF
#   Psh_NF = 1 - Wsh_NF  (absorbs TPI into surplus residual)
#   e_NF   = Psh_NF / Wsh_NF
#
# Capital side: NF corporate only (sector-coherent with income).
# All real series and price indices rebased to 2024 = 100.
#
# Reads:
#   data/processed/kstock_master.csv
#
# Writes:
#   data/processed/US_corporate_NF_kstock_distribution.csv
#
# Sources: 97_kstock_helpers.R (for rebase_index)
############################################################

rm(list = ls())

library(dplyr)
library(readr)

source("codes/97_kstock_helpers.R")

PROCESSED <- "data/processed"
BASE_YEAR <- 2024L


## ----------------------------------------------------------
## Load kstock_master (contains both income + capital)
## ----------------------------------------------------------

master_path <- file.path(PROCESSED, "kstock_master.csv")
if (!file.exists(master_path)) {
  stop("Required file not found: ", master_path,
       "\nRun 62_build_prod_cap_accounts.R first.")
}

master <- readr::read_csv(master_path, show_col_types = FALSE)
message(sprintf("Loaded kstock_master: %d rows, years %d-%d",
                nrow(master), min(master$year), max(master$year)))


## ----------------------------------------------------------
## Rebase price index to 2024 = 100
## ----------------------------------------------------------

message(sprintf("\n--- Rebasing pK_NF_corp to %d = 100 ---", BASE_YEAR))

pK_2024 <- rebase_index(master$pK_NF_corp, master$year, BASE_YEAR, scale = 100)

message(sprintf("  pK(%d) = %.2f (was %.2f on 2017 base)",
                BASE_YEAR,
                pK_2024[master$year == BASE_YEAR],
                master$pK_NF_corp[master$year == BASE_YEAR]))


## ----------------------------------------------------------
## Compute real capital stocks at 2024 prices
## ----------------------------------------------------------

message("\n--- Computing real series (2024 prices) ---")

KNR_NF_2024 <- master$KNC_NF_corp / (pK_2024 / 100)
KGR_NF_2024 <- master$KGC_NF_corp / (pK_2024 / 100)

## Verify: at 2024, real = nominal
check_knr <- abs(KNR_NF_2024[master$year == BASE_YEAR] -
                 master$KNC_NF_corp[master$year == BASE_YEAR])
check_kgr <- abs(KGR_NF_2024[master$year == BASE_YEAR] -
                 master$KGC_NF_corp[master$year == BASE_YEAR])
message(sprintf("  KNR check (2024): real - nominal = %.2f (should be ~0)", check_knr))
message(sprintf("  KGR check (2024): real - nominal = %.2f (should be ~0)", check_kgr))


## ----------------------------------------------------------
## Income distribution (gross basis, abstracting from taxes)
## ----------------------------------------------------------

message("\n--- Computing distributional shares (gross basis) ---")

df <- tibble::tibble(
  year    = master$year,

  ## --- Income side (all nominal, NF corporate) ---
  GVA_NF  = master$GVA_NF,
  GOS_NF  = master$GOS_NF,
  EC_NF   = master$EC_NF,

  ## --- Distributional shares (two-class, TPI absorbed) ---
  Wsh_NF  = EC_NF / GVA_NF,
  Psh_NF  = 1 - Wsh_NF,
  e_NF    = Psh_NF / Wsh_NF,

  ## --- Capital stock: net (current prices) ---
  KNC_NF  = master$KNC_NF_corp,

  ## --- Capital stock: net (2024 prices) ---
  KNR_NF  = KNR_NF_2024,

  ## --- Price index of capital stock (2024 = 100) ---
  pK_NF   = pK_2024,

  ## --- Investment: gross fixed capital formation (current prices) ---
  IGC_NF  = master$IG_cc_NF_corp,

  ## --- Investment price index (= pK under GPIM, 2024 = 100) ---
  IGp_NF  = pK_2024,

  ## --- Capital stock: gross (current prices, GPIM) ---
  KGC_NF  = master$KGC_NF_corp,

  ## --- Capital stock: gross (2024 prices, GPIM) ---
  KGR_NF  = KGR_NF_2024
)


## ----------------------------------------------------------
## Identity checks
## ----------------------------------------------------------

message("\n--- Identity checks ---")

wsh_check <- max(abs(df$Wsh_NF + df$Psh_NF - 1), na.rm = TRUE)
message(sprintf("  Wsh + Psh = 1: max deviation = %.2e (should be ~0)", wsh_check))

e_check <- max(abs(df$e_NF - df$Psh_NF / df$Wsh_NF), na.rm = TRUE)
message(sprintf("  e = Psh/Wsh:   max deviation = %.2e (should be ~0)", e_check))

pk_check <- abs(df$pK_NF[df$year == BASE_YEAR] - 100)
message(sprintf("  pK(2024) = 100: deviation = %.2e", pk_check))

knr_check <- abs(df$KNR_NF[df$year == BASE_YEAR] - df$KNC_NF[df$year == BASE_YEAR])
message(sprintf("  KNR = KNC at 2024: deviation = %.2f", knr_check))


## ----------------------------------------------------------
## Verification printout
## ----------------------------------------------------------

cat("\n=== US CORPORATE NF — KSTOCK + DISTRIBUTION ===\n")
cat(sprintf("  Year range:  %d-%d (%d obs)\n",
            min(df$year), max(df$year), nrow(df)))
cat(sprintf("  Columns:     %d\n", ncol(df)))
cat(sprintf("  Base year:   %d (pK = 100, real = nominal)\n\n", BASE_YEAR))

for (yr in c(1947, 1980, 2007, 2024)) {
  if (yr %in% df$year) {
    v <- df |> dplyr::filter(year == yr)
    cat(sprintf("  %d: GVA=%9.0f | Wsh=%.3f | Psh=%.3f | e=%.3f | KGC=%11.0f | pK=%7.2f\n",
                yr, v$GVA_NF, v$Wsh_NF, v$Psh_NF, v$e_NF, v$KGC_NF, v$pK_NF))
  }
}


## ----------------------------------------------------------
## Write output
## ----------------------------------------------------------

out_path <- file.path(PROCESSED, "US_corporate_NF_kstock_distribution.csv")
dir.create(dirname(out_path), showWarnings = FALSE, recursive = TRUE)
utils::write.csv(df, out_path, row.names = FALSE)

cat(sprintf("\n=== Written: %s ===\n", out_path))
cat(sprintf("  %d rows, %d columns, years %d-%d\n",
            nrow(df), ncol(df), min(df$year), max(df$year)))

message("\nVariables:")
message("  GVA_NF, GOS_NF, EC_NF        — income (nominal, NF corporate)")
message("  Wsh_NF, Psh_NF, e_NF         — distribution (gross basis, TPI absorbed)")
message("  KNC_NF, KNR_NF               — net capital stock (current / 2024 prices)")
message("  pK_NF                         — capital price index (2024 = 100)")
message("  IGC_NF, IGp_NF               — investment flow + price index (2024 = 100)")
message("  KGC_NF, KGR_NF               — gross capital stock GPIM (current / 2024 prices)")
