# Chapter 2 Provider Handoff

This bundle is the finalized provider-side source menu for Chapter 2. It is
intended for downstream use by the Chapter 2 data-management and econometrics
repo.

It does not contain final Chapter 2 econometric variables. It does not
construct utilization, productive capacity, adjusted distribution variables,
GPIM gross stocks, centered variables, interactions, or q-indexes.

## Bundle Status

```text
Variable-menu rows: 71
Locked source concepts: 65
Implied-investment fallback metadata rows: 6
Metadata rows: 71
BEA table metadata candidates: 361
FRED search candidates: 337
Accepted FRED candidates: 0
Provider validation: 71 PASS / 0 FAIL
Existing repository validation: PASS
```

## Unresolved Rows

- `gva_real_or_qindex_corp`
- `gva_real_or_qindex_fc`
- `gva_price_or_deflator_corp`
- `gva_price_or_deflator_fc`
- `me_stock_price_or_revaluation_index`
- `nrc_stock_price_or_revaluation_index`

No unresolved row blocks the baseline. Direct nominal ME/NRC investment is
canonical. Stock-flow-implied investment remains fallback-only and requires a
valid stock-price/revaluation index if activated. `FAAt402` quantity indexes
remain metadata-only comparison/validation objects and are not GPIM products
or baseline price indexes.

`gva_price_or_deflator_nfc` is source-level derived from matching NIPA Table
1.14 NFC current-dollar and chained-dollar GVA components. CORP and FC
real/price rows remain unresolved. Nominal FC residuals are permitted only
where accounting additivity is valid; real and price FC residuals are
prohibited.

## Downstream Boundary

The downstream repo owns real-variable construction, adjusted distribution
variables, GPIM gross stocks, productive capital scale, ME-NRC composition,
centered variables, interaction terms, econometric datasets, and estimations.

`MANIFEST.csv` covers every payload file and this handoff note. The manifest
does not list itself because a stable self-referential SHA-256 checksum is not
defined.
