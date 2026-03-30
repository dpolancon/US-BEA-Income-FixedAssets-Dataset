############################################################
# 63_figure_prod_cap_accounts.R — Dataset 2 Figures
#
# Reads data/processed/kstock_master.csv and produces five
# diagnostic/paper figures for the four-account productive
# capital pipeline.
#
# Uses: ggplot2, theme_ch3(), save_png_pdf_dual(), PAL_OI
# from 99_figure_protocol.R.
#
# Figures:
#   1. KGC_productive vs KGC_total (time series)
#   2. Account share decomposition (stacked area)
#   3. pK by account (multi-line, 2017=100)
#   4. z and rho by account (faceted)
#   5. KNC vs KGC gap by account (4-panel)
############################################################

library(ggplot2)
library(dplyr)
library(tidyr)
library(readr)

source("codes/99_figure_protocol.R")

## ----------------------------------------------------------
## Load data
## ----------------------------------------------------------

master_path <- "data/processed/kstock_master.csv"
if (!file.exists(master_path)) {
  stop("kstock_master.csv not found. Run 62_build_prod_cap_accounts.R first.")
}
master <- readr::read_csv(master_path, show_col_types = FALSE)

long_path <- "data/processed/kstock_accounts_long.csv"
if (file.exists(long_path)) {
  accounts_long <- readr::read_csv(long_path, show_col_types = FALSE)
} else {
  accounts_long <- NULL
}

## Output directory
fig_dir <- "output/CriticalReplication/figures_prod_cap"
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)

## Account palette (colorblind-safe Okabe-Ito)
ACCT_COLORS <- c(
  "NF Corporate"     = unname(PAL_OI["orange"]),
  "Gov Transport"    = unname(PAL_OI["green"]),
  "NF IPP"           = unname(PAL_OI["purple"]),
  "Financial Corp"   = unname(PAL_OI["skyblue"])
)

## Filter to estimation window for cleaner plots
est_years <- 1947:2024
master_est <- master |> dplyr::filter(year %in% est_years)


## ==================================================================
## Figure 1: KGC_productive vs KGC_total
## ==================================================================

fig1_data <- master_est |>
  dplyr::select(year, KGC_productive, KGC_total) |>
  tidyr::pivot_longer(-year, names_to = "series", values_to = "KGC") |>
  dplyr::mutate(
    series = dplyr::case_when(
      series == "KGC_productive" ~ "Productive (A'+B'+C')",
      series == "KGC_total"      ~ "Productive + IPP (A'+B'+C'+D')",
      TRUE ~ series
    )
  )

fig1 <- ggplot(fig1_data, aes(x = year, y = KGC, color = series)) +
  geom_line(linewidth = 0.9) +
  scale_color_manual(values = c(
    "Productive (A'+B'+C')"            = unname(PAL_OI["blue"]),
    "Productive + IPP (A'+B'+C'+D')"   = unname(PAL_OI["orange"])
  )) +
  labs(
    title    = "Gross Capital Stock: Productive vs Total",
    subtitle = "NF corporate + government transport, current cost (billions $)",
    x = NULL, y = "KGC (billions $)",
    caption  = "Source: BEA Fixed Assets Tables 6.1, 7.1; GPIM construction"
  ) +
  theme_ch3()

save_png_pdf_dual(fig1, "fig01_KGC_productive_vs_total", fig_dir)


## ==================================================================
## Figure 2: KGC_NF_corp vs KGC_gov_trans (auxiliary comparison)
## ==================================================================

fig2_data <- master_est |>
  dplyr::select(year, KGC_NF_corp, KGC_gov_trans) |>
  tidyr::pivot_longer(-year, names_to = "series", values_to = "KGC") |>
  dplyr::mutate(
    series = dplyr::case_when(
      series == "KGC_NF_corp"   ~ "NF Corporate (productive)",
      series == "KGC_gov_trans" ~ "Gov Transport (auxiliary)",
      TRUE ~ series
    )
  )

fig2 <- ggplot(fig2_data, aes(x = year, y = KGC, color = series)) +
  geom_line(linewidth = 0.9) +
  scale_color_manual(values = c(
    "NF Corporate (productive)" = unname(PAL_OI["orange"]),
    "Gov Transport (auxiliary)"  = unname(PAL_OI["green"])
  )) +
  labs(
    title    = "Gross Capital Stock: NF Corporate vs Gov Transport",
    subtitle = "NF Corporate = productive aggregate; Gov transport = auxiliary",
    x = NULL, y = "KGC (billions $)",
    caption  = "Source: BEA Fixed Assets Tables 6.1, 7.1; GPIM construction"
  ) +
  theme_ch3()

save_png_pdf_dual(fig2, "fig02_NF_corp_vs_gov_trans", fig_dir)


## ==================================================================
## Figure 3: pK by Account (Own-Series Price Deflators, 2017=100)
## ==================================================================

if (!is.null(accounts_long)) {
  fig3_data <- accounts_long |>
    dplyr::filter(year %in% est_years) |>
    dplyr::select(year, account, pK) |>
    dplyr::mutate(
      account = dplyr::case_when(
        account == "NF_corp"   ~ "NF Corporate",
        account == "gov_trans" ~ "Gov Transport",
        account == "NF_IPP"    ~ "NF IPP",
        account == "fin_corp"  ~ "Financial Corp",
        TRUE ~ account
      )
    )

  fig3 <- ggplot(fig3_data, aes(x = year, y = pK, color = account)) +
    geom_line(linewidth = 0.8) +
    geom_hline(yintercept = 100, linetype = "dashed", color = "grey50",
               linewidth = 0.3) +
    scale_color_manual(values = ACCT_COLORS) +
    labs(
      title    = "Own-Series Capital Price Deflators by Account",
      subtitle = "pK_i = KNC_i / KNR_i * 100, rebased 2017 = 100",
      x = NULL, y = "pK (2017 = 100)",
      caption  = "Source: BEA Fixed Assets Tables 6.1/6.2/7.1/7.2; GPIM derivation"
    ) +
    theme_ch3()

  save_png_pdf_dual(fig3, "fig03_pK_by_account", fig_dir)
} else {
  message("  Skipping Figure 3: accounts_long.csv not found")
}


## ==================================================================
## Figure 4: z (Depreciation) and rho (Retirement) by Account
## ==================================================================

if (!is.null(accounts_long)) {
  fig4_data <- accounts_long |>
    dplyr::filter(year %in% est_years,
                  account %in% c("NF_corp", "gov_trans")) |>
    dplyr::select(year, account, z, rho) |>
    tidyr::pivot_longer(c(z, rho), names_to = "rate_type", values_to = "rate") |>
    dplyr::mutate(
      account = dplyr::case_when(
        account == "NF_corp"   ~ "NF Corporate",
        account == "gov_trans" ~ "Gov Transport",
        TRUE ~ account
      ),
      rate_type = dplyr::case_when(
        rate_type == "z"   ~ "Depreciation rate (z)",
        rate_type == "rho" ~ "Retirement rate (rho)",
        TRUE ~ rate_type
      )
    )

  fig4 <- ggplot(fig4_data, aes(x = year, y = rate, color = account)) +
    geom_line(linewidth = 0.7) +
    facet_wrap(~ rate_type, ncol = 1, scales = "free_y") +
    scale_color_manual(values = ACCT_COLORS[c("NF Corporate", "Gov Transport")]) +
    labs(
      title    = "Depreciation and Retirement Rates by Account",
      subtitle = "z = DEP/(pK * KNR_lag), rho = Weibull steady-state average",
      x = NULL, y = "Rate",
      caption  = "Source: GPIM derivation from BEA Fixed Assets"
    ) +
    theme_ch3()

  save_png_pdf_dual(fig4, "fig04_z_rho_by_account", fig_dir,
                    width = 7, height = 7)
} else {
  message("  Skipping Figure 4: accounts_long.csv not found")
}


## ==================================================================
## Figure 5: KNC vs KGC Gap (Gross-to-Net Ratio) by Account
## ==================================================================

if (!is.null(accounts_long)) {
  fig5_data <- accounts_long |>
    dplyr::filter(year %in% est_years) |>
    dplyr::mutate(
      gross_net_ratio = KGC / KNC,
      account = dplyr::case_when(
        account == "NF_corp"   ~ "NF Corporate",
        account == "gov_trans" ~ "Gov Transport",
        account == "NF_IPP"    ~ "NF IPP",
        account == "fin_corp"  ~ "Financial Corp",
        TRUE ~ account
      )
    ) |>
    dplyr::select(year, account, gross_net_ratio)

  fig5 <- ggplot(fig5_data, aes(x = year, y = gross_net_ratio,
                                 color = account)) +
    geom_line(linewidth = 0.7) +
    geom_hline(yintercept = 1, linetype = "dashed", color = "grey50",
               linewidth = 0.3) +
    facet_wrap(~ account, ncol = 2, scales = "free_y") +
    scale_color_manual(values = ACCT_COLORS) +
    labs(
      title    = "Gross-to-Net Capital Stock Ratio by Account",
      subtitle = "KGC/KNC — the depreciation wedge",
      x = NULL, y = "KGC / KNC",
      caption  = "Source: GPIM construction from BEA Fixed Assets"
    ) +
    theme_ch3() +
    theme(legend.position = "none")

  save_png_pdf_dual(fig5, "fig05_KNC_KGC_gap_by_account", fig_dir,
                    width = 8, height = 6)
} else {
  message("  Skipping Figure 5: accounts_long.csv not found")
}


## ----------------------------------------------------------
## Summary
## ----------------------------------------------------------

message("\n=== Dataset 2 Figures Complete ===")
message(sprintf("  Output directory: %s", fig_dir))
message("  fig01: KGC_productive vs KGC_total")
message("  fig02: NF corporate vs gov transport")
message("  fig03: pK by account (2017=100)")
message("  fig04: z and rho by account")
message("  fig05: KNC vs KGC gap by account")
