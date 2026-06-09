# U.S. BEA Variable Menu Provider

This repository is the locked provider layer for U.S. Bureau of Economic
Analysis data used by Chapter 2. It fetches, stages, documents, and validates
BEA Fixed Assets and NIPA ingredients with table-line-unit-vintage provenance.

It is not the Chapter 2 analytical authority.

## Repository Boundary

| Repository | Responsibility |
| --- | --- |
| `US-BEA-Income-FixedAssets-Dataset` | Fetch and stage auditable BEA/NIPA/Fixed Assets ingredients |
| `Capacity-Utilization-US_Chile` | Construct S10/S20/S30 datasets, GPIM stocks, Shaikh-style corrections, distributive variables, interactions, and admissibility ledgers |

The preferred downstream productive-capacity capital object is:

```text
K_cap = K_ME + K_NRC
```

IPP and government transportation fixed assets are preserved as frontier
conditioners. They are not included in preferred private `K_cap`. The preferred
transformation object is `theta(e_t | IPP_t, GOV_TRANS_t)`.

## Active Pipeline

Run from the repository root:

```powershell
Rscript codes/20_fetch_fixed_assets_menu.R
Rscript codes/30_fetch_income_accounts_menu.R
Rscript codes/40_stage_variable_menu_long.R
Rscript codes/90_validate_variable_menu.R
```

Set `BEA_API_KEY` for a live refresh. Raw snapshots are date-versioned under
`data/raw/provider/` and are never overwritten. Without a key, staging uses the
preserved March 2026 API extracts where available and reports the limitation.

## Provider Artifacts

- `data/metadata/us_bea_variable_menu_locked.csv`
- `data/metadata/us_bea_variable_menu_locked.json`
- `data/metadata/us_bea_source_provenance_ledger.csv`
- `data/staged/us_bea_variable_menu_long.csv`
- `docs/US_BEA_VARIABLE_MENU_PROVIDER_CONTRACT.md`
- `docs/US_BEA_VARIABLE_MENU_VALIDATION_REPORT.md`
- `docs/US_BEA_VARIABLE_MENU_EXECUTION_REPORT.md`

The staged file contains one annual observation per source variable. It does
not contain final GPIM, adjusted profit/wage shares, interaction variables, or
econometric objects.

## Historical Code

The pre-lock Chapter 1 and analytical construction scripts were relocated to
`codes/_legacy/provider_prelock_2026-06-09/`. They are retained for audit
history and are not the active provider pipeline.

## Auxiliary Non-Menu Data

Labor-market files may be retained in this repository for reference or future
extension, but they are outside the active BEA variable-menu provider pipeline.
They must not be added to the locked Chapter 2 variable menu unless a later
explicit pass promotes them into the provider contract.

