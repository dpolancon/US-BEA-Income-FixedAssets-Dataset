# BEA Fixed Assets Table Structure — Claude Code Reference

**Purpose:** Authoritative reference for Claude Code when writing BEA API fetch code.
Read this before writing any `fetch_fa_table()` call or any `LineDescription` pattern.

**Data revision:** September 26, 2025
**API base:** `https://apps.bea.gov/api/data` | `DataSetName = "FixedAssets"`

> ⚠️ **Critical rule:** Always verify `LineDescription` strings from a live API response
> before hardcoding patterns. BEA renumbers lines across comprehensive revisions.
> Match on description, not line number.

---

## What each Section provides

| Section | TableName (net stock) | TableName (investment) | Legal form? | Asset type (E/S/IPP)? | Coverage |
|---|---|---|---|---|---|
| 1. Fixed Assets aggregate | `FAAt101` | `FAAt105` | No | Yes (E/S/IPP) | 1925–2024 / 1901–2024 |
| 2. Private by Type | `FAAt201` | `FAAt207` | No | Yes — 103 sub-lines | 1925–2024 / 1901–2024 |
| 3. Private by Industry | `FAAt301E/S/I/ESI` | `FAAt307E/S/I/ESI` | No | Separate tables per type | 1947–2024 ⚠️ IPP only 2017+ |
| 4. Nonresidential by Industry Group + Legal Form | `FAAt401` | `FAAt407` | Corporate (NOT split Fin/NF) | Yes (E/S/IPP) | 1925–2024 / 1901–2024 |
| 5. Residential | `FAAt501` | `FAAt507` | Owner type only | No | 1925–2024 / 1901–2024 |
| **6. Private by Legal Form** | **`FAAt601`** | **`FAAt607`** | **Yes — Nonfinancial corporate distinct** | **No — aggregate only** | 1925–2024 / 1901–2024 |
| 7. Government | `FAAt701` | `FAAt705` | No | Structures by type | 1925–2024 / 1901–2024 |

### The fundamental constraint

**No single BEA table provides Nonfinancial corporate × asset type (E/S/IPP) simultaneously.**

- Section 6 gives **Nonfinancial corporate** but only as an **aggregate** (no E/S/IPP split)
- Section 4 gives **E/S/IPP** per legal form but **corporate = Financial + Nonfinancial lumped**

**For Dataset 2:** Use Section 6 (FAAt601/602/607) for the NF corporate aggregate account.

---

## Section 6 — FAAt601 / FAAt607 (NF corporate accounts)

### Confirmed line structure (live API, Sep 2025 vintage)

```
L1:  Private fixed assets
L2:  Corporate
L3:  Financial
L4:  Nonfinancial          ← use this for NF corporate aggregate
L5:  Noncorporate
L6:  Sole proprietorships
L7:  Partnerships
L8:  Nonprofit institutions
L9:  Households
L10: Tax-exempt cooperatives
L11: Farms
L12: Manufacturing
L13: Nonfarm nonmanufacturing (nonresidential fixed assets only)
```

**No E/S/IPP sub-lines exist under L4 Nonfinancial.** L5 immediately follows L4.

### Extraction pattern (correct)

```r
# CORRECT: flat match on 'Nonfinancial'
KNC_NF <- lines_df |> filter(grepl("Nonfinancial", LineDescription, ignore.case = TRUE))

# WRONG: AND-pattern — will always return empty
KNC_NF_struct <- lines_df |>
  filter(grepl("Nonfinancial", LineDescription) & grepl("Structures", LineDescription))
```

---

## Section 4 — FAAt401 / FAAt407 (NOT used for NF corporate)

Section 4 splits corporate by **industry group** (Farms, Manufacturing, Nonfarm nonmanufacturing),
not by Financial/Nonfinancial. Switching to it would contaminate NF corporate accounts
with financial-sector capital stock. Do not use for this project.

---

## Section 7 — FAAt701 / FAAt705 (government transport)

### Table 7.1 structure

```
Equipment
Structures
  Residential
  Industrial / Office / Commercial / Health care / Educational / Public safety
  Amusement and recreation
  Transportation
    Highways and streets     ← L14 (verify from live response)
    Air transportation
    Land transportation
    Water transportation     ← INCLUDE (Marx Vol. II Ch. 6)
  Power
  Military facilities
```

All four transport sub-types are productive capital (Marx Vol. II Ch. 6: transport adds
locational use-value before the P→C handoff). Include highways + air + land + water.

BEA may report Federal and State/Local separately — sum both levels.

```r
transport_patterns <- c("Highways and streets", "Air transportation",
                         "Land transportation", "Water transportation")

KNC_gov_transport <- lines_df |>
  filter(grepl(paste(transport_patterns, collapse="|"), LineDescription, ignore.case=TRUE)) |>
  group_by(year) |>
  summarise(value = sum(value))
```

---

## NIPA — T11400 (income accounts)

`DataSetName = "NIPA"`, `TableName = "T11400"`

NF corporate block — Lines 17–40 (Sep 2025 vintage, verify from live response):

| Line | Series | Notes |
|---|---|---|
| 17 | GVA_NF | Gross value added of nonfinancial corporate business |
| 18 | CCA_NF | Consumption of fixed capital |
| 19 | NVA_NF | Net value added — **canonical Y_t** |
| 20 | EC_NF | Compensation of employees |
| 23 | TPI_NF | Taxes on production and imports less subsidies |
| 24 | NOS_NF | Net operating surplus |
| 27 | Profits_IVA_CC_NF | Corporate profits with IVA and CCAdj |
| 35 | IVA_NF | Inventory valuation adjustment |
| 36 | CCAdj_NF | Capital consumption adjustment |

Always match on LineDescription, not line number.

---

## FRED — GDP Deflator (Py)

Series: `A191RD3A086NBEA` | Base year: 2017=100 | Coverage: 1929–2024

---

## Debugging checklist

1. Print all LineDescriptions from the live API response first
2. Check which section the table is from (Section 6 = legal form only)
3. Never use AND-patterns across legal form + asset type — that intersection doesn't exist
4. For hierarchical tables — parent and child have DIFFERENT LineDescription strings
5. For government transport — sum Federal and State/Local levels

---

## Resolved bugs in 60_agents_prod_cap.R

| Bug | Root cause | Fix |
|---|---|---|
| `No line matches: Nonfinancial AND Structures` | AND-pattern on FAAt601 (no E/S/IPP sub-lines) | FAAt601 L4 aggregate only |
| `Parent block (L5–L4) is empty` | extract_child_of_parent() wrong search direction | Replaced with flat extract on L4 |
| `SFC HALT residual=1.16e-10` | Internal tolerance too tight (machine epsilon) | Loosened to 1e-6 |

---

**Last updated:** 2026-03-27 | Source: Live BEA API + docs/bea/bea_tables_notebook.md
