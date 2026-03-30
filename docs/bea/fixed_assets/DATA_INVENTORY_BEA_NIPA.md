# BEA NIPA Fixed Assets Data Inventory
## Critical-Replication-Shaikh Empirical Pipeline

**Date:** March 26, 2026  
**Bundle Version:** v2.2  
**Data Revision:** September 26, 2025

---

## Overview

This inventory documents the **BEA Fixed Assets tables** used in the Critical-Replication-Shaikh empirical pipeline, their coverage, sourcing, and relevance to the ARDL cointegration analysis (Shaikh 1947–2011 replication and extension to 1947–2024).

---

## Core Data Objects

### Private Sector Capital Stock (VAcorp + KGCcorp)

**Configuration:** `y_nom = "VAcorp"` (critical patch; replaces earlier GVAcorp)

| Object | Source Table | Coverage | Sourcing |
|--------|--------------|----------|----------|
| **VAcorp** | Table 2.1 (Net Stock of Private Fixed Assets by Type) | 1925–2024 | BEA Table 2.1, Line 1 (Private fixed assets aggregate) |
| **KGCcorp** | BEA Fixed Assets Companion Tables, Section 1 | 1925–2024 | Gross Capital Stock (current-cost, nonresidential + residential) |
| **NVAcorp** | NIPA Table 1.12 (Net Value Added by Industry) | 1947–2024 | National Income and Product Accounts |

**Why NVA, not GVA?**  
GPIM stock-flow consistency rules entail cointegration of **Net VA** (not GVA) with Gross Capital Stock under common deflator. See §1.4.2 and Appendix: GPIM Formalization.

**Canonical Values (1947):**
- KGCcorp_1947 = 170.58 Bn (not 141.9 Bn—that was 1925)
- Vintage gap = 2.05× (not 2.47×)

---

## Section 3 Tables: Industry-Level Detail

**All Section 3 tables (Equipment, Structures, IPP) cover 1947–2024 with full detail.**

### Tables in Pipeline

| Table | Type | Coverage | NAICS | Use in Pipeline |
|-------|------|----------|-------|-----------------|
| 3.1E | Net Stock, Equipment | 1947–2024 | 96 industries | S0–S3 θ estimation by industry |
| 3.1S | Net Stock, Structures | 1947–2024 | 96 industries | S0–S3 θ estimation by industry |
| 3.1I | Net Stock, IPP | 1947–2024 | 96 industries | Cointegration testing (post-2017 detail) |
| 3.1ESI | Net Stock, Aggregate | 1947–2024 | 96 industries | Robustness checks (E+S+IPP sum) |
| 3.7E | Investment, Equipment | 1947–2024 | 96 industries | S2 VECM validation |
| 3.7S | Investment, Structures | 1947–2024 | 96 industries | S2 VECM validation |
| 3.7I | Investment, IPP | 1947–2024 | 96 industries | S2 VECM validation (post-2017) |
| 3.7ESI | Investment, Aggregate | 1947–2024 | 96 industries | S2 robustness |

---

## Data File Mapping

### In `/data/` directory (as of 2026-03-26)

Assuming standard layout; update paths as needed:

```
data/
├── BEA_FixedAssets_Section1.csv        # Table 1.1 (aggregate net stock)
├── BEA_FixedAssets_Section2.csv        # Table 2.1 (net stock by type)
├── BEA_FixedAssets_Section3_Equipment.csv  # Table 3.1E (equipment by industry)
├── BEA_FixedAssets_Section3_Structures.csv # Table 3.1S (structures by industry)
├── BEA_FixedAssets_Section3_IPP.csv       # Table 3.1I (IPP by industry) — 1947–2024 FULL
├── BEA_FixedAssets_Section3_Aggregate.csv # Table 3.1ESI (E+S+IPP aggregate)
├── BEA_FixedAssets_Section4.csv        # Table 4.1 (nonresidential by industry group)
├── BEA_FixedAssets_Section5.csv        # Table 5.1 (residential by owner/tenure)
├── BEA_FixedAssets_Section6.csv        # Table 6.1 (private by legal form)
├── BEA_FixedAssets_Section7.csv        # Table 7.1 (government)
└── NIPA_VAcorp.csv                     # Table 2.1, aggregated output series
```

**Note:** If files use different naming, update paths in R scripts accordingly.

---

## R Pipeline Integration

### Critical Configuration Points

**File: `26_S0_redesign_ardl_search.R` (and related scripts)**

```r
# CRITICAL: Verify y_nom configuration
y_nom = "VAcorp"  # Correct value (not "GVAcorp")

# Data loading example
load_bea_data <- function(section) {
  # Section 3 tables: 1947–2024 coverage
  # No gap in IPP; full 77-year span available
  # Sourcing: BEA Table 3.1E, 3.1S, 3.1I, 3.1ESI
  # (and 3.7E, 3.7S, 3.7I, 3.7ESI for investment)
}

# Deflator check
deflator = "Py"  # GDP deflator (verify if sector-specific needed)

# Step dummies: d1956, d1974, d1980 (confirmed in memory)
```

### Script Execution Notes

- **Script 26:** S0 redesign grid (40 specifications). Pending rerun with VAcorp correction.
- **Case 5 NA bug:** Pending Claude Code fix (structural dummies in ARDL::ardl() formula placement).
- **Output directory:** `output/CriticalReplication/S0_manualOverride/`

---

## GPIM Integration Points

### Data Consistency Rules (GPIM)

Where applicable to your empirical work:

1. **Real accumulation rule:** K^R = K / p_t^K (capital-goods deflator, not GDP deflator)
2. **Stock-flow identity:** NVA + Depreciation ≡ Gross Investment
3. **Cointegration pairing:** NVA (not GVA) + K^G (gross capital stock) under common deflator
4. **Survival vs. revaluation:** z* compresses physical survival + accounting price adjustment

### Why This Matters for S0–S3

- **S0–S2:** θ estimation under standard ARDL; GPIM provides bounds/consistency checks
- **S3 (S2 inherited):** Regime-specific testing at 1974 dummy; GPIM validates whether closures shift with periodization

---

## Coverage Summary for Your Window (1947–2024)

| Component | Coverage | Status | Notes |
|-----------|----------|--------|-------|
| VAcorp (output) | 1925–2024 | ✅ | Use 1947–2024 for S0–S3 |
| KGCcorp (capital stock) | 1925–2024 | ✅ | Use 1947–2024 for S0–S3 |
| NVA (net value added) | 1947–2024 | ✅ | Full span; GPIM-consistent |
| Equipment by industry | 1947–2024 | ✅ | 96 NAICS, 77-year span |
| Structures by industry | 1947–2024 | ✅ | 96 NAICS, 77-year span |
| IPP by industry | 1947–2024 | ✅ | 96 NAICS, 77-year span (NO gap) |
| Deflator (Py) | 1947–2024 | ✅ | GDP implicit price deflator |

**Key insight:** Full 1947–2024 coverage across all capital stock types and detail levels. No data gaps for ARDL cointegration analysis.

---

## Related Documentation

- **BEA FixedAssets Bundle v2.2:** See `/docs/BEA_FixedAssets_Bundle_v2.2/` for full reference
  - `BEA_FixedAssets_MainNotebook_v2.md` — Account-by-account overview
  - `BEA_FixedAssets_AppendixA_LineDetail_v2.md` — 103 lines (Table 2.1) + 96 industries (Section 3)
  - `BEA_FixedAssets_AppendixB_CoverageMatrix_v2.md` — Period-by-period coverage

- **Dissertation Chapter 1 References:**
  - §1.4.2 Data: Why NVA replaces GVA
  - Appendix: GPIM Formalization (four pairings, deflator tension)

- **Replication Report v3:** §8.5 (data sourcing, GPIM justification)

---

## Data Audit & Validation

### Checksum / Canonical Values

Use these values to verify data loading:

- **VAcorp_1947** = 265.7 Bn (check against BEA Table 2.1, Line 1)
- **KGCcorp_1947** = 170.58 Bn (confirm 1947 vintage, not 1925)
- **NVA/KGCcorp ratio (1950)** ≈ 0.685 (use as sanity check)

### Script Cross-Reference

If you need to audit data sourcing in the pipeline:
- Run `script 90` (data audit cross-reference)
- Cross-check against Real Economic Analysis companion website (realeconomicanalysis.com)
- Verify BEA revision date: September 26, 2025

---

## Questions & Troubleshooting

**Q: Where did the earlier "2017–2024 IPP gap" come from?**  
A: Partial CSV extracts (Table__25__.csv, Table__28__.csv) only contained 2017–2024. Full CSVs (TableIPP.csv, Table__32__.csv) show 1947–2024. Update your data directory with complete files.

**Q: Should I use GVA or NVA for cointegration?**  
A: Use **NVA** (Net Value Added). GPIM stock-flow rules require NVA + K^G cointegration. GVA breaks under current BEA vintage (post-2023 comprehensive revision). See §1.4.2 and Appendix: GPIM Formalization.

**Q: Is the 1947 vintage gap (2.05×) correct?**  
A: Yes. KGCcorp_1947 = 170.58 Bn (confirmed). Earlier value (141.9 Bn) was misread from 1925. Update any scripts using old value.

---

**Last Updated:** March 26, 2026  
**Relevant Commits:** 
- Critical replication pipeline: VAcorp config patch
- GPIM pipeline: ADJ3 implementation (z* coefficient)
- Literature search: Johansen/VECM/CU gap confirmed

