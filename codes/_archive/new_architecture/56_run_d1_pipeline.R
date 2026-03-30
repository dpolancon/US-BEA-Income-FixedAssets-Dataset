############################################################
# 56_run_d1_pipeline.R — D1 Productive Capital Pipeline Runner
#
# Executes the Dataset 1 build chain in dependency order:
#
#   50_fetch_fixed_assets.R      — BEA FA tables (Sections 6 + 7)
#   51_fetch_nipa_income.R       — BEA NIPA T1.14 + FRED Py
#   52_build_income_accounts.R   — NVA_NF, GOS_NF, NOS_NF, EC_NF …
#   53_build_gpim_kstock.R       — GPIM capital stock (all accounts)
#   54_build_utilization_ratios.R— R_obs, profit share, wage share
#   55_assemble_prod_cap_dataset.R— → prod_cap_dataset_d1.csv
#
# Produces:
#   data/processed/prod_cap_dataset_d1.csv   (canonical Dataset 1)
#   data/processed/corporate_sector_dataset.csv (alias — backward compat)
#
# Usage:
#   Rscript codes/56_run_d1_pipeline.R
#
# Each script runs in a clean environment via source().
# Pipeline halts on first failure and reports the error.
############################################################

cat("============================================================\n")
cat("  D1 PRODUCTIVE CAPITAL PIPELINE RUNNER\n")
cat("  Dataset 1 — GPIM capital stocks + income accounts\n")
cat(sprintf("  Started: %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))
cat("============================================================\n\n")

## Pipeline scripts in dependency order
pipeline_scripts <- c(
  "codes/50_fetch_fixed_assets.R",         # Fetch BEA FA by legal form + govt
  "codes/51_fetch_nipa_income.R",           # Fetch NIPA T1.14 + FRED Py
  "codes/52_build_income_accounts.R",       # Build NVA_NF, GOS_NF, NOS_NF, EC_NF
  "codes/53_build_gpim_kstock.R",           # Build KGC, KNC (GPIM + 3 adjustments)
  "codes/54_build_utilization_ratios.R",    # Build R_obs, profit/wage shares, rcorp
  "codes/55_assemble_prod_cap_dataset.R"    # Merge + validate → prod_cap_dataset_d1.csv
)

t_start <- Sys.time()
results <- list()

for (i in seq_along(pipeline_scripts)) {
  script <- pipeline_scripts[i]
  label  <- basename(script)

  cat(sprintf("\n[%d/%d] %s\n", i, length(pipeline_scripts), label))
  cat(paste(rep("-", 60), collapse = ""), "\n")

  if (!file.exists(script)) {
    cat(sprintf("  SKIP: file not found — %s\n", script))
    results[[label]] <- list(status = "SKIP", time = 0, error = "file not found")
    next
  }

  t0 <- Sys.time()

  status <- tryCatch({
    source(script, local = new.env(parent = globalenv()))
    "OK"
  }, error = function(e) {
    cat(sprintf("\n  *** ERROR in %s ***\n  %s\n", label, conditionMessage(e)))
    paste0("FAIL: ", conditionMessage(e))
  })

  elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  results[[label]] <- list(status = status, time = elapsed, error = NA)
  cat(sprintf("  [%s] %.1f sec\n", status, elapsed))

  ## Halt on failure
  if (!startsWith(status, "OK")) {
    cat(sprintf("\n*** PIPELINE HALTED at %s ***\n", label))
    break
  }
}


## ----------------------------------------------------------
## Post-run: verify final deliverable
## ----------------------------------------------------------

final_csv <- "data/processed/prod_cap_dataset_d1.csv"
csv_exists <- file.exists(final_csv)

if (csv_exists) {
  df <- readr::read_csv(final_csv, show_col_types = FALSE)
  cat(sprintf("\n  Final dataset: %s\n", final_csv))
  cat(sprintf("  Rows: %d | Columns: %d | Years: %d-%d\n",
              nrow(df), ncol(df), min(df$year), max(df$year)))

  ## Required columns for ARDL estimation pipeline (20-26 series)
  required <- c("year", "GVAcorp", "VAcorp", "KGCcorp", "Py",
                "exploit_rate", "uK")
  missing  <- setdiff(required, names(df))
  if (length(missing) > 0) {
    cat(sprintf("  WARNING: Missing columns: %s\n",
                paste(missing, collapse = ", ")))
  } else {
    cat("  All required columns present.\n")
  }
}

## Backward compatibility: check alias exists
alias_csv <- "data/processed/corporate_sector_dataset.csv"
if (!file.exists(alias_csv) && csv_exists) {
  file.copy(final_csv, alias_csv)
  message(sprintf("  Alias written: %s", alias_csv))
  message("  (backward compat for 20-26 estimation scripts)")
}


## ----------------------------------------------------------
## Summary
## ----------------------------------------------------------

elapsed_total <- as.numeric(difftime(Sys.time(), t_start, units = "secs"))

cat("\n\n============================================================\n")
cat("  D1 PIPELINE SUMMARY\n")
cat("============================================================\n")
cat(sprintf("%-42s  %6s  %8s\n", "Script", "Status", "Time (s)"))
cat(paste(rep("-", 62), collapse = ""), "\n")

for (label in names(results)) {
  r  <- results[[label]]
  st <- if (startsWith(r$status, "OK")) "OK" else
        if (r$status == "SKIP") "SKIP" else "FAIL"
  cat(sprintf("%-42s  %6s  %8.1f\n", label, st, r$time))
}

cat(paste(rep("-", 62), collapse = ""), "\n")
cat(sprintf("Total elapsed: %.1f sec\n", elapsed_total))
cat(sprintf("Finished: %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))

n_ok   <- sum(sapply(results, function(r) startsWith(r$status, "OK")))
n_fail <- sum(sapply(results, function(r) startsWith(r$status, "FAIL")))
n_skip <- sum(sapply(results, function(r) r$status == "SKIP"))

cat(sprintf("\nResult: %d OK, %d FAIL, %d SKIP out of %d scripts\n",
            n_ok, n_fail, n_skip, length(pipeline_scripts)))

if (n_fail > 0) {
  cat("\n*** PIPELINE FAILED — see errors above ***\n")
  quit(status = 1)
} else if (csv_exists) {
  cat("\n*** PIPELINE COMPLETE ***\n")
  cat(sprintf("  Deliverable: %s\n", final_csv))
  cat("  Alias:       data/processed/corporate_sector_dataset.csv\n")
  cat("  Ready for:   Rscript codes/20_S0_shaikh_faithful.R\n")
  cat("  Extension:   Rscript codes/57_extend_to_present.R\n")
  cat("  Dataset 2:   Rscript codes/62_build_prod_cap_accounts.R\n")
} else {
  cat("\n*** WARNING: Pipeline finished but final CSV not found ***\n")
  quit(status = 1)
}
