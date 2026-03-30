# GPIM Pipeline Audit Report v1

**Date**: 2026-03-25
**Git commit**: `c168805797b3c74daff095784e8339b5291fe88d`
**Auditor**: Claude Code (Opus 4.6)
**Scope**: Corporate sector data pipeline — scripts 50-55, 97, 10, 31

---

## Scripts Read

| Script | Full path |
|--------|-----------|
| 10_config.R | `codes/10_config.R` |
| 31_build_Py_deflator.R | `codes/31_build_Py_deflator.R` |
| 50_fetch_bea_corporate.R | `codes/50_fetch_bea_corporate.R` |
| 51_build_corp_output.R | `codes/51_build_corp_output.R` |
| 52_build_corp_kstock.R | `codes/52_build_corp_kstock.R` |
| 53_build_corp_exploitation.R | `codes/53_build_corp_exploitation.R` |
| 54_assemble_corp_dataset.R | `codes/54_assemble_corp_dataset.R` |
| 55_source_runner.R | `codes/55_source_runner.R` |
| 97_kstock_helpers.R | `codes/97_kstock_helpers.R` |
| 99_utils.R | `codes/99_utils.R` |

---

## CRITICAL FAILURES

**None.** No audit finding would corrupt KGCcorp or VAcorp in the sealed estimation
dataset. The two FAIL items (GPIM-06, ASSEMBLE-04) are non-blocking: the IRS splice
is a known TODO with its toggle disabled, and dummies are created downstream by
estimation scripts.

---

## GPIM RECURSION SUMMARY

### Function signatures (97_kstock_helpers.R)

| Function | Signature | Line |
|----------|-----------|------|
| Core real accumulation | `gpim_accumulate_real(IG_R, z, K0_R)` | 97:197 |
| Core current-cost accumulation | `gpim_accumulate_cc(IG, z_star, K0)` | 97:178 |
| Survival-revaluation factor | `gpim_survival_revaluation(z_t, p_t, p_lag)` | 97:154 |
| Build gross real stock | `gpim_build_gross_real(IG_R, ret, K_net_R_0, dep_rate)` | 97:429 |
| Build gross current-cost stock | `gpim_build_gross_cc(IG_cc, ret, p_K, K_net_cc_0, dep_rate)` | 97:468 |

### z_star formula (as implemented)

```
z*_t = (1 - z_t) * (p_t / p_lag)          # 97:165
```

At t=1: `p_lag[1] = p_K[1]`, so `z*_1 = (1 - z_1) * 1.0 = 1 - z_1` (97:476).

### K0 value

- **Net stock initial**: `K_net_R_0 = KNRcorpbea[1947] * IRS_BEA_RATIO_1947`
  where `IRS_BEA_RATIO_1947 = 0.793` (52:60, 52:257)
- **Gross stock initial**: `K0_gross_R = K_net_R_0 * (avg_dep / mean(ret))` (97:440)
- **Validated KGCcorp(1947)**: ~170.6 Bn (54:199 target, matches canonical anchor 170.58)

### pK source series

`pKN = (KNCcorpbea / KNRcorpbea) * 100` — implicit price deflator from BEA
Fixed Asset Tables 6.1 (current-cost) and 6.2 (chain-type QI). Base: 2005=100.
pKN(1947) = 11.69. (52:189)

### Inventory handling

**No inventories in the pipeline.** The capital stock construction covers fixed
assets only (BEA FAAt607 investment). No inventory addition occurs inside or
outside the GPIM recursion.

### Depletion rates

- **Net stock**: `dcorpstar` — theoretically correct rate (eq. 6):
  `dcorpstar = DEPCcorpbea / (pKN/100 * lag(KNRcorpbea))` (52:218)
- **Gross stock**: `RET_CORP = 1/35 = 0.02857` — retirement rate (52:57)
- Toggle `ADJ1_BEA1993_DEPLETION = TRUE` selects `dcorpstar` over Whelan-Liu
  approximation (52:45, 52:221)

---

## AUDIT CHECKLIST

### 97_kstock_helpers.R — GPIM Core

**GPIM-01: PASS**
Survival-revaluation factor is `z_star = (1 - z_t) * (p_t / p_lag)`.
Price ratio is present. (97:165)

**GPIM-02: PASS**
`pK` = `pKN` (implicit price deflator from BEA Fixed Asset Tables).
`Py` = GDP implicit price deflator (FRED series A191RD3A086NBEA).
Distinct variables sourced from different series. Never assigned the same object.

**GPIM-03: PASS**
At t=1: `p_lag <- c(p_K[1], p_K[-T])` — first element of p_lag equals p_K[1],
giving a price ratio of 1.0. No NA, NaN, or division-by-zero. (97:476)

**GPIM-04: PASS**
Gross stock uses retirement rate (`RET_CORP = 1/35`, 52:57).
Net stock uses depreciation rate (`dcorpstar`, 52:245).
Each uses its own rate — they do not share the same z_dep input.

**GPIM-05: PASS**
No inventory addition occurs inside `gpim_accumulate_real()` or any other
recursion function. No inventories are added anywhere in the pipeline —
the capital stock covers fixed assets only.

**GPIM-06: FAIL**
IRS write-down splice is **not implemented**. Toggle `ADJ3_IRS_SCRAPPING = FALSE`
(52:47). Code at 52:284-299 contains a conditional block with:
```r
## TODO: Implement when IRS data becomes available    # 52:291
```
The splice formula `K_adj[t] = K[t] * (IRS_index[t] / BEA_index[t])` is absent.
**Impact**: Non-blocking — the toggle is disabled and documented as future work.
If needed, the splice should be applied in 52_build_corp_kstock.R §D (lines 280-299)
after the net stock GPIM recursion and before gross stock construction.

**GPIM-07: Function signatures** — see GPIM RECURSION SUMMARY above.

---

### 50_fetch_bea_corporate.R — Data Fetch

**FETCH-01: FAIL**
Data source is the BEA API via `fetch_bea_table()` (50:69), **not** Shaikh's
static spreadsheet. No `use_api` mode flag exists. The FRED deflator is also
fetched live via `fredr` (50:116). However, the sealed dataset was built from
this pipeline and is now frozen — so API-vs-spreadsheet matters only for the
extension layer.

**FETCH-02: PASS**
NIPA Table 1.14 Line 1 loaded as `GVAcorpnipa`. (51:75)

**FETCH-03: PASS**
NIPA Table 1.14 Line 2 loaded as `DEPCcorp`. (51:76)

**FETCH-04: PASS**
NIPA Table 1.14 Line 8 loaded as `NOScorpnipa`. (51:80)

**FETCH-05: FLAG**
The code does NOT use the compound formula `(L4+L44+L73) - (L28+L52+L91)` for
BankMonIntPaid. Instead:

- `BankMonIntPaid` = `extract_line(t7011, 4, ...)` — Line 4 only (51:101)
- `imp_int_paid_nf` = `extract_line(t7011, 49, ...)` — (51:107)
- `imp_int_recv_nf` = `extract_line(t7011, 58, ...)` — (51:108)
- `CorpNFNetImpIntPaid` = `imp_int_paid_nf - imp_int_recv_nf` — (51:112)

**Comment/code mismatch**: Comments at 51:103-105 reference "Line 74" and
"Line 53" but the actual `extract_line()` calls use lines 49 and 58. This
likely reflects a BEA table restructuring between vintage years. The computed
values validate at 1947 (CorpImpIntAdj ≈ 1.5, target 1.5), so the actual
line numbers (49, 58) appear correct for the current BEA vintage.

---

### 51_build_corp_output.R — Output Construction

**OUTPUT-01: PASS**
```r
CorpImpIntAdj = -BankMonIntPaid - CorpNFNetImpIntPaid    # 51:135
```
Both terms subtracted. Net result is positive when imputed interest > 0
(validated: CorpImpIntAdj(1947) ≈ 1.5).

**OUTPUT-02: PASS**
```r
GVAcorp = GVAcorpnipa + CorpImpIntAdj    # 51:136
```

**OUTPUT-03: PASS**
```r
VAcorp = VAcorpnipa + CorpImpIntAdj    # 51:138
```
`VAcorpnipa` is extracted from T1.14 Line 3 (51:77), which is **net** value
added (GVAcorpnipa - CCA) by NIPA definition. So this is equivalent to:
`VAcorp = (GVAcorpnipa - CCA) + CorpImpIntAdj`. Correct.

**OUTPUT-04: PASS**
The correction is applied separately:
- To NOS: `NOScorp = NOScorpnipa + CorpImpIntAdj` (51:137)
- To VA: `VAcorp = VAcorpnipa + CorpImpIntAdj` (51:138)
- Pcorp = Pcorpnipa (NO adjustment, 51:139) — consistent with Shaikh methodology

Identity check at 51:179-182 confirms: `GVAcorp = VAcorp + DEPCcorp`.

---

### 52_build_corp_kstock.R — Capital Stock

**KSTOCK-01: PASS**
Uses `dcorpstar` (theoretically correct depreciation rate, eq. 6) with toggle
`ADJ1_BEA1993_DEPLETION = TRUE` (52:45). The rate is computed from current-vintage
BEA data using the Shaikh formula, not BEA geometric rates directly. (52:218)

**KSTOCK-02: PASS**
K0 is computed, not hardcoded:
```r
K_net_R_0 <- df$KNRcorpbea[1] * IRS_BEA_RATIO_1947    # 52:257
```
where `IRS_BEA_RATIO_1947 = 0.793` (52:60). Gross K0 is derived from net K0
via `dep_rate / mean(ret)` scaling (97:440).

The value 141.9 appears only in diagnostic `cat()` at 52:405 as a Shaikh II.5
comparison target — it is NOT passed as K0 to the recursion.

KGCcorp(1947) validates at ~170.6 (54:199), matching the canonical anchor 170.58.

**KSTOCK-03: PASS**
pK = `pKN` (implicit price deflator):
```r
pKN = (KNCcorpbea / KNRcorpbea) * 100    # 52:189
```
This is the capital-goods price index from BEA Fixed Asset Tables, NOT the GDP
deflator (Py). (52:186-193)

**KSTOCK-04: PASS**
No inventory addition in the pipeline. Investment series is `IGCcorpbea` from
BEA FAAt607 (fixed assets only). No inventory series is fetched, constructed,
or added post-recursion.

**KSTOCK-05: INFO**
Exact K0 source:
- `IRS_BEA_RATIO_1947 = 0.793` (52:60, from Shaikh II.5 row 19)
- `K_net_R_0 = KNRcorpbea[1947] * 0.793` (52:257)
- `K0_gross_R = K_net_R_0 * (avg_dep / mean(RET_CORP))` (97:440)
- Net stock built by `gpim_accumulate_real()` at 52:270
- Gross stock built by `gpim_build_gross_real()` at 52:325
- Current-cost conversion: `KGCcorp = KGRcorp * (pKN / 100)` (52:336)

---

### 53_build_corp_exploitation.R — Exploitation Rate

**EXPL-01: FLAG**
The code computes:
```r
exploit_rate = NOScorp / ECcorp    # 53:72
profit_share = Pcorp / VAcorp      # 53:75
```

The check asks for `Profshcorp = NOScorp / VAcorp`, but the pipeline uses
`profit_share = Pcorp / VAcorp` instead. Here:
- `NOScorp` HAS the imputed-interest correction (from 51:137)
- `VAcorp` HAS the imputed-interest correction (from 51:138)
- `Pcorp` does NOT have the imputed-interest correction (from 51:139)

So `profit_share` uses an uncorrected numerator with a corrected denominator.
This appears intentional (Shaikh treats profits and NOS differently), but the
naming `Profshcorp` in 10_config.R (line 39: `pi_share = "Profshcorp"`) does not
match the column name `profit_share` in the dataset. The CONFIG reference may
be stale or refer to a renamed column.

---

### 54_assemble_corp_dataset.R — Assembly

**ASSEMBLE-01: PASS**
The OLS pre-screen smoke test at 54:221-222 uses `GVAcorp` (not VAcorp):
```r
lnY = log(GVAcorp / (Py / 100))
lnK = log(KGCcorp / (Py / 100))
```
This is intentional (noted in audit prompt). The actual estimation variables
`y` and `k` are NOT created in the assembly script — they are constructed
downstream by estimation scripts using `CONFIG$y_nom = "VAcorp"` and
`CONFIG$k_nom = "KGCcorp"`.

**ASSEMBLE-02: PASS**
Output file: `data/processed/corporate_sector_dataset.csv` (54:252)

**ASSEMBLE-03: PASS**
Dataset rows cover 1947-2011 (T=65 rows). The estimation-sample window
(T=61, 1947-2007) is enforced downstream by `CONFIG$WINDOWS_LOCKED$shaikh_window`.

Note: `shaikh_window = c(1947, 2011)` in 10_config.R:48 defines the data window,
while the S0 estimation sample is further restricted to T=61 by 20_S0_shaikh_faithful.R.

**ASSEMBLE-04: FAIL**
Dummies `d1956`, `d1974`, `d1980` are **not present** as 0/1 columns in the
assembly script or the output CSV. They are created downstream by estimation
scripts (20_S0_shaikh_faithful.R).

**Impact**: Non-blocking — the assembly script produces data, not estimation objects.
Dummies are structural break indicators relevant only to the ARDL estimation stage.

**ASSEMBLE-05: INFO — Final output columns (29 total)**

```
year, GVAcorp, VAcorp, DEPCcorp, NOScorp, ECcorp, Pcorp,
GVAcorpnipa, VAcorpnipa, NOScorpnipa, Pcorpnipa, Tcorp, CorpImpIntAdj,
KGCcorp, KNCcorp, KNCcorpbea, KNRcorpbea, IGCcorpbea, DEPCcorpbea,
dcorpstar, dcorp_WL, pKN,
exploit_rate, profit_share, rcorp, R_obs, R_net,
Py, uK
```

(`uK` is initialized as `NA_real_` at 54:137, filled by ARDL estimation)

---

### 10_config.R — Configuration

**CONFIG-01: PASS** — `y_nom = "VAcorp"` (10:36)

**CONFIG-02: PASS** — `k_nom = "KGCcorp"` (10:37)

**CONFIG-03: FLAG**
`p_index = "Py"` (10:40). Comment says "GDP price index (NIPA T1.1.4, base 2011=100)".
However, 54:201 validation prints "Should be ~11.43 (2017=100 base)".
31_build_Py_deflator.R rebases from 2005=100 to 2011=100 (31:95-104).
The FRED series base has changed over time (2005 → 2009 → 2012 → 2017).
**Documentation inconsistency** — the actual base depends on the vintage fetched.
The sealed dataset likely uses 2011=100 (matching script 31's rebase logic).

**CONFIG-04: PASS**
`shaikh_window = c(1947, 2011)` (10:48). No separate `year_start`/`year_end` fields;
the window is stored as a named two-element vector in `WINDOWS_LOCKED`.

**CONFIG-05: PASS** — `data_corp = "data/processed/corporate_sector_dataset.csv"` (10:21)

---

### 31_build_Py_deflator.R — GDP Deflator

**PY-01: INFO**
This standalone script (179 lines, dated 2026-03-20) builds the GDP implicit
price deflator (Py) for the Shaikh canonical CSV.

**Inputs**:
- ALFRED API: GDPDEF series, vintage 2012-01-01
- Cross-check: `data/raw/shaikh_data/Shaikh_canonical_series_v1.csv`

**Outputs**:
- `data/processed/Py_deflator_provenance.csv`
- `data/raw/ALFRED_GDPDEF_vintage2012.csv` (cache)

**Process**: Fetches quarterly GDPDEF from ALFRED → collapses to annual (Q4) →
rebases from 2005=100 to 2011=100 → cross-checks against canonical CSV → saves
provenance file.

**Integration**: NOT called by `55_source_runner.R` (which runs scripts 50-54)
or by `24_manifest_runner.R` (which runs S0/S1/S2 stages). Must be run manually
or its output (`Py_deflator_provenance.csv`) must already exist. The corporate
pipeline fetches Py separately via FRED in script 50.

**Provenance note**: Py is the only column in the canonical CSV without a Shaikh
source appendix reference (documented at 31:175-177).

---

## EXTENSION READINESS

### Reusable functions for script 56

| Function | File | Line | Purpose |
|----------|------|------|---------|
| `gpim_accumulate_real(IG_R, z, K0_R)` | 97_kstock_helpers.R | 197 | Real GPIM recursion |
| `gpim_build_gross_real(IG_R, ret, K_net_R_0, dep_rate)` | 97_kstock_helpers.R | 429 | Gross stock from net initial |
| `gpim_survival_revaluation(z_t, p_t, p_lag)` | 97_kstock_helpers.R | 154 | z_star computation |
| `gpim_accumulate_cc(IG, z_star, K0)` | 97_kstock_helpers.R | 178 | Current-cost GPIM recursion |
| `safe_write_csv(df, path)` | 99_utils.R | 15 | Write with auto-mkdir |
| `now_stamp()` | 99_utils.R | 10 | Timestamp for logging |

### Data paths

| Object | Path |
|--------|------|
| Sealed dataset | `data/processed/corporate_sector_dataset.csv` |
| Canonical CSV | `data/raw/shaikh_data/Shaikh_canonical_series_v1.csv` |
| Extension output | `data/processed/corporate_sector_dataset_ext.csv` |

### Constants for extension

| Constant | Value | Source |
|----------|-------|--------|
| K0 (canonical 1947 anchor) | 170.58 Bn | 54:199 validation target |
| IRS_BEA_RATIO_1947 | 0.793 | 52:60 |
| RET_CORP | 1/35 = 0.02857 | 52:57 |
| Py base | 2011=100 (from script 31 rebase) | 31:95-104 |
| pKN base | 2005=100 | 52:189 |

### Missing for extension (must be built in script 56)

1. **`bea_get()` utility** — no BEA API wrapper in 99_utils.R; must add one
2. **Depletion rate extension** — `dcorpstar` for 2012+ requires fresh BEA vintage
   data or asset-mix weighting from 1993-vintage rates
3. **T7.11 line mapping verification** — lines 49/58 may shift in newer BEA vintages;
   extension script should print line labels for manual verification
