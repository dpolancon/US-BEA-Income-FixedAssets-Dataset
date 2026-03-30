# Data Source Documentation

## GDP & Capital Stock Dataset (1925-2024) with Shaikh GPIM

---

## 1. FRED Series

| Series ID | Description | Frequency | Start | Source |
|-----------|-------------|-----------|-------|--------|
| GDPA | Gross Domestic Product (nominal) | Annual | 1929 | BEA via FRED |
| GNPA | Gross National Product (nominal) | Annual | 1929 | BEA via FRED |
| A191RD3A086NBEA | GDP Implicit Price Deflator | Annual | 1929 | BEA via FRED |

**Access**: `fredr` R package. API key required (fred.stlouisfed.org).

**Pre-1929 GDP**: Not available from FRED. Historical estimates from Balke-Gordon
(1989) or Johnston-Williamson (measuringworth.com) can be spliced if needed.

---

## 2. BEA Fixed Assets Tables

### Private Fixed Assets (Tables 4.x)

| Table | Content | Valuation | Used For |
|-------|---------|-----------|----------|
| 4.1 | Current-Cost Net Stock of Private Fixed Assets by Type | Current cost | K^{net,cc}, primary stock measure |
| 4.2 | Chain-Type Quantity Indexes for Net Stock of Private FA | Chain-type QI | K^{net,chain}, comparison/SFC test |
| 4.3 | Historical-Cost Net Stock of Private Fixed Assets | Historical cost | K^{net,hist}, quality critique (§7) |
| 4.4 | Current-Cost Depreciation of Private Fixed Assets by Type | Current cost | D^{cc}, depreciation flows |
| 4.7 | Investment in Private Fixed Assets by Type | Current cost | IG^{cc}, gross investment flows |

### Private Fixed Assets by Industry Group and Legal Form (Tables 6.x)

| Table | Content | Valuation | Used For |
|-------|---------|-----------|----------|
| 6.1 | Current-Cost Net Stock by Industry Group & Legal Form | Current cost | Corporate K extraction |
| 6.2 | Chain-Type QI for Net Stock by Industry Group & Legal Form | Chain-type QI | Corporate comparison series |
| 6.3 | Current-Cost Depreciation by Industry Group & Legal Form | Current cost | Corporate depreciation |
| 6.4 | Investment by Industry Group & Legal Form | Current cost | Corporate investment |

### Government Fixed Assets (Tables 7.x)

| Table | Content | Valuation | Used For |
|-------|---------|-----------|----------|
| 7.1 | Current-Cost Net Stock of Government Fixed Assets | Current cost | Government K by defense/nondefense |
| 7.2 | Chain-Type Quantity Indexes for Net Stock of Govt FA | Chain-type QI | Government comparison series |
| 7.3 | Current-Cost Depreciation of Government Fixed Assets | Current cost | Government depreciation |
| 7.4 | Investment in Government Fixed Assets | Current cost | Government investment |

**Coverage**: 1925-2024 (most series). Some detail lines start later.

**Access**: `bea.R` R package (API) or manual CSV download from
https://www.bea.gov/itable/fixed-assets

**BEA API key**: Required for programmatic access. Register at
https://www.bea.gov/resources/for-developers

**Methodology**: BEA (2003). "Fixed Assets and Consumer Durable Goods in the
United States, 1925-97." Available at:
https://www.bea.gov/sites/default/files/methodologies/Fixed-Assets-1925-97.pdf

---

## 3. Asset Type Mapping

BEA Fixed Assets tables organize assets by line number. The mapping from
BEA line numbers to our asset taxonomy (see docs/notation.md) is:

### Table 4.1 (Private Fixed Assets)

| Our Code | BEA Line Description | Approx Line |
|----------|---------------------|-------------|
| TOTAL | Private fixed assets | 1 |
| NRC | Nonresidential: Structures | 3 |
| ME | Nonresidential: Equipment | 6 |
| IP | Nonresidential: Intellectual property products | 9 |
| RC | Residential | 13 |

### Table 6.1 (Private FA by Industry Group & Legal Form)

| Our Code | BEA Line Description | Approx Line |
|----------|---------------------|-------------|
| Corporate | Corporate business | TBD |
| Sole_Prop | Sole proprietorships | TBD |
| Partnership | Partnerships and associations | TBD |

**Note**: Corporate line numbers in Section 6 tables must be validated
at runtime via `validate_line_map()`.

### Table 7.1 (Government Fixed Assets)

| Our Code | BEA Line Description | Approx Line |
|----------|---------------------|-------------|
| Defense_Total | National defense | 2 |
| Defense_NRC | National defense: Structures | 3 |
| Defense_ME | National defense: Equipment | 4 |
| Defense_IP | National defense: IP products | 5 |
| Nondefense_Total | Nondefense | 6 |
| Nondefense_NRC | Nondefense: Structures | 7 |
| Nondefense_ME | Nondefense: Equipment | 8 |
| Nondefense_IP | Nondefense: IP products | 9 |

**Note**: Line numbers are approximate and MUST be validated against actual
BEA table structure at runtime. The `validate_line_map()` function in
`97_kstock_helpers.R` performs this check.

---

## 4. Shaikh Reference Data

### Canonical Series (existing)

| File | Content | Period | Variables |
|------|---------|--------|-----------|
| `Shaikh_canonical_series_v1.csv` | Corporate sector data | 1947-2011 | VAcorp, KGCcorp, KNCcorpbea, pIGcorpbea, uK, etc. |
| `Shaikh_exploitation_rate_faithful_v1.csv` | Exploitation rate audit | 1947-2011 | exploit_rate construction |

### IRS Book Value Data (optional, for §6.3 adjustment)

| File | Content | Period | Source |
|------|---------|--------|--------|
| `irs_book_value.csv` | IRS corporate balance sheet | 1925-1947 | Census 1975, Series V 115, pp. 924-926 |

This file must be manually prepared and placed in `data/raw/bea/`.

---

## 5. Methodological References

1. **Shaikh, A.** (2016). *Capitalism: Competition, Conflict, Crises*.
   Oxford University Press. Appendices 6.5, 6.6, 6.7.

2. **Shaikh, A.** Archive. Bard College Digital Commons.
   https://digitalcommons.bard.edu/as_archive/
   - "Notes on the Method of Estimation of Fixed Capital"
   - "Aggregate Capital Stock Measures"
   - "Stocks-Flows"

3. **BEA** (2003). "Fixed Assets and Consumer Durable Goods in the United
   States, 1925-97." Bureau of Economic Analysis.

4. **Whelan, K.** (2002). "A Guide to U.S. Chain Aggregated NIPA Data."
   *Review of Income and Wealth*, 48(2), 217-233.

5. **Gordon, R.J.** (1993). *The Measurement of Durable Goods Prices*.
   NBER/University of Chicago Press.

6. **Balke, N.S. and Gordon, R.J.** (1989). "The Estimation of Prewar
   Gross National Product: Methodology and New Evidence."
   *Journal of Political Economy*, 97(1), 38-92.

---

## 6. R Package Dependencies

| Package | Purpose | Source |
|---------|---------|--------|
| `bea.R` | BEA API access | CRAN or github.com/us-bea/bea.R |
| `fredr` | FRED API access | CRAN |
| `sandwich` | Newey-West HAC SE (T1-T2) | CRAN |
| `lmtest` | Coefficient testing with custom vcov | CRAN |
| `urca` | Zivot-Andrews test (T3) | CRAN |
| `dplyr` | Data manipulation | CRAN |
| `tidyr` | Data reshaping | CRAN |
| `readr` | CSV I/O | CRAN |
| `ggplot2` | Visualization | CRAN |

---

## 7. Capital-Output Ratio References

1. **Shaikh, A.** (2016). Chapter 6, "The Classical Theory of Accumulation":
   Y/K as the inverse of the organic composition; secular tendency in
   competitive capitalism. See especially §6.1-6.3 and Appendix 6.7 §V.

2. **Shaikh, A.** (2016). Appendix 6.7 §V: Quality adjustment and the
   stock-flow distortion. Testable implications T1-T3 for hedonic deflators.

3. **Gordon, R.J.** (1990). *The Measurement of Durable Goods Prices*.
   University of Chicago Press. Foundational critique of hedonic quality
   adjustments in equipment price indices.

4. **Basu, D. and Manolakos, P.T.** (2013). "Is There a Tendency for the Rate
   of Profit to Fall? Econometric Evidence for the U.S. Economy, 1948-2007."
   *Review of Radical Political Economics*, 45(1), 76-95.

5. **Duménil, G. and Lévy, D.** (2004). *Capital Resurgent: Roots of the
   Neoliberal Revolution*. Harvard University Press. Alternative Y/K series
   and periodization (Fordism/post-Fordism).

---

*Sources v2 | 2026-03-14*
