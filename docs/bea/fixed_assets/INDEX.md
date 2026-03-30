# Critical-Replication-Shaikh: BEA FixedAssets Update v2.2
## Complete Update Package

**Release Date:** March 26, 2026  
**Package Size:** 62 KB | 7 Markdown files  
**Status:** Ready for integration

---

## Quick Start

1. **Read first:** `README_REPO_UPDATE.md` (overview + key corrections)
2. **Integrate using:** `INTEGRATION_CHECKLIST.md` (step-by-step guide)
3. **Reference:** `DATA_INVENTORY_BEA_NIPA.md` (data sourcing + canonical values)
4. **Deep dive:** `docs/BEA_FixedAssets_Bundle_v2.2/` (4 reference files)

---

## Package Contents

### Root Level (3 files)

| File | Purpose | Key Content |
|------|---------|-------------|
| **README_REPO_UPDATE.md** | Integration overview | Critical corrections (IPP 1947–2024, VAcorp config, canonical values) |
| **DATA_INVENTORY_BEA_NIPA.md** | Data sourcing & configuration | Table mapping, GPIM integration, canonical checks, troubleshooting |
| **INTEGRATION_CHECKLIST.md** | Step-by-step integration guide | File placement, code updates, data validation, sign-off |

### docs/BEA_FixedAssets_Bundle_v2.2/ (4 reference files)

| File | Purpose | Audience |
|------|---------|----------|
| **README_BEA_FixedAssets_Bundle.md** | Navigation guide for bundle | Anyone using the bundle |
| **BEA_FixedAssets_MainNotebook_v2.md** | Account-by-account overview (7 sections) | Quick reference for table coverage |
| **BEA_FixedAssets_AppendixA_LineDetail_v2.md** | Full hierarchies: 103 lines + 96 industries | Line-item mapping for data work |
| **BEA_FixedAssets_AppendixB_CoverageMatrix_v2.md** | Period-by-period coverage (1901–2024) | Research planning by time window |

---

## Critical Corrections in v2.2

### ✅ Section 3 IPP Coverage: 1947–2024 (Complete)

**What changed:**
- Earlier partial CSVs (Table__25__.csv, Table__28__.csv) showed only 2017–2024
- Full CSVs (TableIPP.csv, Table__32__.csv) confirm **complete 1947–2024 coverage**
- All Section 3 tables now documented with full span: 1947–2024

**Impact:** Your dissertation window (1947–2024) has **zero data gaps** for IPP by industry.

### ✅ VAcorp Configuration

**What changed:**
- Configuration verified: `y_nom = "VAcorp"` (not GVAcorp)
- Canonical 1947 value: KGCcorp = 170.58 Bn (not 141.9 Bn—that was 1925)
- Vintage gap = 2.05× (not 2.47×)

**Impact:** GPIM-consistent NVA+K^G pairing (not GVA+K^G) now grounded in empirics.

### ✅ No Data Gaps for S0–S3

**What changed:**
- Previously hedged language about IPP availability removed
- Now: Definitive statement of 1947–2024 coverage across all asset types and detail levels

**Impact:** Full design window available for ARDL cointegration (S0–S2) and regime-specific testing (S3 at 1974).

---

## For Your Dissertation Chapter 1

### Relevant Sections

- **§1.4.2 (Data):** References canonical values (KGCcorp_1947, NVA/K ratio) now verified
- **Appendix: GPIM Formalization:** Explains why NVA (not GVA) with K^G pairing
- **Appendix: Four Pairings:** Documents all pairing options and their SFC validity

### Integration Points

- VAcorp output series: 1947–2024 (fully documented)
- NVA (net value added): 1947–2024 (GPIM-consistent)
- Capital stocks by type: Equipment/Structures/IPP all 1947–2024
- Deflator: Py (GDP implicit price deflator)

---

## For Your Empirical Pipeline (Critical-Replication-Shaikh)

### Configuration to Verify

```r
# In your scripts (e.g., 26_S0_redesign_ardl_search.R)
y_nom = "VAcorp"       # Confirmed correct
deflator = "Py"        # GDP implicit price deflator
d1956 = 1 # d1974 = 1 # d1980 = 1  # Step dummies
exact = TRUE           # Bounds testing (condition on T=65 or 78)
```

### Data Files to Update

In `/data/`:
- TableIPP.csv (Table 3.1I, 1947–2024) — replaces Table__25__.csv
- Table__32__.csv (Table 3.7I, 1947–2024) — replaces Table__28__.csv
- All other BEA CSVs (verify full coverage, not partial)

### Next Steps

1. Run Script 26 (S0 redesign, 40 specs) with VAcorp configuration
2. Validate S0–S2 results (rank-1 expected)
3. Prepare S3 testing at 1974 dummy (VECM framework)
4. Cross-stage θ comparison table
5. GPIM validation (if applicable)

---

## How to Use This Package

### For Integration (1-2 hours)

1. Read `README_REPO_UPDATE.md` (~5 min)
2. Follow `INTEGRATION_CHECKLIST.md` step-by-step (~1.5 hours)
3. Verify data with canonical values (`DATA_INVENTORY_BEA_NIPA.md`)
4. Run Script 26 and validate output

### For Reference

- **Quick facts about a table?** → `BEA_FixedAssets_MainNotebook_v2.md`
- **Line-item or industry codes?** → `BEA_FixedAssets_AppendixA_LineDetail_v2.md`
- **Coverage by time period?** → `BEA_FixedAssets_AppendixB_CoverageMatrix_v2.md`
- **Data sourcing & canonical values?** → `DATA_INVENTORY_BEA_NIPA.md`

---

## Support

### Questions Answered in This Package

**Q: Was the 2017–2024 IPP gap real?**  
A: No. Partial CSV extracts created the illusion. Full data shows 1947–2024. See `README_REPO_UPDATE.md`.

**Q: Which capital stock series should I use?**  
A: NVA + K^G (gross capital stock, common deflator). GPIM rules entail this pairing. See `DATA_INVENTORY_BEA_NIPA.md`.

**Q: What are the canonical check values?**  
A: KGCcorp_1947 = 170.58 Bn; NVA/K ≈ 0.685 (1950). See `INTEGRATION_CHECKLIST.md` for validation script.

**Q: Do I need to re-run my scripts?**  
A: Yes, Script 26 (S0 redesign) should be re-run with VAcorp correction and full data. See `INTEGRATION_CHECKLIST.md`.

---

## File Manifest

```
CriticalReplication_BEA_Update_v2.2/
├── INDEX.md (this file)
├── README_REPO_UPDATE.md (start here)
├── DATA_INVENTORY_BEA_NIPA.md (data sourcing)
├── INTEGRATION_CHECKLIST.md (step-by-step guide)
└── docs/
    └── BEA_FixedAssets_Bundle_v2.2/
        ├── README_BEA_FixedAssets_Bundle.md
        ├── BEA_FixedAssets_MainNotebook_v2.md
        ├── BEA_FixedAssets_AppendixA_LineDetail_v2.md
        └── BEA_FixedAssets_AppendixB_CoverageMatrix_v2.md
```

---

**Last Updated:** March 26, 2026  
**Version:** v2.2 (Corrected)  
**Data Revision:** September 26, 2025

