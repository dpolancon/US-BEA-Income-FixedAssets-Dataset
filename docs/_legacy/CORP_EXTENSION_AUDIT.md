# Corporate Sector Extension — Pre-Build Audit

**Date**: 2026-03-14
**Auditor**: Claude Code (automated)
**Purpose**: Verify data availability before building 50-series corporate pipeline

---

## 1. BEA Parsed Tables (`data/interim/bea_parsed/`)

**Status**: EMPTY — directory contains only `.gitkeep`

No BEA tables have been fetched yet. The 40-series pipeline (scripts 41–49) has not been run.
The corporate pipeline (script 50) must fetch its own tables independently.

**Tables needed for corporate sector (not yet fetched)**:
- `FAAt601` — Private FA by Legal Form: Current-Cost Net Stock
- `FAAt602` — Private FA by Legal Form: Chain-Type QI Net Stock
- `FAAt603` — Private FA by Legal Form: Historical-Cost Net Stock
- `FAAt604` — Private FA by Legal Form: Current-Cost Depreciation
- `FAAt607` — Private FA by Legal Form: Investment

**NIPA tables needed (not yet fetched)**:
- `T11400` — NIPA Table 1.14: Gross Value Added of Corporate Business
- `T71100` — NIPA Table 7.11: Interest Paid and Received
- `T10104` — NIPA Table 1.1.4: GDP Implicit Price Deflator (for Py)

### BEA Table Naming — RESOLVED

BEA Fixed Assets Section 6 (FAAt601-604) = **Private FA by Industry Group and Legal Form
of Organization** (contains corporate lines). Government FA is in Section 7 (FAAt701-704).

The `40_gdp_kstock_config.R` previously mislabeled FAAt601-604 as "Government" — this has
been corrected. The config now maps:
- `private_lf_*` → FAAt601-604 (Section 6: Private FA by Legal Form)
- `govt_*` → FAAt701-704 (Section 7: Government Fixed Assets)

---

## 2. NIPA T1.14 and T7.11

**Status**: NOT fetched. No NIPA data exists in `data/interim/bea_parsed/`.

These must be fetched via BEA API with `datasetname = "NIPA"`.

---

## 3. IRS Book Value File

**Status**: `data/raw/irs_book_value.csv` — **DOES NOT EXIST**

Consequence: `CORP_ADJ$ADJ3_IRS_SCRAPPING` must be set to `FALSE`.
The Great Depression scrapping correction (Shaikh Appendix 6.8, eq. 17–18) cannot be applied.
This is consistent with the whole-economy pipeline which also has `ADJ_DEPRESSION_SCRAPPING = FALSE`.

---

## 4. GDP Deflator File

**Status**: `data/processed/gdp_us_1925_2024.csv` — **DOES NOT EXIST**

The 40-series pipeline has not been run. The only deflator data available is:
- `data/raw/ALFRED_GDPDEF_vintage2012.csv` — quarterly vintages, `Py_alfred` column, covers 1947–~2011

This is insufficient because:
1. It contains quarterly (vintage) data, not clean annual series
2. Base year is not 2017=100
3. Coverage may end before 2024

**Resolution**: Script 50 will fetch NIPA Table 1.1.4 (`T10104`) directly from the BEA API
to obtain the GDP implicit price deflator (Py) at annual frequency with 2017=100 base.

---

## 5. Shaikh Canonical Series

**Status**: `data/raw/Shaikh_canonical_series_v1.csv` — **EXISTS**

**Columns** (32): `year, VAcorp, NOScorp, Pcorpnipa, NMINT, KGCcorp, INVcorp, KTCcorp, Rcorp, Profshcorp, rcorp, VAcorpnipa, KNCcorpbea, Rcorpnipa, Profshcorpnipa, rcorpnipa, uK, uFRB, Rcorpn, Profshcorpn, rcorpn, IGCcorpbea, DEPCcorp, pIGcorpbea, GOSRcorp, ECcorp, WEQ2, VAcorp_check, Pcorp, rcorp_sectoral, exploit_rate, pKN`

**Year range**: 1946–2011 (1946 has partial data; 1947 is first complete row)

**1947 benchmark values** (for validation):
| Variable | 1947 Value |
|----------|------------|
| VAcorp | 118.6 |
| NOScorp | 24.9 |
| KGCcorp | 170.58 |
| KNCcorpbea | 190.1 |
| ECcorp | 82.1 |
| DEPCcorp | 8.9 |
| exploit_rate | 0.303 |
| pKN | 11.687 |
| pIGcorpbea | 23.29 |
| IGCcorpbea | 15.7 |

---

## 6. API Keys

**Status**: Hardcoded defaults available in `codes/40_gdp_kstock_config.R`

```r
BEA_API_KEY  = Sys.getenv("BEA_API_KEY", unset = "6EA6700D-A126-484F-A9FC-7DB7E4E0FA4F")
FRED_API_KEY = Sys.getenv("FRED_API_KEY", unset = "fc67199ea06d765ef79b3011dcf75c45")
```

BEA API key is available for fetching. FRED API key is available but not needed for corporate pipeline.

---

## 7. Existing Helper Functions Available for Reuse

From `codes/97_kstock_helpers.R`:
- `parse_bea_api_response()` — BEA API → long format (year, line_number, line_desc, value)
- `validate_line_map()` — verify line numbers match expected descriptions
- `gpim_depreciation_rate()` — theoretically correct rate (eq. 6)
- `gpim_whelan_liu_rate()` — Whelan-Liu approximate rate (eq. 8)
- `gpim_accumulate_real()` — constant-cost accumulation (eq. 5)
- `gpim_accumulate_cc()` — current-cost accumulation (eq. 3)
- `gpim_survival_revaluation()` — z*_t factor (eq. 4)
- `gpim_build_gross_real()` — gross stock with retirement rates
- `gpim_build_gross_cc()` — gross stock current-cost
- `validate_sfc_identity()` — SFC residual check
- `rebase_index()` — rebase price index to new base year
- `log_data_quality()` — series summary statistics
- `ensure_dirs()` — create output directories

From `codes/99_utils.R`:
- `safe_write_csv()` — write CSV with auto-created parent directories
- `now_stamp()` — formatted timestamp

---

## Audit Conclusion

**GO**: All required API access is available. Helper functions exist for GPIM construction.
Script 50 must fetch 8 BEA tables (5 FixedAssets + 3 NIPA) before downstream scripts can run.
ADJ_3 (IRS scrapping) is unavailable and will be skipped.
BEA table naming conflict has been resolved (FAAt6xx = Section 6 legal form, FAAt7xx = Section 7 government).
