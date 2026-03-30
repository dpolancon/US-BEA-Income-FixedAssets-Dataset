#!/usr/bin/env Rscript
# ══════════════════════════════════════════════════════════════════════
#  S0–S1 Closing Figure: Capacity Utilization Fan
#  Loops over {pairing × lag order × trend × dummy treatment}
#  Exports: (1) long CSV of all CU series, (2) faceted fan figure
# ══════════════════════════════════════════════════════════════════════

library(ARDL)
library(dynlm)
library(dplyr)
library(tidyr)
library(ggplot2)
library(readr)
library(here)
library(RColorBrewer)

source("codes/10_config.R")
source("codes/99_utils.R")

# ── Output directory ──────────────────────────────────────────────────
out_dir <- here::here("output", "CriticalReplication", "S0_S1_fan")
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

# ── Load data ─────────────────────────────────────────────────────────
df_raw <- read_csv(here::here(CONFIG[["data_shaikh"]]), show_col_types = FALSE) |>
  filter(year >= 1947, year <= 2011)

# ── Configuration grid ────────────────────────────────────────────────
# Each row defines one ARDL specification → one ECT → one CU series.
#
# Three "families":
#   S0:    ARDL(2,4), step dummies in LR   (replicates v1–v4)
#   S1d:   ARDL(1,3), impulse dummies, transitory (replicates v6)
#   S1nd:  ARDL(1,3), no dummies            (replicates v7)

pairings <- tibble::tribble(
  ~Y_col,     ~K_col,         ~Y_label, ~K_label,
  "VAcorp",   "KGCcorp",      "NVA",    "KG",
  "GVAcorp",  "KGCcorp",      "GVA",    "KG",
  "VAcorp",   "KNCcorpbea",   "NVA",    "KN",
  "GVAcorp",  "KNCcorpbea",   "GVA",    "KN"
)

specs <- tibble::tribble(
  ~order_p, ~order_q, ~has_trend, ~dummy_type, ~family,
  2L,       4L,       FALSE,      "step",      "S0",
  2L,       4L,       TRUE,       "step",      "S0",
  1L,       3L,       FALSE,      "impulse",   "S1d",
  1L,       3L,       TRUE,       "impulse",   "S1d",
  1L,       3L,       FALSE,      "none",      "S1nd",
  1L,       3L,       TRUE,       "none",      "S1nd"
)

grid <- tidyr::crossing(pairings, specs)

cat(sprintf("Grid: %d specifications\n", nrow(grid)))

# ══════════════════════════════════════════════════════════════════════
#  Core estimation function
# ══════════════════════════════════════════════════════════════════════

estimate_cu <- function(df_raw, Y_col, K_col, order_p, order_q,
                        has_trend, dummy_type) {
  
  # ── Build data ────────────────────────────────────────────────────
  df_w <- df_raw |>
    mutate(
      lnY   = log(.data[[Y_col]] / (Py / 100)),
      lnK   = log(.data[[K_col]] / (Py / 100)),
      trend = row_number()
    )
  
  # Dummies (step or impulse or none)
  if (dummy_type == "step") {
    df_w <- df_w |> mutate(
      d1956 = as.integer(year >= 1956),
      d1974 = as.integer(year >= 1974),
      d1980 = as.integer(year >= 1980)
    )
  } else if (dummy_type == "impulse") {
    df_w <- df_w |> mutate(
      d1956 = as.integer(year == 1956),
      d1974 = as.integer(year == 1974),
      d1980 = as.integer(year == 1980)
    )
  }
  
  has_dummies <- dummy_type %in% c("step", "impulse")
  
  # ── ts object ─────────────────────────────────────────────────────
  ts_cols <- c("lnY", "lnK")
  if (has_dummies) ts_cols <- c(ts_cols, "d1956", "d1974", "d1980")
  df_ts <- ts(df_w |> select(all_of(ts_cols)), start = 1947, frequency = 1)
  
  # ── Build dynlm formula ───────────────────────────────────────────
  p <- order_p
  q <- order_q
  
  # Y lags
  y_lags <- paste0("L(lnY, ", 1:p, ")", collapse = " + ")
  
  # K lags (contemporaneous + lagged)
  k_terms <- c("lnK")
  if (q >= 1) k_terms <- c(k_terms, paste0("L(lnK, ", 1:q, ")"))
  k_lags <- paste(k_terms, collapse = " + ")
  
  # Trend
  trend_term <- if (has_trend) "trend(lnY) + " else ""
  
  # Dummies
  dummy_term <- if (has_dummies) " + d1956 + d1974 + d1980" else ""
  
  fml_str <- sprintf("lnY ~ %s%s + %s%s", trend_term, y_lags, k_lags, dummy_term)
  fml <- as.formula(fml_str)
  
  # ── Estimate ARDL ─────────────────────────────────────────────────
  fit <- tryCatch(
    dynlm(fml, data = df_ts, start = 1947, end = 2011),
    error = function(e) { message("ARDL failed: ", e$message); return(NULL) }
  )
  if (is.null(fit)) return(NULL)
  
  cc <- coef(fit)
  
  # ── Extract autoregressive sum ────────────────────────────────────
  gamma_names <- paste0("L(lnY, ", 1:p, ")")
  gamma_sum   <- sum(cc[gamma_names])
  denom       <- 1 - gamma_sum
  
  # ── Extract capital sum ───────────────────────────────────────────
  phi_names <- c("lnK")
  if (q >= 1) phi_names <- c(phi_names, paste0("L(lnK, ", 1:q, ")"))
  phi_sum <- sum(cc[phi_names])
  
  # ── Long-run multipliers ──────────────────────────────────────────
  a     <- cc["(Intercept)"] / denom
  theta <- phi_sum / denom
  
  b <- if (has_trend) cc["trend(lnY)"] / denom else 0
  
  # Dummy LR multipliers (only for step dummies in LR)
  if (dummy_type == "step") {
    c1_lr <- cc["d1956"] / denom
    c2_lr <- cc["d1974"] / denom
    c3_lr <- cc["d1980"] / denom
  } else {
    c1_lr <- 0
    c2_lr <- 0
    c3_lr <- 0
  }
  
  # ── Construct ECT ─────────────────────────────────────────────────
  lr_fitted <- a + theta * df_w$lnK
  
  if (has_trend) lr_fitted <- lr_fitted + b * df_w$trend
  
  if (dummy_type == "step") {
    lr_fitted <- lr_fitted +
      c1_lr * df_w$d1956 +
      c2_lr * df_w$d1974 +
      c3_lr * df_w$d1980
  }
  # impulse and none: dummies not in LR, so no addition
  
  ECT_raw  <- df_w$lnY - lr_fitted
  ECT_mean <- mean(ECT_raw)
  ECT      <- ECT_raw - ECT_mean
  cu       <- exp(ECT)
  
  # ── Return ────────────────────────────────────────────────────────
  tibble(
    year    = df_w$year,
    cu      = cu,
    theta   = theta,
    denom   = denom,
    pi_y    = NA_real_  # filled later if RECM is run
  )
}


# ══════════════════════════════════════════════════════════════════════
#  Run grid
# ══════════════════════════════════════════════════════════════════════

results <- list()

for (i in seq_len(nrow(grid))) {
  g <- grid[i, ]
  
  spec_id <- sprintf("%s~%s|(%d,%d)|%s|%s",
                     g$Y_label, g$K_label,
                     g$order_p, g$order_q,
                     ifelse(g$has_trend, "trend", "notrend"),
                     g$dummy_type)
  cat(sprintf("[%2d/%d] %s ... ", i, nrow(grid), spec_id))
  
  out <- estimate_cu(
    df_raw   = df_raw,
    Y_col    = g$Y_col,
    K_col    = g$K_col,
    order_p  = g$order_p,
    order_q  = g$order_q,
    has_trend = g$has_trend,
    dummy_type = g$dummy_type
  )
  
  if (!is.null(out)) {
    out <- out |> mutate(
      spec_id    = spec_id,
      Y_label    = g$Y_label,
      K_label    = g$K_label,
      order_label = sprintf("(%d,%d)", g$order_p, g$order_q),
      trend_label = ifelse(g$has_trend, "Trend", "No Trend"),
      dummy_label = g$dummy_type,
      family      = g$family,
      pairing     = sprintf("%s ~ K^%s", g$Y_label, g$K_label)
    )
    results[[spec_id]] <- out
    cat(sprintf("theta = %.4f, denom = %.4f\n", out$theta[1], out$denom[1]))
  } else {
    cat("FAILED\n")
  }
}

cu_all <- bind_rows(results)
cat(sprintf("\nTotal series: %d | Total rows: %d\n",
            n_distinct(cu_all$spec_id), nrow(cu_all)))

# ── Export long CSV ───────────────────────────────────────────────────
write_csv(cu_all, file.path(out_dir, "cu_fan_all_series.csv"))
cat("Exported:", file.path(out_dir, "cu_fan_all_series.csv"), "\n")


# ══════════════════════════════════════════════════════════════════════
#  Summary table: theta × denom × spec
# ══════════════════════════════════════════════════════════════════════

summary_tbl <- cu_all |>
  distinct(spec_id, Y_label, K_label, order_label, trend_label,
           dummy_label, family, theta, denom)

write_csv(summary_tbl, file.path(out_dir, "cu_fan_summary.csv"))
cat("\n── Summary ──\n")
print(as.data.frame(summary_tbl), row.names = FALSE)


# ══════════════════════════════════════════════════════════════════════
#  Benchmark series
# ══════════════════════════════════════════════════════════════════════

# Shaikh's published uK (if available in dataset)
# FRB capacity utilization (if available in dataset)
# Adapt column names to your CONFIG

benchmarks <- df_raw |>
  select(year, any_of(c("uK", "uFRB"))) |>
  pivot_longer(-year, names_to = "series", values_to = "cu") |>
  filter(!is.na(cu))

if ("uK" %in% names(df_raw)) {
  cat("Shaikh uK benchmark found\n")
} else {
  cat("WARNING: uK not in dataset — add manually\n")
}
if ("uFRB" %in% names(df_raw)) {
  cat("FRB benchmark found\n")
} else {
  cat("WARNING: uFRB not in dataset — add manually\n")
}


# ══════════════════════════════════════════════════════════════════════
#  Fan figure: facet by K concept (Option A from flag)
# ══════════════════════════════════════════════════════════════════════

# ── Color palette ─────────────────────────────────────────────────────
blues   <- brewer.pal(6, "Blues")[3:6]
oranges <- brewer.pal(6, "Oranges")[3:6]

# Assign colors within each K family
cu_plot <- cu_all |>
  mutate(
    K_facet = ifelse(K_label == "KG",
                     "Gross Capital Stock (K^G)",
                     "Net Capital Stock (K^N)"),
    K_facet = factor(K_facet, levels = c("Gross Capital Stock (K^G)",
                                         "Net Capital Stock (K^N)")),
    # Visual encoding
    lw = case_when(
      order_label == "(1,3)" ~ 0.7,
      order_label == "(2,4)" ~ 0.4
    ),
    lt = case_when(
      dummy_label == "step"    ~ "solid",
      dummy_label == "impulse" ~ "dashed",
      dummy_label == "none"    ~ "dotted"
    ),
    # Alpha: no-trend specs more opaque, trend specs more transparent
    alpha_val = ifelse(trend_label == "No Trend", 0.55, 0.30)
  )

# ── Build plot ────────────────────────────────────────────────────────

p <- ggplot() +
  # Layer 1: CU fan (grouped lines)
  geom_line(
    data = cu_plot,
    aes(x = year, y = cu, group = spec_id,
        color = K_label, alpha = alpha_val,
        linewidth = lw, linetype = lt)
  ) +
  # Layer 2: Benchmarks (bold, on top)
  {if (nrow(benchmarks) > 0)
    geom_line(
      data = benchmarks,
      aes(x = year, y = cu, color = series),
      linewidth = 1.2, alpha = 1
    )
  } +
  # Scales
  scale_color_manual(
    values = c(
      "KG"   = "#3182BD",   # blue family
      "KN"   = "#E6550D",   # orange family
      "uK"   = "#8B0000",   # dark red — Shaikh
      "uFRB" = "#000000"    # black — FRB
    ),
    labels = c(
      "KG"   = "Gross K pairings",
      "KN"   = "Net K pairings",
      "uK"   = "Shaikh uK (benchmark)",
      "uFRB" = "FRB (benchmark)"
    ),
    name = NULL
  ) +
  scale_alpha_identity() +
  scale_linewidth_identity() +
  scale_linetype_identity() +
  scale_y_continuous(labels = scales::percent_format(1)) +
  facet_wrap(~ K_facet) +
  labs(
    title    = "Implicit Capacity Utilization: S0–S1 Specification Fan",
    subtitle = "US Corporate Sector, 1947–2011 | ARDL long-run residual, demeaned",
    x = NULL, y = "Capacity Utilization Rate",
    caption = paste0(
      "Solid = step dummies (S0); Dashed = impulse dummies (S1); ",
      "Dotted = no dummies (S1).\n",
      "Heavier lines = ARDL(1,3) IC-preferred; lighter = ARDL(2,4) Shaikh.\n",
      "More opaque = no trend (Cases 2–3); more transparent = trend (Cases 4–5).\n",
      "Blue family: Gross K. Orange family: Net K."
    )
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position  = "bottom",
    legend.direction = "horizontal",
    panel.grid.minor = element_blank(),
    strip.text       = element_text(face = "bold", size = 11),
    plot.caption     = element_text(size = 8, hjust = 0)
  )

# ── Save ──────────────────────────────────────────────────────────────
ggsave(file.path(out_dir, "cu_fan_S0_S1.png"),
       plot = p, width = 14, height = 7, dpi = 300)
ggsave(file.path(out_dir, "cu_fan_S0_S1.pdf"),
       plot = p, width = 14, height = 7)

cat("\nFigure saved to:", file.path(out_dir, "cu_fan_S0_S1.png"), "\n")
cat("Done.\n")