############################################################
# 45_build_kstock_government.R — Government Capital Stocks
#
# Builds government fixed assets from BEA Tables 6.1-6.4.
# Sub-breakdown: defense vs nondefense, each with
# structures/equipment/IP (broad measures only).
#
# Follows same GPIM structure as 44_build_kstock_private.R.
#
# Output: data/processed/kstock_government.csv
#
# Sources: 40_gdp_kstock_config.R, 97_kstock_helpers.R
############################################################

rm(list = ls())

library(dplyr)
library(tidyr)
library(readr)

source("codes/40_gdp_kstock_config.R")
source("codes/99_utils.R")
source("codes/97_kstock_helpers.R")

ensure_dirs(GDP_CONFIG)

## ==============================================================
## Load parsed BEA government tables
## ==============================================================

load_parsed <- function(label) {
  path <- file.path(GDP_CONFIG$INTERIM_BEA_PARSED, sprintf("%s.csv", label))
  if (!file.exists(path)) {
    stop("Parsed BEA table not found: ", path,
         "\nRun 41_fetch_bea_fixed_assets.R first.")
  }
  readr::read_csv(path, show_col_types = FALSE)
}

tbl_net_cc    <- load_parsed("govt_net_cc")     # Table 6.1
tbl_net_chain <- load_parsed("govt_net_chain")   # Table 6.2
tbl_dep_cc    <- load_parsed("govt_dep_cc")      # Table 6.3
tbl_inv       <- load_parsed("govt_inv")          # Table 6.4

message(sprintf("Loaded 4 government BEA tables. Year range: %d-%d",
                min(tbl_net_cc$year), max(tbl_net_cc$year)))

## ==============================================================
## Define government asset extraction map
##
## Government structure (Table 6.1):
##   Total government
##     National defense
##       Structures
##       Equipment
##       Intellectual property products
##     Nondefense
##       Structures
##       Equipment
##       Intellectual property products
## ==============================================================

lm <- GDP_CONFIG$LINE_MAP_GOVT

govt_assets <- list(
  defense_total = list(line = lm$national_defense, label = "Defense_Total"),
  defense_str   = list(line = lm$defense_structures, label = "Defense_NRC"),
  defense_eq    = list(line = lm$defense_equipment, label = "Defense_ME"),
  defense_ip    = list(line = lm$defense_ip, label = "Defense_IP"),
  nondefense_total = list(line = lm$nondefense, label = "Nondefense_Total"),
  nondefense_str   = list(line = lm$nondefense_structures, label = "Nondefense_NRC"),
  nondefense_eq    = list(line = lm$nondefense_equipment, label = "Nondefense_ME"),
  nondefense_ip    = list(line = lm$nondefense_ip, label = "Nondefense_IP")
)

## ==============================================================
## Extract and build each government asset
## ==============================================================

extract_line <- function(tbl, line, col_name) {
  tbl |>
    filter(line_number == line) |>
    select(year, !!col_name := value) |>
    arrange(year)
}

base_year <- GDP_CONFIG$GPIM$base_year
results <- list()

for (ga_name in names(govt_assets)) {
  spec <- govt_assets[[ga_name]]
  line <- spec$line
  label <- spec$label

  message(sprintf("\nProcessing %s (line %d)...", label, line))

  # Extract from each table
  K_net_cc    <- extract_line(tbl_net_cc, line, "K_net_cc")
  K_net_chain <- extract_line(tbl_net_chain, line, "K_net_chain")
  D_cc        <- extract_line(tbl_dep_cc, line, "D_cc")
  IG_cc       <- extract_line(tbl_inv, line, "IG_cc")

  # Merge
  df <- K_net_cc |>
    left_join(K_net_chain, by = "year") |>
    left_join(D_cc, by = "year") |>
    left_join(IG_cc, by = "year") |>
    mutate(asset = label)

  if (nrow(df) == 0 || all(is.na(df$K_net_cc))) {
    warning(sprintf("No data for %s (line %d). Skipping.", label, line))
    next
  }

  # Own-price implicit deflator
  df <- df |>
    mutate(
      p_K_raw = ifelse(K_net_chain > 0, K_net_cc / K_net_chain, NA_real_)
    )

  if (base_year %in% df$year && !is.na(df$p_K_raw[df$year == base_year])) {
    df <- df |>
      mutate(p_K = rebase_index(p_K_raw, year, base_year, scale = 1.0))
  } else {
    # Fallback: rebase to first non-NA value
    first_valid <- which(!is.na(df$p_K_raw))[1]
    if (!is.na(first_valid)) {
      df <- df |> mutate(p_K = p_K_raw / p_K_raw[first_valid])
    } else {
      df <- df |> mutate(p_K = NA_real_)
    }
  }

  # GPIM deflation
  if (any(!is.na(df$p_K) & df$p_K > 0)) {
    gpim <- gpim_deflate_sfc(df$K_net_cc, df$IG_cc, df$D_cc, df$p_K)
    df <- df |>
      mutate(
        K_net_real = gpim$K_real,
        IG_real    = gpim$IG_real,
        D_real     = gpim$D_real
      )
  } else {
    df <- df |>
      mutate(K_net_real = NA_real_, IG_real = NA_real_, D_real = NA_real_)
  }

  # Gross stock (approximate)
  df <- df |>
    mutate(K_gross_cc = K_net_cc + D_cc)

  results[[ga_name]] <- df
  message(sprintf("  %s: %d obs, K_net_cc range [%.1f, %.1f]",
                  label, nrow(df),
                  min(df$K_net_cc, na.rm = TRUE),
                  max(df$K_net_cc, na.rm = TRUE)))
}

## ==============================================================
## Combine and write output
## ==============================================================

govt_combined <- bind_rows(results) |>
  select(year, asset, K_net_cc, K_gross_cc, K_net_chain,
         K_net_real, IG_cc, IG_real, D_cc, D_real, p_K) |>
  arrange(asset, year)

out_path <- file.path(GDP_CONFIG$PROCESSED, "kstock_government.csv")
safe_write_csv(govt_combined, out_path)

# Also save to interim
safe_write_csv(govt_combined,
  file.path(GDP_CONFIG$INTERIM_KSTOCK, "kstock_government.csv"))

message(sprintf("\n=== Government capital stock complete ==="))
message(sprintf("Output: %s", out_path))
message(sprintf("Assets: %s", paste(unique(govt_combined$asset), collapse = ", ")))
message(sprintf("Years: %d-%d", min(govt_combined$year), max(govt_combined$year)))
