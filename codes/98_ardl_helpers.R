# ============================================================
# 98_ardl_helpers.R — ARDL/VECM/Envelope/Complexity helpers
#
# Consolidated helper module for Chapter 3 Critical Replication.
# Absorbs logic from former 24_complexity_penalties.R and
# 25_envelope_tools.R. Canonical column names only — no aliases.
#
# Contents:
#   1. Covariance sanitization & log-determinant
#   2. C1/ICOMP/RICOMP computation (Bozdogan 1990, 2016)
#   3. Canonical spec-row builder: make_spec_row()
#   4. Pareto frontier extraction: extract_envelope()
#   5. VECM q-profile generator: q_profiles_for_p()
#   6. Figure functions (S1/S2 fit-complexity plane)
#
# Date: 2026-03-11
# ============================================================

# ---- 1. Covariance sanitization & log-determinant ----

#' Sanitize a variance-covariance matrix: symmetrize, check PD,
#' ridge-stabilize if needed.
#' @param vcov_mat square numeric matrix
#' @param eps minimum eigenvalue threshold
#' @return list(ok, mat, flag, stabilized)
sanitize_vcov <- function(vcov_mat, eps = 1e-10) {
  M <- suppressWarnings(as.matrix(vcov_mat))

  if (length(M) == 0 || !is.matrix(M) || nrow(M) != ncol(M)) {
    return(list(ok = FALSE, mat = NA, flag = "invalid_vcov_shape", stabilized = FALSE))
  }

  if (any(!is.finite(M))) {
    return(list(ok = FALSE, mat = NA, flag = "non_finite_vcov", stabilized = FALSE))
  }

  M <- (M + t(M)) / 2

  ev <- tryCatch(eigen(M, symmetric = TRUE, only.values = TRUE)$values,
                 error = function(e) NA_real_)

  if (all(is.finite(ev)) && min(ev) > eps) {
    return(list(ok = TRUE, mat = M, flag = "ok", stabilized = FALSE))
  }

  ridge <- if (all(is.finite(ev))) max(eps, eps - min(ev) + eps) else eps
  M_stab <- M + diag(ridge, nrow(M))

  ev2 <- tryCatch(eigen(M_stab, symmetric = TRUE, only.values = TRUE)$values,
                  error = function(e) NA_real_)

  if (all(is.finite(ev2)) && min(ev2) > 0) {
    return(list(ok = TRUE, mat = M_stab, flag = "ridge_stabilized", stabilized = TRUE))
  }

  list(ok = FALSE, mat = M_stab, flag = "stabilization_failed", stabilized = TRUE)
}

#' Numerically stable log-determinant via Cholesky, with eigenvalue fallback.
#' @param M positive-definite square matrix
#' @return scalar log|M| or NA_real_ on failure
stable_logdet <- function(M) {
  chol_try <- tryCatch(chol(M), error = function(e) NULL)
  if (!is.null(chol_try)) {
    return(2 * sum(log(diag(chol_try))))
  }

  ev <- tryCatch(eigen(M, symmetric = TRUE, only.values = TRUE)$values,
                 error = function(e) NA_real_)
  if (!all(is.finite(ev)) || any(ev <= 0)) return(NA_real_)
  sum(log(ev))
}


# ---- 2. C1 / ICOMP / RICOMP ----

#' Core C1(Σ) computation: (k/2)*log(tr(Σ)/k) - (1/2)*log|Σ|
#' Bozdogan (1990) information complexity measure.
#' @param vcov_mat square positive-definite matrix
#' @param eps eigenvalue floor for sanitization
#' @return list(C1, k, flag, stabilized)
compute_c1_core <- function(vcov_mat, eps = 1e-10) {
  vc <- sanitize_vcov(vcov_mat, eps = eps)
  if (!isTRUE(vc$ok)) {
    return(list(C1 = NA_real_, k = NA_integer_, flag = vc$flag, stabilized = vc$stabilized))
  }

  k <- as.integer(nrow(vc$mat))
  trS <- sum(diag(vc$mat))
  logdetS <- stable_logdet(vc$mat)

  if (!is.finite(trS) || trS <= 0 || !is.finite(logdetS)) {
    return(list(C1 = NA_real_, k = k, flag = "c1_inputs_invalid", stabilized = vc$stabilized))
  }

  C1 <- (k / 2) * log(trS / k) - 0.5 * logdetS

  list(C1 = as.numeric(C1), k = k, flag = vc$flag, stabilized = vc$stabilized)
}

#' ICOMP penalty: 2*C1(F^{-1})
#' Feeds ICOMP = -2*logL + 2*C1(F^{-1})    (Bozdogan 1990)
#' @param vcov_mat model vcov matrix (F^{-1})
#' @return list(ICOMP_pen, ICOMP_flag, ICOMP_stabilized, ICOMP_k_sigma)
compute_icomp_penalty <- function(vcov_mat, eps = 1e-10) {
  c1 <- compute_c1_core(vcov_mat = vcov_mat, eps = eps)

  if (!is.finite(c1$C1)) {
    return(list(ICOMP_pen = NA_real_, ICOMP_flag = c1$flag,
                ICOMP_stabilized = c1$stabilized, ICOMP_k_sigma = c1$k))
  }

  list(
    ICOMP_pen        = 2 * c1$C1,
    ICOMP_flag       = c1$flag,
    ICOMP_stabilized = c1$stabilized,
    ICOMP_k_sigma    = c1$k
  )
}

#' RICOMP penalty: 2*C1(F^{-1} R F^{-1})
#' Sandwich covariance estimator — Bozdogan & Pamukçu (2016)
#' @param sandwich_mat sandwich vcov matrix (F^{-1} R F^{-1})
#' @return list(RICOMP_pen, RICOMP_flag, ...)
compute_RICOMP_penalty <- function(sandwich_mat, eps = 1e-10) {
  c1 <- compute_c1_core(vcov_mat = sandwich_mat, eps = eps)

  if (!is.finite(c1$C1)) {
    return(list(RICOMP_pen = NA_real_, RICOMP_flag = c1$flag,
                RICOMP_stabilized = c1$stabilized, RICOMP_k_sigma = c1$k))
  }

  list(
    RICOMP_pen        = 2 * c1$C1,
    RICOMP_flag       = c1$flag,
    RICOMP_stabilized = c1$stabilized,
    RICOMP_k_sigma    = c1$k
  )
}


# ---- 3. Canonical spec-row builder ----

#' Build one canonical row of the specification lattice.
#' Replaces BOTH versions of compute_complexity_record().
#' Canonical columns only: AIC, BIC, HQ, AICc, ICOMP, RICOMP,
#' neg2logL, k_total. No aliases.
#'
#' @param p lag order on y (or VAR lag order for VECM)
#' @param q lag order on k (or q-profile tag for VECM)
#' @param case PSS case (ARDL) or deterministic branch tag (VECM)
#' @param s dummy structure tag (s0/s1/s2/s3 or h0/h1/h2)
#' @param logLik scalar log-likelihood
#' @param k_total integer total number of estimated parameters
#' @param T_eff integer effective sample size
#' @param vcov_mat model vcov matrix (for ICOMP); NULL if unavailable
#' @param sandwich_mat sandwich vcov (for RICOMP); NULL if unavailable
#' @return single-row data.frame with canonical IC columns
make_spec_row <- function(p, q, case, s, logLik, k_total, T_eff,
                          vcov_mat = NULL, sandwich_mat = NULL) {
  neg2logL <- -2 * as.numeric(logLik)
  k <- as.numeric(k_total)
  T_ <- as.numeric(T_eff)

  AIC_val  <- neg2logL + 2 * k
  BIC_val  <- neg2logL + log(T_) * k
  HQ_val   <- neg2logL + 2 * log(log(T_)) * k
  AICc_val <- if (T_ > k + 1) AIC_val + (2 * k * (k + 1)) / (T_ - k - 1) else NA_real_

  # ICOMP = -2*logL + 2*C1(F^{-1})
  ICOMP_val <- NA_real_
  if (!is.null(vcov_mat)) {
    icomp <- compute_icomp_penalty(vcov_mat)
    if (is.finite(icomp$ICOMP_pen)) {
      ICOMP_val <- neg2logL + icomp$ICOMP_pen
    }
  }

  # RICOMP = -2*logL + 2*C1(F^{-1} R F^{-1})
  RICOMP_val <- NA_real_
  if (!is.null(sandwich_mat)) {
    icomp_m <- compute_RICOMP_penalty(sandwich_mat)
    if (is.finite(icomp_m$RICOMP_pen)) {
      RICOMP_val <- neg2logL + icomp_m$RICOMP_pen
    }
  }

  data.frame(
    p        = p,
    q        = q,
    case     = case,
    s        = s,
    neg2logL = neg2logL,
    k_total  = k,
    T_eff    = T_,
    logLik   = as.numeric(logLik),
    AIC      = AIC_val,
    BIC      = BIC_val,
    HQ       = HQ_val,
    AICc     = AICc_val,
    ICOMP    = ICOMP_val,
    RICOMP = RICOMP_val,
    stringsAsFactors = FALSE
  )
}


# ---- 4. Pareto frontier extraction (from former 25_envelope_tools.R) ----

#' Extract Pareto non-dominated envelope in the fit-complexity plane.
#' For each unique x value, keep the row with the highest y.
#' Then filter to the running-max envelope.
#'
#' @param df data.frame with at least columns x_col and y_col
#' @param x_col character: column name for x-axis (default "k_total")
#' @param y_col character: column name for y-axis (default "logLik")
#' @return data.frame: envelope subset of df
extract_envelope <- function(df, x_col = "k_total", y_col = "logLik") {
  stopifnot(is.data.frame(df), is.character(x_col), is.character(y_col))
  stopifnot(length(x_col) == 1L, length(y_col) == 1L)
  stopifnot(x_col %in% names(df), y_col %in% names(df))

  df_env <- df |>
    dplyr::filter(is.finite(.data[[x_col]]), is.finite(.data[[y_col]])) |>
    dplyr::arrange(.data[[x_col]], dplyr::desc(.data[[y_col]])) |>
    dplyr::group_by(.data[[x_col]]) |>
    dplyr::slice(1L) |>
    dplyr::ungroup() |>
    dplyr::arrange(.data[[x_col]])

  if (nrow(df_env) == 0L) {
    return(df_env)
  }

  keep <- df_env[[y_col]] >= cummax(df_env[[y_col]])
  df_env[keep, , drop = FALSE] |>
    dplyr::arrange(.data[[x_col]])
}


# ---- 5. VECM q-profile generator ----

#' Generate short-run memory allocation profiles for VECM lattice.
#' Asymmetric lag allocation across state variables.
#'
#' For m=2 (bivariate): profiles over (qY, qK)
#' For m=3 (trivariate): profiles over (qY, qK, qE)
#'
#' @param p integer lag depth (VAR order)
#' @param m integer system dimension (2 or 3)
#' @return data.frame with columns q_tag, qY, qK, (qE if m=3)
q_profiles_for_p <- function(p, m = 2L) {
  if (m == 2L) {
    data.frame(
      q_tag = c("sym", "Y_only", "K_only"),
      qY = c(p, p, 0L),
      qK = c(p, 0L, p),
      stringsAsFactors = FALSE
    )
  } else if (m == 3L) {
    data.frame(
      q_tag = c("sym", "Y_only", "K_only", "E_only", "YK", "YE", "KE"),
      qY = c(p, p, 0L, 0L, p, p, 0L),
      qK = c(p, 0L, p, 0L, p, 0L, p),
      qE = c(p, 0L, 0L, p, 0L, p, p),
      stringsAsFactors = FALSE
    )
  } else {
    stop("q_profiles_for_p: m must be 2 or 3, got ", m)
  }
}


# ---- 6. Figure functions for fit-complexity plane ----

#' Plot fit-complexity cloud (S1.1 / S2.1 backbone)
#' @param df data.frame with at least k_total, neg2logL columns
#' @param m0 optional single-row data.frame for the benchmark point
#' @param envelope optional data.frame from extract_envelope()
#' @param title character plot title
#' @return ggplot2 object
plot_fitcomplexity_cloud <- function(df, m0 = NULL, envelope = NULL,
                                     title = "Fit-Complexity Cloud") {
  p <- ggplot2::ggplot(df, ggplot2::aes(x = .data$k_total, y = .data$neg2logL)) +
    ggplot2::geom_point(alpha = 0.3, color = "grey60") +
    ggplot2::theme_minimal() +
    ggplot2::labs(x = expression(k(m)), y = expression(-2 * log * L(m)),
                  title = title)

  if (!is.null(envelope) && nrow(envelope) > 0) {
    p <- p + ggplot2::geom_line(data = envelope,
                                 ggplot2::aes(x = .data$k_total, y = .data$neg2logL),
                                 color = "darkred", linewidth = 0.8)
  }

  if (!is.null(m0) && nrow(m0) > 0) {
    p <- p + ggplot2::geom_point(data = m0,
                                  ggplot2::aes(x = .data$k_total, y = .data$neg2logL),
                                  shape = 8, size = 4, color = "blue")
  }

  p
}

#' Plot IC tangency winners (S1.2 / S2.2 backbone)
#' @param df data.frame with full admissible cloud
#' @param winners named list of single-row data.frames (AIC, BIC, HQ, ICOMP, RICOMP)
#' @param envelope optional Pareto frontier
#' @param m0 optional benchmark point
#' @param title character plot title
#' @return ggplot2 object
plot_ic_tangencies <- function(df, winners, envelope = NULL, m0 = NULL,
                               title = "IC Tangency Points") {
  ic_colors <- c(AIC = "#E41A1C", BIC = "#377EB8", HQ = "#4DAF4A",
                 ICOMP = "#984EA3", RICOMP = "#FF7F00")
  ic_shapes <- c(AIC = 15, BIC = 16, HQ = 17, ICOMP = 18, RICOMP = 4)

  p <- ggplot2::ggplot(df, ggplot2::aes(x = .data$k_total, y = .data$neg2logL)) +
    ggplot2::geom_point(alpha = 0.15, color = "grey70") +
    ggplot2::theme_minimal() +
    ggplot2::labs(x = expression(k(m)), y = expression(-2 * log * L(m)),
                  title = title)

  if (!is.null(envelope) && nrow(envelope) > 0) {
    p <- p + ggplot2::geom_line(data = envelope,
                                 ggplot2::aes(x = .data$k_total, y = .data$neg2logL),
                                 color = "grey30", linewidth = 0.6)
  }

  for (ic_name in names(winners)) {
    w <- winners[[ic_name]]
    if (!is.null(w) && nrow(w) > 0) {
      p <- p + ggplot2::geom_point(
        data = w,
        ggplot2::aes(x = .data$k_total, y = .data$neg2logL),
        color = ic_colors[ic_name], shape = ic_shapes[ic_name], size = 4
      )
    }
  }

  if (!is.null(m0) && nrow(m0) > 0) {
    p <- p + ggplot2::geom_point(data = m0,
                                  ggplot2::aes(x = .data$k_total, y = .data$neg2logL),
                                  shape = 8, size = 4, color = "blue")
  }

  # Build a legend manually from annotation labels
  label_df <- do.call(rbind, lapply(names(winners), function(ic_name) {
    w <- winners[[ic_name]]
    if (!is.null(w) && nrow(w) > 0) {
      data.frame(x = w$k_total[1], y = w$neg2logL[1], ic = ic_name,
                 stringsAsFactors = FALSE)
    }
  }))
  if (!is.null(label_df) && nrow(label_df) > 0) {
    p <- p + ggplot2::annotate("text", x = label_df$x, y = label_df$y,
                                label = label_df$ic, hjust = -0.3, vjust = -0.5,
                                size = 3, fontface = "bold",
                                color = ic_colors[label_df$ic])
  }

  p
}

#' Plot informational domain (S1.3 / S2.3 backbone)
#' @param df data.frame with full admissible cloud
#' @param frontier_df data.frame with specs in F^(0.20) or Omega_20
#' @param envelope optional Pareto frontier
#' @param m0 optional benchmark point
#' @param title character plot title
#' @return ggplot2 object
plot_informational_domain <- function(df, frontier_df, envelope = NULL, m0 = NULL,
                                      title = "Informational Domain") {
  p <- ggplot2::ggplot(df, ggplot2::aes(x = .data$k_total, y = .data$neg2logL)) +
    ggplot2::geom_point(alpha = 0.15, color = "grey70") +
    ggplot2::theme_minimal() +
    ggplot2::labs(x = expression(k(m)), y = expression(-2 * log * L(m)),
                  title = title)

  if (!is.null(frontier_df) && nrow(frontier_df) > 0) {
    p <- p + ggplot2::geom_point(
      data = frontier_df,
      ggplot2::aes(x = .data$k_total, y = .data$neg2logL),
      color = "#FF7F00", alpha = 0.6, size = 2
    )
  }

  if (!is.null(envelope) && nrow(envelope) > 0) {
    p <- p + ggplot2::geom_line(data = envelope,
                                 ggplot2::aes(x = .data$k_total, y = .data$neg2logL),
                                 color = "darkred", linewidth = 0.6)
  }

  if (!is.null(m0) && nrow(m0) > 0) {
    p <- p + ggplot2::geom_point(data = m0,
                                  ggplot2::aes(x = .data$k_total, y = .data$neg2logL),
                                  shape = 8, size = 4, color = "blue")
  }

  n_frontier <- if (!is.null(frontier_df)) nrow(frontier_df) else 0
  p <- p + ggplot2::annotate("text", x = Inf, y = Inf,
                              label = paste0("n = ", n_frontier, " specs"),
                              hjust = 1.1, vjust = 1.5, size = 3.5, color = "grey30")
  p
}


# codes/98_ardl_runner.R
# Minimal ARDL(2,4) Case 3 runner for grid search
# Args: df (with lnY, lnK, d1956, d1974, d1980), window
# Returns: list(theta, a, c_d56, c_d74, c_d80, AIC, loglik)
run_ardl_case_S0helper <- function(df, window = c(1947, 2011)) {
  df <- df |> filter(year >= window[1], year <= window[2])
  df_ts <- ts(df |> select(lnY, lnK, d1956, d1974, d1980),
              start = min(df$year), frequency = 1)
  fit <- ARDL::ardl(lnY ~ lnK | d1956 + d1974 + d1980,
                    data = df_ts, order = c(2, 4))
  lr  <- ARDL::multipliers(fit, type = "lr")
  get_lr <- function(term) {
    r <- lr[lr$Term == term, "Estimate"]
    if (length(r)) r else NA_real_
  }
  list(
    theta  = get_lr("lnK"),
    a      = get_lr("(Intercept)"),
    c_d56  = get_lr("d1956"),
    c_d74  = get_lr("d1974"),
    c_d80  = get_lr("d1980"),
    AIC    = AIC(fit),
    loglik = as.numeric(logLik(fit))
  )
}
# ============================================================
# END 98_ardl_helpers.R
# ============================================================
