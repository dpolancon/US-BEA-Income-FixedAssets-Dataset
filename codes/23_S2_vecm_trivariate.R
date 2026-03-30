# ============================================================
# 23_S2_vecm_trivariate.R
#
# S2 — Johansen VECM: trivariate system (m=3)
#       State vector: X_t = (lnY_t, lnK_t, e_t)'
#       e = log(Profshcorp) as proxy for log exploitation rate
#       Cointegration rank: r in {1, 2}
#
# Lattice: p in 1:4, d in {d0,d1,d2,d3}, h in {h0,h1,h2}, r in {1,2}
#          => 96 specifications before triple admissibility gate
#
# Triple admissibility gate: same as 22_S2_vecm_bivariate.R
#
# P8 rotation diagnostic for r=2 specs in Omega_20:
#   e_t = mu + lambda * u_hat_t + dummies
#   lambda < 0 required for canonical rotation (reserve-army prior)
#   Pure diagnostic — no admissibility gate on rotation.
#
# ICs: AIC, BIC, HQ, ICOMP, RICOMP
# Omega_20: bottom 20% of neg2logL among admissible
#
# Uses:
#   - CONFIG          from codes/10_config.R
#   - utilities       from codes/99_utils.R
#   - make_spec_row() from codes/98_ardl_helpers.R
#   - extract_envelope(), plot_*() from 98_ardl_helpers.R
#
# Outputs under: output/CriticalReplication/S2_vecm/
# ============================================================

rm(list = ls())

suppressPackageStartupMessages({
  library(here)
  library(readxl)
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(tsDyn)
  library(urca)
})

# ------------------------------------------------------------
# Load CONFIG + UTILS + HELPERS
# ------------------------------------------------------------
source(here::here("codes", "10_config.R"))
source(here::here("codes", "99_utils.R"))
source(here::here("codes", "98_ardl_helpers.R"))

stopifnot(exists("CONFIG"))

# ------------------------------------------------------------
# CONSTANTS
# ------------------------------------------------------------
M_DIM        <- 3L             # trivariate system
R_RANK_SET   <- 1:2            # cointegration ranks to try
P_LAG_SET    <- 1:4            # VAR lag order
OMEGA_QUANTILE <- 0.20
TOL_UNIT     <- 1e-3
WINDOW_TAG   <- "shaikh_window"
DUMMY_YEARS  <- c(1956L, 1974L, 1980L)

# Deterministic branches
D_BRANCHES <- list(
  d0 = list(include = "none",  LRinclude = "none",  ecdet = "none"),
  d1 = list(include = "none",  LRinclude = "const", ecdet = "const"),
  d2 = list(include = "const", LRinclude = "none",  ecdet = "none"),
  d3 = list(include = "both",  LRinclude = "none",  ecdet = "none")
)

# Historical shock structures
H_SETS <- list(
  h0 = character(0),
  h1 = "d1974",
  h2 = c("d1956", "d1974", "d1980")
)

IC_NAMES <- c("AIC", "BIC", "HQ", "ICOMP", "RICOMP")

# ------------------------------------------------------------
# 0) Data preparation
# ------------------------------------------------------------
df_raw <- readr::read_csv(here::here(CONFIG[["data_shaikh"]]), show_col_types=FALSE)


Py <- as.numeric(df_raw[[CONFIG$p_index]])
p_scale <- Py / 100

df0 <- data.frame(
  year  = as.integer(df_raw[[CONFIG$year_col]]),
  Y_nom = as.numeric(df_raw[[CONFIG$y_nom]]),
  K_nom = as.numeric(df_raw[[CONFIG$k_nom]]),
  e_raw = as.numeric(df_raw[[CONFIG$e_rate]])   # exploitation rate e = pi/(1-pi)
)
df0 <- df0[complete.cases(df0) & df0$year > 0, ]
df0$lnY <- log(df0$Y_nom / p_scale[match(df0$year, as.integer(df_raw[[CONFIG$year_col]]))])
df0$lnK <- log(df0$K_nom / p_scale[match(df0$year, as.integer(df_raw[[CONFIG$year_col]]))])

# State vector uses ln(e) where e = exploitation rate (Profshcorp/(1-Profshcorp))
# CONFIG$e_rate points to "e" column which IS the exploitation rate
df0$e <- log(df0$e_raw)

# Step dummies
for (yy in DUMMY_YEARS) df0[[paste0("d", yy)]] <- as.integer(df0$year >= yy)

# Window
w <- CONFIG$WINDOWS_LOCKED[[WINDOW_TAG]]
df <- df0[df0$year >= w[1] & df0$year <= w[2], ]
df <- df[order(df$year), ]
df <- df[is.finite(df$e), ]   # Drop any NaN from log(0) etc.
T_obs <- nrow(df)

# State matrix
X3 <- as.matrix(df[, c("lnY", "lnK", "e")])
colnames(X3) <- c("lnY", "lnK", "e")

# Shaikh u for overlay
u_shaikh <- as.numeric(df_raw[["u_shaikh"]])[match(df$year, as.integer(df_raw[[CONFIG$year_col]]))]

# ------------------------------------------------------------
# 1) Output directories + log
# ------------------------------------------------------------
EXERCISE_DIR <- here::here(CONFIG$OUT_CR$S2_vecm %||% "output/CriticalReplication/S2_vecm")
CSV_DIR <- file.path(EXERCISE_DIR, "csv")
LOG_DIR <- file.path(EXERCISE_DIR, "logs")
FIG_DIR <- file.path(EXERCISE_DIR, "figures")

dir.create(CSV_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(LOG_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(FIG_DIR, recursive = TRUE, showWarnings = FALSE)

log_path <- file.path(LOG_DIR, "S2_vecm_trivariate_log.txt")
sink(log_path, split = TRUE)
on.exit(try(sink(), silent = TRUE), add = TRUE)

cat("=== S2 VECM Trivariate (m=3, r in {1,2}) ===\n")
cat("Timestamp: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
n_grid <- length(P_LAG_SET) * length(D_BRANCHES) * length(H_SETS) * length(R_RANK_SET)
cat("Lattice:   p=1:", max(P_LAG_SET), " d={", paste(names(D_BRANCHES), collapse = ","),
    "} h={", paste(names(H_SETS), collapse = ","), "} r={", paste(R_RANK_SET, collapse = ","), "}\n")
cat("Total:     ", n_grid, " specs\n")
cat("Window:    ", WINDOW_TAG, " (", min(df$year), "-", max(df$year), ", T=", T_obs, ")\n\n")

# ------------------------------------------------------------
# 2) Main grid sweep with triple admissibility gate
# ------------------------------------------------------------
spec_rows <- list()
u_hat_list <- list()
beta_store <- list()
alpha_store <- list()
n_done <- 0L
n_fail <- 0L
n_admissible <- 0L

cat("Estimating", n_grid, "specifications...\n")
t0 <- Sys.time()

for (p_lag in P_LAG_SET) {
  for (d_name in names(D_BRANCHES)) {
    d <- D_BRANCHES[[d_name]]

    for (h_name in names(H_SETS)) {
      h_vars <- H_SETS[[h_name]]

      for (r_rank in R_RANK_SET) {
        spec_id <- paste0("p", p_lag, "_", d_name, "_", h_name, "_r", r_rank)
        n_done <- n_done + 1L

        result <- tryCatch({
          # Full dummy matrix (same nrow as X3) for both VECM() and ca.jo()
          dum_mat <- if (length(h_vars) > 0) {
            as.matrix(df[, h_vars, drop = FALSE])
          } else {
            NULL
          }

          # ----- Estimate VECM -----
          vecm_lag <- max(0L, p_lag - 1L)

          vecm_fit <- tsDyn::VECM(
            X3,
            lag       = vecm_lag,
            r         = r_rank,
            estim     = "ML",
            include   = d$include,
            LRinclude = d$LRinclude,
            exogen    = dum_mat
          )

          # ===== TRIPLE ADMISSIBILITY GATE =====

          # Gate 1: Convergence
          all_coefs <- unlist(coef(vecm_fit))
          converged <- !any(is.na(all_coefs)) && !any(is.nan(all_coefs))

          # Gate 2: Rank consistency
          K_jo <- max(2L, as.integer(p_lag))
          jo <- urca::ca.jo(X3, type = "trace", ecdet = d$ecdet,
                            K = K_jo, dumvar = dum_mat)
          idx_rk <- M_DIM - r_rank + 1
          rank_ok <- (jo@teststat[idx_rk] > jo@cval[idx_rk, "5pct"])

          # Gate 3: Stability — build companion from VARrep lag columns
          var_coefs <- tsDyn::VARrep(vecm_fit)
          lag_cols <- grep("\\.l[0-9]+$", colnames(var_coefs))
          if (length(lag_cols) == 0) stop("No lag columns in VARrep")
          A_lag <- var_coefs[, lag_cols, drop = FALSE]
          p_var <- as.integer(ncol(A_lag) / M_DIM)
          if (p_var == 1L) {
            eig_mod <- Mod(eigen(A_lag)$values)
          } else {
            n_comp <- M_DIM * p_var
            C_comp <- matrix(0, n_comp, n_comp)
            C_comp[1:M_DIM, ] <- A_lag
            C_comp[(M_DIM + 1):n_comp, 1:(M_DIM * (p_var - 1))] <- diag(M_DIM * (p_var - 1))
            eig_mod <- Mod(eigen(C_comp)$values)
          }
          stable <- all(eig_mod <= 1 + TOL_UNIT)

          admissible <- converged & rank_ok & stable

          # ----- Extract beta, alpha -----
          beta_hat <- as.matrix(tsDyn::coefB(vecm_fit))
          alpha_hat <- as.matrix(tsDyn::coefA(vecm_fit))

          # ----- Log-likelihood & parameters -----
          ll <- as.numeric(logLik(vecm_fit))
          T_eff <- attr(logLik(vecm_fit), "nobs")
          if (is.null(T_eff)) T_eff <- nrow(residuals(vecm_fit))
          k_tot <- length(unlist(coef(vecm_fit)))

          # ICOMP
          vc_for_icomp <- tryCatch(vcov(vecm_fit), error = function(e) NULL)
          sw_for_icomp <- NULL

          row <- make_spec_row(
            p = p_lag, q = d_name, case = d_name, s = h_name,
            logLik = ll, k_total = k_tot, T_eff = T_eff,
            vcov_mat = vc_for_icomp, sandwich_mat = sw_for_icomp
          )

          # ----- u_hat from first cointegrating vector -----
          coint_resid <- as.numeric(X3 %*% beta_hat[, 1])
          u_hat <- exp(coint_resid - mean(coint_resid))

          # ----- s_K: system capital memory share -----
          s_K <- tryCatch({
            gamma_norms <- numeric(0)
            gamma_k_norms <- numeric(0)
            if (vecm_lag > 0) {
              for (eq_idx in 1:M_DIM) {
                eq_coefs <- coef(vecm_fit)[[eq_idx]]
                all_lag <- grep("^(lnY|lnK|e)\\.l[0-9]", names(eq_coefs), value = TRUE)
                k_lag   <- grep("^lnK\\.l[0-9]", names(eq_coefs), value = TRUE)
                if (length(all_lag) > 0) gamma_norms <- c(gamma_norms, eq_coefs[all_lag]^2)
                if (length(k_lag) > 0)   gamma_k_norms <- c(gamma_k_norms, eq_coefs[k_lag]^2)
              }
            }
            if (sum(gamma_norms) > 0) sqrt(sum(gamma_k_norms)) / sqrt(sum(gamma_norms)) else NA_real_
          }, error = function(e) NA_real_)

          # Append extras
          row$admissible    <- admissible
          row$converged     <- converged
          row$rank_ok       <- rank_ok
          row$stable        <- stable
          row$boundsJo_stat <- jo@teststat[idx_rk]
          row$boundsJo_cval <- jo@cval[idx_rk, "5pct"]
          row$max_eig_mod   <- max(eig_mod)
          row$theta_hat     <- -as.numeric(beta_hat[2, 1])
          row$alpha_y       <- as.numeric(alpha_hat[1, 1])
          row$alpha_k       <- as.numeric(alpha_hat[2, 1])
          row$alpha_e       <- as.numeric(alpha_hat[3, 1])
          row$s_K           <- s_K
          row$m             <- M_DIM
          row$r             <- r_rank
          row$d             <- d_name
          row$h             <- h_name
          row$failed        <- FALSE
          row$error_msg     <- ""

          list(row = row, u_hat = u_hat, beta = beta_hat, alpha = alpha_hat)

        }, error = function(e) {
          row <- data.frame(
            p = p_lag, q = d_name, case = d_name, s = h_name,
            neg2logL = NA_real_, k_total = NA_integer_, T_eff = NA_real_,
            logLik = NA_real_, AIC = NA_real_, BIC = NA_real_,
            HQ = NA_real_, AICc = NA_real_,
            ICOMP = NA_real_, RICOMP = NA_real_,
            admissible = FALSE, converged = FALSE,
            rank_ok = FALSE, stable = FALSE,
            boundsJo_stat = NA_real_, boundsJo_cval = NA_real_,
            max_eig_mod = NA_real_,
            theta_hat = NA_real_, alpha_y = NA_real_, alpha_k = NA_real_,
            alpha_e = NA_real_,
            s_K = NA_real_, m = M_DIM, r = r_rank,
            d = d_name, h = h_name,
            failed = TRUE, error_msg = conditionMessage(e),
            stringsAsFactors = FALSE
          )
          list(row = row, u_hat = rep(NA_real_, T_obs), beta = NULL, alpha = NULL)
        })

        spec_rows[[n_done]] <- result$row
        u_hat_list[[spec_id]] <- result$u_hat
        if (!is.null(result$beta)) beta_store[[spec_id]] <- result$beta
        if (!is.null(result$alpha)) alpha_store[[spec_id]] <- result$alpha

        if (isTRUE(result$row$failed)) n_fail <- n_fail + 1L
        if (isTRUE(result$row$admissible)) n_admissible <- n_admissible + 1L

        if (n_done %% CONFIG$HEARTBEAT_EVERY == 0 || n_done == n_grid) {
          cat(sprintf("  [%d/%d] done | %d failed | %d admissible | elapsed %.1fs\n",
                      n_done, n_grid, n_fail, n_admissible,
                      as.numeric(Sys.time() - t0, units = "secs")))
        }
      }
    }
  }
}

# Combine
lattice_m3 <- bind_rows(spec_rows)
lattice_m3$spec_idx <- seq_len(nrow(lattice_m3))
lattice_m3$spec_id <- paste0("p", lattice_m3$p, "_", lattice_m3$d, "_", lattice_m3$h, "_r", lattice_m3$r)

cat("\nGrid complete:", nrow(lattice_m3), "specs |",
    sum(lattice_m3$failed), "failed |",
    sum(lattice_m3$admissible, na.rm = TRUE), "admissible\n")

# ------------------------------------------------------------
# 3) Admissible set
# ------------------------------------------------------------
A_S2_m3 <- lattice_m3[lattice_m3$admissible & !lattice_m3$failed, ]
cat("A_S2_m3 (admissible):", nrow(A_S2_m3), "specs\n")

if (nrow(A_S2_m3) == 0) {
  cat("WARNING: No admissible m=3 specs!\n")
  safe_write_csv(lattice_m3, file.path(CSV_DIR, "S2_m3_lattice_full.csv"))
  cat("STAGE_STATUS_HINT: stage=S2_m3 status=no_admissible\n")
  cat("DONE (no admissible specs).\n")
  sink()
  quit(save = "no", status = 0)
}

cat("\nGate diagnostics (m=3):\n")
cat("  Convergence failures:", sum(!lattice_m3$converged & !lattice_m3$failed, na.rm = TRUE), "\n")
cat("  Rank test failures: ", sum(!lattice_m3$rank_ok & !lattice_m3$failed, na.rm = TRUE), "\n")
cat("  Stability failures: ", sum(!lattice_m3$stable & !lattice_m3$failed, na.rm = TRUE), "\n")

# Break down by rank
for (rr in R_RANK_SET) {
  sub <- A_S2_m3[A_S2_m3$r == rr, ]
  cat(sprintf("  r=%d admissible: %d\n", rr, nrow(sub)))
}

# ------------------------------------------------------------
# 4) Omega_20 (bottom 20% of neg2logL among admissible)
# ------------------------------------------------------------
q20_m3 <- quantile(A_S2_m3$neg2logL, probs = OMEGA_QUANTILE, na.rm = TRUE)
Omega_20_m3 <- A_S2_m3[!is.na(A_S2_m3$neg2logL) & A_S2_m3$neg2logL <= q20_m3, ]
cat("Omega_20_m3:", nrow(Omega_20_m3), "specs (neg2logL <=", round(q20_m3, 2), ")\n")

cat("\nRank distribution in Omega_20_m3:\n")
print(table(Omega_20_m3$r))

# ------------------------------------------------------------
# 5) IC winners
# ------------------------------------------------------------
ic_winners_m3 <- list()
for (ic in IC_NAMES) {
  vals <- A_S2_m3[[ic]]
  if (all(is.na(vals))) {
    ic_winners_m3[[ic]] <- A_S2_m3[0, ]
    next
  }
  best_idx <- which.min(vals)
  ic_winners_m3[[ic]] <- A_S2_m3[best_idx, , drop = FALSE]
  ww <- ic_winners_m3[[ic]]
  cat(sprintf("  %15s winner: p=%d d=%-2s h=%-2s r=%d | %s=%.2f | theta=%.4f\n",
              ic, ww$p, ww$d, ww$h, ww$r, ic, ww[[ic]], ww$theta_hat))
}

winner_specs <- sapply(ic_winners_m3, function(ww) {
  if (nrow(ww) == 0) return(NA_character_)
  paste(ww$p, ww$d, ww$h, ww$r, sep = "_")
})
n_distinct_winners <- length(unique(na.omit(winner_specs)))
cat("\nIC DIAGNOSTIC (m=3):", n_distinct_winners, "distinct winner(s) across",
    length(IC_NAMES), "criteria\n")
if (n_distinct_winners == 1) {
  cat("  WARNING: All ICs select same m=3 spec -- H0 visual argument weakens\n")
}

# Do IC winners concentrate in m=3 r=1 or r=2?
ic_winner_ranks <- sapply(ic_winners_m3, function(ww) if (nrow(ww) > 0) ww$r else NA_integer_)
cat("IC winner ranks:", paste(ic_winner_ranks, collapse = ", "), "\n")

# ------------------------------------------------------------
# 6) Tracked objects across Omega_20
# ------------------------------------------------------------
beta_k_vals <- Omega_20_m3$theta_hat[is.finite(Omega_20_m3$theta_hat)]
cat("\nTheta (beta_k) across Omega_20_m3:\n")
if (length(beta_k_vals) > 0) {
  cat("  range:", round(range(beta_k_vals), 4), "\n")
  cat("  mean: ", round(mean(beta_k_vals), 4), "\n")
}

# u_hat band
u_mat_omega <- do.call(cbind, u_hat_list[Omega_20_m3$spec_id])
if (!is.null(u_mat_omega) && ncol(u_mat_omega) > 0) {
  u_med_m3   <- apply(u_mat_omega, 1, median, na.rm = TRUE)
  u_lower_m3 <- apply(u_mat_omega, 1, min, na.rm = TRUE)
  u_upper_m3 <- apply(u_mat_omega, 1, max, na.rm = TRUE)
} else {
  u_med_m3 <- u_lower_m3 <- u_upper_m3 <- rep(NA_real_, T_obs)
}

u_band_m3 <- data.frame(
  year    = df$year,
  u_med   = u_med_m3,
  u_lower = u_lower_m3,
  u_upper = u_upper_m3,
  u_shaikh = u_shaikh
)

cat("\nUtilization band Omega_20_m3:\n")
cat("  mean(u_med):", round(mean(u_med_m3, na.rm = TRUE), 4), "\n")
cat("  mean band width:", round(mean(u_upper_m3 - u_lower_m3, na.rm = TRUE), 4), "\n")

cat("\nAlpha across Omega_20_m3:\n")
cat("  alpha_y range:", round(range(Omega_20_m3$alpha_y, na.rm = TRUE), 4), "\n")
cat("  alpha_k range:", round(range(Omega_20_m3$alpha_k, na.rm = TRUE), 4), "\n")
cat("  alpha_e range:", round(range(Omega_20_m3$alpha_e, na.rm = TRUE), 4), "\n")

cat("\nDeterministic branch in Omega_20_m3:\n")
print(table(Omega_20_m3$d))
cat("\nShock structure in Omega_20_m3:\n")
print(table(Omega_20_m3$h))

# ------------------------------------------------------------
# 7) P8 Rotation Diagnostic (r=2 specs in Omega_20 only)
# ------------------------------------------------------------
cat("\n=== P8 ROTATION DIAGNOSTIC ===\n")

Omega_20_m3_r2 <- Omega_20_m3[Omega_20_m3$r == 2, ]
cat("Omega_20_m3 with r=2:", nrow(Omega_20_m3_r2), "specs\n")

rotation_results <- list()
if (nrow(Omega_20_m3_r2) > 0) {
  for (i in seq_len(nrow(Omega_20_m3_r2))) {
    spec <- Omega_20_m3_r2[i, ]
    rot <- tryCatch({
      u_hat_spec <- u_hat_list[[spec$spec_id]]
      if (any(!is.finite(u_hat_spec))) stop("non-finite u_hat")

      # Rotation prior regression: e_t = mu + lambda * u_hat_t + dummies
      rot_df <- data.frame(
        e = df$e,
        u_hat = u_hat_spec
      )
      # Add available dummies from spec's h set
      h_vars_rot <- H_SETS[[spec$h]]
      for (dv in h_vars_rot) rot_df[[dv]] <- df[[dv]]

      fml_str <- "e ~ u_hat"
      if (length(h_vars_rot) > 0) {
        fml_str <- paste0(fml_str, " + ", paste(h_vars_rot, collapse = " + "))
      }
      lm_rot <- lm(as.formula(fml_str), data = rot_df)

      lambda     <- coef(lm_rot)["u_hat"]
      lambda_se  <- sqrt(vcov(lm_rot)["u_hat", "u_hat"])
      lambda_t   <- lambda / lambda_se
      lambda_p   <- pnorm(lambda_t)  # one-tailed p-value, H1: lambda < 0

      data.frame(
        m = spec$m, r = spec$r, p = spec$p,
        d = spec$d, h = spec$h, spec_id = spec$spec_id,
        lambda = as.numeric(lambda),
        lambda_se = as.numeric(lambda_se),
        lambda_t = as.numeric(lambda_t),
        lambda_p = as.numeric(lambda_p),
        sign_consistent = as.numeric(lambda) < 0,
        stringsAsFactors = FALSE
      )
    }, error = function(e) {
      data.frame(
        m = spec$m, r = spec$r, p = spec$p,
        d = spec$d, h = spec$h, spec_id = spec$spec_id,
        lambda = NA_real_, lambda_se = NA_real_,
        lambda_t = NA_real_, lambda_p = NA_real_,
        sign_consistent = NA,
        stringsAsFactors = FALSE
      )
    })
    rotation_results[[i]] <- rot
  }

  rotation_df <- bind_rows(rotation_results)
  safe_write_csv(rotation_df, file.path(CSV_DIR, "S2_rotation_check.csv"))

  # Report
  n_sign_ok <- sum(rotation_df$sign_consistent, na.rm = TRUE)
  cat("\nRotation diagnostic results:\n")
  cat("  r=2 specs tested:", nrow(rotation_df), "\n")
  cat("  lambda < 0 (sign consistent):", n_sign_ok, "\n")
  cat("  lambda range:", round(range(rotation_df$lambda, na.rm = TRUE), 4), "\n")
  cat("  lambda_t range:", round(range(rotation_df$lambda_t, na.rm = TRUE), 4), "\n")
} else {
  cat("  No r=2 specs in Omega_20_m3 -- rotation diagnostic skipped\n")
  # Write empty rotation CSV so downstream consumers don't CONTRACT ERROR
  rotation_df <- data.frame(
    spec_id = character(), p = integer(), d_label = character(),
    h_label = character(), r = integer(),
    lambda = numeric(), lambda_t = numeric(), lambda_p = numeric(),
    sign_consistent = logical(),
    stringsAsFactors = FALSE
  )
  safe_write_csv(rotation_df, file.path(CSV_DIR, "S2_rotation_check.csv"))
}

# ------------------------------------------------------------
# 8) CSV exports
# ------------------------------------------------------------
safe_write_csv(lattice_m3,   file.path(CSV_DIR, "S2_m3_lattice_full.csv"))
safe_write_csv(A_S2_m3,      file.path(CSV_DIR, "S2_m3_admissible.csv"))
safe_write_csv(Omega_20_m3,  file.path(CSV_DIR, "S2_m3_omega20.csv"))
safe_write_csv(u_band_m3,    file.path(CSV_DIR, "S2_m3_u_band.csv"))
cat("\nCSVs written to:", CSV_DIR, "\n")

# ------------------------------------------------------------
# 9) Figures (parallel to S1.1-S1.3)
# ------------------------------------------------------------
envelope_m3 <- extract_envelope(A_S2_m3, x_col = "k_total", y_col = "logLik")

fig1 <- plot_fitcomplexity_cloud(
  A_S2_m3, envelope = envelope_m3,
  title = "S2.1: VECM m=3 Admissible Cloud (fit-complexity)"
)
ggsave(file.path(FIG_DIR, "fig_S2_global_frontier_m3.pdf"),
       fig1, width = 7, height = 5, dpi = 300)

fig2 <- plot_ic_tangencies(
  A_S2_m3, winners = ic_winners_m3, envelope = envelope_m3,
  title = "S2.2: IC Tangency Points m=3 (H0: IC is coordinate selector)"
)
ggsave(file.path(FIG_DIR, "fig_S2_ic_tangencies_m3.pdf"),
       fig2, width = 7, height = 5, dpi = 300)

fig3 <- plot_informational_domain(
  A_S2_m3, frontier_df = Omega_20_m3, envelope = envelope_m3,
  title = "S2.3: Informational Domain Omega_20 (m=3)"
)
ggsave(file.path(FIG_DIR, "fig_S2_informational_domain_m3.pdf"),
       fig3, width = 7, height = 5, dpi = 300)

cat("Figures saved to:", FIG_DIR, "\n")

# ------------------------------------------------------------
# 10) Verification summary
# ------------------------------------------------------------
cat("\n=== S2 TRIVARIATE (m=3) VERIFICATION ===\n")
cat("Total grid:       ", n_grid, "\n")
cat("Failed:           ", sum(lattice_m3$failed), "\n")
cat("Estimated:        ", sum(!lattice_m3$failed), "\n")
cat("Admissible (A_S2):", nrow(A_S2_m3), "\n")
cat("Omega_20 specs:   ", nrow(Omega_20_m3), "\n")
cat("IC distinct winners:", n_distinct_winners, "/", length(IC_NAMES), "\n")
if (length(beta_k_vals) > 0) {
  cat("Theta range Omega_20: [", round(min(beta_k_vals), 4), ",",
      round(max(beta_k_vals), 4), "]\n")
}
if (nrow(Omega_20_m3_r2) > 0 && exists("rotation_df")) {
  cat("Rotation sign-consistent:", sum(rotation_df$sign_consistent, na.rm = TRUE),
      "/", nrow(rotation_df), "\n")
}
cat("========================================\n")
cat("STAGE_STATUS_HINT: stage=S2_m3 status=complete\n")
cat("Omega_20_m3 non-empty:", nrow(Omega_20_m3) > 0, "\n")
cat("\nDONE.\n")
