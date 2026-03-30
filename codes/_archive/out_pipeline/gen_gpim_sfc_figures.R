############################################################
# gen_gpim_sfc_figures.R
#
# Generates figures for the GPIM stock-flow consistency
# evidence from the capital ratio analysis.
#
# Input:  output/gpim_sfc_consistency/csv/capital_ratio_analysis.csv
# Output: output/gpim_sfc_consistency/figures/
#
# NOT part of the main pipeline (codes/24_manifest_runner.R).
# Run standalone when figures need regeneration.
############################################################

rm(list = ls())

library(here)
library(dplyr)
library(tidyr)
library(ggplot2)
library(readr)

source(here::here("codes", "99_figure_protocol.R"))

# ---- paths ----
CSV_PATH <- here::here("output", "gpim_sfc_consistency", "csv",
                        "capital_ratio_analysis.csv")
FIG_DIR  <- here::here("output", "gpim_sfc_consistency", "figures")
dir.create(FIG_DIR, recursive = TRUE, showWarnings = FALSE)

stopifnot(file.exists(CSV_PATH))

df <- read_csv(CSV_PATH, show_col_types = FALSE)
cat("Loaded:", nrow(df), "obs,", min(df$year), "-", max(df$year), "\n")

# ============================================================
# Figure 1 — Y/K under GPIM vs chain-weighted deflation
# ============================================================

# Normalize both series to 1947=1 for visual comparability
# (levels differ by orders of magnitude due to different deflation)
base_year <- 1947L
idx_base <- which(df$year == base_year)

plot_df1 <- df |>
  filter(!is.na(yk_gpim), !is.na(yk_chain)) |>
  mutate(
    yk_gpim_idx  = yk_gpim / yk_gpim[year == base_year],
    yk_chain_idx = yk_chain / yk_chain[year == base_year]
  ) |>
  select(year, yk_gpim_idx, yk_chain_idx) |>
  pivot_longer(-year, names_to = "regime", values_to = "yk_index") |>
  mutate(regime = case_when(
    regime == "yk_gpim_idx"  ~ "GPIM-deflated (SFC-consistent)",
    regime == "yk_chain_idx" ~ "Chain-weighted (BEA)"
  ))

p1 <- ggplot(plot_df1, aes(x = year, y = yk_index, color = regime)) +
  geom_line(linewidth = 0.8) +
  geom_hline(yintercept = 1, linetype = "dotted", color = "grey60") +
  geom_vline(xintercept = c(1973, 1985), linetype = "dashed",
             color = "grey50", alpha = 0.5) +
  annotate("text", x = 1973, y = max(plot_df1$yk_index, na.rm = TRUE) * 0.97,
           label = "1973", size = 2.5, color = "grey40", hjust = -0.2) +
  annotate("text", x = 1985, y = max(plot_df1$yk_index, na.rm = TRUE) * 0.97,
           label = "1985\nhedonic", size = 2.5, color = "grey40", hjust = -0.2) +
  scale_color_manual(values = c(
    "GPIM-deflated (SFC-consistent)" = PAL_OI["blue"],
    "Chain-weighted (BEA)"           = PAL_OI["vermillion"]
  )) +
  labs(
    x = "Year",
    y = expression("Y/K index (" * 1947 == 1 * ")"),
    title = "Output-Capital Ratio: GPIM vs Chain-Weighted Deflation",
    subtitle = "Indexed to 1947 = 1. Divergence reveals the deflator-regime effect on Y/K trend."
  ) +
  theme_ch3() +
  theme(legend.position = "bottom", legend.title = element_blank())

save_png_pdf_dual(p1, "fig_yk_gpim_vs_chain", FIG_DIR, width = 10, height = 6)
cat("Saved: fig_yk_gpim_vs_chain\n")


# ============================================================
# Figure 2 — Log divergence (ln Y/K_GPIM − ln Y/K_chain)
# ============================================================

plot_df2 <- df |>
  filter(!is.na(ln_divergence)) |>
  select(year, ln_divergence)

# Fit a trend line for annotation
fit_div <- lm(ln_divergence ~ year, data = plot_df2)
slope_per_decade <- coef(fit_div)["year"] * 10

p2 <- ggplot(plot_df2, aes(x = year, y = ln_divergence)) +
  geom_line(color = PAL_OI["blue"], linewidth = 0.8) +
  geom_smooth(method = "lm", se = TRUE, color = PAL_OI["orange"],
              fill = PAL_OI["orange"], alpha = 0.15, linewidth = 0.5) +
  geom_vline(xintercept = c(1973, 1985), linetype = "dashed",
             color = "grey50", alpha = 0.5) +
  annotate("text", x = 1973, y = max(plot_df2$ln_divergence) - 0.01,
           label = "1973", size = 2.5, color = "grey40", hjust = -0.2) +
  annotate("text", x = 1985, y = max(plot_df2$ln_divergence) - 0.01,
           label = "1985\nhedonic era", size = 2.5, color = "grey40", hjust = -0.2) +
  annotate("text", x = 1960, y = min(plot_df2$ln_divergence) + 0.02,
           label = sprintf("Trend: %.3f per decade", slope_per_decade),
           size = 3, color = PAL_OI["orange"]) +
  labs(
    x = "Year",
    y = expression(ln(Y/K)[GPIM] - ln(Y/K)[chain]),
    title = "Log Divergence Between GPIM and Chain-Weighted Capital Measures",
    subtitle = "Secular downward drift = chain-weighting inflates K relative to GPIM over time"
  ) +
  theme_ch3()

save_png_pdf_dual(p2, "fig_ln_divergence", FIG_DIR, width = 10, height = 6)
cat("Saved: fig_ln_divergence\n")


# ============================================================
# Figure 3 — Y/K (GPIM) with Fordism / Post-Fordism trends
# ============================================================

plot_df3 <- df |>
  filter(!is.na(ln_yk_gpim)) |>
  mutate(
    period = case_when(
      year >= 1947 & year <= 1973 ~ "Fordism (1947-1973)",
      year >= 1974 & year <= 2011 ~ "Post-Fordism (1974-2011)",
      TRUE                        ~ NA_character_
    )
  )

p3 <- ggplot(plot_df3, aes(x = year, y = ln_yk_gpim)) +
  geom_line(color = "grey40", linewidth = 0.5) +
  geom_smooth(
    data = plot_df3 |> filter(!is.na(period)),
    aes(group = period, color = period),
    method = "lm", se = TRUE, alpha = 0.15, linewidth = 0.7
  ) +
  geom_vline(xintercept = c(1947, 1973, 2011),
             linetype = "dashed", color = "grey60", alpha = 0.5) +
  scale_color_manual(values = c(
    "Fordism (1947-1973)"       = PAL_OI["blue"],
    "Post-Fordism (1974-2011)"  = PAL_OI["vermillion"]
  )) +
  labs(
    x = "Year",
    y = expression(ln(Y/K)[GPIM]),
    title = "Output-Capital Ratio (GPIM): Period Trends",
    subtitle = "Log scale. SFC-consistent deflation preserves the secular decline in Y/K."
  ) +
  theme_ch3() +
  theme(legend.position = "bottom", legend.title = element_blank())

save_png_pdf_dual(p3, "fig_yk_period_trends", FIG_DIR, width = 10, height = 6)
cat("Saved: fig_yk_period_trends\n")

cat("\nDone — all GPIM SFC figures generated.\n")
