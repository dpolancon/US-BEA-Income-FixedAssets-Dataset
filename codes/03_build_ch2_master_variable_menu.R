############################################################
# 03_build_ch2_master_variable_menu.R - Build locked menu
############################################################

rm(list = ls())
source("codes/00_config_provider.R")

paths <- ch2_provider_paths()
ensure_ch2_provider_dirs(paths)

menu_rows <- list()
metadata_rows <- list()

add_variable <- function(
    variable_id, human_label, definition, concept_block, sector_scope = "NA",
    asset_scope = "NA", preferred_role, required_for, provider_priority,
    preferred_source, bea_dataset = "", bea_table_name = "",
    bea_table_description = "", bea_line_number = "", bea_series_code = "",
    bea_line_description = "", bea_metric_name = "",
    fred_search_text = "", fred_series_id = "", fred_title = "",
    fred_units = "", fred_frequency = "", fetch_status,
    construction_status = "primitive_fetch", sector_construction_rule = "",
    formula_if_constructed = "", notes = "", unit_expected = "",
    frequency_expected = "Annual", nominal_or_real = "nominal",
    source_priority = "BEA direct; FRED exact BEA-origin fallback",
    construction_allowed = "no", construction_formula = "",
    aggregation_rule = "not applicable", chapter2_role,
    baseline_status = "locked") {

  menu_rows[[length(menu_rows) + 1L]] <<- data.frame(
    variable_id, concept_block, sector_scope, asset_scope, preferred_role,
    required_for, provider_priority, preferred_source, bea_dataset,
    bea_table_name, bea_table_description, bea_line_number,
    bea_series_code, bea_line_description, bea_metric_name,
    fred_search_text, fred_series_id, fred_title, fred_units,
    fred_frequency, fetch_status, construction_status,
    sector_construction_rule, formula_if_constructed, notes,
    stringsAsFactors = FALSE
  )
  metadata_rows[[length(metadata_rows) + 1L]] <<- data.frame(
    variable_id, human_label, definition, sector_scope, asset_scope,
    unit_expected, frequency_expected, nominal_or_real, source_priority,
    construction_allowed, construction_formula, aggregation_rule,
    chapter2_role, baseline_status, notes,
    stringsAsFactors = FALSE
  )
}

sector_suffix <- c(CORP = "domestic corporate business",
                   NFC = "nonfinancial domestic corporate business",
                   FC = "financial corporate business")

nipa_direct <- list(
  gva_current = list(CORP = c(1, "A451RC", "Gross value added of corporate business"),
                     NFC = c(17, "A455RC", "Gross value added of nonfinancial corporate business"),
                     FC = c(16, "A454RC", "Gross value added of financial corporate business")),
  nva_current = list(CORP = c(3, "A439RC", "Net value added"),
                     NFC = c(19, "A457RC", "Net value added")),
  comp_emp = list(CORP = c(4, "A442RC", "Compensation of employees"),
                  NFC = c(20, "A460RC", "Compensation of employees")),
  cfc = list(CORP = c(2, "A438RC", "Consumption of fixed capital"),
             NFC = c(18, "B456RC", "Consumption of fixed capital")),
  net_operating_surplus = list(CORP = c(8, "W322RC", "Net operating surplus"),
                               NFC = c(24, "W326RC", "Net operating surplus")),
  net_interest = list(CORP = c(9, "A453RC", "Net interest and miscellaneous payments"),
                      NFC = c(25, "B471RC", "Net interest and miscellaneous payments")),
  business_transfers_net = list(CORP = c(10, "W323RC", "Business current transfer payments (net)"),
                                NFC = c(26, "W327RC", "Business current transfer payments (net)")),
  corp_profits_iva_ccadj = list(CORP = c(11, "A445RC", "Corporate profits with IVA and CCAdj"),
                                NFC = c(27, "A463RC", "Corporate profits with IVA and CCAdj")),
  iva = list(CORP = c(35, "B058RC", "Inventory valuation adjustment"),
             NFC = c(39, "B058RC", "Inventory valuation adjustment")),
  ccadj = list(CORP = c(36, "A059RC", "Capital consumption adjustment"),
               NFC = c(40, "B470RC", "Capital consumption adjustment")),
  taxes_prod_imports_less_subsidies = list(
    CORP = c(7, "W321RC", "Taxes on production and imports less subsidies"),
    NFC = c(23, "W325RC", "Taxes on production and imports less subsidies")
  )
)

output_specs <- list(
  list(prefix = "gva_current", label = "Current-dollar gross value added",
       search = "Gross value added of", unit = "Millions of current dollars",
       nominal = "nominal"),
  list(prefix = "nva_current", label = "Current-dollar net value added",
       search = "Net value added of", unit = "Millions of current dollars",
       nominal = "nominal"),
  list(prefix = "gva_real_or_qindex", label = "Real GVA or quantity index",
       search = "Real gross value added of", unit = "Real dollars or quantity index",
       nominal = "real_or_quantity_index"),
  list(prefix = "gva_price_or_deflator", label = "GVA price index or deflator",
       search = "Price index gross value added", unit = "Price index",
       nominal = "price_index")
)

for (spec in output_specs) {
  for (sector in c("CORP", "NFC", "FC")) {
    id <- paste(spec$prefix, tolower(sector), sep = "_")
    direct <- nipa_direct[[spec$prefix]][[sector]]
    if (spec$prefix == "gva_real_or_qindex" && sector == "NFC") {
      direct <- c(41, "B455RX", "Gross value added of nonfinancial corporate business")
    }
    if (spec$prefix == "gva_price_or_deflator" && sector == "NFC") {
      status <- "derivable_from_bea_components"
      source <- "BEA components"
      construction <- "source-level only"
      formula <- "gva_price_or_deflator_nfc = 100 * gva_current_nfc / gva_real_or_qindex_nfc after harmonizing units"
      rule <- "Use matching NFC current-dollar and chained-dollar GVA components only"
      role <- "preferred_baseline_source"
      direct <- c(
        "17 + 41",
        "A455RC + B455RX",
        "NFC current-dollar and chained-dollar gross value added"
      )
    } else if (!is.null(direct)) {
      status <- "direct_bea"
      source <- "BEA"
      construction <- "no"
      formula <- ""
      rule <- ""
      role <- if (spec$prefix %in% c("gva_current", "nva_current")) {
        "preferred_baseline_source"
      } else {
        "robustness_source"
      }
    } else if (sector == "FC" && spec$prefix == "nva_current") {
      status <- "constructed_sector_residual"
      source <- "Sector residual"
      construction <- "yes"
      formula <- "nva_current_fc = nva_current_corp - nva_current_nfc"
      rule <- "FC = CORP - NFC; nominal accounting identity only"
      role <- "source_ingredient"
      direct <- c("", "", "")
    } else {
      status <- "unresolved"
      source <- "Unresolved"
      construction <- "no"
      formula <- ""
      rule <- if (sector == "FC" && grepl("real|price", spec$prefix)) {
        "Do not subtract raw real quantities or price indexes"
      } else {
        ""
      }
      role <- "unresolved"
      direct <- c("", "", "")
    }
    search <- paste(spec$search, sector_suffix[[sector]])
    unresolved_note <- switch(
      id,
      gva_real_or_qindex_corp = paste(
        "Source review completed 2026-06-11: T11400 has no chained-dollar",
        "CORP GVA line. FRED candidates are NFC unit-price or cost series and",
        "do not match the CORP real-GVA concept."
      ),
      gva_real_or_qindex_fc = paste(
        "Source review completed 2026-06-11: no direct FC real-GVA line was",
        "found. FRED candidates are NFC series. Raw CORP-minus-NFC real",
        "residual construction is prohibited."
      ),
      gva_price_or_deflator_corp = paste(
        "Source review completed 2026-06-11: no matching CORP real/quantity",
        "GVA component or exact BEA-origin FRED price series was found, so a",
        "same-boundary implicit deflator cannot yet be formed."
      ),
      gva_price_or_deflator_fc = paste(
        "Source review completed 2026-06-11: no direct FC real/quantity GVA",
        "component or exact BEA-origin FRED price series was found. Raw",
        "real/price residual construction is prohibited."
      ),
      "No verified direct BEA mapping; exact BEA-origin FRED fallback remains unavailable."
    )
    add_variable(
      id, paste(spec$label, sector),
      paste(spec$label, "for the", sector_suffix[[sector]], "boundary."),
      "output_value_added", sector, "NA", "source_ingredient",
      "Chapter 2 output and value-added boundary", 1L, source,
      if (status %in% c("direct_bea", "derivable_from_bea_components")) "NIPA" else "",
      if (status %in% c("direct_bea", "derivable_from_bea_components")) "T11400" else "",
      if (status %in% c("direct_bea", "derivable_from_bea_components")) "NIPA Table 1.14" else "",
      direct[[1]], direct[[2]], direct[[3]],
      if (spec$nominal == "nominal") "Millions of dollars" else "Index",
      search, fetch_status = status,
      construction_status = if (status == "derivable_from_bea_components") {
        "source_level_derived"
      } else if (status == "constructed_sector_residual") {
        "not_constructed_here"
      } else if (status == "unresolved") {
        "not_constructed_here"
      } else {
        "primitive_fetch"
      },
      sector_construction_rule = rule, formula_if_constructed = formula,
      notes = if (status == "derivable_from_bea_components") {
        paste(
          "Derivable from validated T11400 NFC current-dollar line 17 and",
          "chained-dollar line 41 after unit harmonization.",
          "This is a source-level accounting counterpart, not an econometric object."
        )
      } else if (status == "unresolved") {
        unresolved_note
      } else {
        "Verified against the preserved 2026-06-09 T11400 snapshot."
      },
      unit_expected = spec$unit, nominal_or_real = spec$nominal,
      construction_allowed = construction, construction_formula = formula,
      aggregation_rule = if (grepl("real|price", spec$prefix)) {
        if (status == "derivable_from_bea_components") {
          "Match nominal and real/chained-dollar GVA at the same NFC boundary; harmonize units before division."
        } else {
          "No raw subtraction across sector real quantities or price indexes."
        }
      } else {
        "Nominal accounting values are additive across CORP = NFC + FC."
      },
      chapter2_role = role,
      baseline_status = if (status == "derivable_from_bea_components") {
        "source_level_derived"
      } else {
        "locked"
      }
    )
  }
}

distribution_specs <- list(
  comp_emp = c("Compensation of employees paid", "Compensation of employees"),
  cfc = c("Consumption of fixed capital", "Consumption of fixed capital"),
  net_operating_surplus = c("Net operating surplus", "Net operating surplus"),
  net_interest = c("Net interest and miscellaneous payments", "Net interest"),
  business_transfers_net = c("Business current transfer payments net", "Business transfers, net"),
  corp_profits_iva_ccadj = c(
    "Corporate profits with inventory valuation and capital consumption adjustments",
    "Corporate profits with IVA and CCAdj"
  ),
  iva = c("Inventory valuation adjustment corporate profits", "Inventory valuation adjustment"),
  ccadj = c("Capital consumption adjustment corporate profits", "Capital consumption adjustment"),
  taxes_prod_imports_less_subsidies = c(
    "Taxes on production and imports less subsidies",
    "Taxes on production and imports less subsidies"
  )
)

for (prefix in names(distribution_specs)) {
  for (sector in c("CORP", "NFC", "FC")) {
    id <- paste(prefix, tolower(sector), sep = "_")
    direct <- nipa_direct[[prefix]][[sector]]
    if (!is.null(direct)) {
      status <- "direct_bea"
      source <- "BEA"
      formula <- ""
      rule <- ""
      construction <- "no"
    } else {
      status <- "constructed_sector_residual"
      source <- "Sector residual"
      formula <- paste0(id, " = ", prefix, "_corp - ", prefix, "_nfc")
      rule <- "FC = CORP - NFC; nominal accounting identity"
      construction <- "yes"
      direct <- c("", "", "")
    }
    add_variable(
      id, paste(distribution_specs[[prefix]][[2]], sector),
      paste(distribution_specs[[prefix]][[2]], "for the", sector_suffix[[sector]], "boundary."),
      "distribution_accounting", sector, "NA", "source_ingredient",
      "Shaikh-style correction source ingredients", 1L, source,
      if (status == "direct_bea") "NIPA" else "",
      if (status == "direct_bea") "T11400" else "",
      if (status == "direct_bea") "NIPA Table 1.14" else "",
      direct[[1]], direct[[2]], direct[[3]], "Millions of dollars",
      paste(distribution_specs[[prefix]][[1]], sector_suffix[[sector]]),
      fetch_status = status,
      construction_status = if (status == "direct_bea") "primitive_fetch" else "not_constructed_here",
      sector_construction_rule = rule, formula_if_constructed = formula,
      notes = if (status == "direct_bea") {
        "Verified against the preserved 2026-06-09 T11400 snapshot."
      } else {
        "Provider documents the valid nominal residual; downstream analytical construction remains external."
      },
      unit_expected = "Millions of current dollars",
      construction_allowed = construction, construction_formula = formula,
      aggregation_rule = "Nominal accounting values are additive across CORP = NFC + FC.",
      chapter2_role = "source_ingredient"
    )
  }
}

fixed_tables <- list(
  investment_current_dollar = c("FAAt407", "Fixed Assets Table 4.7 current-cost investment", "i3"),
  netstock_current_cost = c("FAAt401", "Fixed Assets Table 4.1 current-cost net stock", "k1"),
  cfc = c("FAAt404", "Fixed Assets Table 4.4 current-cost depreciation", "m1")
)
fixed_lines <- list(
  CORP = c(ME = 18, NRC = 19),
  FC = c(ME = 34, NRC = 35),
  NFC = c(ME = 38, NRC = 39)
)
series_sector_code <- c(CORP = "totl2", FC = "fito2", NFC = "nofi2")
series_asset_code <- c(ME = "eq00", NRC = "st00")

for (family in names(fixed_tables)) {
  for (asset in c("ME", "NRC")) {
    for (sector in c("CORP", "NFC", "FC")) {
      id <- paste(tolower(asset), family, tolower(sector), sep = "_")
      if (family == "investment_current_dollar") {
        id <- paste(tolower(asset), "investment_current_dollar", tolower(sector), sep = "_")
      } else if (family == "netstock_current_cost") {
        id <- paste(tolower(asset), "netstock_current_cost", tolower(sector), sep = "_")
      } else {
        id <- paste(tolower(asset), "cfc", tolower(sector), sep = "_")
      }
      table <- fixed_tables[[family]][[1]]
      line <- fixed_lines[[sector]][[asset]]
      series <- paste0(
        fixed_tables[[family]][[3]], "n", series_sector_code[[sector]],
        series_asset_code[[asset]]
      )
      asset_label <- if (asset == "ME") "equipment" else "structures"
      family_label <- switch(
        family,
        investment_current_dollar = "Current-dollar investment",
        netstock_current_cost = "Current-cost net stock",
        cfc = "Current-cost depreciation"
      )
      search <- paste(family_label, sector_suffix[[sector]], asset_label, "fixed assets")
      add_variable(
        id, paste(family_label, asset, sector),
        paste(family_label, "for", asset_label, "at the", sector, "legal-form boundary."),
        "fixed_assets_gpim", sector, asset, "direct_productive_capacity_capital",
        if (family == "investment_current_dollar") "Preferred GPIM investment input" else {
          "GPIM fallback input and validation"
        },
        1L, "BEA", "FixedAssets", table, fixed_tables[[family]][[2]],
        line, series, if (asset == "ME") "Equipment" else "Structures",
        "Millions of dollars", search, fetch_status = "direct_bea",
        notes = "Verified against the preserved 2026-06-09 Fixed Assets snapshot.",
        unit_expected = "Millions of current dollars",
        construction_allowed = "no",
        aggregation_rule = "Aggregate ME and NRC only in nominal/current-cost terms.",
        chapter2_role = if (family == "investment_current_dollar") {
          "gpim_required_source"
        } else {
          "source_ingredient"
        }
      )
    }
  }
}

for (asset in c("ME", "NRC")) {
  asset_label <- if (asset == "ME") "equipment" else "structures"
  line <- if (asset == "ME") 2 else 3
  series <- if (asset == "ME") "kcntotl1eq00" else "kcntotl1st00"
  id <- paste0(tolower(asset), "_price_or_qindex")
  add_variable(
    id, paste(asset_label, "net-stock quantity index"),
    paste("BEA chain-type quantity index for private", asset_label, "net stocks."),
    "fixed_assets_gpim", "NA", asset, "validation_index",
    "Official quantity-index diagnostic", 2L, "BEA",
    "FixedAssets", "FAAt402",
    "Fixed Assets Table 4.2 net-stock chain-type quantity indexes",
    line, series, if (asset == "ME") "Equipment" else "Structures",
    "Chain-type quantity index",
    paste("Price index", asset_label, "fixed investment"),
    fetch_status = "direct_bea",
    construction_status = "metadata_only",
    notes = paste(
      "Official BEA quality-adjusted quantity index is a comparison/validation",
      "diagnostic, not a price index, GPIM input, or GPIM output."
    ),
    unit_expected = "Chain-type quantity index", nominal_or_real = "quantity_index",
    aggregation_rule = "Do not raw-add ME and NRC quantity indexes.",
    chapter2_role = "validation_only", baseline_status = "comparison_only"
  )

  stock_id <- paste0(tolower(asset), "_stock_price_or_revaluation_index")
  add_variable(
    stock_id, paste(asset_label, "stock price or revaluation index"),
    paste("Price or revaluation index required for stock-flow-implied", asset_label, "investment."),
    "fixed_assets_gpim", "NA", asset, "fallback_input",
    "Stock-flow-implied investment fallback", 3L, "Unresolved",
    fred_search_text = paste("Price index", asset_label, "fixed assets"),
    fetch_status = "unresolved", construction_status = "not_constructed_here",
    notes = paste(
      "Source review completed 2026-06-11: no clean direct BEA or exact",
      "BEA-origin FRED stock-price/revaluation index was found.",
      "Not blocking baseline because direct nominal investment remains canonical.",
      "Required only if implied-investment fallback is activated.",
      "Do not substitute a quantity index."
    ),
    unit_expected = "Price or revaluation index", nominal_or_real = "price_index",
    construction_allowed = "no",
    aggregation_rule = "Asset-specific index required.",
    chapter2_role = "unresolved"
  )
}

implied_formula <- paste0(
  "I_N_implied_i_t = K_N_CC_i_t - ",
  "(P_K_i_t / P_K_i_t_minus_1) * K_N_CC_i_t_minus_1 + CFC_CC_i_t"
)
for (asset in c("ME", "NRC")) {
  for (sector in c("CORP", "NFC", "FC")) {
    id <- paste(tolower(asset), "investment_implied_fallback", tolower(sector), sep = "_")
    add_variable(
      id, paste(asset, "stock-flow-implied investment fallback", sector),
      "Documented fallback construction used only when direct investment is unavailable.",
      "fixed_assets_gpim_fallback", sector, asset, "fallback_diagnostic",
      "GPIM fallback documentation", 4L, "Provider construction",
      fetch_status = "direct_fetch_available_but_not_used",
      construction_status = "fallback_constructed",
      sector_construction_rule = "Use asset-sector matched inputs only.",
      formula_if_constructed = implied_formula,
      notes = "Direct FAAt407 investment is available and remains canonical; this fallback is not computed here.",
      unit_expected = "Millions of current dollars",
      source_priority = "Fallback only after direct BEA and exact BEA-origin FRED",
      construction_allowed = "fallback only",
      construction_formula = implied_formula,
      aggregation_rule = "Construct by asset; aggregate only in nominal/current-cost terms.",
      chapter2_role = "fallback_only", baseline_status = "fallback_only"
    )
  }
}

parameters <- list(
  L_ME = list(value = "14", asset = "ME", label = "ME mean service life"),
  alpha_ME = list(value = "1.7", asset = "ME", label = "ME Weibull shape"),
  L_NRC = list(value = "30", asset = "NRC", label = "NRC mean service life"),
  alpha_NRC = list(value = "1.6", asset = "NRC", label = "NRC Weibull shape")
)
for (id in names(parameters)) {
  spec <- parameters[[id]]
  add_variable(
    id, spec$label,
    paste0(spec$label, " parameter; locked value = ", spec$value, "."),
    "gpim_parameters", "NA", spec$asset, "gpim_parameter",
    "Downstream GPIM parameterization", 0L, "Provider metadata",
    fetch_status = "not_fetchable_parameter", construction_status = "metadata_only",
    notes = paste0(
      "Locked parameter value: ", spec$value,
      ". Lambda may be derived downstream as L / Gamma(1 + 1 / alpha)."
    ),
    unit_expected = if (grepl("^L_", id)) "Years" else "Dimensionless",
    nominal_or_real = "parameter",
    source_priority = "Locked provider metadata; not fetched",
    construction_allowed = "no",
    aggregation_rule = "Asset-specific parameter.",
    chapter2_role = "gpim_parameter"
  )
}

menu <- do.call(rbind, menu_rows)
metadata <- do.call(rbind, metadata_rows)

stopifnot(
  all(menu$sector_scope %in% allowed_sector_scopes),
  all(menu$asset_scope %in% allowed_asset_scopes),
  all(menu$fetch_status %in% allowed_fetch_statuses),
  all(menu$construction_status %in% allowed_construction_statuses),
  all(metadata$chapter2_role %in% allowed_chapter2_roles)
)

menu <- menu[order(menu$concept_block, menu$variable_id), , drop = FALSE]
metadata <- metadata[order(metadata$variable_id), , drop = FALSE]
utils::write.csv(menu, paths$menu_csv, row.names = FALSE, na = "")
utils::write.csv(metadata, paths$metadata_csv, row.names = FALSE, na = "")

message("Master variable menu: ", paths$menu_csv, " (", nrow(menu), " rows)")
message("Master variable metadata: ", paths$metadata_csv, " (", nrow(metadata), " rows)")
