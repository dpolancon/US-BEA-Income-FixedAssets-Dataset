# Critical-Replication-Shaikh: BEA FixedAssets Data Update v2.2
## March 26, 2026

---

## What's Included in This Update

This package contains:

1. **DATA_INVENTORY_BEA_NIPA.md** — Comprehensive inventory of BEA tables used in the pipeline, with canonical data values, configuration notes, and GPIM integration points.

2. **docs/BEA_FixedAssets_Bundle_v2.2/** — Complete reference documentation:
   - README_BEA_FixedAssets_Bundle.md
   - BEA_FixedAssets_MainNotebook_v2.md
   - BEA_FixedAssets_AppendixA_LineDetail_v2.md
   - BEA_FixedAssets_AppendixB_CoverageMatrix_v2.md

---

## Critical Corrections in v2.2

### ✅ Section 3 IPP Coverage: 1947–2024 (NO GAP)

**Previous misunderstanding:** Earlier partial CSVs showed only 2017–2024 data for Table 3.1I/3.7I.

**Correction:** Full CSVs (TableIPP.csv, Table__32__.csv) confirm **complete 1947–2024 coverage** for all Section 3 tables:
- 3.1E (Equipment, Net Stock)
- 3.1S (Structures, Net Stock)
- 3.1I (IPP, Net Stock)
- 3.1ESI (Aggregate, Net Stock)
- 3.7E/3.7S/3.7I/3.7ESI (Investment tables)

**Impact:** Your 1947–2024 window has **full IPP by industry detail** available. No data gaps for S0–S3 cointegration analysis.

### ✅ VAcorp Configuration (Critical Patch)

Configuration: `y_nom = "VAcorp"` (replaces earlier GVAcorp)

**Canonical 1947 values:**
- KGCcorp_1947 = 170.58 Bn (not 141.9 Bn; 1925 was misread)
- Vintage gap = 2.05× (not 2.47×)

**Relevance:** GPIM stock-flow consistency rules entail cointegration of **NVA** (not GVA) with Gross Capital Stock. Current BEA vintage (post-2023 comprehensive revision) breaks GVA+K^G pairing; NVA+K^G pairing is SFC-valid.

---

## How to Integrate Into Your Repo

### Step 1: Copy Files

```bash
# From this update package:
cp DATA_INVENTORY_BEA_NIPA.md /path/to/Critical-Replication-Shaikh/
cp -r docs/BEA_FixedAssets_Bundle_v2.2/ /path/to/Critical-Replication-Shaikh/docs/
```

### Step 2: Update R Scripts

In `26_S0_redesign_ardl_search.R` and related scripts, verify:

```r
y_nom = "VAcorp"  # Confirm this is set (not "GVAcorp")

# Canonical check: 1947 values
# KGCcorp_1947 should equal 170.58 Bn
# NVA/KGCcorp_1950 should ≈ 0.685
```

### Step 3: Update Data Files

If using partial CSVs, replace with full versions:
- **Table 3.1I (Net Stock, IPP by Industry):** Use TableIPP.csv (1947–2024)
- **Table 3.7I (Investment, IPP by Industry):** Use Table__32__.csv (1947–2024)

These are drop-in replacements for earlier partial extracts (Table__25__.csv, Table__28__.csv).

### Step 4: Document in Repo README

Add this section to main `README.md`:

```markdown
## Data Reference

BEA Fixed Assets tables used in this pipeline:
- **Source:** Bureau of Economic Analysis, NIPA Fixed Assets Companion Tables
- **Revision:** September 26, 2025
- **Coverage:** 1947–2024 (full detail across Equipment, Structures, IPP by 96 NAICS industries)
- **Reference:** See `DATA_INVENTORY_BEA_NIPA.md` and `docs/BEA_FixedAssets_Bundle_v2.2/`

Key tables:
- Table 2.1: Net Stock of Private Fixed Assets by Type
- Tables 3.1E/3.1S/3.1I: Net Stock by Industry (Equipment/Structures/IPP)
- Tables 3.7E/3.7S/3.7I: Investment by Industry (Equipment/Structures/IPP)

Configuration: `y_nom = "VAcorp"`, Deflator = `Py` (GDP implicit price deflator)
```

---

## Key Findings & Implications

### For S0–S2 (Scalar θ Estimation)

All three asset types (Equipment, Structures, IPP) available 1947–2024 at industry level. No data gaps. Full window supports cointegration analysis under ARDL/VECM.

### For S3 (Regime-Specific Testing at 1974 Dummy)

- Complete data series spans both regimes (1947–1973 Fordist, 1974–2024 post-Fordist)
- IPP detail available post-2017; for 1974–2016 testing, use Equipment+Structures + aggregate IPP (Table 2.1)
- GPIM rules provide consistency framework for SFC validation

### For GPIM Integration

NVA+K^G cointegration is the empirically-correct pairing. GPIM formalization (Appendix: Four Pairings) justifies:
- Why NVA (not GVA) with K^G (gross, not net) captures real accumulation
- Why common deflator preserves ratio consistency but doesn't solve the stock's own law of motion
- How to bound θ(Λ) via SFC rules

---

## Data Sourcing & Provenance

All tables sourced from:
- **BEA Fixed Assets Companion Tables** (realeconomicanalysis.com)
- **NIPA Table 2.1** (Net Value Added by Industry)
- **Data audit cross-reference:** Script 90 in pipeline

**Verification checklist:**
- Confirm y_nom = "VAcorp" in config
- Check KGCcorp_1947 = 170.58 Bn (canonical)
- Verify NVA/K ratio ≈ 0.685 (1950 sanity check)
- Review GPIM consistency rules (Appendix)

---

## Questions?

**Q: The earlier 2017–2024 IPP gap—was that real?**  
A: No. Partial CSVs created the illusion. Full data shows 1947–2024. Update your `/data/` directory with complete files (TableIPP.csv, Table__32__.csv).

**Q: Should I re-run Script 26?**  
A: Yes, with the VAcorp correction. Script 26 (S0 redesign, 40 specifications) has been pending rerun since VAcorp config patch. Full manifest clean run achieved with VAcorp in place.

**Q: How does GPIM affect the empirical work?**  
A: GPIM provides SFC bounds/checks on θ estimation. All ARDL/VECM results should be hedged as "properties of the estimator at this site" unless corroborated by regime-specific testing (S3). See §1.4.2 for methodology note.

**Q: NVA vs. GVA—which should I use?**  
A: **NVA** (Net Value Added). GPIM stock-flow consistency rules entail NVA+K^G cointegration. GVA breaks under current BEA vintage. Detailed justification in Dissertation Chapter 1, §1.4.2 and Appendix: GPIM Formalization.

---

## File Structure (Updated Repo Layout)

```
Critical-Replication-Shaikh/
├── README.md (update to reference BEA data section)
├── DATA_INVENTORY_BEA_NIPA.md (NEW)
├── docs/
│   ├── BEA_FixedAssets_Bundle_v2.2/ (NEW)
│   │   ├── README_BEA_FixedAssets_Bundle.md
│   │   ├── BEA_FixedAssets_MainNotebook_v2.md
│   │   ├── BEA_FixedAssets_AppendixA_LineDetail_v2.md
│   │   └── BEA_FixedAssets_AppendixB_CoverageMatrix_v2.md
│   └── [existing documentation]
├── data/
│   ├── [BEA CSVs]
│   ├── TableIPP.csv (update/verify: 1947–2024 full)
│   ├── Table__32__.csv (update/verify: 1947–2024 full)
│   └── [other data files]
├── R/ or scripts/
│   ├── 26_S0_redesign_ardl_search.R (verify y_nom = "VAcorp")
│   └── [other scripts]
└── output/
    └── CriticalReplication/ [existing]
```

---

**Last Updated:** March 26, 2026  
**Bundle Version:** v2.2 (Corrected)  
**Data Revision Referenced:** September 26, 2025

