# Chapter 2 Provider Closure

**Closure date:** 2026-06-11

## Implementation Status

The Chapter 2 BEA/FRED provider scaffold is complete with 71 variable-menu
rows: 65 locked source concepts and 6 implied-investment fallback metadata
rows. The architecture and locked concept set were not changed during closure.
No FRED candidate was accepted.

## Validation Status

- Provider scaffold validation: 71 PASS / 0 FAIL.
- Existing repository validation: PASS.
- Direct nominal investment remains canonical.
- Implied investment remains fallback-only.
- `FAAt402` remains metadata-only and comparison/validation-only.
- `gva_price_or_deflator_nfc` remains source-level derived from matching NFC
  current-dollar and chained-dollar GVA components.
- Real and price FC residual construction remains prohibited.

## Unresolved Rows

- `gva_real_or_qindex_corp`
- `gva_real_or_qindex_fc`
- `gva_price_or_deflator_corp`
- `gva_price_or_deflator_fc`
- `me_stock_price_or_revaluation_index`
- `nrc_stock_price_or_revaluation_index`

These rows are non-blocking. The CORP and FC GVA gaps have no accepted
same-boundary source counterpart, and FC real/price residuals are not valid.
The ME/NRC stock revaluation indexes are needed only if the implied-investment
fallback is activated; direct nominal investment remains available and
canonical.

## Handoff

The finalized bundle is located at:

```text
data/downstream/chapter2_provider_handoff/2026-06-11/
```

An identical checksum-verified copy was placed at:

```text
C:\ReposGitHub\Capacity-Utilization-US_Chile\data\provider_handoffs\US_BEA_FixedAssets\2026-06-11\
```

The Chapter 2 data-management/econometrics repo is responsible for constructing
real variables, adjusted distribution variables, GPIM gross stocks, productive
capital scale, ME-NRC composition, centered variables, interaction terms,
econometric datasets, and estimations.
