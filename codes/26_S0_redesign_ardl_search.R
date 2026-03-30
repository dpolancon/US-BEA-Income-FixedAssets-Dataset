# ============================================================
# 26_S0_redesign_ardl_search.R
#
# S0 Redesign — Theoretically-Grounded ARDL Search with Exact Bounds
#
# Case 3 (operative): unrestricted intercept, no trend —
#   theoretically admissible under Shaikh's capital-embodied TC assumption.
# Case 5 (diagnostic): unrestricted intercept, unrestricted trend —
#   implies autonomous TC.  Theoretically inadmissible under Shaikh's
#   framework but included to test whether cointegration is recoverable
#   at all under current-vintage data.
#
# Sweep ARDL(p,q) over p in {1..4}, q in {0..4}, case in {3,5}
# (40 specs). Dual admissibility gate: F-bounds AND t-bounds at 10%
# (exact=TRUE). Five IC criteria: AIC, BIC, HQ, ICOMP, RICOMP (sandwich).
#
# Outputs under: output/CriticalReplication/S0_redesign/
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
  library(sandwich)
  library(lmtest)
  library(tseries)
})

# ------------------------------------------------------------
# Load CONFIG + shared code
# ------------------------------------------------------------
source(here::here("codes", "10_config.R"))
source(here::here("codes", "99_utils.R"))
source(here::here("codes", "98_ardl_helpers.R"))
source(here::here("codes", "99_figure_protocol.R"))

stopifnot(exists("CONFIG"), is.list(CONFIG))

# ------------------------------------------------------------
# LOCKED TOGGLES
# ------------------------------------------------------------
WINDOW_TAG   <- "shaikh_window"
P_RANGE      <- 1:4
Q_RANGE      <- 0:4
CASE_RANGE   <- c(3L, 5L)
EXACT_TEST   <- TRUE
DUMMY_YEARS  <- c(1956L, 1974L, 1980L)
ALPHA_LEVELS <- c(0.10, 0.05, 0.01)
GATE_ALPHA   <- 0.10
IC_NAMES     <- c("AIC", "BIC", "HQ", "ICOMP", "RICOMP")

set.seed(CONFIG$seed)

# ------------------------------------------------------------
# Output directories
# ------------------------------------------------------------
EXERCISE_DIR <- here::here(CONFIG$OUT_CR$S0_redesign %||%
                             "output/CriticalReplication/S0_redesign")
CSV_DIR  <- file.path(EXERCISE_DIR, "csv")
FIG_DIR  <- file.path(EXERCISE_DIR, "figures")
DOC_DIR  <- file.path(EXERCISE_DIR, "docs")

dir.create(CSV_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(FIG_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(DOC_DIR, recursive = TRUE, showWarnings = FALSE)

# Sink to docs
report_path <- file.path(DOC_DIR, "S0_redesign_report.txt")
sink(report_path, split = TRUE)
on.exit(try(sink(), silent = TRUE), add = TRUE)

cat("=== S0 REDESIGN — Case 3 + Case 5 Diagnostic, Exact Bounds, 5-IC Grid Search ===\n")
cat("Timestamp: ", now_stamp(), "\n", sep = "")
cat("Branch: S0_redesign | Cases: 3,5 | exact=TRUE | Grid: ",
    length(P_RANGE), "x", length(Q_RANGE), "x", length(CASE_RANGE), "=",
    length(P_RANGE) * length(Q_RANGE) * length(CASE_RANGE), " specs\n\n", sep = "")

# ============================================================
# STEP 3 — PACKAGE CHECK
# ============================================================
pkg_ver <- packageVersion("ARDL")
cat("ARDL package version:", as.character(pkg_ver), "\n")
if (pkg_ver < "0.2.3") {
  install.packages("ARDL")
  library(ARDL)
  pkg_ver <- packageVersion("ARDL")
}
stopifnot(pkg_ver >= "0.2.3")
cat("sandwich package version:", as.character(packageVersion("sandwich")), "\n\n")

# ============================================================
# STEP 2 — HELPER FUNCTIONS
# ============================================================

sig_stars <- function(p) {
  if (!is.finite(p)) return("")
  if (p < 0.01) return("***")
  if (p < 0.05) return("**")
  if (p < 0.10) return("*")
  ""
}

# Task-specific ICOMP: -2*logLik + k*log(det(C_hat)/k)
# where C_hat = vcov(fit) * n
icomp_calc <- function(fit) {
  tryCatch({
    k <- length(coef(fit))
    n <- nobs(fit)
    sigma2_mat <- vcov(fit) * n
    ld <- stable_logdet(sigma2_mat)
    if (!is.finite(ld)) return(NA_real_)
    as.numeric(-2 * logLik(fit)) + k * (ld - log(k))
  }, error = function(e) NA_real_)
}

# Task-specific RICOMP: same formula but with sandwich covariance
# C_sandwich = bread %*% meat %*% bread
ricomp_calc <- function(fit) {
  tryCatch({
    k <- length(coef(fit))
    n <- nobs(fit)
    meat_mat <- crossprod(sandwich::estfun(fit)) / n
    bread_mat <- sandwich::bread(fit)
    C_sandwich <- bread_mat %*% meat_mat %*% bread_mat
    ld <- stable_logdet(C_sandwich)
    if (!is.finite(ld)) return(NA_real_)
    as.numeric(-2 * logLik(fit)) + k * (ld - log(k))
  }, error = function(e) NA_real_)
}

make_step_dummies <- function(df, years) {
  for (yy in years) df[[paste0("d", yy)]] <- as.integer(df$year >= yy)
  df
}

rebase_to_year_to_100 <- function(p_vec, year_vec, base_year, strict = TRUE) {
  idx <- which(year_vec == base_year)
  if (length(idx) != 1) {
    msg <- paste0("Base year ", base_year, " not uniquely present.")
    if (strict) stop(msg) else { warning(msg); idx <- 1 }
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

# Extract I(0)/I(1) critical values from bounds test object
extract_bounds_cv <- function(bt_obj) {
  out <- list(I0 = NA_real_, I1 = NA_real_)
  if (is.list(bt_obj)) {
    # The ARDL package stores critical values in different ways
    # Try common field names
    if (!is.null(bt_obj$tab)) {
      tab <- bt_obj$tab
      if (is.data.frame(tab) || is.matrix(tab)) {
        if (ncol(tab) >= 2) {
          out$I0 <- as.numeric(tab[1, 1])
          out$I1 <- as.numeric(tab[1, 2])
        }
      }
    }
    # Alternative: check for lower.bound / upper.bound
    if (!is.null(bt_obj$lower.bound)) out$I0 <- as.numeric(bt_obj$lower.bound)
    if (!is.null(bt_obj$upper.bound)) out$I1 <- as.numeric(bt_obj$upper.bound)
  }
  out
}

get_lr_table_with_scaled_dummies <- function(fit_ardl, lnY_name = "lnY",
                                              dummy_names = character()) {
  lr_mult <- ARDL::multipliers(fit_ardl, type = "lr")

  coefs <- coef(fit_ardl)
  phi_names <- grep(paste0("^L\\(", lnY_name, ","), names(coefs), value = TRUE)
  den <- 1 - sum(coefs[phi_names])

  dummy_table <- NULL
  if (length(dummy_names)) {
    gamma_sr  <- coefs[dummy_names]
    dummy_lr  <- gamma_sr / den

    vc <- vcov(fit_ardl)

    se_lr <- numeric(length(dummy_names))
    for (j in seq_along(dummy_names)) {
      dname   <- dummy_names[j]
      gamma_j <- coefs[dname]
      param_names <- c(dname, phi_names)
      idx <- match(param_names, names(coefs))

      grad      <- numeric(length(param_names))
      grad[1]   <- 1 / den
      grad[-1]  <- gamma_j / den^2

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
  if (is.null(lr_full) || !("Term" %in% names(lr_full))) {
    return(list(est = NA_real_, se = NA_real_, p = NA_real_))
  }
  rr <- lr_full[lr_full$Term == term, , drop = FALSE]
  if (nrow(rr) == 0) return(list(est = NA_real_, se = NA_real_, p = NA_real_))
  p_col <- intersect(c("Pr(>|t|)", "Pr...t..", "p.value", "p_value"), names(rr))[1]
  se_col <- intersect(c("Std. Error", "Std..Error"), names(rr))[1]
  list(
    est = suppressWarnings(as.numeric(rr$Estimate[1])),
    se  = if (!is.na(se_col)) suppressWarnings(as.numeric(rr[[se_col]][1])) else NA_real_,
    p   = if (!is.na(p_col)) suppressWarnings(as.numeric(rr[[p_col]][1])) else NA_real_
  )
}

extract_alpha_from_uecm <- function(fit_ardl, lnY_name = "lnY") {
  uecm_model <- tryCatch(ARDL::uecm(fit_ardl), error = function(e) NULL)
  if (is.null(uecm_model)) return(list(est = NA_real_, se = NA_real_, p = NA_real_))
  uecm_coef <- tryCatch(summary(uecm_model)$coefficients, error = function(e) NULL)
  if (is.null(uecm_coef)) return(list(est = NA_real_, se = NA_real_, p = NA_real_))
  rr <- grep(paste0("^L\\(", lnY_name, ", 1\\)$"), rownames(uecm_coef), value = TRUE)
  if (length(rr) == 1) {
    return(list(
      est = as.numeric(uecm_coef[rr, "Estimate"]),
      se  = as.numeric(uecm_coef[rr, "Std. Error"]),
      p   = as.numeric(uecm_coef[rr, "Pr(>|t|)"])
    ))
  }
  list(est = NA_real_, se = NA_real_, p = NA_real_)
}

compute_u_from_lr <- function(df, lnY_name, lnK_name, lr_full, dummy_names) {
  a_lr_vec <- lr_full$Estimate[lr_full$Term == "(Intercept)"]
  a_lr <- if (length(a_lr_vec) > 0 && is.finite(a_lr_vec[1])) a_lr_vec[1] else 0

  theta_lr <- lr_full$Estimate[lr_full$Term == lnK_name]

  dummy_coef <- if (length(dummy_names)) {
    lr_full$Estimate[match(dummy_names, lr_full$Term)]
  } else numeric(0)
  dummy_effect <- if (length(dummy_names)) {
    rowSums(sweep(as.matrix(df[dummy_names]), 2, dummy_coef, `*`))
  } else 0

  lnY  <- df[[lnY_name]]
  lnK  <- df[[lnK_name]]
  lnYp <- a_lr + theta_lr * lnK + dummy_effect
  u    <- exp(lnY - lnYp)

  list(u = u, lnYp = lnYp, intercept = a_lr, theta = theta_lr)
}

# ============================================================
# STEP 0 — VERIFY SHAIKH'S OUTPUT SERIES FROM APPENDIX 6.8
# ============================================================
cat("\n", paste(rep("=", 60), collapse = ""), "\n")
cat("STEP 0 — VERIFY SHAIKH OUTPUT SERIES FROM APPENDIX 6.8\n")
cat(paste(rep("=", 60), collapse = ""), "\n\n")

app68 <- here::here("data", "raw", "other", "_Appendix6.8DataTablesCorrected.xlsx")

if (file.exists(app68)) {
  sheets <- excel_sheets(app68)
  cat("Sheets available:\n")
  print(sheets)

  # Table I.1 — income table
  i1_idx <- which(grepl("I\\.1|I1|income", sheets, ignore.case = TRUE))
  if (length(i1_idx) > 0) {
    sheet_I1 <- tryCatch(read_excel(app68, sheet = sheets[i1_idx[1]]),
                         error = function(e) NULL)
    if (!is.null(sheet_I1)) {
      cat("\nTable I.1 — first 15 rows:\n")
      print(head(sheet_I1, 15))
    }
  } else {
    cat("\nTable I.1 sheet not found by pattern.\n")
  }

  # Table II.5
  ii5_idx <- which(grepl("II\\.5|II5", sheets, ignore.case = TRUE))
  if (length(ii5_idx) > 0) {
    sheet_II5 <- tryCatch(read_excel(app68, sheet = sheets[ii5_idx[1]]),
                          error = function(e) NULL)
    if (!is.null(sheet_II5)) {
      cat("\nTable II.5 — first 20 rows:\n")
      print(head(sheet_II5, 20))
    }
  } else {
    cat("\nTable II.5 sheet not found by pattern.\n")
  }
} else {
  cat("WARNING: Appendix 6.8 Excel file not found at:\n  ", app68, "\n")
  cat("Skipping Step 0 verification.\n")
}

# Check prod_cap_dataset_d1.csv for GVA_nfc column
df_check <- readr::read_csv(here::here(CONFIG$data_shaikh), show_col_types = FALSE)
cat("\nColumns in prod_cap_dataset_d1.csv:\n")
cat(paste(names(df_check), collapse = ", "), "\n")

if ("GVA_nfc" %in% names(df_check)) {
  row_1947 <- df_check[df_check$year == 1947, ]
  cat("\nGVA_nfc column found.\n")
  cat("GVA_nfc / GVAcorp (1947):", round(row_1947$GVA_nfc / row_1947$GVAcorp, 4), "\n")
  row_2011 <- df_check[df_check$year == 2011, ]
  cat("GVA_nfc / GVAcorp (2011):", round(row_2011$GVA_nfc / row_2011$GVAcorp, 4), "\n")
} else {
  cat("\nGVA_nfc column NOT present — proceeding with GVAcorp.\n")
}

gva_1947 <- df_check[df_check$year == 1947, "GVAcorp", drop = TRUE]
cat("GVAcorp 1947:", gva_1947, "\n")

kgc_1947 <- df_check[df_check$year == 1947, "KGCcorp", drop = TRUE]
cat("KGCcorp 1947:", kgc_1947, "\n\n")

# ============================================================
# STEP 1 — DATA PREP
# ============================================================
cat(paste(rep("=", 60), collapse = ""), "\n")
cat("STEP 1 — DATA PREPARATION\n")
cat(paste(rep("=", 60), collapse = ""), "\n\n")

df_raw <- readr::read_csv(here::here(CONFIG$data_shaikh), show_col_types = FALSE)
stopifnot(all(c(CONFIG$year_col, CONFIG$y_nom, CONFIG$k_nom, CONFIG$p_index) %in% names(df_raw)))

# Price rebase to 2005=100
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
    K_nom = as.numeric(.data[[CONFIG$k_nom]])
  ) |>
  filter(is.finite(year), is.finite(Y_nom), is.finite(K_nom)) |>
  arrange(year) |>
  left_join(p_ledger, by = "year")

stopifnot(all(is.finite(df0$p2005)))

# Window lock: 1947-2011
w <- CONFIG$WINDOWS_LOCKED[[WINDOW_TAG]]
stopifnot(!is.null(w), length(w) == 2)
WINDOW_START <- as.integer(w[1])
WINDOW_END   <- as.integer(w[2])

df0 <- df0 |>
  filter(year >= WINDOW_START, year <= WINDOW_END) |>
  arrange(year)

cat("T =", nrow(df0), "observations (", min(df0$year), "-", max(df0$year), ")\n")
stopifnot(nrow(df0) == 65)

# Step dummies + real logs
df0 <- make_step_dummies(df0, DUMMY_YEARS)
dummy_names <- paste0("d", DUMMY_YEARS)

df <- df0 |>
  mutate(
    p_scale = p2005 / 100,
    Y_real  = Y_nom / p_scale,
    K_real  = K_nom / p_scale,
    lnY     = log(Y_real),
    lnK     = log(K_real),
    trend   = seq_len(n())
  )

cat("Data loaded: T=", nrow(df), " obs, years ", min(df$year), "-", max(df$year),
    " | lnY_1947: ", round(df$lnY[1], 4),
    " | lnK_1947: ", round(df$lnK[1], 4),
    " | Y series used: ", CONFIG$y_nom, "\n\n", sep = "")

# Build ts object (include trend for Case 5)
ts_cols <- c("lnY", "lnK", "trend", dummy_names)
df_ts <- ts(df[, ts_cols], start = min(df$year), frequency = 1)

# Load canonical CSV for comparison (uK_shaikh, uFRB)
canonical <- readr::read_csv(here::here(CONFIG$canonical_csv), show_col_types = FALSE)
canonical <- canonical |>
  select(year, uK_shaikh = !!CONFIG$u_shaikh, uFRB = !!CONFIG$u_frb) |>
  filter(year >= WINDOW_START, year <= WINDOW_END)

# ============================================================
# STEP 4 — GRID SEARCH (40 SPECS, CASE 3 + CASE 5)
# ============================================================
cat(paste(rep("=", 60), collapse = ""), "\n")
cat("STEP 4 — GRID SEARCH\n")
cat(paste(rep("=", 60), collapse = ""), "\n\n")

grid <- expand.grid(p = P_RANGE, q = Q_RANGE, case_num = CASE_RANGE,
                    stringsAsFactors = FALSE)
cat("Grid size:", nrow(grid), "specifications\n\n")

# Formulae: Case 3 (no trend), Case 5 (with trend)
dum_str <- paste(dummy_names, collapse = " + ")
fml_case3 <- as.formula(paste0("lnY ~ lnK | ", dum_str))
fml_case5 <- as.formula(paste0("lnY ~ lnK | trend + ", dum_str))

# Storage
results_list <- vector("list", nrow(grid))
u_hat_matrix <- matrix(NA_real_, nrow = nrow(df), ncol = nrow(grid))

for (i in seq_len(nrow(grid))) {
  pp <- grid$p[i]
  qq <- grid$q[i]
  cn <- grid$case_num[i]
  spec_label <- paste0("ARDL(", pp, ",", qq, ") Case ", cn)

  # Select formula and extra fixed-regressor names based on case
  if (cn == 5L) {
    fml_i <- fml_case5
    extra_names <- c("trend", dummy_names)
  } else {
    fml_i <- fml_case3
    extra_names <- dummy_names
  }

  # ----- Estimate -----
  fit <- tryCatch(
    ARDL::ardl(formula = fml_i, data = df_ts, order = c(pp, qq)),
    error = function(e) { cat("  FAIL:", spec_label, "-", e$message, "\n"); NULL }
  )

  if (is.null(fit)) {
    results_list[[i]] <- data.frame(
      p = pp, q = qq, case = cn, spec = spec_label,
      AIC = NA, BIC = NA, HQ = NA, ICOMP = NA, RICOMP = NA,
      logLik = NA, neg2logL = NA, k_total = NA, T_eff = NA,
      R2 = NA, adjR2 = NA,
      F_stat = NA, F_pval = NA, F_sig = "",
      t_stat = NA, t_pval = NA, t_sig = "",
      F_I0_010 = NA, F_I1_010 = NA, F_I0_005 = NA, F_I1_005 = NA,
      F_I0_001 = NA, F_I1_001 = NA,
      t_I0_010 = NA, t_I1_010 = NA, t_I0_005 = NA, t_I1_005 = NA,
      t_I0_001 = NA, t_I1_001 = NA,
      theta = NA, theta_se = NA, theta_p = NA,
      intercept = NA, intercept_se = NA, intercept_p = NA,
      c_d1956 = NA, c_d1956_se = NA, c_d1956_p = NA,
      c_d1974 = NA, c_d1974_se = NA, c_d1974_p = NA,
      c_d1980 = NA, c_d1980_se = NA, c_d1980_p = NA,
      ecm_alpha = NA, ecm_alpha_se = NA, ecm_alpha_p = NA,
      F_pass = FALSE, t_pass = FALSE, admissible = FALSE,
      stringsAsFactors = FALSE
    )
    next
  }

  # ----- ICs -----
  k_total <- length(coef(fit))
  T_eff   <- nobs(fit)
  ll      <- as.numeric(logLik(fit))
  neg2ll  <- -2 * ll
  aic_val <- AIC(fit)
  bic_val <- BIC(fit)
  hq_val  <- neg2ll + 2 * log(log(T_eff)) * k_total
  icomp_val  <- icomp_calc(fit)
  ricomp_val <- ricomp_calc(fit)

  smry <- summary(fit)
  r2_val    <- smry$r.squared
  adjr2_val <- smry$adj.r.squared

  # ----- Bounds tests at 3 alpha levels -----
  # F-bounds
  bt_f_010 <- tryCatch(
    ARDL::bounds_f_test(fit, case = cn, alpha = 0.10, pvalue = TRUE, exact = EXACT_TEST),
    error = function(e) list(statistic = NA_real_, p.value = NA_real_))
  bt_f_005 <- tryCatch(
    ARDL::bounds_f_test(fit, case = cn, alpha = 0.05, pvalue = TRUE, exact = EXACT_TEST),
    error = function(e) list(statistic = NA_real_, p.value = NA_real_))
  bt_f_001 <- tryCatch(
    ARDL::bounds_f_test(fit, case = cn, alpha = 0.01, pvalue = TRUE, exact = EXACT_TEST),
    error = function(e) list(statistic = NA_real_, p.value = NA_real_))

  # t-bounds
  bt_t_010 <- tryCatch(
    ARDL::bounds_t_test(fit, case = cn, alpha = 0.10, pvalue = TRUE, exact = EXACT_TEST),
    error = function(e) list(statistic = NA_real_, p.value = NA_real_))
  bt_t_005 <- tryCatch(
    ARDL::bounds_t_test(fit, case = cn, alpha = 0.05, pvalue = TRUE, exact = EXACT_TEST),
    error = function(e) list(statistic = NA_real_, p.value = NA_real_))
  bt_t_001 <- tryCatch(
    ARDL::bounds_t_test(fit, case = cn, alpha = 0.01, pvalue = TRUE, exact = EXACT_TEST),
    error = function(e) list(statistic = NA_real_, p.value = NA_real_))

  bF <- extract_bt(bt_f_010)
  bT <- extract_bt(bt_t_010)

  # Extract I(0)/I(1) critical values at each alpha
  cv_f_010 <- extract_bounds_cv(bt_f_010)
  cv_f_005 <- extract_bounds_cv(bt_f_005)
  cv_f_001 <- extract_bounds_cv(bt_f_001)
  cv_t_010 <- extract_bounds_cv(bt_t_010)
  cv_t_005 <- extract_bounds_cv(bt_t_005)
  cv_t_001 <- extract_bounds_cv(bt_t_001)

  # ----- LR coefficients -----
  lr_pack <- tryCatch(
    get_lr_table_with_scaled_dummies(fit, lnY_name = "lnY", dummy_names = extra_names),
    error = function(e) list(lr_full_table = NULL, den = NA)
  )
  lr_full <- lr_pack$lr_full_table

  theta_lr    <- extract_lr_row(lr_full, "lnK")
  intercept_lr <- extract_lr_row(lr_full, "(Intercept)")
  d1956_lr    <- extract_lr_row(lr_full, "d1956")
  d1974_lr    <- extract_lr_row(lr_full, "d1974")
  d1980_lr    <- extract_lr_row(lr_full, "d1980")

  # ----- ECM speed -----
  ecm <- extract_alpha_from_uecm(fit, lnY_name = "lnY")

  # ----- Utilization -----
  if (!is.null(lr_full)) {
    u_series <- compute_u_from_lr(df, "lnY", "lnK", lr_full, extra_names)
    u_hat_matrix[, i] <- u_series$u
  }

  # ----- Admissibility -----
  f_pass <- !is.na(bF$pval) && bF$pval < GATE_ALPHA
  t_pass <- !is.na(bT$pval) && bT$pval < GATE_ALPHA
  admissible <- f_pass && t_pass

  # ----- Progress print -----
  cat(sprintf("[%s] F=%.2f (p=%.3f%s) | t=%.2f (p=%.3f%s) | AIC=%.1f | BIC=%.1f | HQ=%.1f | ICOMP=%.1f | RICOMP=%.1f | %s\n",
              spec_label,
              ifelse(is.finite(bF$stat), bF$stat, NA),
              ifelse(is.finite(bF$pval), bF$pval, NA),
              sig_stars(bF$pval),
              ifelse(is.finite(bT$stat), bT$stat, NA),
              ifelse(is.finite(bT$pval), bT$pval, NA),
              sig_stars(bT$pval),
              ifelse(is.finite(aic_val), aic_val, NA),
              ifelse(is.finite(bic_val), bic_val, NA),
              ifelse(is.finite(hq_val), hq_val, NA),
              ifelse(is.finite(icomp_val), icomp_val, NA),
              ifelse(is.finite(ricomp_val), ricomp_val, NA),
              ifelse(admissible, "PASS", "FAIL")))

  results_list[[i]] <- data.frame(
    p = pp, q = qq, case = cn, spec = spec_label,
    AIC = aic_val, BIC = bic_val, HQ = hq_val,
    ICOMP = icomp_val, RICOMP = ricomp_val,
    logLik = ll, neg2logL = neg2ll, k_total = k_total, T_eff = T_eff,
    R2 = r2_val, adjR2 = adjr2_val,
    F_stat = bF$stat, F_pval = bF$pval, F_sig = sig_stars(bF$pval),
    t_stat = bT$stat, t_pval = bT$pval, t_sig = sig_stars(bT$pval),
    F_I0_010 = cv_f_010$I0, F_I1_010 = cv_f_010$I1,
    F_I0_005 = cv_f_005$I0, F_I1_005 = cv_f_005$I1,
    F_I0_001 = cv_f_001$I0, F_I1_001 = cv_f_001$I1,
    t_I0_010 = cv_t_010$I0, t_I1_010 = cv_t_010$I1,
    t_I0_005 = cv_t_005$I0, t_I1_005 = cv_t_005$I1,
    t_I0_001 = cv_t_001$I0, t_I1_001 = cv_t_001$I1,
    theta = theta_lr$est, theta_se = theta_lr$se, theta_p = theta_lr$p,
    intercept = intercept_lr$est, intercept_se = intercept_lr$se, intercept_p = intercept_lr$p,
    c_d1956 = d1956_lr$est, c_d1956_se = d1956_lr$se, c_d1956_p = d1956_lr$p,
    c_d1974 = d1974_lr$est, c_d1974_se = d1974_lr$se, c_d1974_p = d1974_lr$p,
    c_d1980 = d1980_lr$est, c_d1980_se = d1980_lr$se, c_d1980_p = d1980_lr$p,
    ecm_alpha = ecm$est, ecm_alpha_se = ecm$se, ecm_alpha_p = ecm$p,
    F_pass = f_pass, t_pass = t_pass, admissible = admissible,
    stringsAsFactors = FALSE
  )
}

# Bind all results
results <- bind_rows(results_list)

# ============================================================
# STEP 5 — ADMISSIBILITY GATES
# ============================================================
cat("\n", paste(rep("=", 60), collapse = ""), "\n")
cat("STEP 5 — ADMISSIBILITY GATES\n")
cat(paste(rep("=", 60), collapse = ""), "\n\n")

n_admissible <- sum(results$admissible, na.rm = TRUE)
n_admissible_c3 <- sum(results$admissible & results$case == 3L, na.rm = TRUE)
n_admissible_c5 <- sum(results$admissible & results$case == 5L, na.rm = TRUE)

cat("=== CASE 3 (capital-embodied TC — primary specification) ===\n")
cat("Admissible specs (F + t both pass at 10%):", n_admissible_c3, "of",
    sum(results$case == 3L), "\n\n")

if (n_admissible_c3 == 0) {
  cat("WARNING: No Case 3 specifications pass both admissibility gates.\n")
  cat("Cannot select Case 3 IC winners.\n\n")
}

cat("=== CASE 5 DIAGNOSTIC (autonomous TC — theoretically inadmissible) ===\n")
cat("Included to test whether cointegration is recoverable under current-vintage data.\n")
cat("A passing Case 5 specification does NOT constitute a valid capacity utilization estimate.\n")
cat("It documents the structural assumption required to recover cointegration.\n\n")
cat("Admissible specs (F + t both pass at 10%):", n_admissible_c5, "of",
    sum(results$case == 5L), "\n\n")

if (n_admissible_c3 == 0 && n_admissible_c5 > 0) {
  cat(paste(rep("*", 70), collapse = ""), "\n")
  cat("FINDING: Cointegration is not recoverable under any Case 3 specification\n")
  cat("(capital-embodied TC). It is recoverable only under Case 5 (autonomous TC),\n")
  cat("which Shaikh's framework explicitly rejects. This confirms the vintage\n")
  cat("sensitivity finding and identifies the specific structural assumption that\n")
  cat("would need to hold for the methodology to apply to current-vintage data.\n")
  cat(paste(rep("*", 70), collapse = ""), "\n\n")
}

cat("Total admissible:", n_admissible, "of", nrow(results), "\n\n")

admissible_set <- results[results$admissible, ]

# ============================================================
# STEP 6 — IC WINNER SELECTION (within each case separately)
# ============================================================
cat("\n", paste(rep("=", 60), collapse = ""), "\n")
cat("STEP 6 — IC WINNER SELECTION\n")
cat(paste(rep("=", 60), collapse = ""), "\n\n")

winners_by_case <- list()

for (cn in CASE_RANGE) {
  admissible_case <- admissible_set[admissible_set$case == cn, ]
  n_adm_case <- nrow(admissible_case)

  case_tag <- if (cn == 3L) "Case 3 (primary)" else "Case 5 (diagnostic)"

  if (cn == 5L) {
    cat("\n--- CASE 5 DIAGNOSTIC (autonomous TC — theoretically inadmissible) ---\n")
    cat("Included to test whether cointegration is recoverable under current-vintage data.\n")
    cat("A passing Case 5 specification does NOT constitute a valid capacity utilization estimate.\n")
    cat("It documents the structural assumption required to recover cointegration.\n\n")
  } else {
    cat("--- Case 3 (capital-embodied TC — primary specification) ---\n\n")
  }

  if (n_adm_case == 0) {
    cat("  No admissible specs for ", case_tag, " — skipping IC selection.\n\n", sep = "")
    winners_by_case[[as.character(cn)]] <- list()
    next
  }

  case_winners <- list()
  for (ic in IC_NAMES) {
    ic_vals <- admissible_case[[ic]]
    if (all(is.na(ic_vals))) {
      cat("  ", ic, ": no valid values — skipped\n")
      next
    }
    best_idx <- which.min(ic_vals)
    case_winners[[ic]] <- admissible_case[best_idx, ]
    cat(sprintf("  winner_%s: ARDL(%d,%d) Case %d | %s=%.3f | theta=%.4f\n",
                ic, case_winners[[ic]]$p, case_winners[[ic]]$q, cn,
                ic, case_winners[[ic]][[ic]],
                case_winners[[ic]]$theta))
  }

  # Check consensus
  if (length(case_winners) > 0) {
    winner_specs <- sapply(case_winners, function(w) paste0(w$p, ",", w$q))
    spec_counts <- table(winner_specs)
    consensus_specs <- names(spec_counts[spec_counts >= 2])

    if (length(consensus_specs) > 0) {
      cat("\nCONSENSUS detected (", case_tag, "):\n", sep = "")
      for (cs in consensus_specs) {
        which_ics <- names(winner_specs[winner_specs == cs])
        cat("  ARDL(", cs, ") selected by:", paste(which_ics, collapse = ", "), "\n")
      }
    }

    # Check Shaikh benchmark (Case 3 only)
    if (cn == 3L) {
      shaikh_in_admissible <- any(admissible_case$p == 2 & admissible_case$q == 4)
      cat("\nShaikh ARDL(2,4) in admissible set:", ifelse(shaikh_in_admissible, "YES", "NO"), "\n")
    }

    # Check ICOMP vs RICOMP divergence
    if (!is.null(case_winners[["ICOMP"]]) && !is.null(case_winners[["RICOMP"]])) {
      icomp_spec <- paste0(case_winners[["ICOMP"]]$p, ",", case_winners[["ICOMP"]]$q)
      ricomp_spec <- paste0(case_winners[["RICOMP"]]$p, ",", case_winners[["RICOMP"]]$q)
      if (icomp_spec != ricomp_spec) {
        cat("\nICOMP and RICOMP winners DIFFER (", case_tag, "):\n", sep = "")
        cat("  ICOMP  -> ARDL(", icomp_spec, ")\n")
        cat("  RICOMP -> ARDL(", ricomp_spec, ")\n")
        cat("  Sandwich correction is MATERIAL.\n")
      }
    }
  }

  winners_by_case[[as.character(cn)]] <- case_winners
  cat("\n")
}

# Build IC-winner column for results table
results$IC_winner <- ""
for (cn_str in names(winners_by_case)) {
  cn_val <- as.integer(cn_str)
  case_winners <- winners_by_case[[cn_str]]
  if (length(case_winners) > 0) {
    for (ic in names(case_winners)) {
      w <- case_winners[[ic]]
      idx <- which(results$p == w$p & results$q == w$q & results$case == cn_val)
      if (length(idx) == 1) {
        existing <- results$IC_winner[idx]
        results$IC_winner[idx] <- if (nchar(existing) > 0) {
          paste0(existing, "/", ic)
        } else {
          ic
        }
      }
    }
  }
}
# Mark CONSENSUS
for (idx in seq_len(nrow(results))) {
  if (nchar(results$IC_winner[idx]) > 0 &&
      length(strsplit(results$IC_winner[idx], "/")[[1]]) >= 2) {
    results$IC_winner[idx] <- paste0(results$IC_winner[idx], " [CONSENSUS]")
  }
}

# ============================================================
# STEP 7 — FULL RESULTS TABLE (sorted by Case, then AIC)
# ============================================================
cat("\n", paste(rep("=", 60), collapse = ""), "\n")
cat("STEP 7 — FULL RESULTS TABLE (sorted by Case, then AIC)\n")
cat(paste(rep("=", 60), collapse = ""), "\n\n")

results_sorted <- results |> arrange(case, AIC) |> mutate(Rank = row_number())
results_sorted <- results_sorted |>
  select(Rank, spec, case, AIC, BIC, HQ, ICOMP, RICOMP,
         F_stat, F_pval, F_sig, t_stat, t_pval, t_sig,
         admissible, IC_winner, everything())

# Print Case 3 block
cat("--- Case 3 (capital-embodied TC — primary specification) ---\n\n")
results_c3 <- results_sorted[results_sorted$case == 3L, ]
for (i in seq_len(nrow(results_c3))) {
  r <- results_c3[i, ]
  cat(sprintf("%2d | %-18s | AIC=%7.1f | BIC=%7.1f | HQ=%7.1f | ICOMP=%7.1f | RICOMP=%7.1f | F=%.2f%s | t=%.2f%s | %s | %s\n",
              r$Rank, r$spec,
              ifelse(is.finite(r$AIC), r$AIC, NA),
              ifelse(is.finite(r$BIC), r$BIC, NA),
              ifelse(is.finite(r$HQ), r$HQ, NA),
              ifelse(is.finite(r$ICOMP), r$ICOMP, NA),
              ifelse(is.finite(r$RICOMP), r$RICOMP, NA),
              ifelse(is.finite(r$F_stat), r$F_stat, NA),
              r$F_sig,
              ifelse(is.finite(r$t_stat), r$t_stat, NA),
              r$t_sig,
              ifelse(r$admissible, "PASS", "FAIL"),
              r$IC_winner))
}

cat("\n=== CASE 5 DIAGNOSTIC (autonomous TC — theoretically inadmissible) ===\n")
cat("Included to test whether cointegration is recoverable under current-vintage data.\n")
cat("A passing Case 5 specification does NOT constitute a valid capacity utilization estimate.\n")
cat("It documents the structural assumption required to recover cointegration.\n\n")

results_c5 <- results_sorted[results_sorted$case == 5L, ]
for (i in seq_len(nrow(results_c5))) {
  r <- results_c5[i, ]
  cat(sprintf("%2d | %-18s | AIC=%7.1f | BIC=%7.1f | HQ=%7.1f | ICOMP=%7.1f | RICOMP=%7.1f | F=%.2f%s | t=%.2f%s | %s | %s\n",
              r$Rank, r$spec,
              ifelse(is.finite(r$AIC), r$AIC, NA),
              ifelse(is.finite(r$BIC), r$BIC, NA),
              ifelse(is.finite(r$HQ), r$HQ, NA),
              ifelse(is.finite(r$ICOMP), r$ICOMP, NA),
              ifelse(is.finite(r$RICOMP), r$RICOMP, NA),
              ifelse(is.finite(r$F_stat), r$F_stat, NA),
              r$F_sig,
              ifelse(is.finite(r$t_stat), r$t_stat, NA),
              r$t_sig,
              ifelse(r$admissible, "PASS", "FAIL"),
              r$IC_winner))
}

safe_write_csv(results_sorted, file.path(CSV_DIR, "S0_redesign_full_grid.csv"))
cat("\nSaved: S0_redesign_full_grid.csv\n")

# Save admissible subset
if (n_admissible > 0) {
  safe_write_csv(admissible_set |> arrange(case, AIC),
                 file.path(CSV_DIR, "S0_redesign_admissible.csv"))
  cat("Saved: S0_redesign_admissible.csv\n")
}

# ============================================================
# STEP 8 — WINNER DIAGNOSTICS
# ============================================================
cat("\n", paste(rep("=", 60), collapse = ""), "\n")
cat("STEP 8 — WINNER DIAGNOSTICS\n")
cat(paste(rep("=", 60), collapse = ""), "\n\n")

all_winner_rows_for_csv <- list()

for (cn in CASE_RANGE) {
  cn_str <- as.character(cn)
  case_winners <- winners_by_case[[cn_str]]
  if (length(case_winners) == 0) next

  case_tag <- if (cn == 3L) "Case 3 (primary)" else "Case 5 (diagnostic)"

  if (cn == 5L) {
    cat("\n=== CASE 5 DIAGNOSTIC (autonomous TC — theoretically inadmissible) ===\n")
    cat("Included to test whether cointegration is recoverable under current-vintage data.\n")
    cat("A passing Case 5 specification does NOT constitute a valid capacity utilization estimate.\n")
    cat("It documents the structural assumption required to recover cointegration.\n\n")
  }

  # Select formula for this case
  fml_diag <- if (cn == 5L) fml_case5 else fml_case3
  extra_names_diag <- if (cn == 5L) c("trend", dummy_names) else dummy_names

  # Deduplicate winners
  winner_specs_dedup <- unique(sapply(case_winners, function(w) paste0(w$p, ",", w$q)))

  for (ws in winner_specs_dedup) {
    pq <- as.integer(strsplit(ws, ",")[[1]])
    wp <- pq[1]; wq <- pq[2]

    # Which ICs selected this spec
    which_ics <- names(case_winners)[sapply(case_winners, function(w) w$p == wp & w$q == wq)]
    ic_label <- paste(which_ics, collapse = " / ")
    if (length(which_ics) >= 2) ic_label <- paste0(ic_label, " [CONSENSUS]")

    spec_label <- paste0("ARDL(", wp, ",", wq, ") Case ", cn)
    cat(paste(rep("-", 60), collapse = ""), "\n")
    cat("=== IC WINNER:", spec_label, "[", ic_label, "] ===\n")
    cat(paste(rep("-", 60), collapse = ""), "\n\n")

    # Re-fit for diagnostics
    fit_w <- ARDL::ardl(formula = fml_diag, data = df_ts, order = c(wp, wq))

    # Bounds tests detail
    cat("Bounds tests (exact, T=", nobs(fit_w), "):\n", sep = "")

    for (alpha_lev in ALPHA_LEVELS) {
      alpha_tag <- sprintf("%.0f%%", alpha_lev * 100)

      bt_f <- tryCatch(
        ARDL::bounds_f_test(fit_w, case = cn, alpha = alpha_lev,
                            pvalue = TRUE, exact = EXACT_TEST),
        error = function(e) list(statistic = NA, p.value = NA))
      bt_t <- tryCatch(
        ARDL::bounds_t_test(fit_w, case = cn, alpha = alpha_lev,
                            pvalue = TRUE, exact = EXACT_TEST),
        error = function(e) list(statistic = NA, p.value = NA))

      bF_d <- extract_bt(bt_f)
      bT_d <- extract_bt(bt_t)
      cv_f <- extract_bounds_cv(bt_f)
      cv_t <- extract_bounds_cv(bt_t)

      # Determine position relative to bounds
      f_pos <- if (is.finite(bF_d$stat) && is.finite(cv_f$I1)) {
        if (bF_d$stat > cv_f$I1) "above" else if (bF_d$stat < cv_f$I0) "below" else "between"
      } else "N/A"
      t_pos <- if (is.finite(bT_d$stat) && is.finite(cv_t$I1)) {
        if (bT_d$stat < cv_t$I1) "above" else if (bT_d$stat > cv_t$I0) "below" else "between"
      } else "N/A"

      if (alpha_lev == 0.10) {
        cat(sprintf("  F-bounds: Stat=%.2f | p=%.3f %s\n",
                    bF_d$stat, bF_d$pval, sig_stars(bF_d$pval)))
      }
      cat(sprintf("    alpha=%s: I(0)=%.2f | I(1)=%.2f | [%s]\n",
                  alpha_tag,
                  ifelse(is.finite(cv_f$I0), cv_f$I0, NA),
                  ifelse(is.finite(cv_f$I1), cv_f$I1, NA),
                  f_pos))

      if (alpha_lev == 0.10) {
        cat(sprintf("  t-bounds: Stat=%.2f | p=%.3f %s\n",
                    bT_d$stat, bT_d$pval, sig_stars(bT_d$pval)))
      }
      if (alpha_lev == 0.10) {
        # Print t-bounds header on first alpha only
      }
      cat(sprintf("    alpha=%s: I(0)=%.2f | I(1)=%.2f | [%s]\n",
                  alpha_tag,
                  ifelse(is.finite(cv_t$I0), cv_t$I0, NA),
                  ifelse(is.finite(cv_t$I1), cv_t$I1, NA),
                  t_pos))
    }

    # LR coefficients
    lr_pack_w <- get_lr_table_with_scaled_dummies(fit_w, lnY_name = "lnY",
                                                   dummy_names = extra_names_diag)
    lr_w <- lr_pack_w$lr_full_table

    cat("\nLong-run (from restricted LR equation):\n")
    theta_w     <- extract_lr_row(lr_w, "lnK")
    intercept_w <- extract_lr_row(lr_w, "(Intercept)")
    d1956_w     <- extract_lr_row(lr_w, "d1956")
    d1974_w     <- extract_lr_row(lr_w, "d1974")
    d1980_w     <- extract_lr_row(lr_w, "d1980")

    cat(sprintf("  theta (lnK):  %.4f | SE=%.4f | p=%.4f %s\n",
                theta_w$est, theta_w$se, theta_w$p, sig_stars(theta_w$p)))
    cat(sprintf("  intercept:    %.4f | SE=%.4f | p=%.4f %s\n",
                intercept_w$est, intercept_w$se, intercept_w$p, sig_stars(intercept_w$p)))
    cat(sprintf("  c_d1956:      %.4f | SE=%.4f | p=%.4f %s\n",
                d1956_w$est, d1956_w$se, d1956_w$p, sig_stars(d1956_w$p)))
    cat(sprintf("  c_d1974:      %.4f | SE=%.4f | p=%.4f %s\n",
                d1974_w$est, d1974_w$se, d1974_w$p, sig_stars(d1974_w$p)))
    cat(sprintf("  c_d1980:      %.4f | SE=%.4f | p=%.4f %s\n",
                d1980_w$est, d1980_w$se, d1980_w$p, sig_stars(d1980_w$p)))

    if (cn == 5L) {
      trend_w <- extract_lr_row(lr_w, "trend")
      cat(sprintf("  trend (LR):   %.6f | SE=%.6f | p=%.4f %s\n",
                  trend_w$est, trend_w$se, trend_w$p, sig_stars(trend_w$p)))
    }

    # ECM
    ecm_w <- extract_alpha_from_uecm(fit_w, lnY_name = "lnY")
    cat(sprintf("\nECM:\n  alpha (ECM speed): %.4f | SE=%.4f | p=%.4f %s\n",
                ecm_w$est, ecm_w$se, ecm_w$p, sig_stars(ecm_w$p)))

    # Residual diagnostics
    cat("\nResidual diagnostics:\n")
    resids <- residuals(fit_w)

    bg1 <- tryCatch(lmtest::bgtest(fit_w, order = 1), error = function(e) NULL)
    bg4 <- tryCatch(lmtest::bgtest(fit_w, order = 4), error = function(e) NULL)
    arch1 <- tryCatch({
      e2 <- resids^2
      n_e <- length(e2)
      arch_df <- data.frame(e2 = e2[2:n_e], e2_lag1 = e2[1:(n_e - 1)])
      arch_fit <- lm(e2 ~ e2_lag1, data = arch_df)
      lmtest::waldtest(arch_fit, 2)  # test e2_lag1 coefficient
    }, error = function(e) NULL)
    reset_t <- tryCatch(lmtest::resettest(fit_w, power = 2:3), error = function(e) NULL)
    jb <- tryCatch(tseries::jarque.bera.test(resids), error = function(e) NULL)

    cat(sprintf("  Breusch-Godfrey (lag 1): p=%.4f %s\n",
                if (!is.null(bg1)) bg1$p.value else NA,
                if (!is.null(bg1)) sig_stars(bg1$p.value) else ""))
    cat(sprintf("  Breusch-Godfrey (lag 4): p=%.4f %s\n",
                if (!is.null(bg4)) bg4$p.value else NA,
                if (!is.null(bg4)) sig_stars(bg4$p.value) else ""))
    cat(sprintf("  ARCH (lag 1):            p=%.4f %s\n",
                if (!is.null(arch1)) arch1$`Pr(>F)`[2] else NA,
                if (!is.null(arch1)) sig_stars(arch1$`Pr(>F)`[2]) else ""))
    cat(sprintf("  RESET:                   p=%.4f %s\n",
                if (!is.null(reset_t)) reset_t$p.value else NA,
                if (!is.null(reset_t)) sig_stars(reset_t$p.value) else ""))
    cat(sprintf("  Jarque-Bera normality:   p=%.4f %s\n",
                if (!is.null(jb)) jb$p.value else NA,
                if (!is.null(jb)) sig_stars(jb$p.value) else ""))

    # IC coordinates
    w_row <- results[results$p == wp & results$q == wq & results$case == cn, ]
    cat(sprintf("\nIC coordinates:\n  AIC=%.1f | BIC=%.1f | HQ=%.1f | ICOMP=%.1f | RICOMP=%.1f\n",
                w_row$AIC, w_row$BIC, w_row$HQ, w_row$ICOMP, w_row$RICOMP))
    cat("\n")

    all_winner_rows_for_csv[[paste0(cn, "_", ws)]] <- w_row |> mutate(IC_selected = ic_label)
  }
}

# Save IC winners CSV
if (length(all_winner_rows_for_csv) > 0) {
  ic_winners_csv <- bind_rows(all_winner_rows_for_csv)
  safe_write_csv(ic_winners_csv, file.path(CSV_DIR, "S0_redesign_ic_winners.csv"))
  cat("Saved: S0_redesign_ic_winners.csv\n")
}

# ============================================================
# STEP 9 — SHAIKH BENCHMARK ANCHOR (Case 3 only)
# ============================================================
cat("\n", paste(rep("=", 60), collapse = ""), "\n")
cat("STEP 9 — SHAIKH BENCHMARK ARDL(2,4) CASE 3\n")
cat(paste(rep("=", 60), collapse = ""), "\n\n")

shaikh_row <- results[results$p == 2 & results$q == 4 & results$case == 3L, ]

if (nrow(shaikh_row) == 1) {
  cat("Specification: ARDL(2,4) Case 3\n\n")

  # Re-fit for full detail
  fit_shaikh <- ARDL::ardl(formula = fml_case3, data = df_ts, order = c(2, 4))

  cat("Bounds tests (exact=TRUE):\n")
  for (alpha_lev in ALPHA_LEVELS) {
    alpha_tag <- sprintf("%.0f%%", alpha_lev * 100)

    bt_f_s <- tryCatch(
      ARDL::bounds_f_test(fit_shaikh, case = 3L, alpha = alpha_lev,
                          pvalue = TRUE, exact = EXACT_TEST),
      error = function(e) list(statistic = NA, p.value = NA))
    bt_t_s <- tryCatch(
      ARDL::bounds_t_test(fit_shaikh, case = 3L, alpha = alpha_lev,
                          pvalue = TRUE, exact = EXACT_TEST),
      error = function(e) list(statistic = NA, p.value = NA))

    bF_s <- extract_bt(bt_f_s)
    bT_s <- extract_bt(bt_t_s)
    cv_f_s <- extract_bounds_cv(bt_f_s)
    cv_t_s <- extract_bounds_cv(bt_t_s)

    f_pos <- if (is.finite(bF_s$stat) && is.finite(cv_f_s$I1)) {
      if (bF_s$stat > cv_f_s$I1) "above" else if (bF_s$stat < cv_f_s$I0) "below" else "between"
    } else "N/A"
    t_pos <- if (is.finite(bT_s$stat) && is.finite(cv_t_s$I1)) {
      if (bT_s$stat < cv_t_s$I1) "above" else if (bT_s$stat > cv_t_s$I0) "below" else "between"
    } else "N/A"

    if (alpha_lev == 0.10) {
      cat(sprintf("  F-bounds: Stat=%.2f | p=%.3f %s\n",
                  bF_s$stat, bF_s$pval, sig_stars(bF_s$pval)))
    }
    cat(sprintf("    alpha=%s: I(0)=%.2f | I(1)=%.2f | [%s]\n",
                alpha_tag,
                ifelse(is.finite(cv_f_s$I0), cv_f_s$I0, NA),
                ifelse(is.finite(cv_f_s$I1), cv_f_s$I1, NA),
                f_pos))

    if (alpha_lev == 0.10) {
      cat(sprintf("  t-bounds: Stat=%.2f | p=%.3f %s\n",
                  bT_s$stat, bT_s$pval, sig_stars(bT_s$pval)))
    }
    cat(sprintf("    alpha=%s: I(0)=%.2f | I(1)=%.2f | [%s]\n",
                alpha_tag,
                ifelse(is.finite(cv_t_s$I0), cv_t_s$I0, NA),
                ifelse(is.finite(cv_t_s$I1), cv_t_s$I1, NA),
                t_pos))
  }

  cat(sprintf("\nIC values:\n  AIC=%.1f | BIC=%.1f | HQ=%.1f | ICOMP=%.1f | RICOMP=%.1f\n",
              shaikh_row$AIC, shaikh_row$BIC, shaikh_row$HQ,
              shaikh_row$ICOMP, shaikh_row$RICOMP))

  cat(sprintf("\nLR coefficients:\n  theta=%.4f | intercept=%.4f | c_d1956=%.4f | c_d1974=%.4f | c_d1980=%.4f\n",
              shaikh_row$theta, shaikh_row$intercept,
              shaikh_row$c_d1956, shaikh_row$c_d1974, shaikh_row$c_d1980))

  cat("\nAdmissible under redesign criteria:",
      ifelse(shaikh_row$admissible, "YES", "NO"), "\n")
  if (!shaikh_row$admissible) {
    if (!shaikh_row$F_pass) {
      cat("  FAIL: F-bounds gate — p-value =", round(shaikh_row$F_pval, 4), "\n")
    }
    if (!shaikh_row$t_pass) {
      cat("  FAIL: t-bounds gate — p-value =", round(shaikh_row$t_pval, 4), "\n")
    }
  }
} else {
  cat("WARNING: ARDL(2,4) Case 3 not found in results grid.\n")
}

# ============================================================
# STEP 10 — UTILIZATION COMPARISON FIGURE
# ============================================================
cat("\n", paste(rep("=", 60), collapse = ""), "\n")
cat("STEP 10 — UTILIZATION COMPARISON FIGURES\n")
cat(paste(rep("=", 60), collapse = ""), "\n\n")

# Determine which cases have winners for figure generation
# If Case 3 has winners, produce figures for Case 3 winners.
# If Case 3 is empty and Case 5 has winners, produce figures for Case 5 winners
# with diagnostic warning in figure title.
fig_cases <- integer(0)
if (length(winners_by_case[["3"]]) > 0) fig_cases <- c(fig_cases, 3L)
if (length(winners_by_case[["5"]]) > 0) {
  if (length(winners_by_case[["3"]]) > 0) {
    fig_cases <- c(fig_cases, 5L)
  } else {
    fig_cases <- c(fig_cases, 5L)
  }
}

if (length(fig_cases) > 0) {
  for (cn in fig_cases) {
    cn_str <- as.character(cn)
    case_winners <- winners_by_case[[cn_str]]
    if (length(case_winners) == 0) next

    case_diagnostic <- (cn == 5L)
    fml_fig <- if (cn == 5L) fml_case5 else fml_case3
    extra_names_fig <- if (cn == 5L) c("trend", dummy_names) else dummy_names

    winner_specs_dedup <- unique(sapply(case_winners, function(w) paste0(w$p, ",", w$q)))

    for (ws in winner_specs_dedup) {
      pq <- as.integer(strsplit(ws, ",")[[1]])
      wp <- pq[1]; wq <- pq[2]

      which_ics <- names(case_winners)[sapply(case_winners, function(w) w$p == wp & w$q == wq)]
      ic_label <- paste(which_ics, collapse = "/")
      if (length(which_ics) >= 2) ic_label <- paste0(ic_label, " [CONSENSUS]")

      spec_label <- paste0("ARDL(", wp, ",", wq, ") Case ", cn)

      # Get grid index and u_hat
      grid_idx <- which(grid$p == wp & grid$q == wq & grid$case_num == cn)
      u_hat_raw <- u_hat_matrix[, grid_idx]

      # Normalize by mean
      u_hat_norm <- u_hat_raw / mean(u_hat_raw, na.rm = TRUE)

      # Build plot data
      plot_df <- data.frame(year = df$year, stringsAsFactors = FALSE)
      plot_df$u_hat <- u_hat_norm

      # Join canonical series
      plot_df <- plot_df |>
        left_join(canonical, by = "year")

      # Reshape for ggplot
      plot_long <- plot_df |>
        pivot_longer(cols = c(u_hat, uK_shaikh, uFRB),
                     names_to = "series", values_to = "u") |>
        mutate(series = case_when(
          series == "u_hat"     ~ paste0(spec_label, " [", ic_label, "]"),
          series == "uK_shaikh" ~ "Shaikh (2016)",
          series == "uFRB"      ~ "FRB"
        )) |>
        filter(is.finite(u))

      fig_title <- paste0("Capacity utilization: ", spec_label, " [", ic_label, "] vs Shaikh vs FRB")
      if (case_diagnostic) {
        fig_title <- paste0(fig_title, "\n[DIAGNOSTIC — Case 5 autonomous TC, theoretically inadmissible]")
      }

      p_fig <- ggplot(plot_long, aes(x = year, y = u, color = series, linetype = series)) +
        geom_line(linewidth = 0.9, na.rm = TRUE) +
        geom_hline(yintercept = 1, alpha = 0.35) +
        geom_vline(xintercept = DUMMY_YEARS, linetype = "dashed", alpha = 0.45) +
        theme_ch3() +
        theme(legend.position = "bottom", legend.title = element_blank()) +
        scale_color_manual(values = c(
          setNames(PAL_OI["vermillion"], paste0(spec_label, " [", ic_label, "]")),
          "Shaikh (2016)" = "black",
          "FRB" = PAL_OI["skyblue"]
        )) +
        scale_linetype_manual(values = c(
          setNames("solid", paste0(spec_label, " [", ic_label, "]")),
          "Shaikh (2016)" = "dashed",
          "FRB" = "dotted"
        )) +
        labs(
          x = "Year", y = "Capacity Utilization (u)",
          title = fig_title
        )

      fig_stem <- paste0("FIG_S0_redesign_u_ARDL", wp, wq, "_Case", cn)
      save_png_pdf_dual(p_fig, fig_stem, FIG_DIR, width = 11, height = 6.6)
      cat("Saved figure:", fig_stem, "\n")
    }
  }

  # Combined figure across all cases with winners
  all_winner_specs <- list()
  for (cn in fig_cases) {
    cn_str <- as.character(cn)
    case_winners <- winners_by_case[[cn_str]]
    if (length(case_winners) == 0) next
    wsd <- unique(sapply(case_winners, function(w) paste0(w$p, ",", w$q)))
    for (ws in wsd) all_winner_specs[[paste0(cn, "_", ws)]] <- list(cn = cn, ws = ws)
  }

  if (length(all_winner_specs) > 1) {
    plot_combined <- data.frame(year = df$year, stringsAsFactors = FALSE)
    plot_combined <- plot_combined |> left_join(canonical, by = "year")

    for (key in names(all_winner_specs)) {
      cn <- all_winner_specs[[key]]$cn
      ws <- all_winner_specs[[key]]$ws
      pq <- as.integer(strsplit(ws, ",")[[1]])
      grid_idx <- which(grid$p == pq[1] & grid$q == pq[2] & grid$case_num == cn)
      u_raw <- u_hat_matrix[, grid_idx]
      u_norm <- u_raw / mean(u_raw, na.rm = TRUE)
      col_name <- paste0("u_ARDL(", pq[1], ",", pq[2], ")_C", cn)
      plot_combined[[col_name]] <- u_norm
    }

    plot_comb_long <- plot_combined |>
      pivot_longer(-year, names_to = "series", values_to = "u") |>
      filter(is.finite(u))

    p_comb <- ggplot(plot_comb_long, aes(x = year, y = u, color = series)) +
      geom_line(linewidth = 0.8, na.rm = TRUE) +
      geom_hline(yintercept = 1, alpha = 0.35) +
      geom_vline(xintercept = DUMMY_YEARS, linetype = "dashed", alpha = 0.45) +
      theme_ch3() +
      theme(legend.position = "bottom", legend.title = element_blank()) +
      labs(
        x = "Year", y = "Capacity Utilization (u)",
        title = "S0 Redesign: All IC winners vs Shaikh vs FRB"
      )

    save_png_pdf_dual(p_comb, "FIG_S0_redesign_u_combined", FIG_DIR, width = 11, height = 6.6)
    cat("Saved figure: FIG_S0_redesign_u_combined\n")
  }
} else {
  cat("No IC winners — skipping utilization figure.\n")
}

# ============================================================
# STEP 11 — SAVE OUTPUTS
# ============================================================
cat("\n", paste(rep("=", 60), collapse = ""), "\n")
cat("STEP 11 — FINAL OUTPUT SUMMARY\n")
cat(paste(rep("=", 60), collapse = ""), "\n\n")

cat("Output directory:", EXERCISE_DIR, "\n")
cat("CSV files:\n")
cat("  ", file.path(CSV_DIR, "S0_redesign_full_grid.csv"), "\n")
if (n_admissible > 0) {
  cat("  ", file.path(CSV_DIR, "S0_redesign_admissible.csv"), "\n")
  if (length(all_winner_rows_for_csv) > 0) {
    cat("  ", file.path(CSV_DIR, "S0_redesign_ic_winners.csv"), "\n")
  }
}
cat("Report:\n")
cat("  ", report_path, "\n")
cat("Figures in:\n")
cat("  ", FIG_DIR, "\n\n")

# Repeat the vintage sensitivity finding in the final summary
if (n_admissible_c3 == 0 && n_admissible_c5 > 0) {
  cat(paste(rep("*", 70), collapse = ""), "\n")
  cat("FINDING: Cointegration is not recoverable under any Case 3 specification\n")
  cat("(capital-embodied TC). It is recoverable only under Case 5 (autonomous TC),\n")
  cat("which Shaikh's framework explicitly rejects. This confirms the vintage\n")
  cat("sensitivity finding and identifies the specific structural assumption that\n")
  cat("would need to hold for the methodology to apply to current-vintage data.\n")
  cat(paste(rep("*", 70), collapse = ""), "\n\n")
}

cat("STAGE_STATUS_HINT: stage=S0_redesign status=complete\n")
cat("\nDONE.\n")

# Close sink
try(sink(), silent = TRUE)
