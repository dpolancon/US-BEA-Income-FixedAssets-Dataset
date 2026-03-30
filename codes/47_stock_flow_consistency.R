############################################################
# 47_stock_flow_consistency.R — SFC Validation + Deflator Tests
#
# Part A: Stock-flow consistency validation
#   For each asset and valuation, check:
#     residual_t = K_t - (K_{t-1} + I_t - D_t)
#   Current-cost: residual = revaluation (expected)
#   Chain-weighted: residual = index artifact (Shaikh's point)
#   GPIM-deflated: residual ~ 0 (validates GPIM)
#
# Part B: Deflator-comparison protocol (§7.5-7.6)
#   T1: Wedge trend test (Newey-West)
#   T2: Y/K divergence test
#   T3: Structural break (Zivot-Andrews)
#
# All tests hold §6 adjustments fixed; only deflator varies.
# Effects are orthogonal and separable (§7.7).
#
# Outputs:
#   data/interim/validation/sfc_residuals.csv
#   data/interim/validation/deflator_tests_T1_T2_T3.csv
#   data/interim/figures/fig_sfc_residual.png
#   data/interim/figures/fig_quality_wedge.png
#   data/processed/stock_flow_validation.csv
#
# Sources: 40_gdp_kstock_config.R, 97_kstock_helpers.R
############################################################

rm(list = ls())

library(dplyr)
library(readr)
library(ggplot2)

source("codes/40_gdp_kstock_config.R")
source("codes/99_utils.R")
source("codes/97_kstock_helpers.R")

# Load figure protocol if available
if (file.exists("codes/99_figure_protocol.R")) {
  source("codes/99_figure_protocol.R")
}

ensure_dirs(GDP_CONFIG)


## ==============================================================
## Part A: Stock-Flow Consistency Validation
## ==============================================================

message("=== Part A: Stock-Flow Consistency Validation ===\n")

# Load component-level data (long format)
component_files <- list.files(GDP_CONFIG$INTERIM_KSTOCK,
                               pattern = "^kstock_(ME|NRC|RC|IP)\\.csv$",
                               full.names = TRUE)

if (length(component_files) == 0) {
  stop("No component files found. Run 44_build_kstock_private.R first.")
}

sfc_all <- list()

for (fpath in component_files) {
  df <- readr::read_csv(fpath, show_col_types = FALSE)
  asset <- unique(df$asset)[1]
  n <- nrow(df)

  message(sprintf("--- %s (%d obs) ---", asset, n))

  ## SFC check 1: Current-cost
  ## Residual = revaluation term (holding gains/losses)
  sfc_cc <- validate_sfc_identity(
    K     = df$K_net_cc[-1],
    K_lag = df$K_net_cc[-n],
    I     = df$IG_cc[-1],
    D     = df$D_cc[-1],
    label = paste0(asset, "_current_cost")
  ) |> mutate(year = df$year[-1], asset = asset, valuation = "current_cost")

  ## SFC check 2: Chain-weighted
  ## NOTE: Chain-weighted stocks use chain QI, but I and D are in current cost.
  ## The mismatch is INHERENT to the chain-weighted framework.
  ## This is Shaikh's core claim: SFC breaks under chain aggregation.
  sfc_chain <- validate_sfc_identity(
    K     = df$K_net_chain[-1],
    K_lag = df$K_net_chain[-n],
    I     = df$IG_cc[-1],      # No chain-weighted I available
    D     = df$D_cc[-1],       # No chain-weighted D available
    label = paste0(asset, "_chain_weighted")
  ) |> mutate(year = df$year[-1], asset = asset, valuation = "chain_weighted")

  ## SFC check 3: GPIM-deflated NET
  ## Should be ~ 0 by construction (same deflator for K, I, D)
  sfc_gpim <- validate_sfc_identity(
    K     = df$K_net_real[-1],
    K_lag = df$K_net_real[-n],
    I     = df$IG_real[-1],
    D     = df$D_real[-1],
    label = paste0(asset, "_net_gpim_real")
  ) |> mutate(year = df$year[-1], asset = asset, valuation = "net_gpim_real")

  ## ---- GROSS STOCK SFC ----
  ## Per GPIM_Formalization_v3, §1: z_it = retirement rate for gross stocks.
  ## Gross SFC: K^G_t = K^G_{t-1} + IG_t - Ret_t

  has_gross <- all(c("K_gross_real", "Ret_real") %in% names(df))

  if (has_gross) {
    ## SFC check 4: GPIM-deflated GROSS
    ## Should be ~ 0 by construction (eq. 5 with retirement rates)
    sfc_gross_gpim <- validate_gross_sfc(
      K_gross     = df$K_gross_real[-1],
      K_gross_lag = df$K_gross_real[-n],
      I           = df$IG_real[-1],
      Ret         = df$Ret_real[-1],
      label       = paste0(asset, "_gross_gpim_real")
    ) |> mutate(year = df$year[-1], asset = asset, valuation = "gross_gpim_real")

    ## SFC check 5: Chain-weighted GROSS (expect failure)
    ## Implicit chain gross: K_gross_cc * (K_net_chain / K_net_cc)
    K_gross_chain <- df$K_gross_cc * (df$K_net_chain / df$K_net_cc)
    sfc_gross_chain <- validate_gross_sfc(
      K_gross     = K_gross_chain[-1],
      K_gross_lag = K_gross_chain[-n],
      I           = df$IG_cc[-1],
      Ret         = df$Ret_cc[-1],
      label       = paste0(asset, "_gross_chain")
    ) |> mutate(year = df$year[-1], asset = asset, valuation = "gross_chain")
  }

  # Report all SFC checks
  net_checks <- list(sfc_cc, sfc_chain, sfc_gpim)
  if (has_gross) net_checks <- c(net_checks, list(sfc_gross_gpim, sfc_gross_chain))

  for (sfc in net_checks) {
    max_r <- max(abs(sfc$pct_residual), na.rm = TRUE)
    mean_r <- mean(abs(sfc$pct_residual), na.rm = TRUE)
    val <- sfc$valuation[1]
    msg <- sprintf("  %s: mean|resid|=%.6f, max|resid|=%.6f", val, mean_r, max_r)

    if (grepl("gpim_real", val) && max_r < GDP_CONFIG$GPIM$sfc_tolerance) {
      msg <- paste0(msg, " [PASS]")
    } else if (grepl("chain", val) && max_r > GDP_CONFIG$GPIM$sfc_tolerance) {
      msg <- paste0(msg, " [EXPECTED FAIL — confirms Shaikh §2]")
    } else if (val == "current_cost") {
      msg <- paste0(msg, " [revaluation term]")
    }
    message(msg)
  }

  all_sfc <- bind_rows(sfc_cc, sfc_chain, sfc_gpim)
  if (has_gross) all_sfc <- bind_rows(all_sfc, sfc_gross_gpim, sfc_gross_chain)
  sfc_all[[asset]] <- all_sfc
}

sfc_combined <- bind_rows(sfc_all)

# Write SFC results
safe_write_csv(sfc_combined,
  file.path(GDP_CONFIG$INTERIM_VALIDATION, "sfc_residuals.csv"))
safe_write_csv(sfc_combined,
  file.path(GDP_CONFIG$PROCESSED, "stock_flow_validation.csv"))

## SFC diagnostic figure
if (nrow(sfc_combined) > 0) {
  p_sfc <- ggplot(sfc_combined,
                   aes(x = year, y = pct_residual * 100,
                       color = valuation)) +
    geom_line(linewidth = 0.5) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "grey50") +
    facet_wrap(~asset, scales = "free_y") +
    labs(
      title = "Stock-Flow Consistency: Net + Gross, by Valuation Mode",
      subtitle = "GPIM ~ 0 (net + gross); chain-weighted deviates (confirms Shaikh §2)",
      x = "Year",
      y = "SFC Residual (%)",
      color = "Valuation"
    ) +
    theme_minimal()

  ggsave(file.path(GDP_CONFIG$INTERIM_FIGURES, "fig_sfc_residual.png"),
         p_sfc, width = 10, height = 7, dpi = 150)
  message("\nSFC figure saved: fig_sfc_residual.png")
}


## ==============================================================
## Part B: Deflator-Comparison Protocol (§7.5-7.6)
## ==============================================================

message("\n=== Part B: Deflator Tests T1-T3 ===\n")

# Load deflators
deflators <- readr::read_csv(
  file.path(GDP_CONFIG$PROCESSED, "price_deflators.csv"),
  show_col_types = FALSE
)

# Load GDP for Y/K ratio computation (T2)
gdp_path <- file.path(GDP_CONFIG$PROCESSED, "gdp_us_1925_2024.csv")
has_gdp <- file.exists(gdp_path)
if (has_gdp) {
  gdp <- readr::read_csv(gdp_path, show_col_types = FALSE)
}

# Load GPIM and chain stocks
kstock_gpim <- readr::read_csv(
  file.path(GDP_CONFIG$PROCESSED, "kstock_private_gpim_real.csv"),
  show_col_types = FALSE
)
kstock_chain <- readr::read_csv(
  file.path(GDP_CONFIG$PROCESSED, "kstock_private_chain_qty.csv"),
  show_col_types = FALSE
)

## ----------------------------------------------------------
## T1: Wedge Trend Test
##
## omega_t = ln(p^{K,QA}_t) - ln(p^K_t)
## OLS: omega_t = mu + delta*t + nu_t
## Newey-West SE. H0: delta = 0
## ----------------------------------------------------------

message("--- T1: Wedge Trend Test ---")

t1_results <- list()

# For each asset, the own-price deflator (p_K) IS the implicit ratio
# of current-cost to chain-weighted. The "quality-adjusted" deflator
# is the BEA chain-type price index. The "observed" deflator is
# derived from historical-cost data.
#
# For T1, we compare: chain-type implicit deflator vs GDP deflator
# as the two regimes.

for (asset_code in c("ME", "NRC", "RC", "IP")) {
  p_col <- paste0(asset_code, "_p_K")
  if (!p_col %in% names(deflators)) next

  df_t1 <- deflators |>
    select(year, p_asset = !!sym(p_col)) |>
    filter(!is.na(p_asset), p_asset > 0)

  if (nrow(df_t1) < 10) next

  # For T1, we need two deflator regimes.
  # p_QA: the chain-type-derived deflator (embedded in p_K)
  # p_obs: GDP implicit price deflator (common deflator)
  if (has_gdp && "gdp_deflator" %in% names(gdp)) {
    df_t1 <- df_t1 |>
      left_join(gdp |> select(year, gdp_defl = gdp_deflator), by = "year") |>
      filter(!is.na(gdp_defl), gdp_defl > 0) |>
      mutate(
        # Normalize both to same base
        p_QA  = p_asset / p_asset[year == GDP_CONFIG$GPIM$base_year],
        p_obs = gdp_defl / gdp_defl[year == GDP_CONFIG$GPIM$base_year],
        omega = log(p_QA) - log(p_obs),
        trend = year - min(year)
      )

    if (nrow(df_t1) >= 10) {
      # OLS with Newey-West SE
      fit_t1 <- lm(omega ~ trend, data = df_t1)

      # Newey-West if sandwich available
      if (requireNamespace("sandwich", quietly = TRUE) &&
          requireNamespace("lmtest", quietly = TRUE)) {
        nw_test <- lmtest::coeftest(fit_t1,
                     vcov = sandwich::NeweyWest(fit_t1))
        delta   <- nw_test["trend", "Estimate"]
        se_nw   <- nw_test["trend", "Std. Error"]
        t_stat  <- nw_test["trend", "t value"]
        p_val   <- nw_test["trend", "Pr(>|t|)"]
      } else {
        # Fallback: OLS SE
        s <- summary(fit_t1)$coefficients
        delta  <- s["trend", "Estimate"]
        se_nw  <- s["trend", "Std. Error"]
        t_stat <- s["trend", "t value"]
        p_val  <- s["trend", "Pr(>|t|)"]
        message("  (sandwich not available; using OLS SE)")
      }

      t1_results[[asset_code]] <- tibble(
        asset  = asset_code,
        test   = "T1_wedge_trend",
        delta  = delta,
        se     = se_nw,
        t_stat = t_stat,
        p_value = p_val,
        reject_H0 = p_val < 0.05
      )

      message(sprintf("  %s: delta=%.6f, SE=%.6f, p=%.4f %s",
                       asset_code, delta, se_nw, p_val,
                       ifelse(p_val < 0.05, "[REJECT H0]", "[FAIL TO REJECT]")))
    }
  } else {
    message(sprintf("  %s: GDP deflator not available for T1. Skipping.", asset_code))
  }
}


## ----------------------------------------------------------
## T2: Y/K Divergence Test
##
## ln(R^obs_t) - ln(R^QA_t) = gamma_0 + gamma_1*t + xi_t
## H1: gamma_1 < 0
## ----------------------------------------------------------

message("\n--- T2: Y/K Divergence Test ---")

t2_results <- list()

if (has_gdp) {
  for (asset_code in c("ME", "NRC", "RC", "NR", "TOTAL_PRODUCTIVE")) {
    gpim_col <- paste0(asset_code, "_K_net_real")
    chain_col <- paste0(asset_code, "_K_net_chain")

    has_gpim  <- gpim_col %in% names(kstock_gpim)
    has_chain <- chain_col %in% names(kstock_chain)

    if (!has_gpim || !has_chain) next

    df_t2 <- gdp |>
      select(year, Y = gdp_real_2017) |>
      left_join(kstock_gpim |> select(year, K_gpim = !!sym(gpim_col)), by = "year") |>
      left_join(kstock_chain |> select(year, K_chain = !!sym(chain_col)), by = "year") |>
      filter(!is.na(Y), !is.na(K_gpim), !is.na(K_chain),
             Y > 0, K_gpim > 0, K_chain > 0) |>
      mutate(
        R_obs = Y / K_gpim,    # GPIM = "observed-price" regime
        R_QA  = Y / K_chain,   # Chain = "quality-adjusted" regime
        ln_diff = log(R_obs) - log(R_QA),
        trend   = year - min(year)
      )

    if (nrow(df_t2) >= 10) {
      fit_t2 <- lm(ln_diff ~ trend, data = df_t2)
      s <- summary(fit_t2)$coefficients

      t2_results[[asset_code]] <- tibble(
        asset   = asset_code,
        test    = "T2_yk_divergence",
        gamma_1 = s["trend", "Estimate"],
        se      = s["trend", "Std. Error"],
        t_stat  = s["trend", "t value"],
        p_value = s["trend", "Pr(>|t|)"],
        gamma_1_negative = s["trend", "Estimate"] < 0
      )

      message(sprintf("  %s: gamma_1=%.6f, p=%.4f %s",
                       asset_code, s["trend", "Estimate"], s["trend", "Pr(>|t|)"],
                       ifelse(s["trend", "Estimate"] < 0,
                              "[gamma_1 < 0 — quality adj flattens Y/K]",
                              "[gamma_1 >= 0]")))
    }
  }
} else {
  message("  GDP data not available. Skipping T2.")
}


## ----------------------------------------------------------
## T3: Structural Break (Zivot-Andrews)
##
## Zivot-Andrews on omega_t (break in intercept + trend).
## Expected break: 1985-1999 (BEA hedonic adoption).
## ----------------------------------------------------------

message("\n--- T3: Structural Break Test ---")

t3_results <- list()

za_available <- requireNamespace("urca", quietly = TRUE)
if (!za_available) {
  message("  urca package not available. Skipping T3.")
  message("  Install with: install.packages('urca')")
} else {
  for (asset_code in c("ME", "NRC", "RC", "IP")) {
    p_col <- paste0(asset_code, "_p_K")
    if (!p_col %in% names(deflators)) next

    df_t3 <- deflators |>
      select(year, p_asset = !!sym(p_col)) |>
      filter(!is.na(p_asset), p_asset > 0)

    if (has_gdp && "gdp_deflator" %in% names(gdp)) {
      df_t3 <- df_t3 |>
        left_join(gdp |> select(year, gdp_defl = gdp_deflator), by = "year") |>
        filter(!is.na(gdp_defl), gdp_defl > 0) |>
        mutate(
          p_QA  = p_asset / p_asset[1],
          p_obs = gdp_defl / gdp_defl[1],
          omega = log(p_QA) - log(p_obs)
        )

      if (nrow(df_t3) >= 20) {
        omega_ts <- ts(df_t3$omega, start = min(df_t3$year), frequency = 1)

        tryCatch({
          za <- urca::ur.za(omega_ts, model = "both", lag = 2)
          break_idx  <- za@bpoint
          break_year <- min(df_t3$year) + break_idx - 1
          test_stat  <- za@teststat
          cval_5pct  <- za@cval["5pct"]

          in_window <- break_year >= GDP_CONFIG$DEFLATOR_TESTS$za_break_window[1] &&
                       break_year <= GDP_CONFIG$DEFLATOR_TESTS$za_break_window[2]

          t3_results[[asset_code]] <- tibble(
            asset      = asset_code,
            test       = "T3_structural_break",
            break_year = break_year,
            test_stat  = as.numeric(test_stat),
            cval_5pct  = as.numeric(cval_5pct),
            reject_H0  = abs(as.numeric(test_stat)) > abs(as.numeric(cval_5pct)),
            in_hedonic_window = in_window
          )

          message(sprintf("  %s: break at %d, stat=%.3f, cv5%%=%.3f %s %s",
                           asset_code, break_year,
                           as.numeric(test_stat), as.numeric(cval_5pct),
                           ifelse(abs(as.numeric(test_stat)) > abs(as.numeric(cval_5pct)),
                                  "[REJECT]", "[FAIL]"),
                           ifelse(in_window,
                                  "[IN hedonic window 1985-1999]",
                                  "[OUTSIDE window]")))
        }, error = function(e) {
          message(sprintf("  %s: ZA test failed: %s", asset_code, e$message))
        })
      }
    }
  }
}


## ==============================================================
## Combine and write all test results
## ==============================================================

all_tests <- bind_rows(
  bind_rows(t1_results),
  bind_rows(t2_results),
  bind_rows(t3_results)
)

if (nrow(all_tests) > 0) {
  safe_write_csv(all_tests,
    file.path(GDP_CONFIG$INTERIM_VALIDATION, "deflator_tests_T1_T2_T3.csv"))
  message(sprintf("\nDeflator tests saved: %d results",  nrow(all_tests)))
} else {
  message("\nNo deflator test results to write.")
}

## Quality wedge figure
if (exists("df_t1") && nrow(df_t1) > 0) {
  p_wedge <- ggplot(df_t1, aes(x = year, y = omega)) +
    geom_line(linewidth = 0.6) +
    geom_smooth(method = "lm", se = TRUE, color = "red", linetype = "dashed") +
    geom_vline(xintercept = c(1985, 1997), linetype = "dotted",
               color = "blue", alpha = 0.5) +
    annotate("text", x = 1985, y = max(df_t1$omega, na.rm = TRUE),
             label = "BEA hedonic\nadoption", hjust = -0.1, size = 3) +
    labs(
      title = "Quality-Adjustment Wedge (T1)",
      subtitle = expression(omega[t] == ln(p[t]^{K*","*QA}) - ln(p[t]^K)),
      x = "Year", y = expression(omega[t])
    ) +
    theme_minimal()

  ggsave(file.path(GDP_CONFIG$INTERIM_FIGURES, "fig_quality_wedge.png"),
         p_wedge, width = 8, height = 5, dpi = 150)
  message("Quality wedge figure saved.")
}

message(sprintf("\n=== SFC validation & deflator tests complete ==="))
