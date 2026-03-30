############################################################
# 62_build_prod_cap_accounts.R — Coordinator Script
#
# Orchestrates the four-account productive capital pipeline
# (Dataset 2). Contains NO GPIM logic — all computation
# lives in agent functions (60) and helpers (59, 97).
#
# Workflow graph:
#   Phase 0 (parallel fetch) → Gate 0
#   → Phase 1 (parallel GPIM) → Gate 1
#   → Phase 2 (sequential aggregate) → Gate 2
#   → Phase 3 (merge + estimation objects) → Gate 3
#   → Phase 4 (write outputs)
#
# Authority:
#   - KSTOCK_Architecture_v1.md (decision log)
#   - BEA_LineMap_v1.md (API table/line mappings)
#   - Weibull_Retirement_Distributions.md (L, alpha)
#
# Requires: future, future.apply, dplyr, readr
############################################################

rm(list = ls())

library(dplyr)
library(readr)

## ----------------------------------------------------------
## Source all dependencies
## ----------------------------------------------------------

source("codes/40_gdp_kstock_config.R")
source("codes/99_utils.R")
source("codes/97_kstock_helpers.R")
source("codes/59_gpim_helpers.R")
source("codes/60_agents_prod_cap.R")
source("codes/61_validators_prod_cap.R")

ensure_dirs(GDP_CONFIG)


## ----------------------------------------------------------
## Dataset 2 configuration extensions
## ----------------------------------------------------------

## Weibull retirement parameters (LOCKED — KSTOCK_Architecture_v1 §5)
## NF corporate = aggregate (FAAt601 has no E/S/IPP sub-lines);
## investment-weighted average across asset types.
GDP_CONFIG$WEIBULL_PARAMS <- list(
  nf_corporate  = list(L = 22, alpha = 1.65),
  gov_transport = list(L = 60, alpha = 1.3),
  fin_corporate = list(L = 22, alpha = 1.65),
  IPP           = list(L = 5,  alpha = 2.0)
)

## Toggles (KSTOCK_Architecture_v1 §10)
GDP_CONFIG$USE_WEIBULL_RETIREMENT   <- TRUE
GDP_CONFIG$USE_SHAIKH_BEA1993_RATES <- FALSE
GDP_CONFIG$USE_1901_WARMUP          <- TRUE

## Estimation window
GDP_CONFIG$EST_YEARS <- 1947L:2024L


## ----------------------------------------------------------
## Logging setup
## ----------------------------------------------------------

log_path <- file.path(GDP_CONFIG$INTERIM_LOGS,
                       "prod_cap_coordinator_log.txt")
dir.create(dirname(log_path), showWarnings = FALSE, recursive = TRUE)
log_conn <- file(log_path, open = "wt")

log_msg <- function(msg) {
  stamped <- sprintf("[%s] %s", now_stamp(), msg)
  cat(stamped, "\n", file = log_conn)
  message(stamped)
}

log_msg("=== Dataset 2: Four-Account Productive Capital Pipeline ===")
log_msg(sprintf("Weibull: nf_corp(L=%d,a=%.2f) govt(L=%d,a=%.1f) fin_corp(L=%d,a=%.2f) IPP(L=%d,a=%.1f)",
                GDP_CONFIG$WEIBULL_PARAMS$nf_corporate$L,
                GDP_CONFIG$WEIBULL_PARAMS$nf_corporate$alpha,
                GDP_CONFIG$WEIBULL_PARAMS$gov_transport$L,
                GDP_CONFIG$WEIBULL_PARAMS$gov_transport$alpha,
                GDP_CONFIG$WEIBULL_PARAMS$fin_corporate$L,
                GDP_CONFIG$WEIBULL_PARAMS$fin_corporate$alpha,
                GDP_CONFIG$WEIBULL_PARAMS$IPP$L,
                GDP_CONFIG$WEIBULL_PARAMS$IPP$alpha))


## ==================================================================
## Phase 0: PARALLEL FETCH
## ==================================================================

log_msg("--- Phase 0: Parallel fetch ---")

library(future)
library(future.apply)
plan(multisession, workers = 5L)

phase0_result <- tryCatch({

  ## Define fetch tasks as a named list of closures
  ## Each closure captures GDP_CONFIG for the worker
  cfg_snapshot <- GDP_CONFIG

  fetch_futures <- list(
    nf_corp  = future::future({ fetch_NF_corporate(cfg_snapshot) },
                               seed = TRUE),
    fin_corp = future::future({ fetch_financial_corporate(cfg_snapshot) },
                               seed = TRUE),
    govt     = future::future({ fetch_gov_transport(cfg_snapshot) },
                               seed = TRUE),
    ipp      = future::future({ fetch_NF_IPP(cfg_snapshot) },
                               seed = TRUE),
    income   = future::future({ fetch_income_accounts(cfg_snapshot) },
                               seed = TRUE),
    Py       = future::future({ fetch_Py_deflator(cfg_snapshot) },
                               seed = TRUE),
    warmup   = future::future({ fetch_investment_flows_1901(cfg_snapshot) },
                               seed = TRUE)
  )

  ## Collect results
  fetch_results <- lapply(fetch_futures, future::value)
  log_msg(sprintf("Phase 0 complete: %d fetch tasks resolved", length(fetch_results)))
  fetch_results

}, error = function(e) {
  log_msg(sprintf("Phase 0 ERROR: %s", e$message))
  close(log_conn)
  stop(sprintf("PIPELINE HALT at Phase 0 (fetch): %s", e$message))
})


## ----------------------------------------------------------
## Gate 0: API validation
## ----------------------------------------------------------

gate0 <- gate_check_API(phase0_result)
log_msg(gate0$message)

if (!gate0$pass) {
  close(log_conn)
  stop(sprintf("PIPELINE HALT at Gate 0: %s", gate0$message))
}


## ==================================================================
## Phase 1: PARALLEL GPIM CONSTRUCTION
## ==================================================================

log_msg("--- Phase 1: Parallel GPIM construction ---")

phase1_result <- tryCatch({

  warmup_data <- phase0_result$warmup
  cfg_snap    <- GDP_CONFIG

  gpim_futures <- list(
    nf_corp  = future::future({
      gpim_NF_corporate(phase0_result$nf_corp, warmup_data, cfg_snap)
    }, seed = TRUE),
    govt     = future::future({
      gpim_gov_transport(phase0_result$govt, warmup_data, cfg_snap)
    }, seed = TRUE),
    ipp      = future::future({
      gpim_NF_IPP(phase0_result$ipp, warmup_data, cfg_snap)
    }, seed = TRUE),
    fin_corp = future::future({
      gpim_financial_corporate(phase0_result$fin_corp, warmup_data, cfg_snap)
    }, seed = TRUE)
  )

  gpim_results <- lapply(gpim_futures, future::value)
  log_msg(sprintf("Phase 1 complete: %d GPIM accounts built",
                  length(gpim_results)))
  gpim_results

}, error = function(e) {
  log_msg(sprintf("Phase 1 ERROR: %s", e$message))
  close(log_conn)
  stop(sprintf("PIPELINE HALT at Phase 1 (GPIM): %s", e$message))
})


## ----------------------------------------------------------
## Gate 1: Per-account SFC
## ----------------------------------------------------------

gate1 <- gate_check_SFC_per_account(phase1_result)
log_msg(gate1$message)

if (!gate1$pass) {
  cat("\nPer-account SFC details:\n", file = log_conn)
  for (i in seq_len(nrow(gate1$per_account))) {
    r <- gate1$per_account[i, ]
    cat(sprintf("  %s: sfc_max=%.4e, gross_sfc=%.4e, pass=%s\n",
                r$account, r$sfc_max, r$sfc_gross_max, r$pass),
        file = log_conn)
  }
  close(log_conn)
  stop(sprintf("PIPELINE HALT at Gate 1: %s", gate1$message))
}


## ==================================================================
## Phase 2: SEQUENTIAL AGGREGATE
## ==================================================================

log_msg("--- Phase 2: Sequential aggregate ---")

phase2_result <- tryCatch({

  ## Build income accounts
  income <- build_income_accounts(
    raw_t1014 = phase0_result$income,
    Py        = phase0_result$Py
  )

  ## Aggregate productive capital (NF corporate + Gov transport)
  productive <- aggregate_productive(
    nf_corp = phase1_result$nf_corp,
    govt    = phase1_result$govt,
    years   = NULL  # keep all years for now
  )

  log_msg("Phase 2 complete: income + productive aggregate built")
  list(income = income, productive = productive)

}, error = function(e) {
  log_msg(sprintf("Phase 2 ERROR: %s", e$message))
  close(log_conn)
  stop(sprintf("PIPELINE HALT at Phase 2 (aggregate): %s", e$message))
})


## ----------------------------------------------------------
## Gate 2: Aggregate SFC
## ----------------------------------------------------------

gate2 <- gate_check_SFC_aggregate(phase2_result$productive)
log_msg(gate2$message)

if (!gate2$pass) {
  close(log_conn)
  stop(sprintf("PIPELINE HALT at Gate 2: %s", gate2$message))
}


## ==================================================================
## Phase 3: MERGE + ESTIMATION OBJECTS
## ==================================================================

log_msg("--- Phase 3: Merge + estimation objects ---")

phase3_result <- tryCatch({

  master <- build_master_csv(
    prod     = phase2_result$productive,
    income   = phase2_result$income,
    nf_corp  = phase1_result$nf_corp,
    govt     = phase1_result$govt,
    IPP      = phase1_result$ipp,
    fin_corp = phase1_result$fin_corp,
    years    = NULL
  )

  log_msg("Phase 3 complete: master dataset built")
  master

}, error = function(e) {
  log_msg(sprintf("Phase 3 ERROR: %s", e$message))
  close(log_conn)
  stop(sprintf("PIPELINE HALT at Phase 3 (merge): %s", e$message))
})


## ----------------------------------------------------------
## Gate 3: Canonical values (warn only — do not halt)
## ----------------------------------------------------------

gate3 <- gate_check_canonical(
  phase2_result$productive,
  phase2_result$income
)
log_msg(gate3$message)

## Gate 3 warns but does not halt


## ==================================================================
## Phase 4: WRITE OUTPUTS
## ==================================================================

log_msg("--- Phase 4: Write outputs ---")

## 4a. Master CSV
master_path <- file.path(GDP_CONFIG$PROCESSED, "kstock_master.csv")
safe_write_csv(phase3_result, master_path)
log_msg(sprintf("Written: %s (%d rows x %d cols)",
                master_path, nrow(phase3_result), ncol(phase3_result)))

## 4b. Income accounts
income_path <- file.path(GDP_CONFIG$PROCESSED, "income_accounts_NF.csv")
safe_write_csv(phase2_result$income, income_path)
log_msg(sprintf("Written: %s", income_path))

## 4c. Per-account CSVs (long format)
kstock_dir <- file.path(GDP_CONFIG$INTERIM, "kstock_components")
dir.create(kstock_dir, showWarnings = FALSE, recursive = TRUE)

for (acct_name in names(phase1_result)) {
  acct_path <- file.path(kstock_dir, sprintf("kstock_%s.csv", acct_name))
  safe_write_csv(phase1_result[[acct_name]], acct_path)
  log_msg(sprintf("Written: %s", acct_path))
}

## 4d. Accounts long format (all accounts stacked)
accounts_long <- dplyr::bind_rows(
  phase1_result$nf_corp  |> dplyr::mutate(account = "NF_corp"),
  phase1_result$govt     |> dplyr::mutate(account = "gov_trans"),
  phase1_result$ipp      |> dplyr::mutate(account = "NF_IPP"),
  phase1_result$fin_corp |> dplyr::mutate(account = "fin_corp")
)
long_path <- file.path(GDP_CONFIG$PROCESSED, "kstock_accounts_long.csv")
safe_write_csv(accounts_long, long_path)
log_msg(sprintf("Written: %s (%d rows)", long_path, nrow(accounts_long)))


## ==================================================================
## Cleanup
## ==================================================================

plan(sequential)

log_msg("=== Pipeline complete ===")
log_msg(sprintf("Gate 0: %s", gate0$message))
log_msg(sprintf("Gate 1: %s", gate1$message))
log_msg(sprintf("Gate 2: %s", gate2$message))
log_msg(sprintf("Gate 3: %s", gate3$message))

close(log_conn)

message("\n=== Dataset 2: Four-Account Productive Capital — COMPLETE ===")
message(sprintf("  Master CSV: %s", master_path))
message(sprintf("  Income CSV: %s", income_path))
message(sprintf("  Accounts long: %s", long_path))
message(sprintf("  Log: %s", log_path))
message("  Next: 63_figure_prod_cap_accounts.R")
