# Appendix B: Coverage Matrix & Data Availability Guide

## Full Coverage by Table (1901–2024)

### Period 1: 1901–1946
**Only Investment Data Available (Aggregate Level)**

| Table | Type | Years | Coverage |
|-------|------|-------|----------|
| 1.5 | Investment | 1901–1946 | ✅ Fixed Assets (agg) |
| 2.7 | Investment | 1901–1946 | ✅ By Type (Equipment, Structures, IPP) |
| 4.7 | Investment | 1901–1946 | ✅ Nonresidential by Industry Group & Legal Form |
| 5.7 | Investment | 1901–1946 | ✅ Residential by Owner & Tenure |
| 6.7 | Investment | 1901–1946 | ✅ Private by Legal Form |
| 7.5 | Investment | 1901–1946 | ✅ Government |
| 3.7E, 3.7S, 3.7I, 3.7ESI | Investment | 1901–1946 | ❌ No industry detail |

**Analysis Implication:** Pre-1947 researchers can access aggregate investment flows but cannot decompose by industry, and have no capital stock estimates.

---

### Period 2: 1925–1946
**Net Stock (Aggregate) + Investment (Aggregate & Some Detail)**

| Table | Type | Years | Coverage |
|-------|------|-------|----------|
| 1.1 | Net Stock | 1925–1946 | ✅ Fixed Assets (agg) |
| 1.5 | Investment | 1925–1946 | ✅ Fixed Assets (agg) |
| 2.1 | Net Stock | 1925–1946 | ✅ By Type (Equipment, Structures, IPP) |
| 2.7 | Investment | 1925–1946 | ✅ By Type |
| 4.1 | Net Stock | 1925–1946 | ✅ Nonresidential by Industry Group & Legal Form |
| 4.7 | Investment | 1925–1946 | ✅ Nonresidential by Industry Group & Legal Form |
| 5.1 | Net Stock | 1925–1946 | ✅ Residential by Owner & Tenure |
| 5.7 | Investment | 1925–1946 | ✅ Residential by Owner & Tenure |
| 6.1 | Net Stock | 1925–1946 | ✅ Private by Legal Form |
| 6.7 | Investment | 1925–1946 | ✅ Private by Legal Form |
| 7.1 | Net Stock | 1925–1946 | ✅ Government |
| 7.5 | Investment | 1925–1946 | ✅ Government |
| 3.1E, 3.1S, 3.1I, 3.1ESI | Net Stock | 1925–1946 | ❌ No industry detail |
| 3.7E, 3.7S, 3.7I, 3.7ESI | Investment | 1925–1946 | ❌ No industry detail |

**Analysis Implication:** Inter-war period has broader coverage than pre-1925, but still lacks detailed industry breakdown. Legal form and owner type detail available.

---

### Period 3: 1947–2024
**Comprehensive Coverage (All Tables, All Detail)**

| Table | Type | Years | Coverage |
|-------|------|-------|----------|
| 1.1, 2.1, 4.1, 5.1, 6.1, 7.1 | Net Stock | 1947–2024 | ✅ ALL |
| 1.5, 2.7, 4.7, 5.7, 6.7, 7.5 | Investment | 1947–2024 | ✅ ALL |
| 3.1E, 3.1S, 3.1I, 3.1ESI | Net Stock | 1947–2024 | ✅ 96 industries (full detail) |
| 3.7E, 3.7S, 3.7I, 3.7ESI | Investment | 1947–2024 | ✅ 96 industries (full detail) |

**Analysis Implication:** Complete coverage across all detail levels for 77-year span. Full access to Equipment, Structures, and IPP by industry.

---

## Key Data Gaps Summary

| Gap | Affected Tables | Years Missing | Impact |
|-----|-----------------|---------------|--------|
| **Industry detail unavailable** | 3.1E, 3.1S, 3.1I, 3.1ESI, 3.7E, 3.7S, 3.7I, 3.7ESI | 1901–1946 | Cannot decompose by 96 NAICS industries before 1947 |
| **Net stock unavailable** | 1.1, 2.1, 4.1, 5.1, 6.1, 7.1 | 1901–1924 | No capital stock estimates before 1925 |

---

## Recommendations for Analysis by Period

### For 1901–1924 Research
- ✅ Use Table 1.5 (aggregate investment)
- ✅ Use Tables 2.7, 4.7, 5.7, 6.7, 7.5 for sector detail (investment only, no net stock)
- ❌ Cannot do industry-level analysis
- ❌ Cannot estimate capital stocks

**Best Practice:** Restrict to aggregate trends; supplement with alternative historical sources (e.g., BEA Historical Tables, pre-1925 government capital reports).

### For 1925–1946 Research
- ✅ Use Table 1.1 (aggregate net stock)
- ✅ Use Table 2.1 (by Equipment/Structures/IPP)
- ✅ Use Tables 4.1, 5.1, 6.1, 7.1 (by industry group and legal form)
- ❌ Cannot do detailed industry-level analysis

**Best Practice:** Analyze by legal form and ownership type; use aggregate type breakdowns; avoid time-series that require post-1947 industry detail.

### For 1947–2024 Research
- ✅ Use all tables (1.1–7.5) with full detail
- ✅ Use Tables 3.1E, 3.1S, 3.1I, 3.7E, 3.7S, 3.7I for detailed equipment/structures/IPP by industry across full span
- ✅ Use Tables 3.1ESI, 3.7ESI for aggregate fixed assets by industry (1947–2024)
- ✅ Use all other tables (1.1, 2.1, 4.1, 5.1, 6.1, 7.1) for broader analysis

**Best Practice:** Complete data across all dimensions. Design time-series analysis with full 77-year window (1947–2024) for private fixed assets by industry.

---

## Data Quality Notes

### Sources & Revisions
All tables last revised **September 26, 2025**. Data reflect BEA's most recent comprehensive revision of fixed assets accounts.

### Measurement Method
- **Net Stock:** Current-cost net capital stock (depreciated; revalued annually)
- **Investment:** Gross domestic investment in fixed assets (annual flows)
- **Deflator:** Implicit price deflators from NIPA (except industry tables, which may use sector-specific deflators)

### Known Limitations
1. **Industry coverage:** NAICS classification; data revised when NAICS updates (latest revision 2022)
2. **Private nonresidential vs. residential:** Equipment/Structures detail; IPP by type available in Table 2.1 but not by industry-residential split
3. **Government structures by type:** Detailed breakdown available (educational, highways, military, etc.) but discontinuous pre-1947
4. **Deflator consistency:** Verify if sector-specific deflators differ from NIPA implicit price deflators for your analysis

### Recommended Sensitivity Checks
- When using 3.1ESI/3.7ESI across 1947–2024, verify IPP component consistency (use 2.1/2.7 aggregate IPP as parallel check)
- Test continuity at 1947 margin when bridging pre-1947 and post-1947 industry data
- For long-run comparisons (e.g., 1925–2024), ensure consistent deflator treatment (BEA uses CPI-based deflators; verify if sector-specific deflator preferred)

---

## Related Resources

- **BEA Fixed Assets Companion Tables:** https://www.bea.gov/resources/methodologies/nipa
- **NAICS Classification:** https://www.census.gov/naics/
- **NIPA Documentation:** https://www.bea.gov/resources/methodologies
- **Real Economic Analysis Data Portal:** realeconomicanalysis.com (data download location)

---

**Last Updated:** March 26, 2026  
**Data Revision Referenced:** September 26, 2025
