############################################################
# 49_source_runner.R — Sequential runner for the 40-series
#                       GDP & Capital Stock pipeline
#
# Executes scripts 41–48 in dependency order.
# Skips 40_gdp_kstock_config.R (sourced by each script)
# and 49_capital_ratio_analysis.R (optional, post-pipeline).
#
# Usage:
#   Rscript codes/49_source_runner.R
#
# Each script is run in a clean environment via source().
# If any script fails, the runner stops and reports the error.
############################################################

cat("============================================================\n")
cat("  40-SERIES PIPELINE RUNNER\n")
cat("  GDP & Capital Stock Construction\n")
cat(sprintf("  Started: %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))
cat("============================================================\n\n")

## Pipeline scripts in dependency order
## (40_gdp_kstock_config.R is sourced internally by each script)
scripts_40 <- c(
  "codes/41_fetch_bea_fixed_assets.R",    # Fetch BEA Fixed Assets tables
  "codes/42_fetch_fred_gdp.R",            # Fetch FRED GDP/deflator series
  "codes/43_build_gdp_series.R",          # Build GDP series (1925-2024)
  "codes/44_build_kstock_private.R",      # Build private K-stock (GPIM)
  "codes/45_build_kstock_government.R",   # Build government K-stock
  "codes/46_shaikh_adjustments.R",        # Apply Shaikh adjustments (toggle)
  "codes/47_stock_flow_consistency.R",    # SFC validation + deflator tests
  "codes/48_assemble_dataset.R"           # Final assembly: master_dataset.csv
)

t_start <- Sys.time()
results <- list()

for (i in seq_along(scripts_40)) {
  script <- scripts_40[i]
  label  <- basename(script)

  cat(sprintf("\n[%d/%d] %s\n", i, length(scripts_40), label))
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

  ## Stop on failure
  if (!startsWith(status, "OK")) {
    cat(sprintf("\n*** PIPELINE HALTED at %s ***\n", label))
    break
  }
}

## ----------------------------------------------------------
## Summary
## ----------------------------------------------------------

elapsed_total <- as.numeric(difftime(Sys.time(), t_start, units = "secs"))

cat("\n\n============================================================\n")
cat("  40-SERIES PIPELINE SUMMARY\n")
cat("============================================================\n")
cat(sprintf("%-40s  %6s  %8s\n", "Script", "Status", "Time (s)"))
cat(paste(rep("-", 60), collapse = ""), "\n")

for (label in names(results)) {
  r <- results[[label]]
  st <- if (startsWith(r$status, "OK")) "OK" else
        if (r$status == "SKIP") "SKIP" else "FAIL"
  cat(sprintf("%-40s  %6s  %8.1f\n", label, st, r$time))
}

cat(paste(rep("-", 60), collapse = ""), "\n")
cat(sprintf("Total elapsed: %.1f sec\n", elapsed_total))
cat(sprintf("Finished: %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))

n_ok   <- sum(sapply(results, function(r) startsWith(r$status, "OK")))
n_fail <- sum(sapply(results, function(r) startsWith(r$status, "FAIL")))
n_skip <- sum(sapply(results, function(r) r$status == "SKIP"))

cat(sprintf("\nResult: %d OK, %d FAIL, %d SKIP out of %d scripts\n",
            n_ok, n_fail, n_skip, length(scripts_40)))

if (n_fail > 0) {
  cat("\n*** PIPELINE FAILED — see errors above ***\n")
  quit(status = 1)
} else {
  cat("\n*** PIPELINE COMPLETE ***\n")
}
