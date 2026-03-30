############################################################
# 48_assemble_dataset.R — Final Assembly
#
# Merges GDP with capital stocks, computes derived ratios,
# cross-validates against Shaikh canonical series (1947-2011),
# and writes the master dataset.
#
# Output: data/processed/master_dataset.csv
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

if (file.exists("codes/99_figure_protocol.R")) {
  source("codes/99_figure_protocol.R")
}

ensure_dirs(GDP_CONFIG)


## ==============================================================
## Load all processed data
## ==============================================================

message("=== Loading processed datasets ===\n")

# GDP
gdp <- readr::read_csv(
  file.path(GDP_CONFIG$PROCESSED, "gdp_us_1925_2024.csv"),
  show_col_types = FALSE
)
message(sprintf("GDP: %d-%d (%d obs)", min(gdp$year), max(gdp$year), nrow(gdp)))

# Private capital stocks (current-cost)
kstock_cc <- readr::read_csv(
  file.path(GDP_CONFIG$PROCESSED, "kstock_private_current_cost.csv"),
  show_col_types = FALSE
)

# Private capital stocks (GPIM real)
kstock_real <- readr::read_csv(
  file.path(GDP_CONFIG$PROCESSED, "kstock_private_gpim_real.csv"),
  show_col_types = FALSE
)

# Deflators
deflators <- readr::read_csv(
  file.path(GDP_CONFIG$PROCESSED, "price_deflators.csv"),
  show_col_types = FALSE
)

# Government (if available)
govt_path <- file.path(GDP_CONFIG$PROCESSED, "kstock_government.csv")
has_govt <- file.exists(govt_path)
if (has_govt) {
  kstock_govt <- readr::read_csv(govt_path, show_col_types = FALSE)
  message(sprintf("Government K: %d obs", nrow(kstock_govt)))
}

# Shaikh-adjusted (if available)
adj_path <- file.path(GDP_CONFIG$PROCESSED, "kstock_shaikh_adjusted.csv")
has_adj <- file.exists(adj_path)

# SFC validation summary
sfc_path <- file.path(GDP_CONFIG$PROCESSED, "stock_flow_validation.csv")
has_sfc <- file.exists(sfc_path)

message("\n=== Assembling master dataset ===\n")

## ==============================================================
## Merge GDP with capital stocks
## ==============================================================

master <- gdp |>
  left_join(kstock_cc, by = "year", suffix = c("", "_cc")) |>
  left_join(kstock_real, by = "year", suffix = c("", "_real"))

# Add deflators
master <- master |>
  left_join(deflators, by = "year", suffix = c("", "_defl"))

message(sprintf("Master dataset: %d rows, %d columns", nrow(master), ncol(master)))

## ==============================================================
## Compute derived ratios
## ==============================================================

message("Computing derived ratios...")

# For the key productive capital aggregate: TOTAL_PRODUCTIVE = ME + NRC + RC
# Use GPIM real for output-capital ratios

# Identify available capital stock columns
k_cols_real <- grep("_K_net_real$", names(master), value = TRUE)
k_cols_cc   <- grep("_K_net_cc$", names(master), value = TRUE)
ig_cols_cc  <- grep("_IG_cc$", names(master), value = TRUE)
d_cols_cc   <- grep("_D_cc$", names(master), value = TRUE)

# Compute ratios for TOTAL_PRODUCTIVE if available
tp_k_real <- "TOTAL_PRODUCTIVE_K_net_real"
tp_k_cc   <- "TOTAL_PRODUCTIVE_K_net_cc"
tp_ig_cc  <- "TOTAL_PRODUCTIVE_IG_cc"
tp_d_cc   <- "TOTAL_PRODUCTIVE_D_cc"

if (tp_k_real %in% names(master) && "gdp_real_2017" %in% names(master)) {
  master <- master |>
    mutate(
      # Output-capital ratio (Y/K) — real
      yk_ratio_real = gdp_real_2017 / !!sym(tp_k_real),
      # Investment-output ratio (I/Y) — nominal
      iy_ratio_nom = ifelse(gdp_nominal > 0,
                             !!sym(tp_ig_cc) / gdp_nominal,
                             NA_real_),
      # Depreciation-output ratio (D/Y) — nominal
      dy_ratio_nom = ifelse(gdp_nominal > 0,
                             !!sym(tp_d_cc) / gdp_nominal,
                             NA_real_),
      # Investment-capital ratio (I/K) — nominal
      ik_ratio_nom = ifelse(!!sym(tp_k_cc) > 0,
                             !!sym(tp_ig_cc) / !!sym(tp_k_cc),
                             NA_real_),
      # Depreciation-capital ratio (D/K) — nominal
      dk_ratio_nom = ifelse(!!sym(tp_k_cc) > 0,
                             !!sym(tp_d_cc) / !!sym(tp_k_cc),
                             NA_real_)
    )
  message("  Computed: Y/K, I/Y, D/Y, I/K, D/K for TOTAL_PRODUCTIVE")
}

# NOTE: NR = TOTAL_PRODUCTIVE = ME + NRC (RC excluded from productive capital).
# No separate NR ratio needed — yk_ratio_real already covers this.


## ==============================================================
## Cross-validation with Shaikh canonical series (1947-2011)
## ==============================================================

message("\n--- Cross-validation with Shaikh canonical series ---")

shaikh_path <- "data/raw/Shaikh_canonical_series_v1.csv"
if (file.exists(shaikh_path)) {
  shaikh <- readr::read_csv(shaikh_path, show_col_types = FALSE)

  # Overlap period
  overlap_years <- intersect(master$year, shaikh$year)
  message(sprintf("Overlap period: %d-%d (%d years)",
                  min(overlap_years), max(overlap_years), length(overlap_years)))

  # Compare KGCcorp (Shaikh's gross corporate K) if available
  if ("KGCcorp" %in% names(shaikh) && tp_k_cc %in% names(master)) {
    xval <- shaikh |>
      select(year, K_shaikh = KGCcorp) |>
      inner_join(master |> select(year, K_new = !!sym(tp_k_cc)), by = "year") |>
      filter(!is.na(K_shaikh), !is.na(K_new))

    if (nrow(xval) > 0) {
      corr <- cor(xval$K_shaikh, xval$K_new, use = "complete.obs")
      ratio <- mean(xval$K_new / xval$K_shaikh, na.rm = TRUE)
      message(sprintf("  K correlation: %.4f, mean ratio (new/Shaikh): %.4f",
                       corr, ratio))
    }
  }

  # Compare VAcorp (Shaikh's corporate VA) with GDP
  if ("VAcorp" %in% names(shaikh)) {
    xval_y <- shaikh |>
      select(year, VA_shaikh = VAcorp) |>
      inner_join(master |> select(year, gdp_nominal), by = "year") |>
      filter(!is.na(VA_shaikh), !is.na(gdp_nominal))

    if (nrow(xval_y) > 0) {
      # VA_corp should be a fraction of GDP (corporate share)
      ratio_y <- mean(xval_y$VA_shaikh / xval_y$gdp_nominal, na.rm = TRUE)
      message(sprintf("  Corporate VA / GDP ratio: %.4f (expected ~0.5-0.7)",
                       ratio_y))
    }
  }

  # Compare pIGcorpbea (investment deflator) with our deflators
  if ("pIGcorpbea" %in% names(shaikh) && "ME_p_K" %in% names(master)) {
    xval_p <- shaikh |>
      select(year, p_shaikh = pIGcorpbea) |>
      inner_join(master |> select(year, p_new = ME_p_K), by = "year") |>
      filter(!is.na(p_shaikh), !is.na(p_new))

    if (nrow(xval_p) > 0) {
      corr_p <- cor(xval_p$p_shaikh, xval_p$p_new, use = "complete.obs")
      message(sprintf("  Price deflator correlation: %.4f", corr_p))
    }
  }
} else {
  message("  Shaikh canonical series not found. Skipping cross-validation.")
}


## ==============================================================
## Summary figures
## ==============================================================

message("\n--- Generating summary figures ---")

# Figure 1: GDP series
if ("gdp_real_2017" %in% names(master)) {
  p_gdp <- ggplot(master, aes(x = year, y = gdp_real_2017)) +
    geom_line(linewidth = 0.6) +
    labs(title = "US Real GDP (2017 dollars)",
         x = "Year", y = "Billions of 2017$") +
    theme_minimal()
  ggsave(file.path(GDP_CONFIG$INTERIM_FIGURES, "fig_gdp_series.png"),
         p_gdp, width = 8, height = 5, dpi = 150)
  message("  fig_gdp_series.png")
}

# Figure 2: Capital stock composition (current-cost)
comp_cols <- c("ME_K_net_cc", "NRC_K_net_cc", "RC_K_net_cc", "IP_K_net_cc")
comp_cols_present <- comp_cols[comp_cols %in% names(master)]

if (length(comp_cols_present) >= 2) {
  comp_df <- master |>
    select(year, all_of(comp_cols_present)) |>
    tidyr::pivot_longer(-year, names_to = "asset", values_to = "value") |>
    mutate(asset = gsub("_K_net_cc", "", asset))

  p_comp <- ggplot(comp_df, aes(x = year, y = value, fill = asset)) +
    geom_area(alpha = 0.7) +
    labs(title = "Private Capital Stock Composition (Current Cost, Net)",
         x = "Year", y = "Billions of $",
         fill = "Asset") +
    theme_minimal()
  ggsave(file.path(GDP_CONFIG$INTERIM_FIGURES, "fig_kstock_composition.png"),
         p_comp, width = 8, height = 5, dpi = 150)
  message("  fig_kstock_composition.png")
}

# Figure 3: Output-capital ratio (if computed)
if ("yk_ratio_real" %in% names(master)) {
  p_yk <- ggplot(master |> filter(!is.na(yk_ratio_real)),
                  aes(x = year, y = yk_ratio_real)) +
    geom_line(linewidth = 0.6) +
    labs(title = "Output-Capital Ratio (Y/K, GPIM-deflated)",
         x = "Year", y = "Y/K") +
    theme_minimal()
  ggsave(file.path(GDP_CONFIG$INTERIM_FIGURES, "fig_yk_ratio.png"),
         p_yk, width = 8, height = 5, dpi = 150)
  message("  fig_yk_ratio.png")
}


## ==============================================================
## Write master dataset
## ==============================================================

out_path <- file.path(GDP_CONFIG$PROCESSED, "master_dataset.csv")
safe_write_csv(master, out_path)

message(sprintf("\n=== Assembly complete ==="))
message(sprintf("Master dataset: %s", out_path))
message(sprintf("  %d rows x %d columns", nrow(master), ncol(master)))
message(sprintf("  Years: %d-%d", min(master$year), max(master$year)))
message(sprintf("Figures: %s", GDP_CONFIG$INTERIM_FIGURES))

# Build metadata
metadata <- tibble(
  field = c("build_date", "year_range", "n_rows", "n_cols",
            "adj_depression", "adj_wwii", "adj_gpim", "adj_quality",
            "gpim_base_year", "sfc_tolerance"),
  value = c(as.character(Sys.time()),
            sprintf("%d-%d", min(master$year), max(master$year)),
            as.character(nrow(master)),
            as.character(ncol(master)),
            as.character(GDP_CONFIG$ADJ_DEPRESSION_SCRAPPING),
            as.character(GDP_CONFIG$ADJ_WWII_INTERPOLATION),
            as.character(GDP_CONFIG$ADJ_GPIM_DEFLATION),
            as.character(GDP_CONFIG$ADJ_QUALITY_CRITIQUE),
            as.character(GDP_CONFIG$GPIM$base_year),
            as.character(GDP_CONFIG$GPIM$sfc_tolerance))
)
safe_write_csv(metadata,
  file.path(GDP_CONFIG$INTERIM_LOGS, "build_metadata.csv"))

message("\nDone.")
