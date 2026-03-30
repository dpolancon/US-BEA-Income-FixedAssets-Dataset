############################################################
# 10_config.R — Chapter 3 Critical Replication configuration
#
# Lag convention (FROZEN):
#   In tsDyn:
#     VECM(lag = p)  =>  p lags of dX in the short run.
#   Therefore:
#     r = 0 null (no Pi term) must be estimated as
#       lineVar(..., lag = p, I = "diff")
#
#   We DO NOT use (p - 1) mapping.
#   We DO NOT reinterpret lag as VAR-levels lag.
#   We take tsDyn's lag argument literally.
############################################################

CONFIG <- list(

  ## ----------------------------------------------------------
  ## Shaikh replication data (raw)
  ## ----------------------------------------------------------
  data_corp       = "data/processed/prod_cap_dataset_d1.csv",
  data_shaikh    = "data/raw/shaikh_data/Shaikh_canonical_series_v1.csv",
  canonical_csv   = "data/raw/shaikh_data/Shaikh_canonical_series_v1.csv",
  u_frb        = "uFRB",          # FRB capacity utilization (canonical CSV)
  p_inv        = "pIGcorpbea",    # investment deflator (canonical CSV, sensitivity only)
  # exploitation rate construction audit trail (not loaded directly):
  # data/raw/Shaikh_exploitation_rate_faithful_v1.csv

  ## Variables in the Shaikh sheet
  ## Series identification: confirmed from Shaikh_RepData.xlsx (sheet "long")
  ## and S0 deflator grid search (25_S0_deflator_grid_search.R, S0_agent_report.md).
  ## Shaikh uses GVAcorp (= VAcorp + DEPCcorp) deflated by Py (GDP price index,
  ## NIPA T1.1.4, base 2011=100) for BOTH output and capital.
  ## See docs/ardl_series_identification.md for full provenance.
  year_col = "year",
  y_nom    = "VAcorp",      # Gross Value Added = VAcorp + DEPCcorp
  k_nom    = "KGCcorp",
  u_shaikh = "uK",
  pi_share = "Profshcorp",
  p_index  = "Py",           # GDP price index (NIPA T1.1.4, base 2011=100)
  e_rate   = "exploit_rate",

  
  ## ----------------------------------------------------------
  ## Sample windows (full sample must be first)
  ## ----------------------------------------------------------
  WINDOWS_LOCKED = list(
    shaikh_window = c(1947, 2011),   # was c(1947, 2011) — T=61 per Table 6.7.14
    full          = c(-Inf, Inf),
    fordism       = c(-Inf, 1973),
    post_fordism  = c(1974,  Inf)
  ),

  ## ----------------------------------------------------------
  ## Deterministic subspaces
  ##
  ## DSR = short-run deterministic (d equations)  -> tsDyn include
  ## DLR = long-run deterministic (cointegration) -> tsDyn LRinclude
  ##
  ## Allowed values: "none", "const"
  ## ----------------------------------------------------------
  DSR_SET = c("none", "const"),
  DLR_SET = c("none", "const"),

  ## Explicit deterministic pairs (SR, LR)
  DET_PAIRS = list(
    c("none",  "none"),
    c("none",  "const"),
    c("const", "none")
  ),

  ## ----------------------------------------------------------
  ## Critical replication canonical outputs (S0/S1/S2 structure)
  ## ----------------------------------------------------------
  OUT_CR = list(
    S0_faithful  = "output/CriticalReplication/S0_faithful",
    S0_redesign  = "output/CriticalReplication/S0_redesign",
    S1_geometry  = "output/CriticalReplication/S1_geometry",
    S2_vecm      = "output/CriticalReplication/S2_vecm",
    results_pack = "output/CriticalReplication/ResultsPack",
    manifest     = "output/CriticalReplication/Manifest"
  ),

  ## ----------------------------------------------------------
  ## Reproducibility
  ## ----------------------------------------------------------
  seed = 123456L,

  ## ----------------------------------------------------------
  ## Logging behaviour
  ## ----------------------------------------------------------
  HEARTBEAT_EVERY = 25L
)
