# ============================================================
# 21_S1_ardl_geometry.R
#
# S1 — ARDL specification geometry: full lattice, admissibility
#       screening, IC contours, fattened frontier F^(0.20).
#
# Grid: p in 1:5, q in 1:5, case in 1:5, s in {s0,s1,s2,s3}
#        => 500 specifications
#
# Uses:
#   - CONFIG          from codes/10_config.R
#   - utilities       from codes/99_utils.R
#   - make_spec_row() from codes/98_ardl_helpers.R
#   - extract_envelope(), plot_*() from 98_ardl_helpers.R
#
# Outputs under: output/CriticalReplication/S1_geometry/
# ============================================================

rm(list = ls())

suppressPackageStartupMessages({
  library(here)
  library(readxl)
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(ARDL)
  library(ggplot2)
})

# ------------------------------------------------------------
# Load CONFIG + UTILS + HELPERS
# ------------------------------------------------------------
source(here::here("codes", "10_config.R"))
source(here::here("codes", "99_utils.R"))
source(here::here("codes", "98_ardl_helpers.R"))

stopifnot(exists("CONFIG"))

# ------------------------------------------------------------
# TOGGLES
# ------------------------------------------------------------
P_MAX       <- 5L
Q_MAX       <- 5L
CASES       <- 1:5
EXACT_TEST  <- FALSE          # asymptotic; flip to TRUE for exact-sample later
F_GATE_ALPHA <- 0.10          # admissibility threshold for F-bounds
F020_QUANTILE <- 0.20         # fattened frontier: bottom 20% AIC

WINDOW_TAG  <- "shaikh_window"
DUMMY_YEARS <- c(1956L, 1974L, 1980L)

DUMMY_SETS <- list(
  s0 = character(0),
  s1 = "d1974",
  s2 = c("d1974", "d1980"),
  s3 = c("d1956", "d1974", "d1980")
)

# t-bounds feasibility: only cases 1, 3, 5
T_BOUNDS_CASES <- c(1L, 3L, 5L)

# ------------------------------------------------------------
# 0) Data preparation (mirrors S0)
# ------------------------------------------------------------
df_raw <- readr::read_csv(here::here(CONFIG[["data_shaikh"]]), show_col_types=FALSE)

Py <- as.numeric(df_raw[[CONFIG$p_index]])
p_scale <- Py / 100

df0 <- data.frame(
  year  = as.integer(df_raw[[CONFIG$year_col]]),
  Y_nom = as.numeric(df_raw[[CONFIG$y_nom]]),
  K_nom = as.numeric(df_raw[[CONFIG$k_nom]])
)
df0 <- df0[complete.cases(df0) & df0$year > 0, ]
df0$lnY <- log(df0$Y_nom / p_scale[match(df0$year, as.integer(df_raw[[CONFIG$year_col]]))])
df0$lnK <- log(df0$K_nom / p_scale[match(df0$year, as.integer(df_raw[[CONFIG$year_col]]))])

# Step dummies
for (yy in DUMMY_YEARS) df0[[paste0("d", yy)]] <- as.integer(df0$year >= yy)

# Window
w <- CONFIG$WINDOWS_LOCKED[[WINDOW_TAG]]
df <- df0[df0$year >= w[1] & df0$year <= w[2], ]
df <- df[order(df$year), ]
T_obs <- nrow(df)

# ts object with all columns needed
all_dum_names <- paste0("d", DUMMY_YEARS)
df_ts <- ts(df[, c("lnY", "lnK", all_dum_names)],
            start = min(df$year), frequency = 1)

# Shaikh u for RMSE (load separately)
u_shaikh <- as.numeric(df_raw[["u_shaikh"]])[match(df$year, as.integer(df_raw[[CONFIG$year_col]]))]

# ------------------------------------------------------------
# 1) Output directories + log
# ------------------------------------------------------------
EXERCISE_DIR <- here::here(CONFIG$OUT_CR$S1_geometry %||% "output/CriticalReplication/S1_geometry")
CSV_DIR <- file.path(EXERCISE_DIR, "csv")
LOG_DIR <- file.path(EXERCISE_DIR, "logs")
FIG_DIR <- file.path(EXERCISE_DIR, "figures")

dir.create(CSV_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(LOG_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(FIG_DIR, recursive = TRUE, showWarnings = FALSE)

log_path <- file.path(LOG_DIR, "S1_ardl_geometry_log.txt")
sink(log_path, split = TRUE)
on.exit(try(sink(), silent = TRUE), add = TRUE)

cat("=== S1 ARDL Specification Geometry ===\n")
cat("Timestamp: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("Grid:      p=1:", P_MAX, " q=1:", Q_MAX,
    " cases=", paste(CASES, collapse=","),
    " s={", paste(names(DUMMY_SETS), collapse=","), "}\n")
cat("Total:     ", P_MAX * Q_MAX * length(CASES) * length(DUMMY_SETS), " specs\n")
cat("Bounds:    exact=", EXACT_TEST, "\n")
cat("F gate:    alpha=", F_GATE_ALPHA, "\n")
cat("Window:    ", WINDOW_TAG, " (", min(df$year), "-", max(df$year), ", T=", T_obs, ")\n\n")

# ------------------------------------------------------------
# 2) Sandwich vcov helper (HC0 — White 1980)
# ------------------------------------------------------------
compute_sandwich_hc0 <- function(fit) {
  tryCatch({
    X <- model.matrix(fit)
    e <- as.numeric(residuals(fit))   # coerce ts -> plain numeric
    bread <- solve(crossprod(X))
    meat  <- crossprod(X * e)
    bread %*% meat %*% bread
  }, error = function(e) NULL)
}

# ------------------------------------------------------------
# 3) Build ARDL formula per (case, s)
# ------------------------------------------------------------
build_ardl_formula <- function(case_id, dummy_names) {
  has_dummies <- length(dummy_names) > 0
  dum_str <- if (has_dummies) paste(dummy_names, collapse = " + ") else NULL

  if (case_id == 1L) {
    # No intercept, no trend
    if (has_dummies) {
      as.formula(paste0("lnY ~ -1 + lnK | ", dum_str))
    } else {
      as.formula("lnY ~ -1 + lnK")
    }
  } else if (case_id %in% c(4L, 5L)) {
    # Intercept + trend
    if (has_dummies) {
      as.formula(paste0("lnY ~ lnK | trend(lnY) + ", dum_str))
    } else {
      as.formula("lnY ~ lnK | trend(lnY)")
    }
  } else {
    # Cases 2-3: intercept, no trend
    if (has_dummies) {
      as.formula(paste0("lnY ~ lnK | ", dum_str))
    } else {
      as.formula("lnY ~ lnK")
    }
  }
}

# ------------------------------------------------------------
# 4) LR multiplier extraction (reusing S0 delta-method logic)
# ------------------------------------------------------------
extract_lr_all <- function(fit, dummy_names) {
  lr <- tryCatch(ARDL::multipliers(fit, type = "lr"), error = function(e) NULL)
  if (is.null(lr)) return(list(theta = NA_real_, theta_se = NA_real_,
                                 a = NA_real_, den = NA_real_,
                                 lr_dummies = setNames(rep(NA_real_, length(dummy_names)), dummy_names)))

  cc <- coef(fit)
  phi_names <- grep("^L\\(lnY,", names(cc), value = TRUE)
  den <- 1 - sum(cc[phi_names])

  theta_row <- lr[lr$Term == "lnK", , drop = FALSE]
  theta <- if (nrow(theta_row) > 0) theta_row$Estimate[1] else NA_real_
  theta_se <- if (nrow(theta_row) > 0) theta_row[["Std. Error"]][1] else NA_real_

  a_row <- lr[lr$Term == "(Intercept)", , drop = FALSE]
  a <- if (nrow(a_row) > 0) a_row$Estimate[1] else 0

  # Dummy LR multipliers via delta method
  lr_dummies <- setNames(rep(NA_real_, length(dummy_names)), dummy_names)
  if (length(dummy_names) > 0) {
    for (dname in dummy_names) {
      if (dname %in% names(cc)) {
        lr_dummies[dname] <- cc[dname] / den
      }
    }
  }

  list(theta = theta, theta_se = theta_se, a = a, den = den, lr_dummies = lr_dummies)
}

# ------------------------------------------------------------
# 5) Compute u_hat from LR multipliers
# ------------------------------------------------------------
compute_u_hat <- function(df, lr_info, dummy_names, case_id, fit) {
  if (!is.finite(lr_info$theta)) return(rep(NA_real_, nrow(df)))

  lnYp <- lr_info$a + lr_info$theta * df$lnK
  for (dname in dummy_names) {
    if (dname %in% names(lr_info$lr_dummies) && is.finite(lr_info$lr_dummies[dname])) {
      lnYp <- lnYp + lr_info$lr_dummies[dname] * df[[dname]]
    }
  }

  # Trend component for Cases 4-5
  if (case_id %in% c(4L, 5L) && is.finite(lr_info$den) && lr_info$den != 0) {
    cc <- coef(fit)
    trend_name <- grep("^trend", names(cc), value = TRUE)
    if (length(trend_name) > 0) {
      trend_lr <- cc[trend_name[1]] / lr_info$den
      lnYp <- lnYp + trend_lr * seq(0, nrow(df) - 1)
    }
  }

  exp(df$lnY - lnYp)
}

# ------------------------------------------------------------
# 6) Main grid sweep
# ------------------------------------------------------------
grid <- expand.grid(
  p = 1:P_MAX, q = 1:Q_MAX,
  case_id = CASES, s = names(DUMMY_SETS),
  stringsAsFactors = FALSE
)

n_grid <- nrow(grid)
cat("Estimating", n_grid, "specifications...\n")

# Pre-allocate storage
spec_rows <- vector("list", n_grid)
u_hat_store <- matrix(NA_real_, nrow = T_obs, ncol = n_grid)
n_done <- 0L
n_fail <- 0L

t0 <- Sys.time()

for (i in seq_len(n_grid)) {
  pp      <- grid$p[i]
  qq      <- grid$q[i]
  cc      <- grid$case_id[i]
  ss      <- grid$s[i]
  dnames  <- DUMMY_SETS[[ss]]

  spec_id <- paste0("p", pp, "_q", qq, "_c", cc, "_", ss)

  result <- tryCatch({
    fml <- build_ardl_formula(cc, dnames)
    fit <- ARDL::ardl(formula = fml, data = df_ts, order = c(pp, qq))

    # Bounds F-test
    bt_f <- tryCatch(
      ARDL::bounds_f_test(fit, case = cc, alpha = 0.05, pvalue = TRUE, exact = EXACT_TEST),
      error = function(e) list(statistic = NA_real_, p.value = NA_real_)
    )
    f_stat <- if (is.list(bt_f) && !is.null(bt_f$statistic)) as.numeric(bt_f$statistic) else NA_real_
    f_pval <- if (is.list(bt_f) && !is.null(bt_f$p.value))   as.numeric(bt_f$p.value) else NA_real_

    # Bounds t-test (only cases 1, 3, 5)
    t_stat <- NA_real_; t_pval <- NA_real_
    if (cc %in% T_BOUNDS_CASES) {
      bt_t <- tryCatch(
        ARDL::bounds_t_test(fit, case = cc, alpha = 0.05, pvalue = TRUE, exact = EXACT_TEST),
        error = function(e) list(statistic = NA_real_, p.value = NA_real_)
      )
      t_stat <- if (is.list(bt_t) && !is.null(bt_t$statistic)) as.numeric(bt_t$statistic) else NA_real_
      t_pval <- if (is.list(bt_t) && !is.null(bt_t$p.value))   as.numeric(bt_t$p.value) else NA_real_
    }

    # Log-likelihood and parameters
    ll <- as.numeric(logLik(fit))
    k  <- length(coef(fit))
    T_eff <- length(residuals(fit))

    # ICOMP: vcov-based
    vc <- tryCatch(vcov(fit), error = function(e) NULL)

    # RICOMP: sandwich vcov
    sw <- compute_sandwich_hc0(fit)

    # Build canonical spec row (AIC, BIC, HQ, ICOMP, RICOMP)
    row <- make_spec_row(p = pp, q = qq, case = cc, s = ss,
                          logLik = ll, k_total = k, T_eff = T_eff,
                          vcov_mat = vc, sandwich_mat = sw)

    # LR multipliers
    lr_info <- extract_lr_all(fit, dnames)

    # u_hat
    u_hat <- compute_u_hat(df, lr_info, dnames, cc, fit)

    # Append bounds + LR to row
    row$boundsF_stat <- f_stat
    row$boundsF_p    <- f_pval
    row$boundsT_stat <- t_stat
    row$boundsT_p    <- t_pval
    row$theta_hat    <- lr_info$theta
    row$theta_se     <- lr_info$theta_se
    row$a_hat        <- lr_info$a
    row$den          <- lr_info$den
    row$s_K          <- qq / (pp + qq)
    row$admissible   <- if (is.finite(f_pval)) f_pval <= F_GATE_ALPHA else FALSE
    row$failed       <- FALSE
    row$error_msg    <- ""

    list(row = row, u_hat = u_hat)

  }, error = function(e) {
    row <- data.frame(
      p = pp, q = qq, case = cc, s = ss,
      neg2logL = NA_real_, k_total = NA_integer_, T_eff = NA_real_,
      logLik = NA_real_, AIC = NA_real_, BIC = NA_real_,
      HQ = NA_real_, AICc = NA_real_,
      ICOMP = NA_real_, RICOMP = NA_real_,
      boundsF_stat = NA_real_, boundsF_p = NA_real_,
      boundsT_stat = NA_real_, boundsT_p = NA_real_,
      theta_hat = NA_real_, theta_se = NA_real_,
      a_hat = NA_real_, den = NA_real_,
      s_K = qq / (pp + qq),
      admissible = FALSE, failed = TRUE,
      error_msg = conditionMessage(e),
      stringsAsFactors = FALSE
    )
    list(row = row, u_hat = rep(NA_real_, T_obs))
  })

  spec_rows[[i]] <- result$row
  u_hat_store[, i] <- result$u_hat

  if (isTRUE(result$row$failed)) n_fail <- n_fail + 1L
  n_done <- n_done + 1L

  # Heartbeat
  if (n_done %% CONFIG$HEARTBEAT_EVERY == 0 || n_done == n_grid) {
    cat(sprintf("  [%d/%d] done | %d failed | elapsed %.1fs\n",
                n_done, n_grid, n_fail, as.numeric(Sys.time() - t0, units = "secs")))
  }
}

# Combine into lattice data.frame
lattice <- bind_rows(spec_rows)
lattice$spec_idx <- seq_len(nrow(lattice))

cat("\nGrid complete:", nrow(lattice), "specs |",
    sum(lattice$failed), "failed |",
    sum(lattice$admissible, na.rm = TRUE), "admissible\n")

# ------------------------------------------------------------
# 7) Admissibility gate
# ------------------------------------------------------------
A_S1 <- lattice[lattice$admissible & !lattice$failed, ]
cat("A_S1 (admissible set):", nrow(A_S1), "specs\n")

if (nrow(A_S1) == 0) {
  cat("WARNING: No admissible specs! Cannot build frontier.\n")
  cat("STAGE_STATUS_HINT: stage=S1 status=no_admissible\n")
  cat("DONE (no frontier).\n")
  quit(save = "no", status = 0)
}

# ------------------------------------------------------------
# 8) F^(0.20) frontier (bottom 20% AIC among admissible)
# ------------------------------------------------------------
q20_aic <- quantile(A_S1$AIC, probs = F020_QUANTILE, na.rm = TRUE)
F020 <- A_S1[!is.na(A_S1$AIC) & A_S1$AIC <= q20_aic, ]
cat("F^(0.20) frontier:", nrow(F020), "specs (AIC <=", round(q20_aic, 2), ")\n")

# Also compute BIC frontier for comparison
q20_bic <- quantile(A_S1$BIC, probs = F020_QUANTILE, na.rm = TRUE)
F020_bic <- A_S1[!is.na(A_S1$BIC) & A_S1$BIC <= q20_bic, ]
cat("F^(0.20) BIC:     ", nrow(F020_bic), "specs (BIC <=", round(q20_bic, 2), ")\n")

# m0 check: (p=2, q=4, case=3, s=s3)
m0_idx <- which(lattice$p == 2 & lattice$q == 4 & lattice$case == 3 & lattice$s == "s3")
m0_admissible <- if (length(m0_idx) == 1) lattice$admissible[m0_idx] else FALSE
m0_in_F020 <- if (length(m0_idx) == 1 && !is.na(lattice$AIC[m0_idx]))
                lattice$AIC[m0_idx] <= q20_aic else FALSE
cat("\nm0 (p=2,q=4,c=3,s3): admissible=", m0_admissible,
    " | in F^(0.20)=", m0_in_F020, "\n")
if (length(m0_idx) == 1 && !lattice$failed[m0_idx]) {
  cat("  theta_m0 =", round(lattice$theta_hat[m0_idx], 4),
      " | AIC_m0 =", round(lattice$AIC[m0_idx], 2), "\n")
}

# ------------------------------------------------------------
# 9) IC winners
# ------------------------------------------------------------
ic_names <- c("AIC", "BIC", "HQ", "ICOMP", "RICOMP")
ic_winners <- list()
for (ic in ic_names) {
  vals <- A_S1[[ic]]
  if (all(is.na(vals))) {
    ic_winners[[ic]] <- A_S1[0, ]
    next
  }
  best_idx <- which.min(vals)
  ic_winners[[ic]] <- A_S1[best_idx, , drop = FALSE]
  w <- ic_winners[[ic]]
  cat(sprintf("  %15s winner: p=%d q=%d c=%d s=%-2s | %s=%.2f | theta=%.4f\n",
              ic, w$p, w$q, w$case, w$s, ic, w[[ic]], w$theta_hat))
}

# Diagnostic: check if all ICs select the same spec
winner_specs <- sapply(ic_winners, function(w) {
  if (nrow(w) == 0) return(NA_character_)
  paste(w$p, w$q, w$case, w$s, sep="_")
})
n_distinct_winners <- length(unique(na.omit(winner_specs)))
cat("\nIC DIAGNOSTIC: ", n_distinct_winners, "distinct winner(s) across",
    length(ic_names), "criteria\n")
if (n_distinct_winners == 1) {
  cat("  WARNING: All ICs select the same spec — H0 visual argument weakens\n")
}

# ------------------------------------------------------------
# 10) Theta and u_hat statistics across F^(0.20)
# ------------------------------------------------------------
theta_frontier <- F020$theta_hat[is.finite(F020$theta_hat)]
cat("\nTheta across F^(0.20):\n")
cat("  range:", round(range(theta_frontier), 4), "\n")
cat("  mean: ", round(mean(theta_frontier), 4), "\n")
cat("  sd:   ", round(sd(theta_frontier), 4), "\n")

# u_hat band across F^(0.20)
u_mat_frontier <- u_hat_store[, F020$spec_idx, drop = FALSE]
u_med   <- apply(u_mat_frontier, 1, median, na.rm = TRUE)
u_lower <- apply(u_mat_frontier, 1, min, na.rm = TRUE)
u_upper <- apply(u_mat_frontier, 1, max, na.rm = TRUE)

u_band <- data.frame(
  year    = df$year,
  u_med   = u_med,
  u_lower = u_lower,
  u_upper = u_upper,
  u_shaikh = u_shaikh
)

cat("\nUtilization band across F^(0.20):\n")
cat("  mean(u_med):", round(mean(u_med, na.rm = TRUE), 4), "\n")
cat("  mean band width:", round(mean(u_upper - u_lower, na.rm = TRUE), 4), "\n")

# s_K distribution
s_K_frontier <- F020$s_K[is.finite(F020$s_K)]
cat("\ns_K across F^(0.20):\n")
cat("  range:", round(range(s_K_frontier), 4), "\n")
cat("  mean: ", round(mean(s_K_frontier), 4), "\n")

# Case and dummy distribution
cat("\nCase distribution in F^(0.20):\n")
print(table(F020$case))
cat("\nDummy structure distribution in F^(0.20):\n")
print(table(F020$s))

# ------------------------------------------------------------
# 11) CSV exports
# ------------------------------------------------------------
safe_write_csv(lattice,  file.path(CSV_DIR, "S1_lattice_full.csv"))
safe_write_csv(A_S1,     file.path(CSV_DIR, "S1_admissible.csv"))
safe_write_csv(F020,     file.path(CSV_DIR, "S1_frontier_F020.csv"))
safe_write_csv(u_band,   file.path(CSV_DIR, "S1_frontier_u_band.csv"))
safe_write_csv(data.frame(theta = theta_frontier),
               file.path(CSV_DIR, "S1_frontier_theta.csv"))

cat("\nCSVs written to:", CSV_DIR, "\n")

# ------------------------------------------------------------
# 12) Figures
# ------------------------------------------------------------
# Pareto envelope
envelope <- extract_envelope(A_S1, x_col = "k_total", y_col = "logLik")

# m0 row
m0_row <- if (length(m0_idx) == 1 && !lattice$failed[m0_idx]) lattice[m0_idx, ] else NULL

# S1.1 Global Frontier
fig1 <- plot_fitcomplexity_cloud(A_S1, m0 = m0_row, envelope = envelope,
                                  title = "S1.1: ARDL Admissible Cloud (fit-complexity plane)")
ggsave(file.path(FIG_DIR, "fig_S1_global_frontier.png"), fig1, width = 10, height = 7, dpi = 300)

# S1.2 IC Tangency Points
fig2 <- plot_ic_tangencies(A_S1, winners = ic_winners, envelope = envelope, m0 = m0_row,
                            title = "S1.2: IC Tangency Points (H0: IC is coordinate selector)")
ggsave(file.path(FIG_DIR, "fig_S1_ic_tangencies.png"), fig2, width = 10, height = 7, dpi = 300)

# S1.3 Informational Domain
fig3 <- plot_informational_domain(A_S1, frontier_df = F020, envelope = envelope, m0 = m0_row,
                                   title = "S1.3: Informational Domain F^(0.20)")
ggsave(file.path(FIG_DIR, "fig_S1_informational_domain.png"), fig3, width = 10, height = 7, dpi = 300)

cat("Figures saved to:", FIG_DIR, "\n")

# ------------------------------------------------------------
# 13) Verification summary
# ------------------------------------------------------------
cat("\n=== S1 VERIFICATION ===\n")
cat("Total grid:       ", n_grid, "\n")
cat("Failed:           ", sum(lattice$failed), "\n")
cat("Estimated:        ", sum(!lattice$failed), "\n")
cat("Admissible (A_S1):", nrow(A_S1), "\n")
cat("F^(0.20) specs:   ", nrow(F020), "\n")
cat("m0 admissible:    ", m0_admissible, "\n")
cat("m0 in F^(0.20):   ", m0_in_F020, "\n")
cat("IC distinct winners:", n_distinct_winners, "/", length(ic_names), "\n")
cat("Theta range F020: [", round(min(theta_frontier), 4), ",",
    round(max(theta_frontier), 4), "]\n")
cat("========================\n")

cat("STAGE_STATUS_HINT: stage=S1 status=complete\n")
cat("\nDONE.\n")
