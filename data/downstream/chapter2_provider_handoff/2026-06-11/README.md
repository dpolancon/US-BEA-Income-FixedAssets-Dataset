# U.S. BEA Variable Menu Provider

This repository fetches, stages, documents, and validates U.S. Bureau of
Economic Analysis source ingredients for Chapter 2. It is a provider, not the
analytical authority. `Capacity-Utilization-US_Chile` owns GPIM stocks,
Shaikh-style corrections, distributive variables, capacity, utilization,
interactions, admissibility ledgers, and econometric datasets.

## Provider hierarchy

The source hierarchy is:

1. Direct BEA API pull.
2. FRED fallback only for an accepted exact or near-exact BEA-origin series.
3. Financial corporate residual, `FC = CORP - NFC`, only for additive nominal
   accounting values.
4. Explicit `unresolved` status.

API credentials come only from `BEA_API_KEY` and `FRED_API_KEY`. Raw snapshots
are date-versioned under `data/raw/provider/YYYY-MM-DD/` and are never
overwritten. FRED search results are candidates only until their title, BEA
origin, frequency, units, and sample span are reviewed.

## Locked Chapter 2 source-variable menu

The current scaffold contains:

```text
71 variable-menu rows
65 locked source concepts
6 implied-investment fallback metadata rows
71 metadata rows
361 BEA table metadata candidates
337 FRED search candidates, all unaccepted pending review
5 live BEA snapshots under data/raw/provider/2026-06-11
Validation: 71 PASS, 0 FAIL
Existing repository validation: PASS
```

The locked menu covers CORP, NFC, FC, ME, NRC, distribution-accounting
ingredients, FixedAssets inputs, and GPIM parameters. It does not add IPP,
government transportation, parked variables, or final Chapter 2 objects to the
baseline fetch menu.

## Capital aggregation and GPIM rules

The preferred downstream productive-capacity capital object is:

```text
K_cap = K_ME + K_NRC
```

ME and NRC may be aggregated in nominal/current-cost terms. Post-GPIM real ME
and NRC must not be raw-added; real aggregation requires an explicit
price/index rule. The provider does not construct final gross or net GPIM
stocks.

## FixedAssets price and quantity indexes

BEA FixedAssets real fixed-asset series, quantity indexes, and related
price/index objects are comparison and validation objects, not canonical
construction inputs for the Chapter 2 GPIM baseline.

BEA real stocks and quantity indexes embody BEA's quality adjustment,
asset-price treatment, depreciation framework, and aggregation conventions.
Chapter 2 uses its own GPIM stock-flow logic, service-life assumptions, and
retirement rules. Therefore, BEA real/quantity indexes must not define the
baseline GPIM productive-capacity stock unless a later methodological note
explicitly promotes them.

```text
FAAt402 quantity indexes are comparison/validation diagnostics.
They are not price indexes for the Chapter 2 GPIM baseline.
They are not GPIM products.
```

Their metadata status is:

```text
chapter2_role = validation_only
construction_status = metadata_only
baseline_status = comparison_only
```

They may be preserved for comparison with BEA real fixed assets, validation of
GPIM trajectories, diagnostics of divergence, and documentation of BEA
benchmark behavior. They must not be used to raw-deflate the baseline GPIM
stock.

## Direct investment and implied-investment fallback

Direct nominal investment is canonical when available at the required
asset-sector boundary. Stock-flow-implied investment is fallback only:

```text
I_N_implied_i_t =
  K_N_CC_i_t
  - (P_K_i_t / P_K_i_t_minus_1) * K_N_CC_i_t_minus_1
  + CFC_CC_i_t
```

If both direct and implied investment are available, the implied series may
support a validation gap; it does not mechanically replace the direct series.
BEA quality-adjusted real fixed-asset indexes are not substitutes for the GPIM
construction.

## GVA implicit deflators

Nominal GVA plus real/chained-dollar GVA or a quantity-index counterpart permits
a source-level implicit GVA deflator when both components use the same sector
boundary.

With current-dollar and chained-dollar GVA:

```text
GVA_deflator_t = 100 * GVA_current_t / GVA_real_chained_t
```

Units must be harmonized before division. With current-dollar GVA and a
quantity index:

```text
GVA_price_index_t =
  100 * (GVA_current_t / GVA_current_base)
  / (GVA_quantity_index_t / 100)
```

The quantity index's documented base year must be used. This is allowed because
the deflator is a source-level accounting counterpart, not a final Chapter 2
econometric object.

The NFC row is derivable from validated NIPA Table 1.14 current-dollar line 17
and chained-dollar line 41:

```text
fetch_status = derivable_from_bea_components
construction_status = source_level_derived
chapter2_role = preferred_baseline_source
```

CORP remains a robustness-source review item until matching direct components
are confirmed. FC remains unresolved unless direct nominal and direct
real/quantity components exist or a valid index aggregation rule is documented.
FC real GVA and FC price deflators must not be constructed by raw residual
subtraction from CORP and NFC real/price series.

## Current unresolved provider rows

The unresolved rows do not invalidate the provider scaffold. Some remain
unresolved because direct source counterparts have not been accepted. GVA
deflator rows may become source-level derived rows once matching nominal and
real/quantity components are confirmed at the same sector boundary.
FixedAssets stock-price or revaluation-index rows matter only for
implied-investment fallback and validation, not the canonical GPIM baseline.

Current unresolved rows:

- `gva_real_or_qindex_corp`
- `gva_real_or_qindex_fc`
- `gva_price_or_deflator_corp`
- `gva_price_or_deflator_fc`
- `me_stock_price_or_revaluation_index`
- `nrc_stock_price_or_revaluation_index`

`gva_price_or_deflator_nfc` is no longer conceptually unresolved: matching NFC
nominal and chained-dollar components are validated at the same boundary.

## Active pipeline

Run the Chapter 2 provider scaffold from the repository root:

```powershell
Rscript codes/01_discover_bea_metadata.R
Rscript codes/02_discover_fred_candidates.R
Rscript codes/03_build_ch2_master_variable_menu.R
Rscript codes/04_fetch_ch2_provider_sources.R
Rscript codes/05_validate_provider_fetches.R
```

The existing locked provider pipeline remains:

```powershell
Rscript codes/40_stage_variable_menu_long.R
Rscript codes/90_validate_variable_menu.R
```

## Downstream handoff to Chapter 2

The provider supplies auditable source observations, mappings, parameters, and
provenance. The downstream repository may consume these ingredients but owns
all analytical construction. No final GPIM stock, adjusted wage/profit share,
exploitation ratio, capacity/utilization measure, interaction, centered
variable, or econometric object is produced here.

## Provider artifacts

- `data/provider_menu/ch2_master_variable_menu.csv`
- `data/provider_menu/ch2_master_variable_metadata.csv`
- `data/provider_menu/ch2_provider_fetch_status.csv`
- `data/provider_menu/ch2_bea_table_discovery.csv`
- `data/provider_menu/ch2_fred_fallback_candidates.csv`
- `data/metadata/us_bea_variable_menu_locked.csv`
- `data/metadata/us_bea_source_provenance_ledger.csv`
- `data/staged/us_bea_variable_menu_long.csv`
- `docs/ch2_provider_variable_menu.md`
