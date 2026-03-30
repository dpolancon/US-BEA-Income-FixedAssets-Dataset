# ============================================================
# 25_S0_deflator_grid_search.R
#
# Overnight grid search to identify Y series + deflator that
# reproduces Shaikh (2016) Table 6.7.14 ARDL(2,4) targets:
#   theta = 0.6609 | a = 2.1782 | c_d74 = -0.8548
#   AIC   = -319.38 | loglik = 170.69
#
# Search strategy:
#   PHASE 1 — BEA API fetch (Table 1.14 real corporate GVA)
#   PHASE 2 — Build candidate Y series (7 variants)
#   PHASE 3 — ARDL(2,4) Case 3 grid run + composite scoring
#   PHASE 4 — Winner validation + verification block
#   PHASE 5 — Write S0_agent_report.md
#
# Inputs:
#   data/raw/Shaikh_canonical_series_v1.csv
#   data/raw/BEA_T1014_realGVA.csv (written by Phase 1 if API available)
#
# Outputs:
#   output/CriticalReplication/S0_faithful/csv/S0_grid_results.csv
#   output/CriticalReplication/S0_faithful/logs/grid_search_log.txt
#   output/CriticalReplication/S0_faithful/S0_agent_report.md
# ============================================================

rm(list = ls())

suppressPackageStartupMessages({
  library(here)
  library(readr)
  library(readxl)
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(ARDL)
  library(httr)
  library(jsonlite)
})

source(here::here("codes", "10_config.R"))
source(here::here("codes", "99_utils.R"))

# ------------------------------------------------------------
# TARGETS (Shaikh Table 6.7.14)
# ------------------------------------------------------------
TARGET <- list(
  theta  =  0.6609,
  a      =  2.1782,
  c_d56  = -0.7428,
  c_d74  = -0.8548,
  c_d80  = -0.4780,
  AIC    = -319.38,
  loglik =  170.69
)

WINDOW  <- c(1947L, 2011L)
ORDER   <- c(2L, 4L)
DUMMIES <- c("d1956", "d1974", "d1980")

# Composite loss weights
W <- list(theta = 1.0, a = 0.5, c_d74 = 0.3, AIC = 0.01)

SUCCESS_THRESHOLD <- 0.05   # |theta - target| for declaring success

# ------------------------------------------------------------
# OUTPUT PATHS
# ------------------------------------------------------------
OUT_DIR  <- here::here("output/CriticalReplication/S0_faithful")
CSV_DIR  <- file.path(OUT_DIR, "csv")
LOG_DIR  <- file.path(OUT_DIR, "logs")
dir.create(CSV_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(LOG_DIR, recursive = TRUE, showWarnings = FALSE)

log_path    <- file.path(LOG_DIR, "grid_search_log.txt")
report_path <- file.path(OUT_DIR, "S0_agent_report.md")
results_path <- file.path(CSV_DIR, "S0_grid_results.csv")

sink(log_path, split = TRUE)
on.exit(try(sink(), silent = TRUE), add = TRUE)

cat("=== S0 DEFLATOR GRID SEARCH ===\n")
cat("Started:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

# ------------------------------------------------------------
# HELPERS
# ------------------------------------------------------------
make_step_dummies <- function(df, years) {
  for (yy in years) df[[paste0("d", yy)]] <- as.integer(df$year >= yy)
  df
}

rebase_to_100 <- function(vec, year_vec, base_year) {
  idx <- which(year_vec == base_year)
  if (length(idx) != 1) stop("Base year not found: ", base_year)
  100 * vec / vec[idx]
}

run_ardl_case3 <- function(df, label = "unnamed") {
  tryCatch({
    df_w <- df |>
      filter(year >= WINDOW[1], year <= WINDOW[2]) |>
      filter(is.finite(lnY), is.finite(lnK)) |>
      arrange(year)

    if (nrow(df_w) < 20) stop("Insufficient observations after filtering")

    df_ts <- ts(
      df_w |> select(lnY, lnK, all_of(DUMMIES)),
      start = min(df_w$year), frequency = 1
    )

    fit <- ARDL::ardl(
      lnY ~ lnK | d1956 + d1974 + d1980,
      data  = df_ts,
      order = ORDER
    )

    lr  <- ARDL::multipliers(fit, type = "lr")

    get_lr <- function(term) {
      r <- lr$Estimate[lr$Term == term]
      if (length(r) && is.finite(r)) r else NA_real_
    }

    # UECM for u_shaikh comparison
    uecm_obj <- tryCatch(ARDL::uecm(fit), error = function(e) NULL)
    alpha_hat <- NA_real_
    if (!is.null(uecm_obj)) {
      uc <- tryCatch(coef(uecm_obj), error = function(e) NULL)
      if (!is.null(uc)) {
        alpha_hat <- unname(uc[grep("^L\\(lnY, 1\\)", names(uc))])
        if (!length(alpha_hat)) alpha_hat <- NA_real_
      }
    }

    # Recover u_hat
    theta_lr <- get_lr("lnK")
    a_lr     <- get_lr("(Intercept)")
    d56_lr   <- get_lr("d1956")
    d74_lr   <- get_lr("d1974")
    d80_lr   <- get_lr("d1980")

    lnYp <- a_lr + theta_lr * df_w$lnK +
      d56_lr * df_w$d1956 +
      d74_lr * df_w$d1974 +
      d80_lr * df_w$d1980
    u_hat <- exp(df_w$lnY - lnYp)

    rmse_u <- if ("u_shaikh" %in% names(df_w)) {
      sqrt(mean((u_hat - df_w$u_shaikh)^2, na.rm = TRUE))
    } else NA_real_

    list(
      label     = label,
      theta     = theta_lr,
      a         = a_lr,
      c_d56     = d56_lr,
      c_d74     = d74_lr,
      c_d80     = d80_lr,
      alpha     = alpha_hat,
      AIC       = AIC(fit),
      BIC       = BIC(fit),
      loglik    = as.numeric(logLik(fit)),
      R2        = summary(fit)$r.squared,
      rmse_u    = rmse_u,
      n_obs     = nrow(df_w),
      failed    = FALSE,
      error_msg = NA_character_
    )
  }, error = function(e) {
    list(
      label = label, theta = NA_real_, a = NA_real_,
      c_d56 = NA_real_, c_d74 = NA_real_, c_d80 = NA_real_,
      alpha = NA_real_, AIC = NA_real_, BIC = NA_real_,
      loglik = NA_real_, R2 = NA_real_, rmse_u = NA_real_,
      n_obs = NA_integer_, failed = TRUE,
      error_msg = conditionMessage(e)
    )
  })
}

score_candidate <- function(res) {
  if (isTRUE(res$failed) || is.na(res$theta)) return(Inf)
  W$theta  * abs(res$theta - TARGET$theta)  +
  W$a      * abs(res$a     - TARGET$a)      +
  W$c_d74  * abs(res$c_d74 - TARGET$c_d74)  +
  W$AIC    * abs(res$AIC   - TARGET$AIC)
}

# PHASE 1 — FRED direct fetch (no key required)
cat("--- PHASE 1: FRED direct fetch ---\n")

bea_real_path <- here::here("data/raw/BEA_T1014_realGVA.csv")
bea_success   <- FALSE
bea_df        <- NULL

tryCatch({
  # FRED series A455RX1A020NBEA:
  # Real Gross Value Added of Corporate Business
  # Billions of Chained 2012 Dollars, Annual
  fred_url <- "https://fred.stlouisfed.org/graph/fredgraph.csv?id=A455RX1A020NBEA"
  cat("Fetching from FRED:", fred_url, "\n")
  
  fred_raw <- readr::read_csv(fred_url, show_col_types = FALSE) |>
    rename(date = DATE, GVA_real = A455RX1A020NBEA) |>
    mutate(
      year    = as.integer(substr(date, 1, 4)),
      GVA_real = as.numeric(GVA_real)
    ) |>
    filter(is.finite(year), is.finite(GVA_real)) |>
    select(year, GVA_real)
  
  bea_df      <- fred_raw
  bea_success <- TRUE
  readr::write_csv(bea_df, bea_real_path)
  cat("FRED fetch SUCCESS:", nrow(bea_df), "rows written\n")
  cat("GVA_real range:", range(bea_df$year), "\n")
  
}, error = function(e) {
  cat("FRED fetch failed:", conditionMessage(e), "\n")
  cat("Y3/Y6/Y7 will be skipped.\n")
})

# ------------------------------------------------------------
# PHASE 2 — BUILD CANDIDATE Y SERIES
# ------------------------------------------------------------
cat("\n--- PHASE 2: Build Y candidates ---\n")

df_raw <- readr::read_csv(
  here::here(CONFIG$data_shaikh),
  show_col_types = FALSE
) |>
  rename(u_shaikh = uK) |>
  mutate(year = as.integer(year))

# Reconstruct GVAcorp_nom = VAcorp + DEPCcorp
df_raw <- df_raw |>
  mutate(GVAcorp_nom = VAcorp + DEPCcorp)

# Add BEA real GVA if available
if (bea_success && !is.null(bea_df)) {
  df_raw <- df_raw |> left_join(bea_df, by = "year")
} else {
  df_raw <- df_raw |> mutate(GVA_real = NA_real_)
}

# Add step dummies + pKN from II.1 if available
# (pKN not in CSV — will be NA, skipped gracefully)
if (!"pKN" %in% names(df_raw)) df_raw <- df_raw |> mutate(pKN = NA_real_)

# Rebase deflators to 2005=100
df_base <- df_raw |>
  mutate(
    pIG_2005 = rebase_to_100(pIGcorpbea, year, 2005L),
    pKN_2005 = if (any(is.finite(pKN))) rebase_to_100(pKN, year, 2005L) else NA_real_
  )

# K series (locked)
df_base <- df_base |>
  mutate(
    K_real = KGCcorp / (pIG_2005 / 100),
    lnK    = log(K_real)
  )

# Add dummies
df_base <- make_step_dummies(df_base, c(1956L, 1974L, 1980L))

# Build all Y candidates
build_candidates <- function(df) {
  list(
    Y1 = df |> mutate(
      label = "VAcorp / pIG_2005",
      Y_real = VAcorp / (pIG_2005 / 100),
      lnY = log(Y_real)
    ),
    Y2 = df |> mutate(
      label = "GVAcorp_nom / pIG_2005",
      Y_real = GVAcorp_nom / (pIG_2005 / 100),
      lnY = log(Y_real)
    ),
    Y3 = df |> mutate(
      label = "BEA_real_GVA (T1.14 direct)",
      Y_real = GVA_real,
      lnY = log(Y_real)
    ),
    Y4 = df |> mutate(
      label = "VAcorp / pKN_2005",
      Y_real = if (any(is.finite(pKN_2005))) VAcorp / (pKN_2005 / 100) else NA_real_,
      lnY = log(Y_real)
    ),
    Y5 = df |> mutate(
      label = "GVAcorp_nom / pKN_2005",
      Y_real = if (any(is.finite(pKN_2005))) GVAcorp_nom / (pKN_2005 / 100) else NA_real_,
      lnY = log(Y_real)
    ),
    Y6 = df |> mutate(
      # Implicit GVA deflator: if BEA real GVA available
      label = "VAcorp / implicit_GVA_deflator",
      implicit_p = if (any(is.finite(GVA_real))) {
        rebase_to_100(GVAcorp_nom / GVA_real, year, 2005L)
      } else NA_real_,
      Y_real = VAcorp / (implicit_p / 100),
      lnY = log(Y_real)
    ),
    Y7 = df |> mutate(
      label = "GVAcorp_nom / implicit_GVA_deflator",
      implicit_p = if (any(is.finite(GVA_real))) {
        rebase_to_100(GVAcorp_nom / GVA_real, year, 2005L)
      } else NA_real_,
      Y_real = GVAcorp_nom / (implicit_p / 100),
      lnY = log(Y_real)
    )
  )
}

candidates <- build_candidates(df_base)

# ------- PHASE 2b: Load Py (GDP deflator) from RepData.xlsx -------
# Shaikh (2016) uses Py = NIPA Table 1.1.4 GDP price index (base 2011=100)
# for BOTH Y and K deflation, with Y = GVAcorp (not VAcorp).
cat("\n--- PHASE 2b: Load Py from RepData.xlsx ---\n")
repdata_path <- here::here("data/raw/Shaikh_RepData.xlsx")
py_success <- FALSE
if (file.exists(repdata_path)) {
  tryCatch({
    rep_long <- readxl::read_excel(repdata_path, sheet = "long")
    if ("Py" %in% names(rep_long) && "year" %in% names(rep_long)) {
      py_df <- rep_long |>
        transmute(year = as.integer(year), Py = as.numeric(Py)) |>
        filter(is.finite(year), is.finite(Py))
      df_base <- df_base |> left_join(py_df, by = "year")
      py_success <- TRUE
      cat("Py loaded:", nrow(py_df), "observations\n")
      cat("Py(1947) =", round(df_base$Py[df_base$year == 1947], 4), "(base 2011=100)\n")
    }
  }, error = function(e) cat("Py load failed:", conditionMessage(e), "\n"))
} else {
  cat("RepData.xlsx not found — Py candidates skipped\n")
}

# ------- PHASE 2c: Build expanded candidate grid (Y×K variants) -------
cat("\n--- PHASE 2c: Expanded candidate grid ---\n")

# Add Py-based candidates if available
if (py_success) {
  # RepData winner: Y = GVAcorp / Py, K = KGCcorp / Py
  candidates$Y_RepData <- df_base |> mutate(
    label   = "GVAcorp / Py (RepData)",
    Y_real  = GVAcorp_nom / (Py / 100),
    K_real  = KGCcorp / (Py / 100),
    lnY     = log(Y_real),
    lnK     = log(K_real)
  )

  # Mixed: Y = GVAcorp/Py, K = KGCcorp/pKN
  if (any(is.finite(df_base$pKN_2005))) {
    candidates$Y_GVA_Py_K_pKN <- df_base |> mutate(
      label  = "GVAcorp/Py + K/pKN",
      Y_real = GVAcorp_nom / (Py / 100),
      K_real = KGCcorp / (pKN_2005 / 100),
      lnY    = log(Y_real),
      lnK    = log(K_real)
    )
  }
}

# pKN-deflated K variants for existing Y candidates
if (any(is.finite(df_base$pKN_2005))) {
  candidates$Y5_Kb <- df_base |> mutate(
    label  = "GVAcorp_nom / pKN, K / pKN",
    Y_real = GVAcorp_nom / (pKN_2005 / 100),
    K_real = KGCcorp / (pKN_2005 / 100),
    lnY    = log(Y_real),
    lnK    = log(K_real)
  )
  candidates$Y4_Kb <- df_base |> mutate(
    label  = "VAcorp / pKN, K / pKN",
    Y_real = VAcorp / (pKN_2005 / 100),
    K_real = KGCcorp / (pKN_2005 / 100),
    lnY    = log(Y_real),
    lnK    = log(K_real)
  )
}

# K undeflated variants
candidates$Y1_Kc <- df_base |> mutate(
  label  = "VAcorp / pIG, K nominal",
  Y_real = VAcorp / (pIG_2005 / 100),
  K_real = KGCcorp,
  lnY    = log(Y_real),
  lnK    = log(K_real)
)

# Report candidate coverage
for (nm in names(candidates)) {
  cd <- candidates[[nm]]
  n_valid <- sum(is.finite(cd$lnY) & cd$year >= WINDOW[1] & cd$year <= WINDOW[2])
  cat(sprintf("  %s [%s]: %d valid obs in window\n", nm, cd$label[1], n_valid))
}

# ------------------------------------------------------------
# PHASE 3 — GRID RUN
# ------------------------------------------------------------
cat("\n--- PHASE 3: Grid run ---\n")

results_list <- imap(candidates, function(cd, nm) {
  label <- cd$label[1]
  cat(sprintf("Running %s: %s ... ", nm, label))

  # Skip if no valid lnY in window
  n_valid <- sum(is.finite(cd$lnY) & cd$year >= WINDOW[1] & cd$year <= WINDOW[2])
  if (n_valid < 20) {
    cat("SKIPPED (insufficient data)\n")
    return(list(
      label = label, theta = NA_real_, a = NA_real_,
      c_d56 = NA_real_, c_d74 = NA_real_, c_d80 = NA_real_,
      alpha = NA_real_, AIC = NA_real_, BIC = NA_real_,
      loglik = NA_real_, R2 = NA_real_, rmse_u = NA_real_,
      n_obs = n_valid, failed = TRUE, error_msg = "Insufficient data",
      candidate_id = nm, loss = Inf
    ))
  }

  res <- run_ardl_case3(cd, label = label)
  loss <- score_candidate(res)

  cat(sprintf(
    "theta=%.4f | a=%.4f | c_d74=%.4f | AIC=%.2f | L=%.4f%s\n",
    coalesce(res$theta, NA_real_),
    coalesce(res$a,     NA_real_),
    coalesce(res$c_d74, NA_real_),
    coalesce(res$AIC,   NA_real_),
    loss,
    if (isTRUE(res$failed)) " [FAILED]" else ""
  ))

  res$candidate_id <- nm
  res$loss         <- loss
  res
})

# Flatten to tibble
results_tbl <- map_dfr(results_list, function(r) {
  as_tibble(r[c("candidate_id", "label", "theta", "a", "c_d56",
                "c_d74", "c_d80", "alpha", "AIC", "BIC", "loglik",
                "R2", "rmse_u", "n_obs", "failed", "error_msg", "loss")])
}) |>
  arrange(loss)

readr::write_csv(results_tbl, results_path)
cat("\nGrid results written to:", results_path, "\n")

cat("\n=== RANKED RESULTS ===\n")
print(results_tbl |>
  select(candidate_id, label, theta, a, c_d74, AIC, loss, failed) |>
  mutate(across(where(is.numeric), ~ round(.x, 4))))

# ------------------------------------------------------------
# PHASE 4 — WINNER VALIDATION
# ------------------------------------------------------------
cat("\n--- PHASE 4: Winner validation ---\n")

winner_row <- results_tbl |> filter(!failed) |> slice(1)

if (nrow(winner_row) == 0) {
  cat("ERROR: All candidates failed. Cannot declare winner.\n")
  winner_status <- "ALL_FAILED"
} else {
  cat(sprintf("Winner: %s [%s]\n", winner_row$candidate_id, winner_row$label))
  cat(sprintf("  theta = %.4f | target = %.4f | gap = %.4f\n",
              winner_row$theta, TARGET$theta,
              abs(winner_row$theta - TARGET$theta)))

  winner_status <- if (abs(winner_row$theta - TARGET$theta) < SUCCESS_THRESHOLD) {
    cat("STATUS: SUCCESS — theta within threshold\n")
    "SUCCESS"
  } else {
    cat("STATUS: PARTIAL — closest candidate but gap exceeds threshold\n")
    "PARTIAL"
  }

  # Full verification block for winner
  winner_cd <- candidates[[winner_row$candidate_id]]
  winner_res <- run_ardl_case3(winner_cd, label = winner_row$label)

  cat("\n=== WINNER VERIFICATION BLOCK ===\n")
  cat(sprintf("theta_hat: %.4f | Target: %.4f\n", winner_res$theta, TARGET$theta))
  cat(sprintf("a_hat:     %.4f | Target: %.4f\n", winner_res$a,     TARGET$a))
  cat(sprintf("c_d56:     %.4f | Target: %.4f\n", winner_res$c_d56, TARGET$c_d56))
  cat(sprintf("c_d74:     %.4f | Target: %.4f\n", winner_res$c_d74, TARGET$c_d74))
  cat(sprintf("c_d80:     %.4f | Target: %.4f\n", winner_res$c_d80, TARGET$c_d80))
  cat(sprintf("AIC:       %.4f | Target: %.4f\n", winner_res$AIC,   TARGET$AIC))
  cat(sprintf("loglik:    %.4f | Target: %.4f\n", winner_res$loglik, TARGET$loglik))
  cat(sprintf("RMSE_u:    %.6f\n", winner_res$rmse_u))
}

# ------------------------------------------------------------
# PHASE 5 — WRITE REPORT
# ------------------------------------------------------------
cat("\n--- PHASE 5: Writing report ---\n")

ranked_md <- results_tbl |>
  select(candidate_id, label, theta, a, c_d74, AIC, loss, failed) |>
  mutate(across(where(is.numeric), ~ round(.x, 4))) |>
  mutate(
    theta_gap = round(abs(theta - TARGET$theta), 4),
    status    = if_else(!failed & theta_gap < SUCCESS_THRESHOLD, "✓ SUCCESS", "")
  )

# Format as markdown table
md_table <- function(df) {
  header <- paste("|", paste(names(df), collapse = " | "), "|")
  sep    <- paste("|", paste(rep("---", ncol(df)), collapse = " | "), "|")
  rows   <- apply(df, 1, function(r) paste("|", paste(r, collapse = " | "), "|"))
  paste(c(header, sep, rows), collapse = "\n")
}

config_fix <- if (winner_status != "ALL_FAILED") {
  cd_id <- winner_row$candidate_id
  y_series <- switch(cd_id,
    Y1 = "VAcorp",
    Y2 = "GVAcorp_nom (VAcorp + DEPCcorp)",
    Y3 = "GVA_real (BEA Table 1.14 direct)",
    Y4 = "VAcorp",
    Y5 = "GVAcorp_nom",
    Y6 = "VAcorp",
    Y7 = "GVAcorp_nom",
    "UNKNOWN"
  )
  deflator <- switch(cd_id,
    Y1 = "pIGcorpbea (2005=100)",
    Y2 = "pIGcorpbea (2005=100)",
    Y3 = "none (series already real)",
    Y4 = "pKN (2005=100)",
    Y5 = "pKN (2005=100)",
    Y6 = "implicit GVA deflator (GVAcorp_nom / GVA_real)",
    Y7 = "implicit GVA deflator (GVAcorp_nom / GVA_real)",
    "UNKNOWN"
  )
  sprintf(
"```r
# In 10_config.R:
y_nom    = \"%s\"
p_index  = \"%s\"
k_nom    = \"KGCcorp\"   # unchanged
```", y_series, deflator)
} else {
  "No winner identified — all candidates failed."
}

report <- sprintf(
'# S0 Deflator Grid Search — Agent Report
Generated: %s

## Status: %s

## Targets (Shaikh 2016, Table 6.7.14)
| Parameter | Target |
|---|---|
| theta | 0.6609 |
| a (intercept) | 2.1782 |
| c_d74 | -0.8548 |
| AIC | -319.38 |
| loglik | 170.69 |

## BEA API Fetch
Status: %s

## Ranked Candidate Results
%s

## Winner: %s
Label: %s
Theta gap: %.4f

### Verification Block
| | Estimate | Target | Gap |
|---|---|---|---|
| theta | %.4f | %.4f | %.4f |
| a | %.4f | %.4f | %.4f |
| c_d56 | %.4f | %.4f | %.4f |
| c_d74 | %.4f | %.4f | %.4f |
| c_d80 | %.4f | %.4f | %.4f |
| AIC | %.4f | %.4f | %.4f |
| loglik | %.4f | %.4f | %.4f |

## Required CONFIG Changes
%s

## Next Steps
%s

## Search Space Not Covered
- pKN deflator requires manual extraction from Appendix II.1 and addition to CSV
- BEA Table 1.14 real GVA requires API key or manual download if Y3/Y6/Y7 skipped
- If all candidates fail: open _Appendix6.8DataTablesCorrected.xlsx sheet
  Appndx6.8.II.7 and extract the implicit price deflator for corporate capital
  to construct a combined output deflator
',
  format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
  winner_status,
  if (bea_success) "SUCCESS" else "SKIPPED (no API key or local file)",
  md_table(ranked_md),
  if (winner_status != "ALL_FAILED") winner_row$candidate_id else "NONE",
  if (winner_status != "ALL_FAILED") winner_row$label else "N/A",
  if (winner_status != "ALL_FAILED") abs(winner_row$theta - TARGET$theta) else NA,
  if (winner_status != "ALL_FAILED") winner_res$theta  else NA, TARGET$theta,
  if (winner_status != "ALL_FAILED") abs(winner_res$theta  - TARGET$theta)  else NA,
  if (winner_status != "ALL_FAILED") winner_res$a      else NA, TARGET$a,
  if (winner_status != "ALL_FAILED") abs(winner_res$a      - TARGET$a)      else NA,
  if (winner_status != "ALL_FAILED") winner_res$c_d56  else NA, TARGET$c_d56,
  if (winner_status != "ALL_FAILED") abs(winner_res$c_d56  - TARGET$c_d56)  else NA,
  if (winner_status != "ALL_FAILED") winner_res$c_d74  else NA, TARGET$c_d74,
  if (winner_status != "ALL_FAILED") abs(winner_res$c_d74  - TARGET$c_d74)  else NA,
  if (winner_status != "ALL_FAILED") winner_res$c_d80  else NA, TARGET$c_d80,
  if (winner_status != "ALL_FAILED") abs(winner_res$c_d80  - TARGET$c_d80)  else NA,
  if (winner_status != "ALL_FAILED") winner_res$AIC    else NA, TARGET$AIC,
  if (winner_status != "ALL_FAILED") abs(winner_res$AIC    - TARGET$AIC)    else NA,
  if (winner_status != "ALL_FAILED") winner_res$loglik else NA, TARGET$loglik,
  if (winner_status != "ALL_FAILED") abs(winner_res$loglik - TARGET$loglik) else NA,
  config_fix,
  if (winner_status == "SUCCESS") {
    "1. Apply CONFIG changes above\n2. Re-run 20_S0_shaikh_faithful.R\n3. Confirm verification block passes gate\n4. Commit and merge"
  } else {
    "1. Register BEA API key at https://apps.bea.gov/API/signup\n2. Set env var BEA_API_KEY and re-run this script\n3. If Y3/Y6/Y7 still fail: manually download Table 1.14 from BEA website\n4. If all candidates fail: open Appendix II.7 in Excel and extract pY series manually"
  }
)

writeLines(report, report_path)
cat("Report written to:", report_path, "\n")

cat("\n=== GRID SEARCH COMPLETE ===\n")
cat("Finished:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("Status:", winner_status, "\n")
