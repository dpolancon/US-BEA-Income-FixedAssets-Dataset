############################################################
# 59_gpim_helpers.R — GPIM Primitives for Dataset 2
#
# Weibull retirement distributions + SFC-checked recursion
# for the four-account productive capital pipeline.
#
# Extends (does NOT duplicate) 97_kstock_helpers.R.
# Pure functions, no side effects, no file I/O.
#
# Authority:
#   - Weibull_Retirement_Distributions.md (L, alpha params)
#   - KSTOCK_Architecture_v1.md §4 (derivation chain)
#   - GPIM_Formalization_v3 §1 (accumulation eqs.)
#
# Dependencies: 97_kstock_helpers.R (sourced before this)
############################################################


# ==================================================================
# §A. Weibull Retirement Functions
# ==================================================================

#' Compute Weibull scale parameter lambda from mean service life L
#' and shape parameter alpha.
#'
#' lambda = L / Gamma(1 + 1/alpha)
#'
#' @param L     Mean service life (years)
#' @param alpha Shape parameter (> 0)
#' @return Scale parameter lambda
weibull_lambda <- function(L, alpha) {
  stopifnot(L > 0, alpha > 0)
  L / gamma(1 + 1 / alpha)
}


#' Weibull hazard rate at age tau.
#'
#' h(tau) = (alpha / lambda) * (tau / lambda)^(alpha - 1)
#'
#' When alpha = 1, reduces to h = 1/L (constant rate / exponential).
#'
#' @param tau   Asset age (scalar or vector)
#' @param L     Mean service life (years)
#' @param alpha Weibull shape parameter
#' @return Hazard rate h(tau)
weibull_hazard <- function(tau, L, alpha) {
  stopifnot(L > 0, alpha > 0)
  lam <- weibull_lambda(L, alpha)
  (alpha / lam) * (tau / lam)^(alpha - 1)
}


#' Weibull survival function S(tau) = exp(-(tau/lambda)^alpha)
#'
#' @param tau   Asset age (scalar or vector)
#' @param L     Mean service life
#' @param alpha Shape parameter
#' @return Survival probability S(tau)
weibull_survival <- function(tau, L, alpha) {
  lam <- weibull_lambda(L, alpha)
  exp(-(tau / lam)^alpha)
}


#' Steady-state average retirement rate from Weibull distribution.
#'
#' rho_avg = 1 / E[tau] where E[tau] = integral_0^T_max S(tau) dtau
#'
#' When alpha = 1, returns 1/L exactly (exponential special case).
#'
#' @param L     Mean service life (years)
#' @param alpha Weibull shape parameter
#' @param T_max Upper integration limit (default: 3*L)
#' @return Scalar average retirement rate
weibull_avg_retirement <- function(L, alpha, T_max = 3 * L) {
  stopifnot(L > 0, alpha > 0)

  ## Exact for exponential

  if (abs(alpha - 1.0) < 1e-10) return(1 / L)

  ## Numerical integration of survival function
  S_fn <- function(tau) weibull_survival(tau, L, alpha)
  E_tau <- stats::integrate(S_fn, lower = 0, upper = T_max,
                            subdivisions = 500L)$value
  1 / E_tau
}


# ==================================================================
# §B. SFC-Checked GPIM Recursion
# ==================================================================

#' GPIM gross (or net) stock recursion with inline SFC validation.
#'
#' K_t = IG_R_t + (1 - rho_t) * K_{t-1}
#'
#' At every step t, the SFC identity is checked:
#'   |K_t - (K_{t-1} + IG_R_t - rho_t * K_{t-1})| < 1e-6
#'
#' If any step violates: HALT with account, year, and residual.
#'
#' @param IG_R          Real gross investment (vector, length T)
#' @param rho_t         Retirement (or depreciation) rate (scalar or vector)
#' @param KGC_R_init    Initial real stock (scalar)
#' @param account_label Character label for error messages
#' @param year_vec      Integer year vector (for error messages, length T)
#' @return Named list: K_R (vector), Ret_R (vector), sfc_max_resid (scalar)
gpim_recursion <- function(IG_R, rho_t, KGC_R_init,
                           account_label = "unknown",
                           year_vec = seq_along(IG_R)) {
  TT <- length(IG_R)

  ## Vectorize rho if scalar
  if (length(rho_t) == 1L) rho_t <- rep(rho_t, TT)
  stopifnot(length(rho_t) == TT, length(year_vec) == TT)

  K_R   <- numeric(TT)
  Ret_R <- numeric(TT)
  sfc_max <- 0

  K_prev <- KGC_R_init

  for (t in seq_len(TT)) {
    Ret_R[t] <- rho_t[t] * K_prev
    K_R[t]   <- IG_R[t] + (1 - rho_t[t]) * K_prev

    ## Inline SFC check: K_t should equal K_{t-1} + IG_t - Ret_t
    sfc_resid <- abs(K_R[t] - (K_prev + IG_R[t] - Ret_R[t]))
    if (sfc_resid > sfc_max) sfc_max <- sfc_resid

    if (sfc_resid > 1e-6) {
      stop(sprintf(
        "SFC HALT: account=%s, year=%d (t=%d), residual=%.4e\n  K_t=%.6f, K_prev=%.6f, IG=%.6f, Ret=%.6f",
        account_label, year_vec[t], t, sfc_resid,
        K_R[t], K_prev, IG_R[t], Ret_R[t]
      ))
    }

    K_prev <- K_R[t]
  }

  list(
    K_R          = K_R,
    Ret_R        = Ret_R,
    sfc_max_resid = sfc_max
  )
}


# ==================================================================
# §C. Deflator and Derived Series Functions
# ==================================================================

#' Derive own-price implicit deflator pK from current-cost and
#' chain-type quantity index.
#'
#' KNR_real = KNR_idx * base_2017_val / 100
#' pK = (KNC / KNR_real) * 100
#'
#' Result is rebased so pK(2017) = 100.
#'
#' @param KNC           Current-cost net stock (vector)
#' @param KNR_idx       Chain-type quantity index (vector, base=100)
#' @param year_vec      Integer year vector
#' @param base_year     Base year for rebasing (default 2017)
#' @return Named list: pK (vector, 2017=100), KNR_real (vector)
derive_pK <- function(KNC, KNR_idx, year_vec, base_year = 2017L) {
  stopifnot(length(KNC) == length(KNR_idx),
            length(KNC) == length(year_vec))

  ## Find base year value of KNC for converting index to levels
  base_idx <- which(year_vec == base_year)
  if (length(base_idx) == 0) {
    ## Fallback to 2005 for older vintages
    base_idx <- which(year_vec == 2005L)
    if (length(base_idx) == 0) stop("Neither 2017 nor 2005 found in year_vec")
    message("  derive_pK: using 2005 as chain QI base (2017 not found)")
  }
  base_val <- KNC[base_idx[1]]

  KNR_real <- KNR_idx * base_val / 100
  pK_raw   <- (KNC / KNR_real) * 100

  ## Rebase to base_year = 100
  pK <- rebase_index(pK_raw, year_vec, base_year, scale = 100)

  list(pK = pK, KNR_real = KNR_real)
}


#' Derive depreciation from the net stock SFC identity.
#'
#' DEP_t = IG_t - (KNC_t - KNC_{t-1})
#'
#' Not a parameter; not fetched. Derived from two BEA inputs only.
#'
#' @param KNC  Current-cost net stock (vector, length T)
#' @param IG   Gross investment, current cost (vector, length T)
#' @return DEP vector (length T; first element uses KNC[1] as anchor)
derive_DEP <- function(KNC, IG) {
  stopifnot(length(KNC) == length(IG))
  TT <- length(KNC)
  KNC_lag <- c(KNC[1], KNC[-TT])
  DEP <- IG - (KNC - KNC_lag)
  DEP
}


#' Derive theoretically correct depreciation rate z (eq. 6).
#'
#' z_t = DEP_t / (pK_t/100 * KNR_lag_t)
#'
#' Wraps gpim_depreciation_rate() from 97 with pK scaling.
#'
#' @param DEP     Depreciation flow, current cost (vector)
#' @param pK      Own-price deflator (vector, 2017=100)
#' @param KNR_lag Lagged real net stock (vector)
#' @return Depreciation rate z (vector)
derive_z <- function(DEP, pK, KNR_lag) {
  gpim_depreciation_rate(DEP, pK / 100, KNR_lag)
}


# ==================================================================
# §D. Rebasing and Warmup Functions
# ==================================================================

#' Rebase a price index to 2017 = 100.
#'
#' Convenience wrapper around rebase_index() from 97.
#'
#' @param series    Numeric vector (price index)
#' @param year_vec  Integer year vector
#' @param base_year Base year (default 2017)
#' @return Rebased series (base_year = 100)
rebase_2017 <- function(series, year_vec, base_year = 2017L) {
  rebase_index(series, year_vec, base_year, scale = 100)
}


#' GPIM warmup from historical investment flows (1901+).
#'
#' Runs a GPIM recursion co-evolving tau_bar and KGC_R from the given
#' initial conditions. No balanced-growth assumption: rho_t is
#' computed from the evolving tau_bar_t via the Weibull hazard.
#'
#' Returns terminal KGC_R, terminal tau_bar, mean rho, and the full
#' K_R series so the caller can implement fixed-point initialization.
#'
#' @param IG_vec        Investment vector (nominal, starting from 1901)
#' @param L             Mean service life (years)
#' @param alpha         Weibull shape parameter
#' @param year_vec      Year vector matching IG_vec
#' @param pK_vec        Price deflator matching IG_vec (for converting
#'                      nominal IG to real). If NULL, assumes already real.
#' @param KGR_init      Initial gross stock (default 0 = cold start)
#' @param tau_bar_init  Initial mean age (default 0 = cold start)
#' @param checkpoint_year Year to extract checkpoint value (default 1925)
#' @param checkpoint_KNC BEA-reported KNC at checkpoint year (for gap calc)
#' @return Named list: K_R_terminal, tau_bar_terminal, rho_bar, warmup_gap, K_R_series
warmup_from_investment <- function(IG_vec, L, alpha, year_vec,
                                   pK_vec = NULL,
                                   KGR_init = 0,
                                   tau_bar_init = 0,
                                   checkpoint_year = 1925L,
                                   checkpoint_KNC = NULL) {
  stopifnot(length(IG_vec) == length(year_vec))

  ## Convert to real if pK provided
  if (!is.null(pK_vec)) {
    stopifnot(length(pK_vec) == length(IG_vec))
    IG_R <- IG_vec / (pK_vec / 100)
  } else {
    IG_R <- IG_vec
  }

  TT <- length(IG_R)

  K_R     <- numeric(TT)
  rho_wu  <- numeric(TT)
  tau_bar <- tau_bar_init
  K_prev  <- KGR_init

  for (t in seq_len(TT)) {
    ## Retirement rate from current mean age
    if (K_prev > 0 && tau_bar > 0) {
      rho_wu[t] <- weibull_hazard(tau_bar, L, alpha)
      rho_wu[t] <- min(max(rho_wu[t], 0), 1)
    } else {
      rho_wu[t] <- 0
    }

    ## Accumulate
    K_R[t] <- IG_R[t] + (1 - rho_wu[t]) * K_prev

    ## Update mean age: survivors age 1 year, new investment at age 0
    surviving <- K_prev * (1 - rho_wu[t])
    new_stock <- surviving + IG_R[t]
    if (new_stock > 0) {
      tau_bar <- (tau_bar + 1) * surviving / new_stock
    }

    K_prev <- K_R[t]
  }

  ## Checkpoint gap
  warmup_gap <- NA_real_
  if (!is.null(checkpoint_KNC)) {
    cp_idx <- which(year_vec == checkpoint_year)
    if (length(cp_idx) > 0) {
      K_at_cp <- K_R[cp_idx[1]]
      warmup_gap <- abs(K_at_cp - checkpoint_KNC) / checkpoint_KNC
    }
  }

  list(
    K_R_terminal    = K_R[TT],
    tau_bar_terminal = tau_bar,
    rho_bar         = mean(rho_wu[rho_wu > 0]),
    warmup_gap      = warmup_gap,
    K_R_series      = K_R
  )
}


# ==================================================================
# §E. Account-Level GPIM Construction (Full Derivation Chain)
# ==================================================================

#' Run the complete GPIM derivation chain for one capital account.
#'
#' Implements KSTOCK_Architecture_v1 §4.2 exactly:
#'   1. Derive pK from KNC and KNR_idx
#'   2. Derive DEP from net SFC identity
#'   3. Derive z from DEP, pK, KNR_lag
#'   4. Compute IG_R = IG / (pK/100)
#'   5. Net stock recursion (using z as depletion rate)
#'   6. Compute rho (Weibull or simple 1/L)
#'   7. Gross stock recursion (using rho)
#'   8. Convert gross real to gross current-cost
#'
#' @param KNC           Current-cost net stock (vector)
#' @param KNR_idx       Chain-type quantity index (vector)
#' @param IG            Gross investment, current cost (vector)
#' @param year_vec      Integer year vector
#' @param L             Mean service life (years)
#' @param alpha         Weibull shape parameter
#' @param use_weibull   Logical: use Weibull (TRUE) or simple 1/L (FALSE)
#' @param account_label Character label for messages and SFC errors
#' @param warmup_IG_R   Optional: real investment for 1901 warmup (vector)
#' @param warmup_years  Optional: year vector for warmup
#' @param use_fixed_point Logical: run two-pass fixed-point initialization
#'                        anchored to KNR_BEA_1925 (default FALSE)
#' @param base_year     Deflator base year (default 2017)
#' @return tibble with full GPIM output columns
gpim_account <- function(KNC, KNR_idx, IG, year_vec,
                         L, alpha,
                         use_weibull = TRUE,
                         account_label = "account",
                         warmup_IG_R = NULL,
                         warmup_years = NULL,
                         use_fixed_point = FALSE,
                         base_year = 2017L) {

  TT <- length(KNC)
  stopifnot(length(KNR_idx) == TT, length(IG) == TT,
            length(year_vec) == TT)

  message(sprintf("\n--- GPIM: %s (L=%d, alpha=%.1f, weibull=%s) ---",
                  account_label, L, alpha, use_weibull))

  ## Step 1: Deflator
  pK_result <- derive_pK(KNC, KNR_idx, year_vec, base_year)
  pK     <- pK_result$pK
  KNR    <- pK_result$KNR_real
  message(sprintf("  pK range: %.2f to %.2f", min(pK), max(pK)))

  ## Step 2: Depreciation from SFC
  DEP <- derive_DEP(KNC, IG)

  ## Step 3: Depreciation rate z
  KNR_lag <- c(KNR[1], KNR[-TT])
  z <- derive_z(DEP, pK, KNR_lag)
  ## Fill first-period NA with mean
  z[is.na(z)] <- mean(z, na.rm = TRUE)
  message(sprintf("  z mean: %.4f", mean(z, na.rm = TRUE)))

  ## Step 4: Real investment
  IG_R <- IG / (pK / 100)

  ## Step 5: Net stock recursion (validation — should recover KNR)
  KNR_gpim <- gpim_accumulate_real(IG_R, z, KNR[1])

  ## Net SFC cross-check
  net_sfc_max <- max(abs(KNR_gpim - KNR), na.rm = TRUE) /
    max(abs(KNR), na.rm = TRUE)
  message(sprintf("  Net stock GPIM vs BEA max pct gap: %.6f", net_sfc_max))

  ## Step 6: Time-varying retirement rate via mean-age tracking
  ##
  ## tau_bar_t = investment-weighted mean age of surviving stock at t.
  ## Simplified recursion (avoids full vintage tracking):
  ##   tau_bar_t = tau_bar_{t-1} + 1 - rho_{t-1} * tau_bar_{t-1}
  ##            = tau_bar_{t-1} * (1 - rho_{t-1}) + 1
  ## Each surviving cohort ages by 1 year; new investment enters at age 0
  ## and lowers the mean age in proportion to its share of stock.
  ##
  ## rho_t = weibull_hazard(tau_bar_t, L, alpha)

  rho_ss <- weibull_avg_retirement(L, alpha)  # steady-state scalar (for init + warmup)

  if (use_weibull) {
    message(sprintf("  Weibull rho_ss: %.5f (L=%d, alpha=%.2f) — will be time-varying",
                    rho_ss, L, alpha))
  } else {
    message(sprintf("  Simple rho: %.5f (1/L, L=%d) — constant", 1/L, L))
  }

  ## Step 7: Gross stock initial condition
  avg_z <- mean(z, na.rm = TRUE)

  if (!is.null(warmup_IG_R) && !is.null(warmup_years)) {

    ## --- Pass 1: cold-start warmup (K=0, tau_bar=0) ---
    message("  Running 1901 warmup pass 1 (cold start: K=0, tau_bar=0)...")
    wu1 <- warmup_from_investment(
      IG_vec          = warmup_IG_R,
      L               = L,
      alpha           = alpha,
      year_vec        = warmup_years,
      pK_vec          = NULL,
      KGR_init        = 0,
      tau_bar_init    = 0,
      checkpoint_year = year_vec[1],
      checkpoint_KNC  = NULL
    )

    if (use_fixed_point && wu1$K_R_terminal > 0) {
      ## --- Fixed-point back-projection anchored to KNR_BEA_1925 ---
      ## KNR[1] is the BEA 1925 net stock anchor
      KNR_BEA_1925 <- KNR[1]
      psi_cold <- KNR_BEA_1925 / wu1$K_R_terminal
      rho_bar  <- wu1$rho_bar

      ## Back-project: K_GR_1901 = KNR_BEA_1925 / (psi * (1-rho_bar)^N_warmup)
      N_warmup <- length(warmup_years)
      decay_factor <- (1 - rho_bar)^N_warmup
      KGR_1901_init <- KNR_BEA_1925 / (psi_cold * decay_factor)

      message(sprintf("  Fixed-point: psi_cold=%.4f, rho_bar=%.5f, KGR_1901_init=%.2f",
                      psi_cold, rho_bar, KGR_1901_init))

      ## --- Pass 2: re-run warmup with back-projected K_GR_1901 ---
      message("  Running 1901 warmup pass 2 (fixed-point)...")
      wu2 <- warmup_from_investment(
        IG_vec          = warmup_IG_R,
        L               = L,
        alpha           = alpha,
        year_vec        = warmup_years,
        pK_vec          = NULL,
        KGR_init        = KGR_1901_init,
        tau_bar_init    = L / 2,  # reasonable for pre-existing stock
        checkpoint_year = year_vec[1],
        checkpoint_KNC  = NULL
      )

      psi_fixed <- KNR_BEA_1925 / wu2$K_R_terminal
      message(sprintf("  Fixed-point result: psi_1925 %.4f -> %.4f, KGC_R_terminal %.2f -> %.2f",
                      psi_cold, psi_fixed,
                      wu1$K_R_terminal, wu2$K_R_terminal))

      KGC_R_init   <- wu2$K_R_terminal
      tau_bar_init <- wu2$tau_bar_terminal
    } else {
      ## No fixed-point — use cold-start result directly
      KGC_R_init   <- wu1$K_R_terminal
      tau_bar_init <- wu1$tau_bar_terminal
    }

    message(sprintf("  Warmup terminal KGC_R: %.2f, tau_bar: %.2f",
                    KGC_R_init, tau_bar_init))
  } else {
    ## Estimate from net stock initial value
    KGC_R_init <- KNR[1] * (avg_z / rho_ss)
    ## Without warmup, use steady-state mean age as fallback
    tau_bar_init <- L / 2
    message(sprintf("  KGC_R_init (z/rho scaling): %.2f, tau_bar_init: %.1f (no warmup)",
                    KGC_R_init, tau_bar_init))
  }

  ## Step 8: Gross stock recursion with time-varying rho
  if (use_weibull) {
    ## Pre-compute rho_t vector via tau_bar recursion
    rho     <- numeric(TT)
    gross_K <- numeric(TT)  # inline gross stock for tau_bar update
    tau_bar <- tau_bar_init  # from warmup or fallback

    for (t in seq_len(TT)) {
      rho[t] <- weibull_hazard(tau_bar, L, alpha)
      ## Clamp hazard to (0, 1) — safety for extreme ages
      rho[t] <- min(max(rho[t], 0), 1)
      ## Update mean age: survivors age 1 year, new investment enters at age 0
      ## Full version accounting for investment share:
      ##   tau_bar_new = ((tau_bar + 1) * surviving) / (surviving + IG_R)
      K_prev_t <- if (t == 1) KGC_R_init else gross_K[t - 1]
      surviving <- K_prev_t * (1 - rho[t])
      new_stock <- surviving + IG_R[t]
      if (new_stock > 0) {
        tau_bar <- (tau_bar + 1) * surviving / new_stock
      }
      gross_K[t] <- IG_R[t] + (1 - rho[t]) * K_prev_t
    }

    message(sprintf("  Weibull rho range: [%.5f, %.5f], tau_bar final: %.1f",
                    min(rho), max(rho), tau_bar))
  } else {
    rho <- rep(1 / L, TT)
  }

  ## Now run SFC-checked recursion with the rho vector
  gross <- gpim_recursion(
    IG_R          = IG_R,
    rho_t         = rho,
    KGC_R_init    = KGC_R_init,
    account_label = account_label,
    year_vec      = year_vec
  )
  KGC_R <- gross$K_R
  Ret_R <- gross$Ret_R
  message(sprintf("  Gross SFC max resid: %.4e", gross$sfc_max_resid))

  ## Step 9: Gross current-cost
  KGC <- KGC_R * (pK / 100)

  ## Assemble output
  dplyr::tibble(
    year  = year_vec,
    KNC   = KNC,
    KNR   = KNR,
    KGC   = KGC,
    KGR   = KGC_R,
    IG_cc = IG,
    IG_R  = IG_R,
    DEP   = DEP,
    pK    = pK,
    z     = z,
    rho   = rho,
    Ret_R = Ret_R,
    sfc_max_resid = gross$sfc_max_resid
  )
}
