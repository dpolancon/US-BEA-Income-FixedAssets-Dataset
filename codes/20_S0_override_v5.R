library(ARDL)
library(dynlm)
library(dplyr)
library(here)
source("codes/10_config.R")
source("codes/99_utils.R")

# ── Logging ───────────────────────────────────────────────────────────
out_dir <- here::here("output", "CriticalReplication", "S0_manualOverride")


LOG <- function(...) {
  txt <- paste0(capture.output(cat(...)), collapse = "\n")
  cat(txt, "\n")
  cat(txt, "\n", file = log_file, append = TRUE)
}

LOG_PRINT <- function(x) {
  txt <- paste0(capture.output(print(x)), collapse = "\n")
  cat(txt, "\n")
  cat(txt, "\n", file = log_file, append = TRUE)
}

# ── Data ──────────────────────────────────────────────────────────────
df <- readr::read_csv(here::here(CONFIG[["data_shaikh"]]), show_col_types = FALSE)

build_data <- function(df) {
  df |>
    filter(year >= 1947, year <= 2011) |>
    mutate(
      lnY   = log(VAcorp / (Py / 100)),
      lnK   = log(KGCcorp / (Py / 100)),
      d1956 = as.integer(year >= 1956),
      d1974 = as.integer(year >= 1974),
      d1980 = as.integer(year >= 1980),
      trend = row_number()
    )
}

df <- build_data(df)


# =====================================================================
#  GATHER: 8-series CU panel and merge to Shaikh data 
# =====================================================================

cu_manifest <- tibble::tribble(
  ~file,                  ~j,
  "cu_notrend_VAKG.csv",  "va_gk_nt",
  "cu_trend_VAKG.csv",    "va_gk_t",
  "cu_notrend_GVAKG.csv", "gva_gk_nt",
  "cu_trend_GVAKG.csv",   "gva_gk_t",
  "cu_notrend_VAKN.csv",  "va_nk_nt",
  "cu_trend_VAKN.csv",    "va_nk_t",
  "cu_notrend_GVAKN.csv", "gva_nk_nt",
  "cu_trend_GVAKN.csv",   "gva_nk_t"
)

cu_panel <- purrr::map(
  purrr::transpose(cu_manifest),
  function(row) {
    readr::read_csv(file.path(out_dir, row$file), show_col_types = FALSE) |>
      dplyr::select(year, cu) |>
      dplyr::rename(!!paste0("cu_", row$j) := cu)
  }
) |>
  purrr::reduce(dplyr::full_join, by = "year")

#Merge of CU measures and shaikh data 
df <- df |> dplyr::left_join(cu_panel, by = "year")



# =====================================================================
#  PLOT: 8 CU series vs. uFRB and uK benchmarks
# =====================================================================
library(ggplot2)
library(tidyr)
library(dplyr)
library(ggrepel)

# ── 1. Reshape to long ───────────────────────────────────────────────

cu_long <- df |>
  filter(year >= 1947, year <= 2011) |>
  select(year, uFRB, uK,
         cu_va_gk_nt, cu_va_gk_t,
         cu_gva_gk_nt, cu_gva_gk_t,
         cu_va_nk_nt, cu_va_nk_t,
         cu_gva_nk_nt, cu_gva_nk_t) |>
  pivot_longer(-year, names_to = "series", values_to = "value") |>
  mutate(
    role = case_when(
      series %in% c("uFRB", "uK") ~ "benchmark",
      endsWith(series, "_nt")     ~ "no_trend",
      endsWith(series, "_t")      ~ "trend"
    ),
    role = factor(role, levels = c("no_trend", "trend", "benchmark"))
  )

# ── 2. Separate benchmark data (no cluster var → repeats in both facets) ──

benchmark_long <- cu_long |> filter(role == "benchmark")
alts_long      <- cu_long |> filter(role != "benchmark") |>
  mutate(cluster = if_else(role == "trend", "Trend", "No Trend"))

# ── 3. Endpoint labels for benchmarks ───────────────────────────────

bench_labels <- benchmark_long |>
  group_by(series) |>
  slice_max(year)

# ── 4. Color palettes ────────────────────────────────────────────────

alt_colors <- c(
  "cu_va_gk_nt"  = "#9ECAE1",
  "cu_gva_gk_nt" = "#3182BD",
  "cu_va_nk_nt"  = "#FDAE6B",
  "cu_gva_nk_nt" = "#E6550D",
  "cu_va_gk_t"   = "#9ECAE1",
  "cu_gva_gk_t"  = "#3182BD",
  "cu_va_nk_t"   = "#FDAE6B",
  "cu_gva_nk_t"  = "#E6550D"
)

bench_colors <- c("uFRB" = "#000000", "uK" = "#B22222")

# ── 5. Plot ──────────────────────────────────────────────────────────

p <- ggplot() +
  # Layer 1: alternatives (muted, behind)
  geom_line(
    data = alts_long,
    aes(x = year, y = value, group = series, color = series),
    linewidth = 0.5, alpha = 0.45
  ) +
  # Layer 2: benchmarks (bold, on top, repeated across both facets)
  geom_line(
    data = benchmark_long,
    aes(x = year, y = value, group = series, color = series),
    linewidth = 1.2
  ) +
  # Layer 3: benchmark endpoint labels
  geom_label_repel(
    data = bench_labels,
    aes(x = year, y = value, label = series, color = series),
    size = 3, nudge_x = 1, show.legend = FALSE
  ) +
  # Facet by cluster; benchmark data (no cluster column) repeats in both
  facet_wrap(~cluster, ncol = 2) +
  scale_color_manual(
    values = c(alt_colors, bench_colors),
    breaks = c("uFRB", "uK"),         # only benchmarks in legend
    labels = c("FRB (benchmark)", "Shaikh uK (benchmark)")
  ) +
  scale_x_continuous(breaks = seq(1950, 2010, 10)) +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
  labs(
    title    = "Implicit Capacity Utilization: 8 Pairings vs. Benchmarks",
    subtitle = "US Corporate Sector, 1947–2011 | ARDL(2,4) long-run residual",
    x        = NULL,
    y        = "Capacity Utilization Rate",
    color    = NULL,
    caption  = "Trend/no-trend toggle = Pesaran Case III vs. Case II.\nBlue family: Gross Capital Stock (GK). Orange family: Net Capital Stock (NK)."
  ) +
  theme_bw(base_size = 12) +
  theme(
    panel.grid.minor  = element_blank(),
    panel.grid.major  = element_line(color = "grey90"),
    legend.position   = "bottom",
    legend.key.width  = unit(1.5, "cm"),
    strip.background  = element_rect(fill = "grey95"),
    strip.text        = element_text(face = "bold"),
    plot.caption      = element_text(size = 8, color = "grey50")
  ) +
  guides(alpha = "none", linewidth = "none")


ggsave(file.path(out_dir, "cu_comparison_8series.pdf"),
       plot = p, width = 10, height = 5.5, dpi = 300)

ggsave(file.path(out_dir, "cu_comparison_8series.png"),
       plot = p, width = 10, height = 5.5, dpi = 300)


# =====================================================================
#  PLOT: 8 CU series vs. uFRB and uK benchmarks — 2 files by cluster
# =====================================================================

# ── 1. Reshape to long ───────────────────────────────────────────────

cu_long <- df |>
  filter(year >= 1947, year <= 2011) |>
  select(year, uFRB, uK,
         cu_va_gk_nt, cu_va_gk_t,
         cu_gva_gk_nt, cu_gva_gk_t,
         cu_va_nk_nt, cu_va_nk_t,
         cu_gva_nk_nt, cu_gva_nk_t) |>
  pivot_longer(-year, names_to = "series", values_to = "value") |>
  mutate(
    role = case_when(
      series %in% c("uFRB", "uK") ~ "benchmark",
      endsWith(series, "_nt")     ~ "no_trend",
      endsWith(series, "_t")      ~ "trend"
    ),
    role = factor(role, levels = c("no_trend", "trend", "benchmark"))
  )

# ── 2. Split components ──────────────────────────────────────────────

benchmark_long <- cu_long |> filter(role == "benchmark")
trend_long     <- cu_long |> filter(role == "trend")
notrend_long   <- cu_long |> filter(role == "no_trend")

bench_labels <- benchmark_long |> group_by(series) |> slice_max(year)

# ── 3. Color palettes ────────────────────────────────────────────────

alt_colors <- c(
  # GK pairings — blue family
  "cu_va_gk_nt"  = "#9ECAE1",
  "cu_gva_gk_nt" = "#2171B5",
  "cu_va_gk_t"   = "#9ECAE1",
  "cu_gva_gk_t"  = "#2171B5",
  # NK pairings — orange family
  "cu_va_nk_nt"  = "#FDAE6B",
  "cu_gva_nk_nt" = "#D94801",
  "cu_va_nk_t"   = "#FDAE6B",
  "cu_gva_nk_t"  = "#D94801"
)

bench_colors <- c("uFRB" = "#000000", "uK" = "#B22222")
all_colors   <- c(alt_colors, bench_colors)

# ── 4. Shared theme ──────────────────────────────────────────────────

base_theme <- theme_bw(base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(color = "grey90"),
    legend.position  = "bottom",
    legend.key.width = unit(1.5, "cm"),
    plot.caption     = element_text(size = 8, color = "grey50")
  )

# ── 5. Plot factory ──────────────────────────────────────────────────
make_cu_plot <- function(alt_data, cluster_label) {
  subtitle_suffix <- paste0(
    "Pesaran ",
    if (cluster_label == "Long-Run Trend Component") "Case III (restricted trend)" 
    else "Case II (no deterministic trend)"
  )

  ggplot() +
    geom_line(
      data = alt_data,
      aes(x = year, y = value, group = series, color = series),
      linewidth = 0.55, alpha = 0.5
    ) +
    geom_line(
      data = benchmark_long,
      aes(x = year, y = value, group = series, color = series),
      linewidth = 1.2
    ) +
    geom_label_repel(
      data = bench_labels,
      aes(x = year, y = value, label = series, color = series),
      size = 3, nudge_x = 1, show.legend = FALSE
    ) +
    scale_color_manual(
      values = all_colors,
      breaks = c("uFRB", "uK"),
      labels = c("FRB (benchmark)", "Shaikh uK (benchmark)")
    ) +
    scale_x_continuous(breaks = seq(1950, 2010, 10)) +
    scale_y_continuous(labels = scales::label_number(accuracy = 0.01)) +
    labs(
      title    = paste0("Implicit CU — ", cluster_label),
      subtitle = paste0("US Corporate Sector, 1947–2011 | ", subtitle_suffix),
      x        = NULL,
      y        = "Capacity Utilization (exp(ECT))",
      color    = NULL,
      caption  = "Blue: Gross Capital Stock pairings. Orange: Net Capital Stock pairings.\nLight shade: VA. Dark shade: GVA."
    ) +
    base_theme +
    guides(alpha = "none", linewidth = "none")
}

# ── 6. Build and export ──────────────────────────────────────────────

p_notrend <- make_cu_plot(notrend_long, "No Long-Run Trend Component")
p_trend   <- make_cu_plot(trend_long,   "Long-Run Trend Component")

save_plot <- function(p, filename_stem) {
  ggsave(file.path(out_dir, paste0(filename_stem, ".pdf")),
         plot = p, width = 9, height = 5, dpi = 300, device = cairo_pdf)
  ggsave(file.path(out_dir, paste0(filename_stem, ".png")),
         plot = p, width = 9, height = 5, dpi = 150, bg = "white")
}

save_plot(p_notrend, "cu_comparison_notrend")
save_plot(p_trend,   "cu_comparison_trend")
