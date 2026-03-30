# BEA Fixed Assets Tables: Consolidated Reference Notebook v2.1

**Last Updated:** March 26, 2026  
**Data Source:** Bureau of Economic Analysis (BEA) Fixed Assets Companion Tables  
**Data Revision:** September 26, 2025

---

## Executive Summary

This notebook documents the **20 tables** comprising the BEA's comprehensive fixed assets and capital stock accounting system across 7 accounts (Sections 1–7). Coverage spans **1901–2024**, with significant data gaps highlighted for each section.

### Quick Facts
- **Total Tables:** 20 (10 net stock, 10 investment/flow)
- **Temporal Coverage:** 1901–2024 (with gaps)
- **Accounts:** 7 (Fixed Assets, Private by Type, Private by Industry, Nonresidential, Residential, Private [aggregate], Government)
- **Industry Breakdown:** 96 NAICS industries (Section 3 only, 1947–2024)

---

## Accounts Overview & Coverage

### Account 1: Fixed Assets and Consumer Durable Goods

**Coverage Note:** Net stock available 1925–2024; investment available 1901–2024.

| Table | Type | Coverage | Denomination | Last Revised |
|-------|------|----------|--------------|--------------|
| 1.1 | Net Stock | 1925–2024 | Billions $; year-end | Sep 26, 2025 |
| 1.5 | Investment | 1901–2024 | Billions $; annual flow | Sep 26, 2025 |

**Structure:** Aggregate of all fixed assets (Private nonresidential, Private residential, Government nonresidential, Government residential) + Consumer durable goods.

---

### Account 2: Private Fixed Assets by Type (Equipment, Structures, IPP)

**Coverage Note:** Net stock 1925–2024; Investment 1901–2024.

| Table | Type | Coverage | Lines | Last Revised |
|-------|------|----------|-------|--------------|
| 2.1 | Net Stock | 1925–2024 | 103 | Sep 26, 2025 |
| 2.7 | Investment | 1901–2024 | 103 | Sep 26, 2025 |

**Structure:** Equipment (nonresidential detail + residential), Structures (nonresidential + residential with sub-categories), Intellectual Property Products (Software, R&D, Entertainment/literary originals).

**Detail:** See Appendix A for full 103-line hierarchy.

---

### Account 3: Private Fixed Assets by Industry (Equipment, Structures, IPP)

**Coverage Note:** All Section 3 tables available 1947–2024.

| Table | Type | Coverage | Industries | Last Revised |
|-------|------|----------|------------|--------------|
| 3.1E | Net Stock | 1947–2024 | 96 NAICS | Sep 26, 2025 |
| 3.1S | Net Stock | 1947–2024 | 96 NAICS | Sep 26, 2025 |
| 3.1I | Net Stock | 1947–2024 | 96 NAICS | Sep 26, 2025 |
| 3.1ESI | Net Stock | 1947–2024 | 96 NAICS (E+S+IPP agg) | Sep 26, 2025 |
| 3.7E | Investment | 1947–2024 | 96 NAICS | Sep 26, 2025 |
| 3.7S | Investment | 1947–2024 | 96 NAICS | Sep 26, 2025 |
| 3.7I | Investment | 1947–2024 | 96 NAICS | Sep 26, 2025 |
| 3.7ESI | Investment | 1947–2024 | 96 NAICS (E+S+IPP agg) | Sep 26, 2025 |

**Structure:** 96 industries classified by NAICS (Agriculture, Mining, Utilities, Construction, Manufacturing [durable/nondurable], Wholesale/Retail Trade, Transportation, Information, Finance/Insurance/Real Estate, Professional Services, Admin/Waste, Education, Health/Social Assistance, Arts/Entertainment, Accommodation/Food, Other Services).

**Detail:** See Appendix A for full 96-industry breakdown.

---

### Account 4: Nonresidential Fixed Assets by Industry Group and Legal Form

**Coverage Note:** Net stock 1925–2024; Investment 1901–2024.

| Table | Type | Coverage | Last Revised |
|-------|------|----------|--------------|
| 4.1 | Net Stock | 1925–2024 | Sep 26, 2025 |
| 4.7 | Investment | 1901–2024 | Sep 26, 2025 |

**Structure:** By asset type (Equipment, Structures, IPP) × by industry group (Farms, Manufacturing, Nonfarm nonmanufacturing) × by legal form (Corporate [with corporate sub-industry detail], Noncorporate).

---

### Account 5: Residential Fixed Assets by Type of Owner, Legal Form, and Tenure

**Coverage Note:** Net stock 1925–2024; Investment 1901–2024.

| Table | Type | Coverage | Last Revised |
|-------|------|----------|--------------|
| 5.1 | Net Stock | 1925–2024 | Sep 26, 2025 |
| 5.7 | Investment | 1901–2024 | Sep 26, 2025 |

**Structure:** By owner type (Private [Corporate, Noncorporate subdivided into Sole proprietorships, Partnerships, Nonprofit institutions, Households]; Government [Federal, State and local]) × by tenure group (Owner-occupied, Tenant-occupied).

---

### Account 6: Private Fixed Assets by Industry Group and Legal Form (Aggregate)

**Coverage Note:** Net stock 1925–2024; Investment 1901–2024.

| Table | Type | Coverage | Last Revised |
|-------|------|----------|--------------|
| 6.1 | Net Stock | 1925–2024 | Sep 26, 2025 |
| 6.7 | Investment | 1901–2024 | Sep 26, 2025 |

**Structure:** By legal form (Corporate [Financial, Nonfinancial], Noncorporate [Sole proprietorships, Partnerships, Nonprofit institutions, Households]).

---

### Account 7: Government Fixed Assets

**Coverage Note:** Net stock 1925–2024; Investment 1901–2024.

| Table | Type | Coverage | Last Revised |
|-------|------|----------|--------------|
| 7.1 | Net Stock | 1925–2024 | Sep 26, 2025 |
| 7.5 | Investment | 1901–2024 | Sep 26, 2025 |

**Structure:** By asset type (Equipment, Structures) × by structure type (Residential, Industrial, Office, Commercial, Health care, Educational, Public safety, Amusement/recreation, Transportation, Power, Highways/streets, Military facilities).

---

## Data Availability & Coverage Gaps

### Coverage Summary by Period

**1901–1946:**
- ✅ Aggregate investment (Tables 1.5, 4.7, 5.7, 6.7, 7.5)
- ❌ Net stock (begins 1925)
- ❌ Industry detail (begins 1947)

**1947–2024:**
- ✅ Net stock (Tables 1.1, 2.1, 4.1, 5.1, 6.1, 7.1)
- ✅ Aggregate investment (Tables 1.5, 4.7, 5.7, 6.7, 7.5)
- ✅ Industry detail: Equipment & Structures (Tables 3.1E, 3.1S, 3.7E, 3.7S, 3.1ESI, 3.7ESI)
- ⚠️ Industry detail: IPP (Tables 3.1I, 3.7I) — check BEA documentation for coverage span

### Full Coverage Matrix

See **Appendix B: Coverage Matrix** for detailed table-by-table breakdown across all periods and accounts.

---

## Key Definitions

**Net Stock:** Current-cost value of fixed assets at year-end, adjusted for depreciation and price changes.

**Investment (Gross Capital Formation):** Annual additions to capital stock (gross domestic investment in fixed assets).

**Equipment:** Machinery, vehicles, IT equipment, and other movable capital goods.

**Structures:** Buildings, infrastructure, and other immovable installations.

**Intellectual Property Products (IPP):** Software (prepackaged, custom, own-account), R&D (business, nonprofit), and entertainment/literary originals.

**NAICS:** North American Industry Classification System (96 industries across all private sectors).

---

## How to Use This Notebook

1. **For quick facts:** Start with Executive Summary and Accounts Overview.
2. **For detailed account structure:** See specific account section above.
3. **For full line-item/industry breakdown:** See **Appendix A: Full Line-Item Reference**.
4. **For data availability decisions:** See **Appendix B: Coverage Matrix** and the Coverage Gaps section above.
5. **For historical analysis before 1947:** Use aggregate Tables 1.5, 4.7, 5.7, 6.7, 7.5.
6. **For industry detail by type:** Use Equipment/Structures tables (3.1E, 3.1S, 3.7E, 3.7S); verify IPP coverage with BEA.

---

## Appendices

- **Appendix A:** Full Line-Item Reference (BEA_FixedAssets_AppendixA_LineDetail_v2.md)
- **Appendix B:** Coverage Matrix & Data Availability Guide (BEA_FixedAssets_AppendixB_CoverageMatrix_v2.md)

---

**Contact/Source:** Bureau of Economic Analysis, U.S. Department of Commerce  
**Data Download:** Real Economic Analysis companion website (realeconomicanalysis.com)
