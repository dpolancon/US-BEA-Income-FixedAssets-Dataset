# GDP & Capital Stock Dataset Pipeline

## Overview

The 40-series pipeline constructs a unified GDP and capital stock dataset for the
United States (1925–2024), implementing Shaikh's Generalized Perpetual Inventory
Method (GPIM) for deflation and stock-flow-consistent capital measurement.

**Primary output**: `data/processed/master_dataset.csv`

**Authority**: Shaikh (2016), *Capitalism: Competition, Conflict, Crises*,
Appendices 6.5 §V, 6.6 §I, 6.7 §V.

---

## Pipeline Architecture

```
40_gdp_kstock_config.R          Configuration (sample, toggles, paths, API keys)
        │
        ├── 41_fetch_bea_fixed_assets.R     BEA Fixed Assets Tables 4.x, 6.x
        ├── 42_fetch_fred_gdp.R             FRED: GDPA, GNPA, GDP deflator
        │
        ├── 43_build_gdp_series.R           GDP nominal/real + GNP + NFIA
        ├── 44_build_kstock_private.R       Private K by asset (GPIM core)
        ├── 45_build_kstock_government.R    Government K (defense/nondefense)
        │
        ├── 46_shaikh_adjustments.R         Four toggle-able adjustments
        ├── 47_stock_flow_consistency.R     SFC validation + deflator tests T1-T3
        │
        └── 48_assemble_dataset.R           Merge, compute ratios, write master
```

Helper libraries:

| File | Role |
|------|------|
| `97_kstock_helpers.R` | GPIM accumulation, deflators, SFC validation, BEA I/O |
| `99_utils.R` | File I/O, path utilities, `assert_file()` |
| `99_figure_protocol.R` | Visualization protocol (PDF + PNG dual export) |

---

## Script-by-Script Reference

### 40_gdp_kstock_config.R — Configuration

Defines the `GDP_CONFIG` list governing all downstream scripts.

| Parameter | Value | Description |
|-----------|-------|-------------|
| `year_start` | 1925 | Target start year (BEA fixed assets begin here) |
| `year_end` | 2024 | Target end year |
| `year_trim` | 1929 | Fallback if pre-1929 GDP unavailable |
| `GPIM$base_year` | 2017 | Base year for real series rebasing |
| `GPIM$sfc_tolerance` | 0.001 | SFC identity tolerance (0.1%) |
| `GPIM$g_pK_approx` | 0.034 | Approx (1+g_pK) for US corporate |
| `GPIM$z_star_approx` | 0.0329 | Critical depletion rate |

**Adjustment toggles** (orthogonal, composable per §7.7):

| Toggle | Default | Effect |
|--------|---------|--------|
| `ADJ_DEPRESSION_SCRAPPING` | FALSE | IRS book-value correction 1925–1947 |
| `ADJ_GPIM_DEFLATION` | TRUE | GPIM constant-cost (eq. 5) vs BEA chain |
| `ADJ_QUALITY_CRITIQUE` | FALSE | Strip hedonic quality adjustments |
| `ADJ_WWII_INTERPOLATION` | FALSE | Smooth capital stocks 1941–1945 |

### 41_fetch_bea_fixed_assets.R — BEA Data Fetch

Fetches nine Fixed Assets tables from the BEA API (`bea.R` package):

| Table | Content | Valuation |
|-------|---------|-----------|
| 4.1 | Current-Cost Net Stock, Private FA | Current cost |
| 4.2 | Chain-Type QI Net Stock, Private FA | Chain-type |
| 4.3 | Historical-Cost Net Stock, Private FA | Historical |
| 4.4 | Current-Cost Depreciation, Private FA | Current cost |
| 4.7 | Investment in Private Fixed Assets | Current cost |
| 6.1 | Current-Cost Net Stock, Government FA | Current cost |
| 6.2 | Chain-Type QI Net Stock, Government FA | Chain-type |
| 6.3 | Current-Cost Depreciation, Government FA | Current cost |
| 6.4 | Investment in Government Fixed Assets | Current cost |

**Output**: `data/interim/bea_parsed/{table_label}.csv` (long format: year,
line_number, line_desc, value)

### 42_fetch_fred_gdp.R — FRED Data Fetch

Fetches three FRED series via the `fredr` package:

| Series ID | Description |
|-----------|-------------|
| GDPA | Nominal GDP (annual, 1929+) |
| GNPA | Nominal GNP (annual, 1929+) |
| A191RD3A086NBEA | GDP implicit price deflator (1929+) |

**Output**: `data/raw/fred/{SERIES_ID}.csv`

### 43_build_gdp_series.R — GDP Construction

Merges FRED series into a single GDP dataset. Computes:

- `gdp_real_2017`: Real GDP in chained 2017 dollars (nominal / rebased deflator)
- `nfia`: Net Factor Income from Abroad (GNP − GDP)
- Pre-1929 splicing attempted via `data/raw/fred/pre1929_gdp.csv` (if available)

**Output**: `data/processed/gdp_us_1925_2024.csv`

| Column | Description |
|--------|-------------|
| `year` | Calendar year |
| `gdp_nominal` | Nominal GDP (billions $) |
| `gdp_real_2017` | Real GDP (billions 2017$) |
| `gdp_deflator` | GDP implicit price deflator (2017 = 100) |
| `gnp_nominal` | Nominal GNP (billions $) |
| `nfia` | Net Factor Income from Abroad |

### 44_build_kstock_private.R — Private Capital Stock (GPIM Core)

The central script. For each asset type (ME, NRC, RC, IP):

1. **Extract** asset-level series from parsed BEA tables (by line number)
2. **Compute own-price implicit deflators**: `p_K = K_net_cc / K_net_chain`, rebased to base_year = 1.0
3. **Build GPIM NET stocks** via single deflation (eq. 5 with depreciation rate):
   - `K_net_real = K_net_cc / p_K`
   - `IG_real = IG_cc / p_K`
   - `D_real = D_cc / p_K`
   - SFC identity validated: max |residual| < `sfc_tolerance`
4. **Build GPIM GROSS stocks** via forward accumulation (eq. 5 with retirement rate):
   - Per GPIM_Formalization_v3, §1: `z_it` = retirement rate for gross stocks
   - Retirement rates estimated from BEA average service lives (1/L)
   - `K_gross_R_t = IG_R_t + (1 - ret_t) × K_gross_R_{t-1}`
   - Initial condition: `K_gross_0 ≈ K_net_0 × (dep_rate / ret_rate)`
   - SFC validated: GPIM gross passes, chain-weighted gross fails (confirms §2)
5. **Compute GPIM diagnostics**: depreciation rate z_t (eq. 6), retirement rate,
   Whelan-Liu rate (eq. 8), critical rate z*, half-life for both net and gross
6. **Aggregate composites**: TOTAL_PRODUCTIVE = ME + NRC, TOTAL_WITH_RC, TOTAL_ALL

**BEA average service lives** (for retirement rate estimation):

| Asset | Service Life L | Declining Balance δ | Depreciation d = δ/L | Retirement ret = 1/L |
|-------|---------------|--------------------|--------------------|---------------------|
| ME | 15 years | 1.65 | 0.110 | 0.067 |
| NRC | 38 years | 0.91 | 0.024 | 0.026 |
| RC | 50 years | 1.14 | 0.023 | 0.020 |
| IP | 5 years | 1.65 | 0.330 | 0.200 |

**Convergence regimes** (§5.3): Net stocks use depreciation rates (z > z* → convergent).
Gross stocks use retirement rates (ret may be < z* → potentially non-convergent).
This confirms Shaikh's observation that gross stocks may not converge over the sample.

**Outputs**:

| File | Content |
|------|---------|
| `kstock_private_current_cost.csv` | Wide: {asset}\_{K\_net\_cc, K\_gross\_cc, IG\_cc, D\_cc, Ret\_cc} |
| `kstock_private_gpim_real.csv` | Wide: {asset}\_{K\_net\_real, K\_gross\_real, IG\_real, D\_real, Ret\_real} |
| `kstock_private_chain_qty.csv` | Wide: {asset}\_K\_net\_chain (comparison only) |
| `price_deflators.csv` | Wide: {asset}\_p\_K |
| `data/interim/kstock_components/kstock_{asset}.csv` | Long per-asset files |
| `data/interim/validation/gpim_diagnostics.csv` | z\_dep, z\_ret, z*, tau\_half (net + gross) |

**Asset taxonomy**:

| Code | Full Name | BEA Line (Table 4.1) | Productive |
|------|-----------|----------------------|------------|
| ME | Machinery & Equipment | 6 | Yes |
| NRC | Non-Residential Construction (Structures) | 3 | Yes |
| RC | Residential Construction | 13 | No |
| IP | Intellectual Property Products | 9 | No |
| NR | Non-Residential (ME + NRC) | Derived | Yes |
| TOTAL_PRODUCTIVE | ME + NRC | Derived | Yes |
| TOTAL_WITH_RC | ME + NRC + RC | Derived | Comparison |
| TOTAL_ALL | ME + NRC + RC + IP | Derived | Comparison |

TOTAL_PRODUCTIVE = NR = ME + NRC. Following Shaikh's corporate sector concept,
only non-residential fixed capital enters the output-capital ratio. Residential
(RC) and Intellectual Property (IP) are tracked but excluded from the productive
aggregate. TOTAL_WITH_RC and TOTAL_ALL are available as comparison measures.

### 45_build_kstock_government.R — Government Capital Stock

Constructs government fixed assets by defense/nondefense breakdown from BEA
Tables 6.1–6.4. Same deflation logic as private stocks.

**Output**: `data/processed/kstock_government.csv`

### 46_shaikh_adjustments.R — Toggle-able Adjustments

Applies four orthogonal adjustments (any combination, effects separable per §7.7):

**ADJ_1: Depression Scrapping** (§6.3)

IRS book-value correction for 1925–1947. Uses Census 1975, Series V 115:
```
K^adj_t = (IRS_t / BEA_t) × K^BEA_t,     t ∈ [1925, 1947]
K^adj_t = IG_t + z*_t × K^adj_{t-1},      t ≥ 1948
```
Requires `data/raw/bea/irs_book_value.csv` (manual preparation).

**ADJ_2: WWII Interpolation**

Linear interpolation of capital stocks over 1941–1945 to smooth wartime conversion.

**ADJ_3: GPIM Deflation** (§3)

Selects between GPIM constant-cost stocks (eq. 5) and BEA chain-weighted series
(Table 4.2) for the "real" capital stock output.

**ADJ_4: Quality Critique** (§7)

Flags series for non-hedonic deflation. Operationalized in script 47 (T1-T3).

**Output**: `data/processed/kstock_shaikh_adjusted.csv`

### 47_stock_flow_consistency.R — SFC Validation + Deflator Tests

#### Part A: Stock-Flow Consistency (NET + GROSS)

For each asset and valuation mode, validates SFC identities:

**Net stock SFC**: `residual_t = K^net_t − (K^net_{t-1} + IG_t − D_t)`
**Gross stock SFC**: `residual_t = K^gross_t − (K^gross_{t-1} + IG_t − Ret_t)`

| Stock | Valuation | Expected residual | Interpretation |
|-------|-----------|-------------------|----------------|
| Net | Current-cost | Non-zero | Revaluation (holding gains/losses) |
| Net | Chain-weighted | Non-zero | Index artifact (confirms Shaikh §2) |
| Net | GPIM-deflated | ~ 0 | Validates GPIM single-deflation |
| Gross | GPIM-deflated | ~ 0 | Validates GPIM with retirement rates |
| Gross | Chain-weighted | Non-zero | Chain breaks SFC for gross too (§2) |

Per GPIM_Formalization_v3, §1: the same accumulation equations (3) and (5) apply
to both net and gross stocks — the only difference is `z_it` = depreciation rate
(net) vs retirement rate (gross).

**Output**: `data/interim/validation/sfc_residuals.csv`, `fig_sfc_residual.png`

#### Part B: Deflator Tests T1-T3

Three testable implications of the quality-adjustment problem (§7.5-7.6):

**T1 — Wedge Trend Test**

```
ω_t = ln(p^{K,QA}_t) − ln(p^K_t)
OLS: ω_t = μ + δ·t + ν_t,  Newey-West SE
H0: δ = 0
```

Tests whether the log quality-adjustment wedge has a significant time trend.

**T2 — Y/K Divergence Test**

```
ln(R^obs_t) − ln(R^QA_t) = γ₀ + γ₁·t + ξ_t
H1: γ₁ < 0  (quality adjustment flattens output-capital ratio)
```

Compares output-capital ratios under GPIM vs chain-weighted deflation.
A negative γ₁ indicates that hedonic deflation artificially flattens the
secular decline in Y/K.

**T3 — Structural Break (Zivot-Andrews)**

Zivot-Andrews unit root test on ω_t with break in intercept + trend.
Expected break: 1985–1999 (BEA hedonic adoption for computers/software).

**Output**: `data/interim/validation/deflator_tests_T1_T2_T3.csv`, `fig_quality_wedge.png`

### 48_assemble_dataset.R — Final Assembly

Merges GDP with capital stocks, computes derived ratios, cross-validates
against Shaikh canonical series, and writes the master dataset.

**Derived ratios computed**:

| Ratio | Formula | Scope |
|-------|---------|-------|
| `yk_ratio_real` | GDP_real / K_net_real | TOTAL_PRODUCTIVE |
| `iy_ratio_nom` | IG_cc / GDP_nominal | TOTAL_PRODUCTIVE |
| `dy_ratio_nom` | D_cc / GDP_nominal | TOTAL_PRODUCTIVE |
| `ik_ratio_nom` | IG_cc / K_net_cc | TOTAL_PRODUCTIVE |
| `dk_ratio_nom` | D_cc / K_net_cc | TOTAL_PRODUCTIVE |
| `yk_ratio_NR_real` | GDP_real / K_net_real | NR (non-residential) |

**Cross-validation** (1947–2011 overlap with Shaikh):
- Capital stock correlation: K_new vs KGCcorp
- Corporate VA / GDP ratio (expected ~0.5–0.7)
- Investment deflator correlation

**Output**: `data/processed/master_dataset.csv`

---

## GPIM Methodology Summary

### The Problem with Chain-Weighted Aggregation

BEA publishes capital stocks in three valuations:
1. **Current-cost** (Table 4.1): Additive, but mixes price and quantity changes
2. **Chain-type QI** (Table 4.2): Fisher-ideal chain indices; NOT additive across assets
3. **Historical-cost** (Table 4.3): Additive, but embedded in acquisition-year prices

Shaikh's key insight: the standard PIM does not survive chain aggregation.
The stock-flow consistency identity `K_t = K_{t-1} + I_t − D_t` breaks for
chain-weighted stocks because the chain index is not a linear transformation
of its components.

### GPIM Solution

The Generalized PIM deflates current-cost stocks by the SAME own-price implicit
deflator for K, I, and D:

```
p^K_t = K^cc_t / K^chain_t   (implicit deflator from BEA data)

K^R_t  = K^cc_t  / p^K_t
IG^R_t = IG^cc_t / p^K_t     (single deflation — same p_K for all flows)
D^R_t  = D^cc_t  / p^K_t
```

This preserves SFC by construction: `K^R_t = K^R_{t-1} + IG^R_t − D^R_t`.

### Net vs Gross Stocks

Per the GPIM formalization (§1), equations (3) and (5) apply to **both**
net and gross stocks — the only difference is the depletion rate:

- **Net stocks**: `z_t` = depreciation rate → `K^net_R_t = IG_R_t + (1 - z_dep) × K^net_R_{t-1}`
- **Gross stocks**: `z_t` = retirement rate → `K^gross_R_t = IG_R_t + (1 - z_ret) × K^gross_R_{t-1}`

Since `ret < dep` (assets survive longer in the gross stock), gross stocks are
larger than net stocks. The SFC identity holds for **both** under GPIM, and
breaks for **both** under chain-weighted aggregation.

### Convergence Properties

The GPIM accumulation equation has a general solution with transient and
permanent components. The transient decays if `z > z*`, where:

```
z* = g_pK / (1 + g_pK)     (critical depletion rate)
```

US calibration (1947–2009): `z* ≈ 3.29%`. Net depreciation rates (5–8%)
exceed z*, so net capital stocks converge regardless of initial conditions.
Half-life: ~24 years for US corporate sector.

---

## Data Flow Diagram

```
                     FRED API                    BEA API
                        │                           │
                   ┌────┴────┐              ┌───────┴───────┐
                   │ 42_fetch │              │ 41_fetch_bea  │
                   └────┬────┘              └───────┬───────┘
                        │                           │
               data/raw/fred/              data/interim/bea_parsed/
               *.csv                       *.csv (long format)
                        │                           │
                   ┌────┴────┐    ┌─────────────────┼───────────────┐
                   │43_build │    │                  │               │
                   │  _gdp   │    │ 44_build_        │ 45_build_     │
                   └────┬────┘    │ kstock_private   │ kstock_govt   │
                        │         └────┬─────────────┘───────┬──────┘
                        │              │                     │
               gdp_us_1925_2024.csv    │                     │
                        │         kstock_private_*.csv   kstock_government.csv
                        │         price_deflators.csv
                        │              │
                        │         ┌────┴────────┐
                        │         │46_shaikh_adj │
                        │         └────┬────────┘
                        │              │
                        │         kstock_shaikh_adjusted.csv
                        │              │
                        │         ┌────┴────────┐
                        │         │47_sfc_valid  │
                        │         └────┬────────┘
                        │              │
                        │         sfc_residuals.csv
                        │         deflator_tests_T1_T2_T3.csv
                        │              │
                   ┌────┴──────────────┴────┐
                   │ 48_assemble_dataset    │
                   └────────┬───────────────┘
                            │
                   master_dataset.csv
                            │
                   ┌────────┴───────────────┐
                   │ 49_capital_ratio_       │
                   │ analysis                │
                   └────────────────────────┘
```

---

## Output Schema: master_dataset.csv

### GDP columns

| Column | Type | Unit | Source |
|--------|------|------|--------|
| year | int | — | — |
| gdp_nominal | float | Billions $ | FRED GDPA |
| gdp_real_2017 | float | Billions 2017$ | Derived |
| gdp_deflator | float | Index (2017=100) | FRED A191RD3A086NBEA |
| gnp_nominal | float | Billions $ | FRED GNPA |
| nfia | float | Billions $ | GNP − GDP |

### Capital stock columns (per asset: ME, NRC, RC, IP, NR, TOTAL_PRODUCTIVE, TOTAL_ALL)

| Column pattern | Valuation | Unit |
|----------------|-----------|------|
| `{asset}_K_net_cc` | Current-cost | Billions $ |
| `{asset}_K_gross_cc` | Current-cost | Billions $ |
| `{asset}_IG_cc` | Current-cost | Billions $ |
| `{asset}_D_cc` | Current-cost | Billions $ |
| `{asset}_K_net_real` | GPIM constant-cost | Billions 2017$ |
| `{asset}_K_gross_real` | GPIM constant-cost | Billions 2017$ |
| `{asset}_IG_real` | GPIM constant-cost | Billions 2017$ |
| `{asset}_D_real` | GPIM constant-cost | Billions 2017$ |
| `{asset}_K_net_chain` | Chain-type QI | Index (comparison) |
| `{asset}_p_K` | — | Deflator (2017=1.0) |

### Derived ratios

| Column | Formula | Scope |
|--------|---------|-------|
| `yk_ratio_real` | gdp_real_2017 / TOTAL_PRODUCTIVE_K_net_real | ME + NRC |
| `iy_ratio_nom` | TOTAL_PRODUCTIVE_IG_cc / gdp_nominal | ME + NRC |
| `dy_ratio_nom` | TOTAL_PRODUCTIVE_D_cc / gdp_nominal | ME + NRC |
| `ik_ratio_nom` | TOTAL_PRODUCTIVE_IG_cc / TOTAL_PRODUCTIVE_K_net_cc | ME + NRC |
| `dk_ratio_nom` | TOTAL_PRODUCTIVE_D_cc / TOTAL_PRODUCTIVE_K_net_cc | ME + NRC |

---

## Running the Pipeline

### Prerequisites

```r
# R packages
install.packages(c("dplyr", "tidyr", "readr", "ggplot2",
                    "bea.R", "fredr", "sandwich", "lmtest", "urca"))

# API keys (set in environment or 40_gdp_kstock_config.R)
Sys.setenv(BEA_API_KEY = "your-key-here")
Sys.setenv(FRED_API_KEY = "your-key-here")
```

### Execution order

```bash
# From project root in R:
source("codes/41_fetch_bea_fixed_assets.R")   # Fetch BEA data
source("codes/42_fetch_fred_gdp.R")            # Fetch FRED data
source("codes/43_build_gdp_series.R")          # Build GDP
source("codes/44_build_kstock_private.R")      # Build private K (GPIM)
source("codes/45_build_kstock_government.R")   # Build government K
source("codes/46_shaikh_adjustments.R")        # Apply adjustments
source("codes/47_stock_flow_consistency.R")    # Validate SFC + T1-T3
source("codes/48_assemble_dataset.R")          # Assemble master dataset
source("codes/49_capital_ratio_analysis.R")    # Capital-output ratio analysis
```

Scripts are idempotent: re-running overwrites previous outputs.

---

## Reproducibility Notes

- All random operations seeded via `GDP_CONFIG$seed = 123456`
- BEA/FRED data cached in `data/raw/` after first fetch
- SFC validation ensures GPIM stocks satisfy accounting identities
- Build metadata logged to `data/interim/logs/build_metadata.csv`
- Deflator test results archived in `data/interim/validation/`

---

*Pipeline documentation v1 | 2026-03-14*
*Notation: see docs/notation.md | Sources: see docs/gdp_kstock_sources.md*
