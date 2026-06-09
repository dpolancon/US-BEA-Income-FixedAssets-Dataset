############################################################
# 61_validators_prod_cap.R — Validation Gate Functions
#
# Four gate functions for the Dataset 2 productive capital
# pipeline. Each returns list(pass, message, details).
# Gates do NOT stop() — the coordinator (62) decides.
#
# Authority:
#   - KSTOCK_Architecture_v1.md §4.3–4.4 (SFC rules)
#   - KSTOCK_Architecture_v1.md §8 (canonical values)
#
# Dependencies: dplyr
############################################################


# ==================================================================
# Gate 0: API Fetch Validation
# ==================================================================

#' Validate that all fetch results are non-NULL and contain data.
#'
#' @param results Named list of fetch results (from Phase 0)
#' @return list(pass, message, failed_accounts)
gate_check_API <- function(results) {
  failed <- character()

  for (nm in names(results)) {
    res <- results[[nm]]

    ## Check for NULL
    if (is.null(res)) {
      failed <- c(failed, sprintf("%s: NULL result", nm))
      next
    }

    ## For fetch agents returning lists with KNC/IG components
    if (is.list(res) && !is.data.frame(res)) {
      for (comp_nm in c("KNC", "KNR_idx", "IG")) {
        comp <- res[[comp_nm]]
        if (!is.null(comp) && is.data.frame(comp)) {
          if (nrow(comp) == 0) {
            failed <- c(failed, sprintf("%s$%s: 0 rows", nm, comp_nm))
          } else if (max(comp$year) < 2020) {
            failed <- c(failed,
              sprintf("%s$%s: year range ends at %d (expected >=2020)",
                      nm, comp_nm, max(comp$year)))
          }
        }
      }
      next
    }

    ## For data.frame results (income accounts, Py)
    if (is.data.frame(res)) {
      if (nrow(res) == 0) {
        failed <- c(failed, sprintf("%s: 0 rows", nm))
      } else if ("year" %in% names(res) && max(res$year) < 2020) {
        failed <- c(failed,
          sprintf("%s: year range ends at %d", nm, max(res$year)))
      }
    }
  }

  pass <- length(failed) == 0
  msg <- if (pass) {
    sprintf("Gate 0 PASS: All %d fetch results valid", length(results))
  } else {
    sprintf("Gate 0 FAIL: %d issues\n  %s",
            length(failed), paste(failed, collapse = "\n  "))
  }

  list(
    pass            = pass,
    message         = msg,
    failed_accounts = failed
  )
}


# ==================================================================
# Gate 1: Per-Account SFC Validation
# ==================================================================

#' Validate SFC residuals for each individual GPIM account.
#'
#' Checks that sfc_max_resid < 1e-4 for each account.
#' Also re-computes gross SFC as a cross-check.
#'
#' @param results Named list of GPIM account tibbles (from Phase 1)
#' @return list(pass, message, per_account)
gate_check_SFC_per_account <- function(results) {
  accounts <- data.frame(
    account       = character(),
    sfc_max       = numeric(),
    sfc_gross_max = numeric(),
    pass          = logical(),
    stringsAsFactors = FALSE
  )

  for (nm in names(results)) {
    df <- results[[nm]]

    ## Inline SFC residual (already computed in gpim_recursion)
    sfc_inline <- if ("sfc_max_resid" %in% names(df)) {
      max(df$sfc_max_resid, na.rm = TRUE)
    } else {
      NA_real_
    }

    ## Cross-check: recompute gross SFC from output columns
    TT <- nrow(df)
    if (TT > 1 && all(c("KGR", "IG_R", "rho") %in% names(df))) {
      KGR_lag <- c(df$KGR[1], df$KGR[-TT])  # use first as anchor
      implied <- KGR_lag + df$IG_R - df$rho * KGR_lag
      resid_gross <- max(abs(df$KGR[-1] - implied[-1]), na.rm = TRUE)
    } else {
      resid_gross <- NA_real_
    }

    acct_pass <- !is.na(sfc_inline) && sfc_inline < 1e-4

    accounts <- rbind(accounts, data.frame(
      account       = nm,
      sfc_max       = sfc_inline,
      sfc_gross_max = resid_gross,
      pass          = acct_pass,
      stringsAsFactors = FALSE
    ))
  }

  all_pass <- all(accounts$pass)
  msg <- if (all_pass) {
    sprintf("Gate 1 PASS: All %d accounts SFC < 1e-4", nrow(accounts))
  } else {
    failed <- accounts[!accounts$pass, ]
    sprintf("Gate 1 FAIL: %d account(s) violate SFC\n%s",
            nrow(failed),
            paste(sprintf("  %s: sfc=%.4e", failed$account, failed$sfc_max),
                  collapse = "\n"))
  }

  list(
    pass        = all_pass,
    message     = msg,
    per_account = accounts
  )
}


# ==================================================================
# Gate 2: Aggregate SFC Validation
# ==================================================================

#' Validate SFC for the productive capital stock (NF corporate only).
#'
#' KGR_NF_corp_t - KGR_NF_corp_{t-1} = IG_R_NF_corp_t - rho_NF_corp_t * KGR_NF_corp_{t-1}
#' Tolerance: 1e-3.
#'
#' @param prod tibble from aggregate_productive()
#' @return list(pass, message, max_resid, resid_series)
gate_check_SFC_aggregate <- function(prod) {
  TT <- nrow(prod)
  if (TT < 2) {
    return(list(pass = FALSE, message = "Gate 2: Insufficient rows",
                max_resid = NA, resid_series = NULL))
  }

  ## Gross SFC for NF corporate (= productive aggregate)
  KGR     <- prod$KGR_NF_corp
  KGR_lag <- c(KGR[1], KGR[-TT])
  IG_R    <- prod$IG_R_NF_corp
  Ret     <- prod$rho_NF_corp * KGR_lag

  implied_KGR <- KGR_lag + IG_R - Ret
  resid <- abs(KGR[-1] - implied_KGR[-1])
  max_resid <- max(resid, na.rm = TRUE)

  pass <- max_resid < 1e-3
  msg <- if (pass) {
    sprintf("Gate 2 PASS: NF_corp SFC max |resid| = %.6e", max_resid)
  } else {
    worst_idx <- which.max(resid) + 1
    sprintf("Gate 2 FAIL: NF_corp SFC max |resid| = %.6e at year %d",
            max_resid, prod$year[worst_idx])
  }

  list(
    pass         = pass,
    message      = msg,
    max_resid    = max_resid,
    resid_series = resid
  )
}


# ==================================================================
# Gate 3: Canonical Validation Values
# ==================================================================

#' Check mechanical properties of Dataset 2.
#'
#' - pK_productive_2017 = 100 (base year normalization)
#'
#' @param prod   tibble from aggregate_productive()
#' @param income tibble from build_income_accounts()
#' @return list(pass, message, pK_2017)
gate_check_canonical <- function(prod, income) {
  warnings <- character()

  ## pK base year normalization
  pK_2017 <- NA_real_
  if (2017 %in% prod$year) {
    pK_2017 <- prod$pK_productive[prod$year == 2017]
    if (abs(pK_2017 - 100) > 0.1) {
      warnings <- c(warnings,
        sprintf("pK_productive_2017 = %.2f (expected 100.00)", pK_2017))
    }
  }

  pass <- length(warnings) == 0
  msg <- if (pass) {
    sprintf("Gate 3 PASS: pK_2017 = %.2f", pK_2017)
  } else {
    sprintf("Gate 3 WARN: %d issue(s)\n  %s",
            length(warnings), paste(warnings, collapse = "\n  "))
  }

  list(
    pass    = pass,
    message = msg,
    pK_2017 = pK_2017
  )
}
