############################################################
# 10_bea_api_helpers.R - Shared BEA provider infrastructure
############################################################

provider_root <- function() {
  root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
  if (!file.exists(file.path(root, "US-BEA-Income-FixedAssets-Dataset.Rproj"))) {
    stop("Run provider scripts from the repository root.")
  }
  root
}

provider_paths <- function(root = provider_root()) {
  list(
    root = root,
    metadata = file.path(root, "data", "metadata"),
    raw_provider = file.path(root, "data", "raw", "provider"),
    staged = file.path(root, "data", "staged"),
    legacy_cache = file.path(root, "data", "interim", "bea_parsed"),
    docs = file.path(root, "docs")
  )
}

ensure_provider_dirs <- function(paths = provider_paths()) {
  dirs <- unname(unlist(paths[c("metadata", "raw_provider", "staged", "docs")]))
  invisible(lapply(dirs, dir.create, recursive = TRUE, showWarnings = FALSE))
}

provider_download_date <- function() {
  format(Sys.Date(), "%Y-%m-%d")
}

bea_query_string <- function(dataset, table, year = "X") {
  paste0(
    "https://apps.bea.gov/api/data?UserID=${BEA_API_KEY}",
    "&method=GetData&datasetname=", dataset,
    "&TableName=", table,
    "&Frequency=A&Year=", year,
    "&ResultFormat=JSON"
  )
}

fetch_bea_table <- function(dataset, table, year = "X",
                            api_key = Sys.getenv("BEA_API_KEY")) {
  if (!nzchar(api_key)) {
    stop("BEA_API_KEY is not set.")
  }
  if (!requireNamespace("httr", quietly = TRUE)) {
    stop("Package 'httr' is required.")
  }

  response <- httr::GET(
    "https://apps.bea.gov/api/data",
    query = list(
      UserID = api_key,
      method = "GetData",
      datasetname = dataset,
      TableName = table,
      Frequency = "A",
      Year = year,
      ResultFormat = "JSON"
    ),
    httr::timeout(120)
  )
  httr::stop_for_status(response)
  payload <- httr::content(response, as = "parsed", simplifyVector = FALSE)

  error <- payload$BEAAPI$Results$Error
  if (!is.null(error)) {
    stop(error$APIErrorDescription %||% "Unknown BEA API error.")
  }

  records <- payload$BEAAPI$Results$Data
  if (is.null(records) || length(records) == 0L) {
    stop(sprintf("BEA returned no rows for %s/%s.", dataset, table))
  }

  rows <- lapply(records, function(x) {
    data.frame(
      year = as.integer(x$TimePeriod %||% NA_character_),
      line_number = as.integer(x$LineNumber %||% NA_character_),
      line_desc = as.character(x$LineDescription %||% "not_provided"),
      value = suppressWarnings(as.numeric(gsub(",", "", x$DataValue %||% NA_character_))),
      series_code = as.character(x$SeriesCode %||% "not_provided"),
      unit = as.character(x$UNIT_MULT %||% x$CL_UNIT %||% "not_provided"),
      table_name = table,
      source = "BEA_API",
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0L) y else x
}

write_raw_snapshot <- function(data, dataset, table,
                               paths = provider_paths(),
                               download_date = provider_download_date()) {
  out_dir <- file.path(paths$raw_provider, download_date)
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  out_path <- file.path(out_dir, paste0(dataset, "_", table, ".csv"))
  if (file.exists(out_path)) {
    message("Raw snapshot already exists; preserving it: ", out_path)
    return(out_path)
  }
  utils::write.csv(data, out_path, row.names = FALSE, na = "")
  out_path
}

legacy_cache_map <- function() {
  c(
    FAAt401 = "private_net_cc.csv",
    FAAt402 = "private_net_chain.csv",
    FAAt404 = "private_dep_cc.csv",
    FAAt407 = "private_inv.csv",
    FAAt701 = "govt_net_cc.csv",
    FAAt702 = "govt_net_chain.csv",
    FAAt703 = "govt_dep_cc.csv",
    FAAt705 = "govt_inv_cc.csv",
    T11400 = "nipa_t1014.csv",
    T71100 = "nipa_t7011.csv"
  )
}

read_provider_table <- function(table, paths = provider_paths()) {
  snapshots <- list.files(
    paths$raw_provider,
    pattern = paste0("_", table, "\\.csv$"),
    recursive = TRUE,
    full.names = TRUE
  )
  if (length(snapshots) > 0L) {
    path <- sort(snapshots, decreasing = TRUE)[1]
    data <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
    return(list(data = data, path = path, source = "provider_raw_snapshot",
                download_date = basename(dirname(path))))
  }

  cache_file <- unname(legacy_cache_map()[table])
  if (length(cache_file) == 1L && !is.na(cache_file)) {
    path <- file.path(paths$legacy_cache, cache_file)
    if (file.exists(path)) {
      data <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
      fixed_tables <- grepl("^FAA", table)
      cached_date <- if (fixed_tables) "2026-03-15" else "2026-03-25"
      return(list(data = data, path = path, source = "legacy_cached_api_extract",
                  download_date = cached_date))
    }
  }
  NULL
}

manifest_row <- function(variable_id, canonical_name, source_system,
                         bea_dataset, bea_table, bea_line,
                         bea_line_description, sector_boundary, asset_block,
                         account_boundary, unit, price_basis, stock_flow_type,
                         role_tag, priority, required_for_downstream_object,
                         status, notes, source_cache_file = "not_available",
                         aggregation_group = "not_applicable") {
  data.frame(
    variable_id = variable_id,
    canonical_name = canonical_name,
    source_system = source_system,
    bea_dataset = bea_dataset,
    bea_table = bea_table,
    bea_line = as.character(bea_line),
    bea_line_description = bea_line_description,
    series_code = "not_provided_by_cached_extract",
    sector_boundary = sector_boundary,
    asset_block = asset_block,
    account_boundary = account_boundary,
    frequency = "A",
    unit = unit,
    price_basis = price_basis,
    stock_flow_type = stock_flow_type,
    role_tag = role_tag,
    priority = priority,
    required_for_downstream_object = required_for_downstream_object,
    download_date = "resolved_at_stage_time",
    vintage = "BEA vintage at download; cached extracts document 2025-09-26 revision",
    source_url_or_query = if (bea_table %in% c("not_available", "downstream_only")) {
      "not_applicable"
    } else {
      bea_query_string(
        bea_dataset,
        bea_table,
        if (bea_dataset == "FixedAssets") "ALL" else "X"
      )
    },
    status = status,
    notes = notes,
    source_cache_file = source_cache_file,
    aggregation_group = aggregation_group,
    stringsAsFactors = FALSE
  )
}

provider_manifest <- function() {
  rows <- list()
  add <- function(...) rows[[length(rows) + 1L]] <<- manifest_row(...)

  sector_lines <- list(
    CORP = c(TOTAL = 17, ME = 18, NRC = 19, IPP = 20),
    FIN = c(TOTAL = 33, ME = 34, NRC = 35, IPP = 36),
    NFC = c(TOTAL = 37, ME = 38, NRC = 39, IPP = 40)
  )
  family_map <- list(
    net_stock_current_cost = list(table = "FAAt401", cache = "private_net_cc.csv",
                                  unit = "Millions of current dollars",
                                  basis = "current_cost", type = "net_stock"),
    net_stock_quantity_index = list(table = "FAAt402", cache = "private_net_chain.csv",
                                    unit = "Chain-type quantity index",
                                    basis = "chain_quantity_index", type = "net_stock"),
    cfc_current_cost = list(table = "FAAt404", cache = "private_dep_cc.csv",
                            unit = "Millions of current dollars",
                            basis = "current_cost", type = "cfc"),
    gross_investment_current_cost = list(table = "FAAt407", cache = "private_inv.csv",
                                         unit = "Millions of current dollars",
                                         basis = "current_cost", type = "gross_investment")
  )
  asset_roles <- c(
    TOTAL = "capital_menu_total",
    ME = "direct_productive_capacity_capital",
    NRC = "direct_productive_capacity_capital",
    IPP = "frontier_conditioner"
  )
  asset_names <- c(TOTAL = "total", ME = "machinery_equipment",
                   NRC = "nonresidential_structures", IPP = "intellectual_property_products")

  for (sector in names(sector_lines)) {
    priority <- if (sector == "FIN") "diagnostic" else "required"
    for (asset in names(sector_lines[[sector]])) {
      for (family in names(family_map)) {
        spec <- family_map[[family]]
        add(
          paste(sector, asset, family, sep = "__"),
          paste(sector, asset_names[[asset]], family, sep = "_"),
          "BEA", "FixedAssets", spec$table, sector_lines[[sector]][[asset]],
          paste(sector, asset_names[[asset]], family),
          sector, asset, "fixed_assets", spec$unit, spec$basis, spec$type,
          asset_roles[[asset]], priority,
          if (asset %in% c("ME", "NRC")) "downstream_GPIM_and_K_cap" else
            if (asset == "IPP") "frontier_conditioning_variables" else "sector_total_diagnostic",
          "staged",
          "Direct BEA line. ME and NRC enter preferred K_cap downstream; IPP does not.",
          spec$cache
        )
      }
      add(
        paste(sector, asset, "gross_stock_current_cost", sep = "__"),
        paste(sector, asset_names[[asset]], "gross_stock_current_cost", sep = "_"),
        "BEA", "FixedAssets", "not_available", "not_available",
        "BEA standard Fixed Assets API does not publish this legal-form-by-asset gross-stock line",
        sector, asset, "fixed_assets", "not_available", "current_cost", "gross_stock",
        asset_roles[[asset]], priority, "downstream_GPIM_benchmark",
        "not_available",
        "Preserve as a required gap. Do not substitute net stock or construct GPIM here."
      )
      add(
        paste(sector, asset, "official_price_index", sep = "__"),
        paste(sector, asset_names[[asset]], "official_price_index", sep = "_"),
        "BEA", "FixedAssets", "not_available", "unmapped",
        "Price index requires a verified BEA table mapping",
        sector, asset, "fixed_assets", "Index", "official_price_index", "price_index",
        asset_roles[[asset]], "diagnostic", "official_BEA_price_diagnostic",
        "requires_manual_mapping",
        "Diagnostic only. Do not treat an implicit or official BEA price index as a GPIM output."
      )
    }
  }

  for (sector in c("NFC", "CORP")) {
    for (asset in c("ME", "NRC", "IPP")) {
      for (family in c("retirements", "revaluation_holding_gains")) {
        add(
          paste(sector, asset, family, sep = "__"),
          paste(sector, asset_names[[asset]], family, sep = "_"),
          "BEA", "FixedAssets", "not_available", "not_available",
          paste(family, "not directly available in the staged standard table menu"),
          sector, asset, "fixed_assets", "not_available", "not_applicable", family,
          asset_roles[[asset]], "required", "downstream_GPIM_diagnostics",
          "not_available",
          "Retain as an explicit provider gap; no residual construction is permitted here."
        )
      }
    }
  }

  gov_families <- list(
    net_stock_current_cost = list(table = "FAAt701", line_table = "FAAt701",
                                  cache = "govt_net_cc.csv", basis = "current_cost",
                                  type = "net_stock", status = "staged"),
    net_stock_quantity_index = list(table = "FAAt702", line_table = "FAAt702",
                                    cache = "govt_net_chain.csv", basis = "chain_quantity_index",
                                    type = "net_stock", status = "staged"),
    cfc_current_cost = list(table = "FAAt703", line_table = "FAAt703",
                            cache = "govt_dep_cc.csv", basis = "current_cost",
                            type = "cfc", status = "staged"),
    gross_investment_current_cost = list(table = "FAAt705", line_table = "FAAt705",
                                         cache = "FixedAssets_FAAt705.csv",
                                         basis = "current_cost",
                                         type = "gross_investment",
                                         status = "staged")
  )
  gov_components <- c(TRANSPORTATION_STRUCTURES = 12, HIGHWAYS_STREETS = 14)
  for (asset in names(gov_components)) {
    for (family in names(gov_families)) {
      spec <- gov_families[[family]]
      add(
        paste("GOV_TRANS", asset, family, sep = "__"),
        paste("GOV_TRANS", tolower(asset), family, sep = "_"),
        "BEA", "FixedAssets", spec$table, gov_components[[asset]],
        paste("Government", tolower(gsub("_", " ", asset))),
        "GOV_TRANS", asset, "government_fixed_assets",
        if (spec$basis == "chain_quantity_index") "Chain-type quantity index"
        else "Millions of current dollars",
        spec$basis, spec$type, "frontier_conditioner", "required",
        "GOV_TRANS_GPIM_and_frontier_conditioning_variables",
        spec$status,
        if (family == "gross_investment_current_cost") {
          paste(
            "Live BEA FAAt705 mapping verified on 2026-06-09.",
            "Component of downstream GOV_TRANS aggregate;",
            "do not add to preferred private K_cap."
          )
        } else if (spec$status == "staged") {
          "Component of downstream GOV_TRANS aggregate; do not add to preferred private K_cap."
        } else {
          "FAAt705 requires a live BEA fetch or verified local extract."
        },
        spec$cache, "GOV_TRANS"
      )
    }
  }
  add(
    "GOV_TRANS__gross_stock_current_cost", "GOV_TRANS_gross_stock_current_cost",
    "BEA", "FixedAssets", "not_available", "not_available",
    "Current-cost gross stock not published in the standard staged menu",
    "GOV_TRANS", "TRANSPORT_AGGREGATE", "government_fixed_assets",
    "not_available", "current_cost", "gross_stock", "frontier_conditioner", "required",
    "GOV_TRANS_GPIM", "not_available",
    "Do not substitute net stock. Downstream GPIM must be explicit.", aggregation_group = "GOV_TRANS"
  )

  income_lines <- list(
    list("CORP_GVA", "CORP_gross_value_added", "CORP", 1, "gross_value_added", "required"),
    list("CORP_CFC", "CORP_consumption_fixed_capital", "CORP", 2, "cfc", "required"),
    list("CORP_NVA", "CORP_net_value_added", "CORP", 3, "net_value_added", "required"),
    list("CORP_COMP", "CORP_compensation_employees", "CORP", 4, "compensation", "required"),
    list("CORP_NOS", "CORP_net_operating_surplus", "CORP", 8, "net_operating_surplus", "required"),
    list("CORP_NET_INT", "CORP_net_interest_misc_payments", "CORP", 9, "net_interest", "required"),
    list("CORP_TRANSFERS_NET", "CORP_business_current_transfers_net", "CORP", 10, "current_transfers_net", "required"),
    list("CORP_PROFITS_IVA_CC", "CORP_profits_with_IVA_CCAdj", "CORP", 11, "profits", "required"),
    list("CORP_TAX", "CORP_taxes_corporate_income", "CORP", 12, "corporate_taxes", "diagnostic"),
    list("CORP_AFTER_TAX", "CORP_profits_after_tax_IVA_CCAdj", "CORP", 13, "after_tax_profits", "diagnostic"),
    list("CORP_DIVIDENDS_NET", "CORP_net_dividends", "CORP", 14, "dividends_net", "required"),
    list("CORP_UNDISTRIBUTED", "CORP_undistributed_profits_IVA_CCAdj", "CORP", 15, "undistributed_profits", "diagnostic"),
    list("FIN_GVA", "FIN_gross_value_added", "FIN", 16, "gross_value_added", "required"),
    list("NFC_GVA", "NFC_gross_value_added", "NFC", 17, "gross_value_added", "required"),
    list("NFC_CFC", "NFC_consumption_fixed_capital", "NFC", 18, "cfc", "required"),
    list("NFC_NVA", "NFC_net_value_added", "NFC", 19, "net_value_added", "required"),
    list("NFC_COMP", "NFC_compensation_employees", "NFC", 20, "compensation", "required"),
    list("NFC_NOS", "NFC_net_operating_surplus", "NFC", 24, "net_operating_surplus", "required"),
    list("NFC_NET_INT", "NFC_net_interest_misc_payments", "NFC", 25, "net_interest", "required"),
    list("NFC_TRANSFERS_NET", "NFC_business_current_transfers_net", "NFC", 26, "current_transfers_net", "required"),
    list("NFC_PROFITS_IVA_CC", "NFC_profits_with_IVA_CCAdj", "NFC", 27, "profits", "required"),
    list("NFC_TAX", "NFC_taxes_corporate_income", "NFC", 28, "corporate_taxes", "diagnostic"),
    list("NFC_AFTER_TAX", "NFC_profits_after_tax_IVA_CCAdj", "NFC", 29, "after_tax_profits", "diagnostic"),
    list("NFC_DIVIDENDS_NET", "NFC_net_dividends", "NFC", 30, "dividends_net", "required"),
    list("NFC_UNDISTRIBUTED", "NFC_undistributed_profits_IVA_CCAdj", "NFC", 31, "undistributed_profits", "diagnostic"),
    list("NFC_PBT", "NFC_profits_before_tax", "NFC", 32, "profits_before_tax", "required"),
    list("NFC_PAT", "NFC_profits_after_tax", "NFC", 33, "after_tax_profits", "diagnostic"),
    list("NFC_RETAINED", "NFC_undistributed_profits_after_tax", "NFC", 34, "undistributed_profits", "diagnostic"),
    list("CORP_PBT", "CORP_profits_before_tax", "CORP", 37, "profits_before_tax", "required"),
    list("CORP_PAT", "CORP_profits_after_tax", "CORP", 38, "after_tax_profits", "diagnostic")
  )
  for (item in income_lines) {
    add(
      item[[1]], item[[2]], "BEA", "NIPA", "T11400", item[[4]],
      paste("NIPA Table 1.14 line", item[[4]]),
      item[[3]], "not_applicable", "income_accounts",
      "Millions of current dollars", "current_cost", item[[5]],
      if (item[[3]] == "FIN") "corporate_boundary_diagnostic" else "income_account_ingredient",
      item[[6]], "Shaikh_income_correction_and_distributive_variables",
      "staged", "Direct NIPA Table 1.14 line; no adjusted share is constructed here.",
      "nipa_t1014.csv"
    )
  }

  for (id in c("FIN_CFC", "FIN_NVA", "FIN_COMP", "FIN_NOS", "FIN_PBT",
               "FIN_NET_INT", "FIN_TRANSFERS", "FIN_DIVIDENDS")) {
    add(
      id, id, "BEA", "NIPA", "downstream_only", "not_applicable",
      "Derived from explicitly staged CORP/NFC ingredients or requires another NIPA table",
      "FIN", "not_applicable", "income_accounts", "Millions of current dollars",
      "current_cost", "income_account", "corporate_boundary_diagnostic", "required",
      "financial_corporate_correction_layer", "downstream_constructed_only",
      "Do not silently substitute total financial business. Downstream derivation must cite inputs."
    )
  }

  imputed_lines <- list(
    list(4, "BankMonIntPaid_paid_financial"),
    list(44, "BankMonIntPaid_paid_banks_credit_investment"),
    list(73, "BankMonIntPaid_received_federal"),
    list(28, "BankMonIntPaid_received_financial"),
    list(52, "BankMonIntPaid_paid_state_local"),
    list(91, "BankMonIntPaid_paid_government"),
    list(74, "CorpNFNetImpIntPaid_line74"),
    list(53, "CorpNFNetImpIntPaid_line53")
  )
  for (item in imputed_lines) {
    add(
      paste0("T711_L", item[[1]]), item[[2]], "BEA", "NIPA", "T71100", item[[1]],
      paste("NIPA Table 7.11 line", item[[1]]),
      if (item[[1]] %in% c(4, 28, 44)) "FIN" else "CORP_FIN_BOUNDARY",
      "not_applicable", "imputed_interest",
      "Millions of current dollars", "current_cost", "interest_flow",
      "shaikh_candidate_line_ingredient", "required",
      "shaikh_candidate_semantic_audit_only",
      "staged",
      paste(
        "Candidate Shaikh-line ingredient only. Staged with provenance.",
        "Not semantically admissible for CorpImpIntAdj_t construction until",
        "historical/current crosswalk validation passes."
      ),
      "nipa_t7011.csv"
    )
  }

  for (boundary in c("NFC", "CORP", "FIN")) {
    for (flow in c("current_transfer_payments", "current_transfer_receipts",
                   "dividends_paid", "dividends_received")) {
      add(
        paste(boundary, flow, sep = "__"), paste(boundary, flow, sep = "_"),
        "BEA", "NIPA", "not_available", "unmapped",
        "Separate payment and receipt line requires verified NIPA mapping",
        boundary, "not_applicable", "income_accounts",
        "Millions of current dollars", "current_cost", flow,
        "income_account_ingredient", "required", "Shaikh_income_correction",
        "requires_manual_mapping",
        "Net lines may be staged from T1.14, but gross payment/receipt components must not be inferred."
      )
    }
  }

  add(
    "RESIDENTIAL_CAPITAL_MENU", "residential_capital_menu", "BEA", "FixedAssets",
    "not_available", "unmapped", "Residential fixed-assets table mapping",
    "PRIVATE", "RESIDENTIAL", "fixed_assets", "various", "various", "capital_stock",
    "exclusion_diagnostic", "diagnostic", "residential_exclusion_diagnostic",
    "requires_manual_mapping", "Preserve as an exclusion diagnostic; never include silently in K_cap."
  )
  add(
    "INVENTORIES_MENU", "inventories_menu", "BEA", "NIPA",
    "not_available", "unmapped", "Inventory stock/flow table mapping",
    "CORP", "INVENTORIES", "income_accounts", "various", "current_cost", "inventory",
    "circulation_stockflow_diagnostic", "optional", "inventory_diagnostic",
    "requires_manual_mapping", "Optional circulation stock-flow diagnostic."
  )

  downstream <- c(
    "K_G_NFC_ME_GPIM", "K_G_NFC_NRC_GPIM", "K_G_NFC_KCAP_GPIM",
    "K_N_NFC_ME_GPIM", "K_N_NFC_NRC_GPIM", "K_N_NFC_KCAP_GPIM",
    "P_K_NFC_ME_GPIM", "P_K_NFC_NRC_GPIM", "IPP_NFC_GPIM", "GOV_TRANS_GPIM",
    "pi_adj_CORP", "omega_adj_CORP", "e_adj_CORP", "ln_e_adj_CORP",
    "pi_adj_NFC", "omega_adj_NFC", "e_adj_NFC", "ln_e_adj_NFC",
    "e_x_Kcap", "e_x_ME", "e_x_NRC", "e_x_ME_NRC_gap"
  )
  for (id in downstream) {
    add(
      paste0("DOWNSTREAM__", id), id, "downstream_repo", "not_applicable",
      "downstream_only", "not_applicable", "Constructed only in Capacity-Utilization-US_Chile",
      if (grepl("CORP", id)) "CORP" else "NFC",
      "not_applicable", "analytical_construction", "not_applicable", "not_applicable",
      "analytical_object", "downstream_analytical_object", "downstream",
      id, "downstream_constructed_only",
      "Provider supplies ingredients only. This row is a construction contract, not staged data."
    )
  }

  manifest <- do.call(rbind, rows)
  manifest[order(manifest$priority, manifest$sector_boundary,
                 manifest$variable_id), , drop = FALSE]
}

write_locked_manifest <- function(manifest = provider_manifest(),
                                  paths = provider_paths()) {
  ensure_provider_dirs(paths)
  csv_path <- file.path(paths$metadata, "us_bea_variable_menu_locked.csv")
  json_path <- file.path(paths$metadata, "us_bea_variable_menu_locked.json")
  utils::write.csv(manifest, csv_path, row.names = FALSE, na = "")
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("Package 'jsonlite' is required to write the locked JSON manifest.")
  }
  jsonlite::write_json(
    list(
      schema_version = "1.0.0",
      locked_date = "2026-06-09",
      provider_role = "BEA/NIPA/Fixed Assets ingredient provider only",
      analytical_authority = "Capacity-Utilization-US_Chile",
      preferred_K_cap = "K_ME + K_NRC",
      preferred_theta = "theta(omega_t | IPP_t, GOV_TRANS_t)",
      preferred_distributive_state = "wage share (omega_t)",
      alternative_distributive_proxy = "exploitation rate (e_t)",
      variables = manifest
    ),
    json_path, pretty = TRUE, auto_unbox = TRUE, na = "null"
  )
  invisible(c(csv = csv_path, json = json_path))
}
