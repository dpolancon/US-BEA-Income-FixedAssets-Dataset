############################################################
# 60_agents_prod_cap.R — Agent Functions for Dataset 2
#
# Multi-agent productive capital stock pipeline.
# Three agent classes:
#   A. Fetch agents  (7) — BEA API + FRED data retrieval
#   B. GPIM agents   (4) — per-account capital stock construction
#   C. Aggregation   (3) — income accounts, productive aggregate, master CSV
#
# Four accounts (confirmed by live API — FAAt601 has legal-form
# aggregates ONLY, no E/S/IPP sub-lines under any legal form):
#   1. NF corporate (aggregate)       ← FAAt601 L4 "Nonfinancial"
#   2. Gov transport                  ← FAAt701/702/705
#   3. NF IPP (separate tracking)     ← FAAt401 "Corporate; IPP"
#   4. Financial corporate (separate) ← FAAt601 L3 "Financial"
#
# The GPIM for NF corporate runs on the aggregate stock using
# investment-weighted average retirement/depreciation rates across
# all asset types (same approach as 53_build_gpim_kstock.R).
#
# Authority:
#   - KSTOCK_Architecture_v1.md (perimeter + derivation chain)
#   - BEA_LineMap_v1.md (API table/line mappings)
#   - Weibull_Retirement_Distributions.md (L, alpha params)
#
# Dependencies:
#   97_kstock_helpers.R (parse_bea_api_response, gpim_*)
#   59_gpim_helpers.R   (weibull_*, gpim_recursion, gpim_account)
#   99_utils.R          (now_stamp, bea_get)
#   bea.R (or beaR), fredr, dplyr
############################################################


# ==================================================================
# SA. FETCH AGENTS
# ==================================================================

## ------------------------------------------------------------------
## Helper: Extract a sub-line from a parsed BEA table by matching
## line_desc patterns. Returns tibble(year, value).
## ------------------------------------------------------------------

#' Extract a single sub-line from parsed BEA long-format data
#' by matching line description patterns (flat search).
#'
#' @param parsed   Long-format BEA tibble (year, line_number, line_desc, value)
#' @param patterns Character vector of regex patterns (ALL must match)
#' @param label    Label for error messages
#' @return tibble(year, value)
extract_subline <- function(parsed, patterns, label) {
  unique_lines <- parsed |>
    dplyr::distinct(line_number, line_desc) |>
    dplyr::arrange(line_number)

  ## Filter for lines matching ALL patterns
  matches <- unique_lines
  for (pat in patterns) {
    matches <- matches |>
      dplyr::filter(grepl(pat, line_desc, ignore.case = TRUE))
  }

  if (nrow(matches) == 0) {
    stop(sprintf(
      "FETCH ERROR [%s]: No line matches all patterns: %s\nAvailable:\n%s",
      label,
      paste(patterns, collapse = " AND "),
      paste(sprintf("  L%d: %s", unique_lines$line_number,
                    unique_lines$line_desc), collapse = "\n")
    ))
  }

  if (nrow(matches) > 1) {
    message(sprintf("  [%s] Multiple matches — using first: L%d '%s'",
                    label, matches$line_number[1], matches$line_desc[1]))
  }

  target_line <- matches$line_number[1]
  message(sprintf("  [%s] Extracted: Line %d = '%s'",
                  label, target_line, matches$line_desc[1]))

  parsed |>
    dplyr::filter(line_number == target_line) |>
    dplyr::select(year, value) |>
    dplyr::arrange(year)
}


#' Extract and sum multiple sub-lines (for government transport accounts).
#'
#' @param parsed   Long-format BEA tibble
#' @param pattern_list List of character vectors, each a set of AND patterns
#' @param label    Label for messages
#' @return tibble(year, value) with summed values
extract_sum_sublines <- function(parsed, pattern_list, label) {
  components <- list()
  for (i in seq_along(pattern_list)) {
    comp_label <- sprintf("%s_comp%d", label, i)
    components[[i]] <- tryCatch(
      extract_subline(parsed, pattern_list[[i]], comp_label),
      error = function(e) {
        message(sprintf("  [%s] Component %d not found: %s",
                        label, i, e$message))
        NULL
      }
    )
  }

  ## Remove NULLs
  components <- Filter(Negate(is.null), components)
  if (length(components) == 0) {
    stop(sprintf("FETCH ERROR [%s]: No transport sub-lines found", label))
  }

  ## Sum across components by year
  result <- components[[1]]
  if (length(components) > 1) {
    for (i in 2:length(components)) {
      result <- result |>
        dplyr::full_join(components[[i]], by = "year",
                         suffix = c("", paste0("_", i))) |>
        dplyr::mutate(
          value = dplyr::coalesce(value, 0) +
            dplyr::coalesce(.data[[paste0("value_", i)]], 0)
        ) |>
        dplyr::select(year, value)
    }
  }
  result |> dplyr::arrange(year)
}


## ------------------------------------------------------------------
## Helper: Fetch a BEA Fixed Assets table via API
## (Reuses pattern from 50_fetch_fixed_assets.R)
## ------------------------------------------------------------------
fetch_fa_table <- function(table_name, api_key) {
  if (!requireNamespace("bea.R", quietly = TRUE)) {
    if (!requireNamespace("beaR", quietly = TRUE)) {
      stop("Neither bea.R nor beaR available.")
    }
  }

  message(sprintf("  Fetching %s from BEA FixedAssets API...", table_name))

  specs <- list(
    UserID      = api_key,
    Method      = "GetData",
    datasetname = "FixedAssets",
    TableName   = table_name,
    Frequency   = "A",
    Year        = "ALL"
  )

  resp <- tryCatch({
    if (requireNamespace("bea.R", quietly = TRUE)) {
      bea.R::beaGet(specs, asWide = FALSE)
    } else {
      beaR::beaGet(specs, asWide = FALSE)
    }
  }, error = function(e) {
    stop(sprintf("BEA API FAILED for %s: %s", table_name, e$message))
  })

  if (is.null(resp) || nrow(resp) == 0) {
    stop(sprintf("Empty BEA response for %s", table_name))
  }

  parse_bea_api_response(resp)
}


## ------------------------------------------------------------------
## Helper: Fetch a BEA NIPA table via API
## ------------------------------------------------------------------
fetch_nipa_table <- function(table_name, api_key) {
  if (!requireNamespace("bea.R", quietly = TRUE)) {
    if (!requireNamespace("beaR", quietly = TRUE)) {
      stop("Neither bea.R nor beaR available.")
    }
  }

  message(sprintf("  Fetching %s from BEA NIPA API...", table_name))

  specs <- list(
    UserID      = api_key,
    Method      = "GetData",
    datasetname = "NIPA",
    TableName   = table_name,
    Frequency   = "A",
    Year        = "X"
  )

  resp <- tryCatch({
    if (requireNamespace("bea.R", quietly = TRUE)) {
      bea.R::beaGet(specs, asWide = FALSE)
    } else {
      beaR::beaGet(specs, asWide = FALSE)
    }
  }, error = function(e) {
    stop(sprintf("BEA NIPA API FAILED for %s: %s", table_name, e$message))
  })

  if (is.null(resp) || nrow(resp) == 0) {
    stop(sprintf("Empty NIPA response for %s", table_name))
  }

  parse_bea_api_response(resp)
}


## ------------------------------------------------------------------
## Government transport line description patterns
## ------------------------------------------------------------------
GOV_TRANSPORT_PATTERNS <- list(
  highways = c("Highways and streets"),
  air      = c("transportation", "Air"),
  land     = c("transportation", "Other")
)


# ------------------------------------------------------------------
# Fetch Agent 1: NF Corporate (Aggregate) — Account A
#
# FAAt601 has NO E/S/IPP sub-lines under legal-form entries.
# L4 = "Nonfinancial corporate businesses" is the aggregate.
# This replaces the former fetch_NF_structures + fetch_NF_equipment.
# ------------------------------------------------------------------

#' Fetch NF corporate aggregate from BEA Section 6 tables.
#'
#' Extracts the "Nonfinancial" line from FAAt601 (current-cost net
#' stock), FAAt602 (chain-type QI), and FAAt607 (investment).
#' Uses flat pattern match — no hierarchy traversal needed.
#'
#' @param cfg GDP_CONFIG list (must contain BEA_API_KEY)
#' @return Named list: KNC, KNR_idx, IG (each tibble(year, value))
fetch_NF_corporate <- function(cfg) {
  message(sprintf("\n[%s] === Fetch: NF corporate (aggregate) ===", now_stamp()))
  api_key <- cfg$BEA_API_KEY

  tbl_601 <- fetch_fa_table("FAAt601", api_key)
  tbl_602 <- fetch_fa_table("FAAt602", api_key)
  tbl_607 <- fetch_fa_table("FAAt607", api_key)

  ## "Nonfinancial" matches "Nonfinancial corporate businesses"
  ## and does NOT match "Financial corporate businesses"
  pat <- c("Nonfinancial")

  list(
    KNC     = extract_subline(tbl_601, pat, "KNC_NF_corp"),
    KNR_idx = extract_subline(tbl_602, pat, "KNR_NF_corp"),
    IG      = extract_subline(tbl_607, pat, "IG_NF_corp"),
    account = "NF_corp"
  )
}


# ------------------------------------------------------------------
# Fetch Agent 2: Financial Corporate (Aggregate) — Account D
# ------------------------------------------------------------------

#' Fetch Financial corporate aggregate from BEA Section 6 tables.
#'
#' @param cfg GDP_CONFIG list
#' @return Named list: KNC, KNR_idx, IG
fetch_financial_corporate <- function(cfg) {
  message(sprintf("\n[%s] === Fetch: Financial corporate ===", now_stamp()))
  api_key <- cfg$BEA_API_KEY

  tbl_601 <- fetch_fa_table("FAAt601", api_key)
  tbl_602 <- fetch_fa_table("FAAt602", api_key)
  tbl_607 <- fetch_fa_table("FAAt607", api_key)

  ## Match "Financial" but exclude "Nonfinancial" — use negative lookbehind
  ## or two-step: first match "Financial", then exclude "Nonfinancial"
  .extract_fin <- function(parsed, label) {
    unique_lines <- parsed |>
      dplyr::distinct(line_number, line_desc) |>
      dplyr::arrange(line_number)

    matches <- unique_lines |>
      dplyr::filter(
        grepl("Financial", line_desc, ignore.case = TRUE),
        !grepl("Nonfinancial", line_desc, ignore.case = TRUE)
      )

    if (nrow(matches) == 0) {
      stop(sprintf(
        "FETCH ERROR [%s]: No 'Financial' (non-NF) line found.\nAvailable:\n%s",
        label,
        paste(sprintf("  L%d: %s", unique_lines$line_number,
                      unique_lines$line_desc), collapse = "\n")
      ))
    }

    if (nrow(matches) > 1) {
      message(sprintf("  [%s] Multiple matches — using first: L%d '%s'",
                      label, matches$line_number[1], matches$line_desc[1]))
    }

    target_line <- matches$line_number[1]
    message(sprintf("  [%s] Extracted: Line %d = '%s'",
                    label, target_line, matches$line_desc[1]))

    parsed |>
      dplyr::filter(line_number == target_line) |>
      dplyr::select(year, value) |>
      dplyr::arrange(year)
  }

  list(
    KNC     = .extract_fin(tbl_601, "KNC_fin_corp"),
    KNR_idx = .extract_fin(tbl_602, "KNR_fin_corp"),
    IG      = .extract_fin(tbl_607, "IG_fin_corp"),
    account = "fin_corp"
  )
}


# ------------------------------------------------------------------
# Fetch Agent 3: Government Transportation (Account B)
# ------------------------------------------------------------------

#' Fetch government transportation infrastructure from BEA Section 7.
#'
#' Sums highways, air transportation, and land transportation sub-lines.
#'
#' @param cfg GDP_CONFIG list
#' @return Named list: KNC, KNR_idx, IG (each summed across sub-lines)
fetch_gov_transport <- function(cfg) {
  message(sprintf("\n[%s] === Fetch: Gov transport ===", now_stamp()))
  api_key <- cfg$BEA_API_KEY

  tbl_701 <- fetch_fa_table("FAAt701", api_key)
  tbl_702 <- fetch_fa_table("FAAt702", api_key)
  tbl_705 <- fetch_fa_table("FAAt705", api_key)

  ## FAAt701 structure (confirmed from live API):
  ##   L12 = "Transportation" (airports, transit, rail — excl. highways)
  ##   L14 = "Highways and streets"
  ## Both are top-level structure types (siblings), not nested.
  ## Gov transport = L12 + L14.

  KNC <- extract_sum_sublines(
    tbl_701,
    list(c("^Transportation$"), c("Highways and streets")),
    "KNC_gov_trans"
  )

  KNR_idx <- extract_sum_sublines(
    tbl_702,
    list(c("^Transportation$"), c("Highways and streets")),
    "KNR_gov_trans"
  )

  IG <- extract_sum_sublines(
    tbl_705,
    list(c("^Transportation$"), c("Highways and streets")),
    "IG_gov_trans"
  )

  list(
    KNC     = KNC,
    KNR_idx = KNR_idx,
    IG      = IG,
    account = "gov_trans"
  )
}


# ------------------------------------------------------------------
# Fetch Agent 4: NF Corporate IPP (Account C — separate tracking)
#
# FAAt601 has NO asset-type sub-lines. IPP for the corporate sector
# comes from FAAt401 (Table 4.1: Nonresidential by Industry Group
# and Legal Form), which provides "Corporate × IPP".  This is all-
# corporate (Financial + Nonfinancial combined), not NF-specific.
# Financial corporate IPP is small, so this is a close proxy.
# ------------------------------------------------------------------

#' Fetch corporate IPP from BEA Table 4.1/4.2/4.7.
#'
#' @param cfg GDP_CONFIG list
#' @return Named list: KNC, KNR_idx, IG
fetch_NF_IPP <- function(cfg) {
  message(sprintf("\n[%s] === Fetch: Corporate IPP (via FAAt401/402/407) ===",
                  now_stamp()))
  api_key <- cfg$BEA_API_KEY

  ## Section 4 tables — Nonresidential by Industry Group and Legal Form
  tbl_401 <- fetch_fa_table("FAAt401", api_key)
  tbl_402 <- fetch_fa_table("FAAt402", api_key)
  tbl_407 <- fetch_fa_table("FAAt407", api_key)

  ## Match "Intellectual property" under "Corporate" block.
  ## Table 4.1 has Corporate × E/S/IPP.  Pattern: both words must
  ## appear in the same LineDescription (e.g., "Corporate
  ## intellectual property products").  If LineDescriptions are
  ## hierarchical (IPP is a child of Corporate), fall back to
  ## flat search for just "Intellectual property".
  pat_corp_ipp <- c("Intellectual property")

  list(
    KNC     = extract_subline(tbl_401, pat_corp_ipp, "KNC_corp_IPP"),
    KNR_idx = extract_subline(tbl_402, pat_corp_ipp, "KNR_corp_IPP"),
    IG      = extract_subline(tbl_407, pat_corp_ipp, "IG_corp_IPP"),
    account = "NF_IPP"
  )
}


# ------------------------------------------------------------------
# Fetch Agent 5: NIPA Income Accounts (T1.14)
# ------------------------------------------------------------------

#' Fetch NIPA Table 1.14 income accounts.
#'
#' @param cfg GDP_CONFIG list
#' @return Parsed long-format tibble (all T1.14 lines)
fetch_income_accounts <- function(cfg) {
  message(sprintf("\n[%s] === Fetch: NIPA T1.14 ===", now_stamp()))
  fetch_nipa_table("T11400", cfg$BEA_API_KEY)
}


# ------------------------------------------------------------------
# Fetch Agent 6: GDP Deflator (Py) from FRED
# ------------------------------------------------------------------

#' Fetch GDP implicit price deflator from FRED.
#'
#' @param cfg GDP_CONFIG list
#' @return tibble(year, Py_fred) with Py_fred in 2017=100
fetch_Py_deflator <- function(cfg) {
  message(sprintf("\n[%s] === Fetch: FRED Py ===", now_stamp()))

  if (!requireNamespace("fredr", quietly = TRUE)) {
    stop("fredr package required. Install with: install.packages('fredr')")
  }

  fredr::fredr_set_key(cfg$FRED_API_KEY)

  obs <- fredr::fredr(
    series_id         = "A191RD3A086NBEA",
    observation_start = as.Date("1925-01-01"),
    observation_end   = as.Date("2024-12-31"),
    frequency         = "a"
  )

  if (is.null(obs) || nrow(obs) == 0) {
    stop("FRED GDP deflator fetch FAILED")
  }

  result <- obs |>
    dplyr::transmute(
      year = as.integer(format(date, "%Y")),
      Py_fred = value
    )

  message(sprintf("  Py_fred: %d obs, years %d-%d, Py_2017=%.3f",
                  nrow(result), min(result$year), max(result$year),
                  result$Py_fred[result$year == 2017]))
  result
}


# ------------------------------------------------------------------
# Fetch Agent 7: Investment Flows 1901 (Warmup Data)
# ------------------------------------------------------------------

#' Fetch investment flows from 1901 for GPIM warmup.
#'
#' @param cfg GDP_CONFIG list
#' @return Named list: nf_corp_1901, fin_corp_1901, govt_1901, ipp_1901
fetch_investment_flows_1901 <- function(cfg) {
  message(sprintf("\n[%s] === Fetch: 1901 investment warmup ===", now_stamp()))
  api_key <- cfg$BEA_API_KEY

  ## Private FA investment (Table 6.7) — legal-form aggregates
  tbl_607 <- fetch_fa_table("FAAt607", api_key)

  ## Government investment (Table 7.5)
  tbl_705 <- fetch_fa_table("FAAt705", api_key)

  ## Section 4 investment (Table 4.7) — for IPP
  tbl_407 <- fetch_fa_table("FAAt407", api_key)

  ## NF corporate aggregate
  nf_corp_1901 <- extract_subline(tbl_607,
    c("Nonfinancial"), "IG_NF_corp_1901")

  ## Financial corporate aggregate
  .extract_fin_inv <- function(parsed, label) {
    unique_lines <- parsed |>
      dplyr::distinct(line_number, line_desc) |>
      dplyr::arrange(line_number)
    matches <- unique_lines |>
      dplyr::filter(
        grepl("Financial", line_desc, ignore.case = TRUE),
        !grepl("Nonfinancial", line_desc, ignore.case = TRUE)
      )
    if (nrow(matches) == 0) stop(sprintf("No Financial line in %s", label))
    target_line <- matches$line_number[1]
    message(sprintf("  [%s] Extracted: Line %d = '%s'",
                    label, target_line, matches$line_desc[1]))
    parsed |>
      dplyr::filter(line_number == target_line) |>
      dplyr::select(year, value) |>
      dplyr::arrange(year)
  }
  fin_corp_1901 <- .extract_fin_inv(tbl_607, "IG_fin_corp_1901")

  ## Corporate IPP (from Table 4.7)
  ipp_1901 <- extract_subline(tbl_407,
    c("Intellectual property"), "IG_IPP_1901")

  ## Government transport — Transportation (L12) + Highways and streets (L14)
  govt_1901 <- extract_sum_sublines(
    tbl_705,
    list(c("^Transportation$"), c("Highways and streets")),
    "IG_gov_trans_1901"
  )

  list(
    nf_corp_1901  = nf_corp_1901,
    fin_corp_1901 = fin_corp_1901,
    govt_1901     = govt_1901 |> dplyr::arrange(year),
    ipp_1901      = ipp_1901
  )
}


# ==================================================================
# SB. GPIM AGENTS
# ==================================================================

# ------------------------------------------------------------------
# GPIM Agent 1: NF Corporate (Aggregate) — Account A
# ------------------------------------------------------------------

#' Build GPIM capital stock for NF corporate (aggregate).
#'
#' Replaces the former separate gpim_NF_structures + gpim_NF_equipment.
#' Runs on the aggregate NF corporate stock from FAAt601.
#'
#' @param raw      List from fetch_NF_corporate()
#' @param warmup   List from fetch_investment_flows_1901()
#' @param cfg      GDP_CONFIG + WEIBULL_PARAMS
#' @return tibble with full GPIM output columns
gpim_NF_corporate <- function(raw, warmup, cfg) {
  params <- cfg$WEIBULL_PARAMS$nf_corporate
  use_wb <- cfg$USE_WEIBULL_RETIREMENT %||% TRUE
  use_wu <- cfg$USE_1901_WARMUP %||% TRUE

  ## Align KNC, KNR_idx, IG by year
  df <- raw$KNC |>
    dplyr::rename(KNC = value) |>
    dplyr::inner_join(raw$KNR_idx |> dplyr::rename(KNR_idx = value), by = "year") |>
    dplyr::inner_join(raw$IG |> dplyr::rename(IG = value), by = "year") |>
    dplyr::arrange(year)

  ## Prepare warmup
  wu_IG_R <- NULL; wu_years <- NULL
  if (use_wu && !is.null(warmup$nf_corp_1901)) {
    wu_df <- warmup$nf_corp_1901 |>
      dplyr::filter(year < min(df$year)) |>
      dplyr::arrange(year)
    if (nrow(wu_df) > 0) {
      wu_IG_R <- wu_df$value
      wu_years <- wu_df$year
    }
  }

  gpim_account(
    KNC             = df$KNC,
    KNR_idx         = df$KNR_idx,
    IG              = df$IG,
    year_vec        = df$year,
    L               = params$L,
    alpha           = params$alpha,
    use_weibull     = use_wb,
    account_label   = "NF_corp",
    warmup_IG_R     = wu_IG_R,
    warmup_years    = wu_years,
    use_fixed_point = TRUE,
    base_year       = cfg$GPIM$base_year %||% 2017L
  )
}


# ------------------------------------------------------------------
# GPIM Agent 2: Government Transportation (Account B)
# ------------------------------------------------------------------

#' Build GPIM capital stock for government transportation.
gpim_gov_transport <- function(raw, warmup, cfg) {
  params <- cfg$WEIBULL_PARAMS$gov_transport
  use_wb <- cfg$USE_WEIBULL_RETIREMENT %||% TRUE
  use_wu <- cfg$USE_1901_WARMUP %||% TRUE

  df <- raw$KNC |>
    dplyr::rename(KNC = value) |>
    dplyr::inner_join(raw$KNR_idx |> dplyr::rename(KNR_idx = value), by = "year") |>
    dplyr::inner_join(raw$IG |> dplyr::rename(IG = value), by = "year") |>
    dplyr::arrange(year)

  wu_IG_R <- NULL; wu_years <- NULL
  if (use_wu && !is.null(warmup$govt_1901)) {
    wu_df <- warmup$govt_1901 |>
      dplyr::filter(year < min(df$year)) |>
      dplyr::arrange(year)
    if (nrow(wu_df) > 0) {
      wu_IG_R <- wu_df$value
      wu_years <- wu_df$year
    }
  }

  gpim_account(
    KNC           = df$KNC,
    KNR_idx       = df$KNR_idx,
    IG            = df$IG,
    year_vec      = df$year,
    L             = params$L,
    alpha         = params$alpha,
    use_weibull   = use_wb,
    account_label = "gov_trans",
    warmup_IG_R   = wu_IG_R,
    warmup_years  = wu_years,
    base_year     = cfg$GPIM$base_year %||% 2017L
  )
}


# ------------------------------------------------------------------
# GPIM Agent 3: Corporate IPP (Account C — tracked separately)
# ------------------------------------------------------------------

#' Build GPIM capital stock for corporate IPP.
#'
#' IPP does NOT enter KGC_productive. Tracked separately.
gpim_NF_IPP <- function(raw, warmup, cfg) {
  L_ipp     <- cfg$WEIBULL_PARAMS$IPP$L     %||% 5L
  alpha_ipp <- cfg$WEIBULL_PARAMS$IPP$alpha  %||% 2.0
  use_wb    <- cfg$USE_WEIBULL_RETIREMENT    %||% TRUE
  use_wu    <- cfg$USE_1901_WARMUP           %||% TRUE

  df <- raw$KNC |>
    dplyr::rename(KNC = value) |>
    dplyr::inner_join(raw$KNR_idx |> dplyr::rename(KNR_idx = value), by = "year") |>
    dplyr::inner_join(raw$IG |> dplyr::rename(IG = value), by = "year") |>
    dplyr::arrange(year)

  wu_IG_R <- NULL; wu_years <- NULL
  if (use_wu && !is.null(warmup$ipp_1901)) {
    wu_df <- warmup$ipp_1901 |>
      dplyr::filter(year < min(df$year)) |>
      dplyr::arrange(year)
    if (nrow(wu_df) > 0) {
      wu_IG_R <- wu_df$value
      wu_years <- wu_df$year
    }
  }

  gpim_account(
    KNC             = df$KNC,
    KNR_idx         = df$KNR_idx,
    IG              = df$IG,
    year_vec        = df$year,
    L               = L_ipp,
    alpha           = alpha_ipp,
    use_weibull     = use_wb,
    account_label   = "NF_IPP",
    warmup_IG_R     = wu_IG_R,
    warmup_years    = wu_years,
    use_fixed_point = TRUE,
    base_year       = cfg$GPIM$base_year %||% 2017L
  )
}


# ------------------------------------------------------------------
# GPIM Agent 4: Financial Corporate (Account D — tracked separately)
# ------------------------------------------------------------------

#' Build GPIM capital stock for financial corporate.
gpim_financial_corporate <- function(raw, warmup, cfg) {
  params <- cfg$WEIBULL_PARAMS$fin_corporate
  use_wb <- cfg$USE_WEIBULL_RETIREMENT %||% TRUE
  use_wu <- cfg$USE_1901_WARMUP %||% TRUE

  df <- raw$KNC |>
    dplyr::rename(KNC = value) |>
    dplyr::inner_join(raw$KNR_idx |> dplyr::rename(KNR_idx = value), by = "year") |>
    dplyr::inner_join(raw$IG |> dplyr::rename(IG = value), by = "year") |>
    dplyr::arrange(year)

  wu_IG_R <- NULL; wu_years <- NULL
  if (use_wu && !is.null(warmup$fin_corp_1901)) {
    wu_df <- warmup$fin_corp_1901 |>
      dplyr::filter(year < min(df$year)) |>
      dplyr::arrange(year)
    if (nrow(wu_df) > 0) {
      wu_IG_R <- wu_df$value
      wu_years <- wu_df$year
    }
  }

  gpim_account(
    KNC             = df$KNC,
    KNR_idx         = df$KNR_idx,
    IG              = df$IG,
    year_vec        = df$year,
    L               = params$L,
    alpha           = params$alpha,
    use_weibull     = use_wb,
    account_label   = "fin_corp",
    warmup_IG_R     = wu_IG_R,
    warmup_years    = wu_years,
    use_fixed_point = TRUE,
    base_year       = cfg$GPIM$base_year %||% 2017L
  )
}


# ==================================================================
# SC. AGGREGATION AGENTS
# ==================================================================

# ------------------------------------------------------------------
# Aggregation Agent 1: Build NF Income Accounts from T1.14
# ------------------------------------------------------------------

#' Build NF corporate income decomposition from NIPA T1.14.
#'
#' Extracts Lines 17-40 (NF corporate block) and computes derived
#' series: GOS_NF, ProfSh, WageSh, RetRate, DivPay.
#'
#' @param raw_t1014  Parsed NIPA T1.14 tibble (from fetch_income_accounts)
#' @param Py         tibble(year, Py_fred) from fetch_Py_deflator
#' @return tibble with full income decomposition + Py_fred
build_income_accounts <- function(raw_t1014, Py) {
  message(sprintf("\n[%s] === Build: Income accounts ===", now_stamp()))

  ## Line extraction helper (reuses pattern from 52)
  exl <- function(line, col_name) {
    out <- raw_t1014 |>
      dplyr::filter(line_number == line) |>
      dplyr::select(year, !!col_name := value) |>
      dplyr::arrange(year)
    if (nrow(out) == 0) {
      stop(sprintf("NIPA T1.14 Line %d not found (col: %s)", line, col_name))
    }
    out
  }

  ## NF corporate block (Lines 17-40)
  GVA_NF             <- exl(17, "GVA_NF")
  CCA_NF             <- exl(18, "CCA_NF")
  NVA_NF             <- exl(19, "NVA_NF")
  EC_NF              <- exl(20, "EC_NF")
  Wages_NF           <- exl(21, "Wages_NF")
  Supplements_NF     <- exl(22, "Supplements_NF")
  TPI_NF             <- exl(23, "TPI_NF")
  NOS_NF             <- exl(24, "NOS_NF")
  NetInt_NF          <- exl(25, "NetInt_NF")
  BusTransfer_NF     <- exl(26, "BusTransfer_NF")
  Profits_IVA_CC_NF  <- exl(27, "Profits_IVA_CC_NF")
  CorpTax_NF         <- exl(28, "CorpTax_NF")
  PAT_IVA_CC_NF      <- exl(29, "PAT_IVA_CC_NF")
  Dividends_NF       <- exl(30, "Dividends_NF")
  Retained_IVA_CC_NF <- exl(31, "Retained_IVA_CC_NF")
  PBT_NF             <- exl(32, "PBT_NF")
  PAT_NF             <- exl(33, "PAT_NF")
  Retained_NF        <- exl(34, "Retained_NF")
  IVA_NF             <- exl(35, "IVA_NF")
  CCAdj_NF           <- exl(36, "CCAdj_NF")

  ## Merge all
  df <- GVA_NF
  join_list <- list(CCA_NF, NVA_NF, EC_NF, Wages_NF, Supplements_NF,
                    TPI_NF, NOS_NF, NetInt_NF, BusTransfer_NF,
                    Profits_IVA_CC_NF, CorpTax_NF, PAT_IVA_CC_NF,
                    Dividends_NF, Retained_IVA_CC_NF, PBT_NF, PAT_NF,
                    Retained_NF, IVA_NF, CCAdj_NF)
  for (tbl in join_list) {
    df <- df |> dplyr::left_join(tbl, by = "year")
  }

  ## Derived series
  df <- df |>
    dplyr::arrange(year) |>
    dplyr::mutate(
      GOS_NF   = GVA_NF - EC_NF - TPI_NF,
      ProfSh   = NOS_NF / NVA_NF,
      WageSh   = EC_NF / NVA_NF,
      RetRate  = dplyr::if_else(
        !is.na(PAT_NF) & PAT_NF != 0, Retained_NF / PAT_NF, NA_real_),
      DivPay   = dplyr::if_else(
        !is.na(PAT_NF) & PAT_NF != 0, Dividends_NF / PAT_NF, NA_real_)
    )

  ## Internal consistency: NVA = GVA - CCA
  nva_gap <- max(abs(df$NVA_NF - (df$GVA_NF - df$CCA_NF)), na.rm = TRUE)
  if (nva_gap > 0.5) {
    message(sprintf("  WARNING: NVA_NF != GVA_NF - CCA_NF (max gap: %.2f)", nva_gap))
  } else {
    message("  NVA_NF = GVA_NF - CCA_NF: PASS")
  }

  ## Join Py
  df <- df |>
    dplyr::left_join(Py, by = "year")

  message(sprintf("  Income accounts: %d rows, years %d-%d",
                  nrow(df), min(df$year), max(df$year)))
  df
}


# ------------------------------------------------------------------
# Aggregation Agent 2: Aggregate Productive Capital
# ------------------------------------------------------------------

#' Aggregate productive capital (NF corporate only).
#'
#' Gov transport is retained as an auxiliary conditioning variable
#' (kept in the output for master CSV) but excluded from the
#' productive aggregate sum.
#'
#' @param nf_corp  tibble from gpim_NF_corporate()
#' @param govt     tibble from gpim_gov_transport()
#' @param years    Optional: restrict to year range
#' @return tibble with productive aggregates + gov_trans auxiliary columns
aggregate_productive <- function(nf_corp, govt, years = NULL) {
  message(sprintf("\n[%s] === Aggregate: Productive capital ===", now_stamp()))

  ## Year-range overlap check
  yr_nf   <- range(nf_corp$year)
  yr_govt <- range(govt$year)
  yr_overlap <- c(max(yr_nf[1], yr_govt[1]), min(yr_nf[2], yr_govt[2]))
  if (yr_overlap[1] > yr_overlap[2]) {
    stop(sprintf(
      "AGGREGATE HALT: No year overlap between NF corporate (%d-%d) and gov transport (%d-%d)",
      yr_nf[1], yr_nf[2], yr_govt[1], yr_govt[2]
    ))
  }
  message(sprintf("  Year overlap: %d-%d (NF_corp %d-%d, govt %d-%d)",
                  yr_overlap[1], yr_overlap[2],
                  yr_nf[1], yr_nf[2], yr_govt[1], yr_govt[2]))

  ## Rename columns with account suffix
  rename_acct <- function(df, suffix) {
    df |>
      dplyr::select(year, KNC, KNR, KGC, KGR, IG_cc, IG_R, pK, z, rho) |>
      dplyr::rename_with(~ paste0(., "_", suffix), -year)
  }

  n <- rename_acct(nf_corp, "NF_corp")
  g <- rename_acct(govt,    "gov_trans")

  ## Join (inner = restrict to overlap)
  df <- n |>
    dplyr::inner_join(g, by = "year") |>
    dplyr::arrange(year)

  ## Apply year filter
  if (!is.null(years)) {
    df <- df |> dplyr::filter(year %in% years)
  }

  ## Productive aggregates = NF corporate ONLY
  ## Gov transport retained as auxiliary conditioning variable
  df <- df |>
    dplyr::mutate(
      KGC_productive = KGC_NF_corp,
      KNC_productive = KNC_NF_corp,
      KNR_productive = KNR_NF_corp,
      KGR_productive = KGR_NF_corp,
      IG_productive  = IG_cc_NF_corp,
      pK_productive  = pK_NF_corp
    )

  ## Rebase pK_productive to 2017 = 100
  df$pK_productive <- rebase_2017(df$pK_productive, df$year, base_year = 2017L)

  message(sprintf("  Productive aggregate: %d years, KGC range %.0f - %.0f",
                  nrow(df), min(df$KGC_productive), max(df$KGC_productive)))
  df
}


# ------------------------------------------------------------------
# Aggregation Agent 3: Build Master CSV
# ------------------------------------------------------------------

#' Build the final kstock_master.csv dataset.
#'
#' @param prod     tibble from aggregate_productive()
#' @param income   tibble from build_income_accounts()
#' @param nf_corp  tibble from gpim_NF_corporate()
#' @param govt     tibble from gpim_gov_transport()
#' @param IPP      tibble from gpim_NF_IPP()
#' @param fin_corp tibble from gpim_financial_corporate()
#' @param years    Optional: restrict to year range
#' @return Master tibble for kstock_master.csv
build_master_csv <- function(prod, income, nf_corp, govt, IPP, fin_corp,
                             years = NULL) {
  message(sprintf("\n[%s] === Build: Master CSV ===", now_stamp()))

  ## IPP columns
  ipp <- IPP |>
    dplyr::select(year, KGC_NF_IPP = KGC, KNC_NF_IPP = KNC,
                  KNR_NF_IPP = KNR, pK_NF_IPP = pK, z_NF_IPP = z)

  ## Financial corporate columns
  fin <- fin_corp |>
    dplyr::select(year, KGC_fin_corp = KGC, KNC_fin_corp = KNC,
                  KNR_fin_corp = KNR, pK_fin_corp = pK, z_fin_corp = z)

  ## Join productive + income + IPP + financial
  master <- prod |>
    dplyr::inner_join(
      income |> dplyr::select(year, GVA_NF, CCA_NF, NVA_NF, EC_NF,
                              NOS_NF, TPI_NF, GOS_NF, ProfSh, WageSh, Py_fred),
      by = "year"
    ) |>
    dplyr::left_join(ipp, by = "year") |>
    dplyr::left_join(fin, by = "year")

  ## Apply year filter
  if (!is.null(years)) {
    master <- master |> dplyr::filter(year %in% years)
  }

  ## Estimation objects
  master <- master |>
    dplyr::mutate(
      ## Total with IPP
      KGC_total = KGC_productive + dplyr::coalesce(KGC_NF_IPP, 0),

      ## Output-capital ratios
      R_NVA_KGC = NVA_NF / KGC_productive,

      ## Estimation objects — two deflator variants
      k_Py  = log(KGC_productive / (Py_fred / 100)),
      k_pK  = log(KGC_productive / (pK_productive / 100)),
      y_t   = log(NVA_NF / (Py_fred / 100)),

      ## Output variants
      y_GVA = log(GVA_NF / (Py_fred / 100)),
      y_GOS = log(GOS_NF / (Py_fred / 100)),
      y_NOS = log(NOS_NF / (Py_fred / 100))
    )

  message(sprintf("  Master: %d rows x %d cols, years %d-%d",
                  nrow(master), ncol(master),
                  min(master$year), max(master$year)))

  ## Spot check: NVA / KGC_NF_corp (productive = NF_corp only)
  if (1947 %in% master$year) {
    r47 <- master$R_NVA_KGC[master$year == 1947]
    message(sprintf("  Rcorp_1947 = NVA_NF / KGC_NF_corp = %.4f", r47))
  }

  master
}
