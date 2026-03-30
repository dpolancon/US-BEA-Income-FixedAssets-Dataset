# BEA_LineMap_v1
## Precise BEA API Table and Line Number Mappings for Dataset 2

**Date:** 2026-03-26 | **Status:** LOCKED | **BEA Revision:** September 26, 2025
**API base:** `https://apps.bea.gov/api/data`

> This document maps every series in Dataset 2 to its exact BEA table, API table code, and line number. Claude Code reads this before writing any fetch code. Line numbers are from the September 2025 revision and must be verified against BEA API responses before use.

---

# 1. BEA Fixed Assets API — Capital Stock Tables

## 1.1 API Parameters

```r
bea_fetch <- function(TableName, LineDescription=NULL, Year="X") {
  httr::GET(
    url = "https://apps.bea.gov/api/data",
    query = list(
      UserID      = Sys.getenv("BEA_API_KEY"),
      method      = "GetData",
      DataSetName = "FixedAssets",
      TableName   = TableName,
      Year        = Year,
      ResultFormat = "JSON"
    )
  )
}
```

**Key table codes:**

| BEA Table | API TableName | Type | Coverage |
|-----------|--------------|------|----------|
| Table 6.1 | `FAAt601` | Current-cost net stock, private by legal form | 1925–2024 |
| Table 6.2 | `FAAt602` | Chain-type quantity index, private by legal form | 1925–2024 |
| Table 6.7 | `FAAt607` | Investment, private by legal form | 1901–2024 |
| Table 7.1 | `FAAt701` | Current-cost net stock, government | 1925–2024 |
| Table 7.2 | `FAAt702` | Chain-type quantity index, government | 1925–2024 |
| Table 7.5 | `FAAt705` | Investment, government | 1901–2024 |

> ⚠️ **Verification required:** BEA periodically renumbers lines across vintages. Always verify by inspecting the API response `LineDescription` field before hardcoding line numbers.

---

# 2. Account A — NF Corporate Structures

**Source tables:** FAAt601 (net stock), FAAt602 (chain-type qty), FAAt607 (investment)
**Legal form:** Nonfinancial corporate
**Asset type:** Structures

## 2.1 Net stock — FAAt601

| Series | LineDescription (expected) | Line | Notes |
|--------|---------------------------|------|-------|
| `KNC_NF_struct` | Nonfinancial corporate; Structures | Verify | Match on description, not line number |

**Fetch strategy:** Pull full FAAt601. Filter by `LineDescription` matching "Nonfinancial corporate" AND "Structures".

## 2.2 Chain-type index — FAAt602

| Series | LineDescription (expected) | Notes |
|--------|---------------------------|-------|
| `KNR_NF_struct_idx` | Nonfinancial corporate; Structures | Same line position as FAAt601 |

`pK_NF_struct = KNC_NF_struct / (KNR_NF_struct_idx / 100) * 100`. Rebase to 2017=100.

## 2.3 Investment — FAAt607

| Series | LineDescription (expected) | Coverage | Notes |
|--------|---------------------------|----------|-------|
| `IG_NF_struct` | Nonfinancial corporate; Structures | 1901–2024 | Used in GPIM + 1901 warmup |

---

# 3. Account B — NF Corporate Equipment

**Source tables:** FAAt601, FAAt602, FAAt607
**Legal form:** Nonfinancial corporate
**Asset type:** Equipment

## 3.1 Net stock — FAAt601

| Series | LineDescription (expected) |
|--------|---------------------------|
| `KNC_NF_equip` | Nonfinancial corporate; Equipment |

## 3.2 Chain-type index — FAAt602

| Series | LineDescription (expected) |
|--------|---------------------------|
| `KNR_NF_equip_idx` | Nonfinancial corporate; Equipment |

## 3.3 Investment — FAAt607

| Series | LineDescription (expected) | Coverage |
|--------|---------------------------|----------|
| `IG_NF_equip` | Nonfinancial corporate; Equipment | 1901–2024 |

---

# 4. Account C — Government Transportation Infrastructure

**Source tables:** FAAt701 (net stock), FAAt702 (chain-type), FAAt705 (investment)
**Owner:** Federal + State and local (both)
**Structure types:** Highways and streets, Air transportation, Land transportation (transit)

## 4.1 Net stock — FAAt701

| Series | LineDescription (expected) | Notes |
|--------|---------------------------|-------|
| `KNC_gov_highways` | Government; Structures; Highways and streets | ~40–50% of gov structures |
| `KNC_gov_air` | Government; Structures; Air transportation | Airports, terminals |
| `KNC_gov_land` | Government; Structures; Other transportation (land) | Rail, transit lines |

**Aggregation:**
```r
KNC_gov_transport <- KNC_gov_highways + KNC_gov_air + KNC_gov_land
```

> **Note:** BEA Table 7.1 may report Federal and State/Local separately. Sum both levels. Verify using `LineDescription` patterns "Highways and streets", "Transportation" (non-military).

**Excluded structure types (do not include):**
- Military facilities, Educational buildings, Health care, Office/administrative
- Power structures (electricity/gas — enabling but not transportation)
- Conservation and development

## 4.2 Chain-type index — FAAt702

| Series | LineDescription |
|--------|----------------|
| `KNR_gov_highways_idx` | Government; Highways and streets |
| `KNR_gov_air_idx` | Government; Air transportation |
| `KNR_gov_land_idx` | Government; Land transportation |

**Aggregate pK:**
```r
KNR_gov_transport_idx <- KNR_gov_highways_idx + KNR_gov_air_idx + KNR_gov_land_idx
pK_gov_transport <- KNC_gov_transport / (KNR_gov_transport_idx / 100) * 100
```

## 4.3 Investment — FAAt705

| Series | LineDescription | Coverage |
|--------|----------------|----------|
| `IG_gov_highways` | Government; Investment; Highways and streets | 1901–2024 |
| `IG_gov_air` | Government; Investment; Air transportation | 1901–2024 |
| `IG_gov_land` | Government; Investment; Land transportation | 1901–2024 |

---

# 5. Account D — NF Corporate IPP (Separate Tracking)

**Source tables:** FAAt601, FAAt602, FAAt607

| Series | LineDescription | Table | Coverage |
|--------|----------------|-------|----------|
| `KNC_NF_IPP` | Nonfinancial corporate; Intellectual property products | FAAt601 | 1925–2024 |
| `KNR_NF_IPP_idx` | Nonfinancial corporate; Intellectual property products | FAAt602 | 1925–2024 |
| `IG_NF_IPP` | Nonfinancial corporate; Intellectual property products | FAAt607 | 1901–2024 |

> **Note:** IPP does NOT enter KGC_productive. Tracked separately as a capital-reshaping intangible.

---

# 6. Supplementary Capital Series (Separately Tracked)

## 6.1 Financial corporate total — FAAt601

| Series | LineDescription | Notes |
|--------|----------------|-------|
| `KNC_F_struct` | Financial corporate; Structures | Financialization tracker |
| `KNC_F_equip` | Financial corporate; Equipment | |
| `KNC_F_IPP` | Financial corporate; Intellectual property products | |

## 6.2 Noncorporate private — FAAt601

| Series | LineDescription | Notes |
|--------|----------------|-------|
| `KNC_noncorp_struct` | Noncorporate; Structures | Sensitivity series |
| `KNC_noncorp_equip` | Noncorporate; Equipment | |

---

# 7. NIPA Table 1.14 — NF Corporate Income Accounts

**API:** NIPA dataset, TableName = `T11400`
**Coverage:** 1947–2024
**Fetch:** `DataSetName="NIPA"`, `TableName="T11400"`

## 7.1 NF Corporate Block — Lines 17–40

| Series | Line | LineDescription (expected) | Notes |
|--------|------|---------------------------|-------|
| `GVA_NF` | 17 | Gross value added of nonfinancial corporate business | |
| `CCA_NF` | 18 | Consumption of fixed capital | Cross-check with DEP from Fixed Assets |
| `NVA_NF` | 19 | Net value added | **Canonical Y_t** |
| `EC_NF` | 20 | Compensation of employees | |
| `Wages_NF` | 21 | Wages and salaries | |
| `Supplements_NF` | 22 | Supplements to wages and salaries | |
| `TPI_NF` | 23 | Taxes on production and imports less subsidies | |
| `NOS_NF` | 24 | Net operating surplus | |
| `NetInt_NF` | 25 | Net interest and miscellaneous payments | |
| `BusTransfer_NF` | 26 | Business current transfer payments (net) | |
| `Profits_IVA_CC_NF` | 27 | Corporate profits with IVA and CCAdj | |
| `CorpTax_NF` | 28 | Taxes on corporate income | |
| `PAT_IVA_CC_NF` | 29 | Profits after tax with IVA and CCAdj | |
| `Dividends_NF` | 30 | Net dividends | |
| `Retained_IVA_CC_NF` | 31 | Undistributed profits with IVA and CCAdj | |
| `PBT_NF` | 32 | Corporate profits before tax (without IVA and CCAdj) | |
| `PAT_NF` | 33 | Profits after tax (without IVA and CCAdj) | |
| `Retained_NF` | 34 | Undistributed profits after tax (without IVA and CCAdj) | |
| `IVA_NF` | 35 | Inventory valuation adjustment | |
| `CCAdj_NF` | 36 | Capital consumption adjustment | |

> ⚠️ **Line number verification:** NIPA T1.14 line numbers shift across comprehensive revisions. Always match on `LineDescription` field, not on line number alone.

## 7.2 Derived series (computed, not fetched)

```r
GOS_NF   <- GVA_NF - EC_NF - TPI_NF          # Gross operating surplus
ProfSh   <- NOS_NF / NVA_NF                   # Net profit share
WageSh   <- EC_NF  / NVA_NF                   # Wage share
RetRate  <- Retained_NF / PAT_NF              # Retention ratio
DivPay   <- Dividends_NF / PAT_NF             # Dividend payout ratio
```

## 7.3 Cross-account SFC check

```r
DEP_NF_fixed_assets <- IG_NF_struct + IG_NF_equip -
  (KNC_NF_struct - lag(KNC_NF_struct)) -
  (KNC_NF_equip  - lag(KNC_NF_equip))

# Check: CCA_NF_NIPA ~= DEP_NF_fixed_assets
# Discrepancy expected: NF structures+equipment only vs all NF fixed assets
# Flag large deviations (> 5% of CCA_NF) as data quality warnings
```

---

# 8. FRED — GDP Deflator

**Series:** `A191RD3A086NBEA`
**Description:** Gross Domestic Product: Implicit Price Deflator (2017=100)
**Coverage:** 1929–2024

```r
fetch_Py_deflator <- function() {
  fredr::fredr(
    series_id         = "A191RD3A086NBEA",
    observation_start = as.Date("1925-01-01"),
    observation_end   = as.Date("2024-12-31"),
    frequency         = "a"
  ) |>
  dplyr::select(year = date, Py = value) |>
  dplyr::mutate(year = lubridate::year(year))
}
```

**Base year:** Already 2017=100 in current FRED release. No rebasing needed.
**Pre-1929 gap:** FRED Py starts in 1929. Years 1925–1928 will be NA — acceptable since estimation objects start from 1947+.

---

# 9. Investment Flows 1901 — Warmup Data

| Series | Table | Coverage | Notes |
|--------|-------|----------|-------|
| `IG_NF_struct_1901` | FAAt607 | 1901–2024 | Same series as §2.3 — full range |
| `IG_NF_equip_1901` | FAAt607 | 1901–2024 | Same series as §3.3 |
| `IG_gov_transport_1901` | FAAt705 | 1901–2024 | Same series as §4.3 |

**Warmup procedure (when `USE_1901_WARMUP = TRUE`):**
1. Start GPIM recursion from 1901 with `KGC_R_1901 = 0` (cold start)
2. Accumulate using investment flows only
3. At 1925: compare accumulated KGC_R * pK_1925 to BEA-reported KNC_1925
4. Log warmup gap: `warmup_gap = abs(KGC_accumulated_1925 - KNC_1925) / KNC_1925`
5. If warmup gap > 10%, issue warning. Do not halt.
6. From 1925: use BEA-reported KNC_1925 as net stock anchor; continue GPIM forward

---

# 10. API Fetch Verification Protocol

```r
# Step 1: Fetch full table and inspect structure
raw <- bea_fetch(TableName="FAAt601", Year="2022")
lines_df <- raw$BEAAPI$Results$Data |>
  dplyr::select(LineDescription, LineNumber, TimePeriod, DataValue) |>
  dplyr::filter(TimePeriod == "2022") |>
  dplyr::distinct(LineDescription, LineNumber)

# Step 2: Search for target descriptions
lines_df |> dplyr::filter(grepl("Nonfinancial", LineDescription, ignore.case=TRUE))
lines_df |> dplyr::filter(grepl("Structures", LineDescription, ignore.case=TRUE))

# Step 3: Confirm line number matches expected description
# If mismatch: update this document and log the revision date
```

---

# 11. Series Naming Convention

```
{type}_{account}_{subtype}_{modifier}

type:     KNC  (current-cost net stock)
          KNR  (real net stock / chain-type index)
          KGC  (current-cost gross stock — GPIM output)
          IG   (gross investment flow)
          DEP  (depreciation flow — derived)
          pK   (own-series price deflator)
          z    (depreciation rate)
          rho  (retirement rate)

account:  NF_struct   (NF corporate structures)
          NF_equip    (NF corporate equipment)
          gov_trans   (government transportation)
          NF_IPP      (NF corporate IPP)
          productive  (aggregate of first three)

modifier: _R     (real — deflated by own pK)
          _Py    (deflated by GDP deflator Py)
          _2017  (rebased to 2017=100)
```

**Examples:**
- `KGC_productive` — gross current-cost productive capital stock
- `KNR_NF_struct` — real net stock of NF corporate structures
- `pK_gov_trans` — own-series price deflator for government transportation
- `k_Py` — ln(KGC_productive / Py) — canonical estimation object
