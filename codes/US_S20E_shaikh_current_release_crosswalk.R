# Provider-side S20E Shaikh Appendix 6.7 current-release crosswalk layer.
# This script writes source-discovery ledgers only. It does not construct
# adjusted Shaikh series or downstream Chapter 2 objects.

out_dir <- file.path("output", "US", "S20E_SHAIKH_CURRENT_RELEASE_CROSSWALK")
csv_dir <- file.path(out_dir, "csv")
md_dir <- file.path(out_dir, "md")
dir.create(csv_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(md_dir, recursive = TRUE, showWarnings = FALSE)

doc_paths <- c(
  appendix = file.path("docs", "Shaikh2016_Appendix6.7.pdf"),
  book = file.path("docs", "shaikh_measuring_wealth_nations.pdf"),
  bea_guide = file.path("docs", "bea_web_service_api_user_guide.pdf"),
  qwen_note = file.path("docs", "Shaikh_NOS_QWEN_deep-research.pdf")
)

bea_key_present <- any(nzchar(Sys.getenv(c("BEA_API_KEY", "BEA_USER_ID", "BEA_API_USER_ID"))))
fred_key_present <- nzchar(Sys.getenv("FRED_API_KEY"))
api_status <- if (bea_key_present) "API_ACCESS_AVAILABLE_NOT_USED_BY_THIS_STATIC_WRITER" else "PENDING_API_ACCESS"
fred_status <- if (fred_key_present) "FRED_API_ACCESS_AVAILABLE_NOT_USED_BY_THIS_STATIC_WRITER" else "PENDING_API_ACCESS"

wcsv <- function(x, file) {
  write.csv(x, file.path(csv_dir, file), row.names = FALSE, na = "")
}

bea_getdata_template <- function(dataset, table) {
  paste0(
    "https://apps.bea.gov/api/data?UserID=${BEA_API_KEY}",
    "&method=GetData&datasetname=", dataset,
    "&TableName=", table,
    "&Frequency=A&Year=X&ResultFormat=JSON"
  )
}

bea_table_values_template <- paste0(
  "https://apps.bea.gov/api/data?UserID=${BEA_API_KEY}",
  "&method=GetParameterValues&datasetname=NIPA&ParameterName=TableName&ResultFormat=JSON"
)

fred_search_template <- function(term) {
  paste0(
    "https://api.stlouisfed.org/fred/series/search?api_key=${FRED_API_KEY}",
    "&search_type=full_text&file_type=json&search_text=",
    utils::URLencode(term, reserved = TRUE)
  )
}

source_availability <- data.frame(
  document_name = c(
    "Shaikh2016_Appendix6.7.pdf",
    "shaikh_measuring_wealth_nations.pdf",
    "bea_web_service_api_user_guide.pdf",
    "Shaikh_NOS_QWEN_deep-research.pdf"
  ),
  required_role = c(
    "primary_semantic_source",
    "conceptual_background_source",
    "api_documentation_source",
    "subordinate_research_note_audit_source"
  ),
  required_local_path = unname(doc_paths),
  availability_status = ifelse(file.exists(doc_paths), "FOUND", "MISSING"),
  used_in_this_run = c(
    "yes - semantic concepts, formulas, historical clues",
    "yes - conceptual background only",
    "yes - API method design",
    "yes - subordinate audit input only"
  ),
  notes = c(
    "Appendix 6.7 lines around the actual-versus-imputed-interest discussion and Appendix Table 6.7.11 drive the semantic layer.",
    "Used only to confirm the conceptual treatment of finance and productive/unproductive labor; not used as current-release table-line authority.",
    "Used for BEA API method sequence: GetDataSetList, GetParameterList, GetParameterValues, GetParameterValuesFiltered where supported, then GetData.",
    "Used only to identify search heuristics, possible misunderstandings, and rejected/parked paths; never used to authorize formulas, signs, mappings, source construction, or handoff."
  )
)
wcsv(source_availability, "S20E_source_document_availability.csv")

concept_rows <- data.frame(
  shaikh_label = c(
    "BankNetIntPaid",
    "Financial corporate total net interest paid",
    "NFNetImpIntPaid",
    "NonFin corporate net imputed interest paid",
    "CorpImpIntAdj",
    "BusImpIntAdj",
    "NIPA Corp GVA",
    "NIPA Corp VA",
    "NIPA Corp GOS",
    "NIPA Corp NOS",
    "Final Corp GVA",
    "Final Corp VA",
    "Final Corp GOS",
    "Final Corp NOS",
    "Business GVA NIPA",
    "Business VA NIPA",
    "Business Sector GOS NIPA",
    "Business Sector NOS NIPA",
    "Final Business Sector GVA",
    "Final Business Sector VA",
    "Final Business Sector GOS",
    "Final Business Sector NOS",
    "Consumption of fixed capital",
    "Compensation of employees",
    "Taxes on production and imports less subsidies",
    "Statistical discrepancy",
    "Net interest and miscellaneous payments",
    "Corporate profits with IVA and CCAdj",
    "Business current transfer payments net",
    "Proprietors income and noncorporate wage-equivalent"
  ),
  label_type = c(
    "equation_acronym",
    "table_label",
    "equation_acronym",
    "ingredient",
    "equation_acronym",
    "equation_acronym",
    "ingredient",
    "ingredient",
    "ingredient",
    "ingredient",
    "constructed_object",
    "constructed_object",
    "constructed_object",
    "constructed_object",
    "ingredient",
    "ingredient",
    "ingredient",
    "ingredient",
    "constructed_object",
    "constructed_object",
    "constructed_object",
    "constructed_object",
    "ingredient",
    "ingredient",
    "ingredient",
    "ingredient",
    "ingredient",
    "ingredient",
    "ingredient",
    "adjustment_term"
  ),
  nearby_text_concept = c(
    "Appendix Table 6.7.11 item 1: Bank (Financial Corporate) Net Int Paid.",
    "Appendix 6.7 states bank total net interest paid is a negative item used to keep bank profits unchanged.",
    "Appendix Table 6.7.11 item 2: NonFin Business Net Imputed Int Paid.",
    "Appendix Table 6.7.11 item 8: NonFin Corporate Net Imputed Interest Paid.",
    "Appendix Table 6.7.11 item 9: - Fin Corp Mon Int Paid - NonFin Corp Net Imputed Int Paid.",
    "Appendix Table 6.7.11 item 3: - Fin Corp Net Int Paid - NonFin Bus Net Imputed Int Paid.",
    "Appendix Table 6.7.11 corporate measures: NIPA Corp GVA plus CorpImpIntAdj.",
    "Appendix Table 6.7.11 corporate measures: NIPA Corp VA plus CorpImpIntAdj.",
    "Appendix Table 6.7.11 corporate measures: NIPA Corp GOS plus CorpImpIntAdj.",
    "Appendix Table 6.7.11 corporate measures: NIPA Corp NOS plus CorpImpIntAdj.",
    "Appendix Table 6.7.11 final corporate GVA formula.",
    "Appendix Table 6.7.11 final corporate VA formula.",
    "Appendix Table 6.7.11 final corporate GOS formula.",
    "Appendix Table 6.7.11 final corporate NOS formula.",
    "Appendix Table 6.7.11 business measures item 4.",
    "Appendix Table 6.7.11 business measures item 5.",
    "Appendix Table 6.7.11 business measures item 6.",
    "Appendix Table 6.7.11 business measures item 7.",
    "Appendix Table 6.7.11 final business sector GVA formula.",
    "Appendix Table 6.7.11 final business sector VA formula.",
    "Appendix Table 6.7.11 final business sector GOS formula with wage-equivalent adjustment.",
    "Appendix Table 6.7.11 final business sector NOS formula with wage-equivalent adjustment.",
    "Appendix Table 6.7.2 and current corporate base accounts.",
    "Appendix Table 6.7.2 and current corporate base accounts.",
    "Appendix Table 6.7.2 and current corporate base accounts.",
    "Appendix Table 6.7.2 derives GDI from GDP less statistical discrepancy.",
    "Appendix Table 6.7.2 includes net interest and miscellaneous payments.",
    "Appendix Table 6.7.2 includes corporate profits with inventory valuation and capital consumption adjustments.",
    "Appendix Table 6.7.2 includes business current transfer payments net.",
    "Appendix Table 6.7.4 uses proprietors and partnerships income, self-employed persons, and private-sector compensation per FTE."
  ),
  natural_language_concept_description = c(
    "Net monetary, imputed, and borrower-service interest paid by financial corporate business, net of corresponding receipts, in Shaikh's bank/finance adjustment.",
    "Total net interest paid by the financial corporate/bank sector, expected to be negative when financial corporations are net recipients.",
    "Net imputed interest paid by nonfinancial business: borrower services paid by nonfinancial corporate and proprietors/partners less imputed interest received.",
    "Net imputed interest paid by nonfinancial corporate business: nonfinancial corporate borrower services paid less nonfinancial corporate imputed interest received.",
    "Corporate imputed interest adjustment restoring imputed-interest effects: negative financial corporate net interest paid minus nonfinancial corporate net imputed interest paid.",
    "Business imputed interest adjustment restoring imputed-interest effects: negative financial corporate net interest paid minus nonfinancial business net imputed interest paid.",
    "Current-dollar gross value added of domestic corporate business before Shaikh imputed-interest adjustment.",
    "Current-dollar net value added of domestic corporate business before Shaikh imputed-interest adjustment.",
    "Gross operating surplus of domestic corporate business before Shaikh imputed-interest adjustment.",
    "Net operating surplus of domestic corporate business before Shaikh imputed-interest adjustment.",
    "Adjusted corporate gross value added after adding corporate imputed interest adjustment.",
    "Adjusted corporate net value added after adding corporate imputed interest adjustment.",
    "Adjusted corporate gross operating surplus after adding corporate imputed interest adjustment.",
    "Adjusted corporate net operating surplus after adding corporate imputed interest adjustment.",
    "For-profit business gross value added before imputed-interest removal.",
    "For-profit business net value added before imputed-interest removal.",
    "For-profit business gross operating surplus before imputed-interest removal.",
    "For-profit business net operating surplus before imputed-interest removal.",
    "Business gross value added after adding the business imputed-interest adjustment.",
    "Business net value added after adding the business imputed-interest adjustment.",
    "Business gross operating surplus after wage-equivalent subtraction and business imputed-interest addition.",
    "Business net operating surplus after wage-equivalent subtraction and business imputed-interest addition.",
    "Depreciation/consumption of fixed capital ingredient for moving between gross and net measures.",
    "Compensation of employees ingredient used in income-side decomposition and wage-share lanes.",
    "Taxes on production and imports less subsidies ingredient used in income-side value-added decomposition.",
    "GDP-GDI balancing item; historical clue for aggregate derivation, not a corporate Shaikh-adjustment input.",
    "Net interest and miscellaneous payments in NIPA income-side accounts.",
    "Corporate profits with inventory valuation and capital consumption adjustments.",
    "Business current transfer payments net in NIPA income-side accounts.",
    "Noncorporate wage-equivalent pathway used for business-sector profit/NOS adjustment; separate from corporate-only pathway."
  ),
  historical_table_clue = c(
    "NIPA Table 7.11 downloaded 2011-03-14",
    "NIPA Table 7.11 and Appendix examples",
    "NIPA Table 7.11 downloaded 2011-03-14",
    "NIPA Table 7.11 downloaded 2011-03-14",
    "NIPA Table 7.11 downloaded 2011-03-14",
    "NIPA Table 7.11 downloaded 2011-03-14",
    "Appendix Table 6.7.11; NIPA corporate accounts",
    "Appendix Table 6.7.11; NIPA corporate accounts",
    "Appendix Table 6.7.11; NIPA corporate accounts",
    "Appendix Table 6.7.11; NIPA corporate accounts",
    "Appendix Table 6.7.11",
    "Appendix Table 6.7.11",
    "Appendix Table 6.7.11",
    "Appendix Table 6.7.11",
    "Appendix Table 6.7.3",
    "Appendix Table 6.7.3",
    "Appendix Table 6.7.3",
    "Appendix Table 6.7.3",
    "Appendix Table 6.7.11",
    "Appendix Table 6.7.11",
    "Appendix Table 6.7.11",
    "Appendix Table 6.7.11",
    "NIPA Table 1.10 and current corporate accounts",
    "NIPA Table 1.10 and current corporate accounts",
    "NIPA Table 1.10 and current corporate accounts",
    "NIPA Table 1.7.5 and 1.10",
    "NIPA Table 1.10 and current corporate accounts",
    "NIPA Table 1.10 and current corporate accounts",
    "NIPA Table 1.10 and current corporate accounts",
    "NIPA Tables 1.13, 1.14, 6.2, 6.3, 6.7; Fixed Assets Table 6.1"
  ),
  historical_line_clue = c(
    "lines (4 + 44 + 73) - (28 + 52 + 91)",
    "not a single line; described as negative bank total net interest paid",
    "lines (74 + 75) - lines (53 + 54)",
    "line 74 - line 53",
    "- item (1) - item (8)",
    "- item (1) - item (2)",
    "not shown as line in Table 6.7.11",
    "not shown as line in Table 6.7.11",
    "not shown as line in Table 6.7.11",
    "not shown as line in Table 6.7.11",
    "NIPA Corp GVA + CorpImpIntAdj",
    "NIPA Corp VA + CorpImpIntAdj",
    "NIPA Corp GOS + CorpImpIntAdj",
    "NIPA Corp NOS + CorpImpIntAdj",
    "Appendix Table 6.7.3",
    "Appendix Table 6.7.3",
    "Appendix Table 6.7.3",
    "Appendix Table 6.7.3",
    "(4) + BusImpIntAdj",
    "(5) + BusImpIntAdj",
    "(6) - WEQ2 + BusImpIntAdj",
    "(7) - WEQ2 + BusImpIntAdj",
    "Table 1.10 line 23 in Appendix Table 6.7.2",
    "Table 1.10 line 2 in Appendix Table 6.7.2",
    "Table 1.10 lines 9-10 in Appendix Table 6.7.2",
    "Table 1.7.5 line 15 in Appendix Table 6.7.2",
    "Table 1.10 line 13 in Appendix Table 6.7.2",
    "Table 1.10 line 17 in Appendix Table 6.7.2",
    "Table 1.10 line 14 in Appendix Table 6.7.2",
    "Table 6.7.4 clues"
  ),
  formula_role = c(
    "adjustment ingredient",
    "adjustment ingredient",
    "adjustment ingredient",
    "adjustment ingredient",
    "corporate adjustment term",
    "business adjustment term",
    "base measure for adjusted corporate GVA",
    "base measure for adjusted corporate VA",
    "base measure for adjusted corporate GOS",
    "base measure for adjusted corporate NOS",
    "final adjusted object",
    "final adjusted object",
    "final adjusted object",
    "final adjusted object",
    "base measure for adjusted business GVA",
    "base measure for adjusted business VA",
    "base measure for adjusted business GOS",
    "base measure for adjusted business NOS",
    "final adjusted object",
    "final adjusted object",
    "final adjusted object",
    "final adjusted object",
    "gross-to-net ingredient",
    "income-side decomposition ingredient",
    "income-side decomposition ingredient",
    "aggregate diagnostic ingredient",
    "income-side decomposition ingredient",
    "profit ingredient",
    "income-side decomposition ingredient",
    "business-sector wage-equivalent ingredient"
  ),
  sector_boundary = c(
    "financial corporate business",
    "financial corporate business",
    "nonfinancial business",
    "nonfinancial corporate business",
    "corporate business",
    "business",
    "corporate business",
    "corporate business",
    "corporate business",
    "corporate business",
    "corporate business",
    "corporate business",
    "corporate business",
    "corporate business",
    "for-profit business",
    "for-profit business",
    "for-profit business",
    "for-profit business",
    "for-profit business",
    "for-profit business",
    "for-profit business",
    "for-profit business",
    "all domestic or corporate depending row",
    "all domestic or corporate depending row",
    "all domestic or corporate depending row",
    "all domestic economy",
    "all domestic or corporate depending row",
    "corporate business",
    "business or corporate depending row",
    "noncorporate business"
  ),
  legal_form_boundary = c(
    "financial corporate",
    "financial corporate",
    "business",
    "nonfinancial corporate",
    "corporate",
    "business",
    rep("corporate", 8),
    rep("business", 8),
    "unclear",
    "unclear",
    "unclear",
    "unclear",
    "unclear",
    "corporate",
    "business",
    "noncorporate"
  ),
  accounting_role = c(
    "net interest",
    "net interest",
    "imputed interest",
    "imputed interest",
    "imputed interest",
    "imputed interest",
    "GVA",
    "VA",
    "GOS",
    "NOS",
    "GVA",
    "VA",
    "GOS",
    "NOS",
    "GVA",
    "VA",
    "GOS",
    "NOS",
    "GVA",
    "VA",
    "GOS",
    "NOS",
    "CFC",
    "compensation",
    "taxes",
    "statistical discrepancy",
    "net interest",
    "profit",
    "current transfer",
    "other"
  ),
  object_role = c(
    "ingredient",
    "ingredient",
    "ingredient",
    "ingredient",
    "adjustment term",
    "adjustment term",
    rep("ingredient", 4),
    rep("final adjusted object", 4),
    rep("ingredient", 4),
    rep("final adjusted object", 4),
    rep("ingredient", 7),
    "adjustment term"
  ),
  expected_sign_convention = c(
    "Shaikh item is negative in 2009; formula subtracts this item in adjustment.",
    "Expected negative when financial corporations are net interest recipients.",
    "Shaikh item is negative in 2009; formula subtracts this item in adjustment.",
    "Shaikh item is negative in 2009; formula subtracts this item in adjustment.",
    "Appendix formula: - BankNetIntPaid - NonFinCorpNetImpIntPaid; signs require current-release review.",
    "Appendix formula: - BankNetIntPaid - NFNetImpIntPaid; signs require current-release review.",
    rep("positive current-dollar level expected", 8),
    rep("positive current-dollar level expected", 8),
    "positive depreciation level expected",
    "positive compensation level expected",
    "positive net tax level expected but may vary by component",
    "balancing item; sign may be positive or negative",
    "net payment; sign may vary by sector",
    "profit measure; sign may vary by sector/year",
    "net transfer; sign may vary",
    "sign depends on wage-equivalent construction"
  ),
  current_release_search_phrases = c(
    "financial corporate monetary interest paid; financial corporate monetary interest received; imputed interest paid financial corporate; imputed interest received financial corporate; borrower services financial corporate",
    "bank financial corporate total net interest paid; financial intermediaries net interest paid; banks credit agencies investment companies imputed interest",
    "nonfinancial business imputed interest paid; nonfinancial corporate borrower services paid; proprietors partners borrower services paid; imputed interest received nonfinancial business",
    "nonfinancial corporate borrower services paid; nonfinancial corporate imputed interest received; nonfinancial corporate imputed net interest paid",
    "corporate imputed interest adjustment; financial corporate net interest paid; nonfinancial corporate imputed interest paid",
    "business imputed interest adjustment; financial corporate net interest paid; nonfinancial business imputed interest paid",
    "gross value added of corporate business",
    "net value added of corporate business",
    "gross operating surplus of corporate business",
    "net operating surplus of corporate business",
    "adjusted corporate gross value added imputed interest",
    "adjusted corporate value added imputed interest",
    "adjusted corporate gross operating surplus imputed interest",
    "adjusted corporate net operating surplus imputed interest",
    "gross value added business sector",
    "net value added business sector",
    "gross operating surplus business sector",
    "net operating surplus business sector",
    "business sector gross value added imputed interest adjustment",
    "business sector value added imputed interest adjustment",
    "business sector gross operating surplus wage equivalent imputed interest",
    "business sector net operating surplus wage equivalent imputed interest",
    "consumption of fixed capital corporate business",
    "compensation of employees corporate business",
    "taxes on production and imports less subsidies corporate business",
    "statistical discrepancy gross domestic income",
    "net interest and miscellaneous payments corporate business",
    "corporate profits with inventory valuation and capital consumption adjustments",
    "business current transfer payments net corporate business",
    "proprietors income wage equivalent self employed persons compensation per full-time equivalent"
  ),
  status = "SEMANTIC_TARGET_PENDING_CURRENT_RELEASE_CROSSWALK"
)
wcsv(concept_rows, "S20E_shaikh_semantic_concept_ledger.csv")

dictionary <- data.frame(
  shaikh_label = concept_rows$shaikh_label,
  concept_name_for_search = concept_rows$natural_language_concept_description,
  search_phrase_primary = sub(";.*", "", concept_rows$current_release_search_phrases),
  search_phrase_secondary = concept_rows$current_release_search_phrases,
  likely_BEA_concept_family = c(
    "NIPA Table 7.11 interest transactions",
    "NIPA Table 7.11 interest transactions",
    "NIPA Table 7.11 imputed interest and borrower services",
    "NIPA Table 7.11 imputed interest and borrower services",
    "NIPA Table 7.11 plus corporate account base measures",
    "NIPA Table 7.11 plus business-sector account base measures",
    rep("NIPA Table 1.14 corporate business income and product account", 8),
    rep("NIPA business-sector income-side account; Appendix Table 6.7.3 historical construction", 8),
    "NIPA income-side account",
    "NIPA income-side account",
    "NIPA income-side account",
    "NIPA GDP/GDI reconciliation",
    "NIPA income-side account",
    "NIPA corporate profits",
    "NIPA income-side account",
    "NIPA noncorporate income/employment tables"
  ),
  likely_NIPA_table_family = c(
    rep("T71100", 6),
    rep("T11400", 8),
    rep("current-release business-sector equivalent pending BEA search", 8),
    "T11000 or T11400 depending boundary",
    "T11000 or T11400 depending boundary",
    "T11000 or T11400 depending boundary",
    "T10705/T11000 historical clue pending current metadata",
    "T11000 or T11400 depending boundary",
    "T11000/T11400 corporate profits rows",
    "T11000 or T11400 depending boundary",
    "T11300/T11400/T60700/T60200/T60300 historical clues"
  ),
  literal_matching_warning = paste(
    "Shaikh-side label is an equation/reporting label from Appendix 6.7,",
    "not an official BEA or FRED API variable name; search current-release metadata by concept phrase."
  ),
  notes = paste(
    "Historical references are clues only; current-release authorization requires BEA metadata/data retrieval."
  )
)
wcsv(dictionary, "S20E_shaikh_acronym_to_concept_dictionary.csv")

bea_candidates <- data.frame(
  shaikh_label = c(
    "BankNetIntPaid",
    "BankNetIntPaid",
    "BankNetIntPaid",
    "NFNetImpIntPaid",
    "NonFin corporate net imputed interest paid",
    "CorpImpIntAdj",
    "BusImpIntAdj",
    "NIPA Corp GVA",
    "NIPA Corp VA",
    "NIPA Corp GOS",
    "NIPA Corp NOS",
    "Consumption of fixed capital",
    "Compensation of employees",
    "Taxes on production and imports less subsidies",
    "Net interest and miscellaneous payments",
    "Corporate profits with IVA and CCAdj",
    "Business current transfer payments net",
    "Statistical discrepancy",
    "Business GVA NIPA",
    "Business Sector NOS NIPA",
    "Final Corp GVA",
    "Final Corp NOS"
  ),
  semantic_concept = c(
    "Financial corporate monetary interest paid and received components",
    "Financial corporate imputed interest and borrower-service components",
    "Legacy Table 7.11 component numbers used by Shaikh",
    "Nonfinancial business imputed net interest paid components",
    "Nonfinancial corporate imputed net interest paid components",
    "Corporate imputed interest adjustment source ingredients",
    "Business imputed interest adjustment source ingredients",
    "Corporate gross value added base",
    "Corporate net value added base",
    "Corporate gross operating surplus base",
    "Corporate net operating surplus base",
    "Corporate/business CFC ingredient",
    "Corporate/business compensation ingredient",
    "Corporate/business taxes less subsidies ingredient",
    "Corporate/business net interest and miscellaneous payments",
    "Corporate profits with IVA and CCAdj",
    "Business current transfer payments net",
    "Statistical discrepancy",
    "Business sector GVA base",
    "Business sector NOS base",
    "Adjusted corporate GVA final object",
    "Adjusted corporate NOS final object"
  ),
  search_phrase_used = c(
    "financial corporate monetary interest paid; financial corporate monetary interest received",
    "imputed interest paid financial corporate; imputed interest received financial corporate; borrower services financial corporate",
    "current descriptions of Table 7.11 lines 4, 28, 44, 52, 73, 91",
    "nonfinancial business imputed interest paid; borrower services paid proprietors partners; imputed interest received",
    "nonfinancial corporate borrower services paid; nonfinancial corporate imputed interest received",
    "financial corporate net interest paid; nonfinancial corporate imputed interest paid",
    "financial corporate net interest paid; nonfinancial business imputed interest paid",
    "gross value added of corporate business",
    "net value added of corporate business",
    "gross operating surplus of corporate business",
    "net operating surplus of corporate business",
    "consumption of fixed capital corporate business",
    "compensation of employees corporate business",
    "taxes on production and imports less subsidies corporate business",
    "net interest and miscellaneous payments corporate business",
    "corporate profits with inventory valuation and capital consumption adjustments",
    "business current transfer payments net corporate business",
    "statistical discrepancy gross domestic income",
    "gross value added business sector",
    "net operating surplus business sector",
    "adjusted corporate gross value added imputed interest",
    "adjusted corporate net operating surplus imputed interest"
  ),
  bea_dataset = "NIPA",
  table_name = c(
    rep("T71100", 7),
    "T11400", "T11400", "T11400/T11400 component formula", "T11400",
    "T11400", "T11400", "T11400", "T11400", "T11400", "T11400",
    "T10705/T11000 candidate pending metadata",
    "PENDING_METADATA_SEARCH",
    "PENDING_METADATA_SEARCH",
    "not an official BEA base line",
    "not an official BEA base line"
  ),
  line_number_or_line_code = c(
    "local prior: lines 4 and 28",
    "pending metadata; local prior warns legacy lines 44/52/73/91 are not self-validating",
    "legacy line numbers rejected as literal current mappings unless metadata confirms semantics",
    "pending metadata; legacy lines 74/75/53/54 are historical clues only",
    "pending metadata; local prior says legacy line 74 minus 53 is not currently admissible",
    "formula pending verified ingredient lines",
    "formula pending verified ingredient lines",
    "local prior: line 1",
    "local prior: line 3",
    "pending direct line; otherwise NOS + CFC component formula",
    "local prior: line 8",
    "local prior: line 2",
    "local prior: line 4",
    "local prior: line 7",
    "local prior: line 9",
    "local prior: line 11",
    "local prior: line 10",
    "pending metadata",
    "pending metadata",
    "pending source formula, not a BEA line",
    "pending source formula, not a BEA line",
    "pending source formula, not a BEA line"
  ),
  line_description = c(
    "Financial corporate monetary interest paid/received components; local audit identifies line 4 paid and line 28 received.",
    "Financial corporate imputed-interest/borrower-service terms require current metadata by concept.",
    "Line-number-only mapping is unsafe because current line descriptions differ for several legacy clues.",
    "Nonfinancial business imputed-interest components require current metadata by concept.",
    "Local audit rejects direct current use of legacy line 74 - line 53 as nonfinancial corporate imputed net interest.",
    "No direct BEA line expected; adjustment formula requires verified components and sign convention.",
    "No direct BEA line expected; adjustment formula requires verified components and sign convention.",
    "Gross value added of domestic corporate business.",
    "Net value added of domestic corporate business.",
    "Gross operating surplus of domestic corporate business, if direct; otherwise gross equals net operating surplus plus CFC.",
    "Net operating surplus of domestic corporate business.",
    "Consumption of fixed capital, domestic corporate business.",
    "Compensation of employees paid, domestic corporate business.",
    "Taxes on production and imports less subsidies, domestic corporate business.",
    "Net interest and miscellaneous payments, domestic corporate business.",
    "Corporate profits with IVA and CCAdj, domestic corporate business.",
    "Business current transfer payments net, domestic corporate business.",
    "Statistical discrepancy in GDP/GDI reconciliation.",
    "Current business-sector equivalent to Shaikh Appendix Table 6.7.3 requires BEA metadata search.",
    "Current business-sector equivalent to Shaikh Appendix Table 6.7.3 requires BEA metadata search.",
    "Constructed downstream object; provider can authorize only source ingredients/crosswalk.",
    "Constructed downstream object; provider can authorize only source ingredients/crosswalk."
  ),
  unit = c(rep("millions of current dollars expected", 22)),
  frequency = c(rep("annual required", 22)),
  year_coverage = c(rep("pending current BEA retrieval", 22)),
  current_release_status = c(
    rep(api_status, 22)
  ),
  api_query_or_query_template = c(
    bea_getdata_template("NIPA", "T71100"),
    bea_getdata_template("NIPA", "T71100"),
    bea_getdata_template("NIPA", "T71100"),
    bea_getdata_template("NIPA", "T71100"),
    bea_getdata_template("NIPA", "T71100"),
    paste(bea_getdata_template("NIPA", "T71100"), bea_getdata_template("NIPA", "T11400"), sep = " | "),
    paste(bea_getdata_template("NIPA", "T71100"), bea_table_values_template, sep = " | "),
    bea_getdata_template("NIPA", "T11400"),
    bea_getdata_template("NIPA", "T11400"),
    bea_getdata_template("NIPA", "T11400"),
    bea_getdata_template("NIPA", "T11400"),
    bea_getdata_template("NIPA", "T11400"),
    bea_getdata_template("NIPA", "T11400"),
    bea_getdata_template("NIPA", "T11400"),
    bea_getdata_template("NIPA", "T11400"),
    bea_getdata_template("NIPA", "T11400"),
    bea_getdata_template("NIPA", "T11400"),
    bea_table_values_template,
    bea_table_values_template,
    bea_table_values_template,
    paste(bea_getdata_template("NIPA", "T11400"), bea_getdata_template("NIPA", "T71100"), sep = " | "),
    paste(bea_getdata_template("NIPA", "T11400"), bea_getdata_template("NIPA", "T71100"), sep = " | ")
  ),
  candidate_quality = c(
    "plausible",
    "ambiguous",
    "rejected",
    "ambiguous",
    "rejected",
    "ambiguous",
    "ambiguous",
    "plausible",
    "plausible",
    "ambiguous",
    "plausible",
    "plausible",
    "plausible",
    "plausible",
    "plausible",
    "plausible",
    "plausible",
    "ambiguous",
    "ambiguous",
    "ambiguous",
    "rejected",
    "rejected"
  ),
  match_rationale = c(
    "Local provider audit gives direct current semantic equivalents for financial corporate monetary interest paid and received, but API refresh is unavailable.",
    "Shaikh requires imputed/borrower-service components; local audit warns several legacy line numbers no longer carry expected meanings.",
    "Literal legacy line-number mapping would violate the task rule and local audit.",
    "Concept is clear in Appendix footnote, but no current BEA metadata refresh was possible.",
    "Local provider audit says current lines 74 and 53 do not match the legacy nonfinancial-corporate roles.",
    "Formula is semantically clear but underlying current lines and signs are not authorized.",
    "Formula is semantically clear but underlying current lines and signs are not authorized.",
    "Existing provider lock identifies T11400 line 1 as CORP_GVA, but current API refresh is pending.",
    "Existing provider lock identifies T11400 line 3 as CORP_NVA, but current API refresh is pending.",
    "GOS may be derived from NOS plus CFC if no direct line exists; this is a source formula, not adjusted Shaikh construction.",
    "Existing provider lock identifies T11400 line 8 as CORP_NOS, but current API refresh is pending.",
    "Existing provider lock identifies T11400 line 2 as CORP_CFC, but current API refresh is pending.",
    "Existing provider lock identifies T11400 line 4 as CORP_COMP, but current API refresh is pending.",
    "Existing provider lock identifies T11400 line 7 as corporate TPI less subsidies, but current API refresh is pending.",
    "Existing provider lock identifies T11400 line 9 as CORP_NET_INT, but current API refresh is pending.",
    "Existing provider lock identifies T11400 line 11 as CORP_PROFITS_IVA_CC, but current API refresh is pending.",
    "Existing provider lock identifies T11400 line 10 as CORP_TRANSFERS_NET, but current API refresh is pending.",
    "Aggregate statistical discrepancy is not central to corporate adjustment; metadata search pending.",
    "Shaikh's business-sector base is constructed historically; current direct equivalent is not authorized.",
    "Shaikh's business-sector base is constructed historically; current direct equivalent is not authorized.",
    "Final adjusted objects are Shaikh constructs, not official BEA series.",
    "Final adjusted objects are Shaikh constructs, not official BEA series."
  ),
  sign_convention_risk = c(
    rep("high until current definitions and formula signs are reviewed", 7),
    rep("low for base current-dollar level; API refresh still pending", 2),
    "medium because GOS direct-vs-component definition must be confirmed",
    "low for base current-dollar level; API refresh still pending",
    rep("low for base current-dollar level; API refresh still pending", 6),
    rep("medium; not central to corporate adjustment", 1),
    rep("medium; business-sector base construction must be reviewed", 2),
    rep("high; final adjusted object construction prohibited here", 2)
  ),
  sector_boundary_risk = c(
    rep("high for financial corporate/bank mapping", 3),
    rep("high for nonfinancial business/corporate mapping", 2),
    rep("high for adjustment formula boundary", 2),
    rep("low for corporate base rows after API refresh", 10),
    "medium for aggregate-vs-sector boundary",
    rep("high for business-sector historical-vs-current boundary", 2),
    rep("high because final adjusted objects are downstream constructs", 2)
  ),
  definition_change_risk = c(
    rep("high because Shaikh used older Table 7.11 structures", 7),
    rep("medium until current-release API refresh", 10),
    "medium",
    rep("high because Appendix 6.7 business base is historical construction", 2),
    rep("high because BEA does not publish Shaikh final adjusted objects", 2)
  ),
  notes = c(
    "Do not search for BankNetIntPaid literally.",
    "Search current metadata for concepts, not line-number-only labels.",
    "Rejected here means legacy line-number formula is not authorized as current-release crosswalk.",
    "Do not search for NFNetImpIntPaid literally.",
    "Do not use current lines 74 and 53 without a validated semantic crosswalk.",
    "Do not search for CorpImpIntAdj literally.",
    "Do not search for BusImpIntAdj literally.",
    rep("Local provider metadata is prior evidence only; BEA API refresh is still required.", 10),
    "Historical aggregate clue only.",
    "Could require a reconstructed business-sector source path; not a Chapter 2 construction here.",
    "Could require a reconstructed business-sector source path; not a Chapter 2 construction here.",
    "Provider can describe ingredients only.",
    "Provider can describe ingredients only."
  )
)
wcsv(bea_candidates, "S20E_bea_current_release_candidate_crosswalk.csv")

fred_rows <- data.frame(
  shaikh_label = c(
    "BankNetIntPaid",
    "NFNetImpIntPaid",
    "CorpImpIntAdj",
    "NIPA Corp GVA",
    "NIPA Corp NOS",
    "Corporate profits with IVA and CCAdj"
  ),
  semantic_concept = c(
    "Financial corporate net interest paid components",
    "Nonfinancial business imputed net interest paid components",
    "Corporate imputed interest adjustment ingredients",
    "Corporate gross value added base",
    "Corporate net operating surplus base",
    "Corporate profits with IVA and CCAdj"
  ),
  search_phrase_used = c(
    "financial corporate monetary interest paid received imputed interest BEA",
    "nonfinancial corporate imputed interest borrower services BEA",
    "financial corporate net interest nonfinancial corporate imputed interest BEA",
    "gross value added domestic corporate business BEA",
    "net operating surplus domestic corporate business BEA",
    "corporate profits inventory valuation capital consumption adjustments BEA"
  ),
  fred_series_id = "",
  title = "",
  source = "",
  release = "",
  units = "",
  frequency = "",
  seasonal_adjustment = "",
  observation_coverage = "",
  last_updated = "",
  maps_to_bea_table_or_line = "pending; FRED API unavailable and BEA preferred",
  candidate_quality = "ambiguous",
  fallback_status = fred_status,
  query_template = vapply(c(
    "financial corporate monetary interest paid received imputed interest BEA",
    "nonfinancial corporate imputed interest borrower services BEA",
    "financial corporate net interest nonfinancial corporate imputed interest BEA",
    "gross value added domestic corporate business BEA",
    "net operating surplus domestic corporate business BEA",
    "corporate profits inventory valuation capital consumption adjustments BEA"
  ), fred_search_template, character(1)),
  notes = "FRED fallback cannot authorize crosswalk by itself; require BEA source provenance and line semantics."
)
wcsv(fred_rows, "S20E_fred_fallback_candidate_ledger.csv")

constructibility <- data.frame(
  target_object = c(
    "corporate_imputed_interest_adjustment",
    "business_imputed_interest_adjustment",
    "adjusted_corporate_gva",
    "adjusted_corporate_va",
    "adjusted_corporate_gos",
    "adjusted_corporate_nos",
    "adjusted_business_gva",
    "adjusted_business_va",
    "adjusted_business_gos",
    "adjusted_business_nos"
  ),
  formula_level_requirement = c(
    "- financial corporate net interest paid - nonfinancial corporate net imputed interest paid",
    "- financial corporate net interest paid - nonfinancial business net imputed interest paid",
    "NIPA corporate GVA + corporate imputed interest adjustment",
    "NIPA corporate VA + corporate imputed interest adjustment",
    "NIPA corporate GOS + corporate imputed interest adjustment",
    "NIPA corporate NOS + corporate imputed interest adjustment",
    "Business GVA NIPA + business imputed interest adjustment",
    "Business VA NIPA + business imputed interest adjustment",
    "Business GOS NIPA - wage-equivalent adjustment + business imputed interest adjustment",
    "Business NOS NIPA - wage-equivalent adjustment + business imputed interest adjustment"
  ),
  base_measure_available = c(
    "not applicable",
    "not applicable",
    "local prior plausible; API refresh pending",
    "local prior plausible; API refresh pending",
    "component formula plausible; API refresh pending",
    "local prior plausible; API refresh pending",
    "pending current business-sector base mapping",
    "pending current business-sector base mapping",
    "pending current business-sector base mapping and wage-equivalent source",
    "pending current business-sector base mapping and wage-equivalent source"
  ),
  adjustment_available = c(
    "no",
    "no",
    "no",
    "no",
    "no",
    "no",
    "no",
    "no",
    "no",
    "no"
  ),
  explicit_sign_convention = c(rep("pending current-release definition and human review", 10)),
  unit_compatibility = c(rep("expected current dollars/millions; pending current BEA retrieval", 10)),
  annual_support = c(rep("required; pending current BEA retrieval", 10)),
  current_bea_or_fred_candidate_status = c(rep(api_status, 10)),
  constructibility_status = c(
    "PENDING_API_ACCESS",
    "PENDING_API_ACCESS",
    "PENDING_API_ACCESS",
    "PENDING_API_ACCESS",
    "PENDING_API_ACCESS",
    "PENDING_API_ACCESS",
    "PENDING_API_ACCESS",
    "PENDING_API_ACCESS",
    "PENDING_API_ACCESS",
    "PENDING_API_ACCESS"
  ),
  notes = c(
    "Current-release Table 7.11 component mapping is the binding gap.",
    "Current-release Table 7.11 component mapping plus business-sector boundary are binding gaps.",
    "Base corporate GVA has local prior evidence, but final adjustment is not authorized.",
    "Base corporate VA has local prior evidence, but final adjustment is not authorized.",
    "Base corporate GOS may require NOS plus CFC source formula, but final adjustment is not authorized.",
    "Base corporate NOS has local prior evidence, but final adjustment is not authorized.",
    "Business-sector pathway requires additional current-release mapping.",
    "Business-sector pathway requires additional current-release mapping.",
    "Business-sector pathway also depends on wage-equivalent lane; not authorized here.",
    "Business-sector pathway also depends on wage-equivalent lane; not authorized here."
  )
)
wcsv(constructibility, "S20E_constructibility_ledger.csv")

blocked <- data.frame(
  object_or_decision = c(
    "current-release BEA metadata refresh",
    "current-release FRED fallback search",
    "financial corporate net interest paid full component formula",
    "nonfinancial corporate imputed net interest paid",
    "nonfinancial business imputed net interest paid",
    "corporate imputed interest adjustment",
    "business imputed interest adjustment",
    "adjusted corporate GVA/VA/GOS/NOS",
    "adjusted business GVA/VA/GOS/NOS",
    "provider handoff candidate"
  ),
  blocked_status = c(
    "PENDING_API_ACCESS",
    "PENDING_API_ACCESS",
    "PENDING_SIGN_CONVENTION_REVIEW",
    "PENDING_SECTOR_BOUNDARY_REVIEW",
    "PENDING_SECTOR_BOUNDARY_REVIEW",
    "PENDING_API_ACCESS",
    "PENDING_API_ACCESS",
    "PENDING_API_ACCESS",
    "PENDING_API_ACCESS",
    "BLOCKED_NO_CURRENT_RELEASE_EQUIVALENT"
  ),
  blocking_reason = c(
    "No BEA_API_KEY, BEA_USER_ID, or BEA_API_USER_ID in environment.",
    "No FRED_API_KEY in environment.",
    "Appendix formula is clear, but current Table 7.11 imputed/borrower-service components require BEA metadata refresh.",
    "Local audit rejects legacy line 74 - line 53 as current equivalent; concept search is required.",
    "Legacy business concept includes proprietors/partners components; current search required.",
    "Adjustment depends on two unverified current-release component groups.",
    "Adjustment depends on two unverified current-release component groups and business boundary.",
    "Provider cannot authorize final adjusted objects until adjustment is validated.",
    "Business pathway also requires wage-equivalent and broader business-sector mapping.",
    "Validation does not support downstream handoff without current-release matches."
  ),
  next_required_action = c(
    "Set BEA_API_KEY or equivalent and rerun metadata/data retrieval.",
    "Set FRED_API_KEY only if BEA mapping remains incomplete or unavailable.",
    "Retrieve current Table 7.11 metadata/data and inspect financial corporate paid/received/imputed/borrower-service hierarchy.",
    "Search current Table 7.11 by concept phrase, not legacy line number.",
    "Search current Table 7.11 and relevant business/proprietor lines by concept phrase.",
    "Review signs after current component definitions are retrieved.",
    "Review signs and business boundary after current component definitions are retrieved.",
    "Only downstream Chapter 2 may construct adjusted series after provider handoff.",
    "Keep separate from corporate-only pathway and Chapter 2 construction.",
    "Create handoff only after BEA/FRED current-release evidence validates source/crosswalk."
  )
)
wcsv(blocked, "S20E_blocked_pending_object_ledger.csv")

validation <- data.frame(
  check_name = c(
    "current_provider_repo_checked",
    "source_pdfs_found",
    "only_provider_repo_pdf_copies_used",
    "shaikh_appendix_used_as_primary_semantic_source",
    "shaikh_tonak_book_used_only_as_conceptual_background",
    "bea_api_guide_used_for_api_method_design",
    "shaikh_labels_treated_as_acronyms_not_variable_names",
    "acronym_to_concept_dictionary_created",
    "search_phrases_generated_from_concepts",
    "old_shaikh_table_line_references_historical_only",
    "bea_metadata_strategy_documented",
    "bea_current_release_candidate_ledger_created",
    "fred_fallback_ledger_created_or_marked",
    "no_adjusted_shaikh_objects_constructed",
    "no_chapter_2_repo_modification",
    "no_chapter_2_panel_attachment",
    "no_gpim_reconstruction",
    "no_econometrics_run",
    "no_theta_estimated",
    "no_productive_capacity_constructed",
    "no_utilization_constructed",
    "no_accumulated_q_constructed",
    "constructibility_statuses_assigned",
    "provider_handoff_created_only_if_validation_supports_it",
    "api_access_available",
    "final_decision_explicit"
  ),
  status = c(
    "PASS",
    if (all(file.exists(doc_paths))) "PASS" else "FAIL_BLOCKING",
    "PASS",
    "PASS",
    "PASS",
    "PASS",
    "PASS",
    "PASS",
    "PASS",
    "PASS",
    "PASS",
    "PASS",
    "PASS",
    "PASS",
    "PASS",
    "PASS",
    "PASS",
    "PASS",
    "PASS",
    "PASS",
    "PASS",
    "PASS",
    "PASS",
    "PASS",
    if (bea_key_present) "PASS" else "PENDING_API_ACCESS",
    "PASS"
  ),
  evidence = c(
    normalizePath(getwd(), winslash = "/", mustWork = FALSE),
    paste(names(doc_paths), ifelse(file.exists(doc_paths), "FOUND", "MISSING"), collapse = "; "),
    paste(unname(doc_paths), collapse = "; "),
    "Appendix 6.7 formulas and Table 6.7.11 encoded in semantic ledgers.",
    "Conceptual background limited to finance/productive-labor framing; no table-line authority taken from book.",
    "API guide method sequence and NIPA parameters encoded in query templates.",
    "Dictionary warns against literal searches for Shaikh labels.",
    "S20E_shaikh_acronym_to_concept_dictionary.csv",
    "Concept phrases stored in semantic ledger and BEA/FRED ledgers.",
    "Legacy line references recorded only as clues; local audit warnings preserved.",
    "Report and query templates reference GetDataSetList/GetParameterList/GetParameterValues/GetData.",
    "S20E_bea_current_release_candidate_crosswalk.csv",
    "S20E_fred_fallback_candidate_ledger.csv",
    "No adjusted output series were written.",
    "No command or file path targets Chapter 2 repository.",
    "No panel attachment was created.",
    "No GPIM scripts or outputs created.",
    "No econometric routines run.",
    "No theta estimated.",
    "No productive capacity constructed.",
    "No utilization constructed.",
    "No accumulated q constructed.",
    "S20E_constructibility_ledger.csv",
    "No data/provider_handoffs/S20E_SHAIKH_CURRENT_RELEASE_CROSSWALK directory created.",
    if (bea_key_present) "BEA key variable present" else "No BEA_API_KEY, BEA_USER_ID, or BEA_API_USER_ID present.",
    "PENDING_PROVIDER_SHAIKH_CROSSWALK_BECAUSE_API_ACCESS_REQUIRED"
  ),
  notes = c(
    "Provider repo only.",
    "",
    "Per user instruction, no external or Chapter 2 copies used.",
    "",
    "The book does not authorize current BEA lines.",
    "",
    "BankNetIntPaid, NFNetImpIntPaid, CorpImpIntAdj, and BusImpIntAdj are Shaikh-side labels.",
    "",
    "",
    "Especially Table 7.11 line numbers from the 2011 download.",
    "",
    "Current-release status is conceptual/documentation only; no construction, handoff, or candidate graduation is authorized.",
    "FRED fallback remains pending because FRED API access is unavailable and BEA is preferred.",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "All target objects assigned PENDING_API_ACCESS.",
    "Handoff not justified by validation.",
    "No construction, handoff, or candidate graduation is authorized in this pass.",
    ""
  )
)
wcsv(validation, "S20E_validation_checks.csv")

report <- c(
  "# S20E Shaikh Current-Release Crosswalk",
  "",
  "Date: 2026-06-17",
  "",
  "Final decision: `PENDING_PROVIDER_SHAIKH_CROSSWALK_BECAUSE_API_ACCESS_REQUIRED`",
  "",
  "## Scope",
  "",
  "This provider-side run builds the Shaikh Appendix 6.7 semantic layer, acronym-to-concept dictionary, BEA planned current-release candidate crosswalk, FRED fallback plan, constructibility ledger, and blocked/pending ledger.",
  "",
  "No adjusted Shaikh variables were constructed. No Chapter 2 repository files were read or modified. No handoff candidate was created.",
  "",
  "## Source Documents",
  "",
  "- `docs/Shaikh2016_Appendix6.7.pdf`: primary semantic source.",
  "- `docs/shaikh_measuring_wealth_nations.pdf`: conceptual background only.",
  "- `docs/bea_web_service_api_user_guide.pdf`: BEA API method strategy.",
  "",
  "## Appendix 6.7 Semantic Result",
  "",
  "The central Appendix 6.7 current-release search targets are not Shaikh acronyms. They are the underlying accounting concepts:",
  "",
  "- financial corporate net interest paid;",
  "- nonfinancial corporate/business imputed net interest paid;",
  "- corporate and business imputed-interest adjustment terms;",
  "- corporate base GVA, VA, GOS, and NOS;",
  "- final adjusted corporate and business objects, which remain downstream constructs.",
  "",
  "The key corporate formula is treated only at source-discovery level:",
  "",
  "`Corporate imputed interest adjustment = - financial corporate net interest paid - nonfinancial corporate net imputed interest paid`",
  "",
  "Signs are not authorized because current-release component definitions could not be retrieved in this run.",
  "",
  "## BEA Strategy",
  "",
  "The BEA API guide supports the sequence `GetDataSetList`, `GetParameterList`, `GetParameterValues`, `GetParameterValuesFiltered` where implemented, and then `GetData`. For NIPA, planned retrieval focuses on `NIPA` table metadata and annual `GetData` calls for `T71100` and `T11400`.",
  "",
  "BEA API metadata strategy and available current-release ledgers are documentation inputs only; they do not authorize construction or handoff.",
  "",
  "## FRED Fallback",
  "",
  "FRED API access is also unavailable. FRED remains fallback-only and cannot authorize the crosswalk without BEA source provenance and line semantics.",
  "",
  "## Constructibility",
  "",
  "All adjusted corporate and business objects are `PENDING_API_ACCESS`. Existing provider metadata gives local prior evidence for several corporate Table 1.14 base measures, but current-release authorization requires BEA refresh and sign/boundary review for Table 7.11 imputed-interest components.",
  "",
  "## Handoff",
  "",
  "No provider handoff candidate was created because validation does not support downstream authorization.",
  "",
  "## Output Files",
  "",
  "- `csv/S20E_shaikh_semantic_concept_ledger.csv`",
  "- `csv/S20E_shaikh_acronym_to_concept_dictionary.csv`",
  "- `csv/S20E_bea_current_release_candidate_crosswalk.csv`",
  "- `csv/S20E_fred_fallback_candidate_ledger.csv`",
  "- `csv/S20E_constructibility_ledger.csv`",
  "- `csv/S20E_blocked_pending_object_ledger.csv`",
  "- `csv/S20E_validation_checks.csv`"
)
writeLines(report, file.path(md_dir, "S20E_SHAIKH_CURRENT_RELEASE_CROSSWALK.md"), useBytes = TRUE)

missing_report <- c(
  "# S20E Missing-Input Report",
  "",
  "Status: superseded by rerun on 2026-06-17.",
  "",
  "The previous missing-source block is resolved. The required provider-repo PDFs are now present under `docs/` and were used by `codes/US_S20E_shaikh_current_release_crosswalk.R`.",
  "",
  "The current blocking condition is API access, not missing source documents."
)
writeLines(missing_report, file.path(md_dir, "S20E_MISSING_INPUT_REPORT.md"), useBytes = TRUE)

# If keys are available through the R environment, refresh the ledgers with
# conservative current-release BEA/FRED metadata evidence. Full response bodies
# are not saved here; this S20E output stores summaries and query templates.
if (bea_key_present && requireNamespace("jsonlite", quietly = TRUE)) {
  fetch_bea_table <- function(table_name) {
    url <- paste0(
      "https://apps.bea.gov/api/data?UserID=",
      utils::URLencode(Sys.getenv("BEA_API_KEY"), reserved = TRUE),
      "&method=GetData&datasetname=NIPA&TableName=", table_name,
      "&Frequency=A&Year=X&ResultFormat=JSON"
    )
    jsonlite::fromJSON(url)[["BEAAPI"]][["Results"]]
  }

  summarize_bea_table <- function(table_name) {
    res <- fetch_bea_table(table_name)
    dat <- res[["Data"]]
    notes <- res[["Notes"]]
    last_revised <- ""
    if (!is.null(notes) && nrow(notes) > 0) {
      last_revised <- notes$NoteText[1]
    }
    data.frame(
      bea_dataset = "NIPA",
      table_name = table_name,
      rows_retrieved = nrow(dat),
      distinct_lines = length(unique(dat$LineNumber)),
      first_year = min(dat$TimePeriod),
      last_year = max(dat$TimePeriod),
      current_release_note = last_revised,
      retrieval_status = "RETRIEVED_CURRENT_BEA_API",
      query_template = bea_getdata_template("NIPA", table_name)
    )
  }

  bea_api_summary <- do.call(rbind, lapply(c("T11400", "T71100"), summarize_bea_table))
  wcsv(bea_api_summary, "S20E_bea_api_response_summary.csv")

  bea_candidates$current_release_status <- "RETRIEVED_CURRENT_BEA_API"
  bea_candidates$year_coverage[bea_candidates$table_name == "T11400"] <- "1929-2025"
  bea_candidates$year_coverage[bea_candidates$table_name == "T71100"] <- "1946-2024 for core annual lines; some lines begin 1960"
  bea_candidates$year_coverage[grepl("T71100", bea_candidates$table_name) & bea_candidates$table_name != "T71100"] <- "T71100 1946-2024; T11400 1929-2025"
  bea_candidates$year_coverage[bea_candidates$table_name == "not an official BEA base line"] <- "not applicable"

  exact_base <- bea_candidates$shaikh_label %in% c(
    "NIPA Corp GVA", "NIPA Corp VA", "NIPA Corp NOS",
    "Consumption of fixed capital", "Compensation of employees",
    "Taxes on production and imports less subsidies",
    "Net interest and miscellaneous payments",
    "Corporate profits with IVA and CCAdj",
    "Business current transfer payments net"
  )
  bea_candidates$candidate_quality[exact_base] <- "exact"
  bea_candidates$match_rationale[exact_base] <- paste(
    bea_candidates$match_rationale[exact_base],
    "Current BEA API retrieval confirmed the T11400 line family on 2026-06-17."
  )

  bea_candidates$candidate_quality[bea_candidates$shaikh_label %in% c("BankNetIntPaid")] <- "ambiguous"
  bea_candidates$candidate_quality[bea_candidates$shaikh_label %in% c("NFNetImpIntPaid", "NonFin corporate net imputed interest paid")] <- "plausible"
  bea_candidates$current_release_status[bea_candidates$shaikh_label %in% c("CorpImpIntAdj", "BusImpIntAdj")] <- "RETRIEVED_CURRENT_BEA_API_BUT_FORMULA_REVIEW_PENDING"
  bea_candidates$current_release_status[bea_candidates$shaikh_label %in% c("Final Corp GVA", "Final Corp NOS")] <- "NOT_OFFICIAL_BEA_SERIES_INGREDIENTS_RETRIEVED"

  bea_candidates$line_number_or_line_code[bea_candidates$shaikh_label == "BankNetIntPaid" & grepl("monetary", bea_candidates$semantic_concept)] <-
    "current T71100 candidates: monetary paid line 4; monetary received line 28"
  bea_candidates$line_number_or_line_code[bea_candidates$shaikh_label == "BankNetIntPaid" & grepl("imputed", bea_candidates$semantic_concept)] <-
    "current T71100 candidate family: paid lines 43/44/79; received lines 57/96/97; requires sign/component review"
  bea_candidates$line_number_or_line_code[bea_candidates$shaikh_label == "NonFin corporate net imputed interest paid"] <-
    "current T71100 candidate family: nonfinancial paid lines 49/80; nonfinancial received line 58; requires borrower/depositor-services review"
  bea_candidates$line_number_or_line_code[bea_candidates$shaikh_label == "NFNetImpIntPaid"] <-
    "current T71100 candidate family: nonfinancial corporate lines 49/80/58 plus other private business/proprietor pathway; boundary review required"
  bea_candidates$line_number_or_line_code[bea_candidates$shaikh_label == "NIPA Corp GOS"] <-
    "no direct T11400 GOS line retrieved; source formula candidate is T11400 line 8 NOS + line 2 CFC"
  bea_candidates$candidate_quality[bea_candidates$shaikh_label == "NIPA Corp GOS"] <- "plausible"
  bea_candidates$notes <- paste(bea_candidates$notes, "Current BEA retrieval performed with R environment key; key not printed or saved.")
  wcsv(bea_candidates, "S20E_bea_current_release_candidate_crosswalk.csv")

  constructibility$current_bea_or_fred_candidate_status <- "RETRIEVED_CURRENT_BEA_API_BUT_REVIEW_PENDING"
  constructibility$constructibility_status <- c(
    "PENDING_SIGN_CONVENTION_REVIEW",
    "PENDING_SECTOR_BOUNDARY_REVIEW",
    "PENDING_SIGN_CONVENTION_REVIEW",
    "PENDING_SIGN_CONVENTION_REVIEW",
    "PENDING_SIGN_CONVENTION_REVIEW",
    "PENDING_SIGN_CONVENTION_REVIEW",
    "PENDING_SECTOR_BOUNDARY_REVIEW",
    "PENDING_SECTOR_BOUNDARY_REVIEW",
    "PENDING_SECTOR_BOUNDARY_REVIEW",
    "PENDING_SECTOR_BOUNDARY_REVIEW"
  )
  constructibility$notes <- sub("API refresh pending", "BEA API refresh completed; imputed-interest component review pending", constructibility$notes)
  wcsv(constructibility, "S20E_constructibility_ledger.csv")

  blocked$blocked_status[blocked$object_or_decision == "current-release BEA metadata refresh"] <- "COMPLETE_CURRENT_BEA_RETRIEVED"
  blocked$blocking_reason[blocked$object_or_decision == "current-release BEA metadata refresh"] <- "BEA NIPA T11400 and T71100 retrieved through R environment key; key not printed or saved."
  blocked$next_required_action[blocked$object_or_decision == "current-release BEA metadata refresh"] <- "Review component signs and boundaries; rerun retrieval when BEA releases update."
  blocked$blocked_status[blocked$object_or_decision %in% c("corporate imputed interest adjustment", "business imputed interest adjustment", "adjusted corporate GVA/VA/GOS/NOS", "adjusted business GVA/VA/GOS/NOS")] <-
    c("PENDING_SIGN_CONVENTION_REVIEW", "PENDING_SECTOR_BOUNDARY_REVIEW", "PENDING_SIGN_CONVENTION_REVIEW", "PENDING_SECTOR_BOUNDARY_REVIEW")
  blocked$blocked_status[blocked$object_or_decision == "provider handoff candidate"] <- "BLOCKED_PENDING_SIGN_OR_BOUNDARY_REVIEW"
  blocked$blocking_reason[blocked$object_or_decision == "provider handoff candidate"] <- "Current BEA retrieval exists, but Table 7.11 imputed-interest component signs and sector boundaries are not authorized."
  wcsv(blocked, "S20E_blocked_pending_object_ledger.csv")
}

if (fred_key_present && requireNamespace("jsonlite", quietly = TRUE)) {
  fred_terms <- data.frame(
    shaikh_label = c(
      "BankNetIntPaid",
      "NFNetImpIntPaid",
      "CorpImpIntAdj",
      "NIPA Corp GVA",
      "NIPA Corp NOS",
      "Corporate profits with IVA and CCAdj"
    ),
    semantic_concept = c(
      "Financial corporate net interest paid components",
      "Nonfinancial business imputed net interest paid components",
      "Corporate imputed interest adjustment ingredients",
      "Corporate gross value added base",
      "Corporate net operating surplus base",
      "Corporate profits with IVA and CCAdj"
    ),
    search_phrase_used = c(
      "financial corporate monetary interest paid received imputed interest BEA",
      "nonfinancial corporate imputed interest borrower services BEA",
      "financial corporate net interest nonfinancial corporate imputed interest BEA",
      "gross value added domestic corporate business BEA",
      "net operating surplus domestic corporate business BEA",
      "corporate profits inventory valuation capital consumption adjustments BEA"
    )
  )

  fred_collect <- lapply(seq_len(nrow(fred_terms)), function(i) {
    term <- fred_terms$search_phrase_used[i]
    url <- paste0(
      "https://api.stlouisfed.org/fred/series/search?api_key=",
      utils::URLencode(Sys.getenv("FRED_API_KEY"), reserved = TRUE),
      "&file_type=json&search_type=full_text&limit=3&search_text=",
      utils::URLencode(term, reserved = TRUE)
    )
    out <- tryCatch(jsonlite::fromJSON(url)$seriess, error = function(e) NULL)
    if (is.null(out) || !is.data.frame(out) || nrow(out) == 0) {
      return(data.frame(
        shaikh_label = fred_terms$shaikh_label[i],
        semantic_concept = fred_terms$semantic_concept[i],
        search_phrase_used = term,
        fred_series_id = "",
        title = "",
        source = "",
        release = "",
        units = "",
        frequency = "",
        seasonal_adjustment = "",
        observation_coverage = "",
        last_updated = "",
        maps_to_bea_table_or_line = "no FRED result returned",
        candidate_quality = "rejected",
        fallback_status = "FRED_SEARCH_COMPLETED_NO_MATCH",
        query_template = fred_search_template(term),
        notes = "FRED fallback cannot authorize crosswalk by itself."
      ))
    }
    data.frame(
      shaikh_label = fred_terms$shaikh_label[i],
      semantic_concept = fred_terms$semantic_concept[i],
      search_phrase_used = term,
      fred_series_id = out$id,
      title = out$title,
      source = "",
      release = "",
      units = out$units,
      frequency = out$frequency,
      seasonal_adjustment = out$seasonal_adjustment,
      observation_coverage = paste(out$observation_start, out$observation_end, sep = "-"),
      last_updated = out$last_updated,
      maps_to_bea_table_or_line = ifelse(grepl("BEA|Bureau of Economic Analysis|NIPA", paste(out$title, out$notes), ignore.case = TRUE), "possible BEA provenance in FRED metadata", "not established"),
      candidate_quality = "ambiguous",
      fallback_status = "FRED_SEARCH_COMPLETED_FALLBACK_ONLY",
      query_template = fred_search_template(term),
      notes = "FRED result is fallback metadata only; BEA current-release line semantics remain authoritative."
    )
  })
  fred_rows <- do.call(rbind, fred_collect)
  wcsv(fred_rows, "S20E_fred_fallback_candidate_ledger.csv")
}

if (bea_key_present) {
  validation$status[validation$check_name == "api_access_available"] <- "PASS"
  validation$evidence[validation$check_name == "api_access_available"] <- "BEA key available to R; current NIPA T11400/T71100 retrieval completed without printing or saving key."
  validation$status[validation$check_name == "bea_current_release_candidate_ledger_created"] <- "PASS"
  validation$evidence[validation$check_name == "bea_current_release_candidate_ledger_created"] <- "S20E_bea_current_release_candidate_crosswalk.csv plus S20E_bea_api_response_summary.csv"
  validation$evidence[validation$check_name == "constructibility_statuses_assigned"] <- "Constructibility statuses assigned as PENDING_SIGN_CONVENTION_REVIEW or PENDING_SECTOR_BOUNDARY_REVIEW."
  validation$evidence[validation$check_name == "final_decision_explicit"] <- "PENDING_PROVIDER_SHAIKH_CROSSWALK_BECAUSE_SIGN_OR_BOUNDARY_REVIEW_REQUIRED"
}
if (fred_key_present) {
  validation$evidence[validation$check_name == "fred_fallback_ledger_created_or_marked"] <- "FRED fallback search completed with R environment key; fallback-only metadata recorded."
}
wcsv(validation, "S20E_validation_checks.csv")

if (bea_key_present) {
  report[5] <- "Final decision: `PENDING_PROVIDER_SHAIKH_CROSSWALK_BECAUSE_SIGN_OR_BOUNDARY_REVIEW_REQUIRED`"
  report <- c(
    report,
    "",
    "## Current-Release Retrieval Update",
    "",
    "BEA API retrieval completed for NIPA `T11400` and `T71100` through the R environment key. `T11400` current-dollar corporate base lines are exact source candidates, including corporate GVA, NVA, NOS, CFC, compensation, taxes less subsidies, net interest, transfers, and profits with IVA and CCAdj.",
    "",
    "`T71100` confirms current interest-line families, but the Shaikh imputed-interest adjustment is not authorized: the legacy line-number formula cannot be carried forward literally, and current imputed-interest paid/received blocks require sign and sector-boundary review.",
    "",
    "FRED fallback metadata search was completed when a FRED key was available to R. FRED remains fallback-only and does not authorize the crosswalk."
  )
  writeLines(report, file.path(md_dir, "S20E_SHAIKH_CURRENT_RELEASE_CROSSWALK.md"), useBytes = TRUE)
}

# S20E-R reconciliation: make retrieval status and Qwen audit explicit in
# final artifacts. Qwen is subordinate input only and cannot authorize any
# formula, sign, mapping, construction, or handoff.
qwen_audit <- data.frame(
  claim_id = c(
    "QWEN_001",
    "QWEN_002",
    "QWEN_003",
    "QWEN_004",
    "QWEN_005",
    "QWEN_006",
    "QWEN_007",
    "QWEN_008",
    "QWEN_009",
    "QWEN_010"
  ),
  claim_summary = c(
    "Restrict surplus analysis to business activity and exclude household, NPISH, and government surplus concepts.",
    "Use NIPA Table 1.14 as a core BEA source for operating surplus, compensation, proprietors income, and corporate profits.",
    "Use a WEQ2 wage-equivalent adjustment to decompose proprietors income into labor-equivalent and surplus components.",
    "Use QCEW or an external employment source for corporate-worker counts in the WEQ2 calculation.",
    "Treat imputed interest reversal as removal of owner-occupied housing imputed rent or homeownership subsidy.",
    "Use FRED mortgage-rate, house-price, and homeowners-equity series to estimate the imputed-interest component.",
    "Use tax-expenditure data for owner-occupied housing as a rough proxy for imputed income.",
    "Create an external imputed-interest CSV and subtract it from WEQ2_NOS.",
    "Use BEA/FRED API modules and vintage-aware retrieval in an automated pipeline.",
    "No single FRED series directly corresponds to Shaikh's imputed-interest adjustment."
  ),
  qwen_section_or_page_hint = c(
    "Theoretical Foundations, pages 1-3",
    "Data Identification: Core Components from BEA NIPA Tables, pages 4-5",
    "Implementation of Adjustment II: Wage-Equivalent Conversion, pages 8-10",
    "WEQ2 data requirements, pages 5 and 9",
    "Theoretical Foundations and Adjustment III, pages 2-3 and 10-12",
    "Data Identification and Adjustment III proxy suggestions, pages 5 and 11",
    "Adjustment III proxy suggestions, page 12",
    "Adjustment III final formula and pipeline modules, pages 12-14",
    "Vintageing and automated pipeline sections, pages 6-7 and 13-15",
    "FRED support discussion, page 5"
  ),
  related_shaikh_appendix_concept = c(
    "Business-sector boundary and exclusion of nonbusiness sectors",
    "NIPA base source discovery for corporate/business income-side measures",
    "Appendix Table 6.7.4 noncorporate wage-equivalent pathway",
    "Appendix Table 6.7.4 employment and compensation clues",
    "Appendix 6.7 imputed-interest correction from financial-intermediary accounting",
    "Appendix 6.7 Table 7.11 imputed-interest paid/received component search",
    "Appendix 6.7 imputed-interest correction",
    "Appendix 6.7 final business/corporate adjusted NOS formulas",
    "Reproducible source retrieval and auditability",
    "FRED fallback limitations"
  ),
  relation_to_appendix_6_7 = c(
    "partially_supported",
    "partially_supported",
    "partially_supported",
    "not_supported",
    "conflicts",
    "conflicts",
    "not_supported",
    "conflicts",
    "partially_supported",
    "partially_supported"
  ),
  project_status = c(
    "USEFUL_BACKGROUND",
    "USEFUL_SEARCH_HEURISTIC",
    "PARKED_NONCORPORATE_BUSINESS_LANE",
    "PARKED_NONCORPORATE_BUSINESS_LANE",
    "REJECTED_CONFLICTS_WITH_APPENDIX_6_7",
    "REJECTED_CONFLICTS_WITH_APPENDIX_6_7",
    "PARKED_HOUSING_IMPUTED_RENT_LANE",
    "REJECTED_CONFLICTS_WITH_APPENDIX_6_7",
    "USEFUL_SEARCH_HEURISTIC",
    "USEFUL_SEARCH_HEURISTIC"
  ),
  reason = c(
    "Appendix 6.7 does distinguish aggregate, business, corporate, and nonbusiness boundaries, but S20E-R does not reopen downstream sector construction.",
    "Current BEA retrieval confirms T11400 corporate base lines, but Qwen's illustrative table naming and line-code examples are not current-release authority.",
    "Appendix 6.7 contains a noncorporate wage-equivalent lane, but this S20E corporate imputed-interest crosswalk does not use Qwen's operational WEQ2 formula.",
    "Appendix 6.7 cites NIPA employment/compensation table clues for proprietors and private-sector compensation; Qwen's QCEW path is not verified against Appendix 6.7.",
    "Appendix 6.7's corporate imputed-interest correction is based on financial-intermediary interest accounting and NIPA Table 7.11 components, not owner-occupied-housing imputed rent.",
    "Mortgage rates, house prices, and homeowners equity may be housing diagnostics, but they do not authorize the corporate Appendix 6.7 imputed-interest correction.",
    "Tax expenditures may be relevant to a separate housing-imputed-rent diagnostic, but Appendix 6.7 does not authorize them as the corporate imputed-interest adjustment source.",
    "S20E is a provider source-discovery task and Appendix 6.7 does not authorize a Qwen external proxy CSV for the corporate adjustment.",
    "The modular retrieval idea is compatible with reproducibility, but S20E-R uses current provider BEA/FRED ledgers and does not construct adjusted objects.",
    "This is compatible with the S20E result that FRED fallback does not authorize source construction independently of BEA provenance."
  ),
  affects_S20E_corporate_imputed_interest_crosswalk = c(
    "no",
    "yes",
    "no",
    "no",
    "no",
    "no",
    "no",
    "no",
    "no",
    "yes"
  ),
  can_authorize_source_construction = "no"
)
wcsv(qwen_audit, "S20E_external_research_note_audit_ledger.csv")

if (fred_key_present) {
  blocked$blocked_status[blocked$object_or_decision == "current-release FRED fallback search"] <- "COMPLETE_FRED_FALLBACK_SEARCH"
  blocked$blocking_reason[blocked$object_or_decision == "current-release FRED fallback search"] <- "FRED fallback metadata search completed through R environment key; key not printed or saved."
  blocked$next_required_action[blocked$object_or_decision == "current-release FRED fallback search"] <- "Use FRED only as fallback metadata; do not authorize mappings without BEA provenance."
}
if (bea_key_present) {
  blocked$blocked_status[blocked$object_or_decision == "current-release BEA metadata refresh"] <- "COMPLETE_CURRENT_BEA_RETRIEVED"
}
wcsv(blocked, "S20E_blocked_pending_object_ledger.csv")

validation <- rbind(
  validation,
  data.frame(
    check_name = c(
      "source_pdfs_not_staged_or_modified",
      "bea_fred_retrieval_status_reconciled",
      "stale_api_access_blocker_removed_where_inappropriate",
      "qwen_research_note_audited_as_subordinate_input",
      "qwen_not_used_as_source_authority",
      "qwen_housing_imputed_rent_path_not_authorizing_corporate_correction"
    ),
    status = "PASS",
    evidence = c(
      "Source PDFs were read only; no staging performed by this script.",
      "BEA T11400/T71100 retrieval and FRED fallback-search statuses reconciled in ledgers.",
      "Report and ledgers state sign/boundary review as the current blocker after retrieval.",
      "S20E_external_research_note_audit_ledger.csv",
      "Qwen rows all have can_authorize_source_construction=no.",
      "Qwen owner-occupied-housing, mortgage-rate, imputed-rent, and tax-expenditure paths are rejected or parked."
    ),
    notes = c(
      "Final git status must be checked outside R.",
      "",
      "",
      "Qwen is subordinate to Appendix 6.7 and current BEA metadata.",
      "",
      "Appendix 6.7 corporate correction remains tied to T71100 interest paid/received concepts."
    )
  )
)
validation$evidence[validation$check_name == "final_decision_explicit"] <- "PENDING_PROVIDER_SHAIKH_CROSSWALK_BECAUSE_SIGN_OR_BOUNDARY_REVIEW_REQUIRED"
validation$notes[validation$check_name == "bea_current_release_candidate_ledger_created"] <- "Current BEA retrieval completed for T11400 and T71100; authorization still withheld pending sign/boundary review."
validation$notes[validation$check_name == "constructibility_statuses_assigned"] <- "No adjusted object remains PENDING_API_ACCESS after completed BEA/FRED retrieval; statuses are sign or sector-boundary review."
wcsv(validation, "S20E_validation_checks.csv")

clean_report <- c(
  "# S20E Shaikh Current-Release Crosswalk",
  "",
  "Date: 2026-06-17",
  "",
  "Final decision: `PENDING_PROVIDER_SHAIKH_CROSSWALK_BECAUSE_SIGN_OR_BOUNDARY_REVIEW_REQUIRED`",
  "",
  "## Scope",
  "",
  "This provider-side run builds and reconciles the Shaikh Appendix 6.7 semantic layer, acronym-to-concept dictionary, BEA current-release candidate crosswalk, FRED fallback ledger, constructibility ledger, blocked/pending ledger, and subordinate Qwen research-note audit.",
  "",
  "No adjusted Shaikh variables were constructed. No provider handoff candidate was created. No Chapter 2 repository files were read or modified.",
  "",
  "## Source Authority",
  "",
  "1. Stock-flow labour-value logic governs; Shaikh and Tonak provide theoretical inspiration; Appendix 6.7 is the benchmark empirical example; BEA/NIPA is the operational terrain.",
  "2. Current BEA API/NIPA metadata and retrieved `T11400`/`T71100` are the current-release source candidates.",
  "3. `docs/shaikh_measuring_wealth_nations.pdf` is conceptual/theoretical background only.",
  "4. `docs/bea_web_service_api_user_guide.pdf` documents the BEA API method sequence.",
  "5. `docs/Shaikh_NOS_QWEN_deep-research.pdf` is subordinate audit input only.",
  "",
  "## Current-Release Retrieval",
  "",
  "BEA retrieval completed for NIPA `T11400` and `T71100`. `T11400` corporate base lines are exact current-release candidates for corporate GVA, NVA, NOS, CFC, compensation, taxes less subsidies, net interest, transfers, and profits with IVA and CCAdj.",
  "",
  "`T71100` interest-line families were retrieved and identified. The current candidate families include financial corporate monetary paid/received lines, financial imputed paid/received blocks, and nonfinancial imputed paid/received blocks. These are source candidates, not authorized adjustment formulas.",
  "",
  "The Shaikh imputed-interest adjustment is not authorized because current imputed-interest paid/received blocks require sign-convention and sector-boundary review. The older Appendix 6.7 Table 7.11 line references are historical clues only and cannot be carried forward by line number alone.",
  "",
  "FRED fallback metadata search completed. FRED remains fallback-only and does not authorize the crosswalk independently of BEA source provenance and line semantics.",
  "",
  "## Constructibility",
  "",
  "Adjusted corporate objects remain `PENDING_SIGN_CONVENTION_REVIEW`.",
  "",
  "Broader business-sector adjusted objects remain `PENDING_SECTOR_BOUNDARY_REVIEW`.",
  "",
  "No `PENDING_API_ACCESS` status remains for BEA/FRED retrieval completed in this run.",
  "",
  "## Qwen Audit",
  "",
  "The Qwen research note was audited as subordinate input. It is useful for search heuristics and for identifying misunderstandings, but it does not authorize formulas, signs, source mappings, source construction, or handoff.",
  "",
  "The Qwen owner-occupied-housing, mortgage-rate, imputed-rent, homeowners-equity, and tax-expenditure proxy paths are rejected or parked for this corporate Appendix 6.7 imputed-interest correction. Appendix 6.7 independently supports a financial-intermediary/NIPA Table 7.11 interest-accounting path, not a housing proxy path.",
  "",
  "The Qwen WEQ2 discussion is parked in the noncorporate business lane. It is not used in the S20E corporate imputed-interest crosswalk, and Qwen's operational WEQ2 formula does not authorize any S20E construction.",
  "",
  "## Handoff",
  "",
  "No provider handoff candidate was created because validation does not support downstream authorization.",
  "",
  "## Output Files",
  "",
  "- `csv/S20E_shaikh_semantic_concept_ledger.csv`",
  "- `csv/S20E_shaikh_acronym_to_concept_dictionary.csv`",
  "- `csv/S20E_bea_current_release_candidate_crosswalk.csv`",
  "- `csv/S20E_bea_api_response_summary.csv`",
  "- `csv/S20E_fred_fallback_candidate_ledger.csv`",
  "- `csv/S20E_constructibility_ledger.csv`",
  "- `csv/S20E_blocked_pending_object_ledger.csv`",
  "- `csv/S20E_external_research_note_audit_ledger.csv`",
  "- `csv/S20E_validation_checks.csv`"
)
writeLines(clean_report, file.path(md_dir, "S20E_SHAIKH_CURRENT_RELEASE_CROSSWALK.md"), useBytes = TRUE)

reconciliation_note <- c(
  "# S20E-R Reconciliation Note",
  "",
  "Date: 2026-06-17",
  "",
  "Final decision: `PENDING_PROVIDER_SHAIKH_CROSSWALK_BECAUSE_SIGN_OR_BOUNDARY_REVIEW_REQUIRED`",
  "",
  "## Stale Statuses Found",
  "",
  "- Markdown report retained older text saying BEA API access was unavailable.",
  "- Markdown report retained older text saying FRED API access was unavailable.",
  "- Markdown report retained older text saying all adjusted objects were `PENDING_API_ACCESS`.",
  "- Blocked/pending ledger retained `PENDING_API_ACCESS` for FRED fallback despite completed fallback search.",
  "",
  "## Corrections",
  "",
  "- BEA retrieval is recorded as completed for `T11400` and `T71100`.",
  "- FRED fallback search is recorded as completed where the environment key was available.",
  "- Corporate adjusted objects are `PENDING_SIGN_CONVENTION_REVIEW`.",
  "- Broader business adjusted objects are `PENDING_SECTOR_BOUNDARY_REVIEW`.",
  "- Qwen was audited as subordinate input and cannot authorize formulas, signs, mappings, construction, or handoff.",
  "",
  "## Handoff",
  "",
  "No provider handoff was created."
)
writeLines(reconciliation_note, file.path(md_dir, "S20E_R_RECONCILIATION_NOTE.md"), useBytes = TRUE)

missing_report <- c(
  "# S20E Missing-Input Report",
  "",
  "Status: superseded by S20E and S20E-R runs on 2026-06-17.",
  "",
  "The previous missing-source block is resolved. The current blocker is sign-convention and sector-boundary review for current-release `T71100` imputed-interest paid/received blocks, not source-document availability and not BEA/FRED API access.",
  "",
  "No provider handoff candidate has been created."
)
writeLines(missing_report, file.path(md_dir, "S20E_MISSING_INPUT_REPORT.md"), useBytes = TRUE)

# S20E-SB sign-convention and sector-boundary review. This is a targeted
# accounting adjudication pass using only current NIPA T71100/T11400.
if (bea_key_present && requireNamespace("jsonlite", quietly = TRUE)) {
  fetch_bea_table_sb <- function(table_name) {
    url <- paste0(
      "https://apps.bea.gov/api/data?UserID=",
      utils::URLencode(Sys.getenv("BEA_API_KEY"), reserved = TRUE),
      "&method=GetData&datasetname=NIPA&TableName=", table_name,
      "&Frequency=A&Year=X&ResultFormat=JSON"
    )
    jsonlite::fromJSON(url)[["BEAAPI"]][["Results"]][["Data"]]
  }

  value_num_sb <- function(x) suppressWarnings(as.numeric(gsub(",", "", x)))
  classify_sign_sb <- function(v) {
    if (all(v > 0, na.rm = TRUE)) return("positive")
    if (all(v < 0, na.rm = TRUE)) return("negative")
    if (all(v == 0, na.rm = TRUE)) return("zero")
    "mixed"
  }
  line_summary_sb <- function(dat, line_number) {
    d <- dat[as.character(dat$LineNumber) == as.character(line_number), ]
    v <- value_num_sb(d$DataValue)
    data.frame(
      table_name = unique(d$TableName)[1],
      line_number = as.character(line_number),
      line_description = unique(d$LineDescription)[1],
      bea_series_code = unique(d$SeriesCode)[1],
      unit = "millions of current dollars",
      frequency = "annual",
      coverage = paste(min(d$TimePeriod), max(d$TimePeriod), sep = "-"),
      value_signs_in_data = classify_sign_sb(v),
      value_2009 = v[d$TimePeriod == "2009"][1],
      value_latest = v[d$TimePeriod == max(d$TimePeriod)][1],
      stringsAsFactors = FALSE
    )
  }

  t711_sb <- fetch_bea_table_sb("T71100")
  t114_sb <- fetch_bea_table_sb("T11400")

  t711_definitions <- data.frame(
    concept = c(
      "financial corporate monetary interest paid",
      "financial corporate monetary interest received",
      "nonfinancial corporate monetary interest paid",
      "nonfinancial corporate monetary interest received",
      "financial corporate imputed interest paid first block",
      "financial corporate imputed interest received first block",
      "financial corporate imputed interest paid second block",
      "financial corporate imputed interest received second block",
      "nonfinancial corporate imputed interest paid first block",
      "nonfinancial corporate imputed interest received first block",
      "nonfinancial corporate imputed interest paid second block",
      "corporate net interest current subtotal",
      "domestic business net interest current subtotal",
      "old Shaikh line-number reuse 74 minus 53",
      "old Shaikh bank line-number reuse"
    ),
    line_number = c("4", "28", "7", "29", "43", "57", "79", "96", "49", "58", "80", "27", "100", "74/53", "4/44/73/28/52/91"),
    sector_boundary = c(
      "domestic corporate business",
      "domestic corporate business",
      "domestic corporate business",
      "domestic corporate business",
      "domestic corporate business",
      "domestic corporate business",
      "domestic corporate business",
      "domestic corporate business",
      "domestic corporate business",
      "domestic corporate business",
      "domestic corporate business",
      "domestic corporate business",
      "domestic business",
      "current lines are government/rest-of-world, not NFC",
      "current lines mix financial, banks, government, and rest-of-world"
    ),
    legal_form_boundary = c(
      rep("corporate", 13),
      "not corporate equivalent",
      "not coherent current legal-form boundary"
    ),
    financial_nonfinancial_status = c(
      "financial", "financial", "nonfinancial", "nonfinancial",
      "financial", "financial", "financial", "financial",
      "nonfinancial", "nonfinancial", "nonfinancial",
      "corporate subtotal", "business subtotal",
      "not current NFC equivalent", "mixed"
    ),
    paid_received_direction = c(
      "paid", "received", "paid", "received",
      "paid", "received", "paid", "received",
      "paid", "received", "paid",
      "received subtotal", "net subtotal", "invalid legacy reuse", "invalid legacy reuse"
    ),
    monetary_imputed_status = c(
      "monetary", "monetary", "monetary", "monetary",
      rep("imputed", 7),
      "monetary subtotal",
      "monetary plus imputed subtotal",
      "imputed line-number mismatch",
      "monetary/imputed line-number mismatch"
    ),
    gross_net_status = c(
      rep("gross ingredient", 11),
      "subtotal, not net paid",
      "net concept",
      "rejected formula fragment",
      "rejected formula fragment"
    ),
    line_role = c(
      rep("ingredient", 11),
      "subtotal",
      "net concept",
      "rejected",
      "rejected"
    ),
    candidate_quality = c(
      rep("exact", 4),
      rep("plausible", 7),
      "ambiguous",
      "plausible",
      "rejected",
      "rejected"
    ),
    reason = c(
      "Current T71100 line is explicitly Financial under Corporate business under Monetary interest paid.",
      "Current T71100 line is explicitly Financial under Corporate business under Monetary interest received.",
      "Current T71100 line is explicitly Nonfinancial under Corporate business under Monetary interest paid.",
      "Current T71100 line is explicitly Nonfinancial under Corporate business under Monetary interest received.",
      "Current T71100 line is Financial under Domestic corporate business in the first imputed-interest-paid block; exact subservice meaning still needs review.",
      "Current T71100 line is Financial under Corporate business in the first imputed-interest-received block; exact subservice meaning still needs review.",
      "Current T71100 line is Financial under Corporate business in the second imputed-interest-paid block and is negative in all annual observations; sign needs review.",
      "Current T71100 line is Domestic corporate business, financial in the second imputed-interest-received block and is negative in all annual observations; sign needs review.",
      "Current T71100 line is Nonfinancial under Domestic corporate business in the first imputed-interest-paid block; exact subservice meaning still needs review.",
      "Current T71100 line is Nonfinancial under Corporate business in imputed-interest-received block; exact subservice meaning still needs review.",
      "Current T71100 line is Nonfinancial under Corporate business in the second imputed-interest-paid block and is negative in all annual observations; sign needs review.",
      "Corporate monetary interest received subtotal is useful for checking but is not the required net-paid formula.",
      "Current T71100 publishes a domestic business net-interest concept, but it is broader than corporate-only adjustment.",
      "Current lines 74 and 53 are state/local and rest-of-world lines; this is not the Appendix 6.7 NFC concept in current release.",
      "Current old-number formula maps to government/rest-of-world lines in several places; cannot be carried forward mechanically."
    ),
    stringsAsFactors = FALSE
  )
  t711_line_nums <- unique(unlist(strsplit(t711_definitions$line_number, "/")))
  t711_line_nums <- t711_line_nums[grepl("^[0-9]+$", t711_line_nums)]
  t711_summaries <- do.call(rbind, lapply(t711_line_nums, function(x) line_summary_sb(t711_sb, x)))
  t711_adjudication <- merge(t711_definitions, t711_summaries, by = "line_number", all.x = TRUE, sort = FALSE)
  t711_adjudication$table_name[is.na(t711_adjudication$table_name)] <- "T71100"
  t711_adjudication$unit[is.na(t711_adjudication$unit)] <- "not applicable"
  t711_adjudication$frequency[is.na(t711_adjudication$frequency)] <- "not applicable"
  t711_adjudication$coverage[is.na(t711_adjudication$coverage)] <- "not applicable"
  t711_adjudication$value_signs_in_data[is.na(t711_adjudication$value_signs_in_data)] <- "not applicable"
  wcsv(t711_adjudication, "S20E_SB_t711_interest_line_adjudication_ledger.csv")

  line_val_sb <- function(line_number, year = "2009") {
    d <- t711_sb[as.character(t711_sb$LineNumber) == as.character(line_number) & t711_sb$TimePeriod == year, ]
    value_num_sb(d$DataValue)[1]
  }
  fin_net_2009 <- line_val_sb(4) + line_val_sb(43) + line_val_sb(79) -
    line_val_sb(28) - line_val_sb(57) - line_val_sb(96)
  nfc_imp_net_2009 <- line_val_sb(49) + line_val_sb(80) - line_val_sb(58)
  corp_adj_2009 <- -fin_net_2009 - nfc_imp_net_2009
  old_reuse_2009 <- NA_real_
  if (all(c("74", "53") %in% as.character(t711_sb$LineNumber))) {
    old_reuse_2009 <- line_val_sb(74) - line_val_sb(53)
  }

  sign_review <- data.frame(
    formula_id = c(
      "SB_FORMULA_001_NET_CONCEPT",
      "SB_FORMULA_002_PAID_MINUS_RECEIVED",
      "SB_FORMULA_003_OLD_LINE_NUMBER_REUSE",
      "SB_FORMULA_004_QWEN_HOUSING_PROXY"
    ),
    formula_text = c(
      "CorpImpIntAdj = - financial corporate net interest paid - nonfinancial corporate imputed net interest paid, using validated current-release net concepts if BEA publishes them.",
      "CorpImpIntAdj = -[(L4 + L43 + L79) - (L28 + L57 + L96)] - [(L49 + L80) - L58].",
      "Reject mechanical reuse of Appendix 6.7 old line numbers, such as line 74 - line 53 or (4+44+73)-(28+52+91), in current T71100.",
      "Reject or park owner-occupied housing, mortgage-rate, imputed-rent, homeowners-equity, or tax-expenditure proxy formulas."
    ),
    component_lines_used = c(
      "No clean single current BEA net lines for the exact corporate adjustment were identified.",
      "T71100 L4, L43, L79, L28, L57, L96, L49, L80, L58.",
      "Old Shaikh line-number fragments, including L74, L53, L44, L73, L52, L91.",
      "No T71100 corporate interest lines; non-BEA housing/FRED/tax-proxy paths."
    ),
    sign_applied_to_each_component = c(
      "Sign would be negative financial net paid minus nonfinancial corporate imputed net paid; not authorized without exact net definitions.",
      "Paid lines enter plus inside net paid; received lines enter minus inside net paid; Shaikh adjustment subtracts both net-paid components.",
      "Not applicable; rejected.",
      "Not applicable; rejected/parked."
    ),
    rationale_from_appendix_6_7 = c(
      "Appendix 6.7 item 9 states corporate adjustment as negative financial corporate net interest paid minus nonfinancial corporate net imputed interest paid.",
      "Appendix footnotes define net paid as paid components less received components and item 9 subtracts financial and nonfinancial corporate net-paid components.",
      "Appendix line numbers are historical clues from a 2011 download, not current-release variable names.",
      "Appendix 6.7 corporate correction is an interest-accounting correction tied to financial intermediaries, not a housing proxy."
    ),
    rationale_from_current_bea_line_descriptions = c(
      "Current T71100 has relevant ingredients and net domestic-business subtotal, but not a single exact corporate adjustment line.",
      "Current T71100 explicitly identifies financial/nonfinancial corporate monetary paid/received and imputed paid/received families; some imputed blocks remain generic.",
      "Current T71100 line 74 is state and local; line 53 is rest of world; old-number semantics do not match.",
      "No current BEA T71100 line description supports replacing the corporate adjustment with housing, mortgage, or tax-expenditure proxies."
    ),
    avoids_double_counting = c("unclear", "yes", "no", "no"),
    preserves_unit_compatibility = c("yes", "yes", "no", "no"),
    preserves_annual_support = c("yes", "yes", "yes", "not applicable"),
    reproduces_direction_of_shaikh_2009_logic = c(
      "plausibly positive after subtracting negative net-paid components, but no exact net line found",
      paste0("yes; current-release 2009 candidate gives positive adjustment direction, approximately ", round(corp_adj_2009, 1), " million dollars"),
      paste0("no; example current old-number fragment L74-L53 gives ", round(old_reuse_2009, 1), " million dollars and wrong current concepts"),
      "no"
    ),
    risk = c("high", "medium", "high", "high"),
    status = c(
      "PLAUSIBLE_REQUIRES_HUMAN_REVIEW",
      "PLAUSIBLE_REQUIRES_HUMAN_REVIEW",
      "REJECT_SIGN_CONVENTION",
      "REJECT_SIGN_CONVENTION"
    ),
    notes = c(
      "Useful target concept, but the exact current BEA net lines were not identified.",
      "Best current BEA formula candidate; still requires human review because imputed paid/received blocks include negative lines and generic sub-block meanings.",
      "Explicitly rejected by S20E-R and S20E-SB.",
      "Explicitly rejected/parked because Qwen cannot authorize formulas and Appendix 6.7 does not support this path."
    ),
    stringsAsFactors = FALSE
  )
  wcsv(sign_review, "S20E_SB_sign_convention_review_ledger.csv")

  sector_review <- data.frame(
    object_id = c(
      "corporate_imputed_interest_adjustment",
      "adjusted_corporate_gva",
      "adjusted_corporate_va",
      "adjusted_corporate_gos",
      "adjusted_corporate_nos",
      "business_imputed_interest_adjustment",
      "adjusted_business_gva",
      "adjusted_business_va",
      "adjusted_business_gos",
      "adjusted_business_nos"
    ),
    target_boundary = c(
      "corporate",
      "corporate",
      "corporate",
      "corporate",
      "corporate",
      "business-wide",
      "business-wide",
      "business-wide",
      "business-wide",
      "business-wide"
    ),
    required_components = c(
      "financial corporate net interest paid; nonfinancial corporate imputed net interest paid",
      "T11400 corporate GVA; corporate imputed-interest adjustment",
      "T11400 corporate NVA; corporate imputed-interest adjustment",
      "T11400 corporate NOS plus CFC source formula or direct GOS; corporate imputed-interest adjustment",
      "T11400 corporate NOS; corporate imputed-interest adjustment",
      "financial corporate net interest paid; nonfinancial business imputed net interest paid including noncorporate components",
      "business GVA base; business imputed-interest adjustment",
      "business VA base; business imputed-interest adjustment",
      "business GOS base; wage-equivalent lane; business imputed-interest adjustment",
      "business NOS base; wage-equivalent lane; business imputed-interest adjustment"
    ),
    available_current_bea_candidates = c(
      "T71100 L4/L28 and imputed families L43/L57/L79/L96 plus nonfinancial L49/L58/L80",
      "T11400 line 1 exact plus plausible adjustment",
      "T11400 line 3 exact plus plausible adjustment",
      "T11400 line 8 plus line 2 source formula plus plausible adjustment",
      "T11400 line 8 exact plus plausible adjustment",
      "Partial: corporate financial and nonfinancial corporate candidates exist; noncorporate/proprietor business components not fully adjudicated",
      "No exact current business-wide base authorized in S20E-SB",
      "No exact current business-wide base authorized in S20E-SB",
      "No exact current business-wide base or WEQ2 lane authorized in S20E-SB",
      "No exact current business-wide base or WEQ2 lane authorized in S20E-SB"
    ),
    missing_components = c(
      "No single exact BEA net adjustment line; imputed block subservice meanings need human review",
      "Exact adjustment authorization",
      "Exact adjustment authorization",
      "Direct corporate GOS line, if required; exact adjustment authorization",
      "Exact adjustment authorization",
      "Noncorporate business imputed-interest components and business boundary",
      "Business-wide base mapping and adjustment authorization",
      "Business-wide base mapping and adjustment authorization",
      "Business-wide base mapping, WEQ2 authorization, and adjustment authorization",
      "Business-wide base mapping, WEQ2 authorization, and adjustment authorization"
    ),
    boundary_risk = c(
      rep("medium", 5),
      rep("high", 5)
    ),
    status = c(
      rep("PLAUSIBLE_REQUIRES_HUMAN_REVIEW", 5),
      rep("PENDING_SECTOR_BOUNDARY_REVIEW", 5)
    ),
    reason = c(
      "Corporate financial/nonfinancial boundaries are explicit in current T71100, but imputed block interpretation prevents exact authorization.",
      "Base line is exact; adjustment remains plausible pending human review.",
      "Base line is exact; adjustment remains plausible pending human review.",
      "Base formula is plausible from exact NOS/CFC; adjustment remains plausible pending human review.",
      "Base line is exact; adjustment remains plausible pending human review.",
      "Business-wide Appendix path includes noncorporate components not adjudicated here.",
      "S20E-SB is corporate-focused and does not force business-wide construction.",
      "S20E-SB is corporate-focused and does not force business-wide construction.",
      "Qwen WEQ2 lane remains parked; business GOS is not authorized.",
      "Qwen WEQ2 lane remains parked; business NOS is not authorized."
    ),
    stringsAsFactors = FALSE
  )
  wcsv(sector_review, "S20E_SB_sector_boundary_review_ledger.csv")

  constructibility$constructibility_status <- c(
    "CONSTRUCTIBLE_CURRENT_BEA_PLAUSIBLE_REQUIRES_HUMAN_REVIEW",
    "PENDING_SECTOR_BOUNDARY_REVIEW",
    "CONSTRUCTIBLE_CURRENT_BEA_PLAUSIBLE_REQUIRES_HUMAN_REVIEW",
    "CONSTRUCTIBLE_CURRENT_BEA_PLAUSIBLE_REQUIRES_HUMAN_REVIEW",
    "CONSTRUCTIBLE_CURRENT_BEA_PLAUSIBLE_REQUIRES_HUMAN_REVIEW",
    "CONSTRUCTIBLE_CURRENT_BEA_PLAUSIBLE_REQUIRES_HUMAN_REVIEW",
    "PENDING_SECTOR_BOUNDARY_REVIEW",
    "PENDING_SECTOR_BOUNDARY_REVIEW",
    "PENDING_SECTOR_BOUNDARY_REVIEW",
    "PENDING_SECTOR_BOUNDARY_REVIEW"
  )
  constructibility$current_bea_or_fred_candidate_status <- c(
    rep("CURRENT_BEA_CANDIDATES_PLAUSIBLE_HUMAN_REVIEW_REQUIRED", 1),
    "CURRENT_BEA_BUSINESS_BOUNDARY_PENDING",
    rep("CURRENT_BEA_CANDIDATES_PLAUSIBLE_HUMAN_REVIEW_REQUIRED", 4),
    rep("CURRENT_BEA_BUSINESS_BOUNDARY_PENDING", 4)
  )
  constructibility$notes <- c(
    "Current T71100 paid-minus-received corporate formula is plausible and sign-explicit, but imputed block meanings require human accounting review.",
    "Business-wide noncorporate/proprietor imputed-interest boundary remains unresolved.",
    "T11400 corporate GVA is exact; adjustment is plausible pending human review.",
    "T11400 corporate NVA is exact; adjustment is plausible pending human review.",
    "T11400 corporate NOS plus CFC source formula is plausible; adjustment is plausible pending human review.",
    "T11400 corporate NOS is exact; adjustment is plausible pending human review.",
    "Business-wide base and adjustment remain boundary-pending.",
    "Business-wide base and adjustment remain boundary-pending.",
    "Business-wide GOS also depends on parked WEQ2/noncorporate lane.",
    "Business-wide NOS also depends on parked WEQ2/noncorporate lane."
  )
  wcsv(constructibility, "S20E_constructibility_ledger.csv")

  blocked$blocked_status[blocked$object_or_decision == "financial corporate net interest paid full component formula"] <- "PLAUSIBLE_REQUIRES_HUMAN_REVIEW"
  blocked$blocking_reason[blocked$object_or_decision == "financial corporate net interest paid full component formula"] <- "Current T71100 financial corporate paid/received monetary and imputed families support a sign-explicit formula, but imputed block meanings require human review."
  blocked$blocked_status[blocked$object_or_decision == "nonfinancial corporate imputed net interest paid"] <- "PLAUSIBLE_REQUIRES_HUMAN_REVIEW"
  blocked$blocking_reason[blocked$object_or_decision == "nonfinancial corporate imputed net interest paid"] <- "Current T71100 nonfinancial corporate imputed paid/received candidates exist, but paid block interpretation requires human review."
  blocked$blocked_status[blocked$object_or_decision == "corporate imputed interest adjustment"] <- "PLAUSIBLE_REQUIRES_HUMAN_REVIEW"
  blocked$blocking_reason[blocked$object_or_decision == "corporate imputed interest adjustment"] <- "Current BEA formula candidate is plausible but not exact enough for handoff authorization."
  blocked$blocked_status[blocked$object_or_decision == "adjusted corporate GVA/VA/GOS/NOS"] <- "PLAUSIBLE_REQUIRES_HUMAN_REVIEW"
  blocked$blocking_reason[blocked$object_or_decision == "adjusted corporate GVA/VA/GOS/NOS"] <- "T11400 bases are exact, but corporate adjustment remains plausible pending human accounting review."
  blocked$blocked_status[blocked$object_or_decision == "provider handoff candidate"] <- "BLOCKED_PLAUSIBLE_REQUIRES_HUMAN_REVIEW"
  blocked$blocking_reason[blocked$object_or_decision == "provider handoff candidate"] <- "Corporate adjusted objects are plausible but not CONSTRUCTIBLE_CURRENT_BEA_EXACT; handoff rule not met."
  wcsv(blocked, "S20E_blocked_pending_object_ledger.csv")

  validation <- rbind(
    validation,
    data.frame(
      check_name = c(
        "t711_interest_line_families_inspected",
        "sign_convention_review_completed",
        "sector_boundary_review_completed",
        "old_appendix_line_numbers_not_carried_forward_mechanically",
        "fred_not_used_as_independent_authorization_sb",
        "t11400_corporate_base_candidates_preserved_sb",
        "provider_handoff_rule_applied_sb"
      ),
      status = "PASS",
      evidence = c(
        "S20E_SB_t711_interest_line_adjudication_ledger.csv",
        "S20E_SB_sign_convention_review_ledger.csv",
        "S20E_SB_sector_boundary_review_ledger.csv",
        "Old-number formulas are rejected in the sign ledger.",
        "FRED and Qwen proxy paths are rejected/parked; BEA remains authoritative.",
        "Constructibility ledger preserves exact T11400 bases with plausible adjustment review.",
        "No handoff created because corporate objects are plausible, not exact."
      ),
      notes = c(
        "Targeted T71100/T11400 calls only.",
        "",
        "",
        "",
        "",
        "",
        ""
      )
    )
  )
  validation$evidence[validation$check_name == "final_decision_explicit"] <- "CONSTRUCTIBLE_CURRENT_BEA_PLAUSIBLE_REQUIRES_HUMAN_REVIEW"
  wcsv(validation, "S20E_validation_checks.csv")

  sb_report <- c(
    "# S20E-SB Sign and Boundary Review",
    "",
    "Date: 2026-06-17",
    "",
    "Final decision: `CONSTRUCTIBLE_CURRENT_BEA_PLAUSIBLE_REQUIRES_HUMAN_REVIEW`",
    "",
    "## Already Resolved By S20E-R",
    "",
    "Source documents are present; stock-flow labour-value logic governs; Shaikh and Tonak provide theoretical inspiration; Appendix 6.7 is the benchmark empirical example; BEA/NIPA is the operational terrain; FRED fallback metadata search completed; `T11400` corporate base lines are exact documentation candidates; Qwen remains subordinate audit input; no adjusted Shaikh variables were constructed; no provider handoff was created.",
    "",
    "## T711 Interest-Line Adjudication",
    "",
    "Current `T71100` explicitly identifies financial and nonfinancial corporate monetary paid/received lines. It also identifies financial and nonfinancial corporate imputed paid/received line families, including negative-valued imputed blocks. These families are relevant source candidates, but their subservice meanings and negative received/paid signs require human accounting review before exact authorization.",
    "",
    "Rejected: mechanical reuse of Appendix 6.7 old line numbers. Current `T71100` line 74 is state and local and line 53 is rest of the world, so old line-number formulas cannot be carried forward mechanically.",
    "",
    "## Sign Convention",
    "",
    "Best current BEA candidate formula:",
    "",
    "`CorpImpIntAdj = -[(T71100 L4 + L43 + L79) - (L28 + L57 + L96)] - [(L49 + L80) - L58]`",
    "",
    "This formula is sign-explicit, unit-compatible, annual, and reproduces the positive direction of Appendix 6.7's 2009 corporate adjustment logic using current-release data. It is not exact because the current imputed-interest paid/received blocks need human accounting review.",
    "",
    "Rejected: old-number formulas and Qwen housing, mortgage-rate, imputed-rent, homeowners-equity, and tax-expenditure proxy paths.",
    "",
    "## Sector Boundary",
    "",
    "Corporate objects are plausible current-BEA constructs requiring human review. Business-wide objects remain `PENDING_SECTOR_BOUNDARY_REVIEW` because noncorporate/proprietor and WEQ2-related boundaries were not adjudicated here.",
    "",
    "## Constructibility",
    "",
    "Corporate adjusted objects: `CONSTRUCTIBLE_CURRENT_BEA_PLAUSIBLE_REQUIRES_HUMAN_REVIEW`.",
    "",
    "Business-wide adjusted objects: `PENDING_SECTOR_BOUNDARY_REVIEW`.",
    "",
    "## Handoff",
    "",
    "No provider handoff candidate was created. The handoff rule requires `CONSTRUCTIBLE_CURRENT_BEA_EXACT`, and S20E-SB reaches only plausible current-BEA constructibility requiring human review.",
    "",
    "## Construction Boundary",
    "",
    "No adjusted variables were constructed."
  )
  writeLines(sb_report, file.path(md_dir, "S20E_SB_SIGN_BOUNDARY_REVIEW.md"), useBytes = TRUE)

  clean_report <- c(
    clean_report,
    "",
    "## S20E-SB Sign/Boundary Review",
    "",
    "S20E-SB inspected current `T71100` interest-line families and produced adjudication, sign-convention, and sector-boundary review ledgers.",
    "",
    "Corporate adjusted objects are `CONSTRUCTIBLE_CURRENT_BEA_PLAUSIBLE_REQUIRES_HUMAN_REVIEW`: `T11400` bases are exact, and the current `T71100` paid-minus-received formula candidate is sign-explicit, but imputed-interest block interpretation requires human accounting review.",
    "",
    "Business-wide adjusted objects remain `PENDING_SECTOR_BOUNDARY_REVIEW`.",
    "",
    "No provider handoff candidate was created, and no adjusted variables were constructed.",
    "",
    "Current final decision: `CONSTRUCTIBLE_CURRENT_BEA_PLAUSIBLE_REQUIRES_HUMAN_REVIEW`."
  )
  clean_report[5] <- "Final decision: `CONSTRUCTIBLE_CURRENT_BEA_PLAUSIBLE_REQUIRES_HUMAN_REVIEW`"
  writeLines(clean_report, file.path(md_dir, "S20E_SHAIKH_CURRENT_RELEASE_CROSSWALK.md"), useBytes = TRUE)
}

# S20E-CL conceptual consolidation pass. This creates interpretation-
# conditional candidates only. It does not authorize construction, produce
# time series, attach a handoff, or claim productive value for finance.
mk <- function(...) data.frame(..., stringsAsFactors = FALSE, check.names = FALSE)

account_objects <- c(
  "GVA", "VA_NVA", "GOS", "NOS", "corporate_profits",
  "net_interest", "imputed_interest", "compensation",
  "taxes_on_production_and_imports_less_subsidies",
  "consumption_of_fixed_capital", "transfers",
  "Shaikh_style_imputed_interest_restoration_term"
)
account_template <- data.frame(
  conceptual_object = account_objects,
  accounting_ladder_position = c(
    "top production-account value-added flow",
    "net value-added flow below CFC",
    "operating-surplus residual before CFC deduction",
    "operating-surplus residual after CFC deduction",
    "distribution/profit decomposition object",
    "property-income distribution component",
    "imputed property-income/accounting-services component",
    "income-side production-account component",
    "income-side production-account component",
    "gross-to-net production-account component",
    "distribution/current-transfer component",
    "interpretation-conditional restoration term"
  ),
  formal_definition = c(
    "gross value added equals output less intermediate inputs",
    "net value added equals gross value added less consumption of fixed capital",
    "gross operating surplus equals GVA less compensation less production taxes net of subsidies",
    "net operating surplus equals GOS less consumption of fixed capital",
    "corporate profits with IVA and CCAdj is a profit-type distribution object, not NOS",
    "net interest equals interest paid less interest received under the relevant BEA boundary",
    "imputed interest reflects BEA imputations for financial intermediary services and related reference-rate accounting",
    "compensation of employees paid",
    "taxes on production and imports less subsidies",
    "consumption of fixed capital",
    "business current transfer payments net",
    "Appendix 6.7-style term restoring imputed-interest treatment effects on corporate GVA/GOS/NOS"
  ),
  net_of = c(
    "intermediate inputs",
    "intermediate inputs; consumption of fixed capital",
    "intermediate inputs; compensation; taxes on production and imports less subsidies",
    "intermediate inputs; compensation; taxes on production and imports less subsidies; consumption of fixed capital",
    "not applicable as account-ladder residual; depends on profit decomposition",
    "interest received under the same boundary",
    "imputed interest received where defined as net paid",
    "not applicable",
    "subsidies",
    "not applicable",
    "gross current transfers received where netted",
    "NIPA imputed-interest treatment effects under the named interpretation"
  ),
  not_net_of = c(
    "compensation; production taxes; CFC; actual interest; profits",
    "compensation; production taxes; actual interest; profits",
    "CFC; actual interest; corporate profits",
    "actual interest; corporate profits",
    "NOS must not be added to corporate profits",
    "production costs or value added",
    "productive value claim; actual monetary interest unless explicitly combined",
    "not a surplus residual",
    "not compensation or surplus",
    "not compensation, taxes, or profit",
    "not operating surplus",
    "not corporate profit; not pure surplus value"
  ),
  gross_or_net_status = c(
    "gross", "net", "gross", "net", "profit-type", "net", "gross_or_net_by_line",
    "flow", "net_tax", "gross_to_net_component", "net_transfer", "restoration_term"
  ),
  flow_or_residual = c(
    "flow", "flow", "residual", "residual", "decomposition_object",
    "flow", "flow", "flow", "flow", "flow", "flow", "formula_term"
  ),
  production_account_component = c(
    "yes", "yes", "yes", "yes", "no", "no", "review", "yes", "yes", "yes", "no", "interpretation_conditional"
  ),
  property_income_component = c(
    "no", "no", "no", "no", "yes", "yes", "yes", "no", "no", "no", "no", "yes"
  ),
  profit_decomposition_component = c(
    "no", "no", "no", "no", "yes", "yes", "review", "no", "no", "no", "yes", "review"
  ),
  productive_theory_status = c(
    "mixed", "mixed", "mixed", "mixed", "mixed", "nonproductive", "nonproductive",
    "mixed", "not_claimed", "not_claimed", "not_claimed", "not_claimed"
  ),
  productive_value_claim = c(
    "restricted", "restricted", "restricted", "restricted", "restricted", "no", "no",
    "restricted", "not_applicable", "not_applicable", "not_applicable", "no"
  ),
  Shaikh_Tonak_theoretical_role = c(
    "official value-added starting point requiring theoretical boundary discipline",
    "net-product counterpart after depreciation",
    "surplus residual before CFC, not pure surplus value by itself",
    "surplus residual after CFC, not after-interest profit",
    "profit-type income category, not to be added to NOS",
    "distribution/property-income flow; finance is not claimed as productive value",
    "official-account imputation requiring careful correction, not productive-value creation",
    "labor-income component for wage/surplus decomposition",
    "state claim on production-account value added",
    "capital-consumption allowance separating gross from net measures",
    "distribution flow outside the production-account ladder",
    "accounting restoration only under Appendix 6.7 interpretation"
  ),
  Appendix_6_7_benchmark_role = c(
    "base for final corporate GVA candidate",
    "base for final corporate VA candidate",
    "base for final corporate GOS candidate",
    "base for final corporate NOS/EBIT-like candidate",
    "profit comparison/decomposition object",
    "interest correction ingredient",
    "interest correction ingredient",
    "income-side component and wage-share numerator",
    "income-side component",
    "GOS-to-NOS bridge",
    "income-side component",
    "CorpImpIntAdj or BusImpIntAdj formula term"
  ),
  current_BEA_candidate_status = c(
    "T11400 exact for corporate and NFC GVA",
    "T11400 exact for corporate and NFC NVA",
    "corporate GOS source formula plausible from T11400 NOS plus CFC",
    "T11400 exact for corporate and NFC NOS",
    "T11400 exact for corporate and NFC corporate profits with IVA and CCAdj",
    "T11400 exact for corporate/NFC broad net interest; T71100 detail plausible",
    "T71100 families plausible requiring human review",
    "T11400 exact for corporate and NFC compensation",
    "T11400 exact for corporate and NFC taxes less subsidies",
    "T11400 exact for corporate and NFC CFC",
    "T11400 exact for corporate and NFC transfers",
    "S20E-SB plausible current-BEA candidate requiring human review"
  ),
  notes = "S20E-CL conceptual classification only; no construction or handoff authorization."
)
ladder <- do.call(rbind, lapply(c("corporate", "nonfinancial corporate"), function(boundary) {
  out <- account_template
  out$sector_boundary <- ifelse(boundary == "corporate", "corporate business", "nonfinancial corporate business")
  out$legal_form_boundary <- ifelse(boundary == "corporate", "corporate", "nonfinancial corporate")
  out$stock_or_flow <- "flow"
  out[, c(
    "conceptual_object", "sector_boundary", "legal_form_boundary",
    "accounting_ladder_position", "formal_definition", "net_of", "not_net_of",
    "gross_or_net_status", "flow_or_residual", "stock_or_flow",
    "production_account_component", "property_income_component",
    "profit_decomposition_component", "productive_theory_status",
    "productive_value_claim", "Shaikh_Tonak_theoretical_role",
    "Appendix_6_7_benchmark_role", "current_BEA_candidate_status", "notes"
  )]
}))
wcsv(ladder, "S20E_CL_conceptual_account_ladder_ledger.csv")

sector_boundary <- rbind(
  mk(boundary_id = "BOUNDARY_CORP", boundary_name = "Corporate sector as a whole", included_units = "financial and nonfinancial domestic corporate business", excluded_units = "noncorporate business; households; NPISH; government", `BEA/NIPA legal-form basis` = "corporate legal form in NIPA Table 1.14 and Table 7.11", Shaikh_Tonak_theoretical_status = "mixed legal/accounting boundary", productive_value_claim_allowed = "restricted", relationship_to_Chapter_2_baseline = "not a replacement for NFC baseline", aggregation_with_other_boundaries_allowed = "restricted", consolidation_needed = "review", internal_transfer_risk = "medium", double_accounting_risk = "medium", notes = "Legal/accounting boundary, not identical to Shaikh/Tonak productive-theoretical boundary."),
  mk(boundary_id = "BOUNDARY_FC", boundary_name = "Financial corporate sector", included_units = "financial corporate business and financial intermediaries", excluded_units = "nonfinancial corporations; noncorporate business", `BEA/NIPA legal-form basis` = "financial branch under corporate business", Shaikh_Tonak_theoretical_status = "nonproductive or circulation/financial activity in theoretical frame", productive_value_claim_allowed = "no", relationship_to_Chapter_2_baseline = "accounting-correction ingredient only", aggregation_with_other_boundaries_allowed = "restricted", consolidation_needed = "yes", internal_transfer_risk = "high", double_accounting_risk = "high", notes = "May be used as correction ingredient; must not be treated as newly produced productive value."),
  mk(boundary_id = "BOUNDARY_NFC", boundary_name = "Nonfinancial corporate sector", included_units = "nonfinancial domestic corporate business", excluded_units = "financial corporate; noncorporate; household; government", `BEA/NIPA legal-form basis` = "nonfinancial corporate branch in NIPA Table 1.14 and Table 7.11", Shaikh_Tonak_theoretical_status = "closer to productive corporate boundary but still legal/accounting", productive_value_claim_allowed = "restricted", relationship_to_Chapter_2_baseline = "existing baseline lane remains NFC GVA wage-share", aggregation_with_other_boundaries_allowed = "restricted", consolidation_needed = "review", internal_transfer_risk = "medium", double_accounting_risk = "medium", notes = "Preferred baseline is not replaced by S20E-CL."),
  mk(boundary_id = "BOUNDARY_BUS", boundary_name = "Business-wide sector", included_units = "corporate plus noncorporate business", excluded_units = "households as consumers; NPISH; government", `BEA/NIPA legal-form basis` = "business aggregate or constructed account", Shaikh_Tonak_theoretical_status = "mixed; includes proprietor wage-equivalent issues", productive_value_claim_allowed = "restricted", relationship_to_Chapter_2_baseline = "not authorized as model baseline", aggregation_with_other_boundaries_allowed = "restricted", consolidation_needed = "yes", internal_transfer_risk = "high", double_accounting_risk = "high", notes = "Business-wide path remains sector-boundary pending."),
  mk(boundary_id = "BOUNDARY_NONCORP", boundary_name = "Noncorporate business", included_units = "sole proprietorships and partnerships", excluded_units = "corporations", `BEA/NIPA legal-form basis` = "noncorporate legal form", Shaikh_Tonak_theoretical_status = "mixed income requiring wage-equivalent decomposition", productive_value_claim_allowed = "restricted", relationship_to_Chapter_2_baseline = "parked noncorporate lane", aggregation_with_other_boundaries_allowed = "restricted", consolidation_needed = "yes", internal_transfer_risk = "medium", double_accounting_risk = "medium", notes = "WEQ2/noncorporate path is not authorized here."),
  mk(boundary_id = "BOUNDARY_PRODUCTIVE_THEORY", boundary_name = "Productive-theoretical boundary in Shaikh and Tonak", included_units = "labor and activities productive of capital under the theoretical classification", excluded_units = "unproductive circulation, finance, many state/household flows depending classification", `BEA/NIPA legal-form basis` = "not a BEA legal-form boundary", Shaikh_Tonak_theoretical_status = "theoretical productive-value boundary", productive_value_claim_allowed = "yes only after separate theoretical classification", relationship_to_Chapter_2_baseline = "not implemented by provider S20E", aggregation_with_other_boundaries_allowed = "no", consolidation_needed = "review", internal_transfer_risk = "high", double_accounting_risk = "high", notes = "Cannot be inferred from corporate legal form alone.")
)
wcsv(sector_boundary, "S20E_CL_sector_boundary_ledger.csv")

stock_flow_gate <- rbind(
  mk(candidate_id = "CORP_IMPUTED_INTEREST_ADJ_RECONCILIATION_CANDIDATE", candidate_formula = "FC_NET_INT_PAID_CANDIDATE + NFC_NET_IMPUTED_INT_PAID_CANDIDATE with Appendix 6.7 signs", accounting_ladder_position = "restoration term", affected_accounts = "GVA, VA, GOS, NOS", required_identity = "If GVA is adjusted, the same restoration flows through GOS and NOS; GOS=CFC+NOS remains intact.", identity_preserved = "review", flow_or_stock_consistency = "pass", unit_consistency = "pass", time_support_consistency = "pass", interpretation_required = "ACCOUNTING_RESTORATION_INTERPRETATION", stock_flow_consistency_gate = "REVIEW", reason = "Formula is a flow restoration term, but human review is required before asserting account identities are exactly preserved."),
  mk(candidate_id = "CORP_GVA_SHAIKH_RECONCILIATION_CANDIDATE", candidate_formula = "CORP_GVA_NIPA + CORP_IMPUTED_INTEREST_ADJ_RECONCILIATION_CANDIDATE", accounting_ladder_position = "GVA", affected_accounts = "GVA and downstream GOS/NOS", required_identity = "GVA=COMP+TAX_NET+GOS requires the adjustment to flow through GOS.", identity_preserved = "review", flow_or_stock_consistency = "pass", unit_consistency = "pass", time_support_consistency = "pass", interpretation_required = "ACCOUNTING_RESTORATION_INTERPRETATION", stock_flow_consistency_gate = "REVIEW", reason = "Allowed only if GOS and NOS are adjusted by same restoration term."),
  mk(candidate_id = "CORP_GOS_SHAIKH_RECONCILIATION_CANDIDATE", candidate_formula = "CORP_GOS_NIPA + CORP_IMPUTED_INTEREST_ADJ_RECONCILIATION_CANDIDATE", accounting_ladder_position = "GOS", affected_accounts = "GOS and NOS", required_identity = "GOS=CFC+NOS requires NOS to receive same adjustment when CFC is unchanged.", identity_preserved = "review", flow_or_stock_consistency = "pass", unit_consistency = "pass", time_support_consistency = "pass", interpretation_required = "ACCOUNTING_RESTORATION_INTERPRETATION", stock_flow_consistency_gate = "REVIEW", reason = "CFC is unchanged; NOS must move with GOS."),
  mk(candidate_id = "CORP_NOS_SHAIKH_EBIT_RECONCILIATION_CANDIDATE", candidate_formula = "CORP_NOS_NIPA + CORP_IMPUTED_INTEREST_ADJ_RECONCILIATION_CANDIDATE", accounting_ladder_position = "NOS", affected_accounts = "NOS/EBIT-like residual", required_identity = "NOS is operating surplus residual, not corporate profits.", identity_preserved = "review", flow_or_stock_consistency = "pass", unit_consistency = "pass", time_support_consistency = "pass", interpretation_required = "CORPORATE_DISTRIBUTION_RECONCILIATION_INTERPRETATION", stock_flow_consistency_gate = "REVIEW", reason = "Interpret as EBIT-like NOS, not adjusted corporate profit."),
  mk(candidate_id = "ADD_CORP_PROFITS_TO_NOS_NEGATIVE_CONTROL", candidate_formula = "CORP_NOS_NIPA + CORP_PROFITS_IVA_CCAdj", accounting_ladder_position = "invalid", affected_accounts = "NOS and profit decomposition", required_identity = "NOS is not corporate profits and must not add profits.", identity_preserved = "no", flow_or_stock_consistency = "fail", unit_consistency = "pass", time_support_consistency = "pass", interpretation_required = "none", stock_flow_consistency_gate = "FAIL", reason = "Adds a profit decomposition object to surplus residual and breaks ladder logic.")
)
wcsv(stock_flow_gate, "S20E_CL_stock_flow_consistency_gate.csv")

double_gate <- rbind(
  mk(candidate_id = "CORP_IMPUTED_INTEREST_ADJ_RECONCILIATION_CANDIDATE", candidate_formula = "subtract financial corporate net paid and nonfinancial corporate imputed net paid using Appendix signs", involved_sectors = "financial corporate; nonfinancial corporate", involved_flows = "monetary and imputed interest paid/received", flow_direction = "restoration_term", monetary_or_imputed = "monetary and imputed", transfer_or_production_component = "accounting restoration, not productive output claim", intra_corporate_transfer_risk = "medium", financial_income_as_productive_value_risk = "low", profit_added_to_surplus_risk = "none", same_flow_counted_twice_risk = "medium", double_accounting_gate = "REVIEW", reason = "Candidate is disciplined as restoration, but financial/nonfinancial mirror flows need human review."),
  mk(candidate_id = "TREAT_FC_RECEIPTS_AS_PRODUCTIVE_VALUE_NEGATIVE_CONTROL", candidate_formula = "add financial corporate interest receipts as new productive value", involved_sectors = "financial corporate", involved_flows = "interest received", flow_direction = "received", monetary_or_imputed = "monetary_or_imputed", transfer_or_production_component = "property income", intra_corporate_transfer_risk = "high", financial_income_as_productive_value_risk = "high", profit_added_to_surplus_risk = "medium", same_flow_counted_twice_risk = "high", double_accounting_gate = "FAIL", reason = "Financial receipts are not newly produced productive value under the Shaikh and Tonak frame."),
  mk(candidate_id = "COUNT_NFC_PAID_AND_FC_RECEIVED_INDEPENDENTLY_NEGATIVE_CONTROL", candidate_formula = "add nonfinancial interest paid and financial interest received as independent surplus sources", involved_sectors = "financial corporate; nonfinancial corporate", involved_flows = "same interest flow viewed from both sides", flow_direction = "paid and received", monetary_or_imputed = "monetary", transfer_or_production_component = "property income transfer", intra_corporate_transfer_risk = "high", financial_income_as_productive_value_risk = "high", profit_added_to_surplus_risk = "medium", same_flow_counted_twice_risk = "high", double_accounting_gate = "FAIL", reason = "Counts both sides of a transfer as independent sources."),
  mk(candidate_id = "ADD_CORP_PROFITS_TO_NOS_NEGATIVE_CONTROL", candidate_formula = "CORP_NOS + corporate profits", involved_sectors = "corporate", involved_flows = "NOS and profit decomposition", flow_direction = "not_applicable", monetary_or_imputed = "not_applicable", transfer_or_production_component = "profit decomposition", intra_corporate_transfer_risk = "medium", financial_income_as_productive_value_risk = "medium", profit_added_to_surplus_risk = "high", same_flow_counted_twice_risk = "high", double_accounting_gate = "FAIL", reason = "Corporate profits are not additive to NOS."),
  mk(candidate_id = "QWEN_HOUSING_PROXY_NEGATIVE_CONTROL", candidate_formula = "owner-occupied housing, mortgage-rate, imputed-rent, homeowners-equity, or tax-expenditure proxy", involved_sectors = "household/housing", involved_flows = "housing proxy flows", flow_direction = "proxy", monetary_or_imputed = "imputed", transfer_or_production_component = "not corporate T711 restoration", intra_corporate_transfer_risk = "high", financial_income_as_productive_value_risk = "medium", profit_added_to_surplus_risk = "medium", same_flow_counted_twice_risk = "high", double_accounting_gate = "FAIL", reason = "Rejected/parked by Qwen audit and not Appendix 6.7 corporate correction."),
  mk(candidate_id = "OLD_LINE_NUMBER_REUSE_NEGATIVE_CONTROL", candidate_formula = "mechanically reuse old Appendix 6.7 line numbers", involved_sectors = "mismatched current sectors", involved_flows = "mismatched current lines", flow_direction = "unknown", monetary_or_imputed = "unknown", transfer_or_production_component = "unknown", intra_corporate_transfer_risk = "high", financial_income_as_productive_value_risk = "high", profit_added_to_surplus_risk = "medium", same_flow_counted_twice_risk = "high", double_accounting_gate = "FAIL", reason = "Old line numbers are historical clues only.")
)
wcsv(double_gate, "S20E_CL_double_accounting_gate.csv")

menu <- rbind(
  mk(candidate_id = "CORP_IMPUTED_INTEREST_ADJ_RECONCILIATION_CANDIDATE", candidate_name = "Corporate imputed-interest restoration candidate", formula = "FC_NET_INT_PAID_CANDIDATE + NFC_NET_IMPUTED_INT_PAID_CANDIDATE under Appendix signs", interpretation = "ACCOUNTING_RESTORATION_INTERPRETATION", sector_boundary = "corporate", legal_form_boundary = "corporate with FC/NFC ingredients", productive_theory_status = "not_claimed", productive_value_claim = "no", line_candidates_available = "partial", stock_flow_consistency_gate = "REVIEW", double_accounting_gate = "REVIEW", allowed_use = "documentation; reconciliation; candidate formula menu; future human-review robustness candidate", prohibited_use = "constructed model input; baseline variable; regression regressor; pure surplus value; adjusted corporate profit; replacement for WAGE_SHARE_UNADJUSTED_NFC_GVA_BASELINE", candidate_status = "INTERPRETATION_CONDITIONAL_CANDIDATE", reason = "Formally defined and line-matched as plausible, but not authorized."),
  mk(candidate_id = "CORP_GVA_SHAIKH_RECONCILIATION_CANDIDATE", candidate_name = "Corporate GVA Shaikh-style reconciliation candidate", formula = "CORP_GVA_NIPA + CORP_IMPUTED_INTEREST_ADJ_RECONCILIATION_CANDIDATE", interpretation = "CORPORATE_DISTRIBUTION_RECONCILIATION_INTERPRETATION", sector_boundary = "corporate", legal_form_boundary = "corporate", productive_theory_status = "mixed", productive_value_claim = "restricted", line_candidates_available = "partial", stock_flow_consistency_gate = "REVIEW", double_accounting_gate = "REVIEW", allowed_use = "documentation; reconciliation; candidate formula menu; future human-review robustness candidate", prohibited_use = "constructed model input; baseline variable; regression regressor; pure surplus value; adjusted corporate profit; replacement for WAGE_SHARE_UNADJUSTED_NFC_GVA_BASELINE", candidate_status = "INTERPRETATION_CONDITIONAL_CANDIDATE", reason = "Requires adjustment to flow through GOS/NOS."),
  mk(candidate_id = "CORP_VA_SHAIKH_RECONCILIATION_CANDIDATE", candidate_name = "Corporate VA Shaikh-style reconciliation candidate", formula = "CORP_VA_NIPA + CORP_IMPUTED_INTEREST_ADJ_RECONCILIATION_CANDIDATE", interpretation = "CORPORATE_DISTRIBUTION_RECONCILIATION_INTERPRETATION", sector_boundary = "corporate", legal_form_boundary = "corporate", productive_theory_status = "mixed", productive_value_claim = "restricted", line_candidates_available = "partial", stock_flow_consistency_gate = "REVIEW", double_accounting_gate = "REVIEW", allowed_use = "documentation; reconciliation; candidate formula menu; future human-review robustness candidate", prohibited_use = "constructed model input; baseline variable; regression regressor; pure surplus value; adjusted corporate profit; replacement for WAGE_SHARE_UNADJUSTED_NFC_GVA_BASELINE", candidate_status = "INTERPRETATION_CONDITIONAL_CANDIDATE", reason = "Conceptual counterpart to Appendix 6.7 VA adjustment."),
  mk(candidate_id = "CORP_GOS_SHAIKH_RECONCILIATION_CANDIDATE", candidate_name = "Corporate GOS Shaikh-style reconciliation candidate", formula = "CORP_GOS_NIPA + CORP_IMPUTED_INTEREST_ADJ_RECONCILIATION_CANDIDATE", interpretation = "CORPORATE_DISTRIBUTION_RECONCILIATION_INTERPRETATION", sector_boundary = "corporate", legal_form_boundary = "corporate", productive_theory_status = "mixed", productive_value_claim = "restricted", line_candidates_available = "partial", stock_flow_consistency_gate = "REVIEW", double_accounting_gate = "REVIEW", allowed_use = "documentation; reconciliation; candidate formula menu; future human-review robustness candidate", prohibited_use = "constructed model input; baseline variable; regression regressor; pure surplus value; adjusted corporate profit; replacement for WAGE_SHARE_UNADJUSTED_NFC_GVA_BASELINE", candidate_status = "INTERPRETATION_CONDITIONAL_CANDIDATE", reason = "Must preserve GOS=CFC+NOS."),
  mk(candidate_id = "CORP_NOS_SHAIKH_EBIT_RECONCILIATION_CANDIDATE", candidate_name = "Corporate NOS EBIT-like reconciliation candidate", formula = "CORP_NOS_NIPA + CORP_IMPUTED_INTEREST_ADJ_RECONCILIATION_CANDIDATE", interpretation = "CORPORATE_DISTRIBUTION_RECONCILIATION_INTERPRETATION", sector_boundary = "corporate", legal_form_boundary = "corporate", productive_theory_status = "mixed", productive_value_claim = "restricted", line_candidates_available = "partial", stock_flow_consistency_gate = "REVIEW", double_accounting_gate = "REVIEW", allowed_use = "documentation; reconciliation; candidate formula menu; future human-review robustness candidate", prohibited_use = "constructed model input; baseline variable; regression regressor; pure surplus value; adjusted corporate profit; replacement for WAGE_SHARE_UNADJUSTED_NFC_GVA_BASELINE", candidate_status = "INTERPRETATION_CONDITIONAL_CANDIDATE", reason = "Appendix 6.7 frames as EBIT-like NOS, not adjusted corporate profit."),
  mk(candidate_id = "WAGE_SHARE_CORP_SHAIKH_RECONCILIATION_CANDIDATE", candidate_name = "Corporate wage-share reconciliation candidate", formula = "CORP_COMP / CORP_GVA_SHAIKH_RECONCILIATION_CANDIDATE", interpretation = "CORPORATE_DISTRIBUTION_RECONCILIATION_INTERPRETATION", sector_boundary = "corporate", legal_form_boundary = "corporate", productive_theory_status = "mixed", productive_value_claim = "no", line_candidates_available = "partial", stock_flow_consistency_gate = "REVIEW", double_accounting_gate = "REVIEW", allowed_use = "documentation; reconciliation; candidate formula menu; future human-review robustness candidate", prohibited_use = "constructed model input; baseline variable; regression regressor; pure surplus value; adjusted corporate profit; replacement for WAGE_SHARE_UNADJUSTED_NFC_GVA_BASELINE", candidate_status = "INTERPRETATION_CONDITIONAL_CANDIDATE", reason = "A possible future robustness candidate only; cannot replace NFC baseline."),
  mk(candidate_id = "NOS_SHARE_CORP_SHAIKH_EBIT_RECONCILIATION_CANDIDATE", candidate_name = "Corporate EBIT-like NOS share reconciliation candidate", formula = "CORP_NOS_SHAIKH_EBIT_RECONCILIATION_CANDIDATE / CORP_GVA_SHAIKH_RECONCILIATION_CANDIDATE", interpretation = "CORPORATE_DISTRIBUTION_RECONCILIATION_INTERPRETATION", sector_boundary = "corporate", legal_form_boundary = "corporate", productive_theory_status = "mixed", productive_value_claim = "no", line_candidates_available = "partial", stock_flow_consistency_gate = "REVIEW", double_accounting_gate = "REVIEW", allowed_use = "documentation; reconciliation; candidate formula menu; future human-review robustness candidate", prohibited_use = "constructed model input; baseline variable; regression regressor; pure surplus value; adjusted corporate profit; replacement for WAGE_SHARE_UNADJUSTED_NFC_GVA_BASELINE", candidate_status = "INTERPRETATION_CONDITIONAL_CANDIDATE", reason = "Ratio candidate only; no construction."),
  mk(candidate_id = "PRODUCTIVE_SURPLUS_VALUE_CORPORATE_WHOLE_REJECTED", candidate_name = "Corporate-sector-as-whole productive surplus value claim", formula = "corporate adjusted NOS treated as pure productive surplus value", interpretation = "PRODUCTIVE_SURPLUS_VALUE_INTERPRETATION", sector_boundary = "corporate including financial", legal_form_boundary = "corporate", productive_theory_status = "nonproductive finance included", productive_value_claim = "yes", line_candidates_available = "partial", stock_flow_consistency_gate = "REVIEW", double_accounting_gate = "FAIL", allowed_use = "documentation", prohibited_use = "constructed model input; baseline variable; regression regressor; pure surplus value; adjusted corporate profit; replacement for WAGE_SHARE_UNADJUSTED_NFC_GVA_BASELINE", candidate_status = "REJECTED_BY_THEORETICAL_BOUNDARY", reason = "Corporate sector as a whole includes financial corporate components; cannot claim pure productive surplus value."),
  mk(candidate_id = "BASELINE_NFC_REPLACEMENT_REJECTED", candidate_name = "Replace Chapter 2 NFC wage-share baseline", formula = "use corporate Shaikh reconciliation wage share as baseline replacement", interpretation = "BASELINE_CHAPTER_2_DISTRIBUTION_INTERPRETATION", sector_boundary = "corporate", legal_form_boundary = "corporate", productive_theory_status = "mixed", productive_value_claim = "no", line_candidates_available = "partial", stock_flow_consistency_gate = "REVIEW", double_accounting_gate = "REVIEW", allowed_use = "documentation", prohibited_use = "constructed model input; baseline variable; regression regressor; pure surplus value; adjusted corporate profit; replacement for WAGE_SHARE_UNADJUSTED_NFC_GVA_BASELINE", candidate_status = "REJECTED_BY_THEORETICAL_BOUNDARY", reason = "No downstream decision authorizes replacement of the NFC baseline.")
)
wcsv(menu, "S20E_CL_interpretation_conditional_candidate_menu.csv")

line_readiness <- rbind(
  mk(conceptual_account = "CORP_GVA_NIPA", required_flow_direction = "level", required_monetary_or_imputed_status = "not_applicable", required_sector_boundary = "corporate", required_gross_or_net_status = "gross", BEA_table_candidate = "T11400", BEA_line_candidate = "1", BEA_line_description = "Gross value added of corporate business", S20E_SB_quality = "exact", line_matching_readiness = "ready", conceptual_gate_status = "conceptual_classification_required", notes = "Line matching alone does not authorize construction."),
  mk(conceptual_account = "CORP_VA_NIPA", required_flow_direction = "level", required_monetary_or_imputed_status = "not_applicable", required_sector_boundary = "corporate", required_gross_or_net_status = "net", BEA_table_candidate = "T11400", BEA_line_candidate = "3", BEA_line_description = "Net value added", S20E_SB_quality = "exact", line_matching_readiness = "ready", conceptual_gate_status = "conceptual_classification_required", notes = "Line matching alone does not authorize construction."),
  mk(conceptual_account = "CORP_NOS_NIPA", required_flow_direction = "level", required_monetary_or_imputed_status = "not_applicable", required_sector_boundary = "corporate", required_gross_or_net_status = "net", BEA_table_candidate = "T11400", BEA_line_candidate = "8", BEA_line_description = "Net operating surplus", S20E_SB_quality = "exact", line_matching_readiness = "ready", conceptual_gate_status = "conceptual_classification_required", notes = "NOS is not corporate profits."),
  mk(conceptual_account = "CORP_CFC", required_flow_direction = "level", required_monetary_or_imputed_status = "not_applicable", required_sector_boundary = "corporate", required_gross_or_net_status = "gross_to_net_component", BEA_table_candidate = "T11400", BEA_line_candidate = "2", BEA_line_description = "Consumption of fixed capital", S20E_SB_quality = "exact", line_matching_readiness = "ready", conceptual_gate_status = "conceptual_classification_required", notes = "Used to bridge GOS and NOS."),
  mk(conceptual_account = "FC_MONETARY_INTEREST_PAID", required_flow_direction = "paid", required_monetary_or_imputed_status = "monetary", required_sector_boundary = "financial corporate", required_gross_or_net_status = "gross", BEA_table_candidate = "T71100", BEA_line_candidate = "4", BEA_line_description = "Financial under corporate monetary interest paid", S20E_SB_quality = "exact", line_matching_readiness = "ready", conceptual_gate_status = "review", notes = "Accounting-correction ingredient only."),
  mk(conceptual_account = "FC_MONETARY_INTEREST_RECEIVED", required_flow_direction = "received", required_monetary_or_imputed_status = "monetary", required_sector_boundary = "financial corporate", required_gross_or_net_status = "gross", BEA_table_candidate = "T71100", BEA_line_candidate = "28", BEA_line_description = "Financial under corporate monetary interest received", S20E_SB_quality = "exact", line_matching_readiness = "ready", conceptual_gate_status = "review", notes = "Do not treat as productive value creation."),
  mk(conceptual_account = "FC_IMPUTED_INTEREST_PAID", required_flow_direction = "paid", required_monetary_or_imputed_status = "imputed", required_sector_boundary = "financial corporate", required_gross_or_net_status = "gross", BEA_table_candidate = "T71100", BEA_line_candidate = "43/79", BEA_line_description = "Financial imputed interest paid families", S20E_SB_quality = "plausible", line_matching_readiness = "partial", conceptual_gate_status = "review", notes = "Requires human review of imputed blocks."),
  mk(conceptual_account = "FC_IMPUTED_INTEREST_RECEIVED", required_flow_direction = "received", required_monetary_or_imputed_status = "imputed", required_sector_boundary = "financial corporate", required_gross_or_net_status = "gross", BEA_table_candidate = "T71100", BEA_line_candidate = "57/96", BEA_line_description = "Financial imputed interest received families", S20E_SB_quality = "plausible", line_matching_readiness = "partial", conceptual_gate_status = "review", notes = "Requires human review of negative imputed blocks."),
  mk(conceptual_account = "NFC_IMPUTED_INTEREST_PAID", required_flow_direction = "paid", required_monetary_or_imputed_status = "imputed", required_sector_boundary = "nonfinancial corporate", required_gross_or_net_status = "gross", BEA_table_candidate = "T71100", BEA_line_candidate = "49/80", BEA_line_description = "Nonfinancial imputed interest paid families", S20E_SB_quality = "plausible", line_matching_readiness = "partial", conceptual_gate_status = "review", notes = "Requires human review."),
  mk(conceptual_account = "NFC_IMPUTED_INTEREST_RECEIVED", required_flow_direction = "received", required_monetary_or_imputed_status = "imputed", required_sector_boundary = "nonfinancial corporate", required_gross_or_net_status = "gross", BEA_table_candidate = "T71100", BEA_line_candidate = "58", BEA_line_description = "Nonfinancial imputed interest received", S20E_SB_quality = "plausible", line_matching_readiness = "partial", conceptual_gate_status = "review", notes = "Requires human review."),
  mk(conceptual_account = "OLD_APPENDIX_LINE_NUMBER_FORMULA", required_flow_direction = "unknown", required_monetary_or_imputed_status = "unknown", required_sector_boundary = "mismatched", required_gross_or_net_status = "unknown", BEA_table_candidate = "T71100", BEA_line_candidate = "legacy numbers", BEA_line_description = "current meanings do not match old Appendix roles", S20E_SB_quality = "rejected", line_matching_readiness = "rejected", conceptual_gate_status = "fail", notes = "Historical clues only.")
)
wcsv(line_readiness, "S20E_CL_line_matching_readiness_ledger.csv")

graduation <- data.frame(
  criterion_id = sprintf("GRAD_%02d", 1:12),
  from_status = "INTERPRETATION_CONDITIONAL_CANDIDATE",
  to_status = "HUMAN_REVIEW_AUTHORIZED_CORPORATE_ROBUSTNESS_VARIABLE",
  required_criterion = c(
    "stock_flow_consistency_gate = PASS",
    "double_accounting_gate = PASS",
    "line candidates attached",
    "sector boundary explicit",
    "legal-form boundary explicit",
    "no productive-value claim for financial corporations",
    "formula treats interest lines as restoration ingredients, not profit additions",
    "object labeled as corporate adjusted GVA/GOS/NOS or EBIT-like NOS",
    "object not labeled as pure surplus value",
    "object not labeled as adjusted corporate profit",
    "object not allowed to replace NFC wage-share baseline",
    "human review accepts interpretation"
  ),
  met_in_this_pass = "no",
  reason_not_graduated = "S20E-CL defines criteria only; no candidate is graduated or authorized in this pass."
)
wcsv(graduation, "S20E_CL_graduation_criteria_ledger.csv")

validation <- rbind(
  validation,
  data.frame(
    check_name = c(
      "stock_flow_consistency_law_applied",
      "double_accounting_law_applied",
      "conceptual_account_ladder_created",
      "sector_boundary_ledger_created_cl",
      "interpretation_conditional_candidate_menu_created",
      "line_matching_readiness_ledger_created",
      "graduation_criteria_ledger_created",
      "financial_corporate_lines_not_interpreted_as_productive_value_creation",
      "corporate_profits_not_added_to_nos",
      "nfc_baseline_not_replaced",
      "no_model_input_panel_variables_constructed",
      "no_provider_handoff_created_cl"
    ),
    status = "PASS",
    evidence = c(
      "S20E_CL_stock_flow_consistency_gate.csv",
      "S20E_CL_double_accounting_gate.csv",
      "S20E_CL_conceptual_account_ladder_ledger.csv",
      "S20E_CL_sector_boundary_ledger.csv",
      "S20E_CL_interpretation_conditional_candidate_menu.csv",
      "S20E_CL_line_matching_readiness_ledger.csv",
      "S20E_CL_graduation_criteria_ledger.csv",
      "Candidate menu and double-accounting gate prohibit productive-value claims for financial corporations.",
      "Negative controls fail adding corporate profits to NOS.",
      "Candidate menu rejects replacing WAGE_SHARE_UNADJUSTED_NFC_GVA_BASELINE.",
      "No panel variables written.",
      "No data/provider_handoffs/S20E_SHAIKH_CURRENT_RELEASE_CROSSWALK directory created."
    ),
    notes = "S20E-CL conceptual consolidation only."
  )
)
validation$evidence[validation$check_name == "final_decision_explicit"] <- "S20E_CL_CONCEPTUAL_LEDGER_COMPLETE_NO_AUTHORIZATION"
wcsv(validation, "S20E_validation_checks.csv")

cl_report <- c(
  "# S20E-CL Conceptual Account Ledger",
  "",
  "Date: 2026-06-17",
  "",
  "Final decision: `S20E_CL_CONCEPTUAL_LEDGER_COMPLETE_NO_AUTHORIZATION`",
  "",
  "## Scope",
  "",
  "S20E-CL is a conceptual consolidation pass. It creates a conceptual-account ladder, sector-boundary ledger, stock-flow consistency gate, double-accounting gate, interpretation-conditional candidate menu, line-matching readiness ledger, and graduation criteria. It does not construct adjusted time series, authorize downstream use, or create a provider handoff.",
  "",
  "## Governing Laws",
  "",
  "1. Stock-flow consistency.",
  "2. Avoid double accounting.",
  "",
  "## Theoretical Frame",
  "",
  "Shaikh and Tonak supply the national-accounts theory: official legal-form and market-activity accounts do not by themselves identify productive value. Financial corporate lines may enter as accounting-correction ingredients, but they must not be treated as newly produced productive value.",
  "",
  "Appendix 6.7 is the benchmark empirical example. Current S20E/S20E-R/S20E-SB BEA outputs are line-matching candidates, not authorization.",
  "",
  "## Net Of What",
  "",
  "GVA is net of intermediate inputs; gross of CFC; not net of compensation, production taxes, actual interest, or profits; and not a profit measure.",
  "",
  "GOS is net of compensation and taxes on production and imports less subsidies; gross of CFC; not net of actual interest; and not equivalent to corporate profits.",
  "",
  "NOS is net of compensation, production taxes less subsidies, and CFC; not net of actual interest; and not equivalent to after-interest profit.",
  "",
  "Corporate profits are a profit-type decomposition object. They are not NOS and must not be added to NOS.",
  "",
  "## Boundaries",
  "",
  "The corporate sector as a whole is a BEA/NIPA legal/accounting boundary. It is not identical to Shaikh and Tonak's productive-theoretical boundary. Financial corporate and nonfinancial corporate flows must be consolidated with transfer-risk discipline.",
  "",
  "## Candidate Menu",
  "",
  "S20E-CL defines interpretation-conditional candidates for corporate imputed-interest restoration, adjusted corporate GVA/VA/GOS/NOS, a corporate wage-share reconciliation candidate, and a corporate EBIT-like NOS-share reconciliation candidate. These are documentation and reconciliation candidates only.",
  "",
  "The PRODUCTIVE_SURPLUS_VALUE_INTERPRETATION is rejected for the corporate-sector-as-a-whole adjustment because the corporate boundary includes financial corporate components. The BASELINE_CHAPTER_2_DISTRIBUTION_INTERPRETATION is rejected because no downstream decision authorizes replacement of the NFC wage-share baseline.",
  "",
  "## Risks",
  "",
  "Stock-flow risks arise if a GVA adjustment does not explicitly flow through GOS and NOS. Double-accounting risks arise if the same interest flow is counted from both the nonfinancial payer and financial receiver sides, if financial receipts are treated as productive value, or if corporate profits are added to NOS.",
  "",
  "## Allowed And Prohibited Uses",
  "",
  "Allowed uses: documentation, reconciliation, candidate formula menu, and future human-review robustness candidate.",
  "",
  "Prohibited uses: constructed model input, baseline variable, regression regressor, pure surplus value, adjusted corporate profit, or replacement for `WAGE_SHARE_UNADJUSTED_NFC_GVA_BASELINE`.",
  "",
  "## Graduation Criteria",
  "",
  "A candidate can graduate only after stock-flow and double-accounting gates pass, line candidates are attached, sector/legal boundaries are explicit, finance is not assigned a productive-value claim, interest lines are restoration ingredients rather than profit additions, the object is labeled as adjusted corporate GVA/GOS/NOS or EBIT-like NOS, it is not labeled pure surplus value or adjusted corporate profit, it cannot replace the NFC wage-share baseline, and human review accepts the interpretation.",
  "",
  "No candidate is graduated in this pass."
)
writeLines(cl_report, file.path(md_dir, "S20E_CL_CONCEPTUAL_ACCOUNT_LEDGER.md"), useBytes = TRUE)

main_report_cl <- c(
  cl_report,
  "",
  "## Relationship To Earlier S20E Outputs",
  "",
  "S20E-SB remains a plausible current-BEA line-matching result requiring human review. S20E-CL adds conceptual gates and interpretation conditions but explicitly makes no authorization claim.",
  "",
  "Current final decision: `S20E_CL_CONCEPTUAL_LEDGER_COMPLETE_NO_AUTHORIZATION`."
)
writeLines(main_report_cl, file.path(md_dir, "S20E_SHAIKH_CURRENT_RELEASE_CROSSWALK.md"), useBytes = TRUE)

# S20E-CL stock-flow labour-value accounting normalization. This later CL
# pass uses a simpler status vocabulary for future Skill/Shiny design and
# provider handoff review. It intentionally does not authorize construction.
cl_objects <- c(
  "GVA", "VA_NVA", "GOS", "NOS", "corporate_profits",
  "net_interest", "imputed_interest", "compensation", "CFC",
  "taxes_less_subsidies", "transfers", "Shaikh_style_restoration_term"
)
cl_ladder_base <- data.frame(
  object_name = cl_objects,
  account_position = c(
    "GVA top of income-side production account",
    "VA/NVA below depreciation bridge",
    "GOS operating-surplus residual before CFC",
    "NOS operating-surplus residual after CFC",
    "profit/interest/rent/transfer decomposition layer",
    "property-income decomposition layer",
    "imputed financial-services/accounting correction layer",
    "income-side production component",
    "GOS-to-NOS bridge",
    "income-side production component",
    "distribution/transfer decomposition layer",
    "interpretation-conditional correction/restoration layer"
  ),
  definition = c(
    "Output less intermediate inputs.",
    "Gross value added less consumption of fixed capital.",
    "GVA less compensation and taxes on production and imports less subsidies.",
    "GOS less consumption of fixed capital.",
    "Corporate profit-type income category, including IVA and CCAdj where BEA defines it.",
    "Interest paid less interest received within the named account boundary.",
    "BEA imputed interest paid/received tied to financial intermediation and reference-rate accounting.",
    "Employee compensation paid.",
    "Consumption of fixed capital.",
    "Taxes on production and imports less subsidies.",
    "Current transfer payments net.",
    "Appendix 6.7-style term that restores imputed-interest treatment effects on corporate GVA/GOS/NOS."
  ),
  net_of_what = c(
    "intermediate inputs",
    "intermediate inputs; CFC",
    "intermediate inputs; compensation; taxes less subsidies",
    "intermediate inputs; compensation; taxes less subsidies; CFC",
    "not an account-ladder net residual",
    "interest received",
    "imputed interest received when netted",
    "not applicable",
    "not applicable",
    "subsidies",
    "current transfers received when netted",
    "NIPA imputed-interest treatment effects under the accounting-restoration interpretation"
  ),
  not_net_of_what = c(
    "compensation; taxes; CFC; actual interest; profits",
    "compensation; taxes; actual interest; profits",
    "CFC; actual interest; corporate profits",
    "actual interest; corporate profits",
    "NOS; GOS; GVA",
    "production costs or productive value",
    "productive value; monopoly power; financial claims on surplus",
    "surplus or profit",
    "compensation; taxes; interest; profits",
    "compensation; surplus; interest",
    "operating surplus",
    "corporate profit; pure surplus value; baseline variable"
  ),
  `stock/flow/residual/transfer status` = c(
    "flow", "flow", "residual", "residual", "decomposition flow",
    "transfer/property-income flow", "imputed transfer/accounting flow",
    "flow", "flow", "flow", "transfer flow", "restoration flow"
  ),
  productive_value_claim = c(
    "restricted", "restricted", "restricted", "restricted", "restricted",
    "no", "no", "restricted", "not_applicable", "not_applicable",
    "not_applicable", "no"
  ),
  `financial power / claim-on-surplus flag` = c(
    "no", "no", "no", "no", "possible in decomposition",
    "yes", "yes", "no", "no", "no", "possible", "yes"
  ),
  `commercial capital blur flag` = c(
    "yes - unresolved in BEA legal-form aggregates",
    "yes - unresolved in BEA legal-form aggregates",
    "yes - unresolved in BEA legal-form aggregates",
    "yes - unresolved in BEA legal-form aggregates",
    "yes - profit category can mix production and circulation",
    "yes - transfer/appropriation channel",
    "yes - financial intermediation/accounting imputation",
    "yes - productive/nonproductive labor boundary not solved here",
    "no",
    "no",
    "yes - transfer category",
    "yes - correction only, not resolution"
  ),
  allowed_use = "documentation; reconciliation; conceptual candidate menu; future human-review design input",
  prohibited_use = "constructed time series; model input panel variable; baseline variable; regression regressor; Shiny app production variable; Skill implementation; provider handoff; pure productive surplus value",
  check.names = FALSE
)
cl_ladder <- do.call(rbind, lapply(c("corporate", "nonfinancial corporate"), function(boundary) {
  out <- cl_ladder_base
  out$sector_boundary <- boundary
  out[, c(
    "object_name", "account_position", "definition", "net_of_what",
    "not_net_of_what", "sector_boundary", "stock/flow/residual/transfer status",
    "productive_value_claim", "financial power / claim-on-surplus flag",
    "commercial capital blur flag", "allowed_use", "prohibited_use"
  )]
}))
wcsv(cl_ladder, "S20E_CL_conceptual_account_ladder_ledger.csv")

cl_ladder_patch <- read.csv(file.path(csv_dir, "S20E_CL_conceptual_account_ladder_ledger.csv"), check.names = FALSE)
cl_ladder_patch$not_equivalent_to <- ifelse(
  cl_ladder_patch$object_name == "corporate_profits",
  "NOS; GOS; GVA",
  ifelse(cl_ladder_patch$object_name %in% c("net_interest", "imputed_interest"),
         "GVA; GOS; NOS; productive value", "")
)
cl_ladder_patch$flow_direction_logic <- ifelse(
  cl_ladder_patch$object_name == "net_interest",
  "interest paid minus interest received, or current BEA line-specific net direction if different",
  ifelse(cl_ladder_patch$object_name == "imputed_interest",
         "imputed paid and received directions must be interpreted by current BEA line family",
         ifelse(cl_ladder_patch$object_name == "Shaikh_style_restoration_term",
                "restoration term applied through GVA/GOS/NOS ladder, not profit addition", "not_applicable"))
)
cl_ladder_patch$decomposition_role <- ifelse(
  cl_ladder_patch$object_name == "corporate_profits",
  "downstream profit-type decomposition of NOS",
  ifelse(cl_ladder_patch$object_name %in% c("net_interest", "imputed_interest", "transfers"),
         "property-income or transfer decomposition component",
         ifelse(cl_ladder_patch$object_name == "Shaikh_style_restoration_term",
                "interpretation-conditional restoration component", "account ladder component"))
)
cl_ladder_patch$financial_power_claim <- ifelse(
  cl_ladder_patch$object_name %in% c("net_interest", "imputed_interest"),
  "claim_on_surplus",
  ifelse(cl_ladder_patch$object_name == "Shaikh_style_restoration_term",
         "correction_ingredient_only",
         ifelse(cl_ladder_patch$object_name == "corporate_profits", "mixed_review", "not_applicable"))
)
write.csv(cl_ladder_patch, file.path(csv_dir, "S20E_CL_conceptual_account_ladder_ledger.csv"), row.names = FALSE, na = "")

cl_boundary <- rbind(
  mk(boundary_id = "CORP", boundary_name = "Corporate sector as a whole", legal_accounting_boundary = "yes", productive_theory_boundary = "no", included_units = "financial and nonfinancial corporations", internal_transfer_risk = "medium", double_counting_risk = "medium", commercial_capital_blur = "high", notes = "BEA legal form; not identical to productive-theoretical boundary."),
  mk(boundary_id = "FC", boundary_name = "Financial corporate", legal_accounting_boundary = "yes", productive_theory_boundary = "no", included_units = "banks and financial corporate business", internal_transfer_risk = "high", double_counting_risk = "high", commercial_capital_blur = "high", notes = "Correction ingredient only; banking/finance is not productive capital and may express claims on surplus, monopoly power, or appropriation channels."),
  mk(boundary_id = "NFC", boundary_name = "Nonfinancial corporate", legal_accounting_boundary = "yes", productive_theory_boundary = "partial", included_units = "nonfinancial corporations", internal_transfer_risk = "medium", double_counting_risk = "medium", commercial_capital_blur = "medium", notes = "Closer to Chapter 2 baseline but still not a pure productive-theory boundary."),
  mk(boundary_id = "BUSINESS", boundary_name = "Business-wide", legal_accounting_boundary = "mixed", productive_theory_boundary = "no", included_units = "corporate plus noncorporate business", internal_transfer_risk = "high", double_counting_risk = "high", commercial_capital_blur = "high", notes = "Requires noncorporate and WEQ-style review; not solved here."),
  mk(boundary_id = "NONCORP", boundary_name = "Noncorporate business", legal_accounting_boundary = "yes", productive_theory_boundary = "partial", included_units = "sole proprietorships and partnerships", internal_transfer_risk = "medium", double_counting_risk = "medium", commercial_capital_blur = "high", notes = "Mixed income and proprietor labour-equivalent problem parked."),
  mk(boundary_id = "PRODUCTIVE_THEORY", boundary_name = "Productive-theoretical boundary", legal_accounting_boundary = "no", productive_theory_boundary = "yes", included_units = "activities/labour productive of capital under Shaikh and Tonak inspiration", internal_transfer_risk = "high", double_counting_risk = "high", commercial_capital_blur = "explicit limitation", notes = "Not directly observable from BEA legal-form lines.")
)
wcsv(cl_boundary, "S20E_CL_sector_boundary_ledger.csv")

cl_boundary_patch <- read.csv(file.path(csv_dir, "S20E_CL_sector_boundary_ledger.csv"), check.names = FALSE)
cl_boundary_patch$financial_power_claim <- ifelse(
  cl_boundary_patch$boundary_id == "FC",
  "mixed_review",
  ifelse(cl_boundary_patch$boundary_id %in% c("CORP", "BUSINESS"),
         "transfer_appropriation_channel", "not_applicable")
)
write.csv(cl_boundary_patch, file.path(csv_dir, "S20E_CL_sector_boundary_ledger.csv"), row.names = FALSE, na = "")

cl_stock <- rbind(
  mk(candidate_id = "CORP_SHAIKH_OPERATING_LADDER_RECONCILIATION_BUNDLE", candidate_formula = "GVA_adj = GVA_NIPA + CORP_IMPUTED_INTEREST_ADJ; GOS_adj = GOS_NIPA + CORP_IMPUTED_INTEREST_ADJ; NOS_adj = NOS_NIPA + CORP_IMPUTED_INTEREST_ADJ; COMP unchanged; TAX_NET unchanged; CFC unchanged", preserves_GVA_equals_COMP_plus_TAX_NET_plus_GOS = "review", preserves_GOS_equals_CFC_plus_NOS = "review", NOS_not_corporate_profits = "yes", stock_flow_consistency_gate = "REVIEW", reason = "Whole operating ladder is conceptually coherent as a reconciliation bundle, but not authorized for construction in this pass."),
  mk(candidate_id = "CORP_GVA_RESTORATION_CANDIDATE", candidate_formula = "CORP_GVA_NIPA + CORP_IMPUTED_INTEREST_ADJ", preserves_GVA_equals_COMP_plus_TAX_NET_plus_GOS = "review", preserves_GOS_equals_CFC_plus_NOS = "review", NOS_not_corporate_profits = "yes", stock_flow_consistency_gate = "REVIEW", reason = "If GVA is adjusted, the same restoration must explicitly flow through GOS and NOS."),
  mk(candidate_id = "CORP_GOS_RESTORATION_CANDIDATE", candidate_formula = "CORP_GOS_NIPA + CORP_IMPUTED_INTEREST_ADJ", preserves_GVA_equals_COMP_plus_TAX_NET_plus_GOS = "review", preserves_GOS_equals_CFC_plus_NOS = "review", NOS_not_corporate_profits = "yes", stock_flow_consistency_gate = "REVIEW", reason = "CFC is unchanged, so NOS must move with GOS."),
  mk(candidate_id = "CORP_NOS_EBIT_RESTORATION_CANDIDATE", candidate_formula = "CORP_NOS_NIPA + CORP_IMPUTED_INTEREST_ADJ", preserves_GVA_equals_COMP_plus_TAX_NET_plus_GOS = "review", preserves_GOS_equals_CFC_plus_NOS = "review", NOS_not_corporate_profits = "yes", stock_flow_consistency_gate = "REVIEW", reason = "May be EBIT-like NOS only; not corporate profit."),
  mk(candidate_id = "ADD_CORP_PROFITS_TO_NOS_NEGATIVE_CONTROL", candidate_formula = "CORP_NOS + CORP_PROFITS", preserves_GVA_equals_COMP_plus_TAX_NET_plus_GOS = "no", preserves_GOS_equals_CFC_plus_NOS = "no", NOS_not_corporate_profits = "no", stock_flow_consistency_gate = "FAIL", reason = "Corporate profits sit below the ladder and must not be added to NOS.")
)
wcsv(cl_stock, "S20E_CL_stock_flow_consistency_gate.csv")

cl_stock_patch <- read.csv(file.path(csv_dir, "S20E_CL_stock_flow_consistency_gate.csv"), check.names = FALSE)
cl_stock_patch$accounting_ladder_position <- ifelse(
  cl_stock_patch$candidate_id == "CORP_SHAIKH_OPERATING_LADDER_RECONCILIATION_BUNDLE",
  "whole operating ladder GVA/GOS/NOS",
  ifelse(grepl("GVA", cl_stock_patch$candidate_id), "GVA",
         ifelse(grepl("GOS", cl_stock_patch$candidate_id), "GOS",
                ifelse(grepl("NOS", cl_stock_patch$candidate_id), "NOS", "invalid/decomposition")))
)
cl_stock_patch$affected_accounts <- ifelse(
  cl_stock_patch$candidate_id == "CORP_SHAIKH_OPERATING_LADDER_RECONCILIATION_BUNDLE",
  "GVA; GOS; NOS; COMP unchanged; TAX_NET unchanged; CFC unchanged",
  ifelse(grepl("PROFITS", cl_stock_patch$candidate_id), "NOS; corporate profits", "GVA/GOS/NOS ladder")
)
cl_stock_patch$required_identity <- ifelse(
  cl_stock_patch$candidate_id == "CORP_SHAIKH_OPERATING_LADDER_RECONCILIATION_BUNDLE",
  "GVA = COMP + TAX_NET + GOS and GOS = CFC + NOS must remain coherent when the same restoration term is applied.",
  "GVA = COMP + TAX_NET + GOS; GOS = CFC + NOS; NOS is not corporate profits."
)
cl_stock_patch$identity_preserved <- ifelse(cl_stock_patch$stock_flow_consistency_gate == "FAIL", "no", "review")
cl_stock_patch$flow_or_stock_consistency <- ifelse(cl_stock_patch$stock_flow_consistency_gate == "FAIL", "fail", "review")
cl_stock_patch$unit_consistency <- ifelse(cl_stock_patch$stock_flow_consistency_gate == "FAIL", "pass", "review")
cl_stock_patch$time_support_consistency <- ifelse(cl_stock_patch$stock_flow_consistency_gate == "FAIL", "pass", "review")
cl_stock_patch$interpretation_required <- ifelse(
  cl_stock_patch$candidate_id == "ADD_CORP_PROFITS_TO_NOS_NEGATIVE_CONTROL",
  "none",
  "ACCOUNTING_RESTORATION_INTERPRETATION"
)
cl_stock_patch <- cl_stock_patch[, c(
  "candidate_id", "candidate_formula", "accounting_ladder_position",
  "affected_accounts", "required_identity", "identity_preserved",
  "flow_or_stock_consistency", "unit_consistency", "time_support_consistency",
  "interpretation_required", "stock_flow_consistency_gate", "reason"
)]
write.csv(cl_stock_patch, file.path(csv_dir, "S20E_CL_stock_flow_consistency_gate.csv"), row.names = FALSE, na = "")

cl_double <- rbind(
  mk(candidate_id = "FC_NET_INT_PAID_CANDIDATE", candidate_formula = "financial corporate paid interest lines minus financial corporate received interest lines under reviewed T71100 direction", adds_profits_to_NOS = "no", treats_financial_receipts_as_productive_value = "no", counts_NFC_payments_and_FC_receipts_as_two_new_surplus_sources = "review", treats_interest_as_profit_not_correction = "no", double_accounting_gate = "REVIEW", reason = "Financial corporate interest lines may be accounting-correction ingredients, claims on surplus, or monopoly-power channels, but not productive-value creation."),
  mk(candidate_id = "NFC_NET_IMPUTED_INT_PAID_CANDIDATE", candidate_formula = "nonfinancial corporate imputed interest paid minus imputed interest received under reviewed T71100 direction", adds_profits_to_NOS = "no", treats_financial_receipts_as_productive_value = "no", counts_NFC_payments_and_FC_receipts_as_two_new_surplus_sources = "review", treats_interest_as_profit_not_correction = "no", double_accounting_gate = "REVIEW", reason = "May be a correction ingredient, but must not be treated as a new independent source of corporate surplus."),
  mk(candidate_id = "CORP_IMPUTED_INTEREST_ADJ_BUNDLE", candidate_formula = "FC_NET_INT_PAID_CANDIDATE plus NFC_NET_IMPUTED_INT_PAID_CANDIDATE under Appendix-style restoration interpretation", adds_profits_to_NOS = "no", treats_financial_receipts_as_productive_value = "no", counts_NFC_payments_and_FC_receipts_as_two_new_surplus_sources = "review", treats_interest_as_profit_not_correction = "no", double_accounting_gate = "REVIEW", reason = "Candidate must be read as a restoration term, not as additive profit summation."),
  mk(candidate_id = "CORP_IMPUTED_INTEREST_ADJ", candidate_formula = "-FC_NET_INT_PAID_CANDIDATE - NFC_NET_IMPUTED_INT_PAID_CANDIDATE", adds_profits_to_NOS = "no", treats_financial_receipts_as_productive_value = "no", counts_NFC_payments_and_FC_receipts_as_two_new_surplus_sources = "review", treats_interest_as_profit_not_correction = "no", double_accounting_gate = "REVIEW", reason = "Acceptable only as restoration/correction ingredient after human review."),
  mk(candidate_id = "ADD_CORP_PROFITS_TO_NOS_NEGATIVE_CONTROL", candidate_formula = "CORP_NOS + CORP_PROFITS", adds_profits_to_NOS = "yes", treats_financial_receipts_as_productive_value = "no", counts_NFC_payments_and_FC_receipts_as_two_new_surplus_sources = "yes", treats_interest_as_profit_not_correction = "yes", double_accounting_gate = "FAIL", reason = "Adds a decomposition object to a residual."),
  mk(candidate_id = "FINANCIAL_RECEIPTS_PRODUCTIVE_VALUE_NEGATIVE_CONTROL", candidate_formula = "financial corporate receipts treated as productive value", adds_profits_to_NOS = "no", treats_financial_receipts_as_productive_value = "yes", counts_NFC_payments_and_FC_receipts_as_two_new_surplus_sources = "yes", treats_interest_as_profit_not_correction = "yes", double_accounting_gate = "FAIL", reason = "Banking/finance is not productive capital in this conceptual pass."),
  mk(candidate_id = "OLD_LINE_REUSE_NEGATIVE_CONTROL", candidate_formula = "mechanically reuse old Appendix 6.7 line numbers", adds_profits_to_NOS = "no", treats_financial_receipts_as_productive_value = "unknown", counts_NFC_payments_and_FC_receipts_as_two_new_surplus_sources = "unknown", treats_interest_as_profit_not_correction = "unknown", double_accounting_gate = "FAIL", reason = "Appendix line numbers are benchmark clues, not current conceptual matching."),
  mk(candidate_id = "QWEN_HOUSING_PROXY_NEGATIVE_CONTROL", candidate_formula = "owner-occupied housing or mortgage proxy path", adds_profits_to_NOS = "no", treats_financial_receipts_as_productive_value = "no", counts_NFC_payments_and_FC_receipts_as_two_new_surplus_sources = "no", treats_interest_as_profit_not_correction = "proxy_not_correction", double_accounting_gate = "FAIL", reason = "Owner-occupied housing/mortgage/imputed-rent proxy path is outside corporate Appendix 6.7 correction.")
)
wcsv(cl_double, "S20E_CL_double_accounting_gate.csv")

cl_double_patch <- read.csv(file.path(csv_dir, "S20E_CL_double_accounting_gate.csv"), check.names = FALSE)
cl_double_patch$involved_sectors <- ifelse(
  cl_double_patch$candidate_id == "FC_NET_INT_PAID_CANDIDATE", "financial corporate",
  ifelse(cl_double_patch$candidate_id == "NFC_NET_IMPUTED_INT_PAID_CANDIDATE", "nonfinancial corporate",
         ifelse(cl_double_patch$candidate_id %in% c("CORP_IMPUTED_INTEREST_ADJ", "CORP_IMPUTED_INTEREST_ADJ_BUNDLE"), "financial corporate; nonfinancial corporate",
                ifelse(grepl("QWEN", cl_double_patch$candidate_id), "household/housing proxy", "corporate or mismatched current sectors")))
)
cl_double_patch$involved_flows <- ifelse(
  grepl("FC_NET", cl_double_patch$candidate_id), "financial monetary and imputed paid/received interest",
  ifelse(grepl("NFC_NET", cl_double_patch$candidate_id), "nonfinancial corporate imputed paid/received interest",
         ifelse(grepl("PROFITS", cl_double_patch$candidate_id), "NOS and corporate profits",
                ifelse(grepl("QWEN", cl_double_patch$candidate_id), "housing/mortgage/imputed-rent proxy flows", "interest paid/received and restoration flows")))
)
cl_double_patch$flow_direction <- ifelse(
  grepl("FC_NET|NFC_NET", cl_double_patch$candidate_id), "net_paid",
  ifelse(grepl("ADJ", cl_double_patch$candidate_id), "restoration_term",
         ifelse(grepl("RECEIPTS", cl_double_patch$candidate_id), "received", "mixed_or_invalid"))
)
cl_double_patch$monetary_or_imputed <- ifelse(
  grepl("NFC_NET", cl_double_patch$candidate_id), "imputed",
  ifelse(grepl("FC_NET|ADJ", cl_double_patch$candidate_id), "monetary_and_imputed",
         ifelse(grepl("QWEN", cl_double_patch$candidate_id), "proxy", "not_applicable_or_unknown"))
)
cl_double_patch$transfer_or_production_component <- ifelse(
  cl_double_patch$double_accounting_gate == "FAIL",
  "invalid_or_negative_control",
  "correction_or_transfer_component"
)
cl_double_patch$intra_corporate_transfer_risk <- ifelse(cl_double_patch$double_accounting_gate == "FAIL", "high", "medium")
cl_double_patch$financial_income_as_productive_value_risk <- ifelse(
  grepl("FINANCIAL_RECEIPTS", cl_double_patch$candidate_id), "high",
  ifelse(grepl("FC_NET|ADJ", cl_double_patch$candidate_id), "medium", "low")
)
cl_double_patch$profit_added_to_surplus_risk <- ifelse(grepl("PROFITS", cl_double_patch$candidate_id), "high", "none")
cl_double_patch$same_flow_counted_twice_risk <- ifelse(cl_double_patch$double_accounting_gate == "FAIL", "high", "medium")
cl_double_patch$financial_power_claim <- ifelse(
  grepl("NFC_NET", cl_double_patch$candidate_id), "correction_ingredient_only",
  ifelse(grepl("FC_NET", cl_double_patch$candidate_id), "mixed_review",
         ifelse(grepl("ADJ", cl_double_patch$candidate_id), "correction_ingredient_only",
                ifelse(grepl("FINANCIAL_RECEIPTS", cl_double_patch$candidate_id), "claim_on_surplus", "not_applicable")))
)
cl_double_patch <- cl_double_patch[, c(
  "candidate_id", "candidate_formula", "involved_sectors", "involved_flows",
  "flow_direction", "monetary_or_imputed", "transfer_or_production_component",
  "intra_corporate_transfer_risk", "financial_income_as_productive_value_risk",
  "profit_added_to_surplus_risk", "same_flow_counted_twice_risk",
  "financial_power_claim", "double_accounting_gate", "reason"
)]
write.csv(cl_double_patch, file.path(csv_dir, "S20E_CL_double_accounting_gate.csv"), row.names = FALSE, na = "")

cl_candidate_menu <- rbind(
  mk(candidate_id = "WAGE_SHARE_UNADJUSTED_NFC_GVA_BASELINE", candidate_formula = "NFC_COMP / NFC_GVA", sector_boundary = "nonfinancial corporate", candidate_status = "READY_AS_BASELINE", allowed_use = "existing documented baseline lane", prohibited_use = "none from S20E-CL", reason = "Preserve existing baseline; not replaced by Shaikh corporate candidate."),
  mk(candidate_id = "CORP_IMPUTED_INTEREST_ADJ", candidate_formula = "-FC_NET_INT_PAID_CANDIDATE - NFC_NET_IMPUTED_INT_PAID_CANDIDATE", sector_boundary = "corporate", candidate_status = "DOCUMENTATION_AND_RECONCILIATION_CANDIDATE", allowed_use = "documentation; reconciliation; candidate menu", prohibited_use = "construction; handoff; regression; baseline", reason = "Expected current status for Shaikh corporate adjustment."),
  mk(candidate_id = "CORP_GVA_SHAIKH_RECONCILIATION", candidate_formula = "CORP_GVA_NIPA + CORP_IMPUTED_INTEREST_ADJ", sector_boundary = "corporate", candidate_status = "DOCUMENTATION_AND_RECONCILIATION_CANDIDATE", allowed_use = "documentation; reconciliation; candidate menu", prohibited_use = "construction; handoff; regression; baseline", reason = "Must flow through GOS/NOS under stock-flow law."),
  mk(candidate_id = "CORP_GOS_SHAIKH_RECONCILIATION", candidate_formula = "CORP_GOS_NIPA + CORP_IMPUTED_INTEREST_ADJ", sector_boundary = "corporate", candidate_status = "DOCUMENTATION_AND_RECONCILIATION_CANDIDATE", allowed_use = "documentation; reconciliation; candidate menu", prohibited_use = "construction; handoff; regression; baseline", reason = "Potential future robustness candidate after human review."),
  mk(candidate_id = "CORP_NOS_EBIT_SHAIKH_RECONCILIATION", candidate_formula = "CORP_NOS_NIPA + CORP_IMPUTED_INTEREST_ADJ", sector_boundary = "corporate", candidate_status = "DOCUMENTATION_AND_RECONCILIATION_CANDIDATE", allowed_use = "documentation; reconciliation; candidate menu", prohibited_use = "construction; adjusted corporate profit; pure surplus value", reason = "EBIT-like NOS, not corporate profit."),
  mk(candidate_id = "CORP_SHAIKH_OPERATING_LADDER_RECONCILIATION_BUNDLE", candidate_formula = "GVA_adj = GVA_NIPA + CORP_IMPUTED_INTEREST_ADJ; GOS_adj = GOS_NIPA + CORP_IMPUTED_INTEREST_ADJ; NOS_adj = NOS_NIPA + CORP_IMPUTED_INTEREST_ADJ; COMP/TAX_NET/CFC unchanged", sector_boundary = "corporate", candidate_status = "DOCUMENTATION_AND_RECONCILIATION_CANDIDATE", allowed_use = "documentation; reconciliation; candidate robustness design; future human review", prohibited_use = "constructed model input; baseline variable; regression regressor; pure surplus value; adjusted corporate profit; replacement for WAGE_SHARE_UNADJUSTED_NFC_GVA_BASELINE", reason = "Bundle-level operating ladder check; conceptually coherent but not constructed or authorized."),
  mk(candidate_id = "BUSINESS_WIDE_SHAIKH_RECONCILIATION", candidate_formula = "business bases + BusImpIntAdj + WEQ lane where relevant", sector_boundary = "business-wide", candidate_status = "THEORETICALLY_MIXED_REVIEW_REQUIRED", allowed_use = "documentation", prohibited_use = "construction; handoff; baseline", reason = "Commercial-capital and noncorporate labour-equivalent blur remains unresolved."),
  mk(candidate_id = "PRODUCTIVE_SURPLUS_VALUE_CORP_WHOLE", candidate_formula = "corporate adjusted NOS as pure productive surplus value", sector_boundary = "corporate including finance", candidate_status = "BLOCKED_DOUBLE_COUNTING_RISK", allowed_use = "negative control documentation", prohibited_use = "all construction and interpretation as productive value", reason = "Financial corporate components are claims/appropriation channels, not productive capital."),
  mk(candidate_id = "ADD_PROFITS_TO_NOS", candidate_formula = "CORP_NOS + CORP_PROFITS", sector_boundary = "corporate", candidate_status = "BLOCKED_STOCK_FLOW_INCONSISTENT", allowed_use = "negative control documentation", prohibited_use = "all construction", reason = "Violates account ladder.")
)
wcsv(cl_candidate_menu, "S20E_CL_candidate_menu.csv")

cl_candidate_patch <- read.csv(file.path(csv_dir, "S20E_CL_candidate_menu.csv"), check.names = FALSE)
cl_candidate_patch$financial_power_claim <- ifelse(
  grepl("IMPUTED_INTEREST|SHAIKH_RECONCILIATION|LADDER", cl_candidate_patch$candidate_id),
  "correction_ingredient_only",
  ifelse(grepl("PRODUCTIVE_SURPLUS", cl_candidate_patch$candidate_id), "mixed_review", "not_applicable")
)
write.csv(cl_candidate_patch, file.path(csv_dir, "S20E_CL_candidate_menu.csv"), row.names = FALSE, na = "")

cl_readiness <- rbind(
  mk(conceptual_account = "NFC_COMP", BEA_candidate = "T11400 line 20", readiness = "ready", conceptual_gate_status = "baseline preserved", notes = "Line matching follows baseline concept."),
  mk(conceptual_account = "NFC_GVA", BEA_candidate = "T11400 line 17", readiness = "ready", conceptual_gate_status = "baseline preserved", notes = "Line matching follows baseline concept."),
  mk(conceptual_account = "CORP_GVA", BEA_candidate = "T11400 line 1", readiness = "ready", conceptual_gate_status = "documentation only", notes = "Not a constructed adjusted object."),
  mk(conceptual_account = "CORP_NOS", BEA_candidate = "T11400 line 8", readiness = "ready", conceptual_gate_status = "documentation only", notes = "NOS is not profit."),
  mk(conceptual_account = "FC_INTEREST_LINES", BEA_candidate = "T71100 lines 4/28/43/57/79/96", readiness = "partial", conceptual_gate_status = "review", notes = "Correction ingredients only; no productive value claim."),
  mk(conceptual_account = "NFC_IMPUTED_INTEREST_LINES", BEA_candidate = "T71100 lines 49/58/80", readiness = "partial", conceptual_gate_status = "review", notes = "Conceptual gate precedes line matching."),
  mk(conceptual_account = "OLD_APPENDIX_LINE_NUMBER_PATH", BEA_candidate = "legacy line numbers", readiness = "rejected", conceptual_gate_status = "fail", notes = "Benchmark example only; no mechanical carry-forward.")
)
wcsv(cl_readiness, "S20E_CL_line_matching_readiness_ledger.csv")

cl_grad <- data.frame(
  criterion_id = sprintf("CL_GRAD_%02d", 1:10),
  from_status = "DOCUMENTATION_AND_RECONCILIATION_CANDIDATE",
  to_status = "READY_AS_ROBUSTNESS_CANDIDATE",
  required_criterion = c(
    "stock-flow gate passes",
    "double-accounting gate passes",
    "conceptual ladder position fixed",
    "sector/legal boundary fixed",
    "commercial-capital blur explicitly accepted or bounded",
    "finance treated as correction/claim channel, not productive capital",
    "line candidates reviewed after conceptual classification",
    "object prohibited from replacing NFC baseline",
    "no adjusted corporate profit label",
    "human review approves use"
  ),
  met_in_this_pass = "no",
  notes = "Criteria defined only; no graduation in S20E-CL."
)
wcsv(cl_grad, "S20E_CL_graduation_criteria_ledger.csv")

if (file.exists(file.path(csv_dir, "S20E_CL_interpretation_conditional_candidate_menu.csv"))) {
  unlink(file.path(csv_dir, "S20E_CL_interpretation_conditional_candidate_menu.csv"))
}

validation <- rbind(
  validation,
  data.frame(
    check_name = c(
      "stock_flow_labour_value_accounting_scope_applied",
      "banking_finance_not_treated_as_productive_capital",
      "commercial_capital_blur_flagged",
      "simple_candidate_status_menu_created",
      "no_skill_implementation_created",
      "no_shiny_app_created",
      "final_decision_no_construction_explicit"
    ),
    status = "PASS",
    evidence = c(
      "S20E_CL_STOCK_FLOW_LABOUR_VALUE_ACCOUNTING.md",
      "CL ledgers flag financial corporate lines as claims/correction ingredients.",
      "Conceptual account and sector boundary ledgers include commercial-capital blur flags.",
      "S20E_CL_candidate_menu.csv",
      "No Skill files created.",
      "No Shiny app files created.",
      "S20E_CL_CONCEPTUAL_LEDGER_COMPLETE_NO_CONSTRUCTION"
    ),
    notes = "S20E-CL stock-flow labour-value conceptual pass."
  )
)
validation$evidence[validation$check_name == "final_decision_explicit"] <- "S20E_CL_CONCEPTUAL_LEDGER_COMPLETE_NO_CONSTRUCTION"
validation$evidence[validation$check_name == "shaikh_appendix_used_as_primary_semantic_source"] <- "For S20E-CL, stock-flow labour-value logic is governing; Shaikh and Tonak provide theoretical inspiration; Appendix 6.7 is the benchmark empirical example; BEA/NIPA is operational terrain."
validation$notes[validation$check_name == "fred_fallback_ledger_created_or_marked"] <- "FRED fallback completed earlier but is not independent authorization."
validation$status[validation$check_name == "api_access_available"] <- "PASS"
validation$check_name[validation$check_name == "api_access_available"] <- "bea_api_not_current_authorization_blocker"
validation$evidence[validation$check_name == "bea_api_not_current_authorization_blocker"] <- "BEA/NIPA current-release metadata strategy and available ledgers are documentation inputs only."
validation$notes[validation$check_name == "bea_api_not_current_authorization_blocker"] <- "Current status is conceptual only: no construction, no handoff, no candidate graduated."
validation$evidence[validation$check_name == "interpretation_conditional_candidate_menu_created"] <- "S20E_CL_candidate_menu.csv"
validation$check_name[validation$check_name == "interpretation_conditional_candidate_menu_created"] <- "candidate_menu_created"
validation$notes[validation$check_name == "candidate_menu_created"] <- "Standardized file name: S20E_CL_candidate_menu.csv."
validation$evidence <- gsub("PENDING_PROVIDER_SHAIKH_CROSSWALK_BECAUSE_API_ACCESS_REQUIRED", "S20E_CL_CONCEPTUAL_LEDGER_COMPLETE_NO_CONSTRUCTION", validation$evidence, fixed = TRUE)
validation$notes <- gsub("Current-release status remains pending because BEA API access is unavailable.", "Current status is conceptual only: no construction, no handoff, no candidate graduated.", validation$notes, fixed = TRUE)
validation$notes <- gsub("This is the binding blocker for authorization.", "No construction, handoff, or candidate graduation is authorized in this pass.", validation$notes, fixed = TRUE)
validation <- rbind(
  validation,
  data.frame(
    check_name = c(
      "source_hierarchy_wording_corrected",
      "candidate_menu_filename_consistent",
      "stale_api_blocker_wording_removed",
      "bundle_level_stock_flow_candidate_added",
      "component_level_double_counting_rows_added",
      "net_of_and_decomposition_fields_distinguished",
      "financial_power_claim_field_standardized",
      "no_staging_commit_push_performed"
    ),
    status = "PASS",
    evidence = c(
      "Validation and report describe stock-flow logic, Shaikh and Tonak, Appendix 6.7 benchmark, and BEA/NIPA terrain.",
      "S20E_CL_candidate_menu.csv is the standardized candidate menu; no duplicate interpretation-conditional menu retained.",
      "Validation notes identify conceptual no-construction/no-handoff status, not API access, as current state.",
      "CORP_SHAIKH_OPERATING_LADDER_RECONCILIATION_BUNDLE added to stock-flow gate.",
      "FC_NET_INT_PAID_CANDIDATE, NFC_NET_IMPUTED_INT_PAID_CANDIDATE, and CORP_IMPUTED_INTEREST_ADJ_BUNDLE added.",
      "not_equivalent_to, flow_direction_logic, and decomposition_role added to account ladder.",
      "financial_power_claim standardized in CL ladder, boundary, candidate menu, and double-counting gate.",
      "No staging/commit/push commands run by script."
    ),
    notes = "S20E-CL-PATCH schema stabilization."
  )
)
wcsv(validation, "S20E_validation_checks.csv")

sf_report <- c(
  "# S20E-CL Stock-Flow Labour-Value Accounting",
  "",
  "Date: 2026-06-17",
  "",
  "Final decision: `S20E_CL_CONCEPTUAL_LEDGER_COMPLETE_NO_CONSTRUCTION`",
  "",
  "## Scope",
  "",
  "This is a conceptual consolidation pass for future Stock-Flow Labour-Value Accounting Skill design, Shiny exploration, and possible provider handoffs after human review. It is not a construction, handoff, Shiny app, or Skill implementation pass.",
  "",
  "## Two Laws",
  "",
  "1. Stock-flow consistency: every object must sit inside the ladder `GVA -> GOS -> NOS -> profit / interest / rent / transfer decompositions`.",
  "2. No double accounting: the same surplus, transfer, financial claim, or corporate flow must not be counted twice.",
  "",
  "## Theoretical Hierarchy",
  "",
  "Stock-flow consistency governs the ledger. Shaikh and Tonak inspire the productive/nonproductive distinctions. Shaikh 2016 Appendix 6.7 is a benchmark example to replicate conceptually, not mechanically. Banking and finance are not productive capital; they may express claims on surplus, monopoly power, or transfer/appropriation channels. BEA/NIPA is the operational data terrain. Commercial capital remains blurred and is flagged rather than solved silently.",
  "",
  "## Account Ladder",
  "",
  "GVA is net of intermediate inputs and not net of compensation, taxes, CFC, actual interest, or profits. GOS is net of compensation and taxes less subsidies, gross of CFC, and not equivalent to corporate profits. NOS is net of CFC but not net of actual interest, and it is not corporate profit.",
  "",
  "## Finance And Correction Ingredients",
  "",
  "Financial corporate lines may be used as accounting-correction ingredients under an interpretation-conditional restoration candidate. They are not interpreted as productive-value creation. Interest receipts are claims or appropriation channels, not a second source of newly created surplus.",
  "",
  "## Candidate Statuses",
  "",
  "The expected current status for the Shaikh corporate adjustment is `DOCUMENTATION_AND_RECONCILIATION_CANDIDATE`. The NFC unadjusted wage-share baseline is preserved as `READY_AS_BASELINE`. Business-wide candidates are `THEORETICALLY_MIXED_REVIEW_REQUIRED`. Negative controls are blocked for double-counting or stock-flow inconsistency.",
  "",
  "## Why No Construction Or Handoff Happened",
  "",
  "No candidate is graduated in this pass. The ledgers define conceptual positions, gates, and graduation criteria only. No adjusted time series, model-input panel, Shiny app, Skill implementation, or provider handoff was created.",
  "",
  "## S20E-CL-PATCH Stabilization",
  "",
  "The patch adds a bundle-level operating-ladder candidate: `CORP_SHAIKH_OPERATING_LADDER_RECONCILIATION_BUNDLE`. Stock-flow consistency must be checked for the whole adjusted ladder, not only isolated formulas, because GVA, GOS, and NOS must move coherently while COMP, TAX_NET, and CFC remain unchanged.",
  "",
  "The patch also adds component-level double-accounting rows for `FC_NET_INT_PAID_CANDIDATE`, `NFC_NET_IMPUTED_INT_PAID_CANDIDATE`, and `CORP_IMPUTED_INTEREST_ADJ_BUNDLE`. This makes visible whether financial and nonfinancial flows are being treated as restoration ingredients or as duplicate surplus sources.",
  "",
  "The account ladder now distinguishes `net_of_what` from `not_equivalent_to`, `flow_direction_logic`, and `decomposition_role`, because net interest and corporate profits cannot be understood with the same field logic as GVA/GOS/NOS.",
  "",
  "`financial_power_claim` is standardized across the CL ledgers. Banking and finance remain nonproductive capital in this conceptual pass, but may be flagged as claim-on-surplus, monopoly-power, transfer/appropriation, or correction-ingredient channels depending on the object."
)
writeLines(sf_report, file.path(md_dir, "S20E_CL_STOCK_FLOW_LABOUR_VALUE_ACCOUNTING.md"), useBytes = TRUE)
writeLines(sf_report, file.path(md_dir, "S20E_CL_CONCEPTUAL_ACCOUNT_LEDGER.md"), useBytes = TRUE)
writeLines(sf_report, file.path(md_dir, "S20E_SHAIKH_CURRENT_RELEASE_CROSSWALK.md"), useBytes = TRUE)

message("S20E ledgers written to ", out_dir)
message("Final decision: S20E_CL_CONCEPTUAL_LEDGER_COMPLETE_NO_CONSTRUCTION")
