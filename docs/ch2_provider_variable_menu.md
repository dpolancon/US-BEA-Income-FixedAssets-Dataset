# Chapter 2 BEA/FRED Provider Variable Menu

## Purpose

This provider menu identifies and documents primitive BEA/FRED source inputs
required by Chapter 2. It does not construct GPIM stocks, adjusted
distributional variables, utilization, capacity, interactions, or econometric
datasets. Those objects remain owned by `Capacity-Utilization-US_Chile`.

## Provider Hierarchy

1. Direct BEA API table and line.
2. Exact or near-exact BEA-origin FRED fallback.
3. Financial corporate residual, `FC = CORP - NFC`, only where nominal
   accounting additivity is valid.
4. Explicit `unresolved` status.

API credentials are read only from `BEA_API_KEY` and `FRED_API_KEY`. Raw BEA
snapshots are preserved under `data/raw/provider/YYYY-MM-DD/`.

## Sector Boundaries

- `CORP`: total domestic corporate sector.
- `NFC`: nonfinancial domestic corporate sector.
- `FC`: financial corporate sector.
- `NA`: not sector-specific or a parameter.

No broader business, private, or economy total may silently replace these
boundaries.

## Financial Corporate Residual

Nominal income-account variables may document `FC = CORP - NFC` when the
underlying accounting values are additive. The provider does not perform final
Chapter 2 constructions. Real quantities and price indexes are not subtracted
unless an explicit aggregation identity is documented; unsupported FC
real/price objects remain unresolved.

## Fixed Assets and GPIM

Direct current-dollar investment from Fixed Assets Table 4.7 is the canonical
GPIM flow input when the exact asset-sector boundary exists. Stock-flow-implied
investment is fallback only:

```text
I_N_implied_i_t =
  K_N_CC_i_t
  - (P_K_i_t / P_K_i_t_minus_1) * K_N_CC_i_t_minus_1
  + CFC_CC_i_t
```

The provider documents this formula but does not replace direct investment or
construct GPIM capital stocks. ME and NRC may be aggregated in nominal or
current-cost terms. Post-GPIM real ME and NRC and official quantity indexes
must not be raw-added.

### FixedAssets Index Status

BEA FixedAssets real stocks, quantity indexes, and related index objects embody
BEA quality adjustment, asset-price treatment, depreciation, and aggregation
conventions. They are comparison objects, not canonical Chapter 2 GPIM inputs.

For `FAAt402`:

```text
chapter2_role = validation_only
construction_status = metadata_only
baseline_status = comparison_only
```

The indexes may validate GPIM trajectories and document divergence from BEA
benchmarks. They are not price indexes, GPIM products, or inputs for
raw-deflating the baseline GPIM stock.

## GVA Implicit Deflators

An implicit GVA deflator is a permitted source-level accounting construction
when nominal and real/chained-dollar GVA refer to the same sector boundary:

```text
GVA_deflator_t = 100 * GVA_current_t / GVA_real_chained_t
```

Units must be harmonized first. A current-dollar series and a quantity index
may instead support:

```text
GVA_price_index_t =
  100 * (GVA_current_t / GVA_current_base)
  / (GVA_quantity_index_t / 100)
```

using the quantity index's documented base year.

NFC current-dollar GVA (`T11400` line 17) and chained-dollar GVA (`T11400`
line 41) are validated at the same boundary. Therefore
`gva_price_or_deflator_nfc` is documented as:

```text
fetch_status = derivable_from_bea_components
construction_status = source_level_derived
chapter2_role = preferred_baseline_source
```

CORP remains a robustness-source review item. FC real GVA and price deflators
remain unresolved and must not be formed by raw residual subtraction.

## Outputs

- `data/provider_menu/ch2_master_variable_menu.csv`
- `data/provider_menu/ch2_master_variable_metadata.csv`
- `data/provider_menu/ch2_provider_fetch_status.csv`
- `data/provider_menu/ch2_bea_table_discovery.csv`
- `data/provider_menu/ch2_fred_fallback_candidates.csv`

## Scripts

- `codes/00_config_provider.R`
- `codes/01_discover_bea_metadata.R`
- `codes/02_discover_fred_candidates.R`
- `codes/03_build_ch2_master_variable_menu.R`
- `codes/04_fetch_ch2_provider_sources.R`
- `codes/05_validate_provider_fetches.R`

Run in numeric order. Without API keys, BEA discovery and validation use
preserved provider snapshots, while FRED discovery emits a schema-valid empty
candidate file rather than inventing matches.

## Open Unresolved Items

1. Whether FixedAssets exposes all investment flows at every exact
   asset-sector/legal-form boundary in future vintages.
2. Whether direct financial-corporate lines exist for all income-side
   variables outside Table 1.14.
3. Whether direct real/price GVA counterparts exist for CORP and FC. The NFC
   implicit deflator is already derivable from matching validated components.
4. Whether future FRED fallback candidates exactly match the required BEA
   concepts, units, frequency, and sample span.
5. A verified stock price or revaluation index for the stock-flow-implied
   investment fallback.

## Final Source-Acceptance Review

The six remaining unresolved rows were reviewed on 2026-06-11 against live BEA
metadata, preserved BEA snapshots, and the FRED candidate file. No candidate
met all acceptance conditions for dataset/table/line, metric, sector boundary,
unit, frequency, and source provenance.

- `gva_real_or_qindex_corp`: `T11400` has no chained-dollar CORP GVA line;
  FRED results were NFC unit-price or cost series.
- `gva_real_or_qindex_fc`: no direct FC real-GVA line; available candidates
  were NFC series.
- `gva_price_or_deflator_corp`: no matching same-boundary CORP real/quantity
  component or exact BEA-origin price series.
- `gva_price_or_deflator_fc`: no direct FC real/quantity component or accepted
  price series.
- `me_stock_price_or_revaluation_index`: no clean direct or FRED match.
- `nrc_stock_price_or_revaluation_index`: no clean direct or FRED match.

The FC rows must not be formed by raw residual subtraction. The ME/NRC
revaluation rows are non-blocking because direct nominal investment is
canonical; they are required only if the implied-investment fallback is
activated.
