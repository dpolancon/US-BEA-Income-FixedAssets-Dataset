# AGENTS.md - U.S. BEA Variable Menu Provider

**Last updated:** 2026-06-09

## Active Role

This repository fetches, stages, documents, and validates BEA Fixed Assets and
NIPA source variables for Chapter 2. It is a provider, not the analytical
authority.

`C:\ReposGitHub\Capacity-Utilization-US_Chile` owns S10/S20/S30, GPIM,
Shaikh-style income corrections, distributive variables, interactions,
admissibility ledgers, and final source-of-truth datasets.

## Locked Theory and Asset Roles

- Preferred downstream capital: `K_cap = K_ME + K_NRC`.
- `ME`: `direct_productive_capacity_capital`.
- `NRC`: `direct_productive_capacity_capital`.
- `IPP`: `frontier_conditioner`, excluded from preferred `K_cap`.
- `GOV_TRANS`: `frontier_conditioner`, excluded from preferred private `K_cap`.
- Residential capital: `exclusion_diagnostic`.
- Financial fixed assets: `corporate_boundary_diagnostic`.
- Inventories: `circulation_stockflow_diagnostic`.
- Preferred transformation: `theta(e_t | IPP_t, GOV_TRANS_t)`.
- Do not implement the additive alternative
  `g_Yp = theta*g_Kcap + psi*g_IPP + gamma*g_GOV_TRANS`.

## Active Files

- `codes/10_bea_api_helpers.R`
- `codes/20_fetch_fixed_assets_menu.R`
- `codes/30_fetch_income_accounts_menu.R`
- `codes/40_stage_variable_menu_long.R`
- `codes/90_validate_variable_menu.R`
- `data/metadata/us_bea_variable_menu_locked.csv`
- `data/metadata/us_bea_variable_menu_locked.json`
- `data/metadata/us_bea_source_provenance_ledger.csv`
- `data/staged/us_bea_variable_menu_long.csv`

Scripts under `codes/_legacy/` are historical and not active.

## Safety Rules

- Never push directly to `main`.
- Never auto-merge.
- Never overwrite or delete raw data.
- Store live snapshots under `data/raw/provider/YYYY-MM-DD/`.
- Use `BEA_API_KEY`; never hard-code a key or print it to logs.
- Do not silently substitute total private, total business, or total economy
  for NFC, CORP, FIN, or GOV_TRANS.
- Missing mappings must use explicit statuses such as `not_available`,
  `requires_manual_mapping`, or `downstream_constructed_only`.
- Preserve BEA table, line, description, unit, frequency, download date,
  vintage, query, sector, asset, and role provenance.

## Provider Boundary

Do not construct final:

- gross or net GPIM stocks;
- adjusted value added, operating surplus, profit shares, wage shares, or `e`;
- `e_x_Kcap`, `e_x_ME`, `e_x_NRC`, or `e_x_ME_NRC_gap`;
- capacity, utilization, transformation-elasticity, or econometric objects.

The provider may list these as downstream contracts and must stage every
available source ingredient needed to construct them.

## Validation

Run:

```powershell
Rscript codes/40_stage_variable_menu_long.R
Rscript codes/90_validate_variable_menu.R
```

Validation must confirm the eight locked NIPA Table 7.11 lines, asset role
tags, NFC/CORP/FIN/GOV_TRANS boundaries, diagnostic treatment of official
indexes, downstream ownership, and complete staged provenance.
