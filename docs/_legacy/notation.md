# Notation and Asset Taxonomy

## GDP & Capital Stock Dataset (1925-2024) with Shaikh GPIM

**Source authority**: Shaikh (2016), *Capitalism: Competition, Conflict, Crises*,
Appendix 6.5 section V, Appendix 6.6 section I, and Appendix 6.7 section V.

**Formalization reference**: `GPIM_Formalization_v3.md` (Session 7, 2026-03-13).

---

## 1. Asset Categories

| Code  | Full Name                      | Productive? | Definition                   |
|-------|--------------------------------|-------------|------------------------------|
| ME    | Machinery & Equipment          | Yes         | BEA "Equipment" lines        |
| NRC   | Non-Residential Construction   | Yes         | BEA "Structures" lines       |
| RC    | Residential Construction       | No*         | BEA "Residential" lines      |
| IP    | Intellectual Property Products | No*         | BEA "IP products" lines      |
| NR    | Non-Residential aggregate      | Yes         | NR = ME + NRC                |
| TOTAL | Total productive fixed capital | Yes         | TOTAL = ME + NRC             |

*RC and IP are identified and tracked separately but **excluded** from productive
capital. TOTAL_PRODUCTIVE = NR = ME + NRC, following Shaikh's corporate sector
concept where only non-residential fixed capital enters the output-capital ratio.
TOTAL_WITH_RC (ME + NRC + RC) and TOTAL_ALL (ME + NRC + RC + IP) are available
as comparison aggregates.

### Government Fixed Assets

| Sector          | Sub-categories (broad only)           |
|-----------------|---------------------------------------|
| National Defense| Structures / Equipment / IP           |
| Nondefense      | Structures / Equipment / IP           |

No refined sub-categories beyond this breakdown.

---

## 2. Variable Naming Conventions

### Prefixes

| Prefix | Meaning                          | Example          |
|--------|----------------------------------|------------------|
| `K`    | Capital stock                    | `K_ME_net_cc`    |
| `IG`   | Gross investment                 | `IG_ME_cc`       |
| `D`    | Depreciation                     | `D_ME_cc`        |
| `p`    | Price index                      | `p_ME`           |
| `z`    | Depletion rate                   | `z_ME`           |
| `R`    | Output-capital ratio             | `R_obs`, `R_QA`  |
| `gdp`  | Gross domestic product           | `gdp_nominal`    |
| `gnp`  | Gross national product           | `gnp_nominal`    |

### Suffixes

| Suffix   | Meaning                                    |
|----------|--------------------------------------------|
| `_cc`    | Current-cost valuation                     |
| `_real`  | Constant-cost (GPIM-deflated)              |
| `_chain` | Chain-type quantity index (BEA)            |
| `_hist`  | Historical-cost valuation                  |
| `_net`   | Net stock (minus accumulated depreciation) |
| `_gross` | Gross stock (surviving assets at cost)     |
| `_unadj` | Unadjusted (no Shaikh corrections)        |
| `_gpim`  | GPIM-deflated                              |
| `_adj`   | Adjusted (Shaikh corrections applied)      |

---

## 3. Valuation Modes

| Mode            | BEA Source  | SFC Identity         | Additive? | Shaikh Preferred |
|-----------------|-------------|----------------------|-----------|------------------|
| Current cost    | Table 4.1   | Holds + revaluation  | Yes       | Yes              |
| Chain-type QI   | Table 4.2   | Breaks (artifact)    | No        | No               |
| Historical cost | Table 4.3   | Holds exactly        | Yes       | Partial          |
| GPIM constant   | Derived     | Holds by construction| Yes       | Yes              |

**Current cost**: `K_t` includes revaluation (holding gains/losses). The identity
`K_t = K_{t-1} + IG_t - D_t + R_t` holds exactly where `R_t` is revaluation.

**Chain-type QI**: Fisher-ideal chain aggregation of individual asset stocks. The
standard micro PIM does not survive this aggregation. Residuals in the SFC identity
are index-number artifacts, not revaluation.

**GPIM constant cost**: Derived by deflating current-cost series by own-price
implicit deflators. Preserves SFC identity `K^R_t = K^R_{t-1} + IG^R_t - D^R_t`
by construction when investment and depreciation are deflated by the same price index.

---

## 4. Stock Measures

**Net stock**: Total accumulated investment minus accumulated depreciation over the
asset's service life. Reflects the remaining productive value of the asset.
GPIM accumulation: `K^net_R_t = IG_R_t + (1 - z_dep_t) × K^net_R_{t-1}` (eq. 5)

**Gross stock**: Total accumulated investment minus retirements (not depreciation).
Reflects the physical stock of surviving assets valued at replacement cost.
GPIM accumulation: `K^gross_R_t = IG_R_t + (1 - z_ret_t) × K^gross_R_{t-1}` (eq. 5)

Per §1 of the GPIM formalization: equations (3) and (5) apply to both net and
gross stocks — the only difference is whether the depletion rate `z_it` is the
depreciation rate (net) or the retirement rate (gross). SFC holds for both under
GPIM single deflation; breaks for both under chain-weighted aggregation.

**Retirement rates**: Estimated from BEA average service lives as `ret = 1/L`:
ME = 1/15, NRC = 1/38, RC = 1/50, IP = 1/5.

---

## 5. GPIM Accumulation Rules

### Current-cost stock (eq. 3)

```
K_t = IG_t + z*_t * K_{t-1}
```

where the composite survival-revaluation factor is:

```
z*_t = (1 - z_t) * (p^K_t / p^K_{t-1})        (eq. 4)
```

`z*_t` encapsulates: (i) the fraction `(1 - z_t)` surviving the period, and
(ii) revaluation from period-(t-1) to period-t prices.

### Constant-cost (real) stock (eq. 5)

```
K^R_t = IG^R_t + (1 - z_t) * K^R_{t-1}
```

where `IG^R_t = IG_t / p^K_t`. This is an exact algebraic transformation of eq. 3.

### Theoretically correct aggregate depreciation rate (eq. 6)

```
z_t = D_t / (p^K_t * K^R_{t-1}) = sum_i z_{it} * w_{it}
```

where reflated weights are:

```
w_{it} = (p^K_{it} * K^R_{i,t-1}) / (p^K_t * K^R_{t-1})     (eq. 7)
```

### Whelan-Liu approximation (eq. 8)

```
z^WL_t = D_t / K_{t-1}
```

Biased: uses lagged current values instead of reflated values.

---

## 6. Convergence Properties

### General solution (constant-coefficient approximation)

```
K_t = A(z) * (z*)^t + C(z) * IG_t              (eq. 11)
C(z) = (1+g_I) / [(1+g_I) - (1-z)(1+g_pK)]    (eq. 12)
A(z) = K_0 - C(z) * IG_0                        (eq. 13)
```

### Critical depletion rate (eq. 15)

```
z_star = g_pK / (1 + g_pK)
```

| Condition       | Regime     | Implication                                   |
|-----------------|------------|-----------------------------------------------|
| z > z_star      | z* < 1     | Transient decays: initial-value convergence    |
| z = z_star      | z* = 1     | Transient persists as constant level shift     |
| z < z_star      | z* > 1     | Transient grows: initial-value divergence      |

**US calibration (1947-2009)**: `(1+g_pK) ~ 1.034`, `z_star ~ 3.29%`.
Net depreciation rates (~5-8%) exceed z_star: net stocks converge.
Gross retirement rates may be below z_star: gross stocks may not converge.

### Half-life (eq. 16)

```
tau_half = ln(2) / ln(1/z*)
```

US corporate net stock: tau_half ~ 24 years.

---

## 7. Shaikh's Three Adjustments

### ADJ_1: Depletion rates (section 6.1)

BEA 1993 finite-service-life vs BEA 2011 geometric-infinite-life assumptions.
Our generalized approach uses current BEA releases but quantifies sensitivity.

### ADJ_2: Initial values (section 6.2)

BEA 1993 starts ~31% below BEA 2011 in 1925; gap narrows to <2% by 1969.
Sensitivity documented via convergence half-life computation.

### ADJ_3: Great Depression scrapping (section 6.3)

IRS book value index correction for 1925-1947:

```
K^adj_t = (IRS_t / BEA_t) * K^BEA_t,     t in [1925, 1947]    (eq. 17)
K^adj_t = IG_t + z*_t * K^adj_{t-1},      t >= 1948             (eq. 18)
```

Toggle-able: when OFF, BEA official series used directly.

---

## 8. Deflator Problem: Quality Adjustment

### The stock-flow distortion (section 7.3)

Quality-adjusted (hedonic) deflators absorb secular variation in capital
productivity into the price index:

```
(Y_t/p^Y_t) / (K_t/p^{K,QA}_t) = (Y_t/K_t) * (p^{K,QA}_t / p^Y_t)    (eq. 19)
```

The spurious relative-price wedge contaminates the stock-flow ratio.

### Log quality-adjustment wedge (eq. 22)

```
omega_t = ln(p^{K,QA}_t) - ln(p^K_t)
```

### Testable implications

**T1 (Wedge trend)**: OLS `omega_t = mu + delta*t + nu_t`, Newey-West SE.
H0: delta = 0.

**T2 (Y/K divergence)**: `ln(R^obs_t) - ln(R^QA_t) = gamma_0 + gamma_1*t + xi_t`.
H1: gamma_1 < 0 (quality adjustment flattens output-capital ratio).

**T3 (Structural break)**: Zivot-Andrews on omega_t. Expected break: 1985-1999
(BEA hedonic adoption for computers/software/communications).

Adjustments and deflator choice are orthogonal dimensions (section 7.7).

---

## 9. BEA Data Sources

| Table | Content                                  | Valuation     | Coverage   |
|-------|------------------------------------------|---------------|------------|
| 4.1   | Current-Cost Net Stock, Private FA       | Current cost  | 1925-2024  |
| 4.2   | Chain-Type QI Net Stock, Private FA      | Chain-type    | 1925-2024  |
| 4.3   | Historical-Cost Net Stock, Private FA    | Historical    | 1925-2024  |
| 4.4   | Current-Cost Depreciation, Private FA    | Current cost  | 1925-2024  |
| 4.7   | Investment in Private Fixed Assets       | Current cost  | 1925-2024  |
| 6.1   | Current-Cost Net Stock, Government FA    | Current cost  | 1925-2024  |
| 6.2   | Chain-Type QI Net Stock, Government FA   | Chain-type    | 1925-2024  |
| 6.3   | Current-Cost Depreciation, Government FA | Current cost  | 1925-2024  |
| 6.4   | Investment in Government Fixed Assets    | Current cost  | 1925-2024  |

---

## 10. Full Notation Index

| Symbol          | Definition                                          | Eq.    |
|-----------------|-----------------------------------------------------|--------|
| K_t             | Aggregate current-cost capital stock                | eq. 3  |
| K^R_t           | Aggregate constant-cost (real) capital stock        | eq. 5  |
| K^{R,obs}_t     | Real stock under observed-price deflator            | eq. 23 |
| K^{R,QA}_t      | Real stock under quality-adjusted deflator          | eq. 23 |
| K^adj_t         | GPIM-adjusted stock (post-IRS correction)           | eq. 17 |
| IG_t            | Aggregate gross investment (current prices)         | eq. 3  |
| IG^R_t          | Aggregate real gross investment                     | eq. 5  |
| z_t             | Theoretically correct aggregate depreciation rate   | eq. 6  |
| z^WL_t          | Whelan-Liu approximate depreciation rate            | eq. 8  |
| z*_t            | Composite survival-revaluation factor               | eq. 4  |
| z_star          | Critical depletion rate (convergence threshold)     | eq. 15 |
| p^K_t           | Aggregate capital-goods price index (observed)      | eq. 4  |
| p^{K,QA}_t      | Quality-adjusted capital-goods price index          | S7.2   |
| p^K_{it}        | Asset-type i price index                            | eq. 7  |
| omega_t         | Log quality-adjustment wedge                        | eq. 22 |
| R^obs_t         | Output-capital ratio (observed-price deflator)      | eq. 24 |
| R^QA_t          | Output-capital ratio (quality-adjusted deflator)    | eq. 24 |
| g_I             | Average growth rate of gross investment             | S5.1   |
| g_pK            | Average growth rate of capital-goods prices         | eq. 9  |
| C(z)            | Permanent-component multiplier                      | eq. 12 |
| A(z)            | Transient-component amplitude                       | eq. 13 |
| tau_half        | Half-life of transient component                    | eq. 16 |
| D_t             | Aggregate nominal depreciation                      | eq. 6  |
| w_{it}          | Reflated real-stock weight for asset i              | eq. 7  |

---

*Notation v2 | 2026-03-14*
*Do not edit without version increment*
