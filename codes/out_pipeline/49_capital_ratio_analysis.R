############################################################
# 49_capital_ratio_analysis.R — Capital-Output Ratio Analysis
#
# Computes and analyzes the output-capital ratio (Y/K) under
# alternative deflation regimes, tests for secular trends,
# and generates paper-facing figures.
#
# This script is a strict consumer of 48_assemble_dataset.R
# output plus raw component data from 44 and 47.
#
# Analysis sections:
#   A. Y/K ratio time series (GPIM vs chain-weighted)
#   B. Period decomposition (Fordism, post-Fordism)
#   C. Asset-level Y/K ratios (ME, NRC, TOTAL_PRODUCTIVE = ME+NRC)
#   D. Capital deepening vs. output growth decomposition
#   E. Formal T1-T3 summary table
#   F. Cross-validation with Shaikh canonical Y/K
#
# Output:
#   data/processed/capital_ratio_analysis.csv
#   data/interim/figures/fig_yk_ratio_comparison.png
#   data/interim/figures/fig_yk_ratio_periods.png
#   data/interim/figures/fig_yk_decomposition.png
#   data/interim/figures/fig_yk_asset_level.png
#   data/interim/figures/fig_yk_shaikh_crossval.png
#   data/interim/validation/capital_ratio_summary.csv
#
# Sources: 40_gdp_kstock_config.R, 97_kstock_helpers.R
############################################################

rm(list = ls())

library(dplyr)
library(tidyr)
library(readr)
library(ggplot2)

source("codes/40_gdp_kstock_config.R")
source("codes/99_utils.R")
source("codes/97_kstock_helpers.R")

if (file.exists("codes/99_figure_protocol.R")) {
  source("codes/99_figure_protocol.R")
}

ensure_dirs(GDP_CONFIG)


## ==============================================================
## Load data
## ==============================================================

message("=== Capital-Output Ratio Analysis ===\n")

# Master dataset (from 48)
master_path <- file.path(GDP_CONFIG$PROCESSED, "master_dataset.csv")
if (!file.exists(master_path)) {
  stop("Master dataset not found. Run 48_assemble_dataset.R first.\n",
       "Path: ", master_path)
}
master <- readr::read_csv(master_path, show_col_types = FALSE)
message(sprintf("Master dataset: %d-%d (%d obs, %d cols)",
                min(master$year), max(master$year),
                nrow(master), ncol(master)))

# Chain-weighted stocks (for regime comparison)
chain_path <- file.path(GDP_CONFIG$PROCESSED, "kstock_private_chain_qty.csv")
has_chain <- file.exists(chain_path)
if (has_chain) {
  kstock_chain <- readr::read_csv(chain_path, show_col_types = FALSE)
}

# Deflator test results (from 47)
defl_test_path <- file.path(GDP_CONFIG$INTERIM_VALIDATION,
                             "deflator_tests_T1_T2_T3.csv")
has_defl_tests <- file.exists(defl_test_path)
if (has_defl_tests) {
  defl_tests <- readr::read_csv(defl_test_path, show_col_types = FALSE)
}

# Shaikh canonical (for cross-validation)
shaikh_path <- "data/raw/Shaikh_canonical_series_v1.csv"
has_shaikh <- file.exists(shaikh_path)
if (has_shaikh) {
  shaikh <- readr::read_csv(shaikh_path, show_col_types = FALSE)
}


## ==============================================================
## §A. Y/K Ratio Time Series: GPIM vs Chain-Weighted
## ==============================================================

message("\n--- §A: Y/K ratio comparison (GPIM vs chain) ---")

ratio_df <- master |>
  select(year, gdp_real_2017, gdp_nominal) |>
  filter(!is.na(gdp_real_2017))

# GPIM-deflated Y/K (from master)
if ("yk_ratio_real" %in% names(master)) {
  ratio_df <- ratio_df |>
    left_join(master |> select(year, yk_gpim = yk_ratio_real), by = "year")
} else if ("TOTAL_PRODUCTIVE_K_net_real" %in% names(master)) {
  ratio_df <- ratio_df |>
    left_join(master |> select(year, K_gpim = TOTAL_PRODUCTIVE_K_net_real),
              by = "year") |>
    mutate(yk_gpim = gdp_real_2017 / K_gpim)
}

# Chain-weighted Y/K
if (has_chain && "TOTAL_PRODUCTIVE_K_net_chain" %in% names(kstock_chain)) {
  ratio_df <- ratio_df |>
    left_join(kstock_chain |>
                select(year, K_chain = TOTAL_PRODUCTIVE_K_net_chain),
              by = "year") |>
    mutate(yk_chain = gdp_real_2017 / K_chain)
}

# NOTE: TOTAL_PRODUCTIVE = NR = ME + NRC (RC excluded from productive capital).
# yk_gpim already reflects this definition. No separate NR ratio needed.

# Nominal Y/K (current-cost)
if ("TOTAL_PRODUCTIVE_K_net_cc" %in% names(master)) {
  ratio_df <- ratio_df |>
    left_join(master |> select(year, K_cc = TOTAL_PRODUCTIVE_K_net_cc),
              by = "year") |>
    mutate(yk_nominal = gdp_nominal / K_cc)
}

# Log differences for trend analysis
ratio_df <- ratio_df |>
  mutate(
    ln_yk_gpim  = ifelse(!is.na(yk_gpim) & yk_gpim > 0,
                          log(yk_gpim), NA_real_),
    ln_yk_chain = ifelse(!is.na(yk_chain) & yk_chain > 0,
                          log(yk_chain), NA_real_),
    # Log divergence: captures deflator-regime effect on Y/K
    ln_divergence = ln_yk_gpim - ln_yk_chain
  )

# Report
n_valid <- sum(!is.na(ratio_df$yk_gpim))
message(sprintf("  GPIM Y/K: %d valid obs", n_valid))
if ("yk_chain" %in% names(ratio_df)) {
  n_chain <- sum(!is.na(ratio_df$yk_chain))
  message(sprintf("  Chain Y/K: %d valid obs", n_chain))
}


## ==============================================================
## §B. Period Decomposition
##
## Fordism:       1947-1973
## Post-Fordism:  1974-2011 (Shaikh window end)
## Full sample:   1947-2011
## Extended:      1929-2024 (data availability)
## ==============================================================

message("\n--- §B: Period decomposition ---")

periods <- list(
  fordism      = c(1947L, 1973L),
  post_fordism = c(1974L, 2011L),
  shaikh       = c(1947L, 2011L),
  full         = c(min(ratio_df$year), max(ratio_df$year))
)

period_stats <- list()

for (pname in names(periods)) {
  yr <- periods[[pname]]
  sub <- ratio_df |>
    filter(year >= yr[1], year <= yr[2], !is.na(yk_gpim))

  if (nrow(sub) < 5) next

  # Trend regression: ln(Y/K) = a + b*t
  sub <- sub |> mutate(trend = year - min(year))
  fit <- lm(ln_yk_gpim ~ trend, data = sub)
  s <- summary(fit)$coefficients

  # Growth rates
  yk_start <- sub$yk_gpim[1]
  yk_end   <- sub$yk_gpim[nrow(sub)]
  annual_change <- (yk_end / yk_start)^(1 / (nrow(sub) - 1)) - 1

  period_stats[[pname]] <- tibble(
    period     = pname,
    year_start = yr[1],
    year_end   = yr[2],
    n_years    = nrow(sub),
    yk_mean    = mean(sub$yk_gpim, na.rm = TRUE),
    yk_sd      = sd(sub$yk_gpim, na.rm = TRUE),
    yk_start   = yk_start,
    yk_end     = yk_end,
    annual_pct_change = annual_change * 100,
    trend_coef = s["trend", "Estimate"],
    trend_se   = s["trend", "Std. Error"],
    trend_pval = s["trend", "Pr(>|t|)"]
  )

  message(sprintf("  %s (%d-%d): mean Y/K=%.4f, annual change=%.2f%%/yr, trend p=%.4f",
                  pname, yr[1], yr[2],
                  mean(sub$yk_gpim, na.rm = TRUE),
                  annual_change * 100,
                  s["trend", "Pr(>|t|)"]))
}

period_summary <- bind_rows(period_stats)


## ==============================================================
## §C. Asset-Level Y/K Ratios
## ==============================================================

message("\n--- §C: Asset-level Y/K ratios ---")

asset_ratios <- list()

for (asset_code in c("ME", "NRC", "TOTAL_PRODUCTIVE", "TOTAL_WITH_RC")) {
  k_col_real <- paste0(asset_code, "_K_net_real")

  if (!k_col_real %in% names(master)) next

  asset_df <- master |>
    select(year, gdp_real_2017, K_real = !!sym(k_col_real)) |>
    filter(!is.na(gdp_real_2017), !is.na(K_real), K_real > 0) |>
    mutate(
      yk = gdp_real_2017 / K_real,
      asset = asset_code
    )

  if (nrow(asset_df) > 0) {
    asset_ratios[[asset_code]] <- asset_df |>
      select(year, asset, yk)

    message(sprintf("  %s: Y/K range [%.4f, %.4f]",
                    asset_code,
                    min(asset_df$yk), max(asset_df$yk)))
  }
}

asset_ratio_df <- bind_rows(asset_ratios)


## ==============================================================
## §D. Capital Deepening vs. Output Growth Decomposition
##
## ln(Y/K)_t - ln(Y/K)_{t-1} = Δln(Y)_t - Δln(K)_t
##
## Decomposes Y/K changes into output growth and capital
## accumulation components.
## ==============================================================

message("\n--- §D: Growth decomposition ---")

decomp_col <- "TOTAL_PRODUCTIVE_K_net_real"
if (decomp_col %in% names(master)) {
  decomp <- master |>
    select(year, gdp_real_2017, K_real = !!sym(decomp_col)) |>
    filter(!is.na(gdp_real_2017), !is.na(K_real),
           gdp_real_2017 > 0, K_real > 0) |>
    mutate(
      dln_Y  = c(NA, diff(log(gdp_real_2017))),
      dln_K  = c(NA, diff(log(K_real))),
      dln_YK = dln_Y - dln_K
    ) |>
    filter(!is.na(dln_YK))

  # Period averages
  for (pname in names(periods)) {
    yr <- periods[[pname]]
    sub <- decomp |> filter(year >= yr[1], year <= yr[2])
    if (nrow(sub) < 3) next

    avg_dln_Y  <- mean(sub$dln_Y, na.rm = TRUE) * 100
    avg_dln_K  <- mean(sub$dln_K, na.rm = TRUE) * 100
    avg_dln_YK <- mean(sub$dln_YK, na.rm = TRUE) * 100

    message(sprintf("  %s: ΔlnY=%.2f%%  ΔlnK=%.2f%%  Δln(Y/K)=%.2f%%",
                    pname, avg_dln_Y, avg_dln_K, avg_dln_YK))
  }
} else {
  message("  Capital stock not available for decomposition.")
  decomp <- tibble()
}


## ==============================================================
## §E. Formal T1-T3 Summary Table
##
## Consolidates deflator test results from 47 with Y/K analysis.
## ==============================================================

message("\n--- §E: Deflator test summary ---")

if (has_defl_tests && nrow(defl_tests) > 0) {
  # T1 results
  t1 <- defl_tests |> filter(test == "T1_wedge_trend")
  if (nrow(t1) > 0) {
    message("  T1 (Wedge Trend):")
    for (i in seq_len(nrow(t1))) {
      row <- t1[i, ]
      message(sprintf("    %s: δ=%.6f (SE=%.6f), p=%.4f %s",
                      row$asset, row$delta, row$se, row$p_value,
                      ifelse(row$reject_H0, "[REJECT]", "[FAIL]")))
    }
  }

  # T2 results
  t2 <- defl_tests |> filter(test == "T2_yk_divergence")
  if (nrow(t2) > 0) {
    message("  T2 (Y/K Divergence):")
    for (i in seq_len(nrow(t2))) {
      row <- t2[i, ]
      message(sprintf("    %s: γ₁=%.6f (SE=%.6f), p=%.4f %s",
                      row$asset, row$gamma_1, row$se, row$p_value,
                      ifelse(row$gamma_1_negative,
                             "[γ₁<0 — QA flattens Y/K]",
                             "[γ₁≥0]")))
    }
  }

  # T3 results
  t3 <- defl_tests |> filter(test == "T3_structural_break")
  if (nrow(t3) > 0) {
    message("  T3 (Structural Break):")
    for (i in seq_len(nrow(t3))) {
      row <- t3[i, ]
      message(sprintf("    %s: break=%d, stat=%.3f vs cv5%%=%.3f %s %s",
                      row$asset, row$break_year,
                      row$test_stat, row$cval_5pct,
                      ifelse(row$reject_H0, "[REJECT]", "[FAIL]"),
                      ifelse(row$in_hedonic_window, "[IN window]", "")))
    }
  }
} else {
  message("  No deflator test results found. Run 47_stock_flow_consistency.R.")
}


## ==============================================================
## §F. Cross-Validation with Shaikh Canonical Y/K
## ==============================================================

message("\n--- §F: Cross-validation with Shaikh ---")

xval_yk <- NULL

if (has_shaikh) {
  # Shaikh's Y/K = VAcorp / KGCcorp (corporate sector)
  if ("VAcorp" %in% names(shaikh) && "KGCcorp" %in% names(shaikh)) {
    shaikh_yk <- shaikh |>
      filter(!is.na(VAcorp), !is.na(KGCcorp), KGCcorp > 0) |>
      mutate(yk_shaikh = VAcorp / KGCcorp) |>
      select(year, yk_shaikh)

    if ("yk_gpim" %in% names(ratio_df)) {
      xval_yk <- shaikh_yk |>
        inner_join(ratio_df |> select(year, yk_gpim), by = "year") |>
        filter(!is.na(yk_shaikh), !is.na(yk_gpim))

      if (nrow(xval_yk) > 5) {
        corr <- cor(xval_yk$yk_shaikh, xval_yk$yk_gpim, use = "complete.obs")
        ratio <- mean(xval_yk$yk_gpim / xval_yk$yk_shaikh, na.rm = TRUE)

        # Trend comparison
        xval_yk <- xval_yk |> mutate(trend = year - min(year))
        fit_s <- lm(log(yk_shaikh) ~ trend, data = xval_yk)
        fit_g <- lm(log(yk_gpim) ~ trend, data = xval_yk)

        slope_s <- coef(fit_s)["trend"]
        slope_g <- coef(fit_g)["trend"]

        message(sprintf("  Shaikh vs GPIM Y/K correlation: %.4f", corr))
        message(sprintf("  Mean level ratio (GPIM/Shaikh): %.4f", ratio))
        message(sprintf("  Trend slopes: Shaikh=%.6f, GPIM=%.6f", slope_s, slope_g))
        message("  NOTE: Level difference expected — Shaikh uses corporate VA,")
        message("        we use GDP. Trend direction matters more than levels.")
      }
    }
  }
} else {
  message("  Shaikh canonical series not available. Skipping.")
}


## ==============================================================
## Figures
## ==============================================================

message("\n--- Generating figures ---")

fig_dir <- GDP_CONFIG$INTERIM_FIGURES

# Figure 1: Y/K ratio comparison (GPIM vs chain)
if ("yk_gpim" %in% names(ratio_df)) {
  plot_df <- ratio_df |>
    filter(!is.na(yk_gpim)) |>
    select(year, any_of(c("yk_gpim", "yk_chain", "yk_nominal"))) |>
    pivot_longer(-year, names_to = "regime", values_to = "yk") |>
    filter(!is.na(yk)) |>
    mutate(regime = case_match(regime,
      "yk_gpim"    ~ "GPIM-deflated (Y/K real)",
      "yk_chain"   ~ "Chain-weighted (Y/K real)",
      "yk_nominal" ~ "Nominal (Y/K current-cost)",
      .default = regime
    ))

  p1 <- ggplot(plot_df, aes(x = year, y = yk, color = regime)) +
    geom_line(linewidth = 0.7) +
    labs(
      title = "Output-Capital Ratio Under Alternative Deflation Regimes",
      subtitle = "GPIM preserves SFC; chain-weighted introduces index-number artifacts",
      x = "Year", y = "Y / K",
      color = "Deflation regime"
    ) +
    theme_minimal() +
    theme(legend.position = "bottom")

  ggsave(file.path(fig_dir, "fig_yk_ratio_comparison.png"),
         p1, width = 10, height = 6, dpi = 150)
  ggsave(file.path(fig_dir, "fig_yk_ratio_comparison.pdf"),
         p1, width = 10, height = 6)
  message("  fig_yk_ratio_comparison.{png,pdf}")
}

# Figure 2: Y/K by period
if ("yk_gpim" %in% names(ratio_df)) {
  period_df <- ratio_df |>
    filter(!is.na(yk_gpim)) |>
    mutate(
      period = case_when(
        year >= 1947 & year <= 1973 ~ "Fordism (1947-1973)",
        year >= 1974 & year <= 2011 ~ "Post-Fordism (1974-2011)",
        year > 2011                 ~ "Post-2011",
        TRUE                        ~ "Pre-Fordism"
      )
    )

  p2 <- ggplot(period_df, aes(x = year, y = yk_gpim)) +
    geom_line(linewidth = 0.6) +
    geom_smooth(aes(group = period, color = period),
                method = "lm", se = TRUE, linewidth = 0.5, alpha = 0.2) +
    geom_vline(xintercept = c(1947, 1973, 2011),
               linetype = "dashed", color = "grey50", alpha = 0.5) +
    labs(
      title = "Output-Capital Ratio: Period Trends",
      subtitle = "GPIM-deflated productive capital (ME + NRC)",
      x = "Year", y = "Y / K",
      color = "Period"
    ) +
    theme_minimal() +
    theme(legend.position = "bottom")

  ggsave(file.path(fig_dir, "fig_yk_ratio_periods.png"),
         p2, width = 10, height = 6, dpi = 150)
  ggsave(file.path(fig_dir, "fig_yk_ratio_periods.pdf"),
         p2, width = 10, height = 6)
  message("  fig_yk_ratio_periods.{png,pdf}")
}

# Figure 3: Growth decomposition
if (nrow(decomp) > 0) {
  decomp_plot <- decomp |>
    select(year, dln_Y, dln_K) |>
    pivot_longer(-year, names_to = "component", values_to = "growth") |>
    mutate(component = case_match(component,
      "dln_Y" ~ "Output growth (Δln Y)",
      "dln_K" ~ "Capital growth (Δln K)"
    ))

  p3 <- ggplot(decomp_plot, aes(x = year, y = growth * 100, color = component)) +
    geom_line(linewidth = 0.5, alpha = 0.6) +
    geom_smooth(method = "loess", span = 0.3, se = FALSE, linewidth = 0.8) +
    geom_hline(yintercept = 0, linetype = "dashed") +
    labs(
      title = "Capital Deepening vs. Output Growth",
      subtitle = "When Δln K > Δln Y persistently, Y/K declines (capital deepening)",
      x = "Year", y = "Annual growth rate (%)",
      color = NULL
    ) +
    theme_minimal() +
    theme(legend.position = "bottom")

  ggsave(file.path(fig_dir, "fig_yk_decomposition.png"),
         p3, width = 10, height = 6, dpi = 150)
  ggsave(file.path(fig_dir, "fig_yk_decomposition.pdf"),
         p3, width = 10, height = 6)
  message("  fig_yk_decomposition.{png,pdf}")
}

# Figure 4: Asset-level Y/K
if (nrow(asset_ratio_df) > 0) {
  p4 <- ggplot(asset_ratio_df, aes(x = year, y = yk, color = asset)) +
    geom_line(linewidth = 0.6) +
    labs(
      title = "Output-Capital Ratio by Asset Type",
      subtitle = "GPIM-deflated capital stocks; GDP / asset-specific K",
      x = "Year", y = "Y / K",
      color = "Asset"
    ) +
    theme_minimal() +
    theme(legend.position = "bottom")

  ggsave(file.path(fig_dir, "fig_yk_asset_level.png"),
         p4, width = 10, height = 6, dpi = 150)
  ggsave(file.path(fig_dir, "fig_yk_asset_level.pdf"),
         p4, width = 10, height = 6)
  message("  fig_yk_asset_level.{png,pdf}")
}

# Figure 5: Shaikh cross-validation
if (!is.null(xval_yk) && nrow(xval_yk) > 5) {
  xval_plot <- xval_yk |>
    select(year, yk_shaikh, yk_gpim) |>
    pivot_longer(-year, names_to = "source", values_to = "yk") |>
    mutate(source = case_match(source,
      "yk_shaikh" ~ "Shaikh (VAcorp / KGCcorp)",
      "yk_gpim"   ~ "This dataset (GDP / K_GPIM)"
    ))

  p5 <- ggplot(xval_plot, aes(x = year, y = yk, color = source)) +
    geom_line(linewidth = 0.7) +
    labs(
      title = "Cross-Validation: Y/K vs Shaikh Canonical Series",
      subtitle = "Level difference expected (corporate VA vs GDP); trend direction matters",
      x = "Year", y = "Y / K",
      color = "Source"
    ) +
    theme_minimal() +
    theme(legend.position = "bottom")

  ggsave(file.path(fig_dir, "fig_yk_shaikh_crossval.png"),
         p5, width = 10, height = 6, dpi = 150)
  ggsave(file.path(fig_dir, "fig_yk_shaikh_crossval.pdf"),
         p5, width = 10, height = 6)
  message("  fig_yk_shaikh_crossval.{png,pdf}")
}


## ==============================================================
## Write outputs
## ==============================================================

message("\n--- Writing outputs ---")

# 1. Capital ratio analysis dataset
out_ratio <- ratio_df |>
  select(year, any_of(c("gdp_real_2017", "yk_gpim", "yk_chain",
                          "yk_nominal",
                          "ln_yk_gpim", "ln_yk_chain", "ln_divergence")))
safe_write_csv(out_ratio,
  file.path(GDP_CONFIG$PROCESSED, "capital_ratio_analysis.csv"))
message(sprintf("  capital_ratio_analysis.csv (%d rows)", nrow(out_ratio)))

# 2. Period summary
safe_write_csv(period_summary,
  file.path(GDP_CONFIG$INTERIM_VALIDATION, "capital_ratio_periods.csv"))
message(sprintf("  capital_ratio_periods.csv (%d periods)", nrow(period_summary)))

# 3. Asset-level ratios
if (nrow(asset_ratio_df) > 0) {
  safe_write_csv(asset_ratio_df,
    file.path(GDP_CONFIG$INTERIM_VALIDATION, "capital_ratio_by_asset.csv"))
  message(sprintf("  capital_ratio_by_asset.csv (%d rows)", nrow(asset_ratio_df)))
}

# 4. Growth decomposition
if (nrow(decomp) > 0) {
  safe_write_csv(decomp,
    file.path(GDP_CONFIG$INTERIM_VALIDATION, "capital_ratio_decomposition.csv"))
  message(sprintf("  capital_ratio_decomposition.csv (%d rows)", nrow(decomp)))
}

# 5. Consolidated summary table
summary_rows <- list()

# Y/K level summary
if ("yk_gpim" %in% names(ratio_df)) {
  valid_yk <- ratio_df |> filter(!is.na(yk_gpim))
  summary_rows[["yk_gpim_mean"]] <- tibble(
    metric = "Y/K (GPIM) mean",
    value  = mean(valid_yk$yk_gpim),
    note   = sprintf("%d-%d", min(valid_yk$year), max(valid_yk$year))
  )
}

# T1-T3 condensed
if (has_defl_tests) {
  for (i in seq_len(nrow(defl_tests))) {
    row <- defl_tests[i, ]
    summary_rows[[paste0("test_", i)]] <- tibble(
      metric = paste(row$test, row$asset, sep = "_"),
      value  = ifelse("delta" %in% names(row), row$delta,
               ifelse("gamma_1" %in% names(row), row$gamma_1,
               ifelse("break_year" %in% names(row), row$break_year, NA))),
      note   = ifelse("p_value" %in% names(row),
                       sprintf("p=%.4f", row$p_value),
                       "")
    )
  }
}

# Period trend slopes
for (i in seq_len(nrow(period_summary))) {
  ps <- period_summary[i, ]
  summary_rows[[paste0("period_", ps$period)]] <- tibble(
    metric = paste0("trend_", ps$period),
    value  = ps$trend_coef,
    note   = sprintf("p=%.4f, %d-%d", ps$trend_pval, ps$year_start, ps$year_end)
  )
}

summary_table <- bind_rows(summary_rows)
safe_write_csv(summary_table,
  file.path(GDP_CONFIG$INTERIM_VALIDATION, "capital_ratio_summary.csv"))
message(sprintf("  capital_ratio_summary.csv (%d rows)", nrow(summary_table)))


## ==============================================================
## Final report
## ==============================================================

message(sprintf("\n=== Capital-Output Ratio Analysis Complete ==="))
message(sprintf("Main output: %s",
                file.path(GDP_CONFIG$PROCESSED, "capital_ratio_analysis.csv")))
message(sprintf("Figures: %s", fig_dir))
message(sprintf("Validation: %s", GDP_CONFIG$INTERIM_VALIDATION))

if ("yk_gpim" %in% names(ratio_df)) {
  valid <- ratio_df |> filter(!is.na(yk_gpim))
  message(sprintf("\nKey findings:"))
  message(sprintf("  Y/K (GPIM, full sample): %.4f mean, range [%.4f, %.4f]",
                  mean(valid$yk_gpim), min(valid$yk_gpim), max(valid$yk_gpim)))
  if (nrow(period_summary) > 0) {
    for (i in seq_len(nrow(period_summary))) {
      ps <- period_summary[i, ]
      direction <- ifelse(ps$trend_coef < 0, "declining", "rising")
      sig <- ifelse(ps$trend_pval < 0.05, "(significant)", "(not significant)")
      message(sprintf("  %s: %s Y/K %s",
                      ps$period, direction, sig))
    }
  }
}

message("\nDone.")
