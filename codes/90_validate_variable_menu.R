############################################################
# 90_validate_variable_menu.R - Validate provider contract
############################################################

rm(list = ls())
source("codes/10_bea_api_helpers.R")

paths <- provider_paths()
manifest_path <- file.path(paths$metadata, "us_bea_variable_menu_locked.csv")
ledger_path <- file.path(paths$metadata, "us_bea_source_provenance_ledger.csv")
staged_path <- file.path(paths$staged, "us_bea_variable_menu_long.csv")

for (path in c(manifest_path, ledger_path, staged_path)) {
  if (!file.exists(path)) stop("Required provider artifact missing: ", path)
}

manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE, check.names = FALSE)
ledger <- utils::read.csv(ledger_path, stringsAsFactors = FALSE, check.names = FALSE)
staged <- utils::read.csv(staged_path, stringsAsFactors = FALSE, check.names = FALSE)

required_columns <- c(
  "variable_id", "canonical_name", "source_system", "bea_dataset",
  "bea_table", "bea_line", "bea_line_description", "series_code",
  "sector_boundary", "asset_block", "account_boundary", "frequency",
  "unit", "price_basis", "stock_flow_type", "role_tag", "priority",
  "required_for_downstream_object", "download_date", "vintage",
  "source_url_or_query", "status", "notes"
)
missing_columns <- setdiff(required_columns, names(staged))
complete_provenance <- length(missing_columns) == 0L &&
  all(vapply(staged[required_columns], function(x) {
    all(!is.na(x) & nzchar(trimws(as.character(x))))
  }, logical(1)))

required_711 <- paste0("T711_L", c(4, 44, 73, 28, 52, 91, 74, 53))
present_711 <- required_711 %in% unique(staged$variable_id)

me_nrc_roles <- unique(manifest$role_tag[manifest$asset_block %in% c("ME", "NRC")])
ipp_gov_roles <- unique(manifest$role_tag[
  manifest$asset_block == "IPP" | manifest$sector_boundary == "GOV_TRANS"
])
boundaries <- c("NFC", "CORP", "FIN", "GOV_TRANS")
boundary_check <- boundaries %in% unique(manifest$sector_boundary)
downstream_leak <- any(grepl("^DOWNSTREAM__", staged$variable_id))
official_indexes_diagnostic <- all(
  manifest$priority[manifest$stock_flow_type == "price_index"] == "diagnostic"
)
readme_path <- file.path(paths$root, "README.md")
readme_text <- if (file.exists(readme_path)) paste(readLines(readme_path, warn = FALSE), collapse = "\n") else ""
ownership_documented <- grepl("Capacity-Utilization-US_Chile", readme_text, fixed = TRUE)

hard_checks <- c(
  complete_provenance = complete_provenance,
  required_table_711_lines = all(present_711),
  me_nrc_direct_capital = identical(me_nrc_roles, "direct_productive_capacity_capital"),
  ipp_gov_frontier = identical(ipp_gov_roles, "frontier_conditioner"),
  all_boundaries_represented = all(boundary_check),
  no_downstream_objects_staged = !downstream_leak,
  official_indexes_diagnostic = official_indexes_diagnostic,
  downstream_ownership_documented = ownership_documented
)

required_ledger <- ledger[ledger$priority == "required", , drop = FALSE]
staged_required <- required_ledger[required_ledger$status == "staged", , drop = FALSE]
not_available <- required_ledger[required_ledger$status == "not_available", , drop = FALSE]
manual <- required_ledger[required_ledger$status == "requires_manual_mapping", , drop = FALSE]
downstream_only <- required_ledger[
  required_ledger$status == "downstream_constructed_only", , drop = FALSE
]
live_dates <- unique(staged$download_date[grepl("data/raw/provider", staged$source_file, fixed = TRUE)])
used_live_fetch <- length(live_dates) > 0L
fetch_statement <- if (used_live_fetch) {
  paste0(
    "Live BEA snapshots were staged for download date(s): ",
    paste(sort(live_dates), collapse = ", "),
    ". Raw snapshots are preserved under `data/raw/provider/`."
  )
} else {
  paste(
    "Live BEA fetching was unavailable in this run.",
    "Staging used preserved March 2026 API extracts where available."
  )
}

fmt_ids <- function(x) {
  if (length(x) == 0L) return("- None")
  paste0("- `", x, "`", collapse = "\n")
}
fmt_check <- function(value) if (isTRUE(value)) "PASS" else "FAIL"

report <- c(
  "# U.S. BEA Variable Menu Validation Report",
  "",
  paste0("**Run date:** ", provider_download_date()),
  "",
  "## Scope",
  "",
  "This report validates the BEA/NIPA/Fixed Assets provider layer. It does not validate",
  "Chapter 2 GPIM, distributive variables, interaction variables, or econometric results.",
  "",
  fetch_statement,
  "",
  "## Validation Answers",
  "",
  paste0("1. Successfully staged required variables: **", nrow(staged_required),
         " manifest variables**, **", nrow(staged), " annual observations**."),
  paste0("2. Required variables unavailable directly from the locked standard menu: **",
         nrow(not_available), "**."),
  paste0("3. Required variables needing live fetch, manual mapping, or downstream derivation: **",
         nrow(manual) + nrow(downstream_only), "**."),
  paste0("4. IPP and GOV_TRANS preserved as frontier conditioners and excluded from preferred `K_cap`: **",
         fmt_check(hard_checks["ipp_gov_frontier"]), "**."),
  paste0("5. ME and NRC tagged `direct_productive_capacity_capital`: **",
         fmt_check(hard_checks["me_nrc_direct_capital"]), "**."),
  paste0("6. Required NIPA Table 7.11 lines present: **",
         fmt_check(hard_checks["required_table_711_lines"]), "**."),
  "   Shaikh formula semantic admissibility: **BLOCKED**.",
  "   Staged T711 rows prove presence and provenance only; the semantic audit does not validate the formula roles.",
  paste0("7. NFC, CORP, FIN, and GOV_TRANS boundaries represented: **",
         fmt_check(hard_checks["all_boundaries_represented"]), "**."),
  paste0("8. Official BEA real/price indexes diagnostic rather than GPIM outputs: **",
         fmt_check(hard_checks["official_indexes_diagnostic"]), "**."),
  paste0("9. Downstream analytical ownership documented: **",
         fmt_check(hard_checks["downstream_ownership_documented"]), "**."),
  paste0("10. Every staged row has table-line-unit-vintage provenance: **",
         fmt_check(hard_checks["complete_provenance"]), "**."),
  "",
  "### Successfully Staged Required Variables",
  "",
  fmt_ids(staged_required$variable_id),
  "",
  "## Required Gaps",
  "",
  "### Not Available Directly",
  "",
  fmt_ids(not_available$variable_id),
  "",
  "### Requires Manual Mapping or Live Fetch",
  "",
  fmt_ids(manual$variable_id),
  "",
  "### Downstream Construction Only",
  "",
  fmt_ids(downstream_only$variable_id),
  "",
  "## Interpretation Lock",
  "",
  "- Preferred private productive-capacity capital is `K_cap = K_ME + K_NRC`.",
  "- IPP and government transportation assets remain staged frontier conditioners.",
  "- The preferred transformation object is `theta(omega_t | IPP_t, GOV_TRANS_t)`.",
  "- Wage share is the preferred downstream distributive state; exploitation rate is an alternative proxy.",
  "- The additive alternative `g_Yp = theta*g_Kcap + psi*g_IPP + gamma*g_GOV_TRANS` is not implemented.",
  "- Official BEA quantity and price indexes are diagnostics, not binding GPIM products.",
  "- Gross stock, retirements, revaluation, separate transfer receipts/payments, and separate dividend flows are not imputed here.",
  "- Live BEA metadata identifies `FAAt705` as government investment and `FAAt707` as current-cost average age.",
  "- The audit-time `FAAt707` raw snapshot is retained but excluded from the locked investment menu.",
  "",
  "## S30I Diagnostic Readiness",
  "",
  "The staged menu separates source behavior by asset, stock/flow family, sector boundary,",
  "and official quantity-index status. This allows the downstream repo to distinguish BEA",
  "series behavior from GPIM implementation, gross/net choices, NFC/CORP boundaries,",
  "ME-NRC composition, IPP treatment, and GOV_TRANS frontier conditioning.",
  "",
  "## Handoff to Capacity-Utilization-US_Chile",
  "",
  "The downstream analytical repository may import:",
  "",
  "- the staged T711 candidate lines",
  "- `data/metadata/us_bea_shaikh_candidate_line_semantic_audit.csv`",
  "- `docs/US_BEA_SHAIKH_LINE_SEMANTIC_AUDIT.md`",
  "",
  "It must not construct the following until a documented historical/current semantic crosswalk validates the formula roles:",
  "",
  "- `BankMonIntPaid`",
  "- `CorpNFNetImpIntPaid`",
  "- `CorpImpIntAdj_t`",
  "- Shaikh-adjusted value added",
  "- Shaikh-adjusted operating surplus",
  "- Shaikh-adjusted distributive variables",
  "",
  "Non-Shaikh downstream work may proceed in later bounded passes, including:",
  "",
  "- `K_G_NFC_ME_GPIM`, `K_G_NFC_NRC_GPIM`, `K_G_NFC_KCAP_GPIM`",
  "- `K_N_NFC_ME_GPIM`, `K_N_NFC_NRC_GPIM`, `K_N_NFC_KCAP_GPIM`",
  "- `P_K_NFC_ME_GPIM`, `P_K_NFC_NRC_GPIM`, `IPP_NFC_GPIM`, `GOV_TRANS_GPIM`",
  "- preferred wage-share interactions: `omega_x_Kcap`, `omega_x_ME`, `omega_x_NRC`, `omega_x_ME_NRC_gap`",
  "- alternative exploitation-rate proxies: `e_x_Kcap`, `e_x_ME`, `e_x_NRC`, `e_x_ME_NRC_gap`",
  "- `source_provenance_ledger`",
  "",
  "These are not final products of this provider repository. The downstream repo owns",
  "GPIM, interaction variables, admissibility ledgers, and S10/S20/S30.",
  "Shaikh-style adjusted construction remains blocked by the semantic audit.",
  "",
  "## Hard Checks",
  "",
  paste0("- ", names(hard_checks), ": **", vapply(hard_checks, fmt_check, character(1)), "**")
)

report_path <- file.path(paths$docs, "US_BEA_VARIABLE_MENU_VALIDATION_REPORT.md")
writeLines(report, report_path, useBytes = TRUE)

if (!all(hard_checks)) {
  failed <- names(hard_checks)[!hard_checks]
  stop("Provider validation failed: ", paste(failed, collapse = ", "))
}

message("Provider validation PASS")
message("Report: ", report_path)
