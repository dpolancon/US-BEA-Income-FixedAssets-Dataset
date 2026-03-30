# ============================================================
# 20_S0_shaikh_faithful.R
#
# S0 — Shaikh faithful ARDL(2,4) replication + five-case comparison
#
# Fixed-spec replication at m0 = (p=2, q=4, case=3, s=s3).
# Produces three canonical public CSVs:
#   - S0_spec_report.csv         (contest table: all 5 cases)
#   - S0_fivecase_summary.csv    (coefficient summary)
#   - S0_utilization_series.csv  (u_hat + yp_hat annual series)
#
# Uses:
#   - CONFIG from codes/10_config.R
#   - utilities from codes/99_utils.R
#
# Outputs under: output/CriticalReplication/S0_faithful/
# Manifest: written by 24_manifest_runner.R only (no local append)
# ============================================================

rm(list = ls())

suppressPackageStartupMessages({
  library(here)
  library(readxl)
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(stringr)
  library(ARDL)
  library(ggplot2)
})

# ------------------------------------------------------------
# Load CONFIG + UTILS (repo-native)
# ------------------------------------------------------------
source(here::here("codes", "10_config.R"))
source(here::here("codes", "99_utils.R"))

stopifnot(exists("CONFIG"))
stopifnot(is.list(CONFIG))

# ------------------------------------------------------------
# LOCKED TOGGLES (Study A)
# ------------------------------------------------------------
WINDOW_TAG <- "shaikh_window"
ORDER      <- c(2, 4)     # (p,q) locked
CASES      <- 1:5         # PSS cases 1..5
EXACT_TEST <- FALSE       # FALSE = asymptotic; TRUE = in-sample (exact=TRUE)

# Admissibility for t-bounds robustness labeling (your lockdown)
T_BOUNDS_ADMISSIBLE_CASES <- c(1, 3, 5)

# F-gate alpha (used only for flagging; p-values still reported)
F_GATE_ALPHA <- 0.10

# Step dummies (kept as in your current script)
DUMMY_YEARS <- c(1956L, 1974L, 1980L)

# ------------------------------------------------------------
# Helpers (local)
# ------------------------------------------------------------
make_step_dummies <- function(df, years) {
  for (yy in years) df[[paste0("d", yy)]] <- as.integer(df$year >= yy)
  df
}

rebase_to_year_to_100 <- function(p_vec, year_vec, base_year, strict = TRUE) {
  idx <- which(year_vec == base_year)
  if (length(idx) != 1) {
    msg <- paste0("Base year ", base_year, " not uniquely present in price index series.")
    if (strict) stop(msg) else {
      warning(msg, " Falling back to first observation in provided series.")
      idx <- 1
    }
  }
  p0 <- p_vec[idx]
  if (!is.finite(p0) || p0 <= 0) stop("Invalid base-year price index value.")
  100 * (p_vec / p0)
}

extract_bt <- function(bt_obj) {
  out <- list(stat = NA_real_, pval = NA_real_)
  if (is.list(bt_obj)) {
    if (!is.null(bt_obj$statistic)) out$stat <- suppressWarnings(as.numeric(bt_obj$statistic))
    if (!is.null(bt_obj$p.value))   out$pval <- suppressWarnings(as.numeric(bt_obj$p.value))
  }
  out
}

# stars helper: prefer your utils add_stars(); fallback local
stars_from_p <- function(p) {
  if (!is.finite(p)) return("")
  if (p <= 0.01) return("***")
  if (p <= 0.05) return("**")
  if (p <= 0.10) return("*")
  ""
}

# LR multipliers + scaled LR dummy multipliers via delta method
# ------------------------------------------------------------------
# multipliers() omits fixed regressors (dummies after "|"), so we
# compute: LR(d_j) = gamma_j / (1 - phi_1 - phi_2 - ...)
# SE via delta method:
#   g = [ 1/den,  gamma_j/den^2, gamma_j/den^2, ... ] (gradient)
#   SE = sqrt( g' V_sub g )   where V_sub is vcov submatrix for
#                              {gamma_j, phi_1, phi_2, ...}
# ------------------------------------------------------------------
get_lr_table_with_scaled_dummies <- function(fit_ardl, lnY_name = "lnY", dummy_names = character()) {
  lr_mult <- ARDL::multipliers(fit_ardl, type = "lr")

  coefs <- coef(fit_ardl)
  # AR lag coefficient names  e.g. L(lnY, 1), L(lnY, 2)
  phi_names <- grep(paste0("^L\\(", lnY_name, ","), names(coefs), value = TRUE)
  # denominator: 1 - sum phi_i
  den <- 1 - sum(coefs[phi_names])

  dummy_table <- NULL
  if (length(dummy_names)) {
    gamma_sr  <- coefs[dummy_names]          # SR dummy coefficients
    dummy_lr  <- gamma_sr / den              # LR multipliers

    vc <- vcov(fit_ardl)

    se_lr <- numeric(length(dummy_names))
    for (j in seq_along(dummy_names)) {
      dname   <- dummy_names[j]
      gamma_j <- coefs[dname]

      # indices in vcov for {gamma_j, phi_1, phi_2, ...}
      param_names <- c(dname, phi_names)
      idx <- match(param_names, names(coefs))

      # gradient vector  ∂LR/∂theta
      grad      <- numeric(length(param_names))
      grad[1]   <- 1 / den                  # ∂/∂gamma_j
      grad[-1]  <- gamma_j / den^2          # ∂/∂phi_i  (each AR lag)

      V_sub     <- vc[idx, idx, drop = FALSE]
      se_lr[j]  <- sqrt(as.numeric(t(grad) %*% V_sub %*% grad))
    }

    t_lr <- as.numeric(dummy_lr) / se_lr
    p_lr <- 2 * pt(abs(t_lr), df = df.residual(fit_ardl), lower.tail = FALSE)

    dummy_table <- data.frame(
      Term         = dummy_names,
      Estimate     = as.numeric(dummy_lr),
      `Std. Error` = se_lr,
      `t value`    = t_lr,
      `Pr(>|t|)`   = p_lr,
      stringsAsFactors = FALSE
    )
    names(dummy_table) <- names(lr_mult)
  }

  lr_full_table <- if (!is.null(dummy_table)) rbind(lr_mult, dummy_table) else lr_mult
  list(lr_full_table = lr_full_table, den = den)
}

extract_lr_row <- function(lr_full, term) {
  if (is.null(lr_full) || !("Term" %in% names(lr_full))) return(list(est = NA_real_, p = NA_real_))
  rr <- lr_full[lr_full$Term == term, , drop = FALSE]
  if (nrow(rr) == 0) return(list(est = NA_real_, p = NA_real_))
  p_col <- intersect(c("Pr(>|t|)", "Pr...t..", "p.value", "p_value"), names(rr))[1]
  list(
    est = suppressWarnings(as.numeric(rr$Estimate[1])),
    p = if (!is.na(p_col)) suppressWarnings(as.numeric(rr[[p_col]][1])) else NA_real_
  )
}

# Extract alpha (speed) from UECM coefficient on L(lnY,1)
extract_alpha_from_uecm <- function(fit_ardl, lnY_name = "lnY") {
  uecm_model <- ARDL::uecm(fit_ardl)
  uecm_coef <- tryCatch(summary(uecm_model)$coefficients, error = function(e) NULL)
  if (is.null(uecm_coef)) return(NA_real_)
  rr <- grep(paste0("^L\\(", lnY_name, ", 1\\)$"), rownames(uecm_coef), value = TRUE)
  if (length(rr) == 1) return(as.numeric(uecm_coef[rr, "Estimate"]))
  NA_real_
}

# Build u and lnY^p from LR object:
# lnY^p = a + theta lnK + sum_j lr_dummy_j * d_j
compute_u_from_lr <- function(df, lnY_name, lnK_name, lr_full, dummy_names) {
  a_lr_vec <- lr_full$Estimate[lr_full$Term == "(Intercept)"]
  a_lr <- if (length(a_lr_vec) > 0 && is.finite(a_lr_vec[1])) a_lr_vec[1] else 0

  theta_lr <- lr_full$Estimate[lr_full$Term == lnK_name]

  dummy_coef <- if (length(dummy_names)) lr_full$Estimate[match(dummy_names, lr_full$Term)] else numeric(0)
  dummy_effect <- if (length(dummy_names)) rowSums(df[dummy_names] * dummy_coef) else 0

  lnY  <- df[[lnY_name]]
  lnK  <- df[[lnK_name]]
  lnYp <- a_lr + theta_lr * lnK + dummy_effect
  u    <- exp(lnY - lnYp)

  list(u = u, lnYp = lnYp, intercept = a_lr, theta = theta_lr)
}

# ------------------------------------------------------------
# 0) Load dataset (CONFIG) + build deflator base 2011 only
# ------------------------------------------------------------
df_raw <- readr::read_csv(here::here(CONFIG$data_shaikh))
df_raw <- df_raw |> rename(u_shaikh = uK)
stopifnot(all(c(CONFIG$year_col, CONFIG$y_nom, CONFIG$k_nom, CONFIG$p_index) %in% names(df_raw)))

# ledger for p rebase (fail fast)
p_ledger <- df_raw |>
  transmute(
    year  = as.integer(.data[[CONFIG$year_col]]),
    p_raw = as.numeric(.data[[CONFIG$p_index]])
  ) |>
  filter(is.finite(year), is.finite(p_raw), p_raw > 0) |>
  arrange(year)

stopifnot(any(p_ledger$year == 2005L))

p_ledger <- p_ledger |>
  mutate(p2005 = rebase_to_year_to_100(p_raw, year, 2005L, strict = TRUE)) |>
  select(year, p2005)

df0 <- df_raw |>
  transmute(
    year  = as.integer(.data[[CONFIG$year_col]]),
    Y_nom = as.numeric(.data[[CONFIG$y_nom]]),
    K_nom = as.numeric(.data[[CONFIG$k_nom]]),
    u_shaikh = {
      if (!is.null(CONFIG$u_shaikh) && CONFIG$u_shaikh %in% names(df_raw)) {
        as.numeric(.data[[CONFIG$u_shaikh]])
      } else if ("u_shaikh" %in% names(df_raw)) {
        as.numeric(.data[["u_shaikh"]])
      } else {
        NA_real_
      }
    }
  ) |>
  filter(is.finite(year), is.finite(Y_nom), is.finite(K_nom)) |>
  arrange(year) |>
  left_join(p_ledger, by = "year")

stopifnot(all(is.finite(df0$p2005)))

# ------------------------------------------------------------
# 1) Window lock
# ------------------------------------------------------------
w <- CONFIG$WINDOWS_LOCKED[[WINDOW_TAG]]
stopifnot(!is.null(w), length(w) == 2)

WINDOW_START <- as.integer(w[1])
WINDOW_END   <- as.integer(w[2])

df0 <- df0 |>
  filter(year >= w[1], year <= w[2]) |>
  arrange(year)

# ------------------------------------------------------------
# 2) Output dirs + log sink (CONFIG)
# ------------------------------------------------------------
EXERCISE_DIR <- here::here(CONFIG$OUT_CR$S0_faithful %||% "output/CriticalReplication/S0_faithful")
CSV_DIR <- file.path(EXERCISE_DIR, "csv")
LOG_DIR <- file.path(EXERCISE_DIR, "logs")
FIG_DIR <- file.path(EXERCISE_DIR, "figures")

dir.create(CSV_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(LOG_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(FIG_DIR, recursive = TRUE, showWarnings = FALSE)

log_path <- file.path(LOG_DIR, paste0("SHAIKH_ARDL_replication_log_", WINDOW_TAG, ".txt"))
sink(log_path, split = TRUE)
on.exit(try(sink(), silent = TRUE), add = TRUE)

cat("=== Shaikh ARDL replication — CASE TOGGLE (Study A) ===\n")
cat("Timestamp: ", now_stamp(), "\n", sep = "")
cat("Window:    ", WINDOW_TAG, " (", min(df0$year), "-", max(df0$year), ")\n", sep = "")
cat("Order:     (p,q) = (", paste(ORDER, collapse = ","), ")\n", sep = "")
cat("Cases:     ", paste(CASES, collapse = ","), "\n", sep = "")
cat("Bounds:    exact=", EXACT_TEST, " (FALSE=asymptotic; TRUE=in-sample)\n\n", sep = "")

# ------------------------------------------------------------
# 3) Dummies + build real logs (base 2011 only)
# ------------------------------------------------------------
df0 <- make_step_dummies(df0, DUMMY_YEARS)
dummy_names <- paste0("d", DUMMY_YEARS)

df <- df0 |>
  mutate(
    p = p2005,
    p_scale = p / 100,
    Y_real  = Y_nom / p_scale,
    K_real  = K_nom / p_scale,
    lnY     = log(Y_real),
    lnK     = log(K_real)
  )

# ------------------------------------------------------------
# 4) Run one CASE (bounded tests + LR + u)
# ------------------------------------------------------------
run_one_case <- function(df, case_id, order, dummy_names, exact_test) {
  df_ts <- ts(df |> select(all_of(c("lnY", "lnK", dummy_names))),
              start = min(df$year), frequency = 1)

  # Case-appropriate ARDL formula:
  #   Case 1: no intercept, no trend
  #   Cases 2-3: intercept, no trend (standard)
  #   Cases 4-5: intercept + trend (trend as fixed regressor)
  dum_str <- paste(dummy_names, collapse = " + ")
  if (case_id == 1L) {
    fml <- as.formula(paste0("lnY ~ -1 + lnK | ", dum_str))
  } else if (case_id %in% c(4L, 5L)) {
    fml <- as.formula(paste0("lnY ~ lnK | trend(lnY) + ", dum_str))
  } else {
    fml <- as.formula(paste0("lnY ~ lnK | ", dum_str))
  }
  fit <- ARDL::ardl(formula = fml, data = df_ts, order = order)

  # F-bounds test (always applicable)
  bt_f <- ARDL::bounds_f_test(fit, case = case_id, alpha = 0.05, pvalue = TRUE, exact = exact_test)

  # t-bounds test (not applicable for cases 2, 4)
  bt_t <- tryCatch(
    ARDL::bounds_t_test(fit, case = case_id, alpha = 0.05, pvalue = TRUE, exact = exact_test),
    error = function(e) list(statistic = NA_real_, p.value = NA_real_)
  )

  bF <- extract_bt(bt_f)
  bT <- extract_bt(bt_t)

  # LR multipliers + LR dummy scaling
  lr_pack <- get_lr_table_with_scaled_dummies(fit, lnY_name = "lnY", dummy_names = dummy_names)
  lr_full <- lr_pack$lr_full_table

  theta <- extract_lr_row(lr_full, "lnK")
  intercept <- extract_lr_row(lr_full, "(Intercept)")
  alpha_hat <- extract_alpha_from_uecm(fit, lnY_name = "lnY")

  # Recover utilization from LR relation
  series <- compute_u_from_lr(df, "lnY", "lnK", lr_full, dummy_names)

  # For Cases 4-5, add trend component to capacity benchmark
  if (case_id %in% c(4L, 5L)) {
    coefs <- coef(fit)
    trend_name <- grep("^trend", names(coefs), value = TRUE)
    if (length(trend_name) > 0) {
      trend_sr <- coefs[trend_name[1]]
      trend_lr <- trend_sr / lr_pack$den
      trend_vals <- seq(0, nrow(df) - 1)
      series$lnYp <- series$lnYp + trend_lr * trend_vals
      series$u <- exp(df$lnY - series$lnYp)
    }
  }

  list(
    case_id = case_id,
    fml     = fml,
    fit     = fit,
    bt_f    = bF,
    bt_t    = bT,
    lr_full = lr_full,
    theta   = theta,
    intercept = intercept,
    alpha_hat = alpha_hat,
    u = series$u,
    lnYp = series$lnYp
  )
}

# ------------------------------------------------------------
# 5) Execute all cases
# ------------------------------------------------------------
results <- lapply(CASES, function(cc) {
  cat("------------------------------------------------------------\n")
  cat("CASE ", cc, " | order=", paste(ORDER, collapse=","), " | exact=", EXACT_TEST, "\n", sep="")
  tryCatch({
    out <- run_one_case(df, case_id = cc, order = ORDER, dummy_names = dummy_names, exact_test = EXACT_TEST)
    cat("Formula: ", deparse(out$fml), "\n", sep="")
    print(summary(out$fit))
    cat("\nBounds F:\n"); print(ARDL::bounds_f_test(out$fit, case = cc, alpha = 0.05, pvalue = TRUE, exact = EXACT_TEST))
    bt_t_disp <- tryCatch(
      ARDL::bounds_t_test(out$fit, case = cc, alpha = 0.05, pvalue = TRUE, exact = EXACT_TEST),
      error = function(e) NULL
    )
    if (!is.null(bt_t_disp)) {
      cat("\nBounds t:\n"); print(bt_t_disp)
    } else {
      cat("\nBounds t: not applicable for case ", cc, "\n")
    }
    cat("\nTheta (LR lnK): ", signif(out$theta$est, 6), " | p=", signif(out$theta$p, 6), "\n", sep="")
    cat("Alpha (UECM L(lnY,1)): ", signif(out$alpha_hat, 6), "\n", sep="")
    out
  }, error = function(e) {
    cat("CASE ", cc, " FAILED: ", conditionMessage(e), "\n")
    list(
      case_id   = cc,
      failed    = TRUE,
      error_msg = conditionMessage(e),
      fml       = NA,
      fit       = NULL,
      bt_f      = list(stat = NA_real_, pval = NA_real_),
      bt_t      = list(stat = NA_real_, pval = NA_real_),
      theta     = list(est = NA_real_, p = NA_real_),
      intercept = list(est = NA_real_, p = NA_real_),
      alpha_hat = NA_real_,
      u         = rep(NA_real_, nrow(df)),
      lnYp      = rep(NA_real_, nrow(df)),
      lr_full   = NULL
    )
  })
})

# ------------------------------------------------------------
# 6) Build contest table (LEVELS, not deltas) — ALL cases
# ------------------------------------------------------------
contest <- tibble(
  window_tag = WINDOW_TAG,
  order_p = ORDER[1],
  order_q = ORDER[2],
  exact_test = EXACT_TEST,
  case_id = sapply(results, `[[`, "case_id"),
  failed  = sapply(results, function(x) isTRUE(x$failed)),

  boundsF_stat = sapply(results, function(x) x$bt_f$stat),
  boundsF_p    = sapply(results, function(x) x$bt_f$pval),

  boundsT_stat = sapply(results, function(x) x$bt_t$stat),
  boundsT_p    = sapply(results, function(x) x$bt_t$pval),

  theta_hat    = sapply(results, function(x) x$theta$est),
  theta_p      = sapply(results, function(x) x$theta$p),

  alpha_hat    = sapply(results, function(x) x$alpha_hat),

  # Admissibility / robustness flags (failed cases are not admissible)
  F_pass = if_else(!failed & !is.na(boundsF_p), boundsF_p <= F_GATE_ALPHA, FALSE),
  t_admissible = case_id %in% T_BOUNDS_ADMISSIBLE_CASES & !failed,
  t_pass_10 = if_else(t_admissible & !is.na(boundsT_p), boundsT_p <= 0.10, NA),
  t_pass_05 = if_else(t_admissible & !is.na(boundsT_p), boundsT_p <= 0.05, NA),
  t_pass_01 = if_else(t_admissible & !is.na(boundsT_p), boundsT_p <= 0.01, NA)
) |>
  mutate(
    boundsF_stars = map_chr(boundsF_p, ~ if (is.na(.x)) "" else stars_from_p(.x)),
    boundsT_stars = if_else(t_admissible, map_chr(boundsT_p, ~ if (is.na(.x)) "" else stars_from_p(.x)), ""),
    theta_stars   = map_chr(theta_p, ~ if (is.na(.x)) "" else stars_from_p(.x)),

    # Legend robustness stars: only meaningful if F_pass AND t_admissible
    robust_star = case_when(
      F_pass & t_admissible & !is.na(boundsT_p) & boundsT_p <= 0.01 ~ "***",
      F_pass & t_admissible & !is.na(boundsT_p) & boundsT_p <= 0.05 ~ "**",
      F_pass & t_admissible & !is.na(boundsT_p) & boundsT_p <= 0.10 ~ "*",
      TRUE ~ ""
    )
  )

contest_path <- file.path(CSV_DIR, "S0_spec_report.csv")
safe_write_csv(contest, contest_path)
cat("\nWrote contest CSV:\n  ", contest_path, "\n", sep="")

# ------------------------------------------------------------
# 7) Coefficient table (LR multipliers table per case)
# ------------------------------------------------------------
coef_tbl <- purrr::map_dfr(results, function(x) {
  if (isTRUE(x$failed) || is.null(x$lr_full)) return(NULL)
  lr <- x$lr_full
  lr |>
    mutate(
      case_id = x$case_id,
      order_p = ORDER[1],
      order_q = ORDER[2],
      exact_test = EXACT_TEST,
      window_tag = WINDOW_TAG
    ) |>
    select(window_tag, case_id, order_p, order_q, exact_test, everything())
})

coef_path <- file.path(CSV_DIR, "S0_fivecase_summary.csv")
safe_write_csv(coef_tbl, coef_path)
cat("Wrote coef CSV:\n  ", coef_path, "\n", sep="")

# ------------------------------------------------------------
# 8) Build u-series wide CSV: Shaikh + u_caseX (ALL cases)
#    u_hat = Case 3 (Shaikh's benchmark), yp_hat = Case 3 capacity
# ------------------------------------------------------------
# Identify Case 3 result (Shaikh's benchmark specification)
res_c3 <- results[[which(sapply(results, `[[`, "case_id") == 3)]]

u_cases <- tibble(
  year     = df$year,
  u_shaikh = df$u_shaikh,
  u_hat    = res_c3$u,
  yp_hat   = res_c3$lnYp
)
for (x in results) {
  u_cases[[paste0("u_case", x$case_id)]] <- x$u
}
u_cases_path <- file.path(CSV_DIR, "S0_utilization_series.csv")
safe_write_csv(u_cases, u_cases_path)
cat("Wrote u-cases CSV:\n  ", u_cases_path, "\n", sep="")

# ------------------------------------------------------------
# 9) Main comparison figure:
#     Shaikh u + ALL cases that pass F gate
#     Legend includes robustness stars (from t-bounds) only for cases 1/3/5
# ------------------------------------------------------------
plot_long <- u_cases |>
  pivot_longer(-c(year, u_shaikh), names_to = "series", values_to = "u") |>
  mutate(
    case_id = as.integer(str_extract(series, "\\d+"))
  ) |>
  left_join(contest |> select(case_id, F_pass, t_admissible, robust_star), by = "case_id") |>
  filter(F_pass) |>
  mutate(
    label = case_when(
      is.na(case_id) ~ series,
      t_admissible ~ paste0("Case ", case_id, " (F-pass, t-robust ", robust_star, ")"),
      TRUE ~ paste0("Case ", case_id, " (F-pass, t n/a)")
    )
  )

shaikh_df <- tibble(year = df$year, u = df$u_shaikh, label = "Shaikh (2016)")

plot_df <- bind_rows(
  shaikh_df,
  plot_long |> select(year, u, label)
) |>
  filter(is.finite(u))

p <- ggplot(plot_df, aes(x = year, y = u, color = label, linetype = label)) +
  geom_line(linewidth = 0.9, na.rm = TRUE) +
  geom_hline(yintercept = 1, alpha = 0.35) +
  geom_vline(xintercept = DUMMY_YEARS, linetype = "dashed", alpha = 0.45) +
  theme_minimal(base_size = 12) +
  theme(
    legend.title = element_blank(),
    legend.position = "bottom",
    axis.text.x = element_text(angle = 45, hjust = 1)
  ) +
  labs(
    x = "Year",
    y = "Capacity Utilization (u)",
    title = paste0(
      "Shaikh replication | ARDL(", ORDER[1], ",", ORDER[2], ") | F-pass cases only | base p(2011)=100"
    ),
    subtitle = "Legend robustness stars apply only when t-bounds is admissible (cases 1,3,5) and F-pass"
  )

fig_path <- file.path(FIG_DIR, paste0("FIG_S0_ARDL_u_compare_cases_Fpass_", WINDOW_TAG, ".png"))
ggsave(fig_path, p, width = 11, height = 6.6, dpi = 300)
cat("Saved figure:\n  ", fig_path, "\n", sep="")

# ------------------------------------------------------------
# 10) Verification block — canonical benchmark comparison
# ------------------------------------------------------------
# Case 3 LR coefficients for verification against Shaikh Table 6.7.14
lr_c3      <- res_c3$lr_full
theta_v    <- extract_lr_row(lr_c3, "lnK")$est
a_v        <- extract_lr_row(lr_c3, "(Intercept)")$est
c_d74_v    <- extract_lr_row(lr_c3, "d1974")$est
c_d56_v    <- extract_lr_row(lr_c3, "d1956")$est
c_d80_v    <- extract_lr_row(lr_c3, "d1980")$est

fit_c3     <- res_c3$fit
aic_v      <- AIC(fit_c3)
bic_v      <- BIC(fit_c3)
loglik_v   <- as.numeric(logLik(fit_c3))
r2_v       <- summary(fit_c3)$r.squared

# RMSE vs Shaikh published series
rmse_s0 <- sqrt(mean((res_c3$u - df$u_shaikh)^2, na.rm = TRUE))

cat("\n=== S0 VERIFICATION vs SHAIKH TABLE 6.7.14 ===\n")
cat("theta_hat:", round(theta_v, 4),  "| Target: 0.6609\n")
cat("a_hat:    ", round(a_v, 4),      "| Target: 2.1782\n")
cat("c_d74:    ", round(c_d74_v, 4),  "| Target: -0.8548\n")
cat("c_d56:    ", round(c_d56_v, 4),  "| Target: -0.7428\n")
cat("c_d80:    ", round(c_d80_v, 4),  "| Target: -0.4780\n")
cat("AIC:      ", round(aic_v, 4),    "| Target: -319.3801\n")
cat("BIC:      ", round(bic_v, 4),    "| Target: -296.1605\n")
cat("loglik:   ", round(loglik_v, 4), "| Target: 170.6901\n")
cat("R2:       ", round(r2_v, 4),     "| Target: 0.9992\n")
cat("RMSE vs Shaikh:", round(rmse_s0, 6), "\n")
cat("==============================================\n")

# NOTE: Manifest append removed — 24_manifest_runner.R is the sole manifest writer.
cat("STAGE_STATUS_HINT: stage=S0 status=complete\n")
cat("\nDONE.\n")