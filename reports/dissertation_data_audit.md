# Repo Audit — Data and Capital-Stock Construction

## 1. Executive summary

This repo is best read as a **U.S. direct-source capital-stock construction repository** built around BEA Fixed Assets, BEA NIPA, and FRED inputs, with GPIM logic layered on top for net and gross stock reconstruction. Its dissertation value is on the **data/construction architecture**: source ingestion, table/line disambiguation, own-price deflator construction, depreciation-versus-retirement separation, Weibull service-life logic, and stock-flow-consistent output bundles.

Operationally, the repo contains a live construction layer centered on `codes/50_*` to `codes/62_*`, plus an older archived 40-series pipeline under `codes/_archive/`. The checked-in processed outputs are useful for writing, but the repo is **not cleanly documented as one single runnable pipeline**: the root `README.md` is effectively empty, several docs still carry estimation-era language, a repeatedly referenced `codes/10_config.R` is absent, and some live scripts expect filenames that do not match the checked-in `data/interim/bea_parsed/` objects. For dissertation prose, the repo should therefore be cited as the **U.S. construction backend and audit trail**, not as a polished public package.

## 2. Relevant repo map

Only files/folders relevant to the data/construction layer are listed here.

- Capital-stock ingestion:
  - `codes/50_fetch_fixed_assets.R`
  - `codes/51_fetch_nipa_income.R`
  - `data/raw/bea/`
  - `data/interim/bea_parsed/`
- GPIM / perpetual inventory logic:
  - `codes/53_build_gpim_kstock.R`
  - `codes/59_gpim_helpers.R`
  - `codes/97_kstock_helpers.R`
  - `codes/60_agents_prod_cap.R`
  - `codes/61_validators_prod_cap.R`
  - `codes/62_build_prod_cap_accounts.R`
- Retirement functions / Weibull / service lives:
  - `docs/Weibull_Retirement_Distributions.md`
  - `docs/KSTOCK_Architecture_v1.md`
  - `codes/59_gpim_helpers.R`
  - `codes/62_build_prod_cap_accounts.R`
- Gross vs net stock logic:
  - `codes/53_build_gpim_kstock.R`
  - `codes/59_gpim_helpers.R`
  - `codes/60_agents_prod_cap.R`
  - `data/processed/corp_kstock_series.csv`
  - `data/processed/kstock_master.csv`
  - `data/processed/kstock_accounts_long.csv`
- Source harmonization / direct-source ingestion:
  - `docs/BEA_LineMap_v1.md`
  - `docs/BEA_TableStructure_ClaudeCode.md`
  - `docs/bea/fixed_assets/README_BEA_FixedAssets_Bundle.md`
  - `docs/bea/fixed_assets/BEA_FixedAssets_MainNotebook_v2.md`
  - `docs/bea/fixed_assets/BEA_FixedAssets_AppendixA_LineDetail_v2.md`
  - `docs/bea/fixed_assets/BEA_FixedAssets_AppendixB_CoverageMatrix_v2.md`
- Output bundles / assumptions / reproducibility:
  - `codes/56_assemble_NF_kstock_distribution.R`
  - `codes/57_extend_to_present.R`
  - `codes/90_data_audit.R`
  - `data/interim/kstock_components/`
  - `data/interim/logs/build_metadata.csv`
  - `output/validation/gpim_sfc_consistency/GPIM_SFC_BRIEF.md`
- Documentation useful for dissertation writing:
  - `docs/KSTOCK_Architecture_v1.md`
  - `docs/VARIABLE_SCOPE_AND_GPIM_EXTENSIONS.md`
  - `docs/Weibull_Retirement_Distributions.md`
  - `docs/BEA_LineMap_v1.md`
  - `docs/BEA_TableStructure_ClaudeCode.md`
  - `docs/_legacy/GPIM_AuditReport_v1.md`

## 3. File inventory

| Path | Type | Scope | Main function | Key objects | Priority |
|---|---|---|---|---|---|
| `codes/50_fetch_fixed_assets.R` | script | U.S. BEA direct-source ingestion | Fetches BEA Fixed Assets Section 6 and 7 tables | `FAAt601`, `FAAt602`, `FAAt603`, `FAAt604`, `FAAt607`, `FAAt701`, `FAAt702`, `FAAt705` | High |
| `codes/51_fetch_nipa_income.R` | script | Income-side source ingestion | Fetches NIPA income tables and FRED deflator used alongside capital construction | `T11400`, `T71100`, `Py` | Medium |
| `codes/52_build_income_accounts.R` | script | Source harmonization | Builds NF corporate income accounts used to pair with capital-side outputs | `GVA_NF`, `CCA_NF`, `NVA_NF`, `GOS_NF`, `CorpImpIntAdj` | Medium |
| `codes/53_build_gpim_kstock.R` | script | Corporate GPIM reconstruction | Derives own-price deflator, depreciation rates, net stock, gross stock, and ADJ1-ADJ3 variants | `KNCcorp`, `KGCcorp`, `KNRcorp`, `dcorpstar`, `pKN`, `RET_CORP` | High |
| `codes/56_assemble_NF_kstock_distribution.R` | script | Output bundle | Packages NF capital/distribution series into a drafting-ready CSV rebased to 2024 | `KNC_NF`, `KNR_NF`, `KGC_NF`, `KGR_NF`, `pK_NF` | Medium |
| `codes/57_extend_to_present.R` | script | Extension / reproducibility | Extends the sealed corporate construction forward with fresh BEA/FRED pulls | `FAAt601`, `FAAt602`, `FAAt604`, `FAAt607`, `Py` | Low |
| `codes/59_gpim_helpers.R` | helper | GPIM mechanics | Defines Weibull functions, SFC-checked recursion, warmup, and deflator derivation | `weibull_*`, `derive_pK()`, `derive_DEP()`, `gpim_recursion()`, `warmup_from_investment()` | High |
| `codes/60_agents_prod_cap.R` | helper/script | Multi-account capital construction | Fetches account-specific inputs, runs `gpim_account()`, aggregates, and builds master CSV | `NF_corp`, `gov_trans`, `NF_IPP`, `fin_corp`, `KGC_productive` | High |
| `codes/61_validators_prod_cap.R` | helper | Validation / reproducibility | Defines gate checks for fetch completeness, SFC, and canonical normalization | `gate_check_API()`, `gate_check_SFC_*()`, `gate_check_canonical()` | Medium |
| `codes/62_build_prod_cap_accounts.R` | script | Coordinator + parameter locking | Injects locked Weibull parameters and writes master outputs | `WEIBULL_PARAMS`, `USE_1901_WARMUP`, `kstock_master.csv`, `kstock_accounts_long.csv` | High |
| `codes/90_data_audit.R` | script | Provenance audit | Reconciles Shaikh workbook releases and canonical CSV | `xlsx_original`, `xlsx_corrected`, `xlsx_rearranged`, `csv_canonical` | Medium |
| `codes/97_kstock_helpers.R` | helper | Shared capital-stock math and BEA parsing | Parses BEA data and implements core GPIM accumulation functions | `parse_bea_api_response()`, `gpim_accumulate_*()`, `gpim_depreciation_rate()` | High |
| `docs/KSTOCK_Architecture_v1.md` | doc | Architecture / assumptions | Consolidated decision log for source perimeter, two-input rule, deflator logic, and locked parameters | dataset boundary, `KNC_i_t`, `IG_i_t`, `WEIBULL_PARAMS` | High |
| `docs/Weibull_Retirement_Distributions.md` | doc | Retirement methodology | Formalizes retirement versus depreciation and justifies `L` / `alpha` choices | `rho(τ)`, `lambda`, cold-start warmup | High |
| `docs/BEA_LineMap_v1.md` | doc | Source provenance | Maps BEA and NIPA tables/lines to constructed objects | `FAAt601/607`, `FAAt701/705`, `T11400` | High |
| `docs/BEA_TableStructure_ClaudeCode.md` | doc | Source harmonization constraints | Explains why Section 6 gives NF corporate aggregate only, and how to match lines safely | Section 6 vs Section 4 constraint | High |
| `data/raw/bea/` | data dir | Direct-source input | Stores raw BEA extracts used for reconstruction | `private_*_raw.csv`, `private_lf_*_raw.csv`, `govt_*_raw.csv` | High |
| `data/interim/bea_parsed/` | data dir | Harmonized source tables | Stores parsed BEA and NIPA tables used by downstream builders | `private_lf_net_cc.csv`, `nipa_t1014.csv`, `nipa_t7011.csv` | High |
| `data/interim/kstock_components/` | data dir | Per-account outputs | Stores account-level GPIM outputs for inspection and reuse | `kstock_nf_corp.csv`, `kstock_government.csv`, `kstock_TOTAL_PRODUCTIVE.csv` | Medium |
| `data/interim/logs/build_metadata.csv` | log | Reproducibility | Records build date, sample range, toggles, and base-year settings | `build_date`, `adj_gpim`, `gpim_base_year`, `sfc_tolerance` | Medium |
| `data/processed/corp_kstock_series.csv` | output | Corporate stock bundle | Main corporate GPIM output | `KNCcorpbea`, `KNCcorp`, `KGCcorp`, `dcorpstar`, `pKN` | High |
| `data/processed/kstock_master.csv` | output | Wide master bundle | Main multi-account output for dissertation drafting | `KGC_NF_corp`, `KGC_gov_trans`, `KGC_productive`, `pK_productive`, `NVA_NF` | High |
| `data/processed/kstock_accounts_long.csv` | output | Long per-account bundle | Long-form GPIM outputs by account | `KNC`, `KGC`, `IG_cc`, `z`, `rho`, `account` | Medium |
| `data/processed/US_corporate_NF_kstock_distribution.csv` | output | Drafting-ready NF bundle | Combines income-distribution and capital-stock variables at 2024 prices | `GVA_NF`, `Wsh_NF`, `Psh_NF`, `KGC_NF`, `pK_NF` | Medium |
| `output/validation/gpim_sfc_consistency/GPIM_SFC_BRIEF.md` | output doc | Validation narrative | Summarizes why GPIM is preferred over chain-weighted capital for SFC | GPIM vs chain divergence | Medium |

## 4. Shared methodological relevance

| Dissertation theme | Most relevant files | What they contribute |
|---|---|---|
| Depreciation vs retirement | `codes/53_build_gpim_kstock.R`, `codes/59_gpim_helpers.R`, `docs/Weibull_Retirement_Distributions.md` | The repo clearly distinguishes **depreciation** for net stock from **retirement** for gross stock; this is central for the shared methods section. |
| Gross vs net capital stock | `codes/53_build_gpim_kstock.R`, `codes/60_agents_prod_cap.R`, `data/processed/corp_kstock_series.csv`, `data/processed/kstock_master.csv` | These files show how nominal and real net/gross stocks are built and stored side by side. |
| GPIM recursion | `codes/59_gpim_helpers.R`, `codes/97_kstock_helpers.R`, `codes/53_build_gpim_kstock.R`, `codes/60_agents_prod_cap.R` | These are the closest thing to the repo’s capital-side “methods core”: deflator derivation, SFC-based depreciation, warmup, and recursion. |
| Parameter locking | `docs/KSTOCK_Architecture_v1.md`, `docs/Weibull_Retirement_Distributions.md`, `codes/62_build_prod_cap_accounts.R` | These hold the explicit service-life and shape assumptions, plus the toggles that are supposed to govern the build. |
| Source provenance | `codes/50_fetch_fixed_assets.R`, `codes/51_fetch_nipa_income.R`, `docs/BEA_LineMap_v1.md`, `docs/BEA_TableStructure_ClaudeCode.md`, `docs/bea/fixed_assets/*` | These support the dissertation’s account of where each object comes from and how BEA table structure constrains construction choices. |
| Reproducibility / assumptions | `codes/61_validators_prod_cap.R`, `codes/90_data_audit.R`, `data/interim/logs/build_metadata.csv`, `output/validation/gpim_sfc_consistency/GPIM_SFC_BRIEF.md` | These provide the strongest evidence for a reproducible, auditable construction layer, even though the top-level pipeline is currently messy. |

## 5. Country-specific role of this repo

This repo is **U.S. direct-source capital-stock construction**.

It should appear in the dissertation as the **U.S. source-construction backend**: the repository where BEA Fixed Assets, NIPA, and FRED series are ingested, harmonized, and transformed into capital-stock objects through GPIM logic. It is **not** a Chile harmonized construction repo. If the dissertation has a cross-country architecture section, this repo should represent the **direct-source U.S. side**, while the Chile repo should be presented separately as the harmonized/non-BEA counterpart.

## 6. Main text vs appendix handoff

Main text, in compressed form:

- The source stack: BEA Fixed Assets + BEA NIPA + FRED.
- The two-input GPIM rule on the capital side: current-cost net stock plus gross investment, with the stock-flow-consistent objects derived from those.
- The conceptual split between depreciation (net stock) and retirement (gross stock).
- The existence of locked service-life and retirement assumptions, plus audited output bundles.

Appendix only:

- Full BEA table and line mappings.
- Weibull parameter derivation, service-life triangulation, and cold-start/warmup details.
- ADJ toggles and historical corrections such as Depression-era scrapping.
- File-level provenance, build metadata, validation gates, and GPIM-vs-chain SFC notes.
- Repo messiness and historical layering: archived pipelines, stale docs, and naming drift.

## 7. Immediate writing-use outputs

- Shared data architecture:
  - `docs/KSTOCK_Architecture_v1.md`
  - `codes/59_gpim_helpers.R`
  - `codes/62_build_prod_cap_accounts.R`
- Country subsection:
  - `docs/BEA_LineMap_v1.md`
  - `codes/50_fetch_fixed_assets.R`
  - `data/processed/kstock_master.csv`
- GPIM / retirement appendix:
  - `docs/Weibull_Retirement_Distributions.md`
  - `codes/59_gpim_helpers.R`
  - `codes/53_build_gpim_kstock.R`
- Source-reconciliation appendix:
  - `codes/90_data_audit.R`
  - `docs/BEA_TableStructure_ClaudeCode.md`
  - `docs/bea/fixed_assets/BEA_FixedAssets_MainNotebook_v2.md`
  - `data/interim/logs/build_metadata.csv`

## 8. Gaps or messiness

- `README.md` is effectively empty, so the repo does not currently narrate itself at the top level.
- Many live scripts source `codes/10_config.R`, but that file is **not present** in the current tree.
- `codes/62_build_prod_cap_accounts.R` sources `codes/40_gdp_kstock_config.R`, but the visible file is only `codes/_archive/40_gdp_kstock_config.R`.
- The checked-in parsed BEA files do not line up cleanly with some live-script expectations:
  - `codes/53_build_gpim_kstock.R` expects `fa_private_*`
  - `data/interim/bea_parsed/` currently contains `private_*`, `private_lf_*`, and `corp_*`
- The repo contains at least three layers at once:
  - live 50-62 construction scripts
  - archived 40-series pipeline
  - update/legacy documentation bundles
- Some docs contradict or drift from current code:
  - `docs/KSTOCK_Architecture_v1.md` still frames a four-account productive dataset with wider scope
  - `codes/60_agents_prod_cap.R` currently sets `KGC_productive = KGC_NF_corp`, keeping government as auxiliary rather than inside the productive aggregate
- Several docs still mix in ARDL/VECM/estimation wording; those files are useful as history, but not as clean construction-only exposition.
- Some docs point to other repos or layouts, for example `C:\ReposGitHub\Critical-Replication-Shaikh\` and `docs/BEA_FixedAssets_Bundle_v2.2/`, which do not match the current repo exactly.

## 9. Evidence snippets

- `README.md`
  - Empty/near-empty file; no substantive repo-level explanation.
- `codes/50_fetch_fixed_assets.R`
  - “Downloads BEA FixedAssets dataset tables for all accounts”
- `codes/53_build_gpim_kstock.R`
  - “Each account is built from two BEA-reported inputs only”
- `codes/59_gpim_helpers.R`
  - “Weibull retirement distributions + SFC-checked recursion”
- `docs/Weibull_Retirement_Distributions.md`
  - “The retirement rate ρ(τ) is not directly observed.”
- `docs/BEA_TableStructure_ClaudeCode.md`
  - “No single BEA table provides Nonfinancial corporate × asset type”
- `codes/60_agents_prod_cap.R`
  - “Productive aggregates = NF corporate ONLY”
- `docs/KSTOCK_Architecture_v1.md`
  - `Repo: C:\ReposGitHub\Critical-Replication-Shaikh\`
- `codes/62_build_prod_cap_accounts.R`
  - `GDP_CONFIG$WEIBULL_PARAMS <- list(`
- `data/interim/logs/build_metadata.csv`
  - `adj_gpim,TRUE`
  - `gpim_base_year,2017`

