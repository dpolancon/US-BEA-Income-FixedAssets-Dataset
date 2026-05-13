############################################################
# 66_export_ch2_us_composition_panel.R
#
# Build the Tier-B ME-NRC component proxy panel for Chapter 2.
#
# This script does not estimate any econometric model. It exports a
# narrow composition panel for the NFCorp-centered Chapter 2
# transformation relation and validates the inherited ME + NRC
# identity against kstock_TOTAL_PRODUCTIVE.csv.
############################################################

source("codes/99_utils.R")

TOL <- 1e-6

input_paths <- list(
  ME = "data/interim/kstock_components/kstock_ME.csv",
  NRC = "data/interim/kstock_components/kstock_NRC.csv",
  IP = "data/interim/kstock_components/kstock_IP.csv",
  TOTAL_PRODUCTIVE = "data/interim/kstock_components/kstock_TOTAL_PRODUCTIVE.csv"
)

output_path <- "data/final/us_nfcorp_composition_proxy_for_ch2.csv"
validation_check_path <- "data/interim/validation/ch2_me_nrc_component_identity_check.csv"
validation_summary_path <- "data/interim/validation/ch2_me_nrc_component_identity_summary.csv"
readme_path <- "artifacts/ch2_exports/US_COMPOSITION_PROXY_FOR_CH2_README.md"

required_component_cols <- c(
  "year",
  "K_gross_real",
  "K_gross_cc",
  "IG_real",
  "IG_cc",
  "p_K"
)

read_component <- function(asset_code, path) {
  if (!file.exists(path)) {
    stop(sprintf("Missing required input for %s: %s", asset_code, path), call. = FALSE)
  }

  df <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)

  missing_cols <- setdiff(required_component_cols, names(df))
  if (length(missing_cols) > 0L) {
    stop(
      sprintf(
        "%s is missing required columns: %s",
        path,
        paste(missing_cols, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  if (anyDuplicated(df$year) > 0L) {
    stop(sprintf("%s has duplicate year values.", path), call. = FALSE)
  }

  df <- df[order(df$year), required_component_cols]
  names(df)[names(df) != "year"] <- paste0(names(df)[names(df) != "year"], "_", asset_code)
  df
}

safe_ratio <- function(num, den) {
  out <- rep(NA_real_, length(num))
  ok <- !is.na(num) & !is.na(den) & abs(den) > .Machine$double.eps
  out[ok] <- num[ok] / den[ok]
  out
}

format_num <- function(x) {
  ifelse(
    is.na(x),
    "NA",
    format(signif(x, 8L), scientific = TRUE, trim = TRUE)
  )
}

build_identity_check <- function(me, nrc, total_productive) {
  check <- merge(me, nrc, by = "year", all = TRUE)
  check <- merge(check, total_productive, by = "year", all = TRUE)
  check <- check[order(check$year), ]

  variables <- c("K_gross_real", "K_gross_cc", "IG_real", "IG_cc")

  out <- data.frame(year = check$year)

  for (v in variables) {
    me_col <- paste0(v, "_ME")
    nrc_col <- paste0(v, "_NRC")
    total_col <- paste0(v, "_TOTAL_PRODUCTIVE")

    component_sum <- check[[me_col]] + check[[nrc_col]]
    gap <- check[[total_col]] - component_sum

    out[[paste0("ME_", v)]] <- check[[me_col]]
    out[[paste0("NRC_", v)]] <- check[[nrc_col]]
    out[[paste0("ME_NRC_component_", v)]] <- component_sum
    out[[paste0("inherited_total_productive_", v)]] <- check[[total_col]]
    out[[paste0("gap_", v)]] <- gap
    out[[paste0("abs_gap_", v)]] <- abs(gap)
  }

  out
}

summarize_identity_check <- function(identity_check, tolerance) {
  variables <- c("K_gross_real", "K_gross_cc", "IG_real", "IG_cc")

  do.call(
    rbind,
    lapply(variables, function(v) {
      gap_col <- paste0("gap_", v)
      abs_gap_col <- paste0("abs_gap_", v)
      abs_gap <- identity_check[[abs_gap_col]]

      if (all(is.na(abs_gap))) {
        max_abs_gap <- NA_real_
        max_gap <- NA_real_
        max_gap_year <- NA_integer_
      } else {
        idx <- which.max(abs_gap)
        max_abs_gap <- abs_gap[idx]
        max_gap <- identity_check[[gap_col]][idx]
        max_gap_year <- identity_check$year[idx]
      }

      data.frame(
        variable = v,
        identity = sprintf(
          "inherited TOTAL_PRODUCTIVE %s minus ME + NRC %s",
          v,
          v
        ),
        max_gap_year = max_gap_year,
        max_gap = max_gap,
        max_abs_gap = max_abs_gap,
        tolerance = tolerance,
        pass = !is.na(max_abs_gap) && max_abs_gap <= tolerance,
        stringsAsFactors = FALSE
      )
    })
  )
}

write_readme <- function(path, panel, identity_summary, tolerance, identity_pass) {
  dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)

  max_gap_text <- paste(
    sprintf(
      "- `%s`: max absolute gap = %s in %s",
      identity_summary$variable,
      format_num(identity_summary$max_abs_gap),
      identity_summary$max_gap_year
    ),
    collapse = "\n"
  )

  warning_block <- if (identity_pass) {
    "Identity status: PASS. The inherited TOTAL_PRODUCTIVE file equals ME + NRC within the numerical tolerance used here."
  } else {
    paste(
      "WARNING: Identity status: FAIL.",
      "At least one inherited TOTAL_PRODUCTIVE = ME + NRC max absolute gap exceeds the numerical tolerance.",
      "Do not treat the inherited aggregate as validated without inspecting the validation CSVs."
    )
  }

  lines <- c(
    "# US Composition Proxy for Chapter 2",
    "",
    sprintf("Generated by `codes/66_export_ch2_us_composition_panel.R` on %s.", Sys.Date()),
    "",
    "## Purpose",
    "",
    "This output is a Tier-B ME-NRC component proxy for the NFCorp-centered Chapter 2 transformation relation.",
    "",
    "It is not a direct NFCorp-by-asset-type capital split. The target sector is `NFCorp`, but the available composition basis in this BEA repo is a machinery/equipment and nonresidential construction component proxy.",
    "",
    "## Analytical Register",
    "",
    "- `sector_target`: `NFCorp`",
    "- `composition_basis`: `ME_NRC_component_proxy`",
    "- `composition_tier`: `Tier B`",
    "- `direct_sector_asset_split`: `FALSE`",
    "- The default stock share is `s_ME_over_ME_NRC_gross_real`, built from gross real GPIM stocks.",
    "- The default flow share is `phi_ME_over_ME_NRC_real`, built from real investment.",
    "- Gross real GPIM stock is a stock-flow-consistency device: a constant-price measure of purchasing power embodied in heterogeneous capital goods still in operation, not literal physical capital.",
    "- Current-cost shares are diagnostics: `s_ME_over_ME_NRC_gross_cc` and `phi_ME_over_ME_NRC_cc`.",
    "- IP is excluded from the default ME-NRC denominator and retained only as auxiliary/robustness information.",
    "- The label `TOTAL_PRODUCTIVE` is avoided in Chapter 2 output variables.",
    "",
    "## Output Files",
    "",
    "- `data/final/us_nfcorp_composition_proxy_for_ch2.csv`",
    "- `data/interim/validation/ch2_me_nrc_component_identity_check.csv`",
    "- `data/interim/validation/ch2_me_nrc_component_identity_summary.csv`",
    "",
    "## Panel Coverage",
    "",
    sprintf("- Rows: %d", nrow(panel)),
    sprintf("- Years: %s-%s", min(panel$year, na.rm = TRUE), max(panel$year, na.rm = TRUE)),
    "",
    "## ME + NRC Identity Check",
    "",
    warning_block,
    "",
    sprintf("Tolerance: `%s`.", format_num(tolerance)),
    "",
    max_gap_text,
    ""
  )

  writeLines(lines, con = path, useBytes = TRUE)
}

message("=== Chapter 2 US ME-NRC component proxy export ===")

components <- Map(read_component, names(input_paths), input_paths)

panel <- merge(components$ME, components$NRC, by = "year", all = FALSE)
panel <- merge(panel, components$IP, by = "year", all = FALSE)
panel <- panel[order(panel$year), ]

if (nrow(panel) == 0L) {
  stop("ME, NRC, and IP component files have no overlapping years.", call. = FALSE)
}

export <- data.frame(
  year = panel$year,

  K_ME_gross_real = panel$K_gross_real_ME,
  K_NRC_gross_real = panel$K_gross_real_NRC,
  K_ME_NRC_component_gross_real = panel$K_gross_real_ME + panel$K_gross_real_NRC,
  s_ME_over_ME_NRC_gross_real = safe_ratio(
    panel$K_gross_real_ME,
    panel$K_gross_real_ME + panel$K_gross_real_NRC
  ),

  IG_ME_real = panel$IG_real_ME,
  IG_NRC_real = panel$IG_real_NRC,
  IG_ME_NRC_component_real = panel$IG_real_ME + panel$IG_real_NRC,
  phi_ME_over_ME_NRC_real = safe_ratio(
    panel$IG_real_ME,
    panel$IG_real_ME + panel$IG_real_NRC
  ),

  K_ME_gross_cc = panel$K_gross_cc_ME,
  K_NRC_gross_cc = panel$K_gross_cc_NRC,
  K_ME_NRC_component_gross_cc = panel$K_gross_cc_ME + panel$K_gross_cc_NRC,
  s_ME_over_ME_NRC_gross_cc = safe_ratio(
    panel$K_gross_cc_ME,
    panel$K_gross_cc_ME + panel$K_gross_cc_NRC
  ),

  IG_ME_cc = panel$IG_cc_ME,
  IG_NRC_cc = panel$IG_cc_NRC,
  IG_ME_NRC_component_cc = panel$IG_cc_ME + panel$IG_cc_NRC,
  phi_ME_over_ME_NRC_cc = safe_ratio(
    panel$IG_cc_ME,
    panel$IG_cc_ME + panel$IG_cc_NRC
  ),

  pK_ME = panel$p_K_ME,
  pK_NRC = panel$p_K_NRC,
  pK_relative_ME_NRC = safe_ratio(panel$p_K_ME, panel$p_K_NRC),

  K_IP_gross_real = panel$K_gross_real_IP,
  K_IP_gross_cc = panel$K_gross_cc_IP,

  sector_target = "NFCorp",
  composition_basis = "ME_NRC_component_proxy",
  composition_tier = "Tier B",
  direct_sector_asset_split = FALSE,
  capacity_register = "gross_real_GPIM_stock",
  profitability_register = "real_investment_flow_default_current_cost_diagnostics",
  notes = paste(
    "Tier-B ME-NRC component proxy; not a direct NFCorp-by-asset-type split.",
    "Default denominator excludes IP; IP columns are auxiliary.",
    "Gross real GPIM stock is a constant-price purchasing-power stock-flow-consistency measure, not literal physical capital."
  ),
  stringsAsFactors = FALSE
)

identity_check <- build_identity_check(
  components$ME,
  components$NRC,
  components$TOTAL_PRODUCTIVE
)
identity_summary <- summarize_identity_check(identity_check, TOL)
identity_pass <- all(identity_summary$pass)

safe_write_csv(export, output_path)
safe_write_csv(identity_check, validation_check_path)
safe_write_csv(identity_summary, validation_summary_path)
write_readme(readme_path, export, identity_summary, TOL, identity_pass)

message(sprintf("Written: %s (%d rows x %d cols)", output_path, nrow(export), ncol(export)))
message(sprintf("Written: %s", validation_check_path))
message(sprintf("Written: %s", validation_summary_path))
message(sprintf("Written: %s", readme_path))

if (!identity_pass) {
  warning(
    paste(
      "\n*** WARNING: ME + NRC identity check exceeds tolerance. ***",
      sprintf("Tolerance: %s", format_num(TOL)),
      sprintf("Inspect: %s", validation_summary_path),
      sep = "\n"
    ),
    call. = FALSE
  )
} else {
  message(sprintf("ME + NRC identity check passed at tolerance %s.", format_num(TOL)))
}

message(sprintf("Panel coverage: %d rows, years %s-%s", nrow(export), min(export$year), max(export$year)))
message("=== Export complete ===")
