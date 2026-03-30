# ============================================================
# 26_S0_manual_override_RepData.R
#
# Manual override: test Y = GVAcorp_nom / Py (RepData deflator)
# against all K deflator variants, with full delta-method LR
# dummy multipliers — the grid search could not compute these.
#
# Candidates tested:
#   A: Y=GVAcorp/Py,  K=KGCcorp/pIG   [best intercept from grid]
#   B: Y=GVAcorp/Py,  K=KGCcorp/pKN   [best AIC from grid, combined]
#   C: Y=VAcorp/Py,   K=KGCcorp/pIG   [net output variant]
#   D: Y=GVAcorp/Py,  K=KGCcorp/Py    [pure Py deflation of both]
#
# Targets (Shaikh 2016, Table 6.7.14):
#   theta=-0.6609 | a=2.1782 | c_d56=-0.7428
#   c_d74=-0.8548 | c_d80=-0.4780 | AIC=-319.38
#
# Outputs:
#   Printed verification blocks for all candidates
#   output/CriticalReplication/S0_faithful/csv/S0_override_results.csv
# ============================================================

rm(list = ls())

suppressPackageStartupMessages({
  library(here)
  library(readr)
  library(readxl)
  library(dplyr)
  library(purrr)
  library(ARDL)
})

source(here::here("codes", "10_config.R"))
source(here::here("codes", "99_utils.R"))

# ------------------------------------------------------------
# TARGETS
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

WINDOW     <- c(1947L, 2011L)
ORDER      <- c(2L, 4L)
DUMMY_YEARS <- c(1956L, 1974L, 1980L)

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

# Full ARDL runner with delta-method LR dummy multipliers
run_full_ardl <- function(df, label) {
  cat("\n", strrep("=", 60), "\n")
  cat("CANDIDATE:", label, "\n")
  cat(strrep("=", 60), "\n")
  
  tryCatch({
    df_w <- df |>
      filter(year >= WINDOW[1], year <= WINDOW[2]) |>
      filter(is.finite(lnY), is.finite(lnK)) |>
      arrange(year)
    
    cat("N obs in window:", nrow(df_w),
        " | lnY[1947]=", round(df_w$lnY[df_w$year==1947], 4),
        " | lnK[1947]=", round(df_w$lnK[df_w$year==1947], 4), "\n")
    
    # Structural break check
    cat("\nStructural break check (lnY at dummy years):\n")
    df_w |>
      filter(year %in% c(1955, 1956, 1957, 1973, 1974, 1975,
                         1979, 1980, 1981)) |>
      select(year, lnY, lnK) |>
      print()
    
    dummy_names <- paste0("d", DUMMY_YEARS)
    
    df_ts <- ts(
      df_w |> select(lnY, lnK, all_of(dummy_names)),
      start = min(df_w$year), frequency = 1
    )
    
    fit <- ARDL::ardl(
      lnY ~ lnK | d1956 + d1974 + d1980,
      data  = df_ts,
      order = ORDER
    )
    
    cat("\n--- ARDL(2,4) SR Coefficients ---\n")
    print(summary(fit)$coefficients)
    
    # LR multipliers via multipliers() for lnK + intercept
    lr_base <- ARDL::multipliers(fit, type = "lr")
    
    # Delta-method LR multipliers for dummies
    coefs     <- coef(fit)
    phi_names <- grep("^L\\(lnY,", names(coefs), value = TRUE)
    den       <- 1 - sum(coefs[phi_names])
    
    gamma_sr <- coefs[dummy_names]
    dummy_lr <- gamma_sr / den
    
    vc    <- vcov(fit)
    se_lr <- numeric(length(dummy_names))
    
    for (j in seq_along(dummy_names)) {
      dname   <- dummy_names[j]
      gamma_j <- coefs[dname]
      pnames  <- c(dname, phi_names)
      idx     <- match(pnames, names(coefs))
      grad    <- numeric(length(pnames))
      grad[1]  <- 1 / den
      grad[-1] <- gamma_j / den^2
      V_sub    <- vc[idx, idx, drop = FALSE]
      se_lr[j] <- sqrt(as.numeric(t(grad) %*% V_sub %*% grad))
    }
    
    t_lr <- dummy_lr / se_lr
    p_lr <- 2 * pt(abs(t_lr), df = df.residual(fit), lower.tail = FALSE)
    
    dummy_table <- data.frame(
      Term       = dummy_names,
      Estimate   = as.numeric(dummy_lr),
      SE         = se_lr,
      t_val      = t_lr,
      p_val      = p_lr,
      stringsAsFactors = FALSE
    )
    
    cat("\n--- LR Multipliers (delta-method dummies) ---\n")
    print(lr_base)
    cat("\nDummy LR multipliers:\n")
    print(dummy_table)
    
    # Extract key estimates
    theta  <- lr_base$Estimate[lr_base$Term == "lnK"]
    a_hat  <- lr_base$Estimate[lr_base$Term == "(Intercept)"]
    c_d56  <- dummy_lr["d1956"]
    c_d74  <- dummy_lr["d1974"]
    c_d80  <- dummy_lr["d1980"]
    
    aic_v    <- AIC(fit)
    bic_v    <- BIC(fit)
    loglik_v <- as.numeric(logLik(fit))
    r2_v     <- summary(fit)$r.squared
    
    # Recover u_hat and RMSE vs u_shaikh
    lnYp  <- a_hat + theta * df_w$lnK +
      c_d56 * df_w$d1956 +
      c_d74 * df_w$d1974 +
      c_d80 * df_w$d1980
    u_hat <- exp(df_w$lnY - lnYp)
    rmse_u <- if ("u_shaikh" %in% names(df_w)) {
      sqrt(mean((u_hat - df_w$u_shaikh)^2, na.rm = TRUE))
    } else NA_real_
    
    # F-bounds test
    bt_f <- tryCatch(
      ARDL::bounds_f_test(fit, case = 3, alpha = 0.05,
                          pvalue = TRUE, exact = FALSE),
      error = function(e) NULL
    )
    bt_t <- tryCatch(
      ARDL::bounds_t_test(fit, case = 3, alpha = 0.05,
                          pvalue = TRUE, exact = FALSE),
      error = function(e) NULL
    )
    
    cat("\n--- VERIFICATION vs SHAIKH TABLE 6.7.14 ---\n")
    cat(sprintf("theta_hat: %7.4f  | Target: %7.4f  | Gap: %+.4f\n",
                theta,  TARGET$theta,  theta  - TARGET$theta))
    cat(sprintf("a_hat:     %7.4f  | Target: %7.4f  | Gap: %+.4f\n",
                a_hat,  TARGET$a,      a_hat  - TARGET$a))
    cat(sprintf("c_d56:     %7.4f  | Target: %7.4f  | Gap: %+.4f\n",
                c_d56,  TARGET$c_d56,  c_d56  - TARGET$c_d56))
    cat(sprintf("c_d74:     %7.4f  | Target: %7.4f  | Gap: %+.4f\n",
                c_d74,  TARGET$c_d74,  c_d74  - TARGET$c_d74))
    cat(sprintf("c_d80:     %7.4f  | Target: %7.4f  | Gap: %+.4f\n",
                c_d80,  TARGET$c_d80,  c_d80  - TARGET$c_d80))
    cat(sprintf("AIC:       %7.4f  | Target: %7.4f  | Gap: %+.4f\n",
                aic_v,  TARGET$AIC,    aic_v  - TARGET$AIC))
    cat(sprintf("loglik:    %7.4f  | Target: %7.4f  | Gap: %+.4f\n",
                loglik_v, TARGET$loglik, loglik_v - TARGET$loglik))
    cat(sprintf("R2:        %7.4f\n", r2_v))
    cat(sprintf("RMSE_u:    %7.6f\n", rmse_u))
    
    if (!is.null(bt_f)) {
      cat(sprintf("Bounds F:  stat=%.4f  p=%.4f\n",
                  bt_f$statistic, bt_f$p.value))
    }
    if (!is.null(bt_t)) {
      cat(sprintf("Bounds t:  stat=%.4f  p=%.4f\n",
                  bt_t$statistic, bt_t$p.value))
    }
    
    # Composite loss (with dummies now)
    loss <- abs(theta - TARGET$theta) +
      0.5 * abs(a_hat - TARGET$a) +
      0.3 * abs(c_d74 - TARGET$c_d74) +
      0.01 * abs(aic_v - TARGET$AIC)
    
    cat(sprintf("\nComposite loss L: %.4f\n", loss))
    
    list(
      label  = label,
      theta  = theta,  a = a_hat,
      c_d56  = c_d56,  c_d74 = c_d74, c_d80 = c_d80,
      AIC    = aic_v,  loglik = loglik_v, R2 = r2_v,
      rmse_u = rmse_u, loss = loss, failed = FALSE
    )
    
  }, error = function(e) {
    cat("FAILED:", conditionMessage(e), "\n")
    list(label = label, theta = NA, a = NA, c_d56 = NA,
         c_d74 = NA, c_d80 = NA, AIC = NA, loglik = NA,
         R2 = NA, rmse_u = NA, loss = Inf, failed = TRUE)
  })
}

# ------------------------------------------------------------
# LOAD BASE DATA
# ------------------------------------------------------------
df_raw <- readr::read_csv(
  here::here(CONFIG$data_shaikh),
  show_col_types = FALSE
) |>
  rename(u_shaikh = uK) |>
  mutate(
    year        = as.integer(year),
    GVAcorp_nom = VAcorp + DEPCcorp
  )

# Load Py from RepData.xlsx
py_df <- readxl::read_excel(
  here::here("data/raw/Shaikh_RepData.xlsx"),
  sheet = "long"
) |>
  transmute(year = as.integer(year), Py = as.numeric(Py)) |>
  filter(is.finite(year), is.finite(Py))

cat("Py loaded:", nrow(py_df), "obs\n")
cat("Py 1947:", round(py_df$Py[py_df$year == 1947], 4),
    "| Py 2011:", round(py_df$Py[py_df$year == 2011], 4), "\n")

# Load pKN from Appendix II.1
xl_path <- here::here("data/raw/_Appendix6.8DataTablesCorrected.xlsx")
pKN_df  <- tryCatch({
  df_II1_raw <- readxl::read_excel(
    xl_path, sheet = "Appndx 6.8.II.1",
    col_names = TRUE
  )
  # Row 4 = pKN, years start at col 4
  pKN_row <- df_II1_raw[4, ]
  year_cols <- names(df_II1_raw)[4:ncol(df_II1_raw)]
  years_int <- suppressWarnings(as.integer(year_cols))
  vals      <- suppressWarnings(as.numeric(pKN_row[4:ncol(df_II1_raw)]))
  valid     <- is.finite(years_int) & is.finite(vals)
  data.frame(year = years_int[valid], pKN = vals[valid])
}, error = function(e) {
  cat("pKN extraction failed:", conditionMessage(e), "\n")
  NULL
})

if (!is.null(pKN_df)) {
  cat("pKN loaded:", nrow(pKN_df), "obs\n")
  cat("pKN 1947:", round(pKN_df$pKN[pKN_df$year == 1947], 4), "\n")
}

# ------------------------------------------------------------
# BUILD BASE FRAME
# ------------------------------------------------------------
df_base <- df_raw |>
  left_join(py_df, by = "year") |>
  mutate(
    pIG_2005 = rebase_to_100(pIGcorpbea, year, 2005L)
  )

if (!is.null(pKN_df)) {
  df_base <- df_base |>
    left_join(pKN_df, by = "year") |>
    mutate(pKN_2005 = rebase_to_100(pKN, year, 2005L))
} else {
  df_base <- df_base |> mutate(pKN = NA_real_, pKN_2005 = NA_real_)
}

df_base <- make_step_dummies(df_base, DUMMY_YEARS)

# ------------------------------------------------------------
# BUILD CANDIDATES
# ------------------------------------------------------------

# A: GVAcorp/Py, K/pIG  [best a from grid]
cd_A <- df_base |> mutate(
  lnY = log(GVAcorp_nom / (Py / 100)),
  lnK = log(KGCcorp     / (pIG_2005 / 100))
)

# B: GVAcorp/Py, K/pKN  [best AIC from grid, now with dummies]
cd_B <- df_base |> mutate(
  lnY = log(GVAcorp_nom / (Py / 100)),
  lnK = log(KGCcorp     / (pKN_2005 / 100))
)

# C: VAcorp/Py, K/pIG  [net output]
cd_C <- df_base |> mutate(
  lnY = log(VAcorp  / (Py / 100)),
  lnK = log(KGCcorp / (pIG_2005 / 100))
)

# D: GVAcorp/Py, K/Py  [pure Py, closest to RepData winner]
cd_D <- df_base |> mutate(
  lnY = log(GVAcorp_nom / (Py / 100)),
  lnK = log(KGCcorp     / (Py / 100))
)

# E: VAcorp/Py, K/Py
cd_E <- df_base |> mutate(
  lnY = log(VAcorp  / (Py / 100)),
  lnK = log(KGCcorp / (Py / 100))
)

# F: VAcorp/Py, K/pKN
cd_F <- df_base |> mutate(
  lnY = log(VAcorp  / (Py / 100)),
  lnK = log(KGCcorp / (pKN_2005 / 100))
)

# ------------------------------------------------------------
# RUN ALL
# ------------------------------------------------------------
candidates <- list(
  A = list(df = cd_A, label = "GVAcorp/Py | K/pIG"),
  B = list(df = cd_B, label = "GVAcorp/Py | K/pKN"),
  C = list(df = cd_C, label = "VAcorp/Py  | K/pIG"),
  D = list(df = cd_D, label = "GVAcorp/Py | K/Py"),
  E = list(df = cd_E, label = "VAcorp/Py  | K/Py"),
  F = list(df = cd_F, label = "VAcorp/Py  | K/pKN")
)

results <- imap(candidates, function(x, nm) {
  run_full_ardl(x$df, label = paste0(nm, ": ", x$label))
})

# ------------------------------------------------------------
# SUMMARY TABLE
# ------------------------------------------------------------
cat("\n\n", strrep("=", 70), "\n")
cat("SUMMARY — ALL CANDIDATES\n")
cat(strrep("=", 70), "\n")

summary_tbl <- map_dfr(results, function(r) {
  tibble(
    label  = r$label,
    theta  = round(r$theta,  4),
    a      = round(r$a,      4),
    c_d74  = round(r$c_d74,  4),
    c_d56  = round(r$c_d56,  4),
    c_d80  = round(r$c_d80,  4),
    AIC    = round(r$AIC,    2),
    loss   = round(r$loss,   4),
    failed = r$failed
  )
}) |> arrange(loss)

print(summary_tbl, n = 20)

cat("\nTargets:\n")
cat(sprintf("  theta=%.4f | a=%.4f | c_d74=%.4f | c_d56=%.4f | c_d80=%.4f | AIC=%.2f\n",
            TARGET$theta, TARGET$a, TARGET$c_d74,
            TARGET$c_d56, TARGET$c_d80, TARGET$AIC))

# Write CSV
out_path <- here::here(
  "output/CriticalReplication/S0_faithful/csv/S0_override_results.csv"
)
dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)
readr::write_csv(summary_tbl, out_path)
cat("\nResults written to:", out_path, "\n")

# Winner
winner <- summary_tbl |> filter(!failed) |> slice(1)
cat("\nBEST CANDIDATE:", winner$label, "\n")
cat(sprintf("  theta gap: %.4f | a gap: %.4f | c_d74 gap: %.4f | loss: %.4f\n",
            abs(winner$theta - TARGET$theta),
            abs(winner$a     - TARGET$a),
            abs(winner$c_d74 - TARGET$c_d74),
            winner$loss))

if (abs(winner$theta - TARGET$theta) < 0.05) {
  cat("\nSTATUS: SUCCESS — theta within 0.05 threshold\n")
} else {
  cat("\nSTATUS: PARTIAL — best available, gap exceeds threshold\n")
  cat("Next: check Appendix 6.7 for the exact deflator Shaikh describes in text\n")
}