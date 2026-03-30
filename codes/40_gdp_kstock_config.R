############################################################
# 40_gdp_kstock_config.R — GDP & Capital Stock Dataset
#                           Module Configuration
#
# GPIM formalization: Shaikh (2016), Appendix 6.5 §V,
#   Appendix 6.6 §I, Appendix 6.7 §V
# Notation reference: docs/notation.md
#
# This config drives the 40-series pipeline:
#   41 → BEA fetch
#   42 → FRED fetch
#   43 → GDP construction
#   44 → Private capital stocks (GPIM)
#   45 → Government capital stocks
#   46 → Shaikh adjustments (toggle-able)
#   47 → Stock-flow consistency + deflator tests T1-T3
#   48 → Final assembly
#   49 → Capital-output ratio analysis
############################################################

GDP_CONFIG <- list(

  ## ----------------------------------------------------------
  ## Sample range
  ## ----------------------------------------------------------
  year_start = 1925L,
  year_end   = 2024L,
  year_trim  = 1929L,   # fallback if pre-1929 GDP unavailable

  ## ----------------------------------------------------------
  ## FRED series IDs
  ## ----------------------------------------------------------
  FRED_SERIES = list(
    gdp_nominal  = "GDPA",            # Nominal GDP annual (1929+)
    gnp_nominal  = "GNPA",            # Nominal GNP annual (1929+)
    gdp_deflator = "A191RD3A086NBEA"  # GDP implicit price deflator (1929+)
  ),

  ## ----------------------------------------------------------
  ## BEA Fixed Assets table identifiers
  ##
  ## Private fixed assets: Tables 4.x
  ## Government fixed assets: Tables 6.x
  ##
  ## These are the TableName values for beaGet().
  ## ----------------------------------------------------------
  BEA_TABLES = list(
    # Private
    private_net_cc    = "FAAt401",   # Table 4.1: Current-Cost Net Stock
    private_net_chain = "FAAt402",   # Table 4.2: Chain-Type QI Net Stock
    private_net_hist  = "FAAt403",   # Table 4.3: Historical-Cost Net Stock
    private_dep_cc    = "FAAt404",   # Table 4.4: Current-Cost Depreciation
    private_inv       = "FAAt407",   # Table 4.7: Investment in Private FA
    # Private FA by Industry Group and Legal Form of Organization (Section 6)
    private_lf_net_cc    = "FAAt601",   # Table 6.1: Current-Cost Net Stock
    private_lf_net_chain = "FAAt602",   # Table 6.2: Chain-Type QI Net Stock
    private_lf_dep_cc    = "FAAt603",   # Table 6.3: Current-Cost Depreciation
    private_lf_inv       = "FAAt604",   # Table 6.4: Investment by Legal Form
    # Government Fixed Assets (Section 7)
    govt_net_cc       = "FAAt701",   # Table 7.1: Current-Cost Net Stock
    govt_net_chain    = "FAAt702",   # Table 7.2: Chain-Type QI Net Stock
    govt_dep_cc       = "FAAt703",   # Table 7.3: Current-Cost Depreciation
    govt_inv          = "FAAt704"    # Table 7.4: Investment in Govt FA
  ),

  ## ----------------------------------------------------------
  ## Asset taxonomy
  ##
  ## Each entry maps our code to the BEA line description
  ## substring used for matching in Fixed Assets tables.
  ## See docs/notation.md §1 for definitions.
  ## ----------------------------------------------------------
  ASSET_TAXONOMY = list(
    ME  = "Equipment",
    NRC = "Structures",
    RC  = "Residential",
    IP  = "Intellectual property products"
  ),

  ## Composite aggregates (computed, not extracted from BEA)
  ##
  ## TOTAL_PRODUCTIVE excludes RC (Residential) and IP, following
  ## Shaikh's corporate sector concept: only non-residential fixed
  ## capital (Equipment + Structures) enters the output-capital ratio.
  ASSET_COMPOSITES = list(
    NR               = c("ME", "NRC"),
    TOTAL_PRODUCTIVE = c("ME", "NRC"),
    TOTAL_WITH_RC    = c("ME", "NRC", "RC"),
    TOTAL_ALL        = c("ME", "NRC", "RC", "IP")
  ),

  ## ----------------------------------------------------------
  ## BEA line-number mapping (Table 4.1 structure)
  ##
  ## These are approximate and MUST be validated at runtime

  ## against actual line descriptions from the API/CSV.
  ## The validate_line_map() function in 97_kstock_helpers.R
  ## checks these against parsed data.
  ## ----------------------------------------------------------
  LINE_MAP_PRIVATE = list(
    total          = 1L,
    nonresidential = 2L,
    structures     = 3L,
    equipment      = 6L,
    ip_products    = 9L,
    residential    = 13L
  ),

  ## Government (Table 7.1 structure)
  LINE_MAP_GOVT = list(
    total           = 1L,
    national_defense = 2L,
    defense_structures = 3L,
    defense_equipment  = 4L,
    defense_ip         = 5L,
    nondefense         = 6L,
    nondefense_structures = 7L,
    nondefense_equipment  = 8L,
    nondefense_ip         = 9L
  ),

  ## ----------------------------------------------------------
  ## Shaikh adjustment toggles (per §6-7 of GPIM formalization)
  ##
  ## Each toggle is an orthogonal dimension of the capital stock
  ## construction. Effects are separable (§7.7). The SFC
  ## validation script (47) cross-validates EVERY active
  ## combination against the stock-flow identity.
  ## ----------------------------------------------------------

  # §6.3: IRS book-value correction for Great Depression scrapping
  # Requires manual IRS data in data/raw/irs_book_value.csv
  ADJ_DEPRESSION_SCRAPPING = FALSE,

  # §3: Use GPIM constant-cost deflation (eq. 5) instead of
  # BEA chain-weighted series (Table 4.2)
  ADJ_GPIM_DEFLATION = TRUE,

  # §7: Strip hedonic quality adjustments from chain indices
  ADJ_QUALITY_CRITIQUE = FALSE,

  # Interpolate capital stocks over WWII period (1941-1945)
  ADJ_WWII_INTERPOLATION = FALSE,

  ## ----------------------------------------------------------
  ## GPIM calibration parameters (§5)
  ## ----------------------------------------------------------
  GPIM = list(
    base_year       = 2017L,   # Base year for real series rebasing
    sfc_tolerance   = 0.001,   # SFC identity tolerance (0.1%)
    g_pK_approx     = 0.034,   # Approx (1+g_pK) for US corporate (§5.3)
    z_star_approx   = 0.0329   # Critical depletion rate: g_pK/(1+g_pK)
  ),

  ## ----------------------------------------------------------
  ## Deflator test protocol (§7.5-7.6)
  ## ----------------------------------------------------------
  DEFLATOR_TESTS = list(
    newey_west_lag  = NULL,     # NULL = automatic bandwidth selection
    za_break_window = c(1985L, 1999L),  # Expected hedonic adoption window
    za_model        = "both"   # Zivot-Andrews: break in intercept + trend
  ),

  ## ----------------------------------------------------------
  ## Data paths (relative to project root)
  ## ----------------------------------------------------------
  RAW_BEA     = "data/raw/bea",
  RAW_FRED    = "data/raw/fred",
  INTERIM     = "data/interim",
  PROCESSED   = "data/processed",

  ## Interim sub-paths
  INTERIM_BEA_PARSED     = "data/interim/bea_parsed",
  INTERIM_KSTOCK         = "data/interim/kstock_components",
  INTERIM_GDP            = "data/interim/gdp_components",
  INTERIM_VALIDATION     = "data/interim/validation",
  INTERIM_FIGURES        = "data/interim/figures",
  INTERIM_LOGS           = "data/interim/logs",

  ## ----------------------------------------------------------
  ## API keys (from environment variables)
  ## ----------------------------------------------------------
  BEA_API_KEY  = Sys.getenv("BEA_API_KEY",
                             unset = "6EA6700D-A126-484F-A9FC-7DB7E4E0FA4F"),
  FRED_API_KEY = Sys.getenv("FRED_API_KEY",
                             unset = "fc67199ea06d765ef79b3011dcf75c45"),

  ## ----------------------------------------------------------
  ## Reproducibility
  ## ----------------------------------------------------------
  seed = 123456L
)
