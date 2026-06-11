############################################################
# 05_validate_provider_fetches.R - Validate Chapter 2 menu
############################################################

rm(list = ls())
source("codes/00_config_provider.R")

paths <- ch2_provider_paths()
for (path in c(paths$menu_csv, paths$metadata_csv)) {
  if (!file.exists(path)) stop("Required artifact missing: ", path)
}
menu <- utils::read.csv(paths$menu_csv, stringsAsFactors = FALSE, check.names = FALSE)
metadata <- utils::read.csv(paths$metadata_csv, stringsAsFactors = FALSE, check.names = FALSE)

menu_columns <- c(
  "variable_id", "concept_block", "sector_scope", "asset_scope",
  "preferred_role", "required_for", "provider_priority", "preferred_source",
  "bea_dataset", "bea_table_name", "bea_table_description",
  "bea_line_number", "bea_series_code", "bea_line_description",
  "bea_metric_name", "fred_search_text", "fred_series_id", "fred_title",
  "fred_units", "fred_frequency", "fetch_status", "construction_status",
  "sector_construction_rule", "formula_if_constructed", "notes"
)
metadata_columns <- c(
  "variable_id", "human_label", "definition", "sector_scope", "asset_scope",
  "unit_expected", "frequency_expected", "nominal_or_real", "source_priority",
  "construction_allowed", "construction_formula", "aggregation_rule",
  "chapter2_role", "baseline_status", "notes"
)
assert_columns(menu, menu_columns, "Master menu")
assert_columns(metadata, metadata_columns, "Master metadata")

required_ids <- c(
  as.vector(outer(
    c("gva_current", "nva_current", "gva_real_or_qindex", "gva_price_or_deflator"),
    c("corp", "nfc", "fc"), paste, sep = "_"
  )),
  as.vector(outer(
    c("comp_emp", "cfc", "net_operating_surplus", "net_interest",
      "business_transfers_net", "corp_profits_iva_ccadj", "iva", "ccadj",
      "taxes_prod_imports_less_subsidies"),
    c("corp", "nfc", "fc"), paste, sep = "_"
  )),
  as.vector(outer(
    c("me_investment_current_dollar", "nrc_investment_current_dollar",
      "me_netstock_current_cost", "nrc_netstock_current_cost",
      "me_cfc", "nrc_cfc"),
    c("corp", "nfc", "fc"), paste, sep = "_"
  )),
  "me_price_or_qindex", "nrc_price_or_qindex",
  "me_stock_price_or_revaluation_index", "nrc_stock_price_or_revaluation_index",
  "L_ME", "alpha_ME", "L_NRC", "alpha_NRC"
)

parked_patterns <- c(
  "utilization", "productive_capacity", "centered", "interaction",
  "adjusted_wage_share", "adjusted_profit_share", "exploitation",
  "logged_exploitation", "gpim_gross_stock", "productive_capital_scale",
  "composition_tau", "ipp", "govtrans", "effective_demand", "^q_t"
)
primitive_final_patterns <- c(
  "adjusted_wage_share", "adjusted_profit_share", "exploitation",
  "gpim_gross_stock", "productive_capital_scale", "centered", "interaction"
)

validation <- data.frame(
  variable_id = menu$variable_id,
  sector_scope = menu$sector_scope,
  fetch_status = menu$fetch_status,
  validation_status = "PASS",
  validation_message = "Explicit provider status and metadata are present.",
  stringsAsFactors = FALSE
)

fail_row <- function(ids, message) {
  idx <- validation$variable_id %in% ids
  validation$validation_status[idx] <<- "FAIL"
  validation$validation_message[idx] <<- message
}

missing_required <- setdiff(required_ids, menu$variable_id)
if (length(missing_required) > 0L) {
  validation <- rbind(
    validation,
    data.frame(
      variable_id = missing_required,
      sector_scope = "",
      fetch_status = "",
      validation_status = "FAIL",
      validation_message = "Required variable ID is missing from the menu.",
      stringsAsFactors = FALSE
    )
  )
}

invalid_provider <- !menu$fetch_status %in% allowed_fetch_statuses
if (any(invalid_provider)) {
  fail_row(menu$variable_id[invalid_provider], "Invalid or absent provider status.")
}

parked <- Reduce(`|`, lapply(parked_patterns, grepl, x = tolower(menu$variable_id)))
if (any(parked)) fail_row(menu$variable_id[parked], "Parked variable appears in locked menu.")

primitive <- menu$construction_status == "primitive_fetch"
final_object <- Reduce(`|`, lapply(
  primitive_final_patterns, grepl, x = tolower(menu$variable_id)
))
if (any(primitive & final_object)) {
  fail_row(
    menu$variable_id[primitive & final_object],
    "Final Chapter 2 object is incorrectly marked as a primitive fetch."
  )
}

fc_residual <- menu$fetch_status == "constructed_sector_residual"
dependency_ok <- grepl("_corp", menu$formula_if_constructed, fixed = TRUE) &
  grepl("_nfc", menu$formula_if_constructed, fixed = TRUE)
if (any(fc_residual & !dependency_ok)) {
  fail_row(
    menu$variable_id[fc_residual & !dependency_ok],
    "FC residual lacks documented CORP and NFC dependencies."
  )
}

fallback <- grepl("_investment_implied_fallback_", menu$variable_id)
fallback_meta <- metadata$chapter2_role[
  match(menu$variable_id[fallback], metadata$variable_id)
]
fallback_ok <- menu$construction_status[fallback] == "fallback_constructed" &
  fallback_meta == "fallback_only"
if (any(!fallback_ok)) {
  fail_row(
    menu$variable_id[fallback][!fallback_ok],
    "Implied investment fallback is not tagged fallback_only."
  )
}

parameter <- menu$variable_id %in% c("L_ME", "alpha_ME", "L_NRC", "alpha_NRC")
parameter_ok <- menu$fetch_status[parameter] == "not_fetchable_parameter" &
  menu$construction_status[parameter] == "metadata_only"
if (any(!parameter_ok)) {
  fail_row(
    menu$variable_id[parameter][!parameter_ok],
    "GPIM service-life parameter is not metadata-only."
  )
}

index_rows <- menu$bea_table_name == "FAAt402"
index_meta <- metadata[match(menu$variable_id[index_rows], metadata$variable_id), , drop = FALSE]
index_ok <- menu$construction_status[index_rows] == "metadata_only" &
  index_meta$chapter2_role == "validation_only" &
  index_meta$baseline_status == "comparison_only"
if (any(!index_ok)) {
  fail_row(
    menu$variable_id[index_rows][!index_ok],
    "FAAt402 index is not locked as metadata-only comparison/validation."
  )
}

nfc_deflator <- menu$variable_id == "gva_price_or_deflator_nfc"
nfc_deflator_ok <- menu$fetch_status[nfc_deflator] == "derivable_from_bea_components" &
  menu$construction_status[nfc_deflator] == "source_level_derived" &
  grepl("gva_current_nfc", menu$formula_if_constructed[nfc_deflator], fixed = TRUE) &
  grepl("gva_real_or_qindex_nfc", menu$formula_if_constructed[nfc_deflator], fixed = TRUE)
if (!isTRUE(nfc_deflator_ok)) {
  fail_row(
    "gva_price_or_deflator_nfc",
    "NFC GVA deflator is not documented as a same-boundary BEA component derivation."
  )
}

fc_real_price <- menu$variable_id %in% c(
  "gva_real_or_qindex_fc", "gva_price_or_deflator_fc"
)
if (any(menu$fetch_status[fc_real_price] != "unresolved")) {
  fail_row(
    menu$variable_id[fc_real_price][menu$fetch_status[fc_real_price] != "unresolved"],
    "FC real/price object must remain unresolved; raw residual subtraction is prohibited."
  )
}

fred_accepted <- menu$fetch_status == "fallback_fred" |
  (!is.na(menu$fred_series_id) & nzchar(menu$fred_series_id))
if (any(fred_accepted)) {
  fail_row(
    menu$variable_id[fred_accepted],
    "A FRED candidate was accepted without an explicit promotion task."
  )
}

direct_rows <- menu$fetch_status == "direct_bea"
for (i in which(direct_rows)) {
  path <- find_latest_bea_snapshot(
    menu$bea_dataset[i], menu$bea_table_name[i], paths
  )
  if (is.null(path)) {
    validation$validation_status[i] <- "FAIL"
    validation$validation_message[i] <- "Direct BEA mapping has no preserved source snapshot."
    next
  }
  data <- standardize_bea_snapshot(path, menu$bea_dataset[i], menu$bea_table_name[i])
  line <- suppressWarnings(as.integer(menu$bea_line_number[i]))
  code <- menu$bea_series_code[i]
  present <- any(data$line_number == line, na.rm = TRUE)
  if (nzchar(code) && "series_code" %in% names(data)) {
    present <- present && any(data$series_code == code, na.rm = TRUE)
  }
  if (!present) {
    validation$validation_status[i] <- "FAIL"
    validation$validation_message[i] <- paste0(
      "Mapped BEA table/line/series is absent from preserved snapshot: ",
      menu$bea_table_name[i], " line ", menu$bea_line_number[i], "."
    )
  } else {
    validation$validation_message[i] <- paste0(
      "Verified in preserved ", menu$bea_table_name[i], " snapshot."
    )
  }
}

validation <- validation[order(validation$validation_status, validation$variable_id), , drop = FALSE]
utils::write.csv(validation, paths$status_csv, row.names = FALSE, na = "")

failed <- validation$validation_status == "FAIL"
message("Provider validation status: ", paths$status_csv,
        " (", sum(!failed), " PASS, ", sum(failed), " FAIL)")
if (any(failed)) {
  stop("Chapter 2 provider validation failed for: ",
       paste(validation$variable_id[failed], collapse = ", "))
}
