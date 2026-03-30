# BEA Fixed Assets Tables: Consolidated Reference Bundle v2.0

## Contents

This bundle contains a **3-file reference system** for the Bureau of Economic Analysis (BEA) Fixed Assets tables:

### 1. **BEA_FixedAssets_MainNotebook_v2.md** (8.2 KB, 191 lines)
**The entry point.** Executive summary, account overviews, coverage notes, and quick-reference tables for all 7 accounts (Fixed Assets, Private by Type, Private by Industry, Nonresidential, Residential, Private aggregate, Government).

- Start here for orientation
- Contains coverage gaps flagged by account
- Directs to appendices for detailed analysis

### 2. **BEA_FixedAssets_AppendixA_LineDetail_v2.md** (9.1 KB, 298 lines)
**Full line-item and industry hierarchies.**
- All 103 lines for Table 2.1/2.7 (Equipment, Structures, IPP)
- All 96 NAICS industries for Section 3 tables
- Cross-referenced to line/industry numbers in actual CSVs

**Use this when:** You need to map specific line items or industries to the raw data tables.

### 3. **BEA_FixedAssets_AppendixB_CoverageMatrix_v2.md** (8.0 KB, 166 lines)
**Data availability by period (1901–2024).**
- Table-by-table coverage grid across 4 periods: 1901–1924, 1925–1946, 1947–2016, 2017–2024
- Gap analysis with research implications
- Recommendations for analysis by period
- Quality notes and sensitivity checks

**Use this when:** You're deciding which tables to use for your time period, or assessing whether historical data exists.

---

## Quick Navigation

### If you need...

**A quick fact about a specific table:**
→ Main Notebook → Accounts Overview

**Full line-by-line breakdown (all 103 equipment/structure/IPP lines):**
→ Appendix A → Table 2.1/2.7 section

**All 96 industries in order:**
→ Appendix A → Table 3.1E/3.1S/3.1I/3.1ESI section

**To know what data exists for 1935:**
→ Appendix B → Period 2 (1925–1946) table

**To know what data exists for industry detail before 1947:**
→ Appendix B → Key Data Gaps Summary

**To plan a 1947–2024 time-series analysis:**
→ Appendix B → Recommendations for 1947–2016 Research

---

## Key Coverage Alerts ⚠️

### Critical Data Gap: IPP by Industry
- **Available:** 2017–2024 ONLY
- **Missing:** 1947–2016 (70-year gap)
- **Workaround:** Use aggregate Table 2.1/2.7 for IPP trends; use Equipment/Structures (3.1E, 3.1S) for full 1947–2024 coverage

### No Industry Detail Before 1947
- **Section 3 tables (3.1E, 3.1S, 3.7E, 3.7S):** Start 1947
- **Workaround:** Use aggregate Tables 1.1–1.5, 4.1–4.7, etc. for pre-1947 (but at sector/legal-form level, not industry)

### No Net Stock Before 1925
- **Tables 1.1, 2.1, 4.1, 5.1, 6.1, 7.1:** Start 1925
- **Investment available back to 1901** (Table 1.5, 2.7, etc.)

---

## About This Data

**Source:** Bureau of Economic Analysis, U.S. Department of Commerce  
**Data Revision:** September 26, 2025  
**Tables Included:** 20 total (10 net stock, 10 investment/flow)  
**Time Coverage:** 1901–2024 (with gaps noted)  
**Accounts:** 7 (Sections 1–7)  
**Industries:** 96 NAICS (Section 3 only, 1947–2024)  

---

## How to Use This Bundle

1. **Start with Main Notebook** for orientation and quick answers
2. **Jump to Appendix A** when you need to look up a specific line number or industry code
3. **Jump to Appendix B** when planning analysis for a specific time period or assessing data availability

All three files are standalone but cross-referenced. You can read them linearly or jump to the section you need.

---

## Version History

- **v2.0 (March 26, 2026):** Complete consolidation with full line-item detail, 96-industry breakdown, and coverage matrix by period. All 20 tables documented.
- **v1.0 (March 16, 2026):** Initial account-level documentation.

---

**Last Updated:** March 26, 2026
