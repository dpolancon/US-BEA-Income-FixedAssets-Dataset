# KSTOCK_Architecture_v1
## Four-Account Productive Capital Dataset — Consolidated Decision Log

**Date:** 2026-03-26 | **Status:** LOCKED | **Version:** 1.0
**Repo:** `C:\ReposGitHub\Critical-Replication-Shaikh\`
**Output:** `data/processed/kstock_master.csv`

> This document is the authoritative reference for all architectural decisions governing Dataset 2. Claude Code reads this before writing any code. Nothing here is provisional unless explicitly marked OPEN.

---

# 1. Purpose and Scope

**Dataset 2** is a four-account productive capital dataset built from the current BEA vintage (September 2025 revision), covering 1925–2024. It is **distinct** from Dataset 1 (the sealed Shaikh replication, 2011 BEA vintage, 1947–2011). The two datasets must never be mixed.

**Research purpose:** Extend the GPIM capital stock construction to a theoretically correct four-account decomposition — nonfinancial corporate structures, nonfinancial corporate equipment, government transportation infrastructure, and NF corporate IPP (tracked separately). Provides the capital stock series for robustness analysis of the θ(Λ) estimation in S3 and for the Chile comparative axis.

**Governing principle:** SFC first, always. All series are derived from two BEA-reported inputs — current-cost net stock (KNC) and gross investment flow (IG) — via strict stock-flow consistency. No external price index, no quality adjustment, and no assumption enters the construction beyond the Weibull retirement parameters. If SFC fails at any step, the pipeline halts.

---

# 2. Dataset Boundary

## 2.1 Canonical productive capital stock

```
KGC_productive_t = KGC_NF_structures_t + KGC_NF_equipment_t + KGC_gov_transport_t
```

**Perimeter:** Nonfinancial corporate (structures + equipment) + government transportation infrastructure.

**Theoretical grounding:**
- NF corporate structures and equipment: nonfinancial corporate business as the locus of productive capital accumulation. Output = NVA_NF = NIPA T1.14 Line 19.
- Government transportation infrastructure: general conditions of production in the Marxist sense (Marx Vol. II). Highways, airports, and land transportation infrastructure are non-substitutable material conditions for the circuit of corporate capital. Grounded in Shaikh (2016) Ch. 7 social capital. **NOT justified via Aschauer (1989)** — that is a neoclassical production function argument incompatible with the framework.

## 2.2 Separately tracked series (not in KGC_productive)

| Series | Theoretical role | BEA source |
|--------|-----------------|------------|
| `KGC_NF_IPP` | Capital-reshaping intangible | Table 6.1, NF corporate IPP line |
| `KGC_F_total` | Financial corporate — financialization tracker | Table 6.1, Financial corporate line |
| `K_noncorp` | Noncorporate private — sensitivity series | Table 6.1, Noncorporate line |
| `inv_NF` | Circuit capital — NF corporate inventories | NIPA Table 5.7.5B |

## 2.3 Output series

```
Y_t = NVA_NF_t  (NIPA T1.14 Line 19 — Net value added, nonfinancial corporate)
```

**Why NVA not GVA:** GPIM stock-flow consistency rules entail cointegration of NVA (not GVA) with gross capital stock under common deflator. The gross-gross pairing (GVA + K^G) breaks under the post-2023 BEA comprehensive revision due to secular rise in CFC/GVA ratio.

---

# 3. Data Sources and Coverage

## 3.1 Capital stock accounts

| Account | Net stock table | Investment table | Coverage |
|---------|----------------|-----------------|----------|
| NF corporate structures | BEA FAAt601 (Table 6.1), NF struct. line | BEA FAAt607 (Table 6.7), NF struct. line | 1925–2024 |
| NF corporate equipment | BEA FAAt601 (Table 6.1), NF equip. line | BEA FAAt607 (Table 6.7), NF equip. line | 1925–2024 |
| Gov transportation | BEA FAAt701 (Table 7.1), transport lines | BEA FAAt705 (Table 7.5), transport lines | 1925–2024 |
| NF corporate IPP | BEA FAAt601 (Table 6.1), NF IPP line | BEA FAAt607 (Table 6.7), NF IPP line | 1925–2024 |

**Investment warmup:** Tables 6.7 and 7.5 provide investment flows from 1901. When `USE_1901_WARMUP = TRUE`, the GPIM recursion begins in 1901 using investment flows only, and the 1925 net stock serves as a validation checkpoint rather than a cold-start anchor.

## 3.2 Income accounts

| Series | Source | Lines |
|--------|--------|-------|
| Full NF corporate income decomposition | NIPA Table 1.14 | Lines 17–40 |
| GDP implicit price deflator (Py) | FRED: A191RD3A086NBEA | — |

## 3.3 BEA API credentials

Stored in `C:\Users\User\OneDrive\Documents\.Renviron`:
- `BEA_API_KEY` — BEA data API
- `FRED_API_KEY` — FRED data API

Fetch infrastructure: `codes/50_fetch_fixed_assets.R` (existing). New fetch functions for accounts C, D, E, G to be added in `codes/60_agents_prod_cap.R`.

---

# 4. GPIM Construction Rules

## 4.1 Master rule: two inputs only

All series derived from `KNC_i_t` (BEA-reported current-cost net stock) and `IG_i_t` (BEA-reported gross investment flow). Everything else derived. No exceptions.

## 4.2 Derivation chain per account

```
DEP_i_t  = IG_i_t - (KNC_i_t - KNC_i_{t-1})          [SFC identity — not a parameter]
pK_i_t   = KNC_i_t / KNR_i_t * 100                    [own-series deflator, KNR from FAAt602]
z_i_t    = DEP_i_t / (pK_i_t/100 * KNR_i_{t-1})       [theoretically correct dep. rate]
IG_R_i_t = IG_i_t / (pK_i_t / 100)                    [real investment]
KNR_i_t  = IG_R_i_t + (1 - z_i_t) * KNR_i_{t-1}      [GPIM real net stock recursion]
rho_i_t  = weibull_hazard(tau_bar_i_t, L_i, alpha_i)  [retirement rate — see §5]
KGC_R_i_t= IG_R_i_t + (1 - rho_i_t) * KGC_R_i_{t-1} [gross real stock]
KGC_i_t  = KGC_R_i_t * (pK_i_t / 100)                [gross current-cost stock]
```

## 4.3 SFC checks — mandatory at every step

```
Net SFC:   KNC_i_t - KNC_i_{t-1} = IG_i_t - DEP_i_t          [tolerance: 1e-4]
Real SFC:  KNR_i_t - KNR_i_{t-1} = IG_R_i_t - DEP_R_i_t      [tolerance: 1e-4]
```

If either identity fails: **HALT**. Log the account, year, and violation magnitude.

## 4.4 Aggregate construction

```
KNC_productive_t = sum_i KNC_i_t
KNR_productive_t = sum_i KNR_i_t
KGC_productive_t = sum_i KGC_i_t
pK_productive_t  = KNC_productive_t / KNR_productive_t * 100
```

Aggregate SFC check (tolerance 1e-3):
```
KNC_productive_t - KNC_productive_{t-1} = IG_productive_t - DEP_productive_t
```

---

# 5. Weibull Retirement Parameters

**Method:** Option B (Weibull with finite service lives). Toggle for Shaikh BEA 1993 rates preserved as sensitivity-only.

**Canonical parameters — LOCKED:**

| Account | L (yr) | alpha | lambda = L/Gamma(1+alpha^-1) | Sources |
|---------|--------|-------|------------------------------|---------|
| NF corporate structures | **30** | **1.6** | ~33.0 | Fraumeni T (adj.), Shaikh implicit, Nomura Case-3 |
| NF corporate equipment | **14** | **1.7** | ~15.3 | All three sources convergent |
| Gov transportation | **60** | **1.3** | ~68.4 | Fraumeni T (US highways), Nomura alpha (roads shape) |

**Weibull hazard function:**
```
h(tau) = (alpha/lambda) * (tau/lambda)^(alpha-1)    where lambda = L / Gamma(1 + alpha^-1)
```

**Toggle in 10_config.R:**
```r
USE_WEIBULL_RETIREMENT   <- TRUE    # Option B — canonical
USE_SHAIKH_BEA1993_RATES <- FALSE   # Option A — sensitivity only

WEIBULL_PARAMS <- list(
  structures    = list(L=30, alpha=1.6),
  equipment     = list(L=14, alpha=1.7),
  gov_transport = list(L=60, alpha=1.3)
)
```

---

# 6. Deflator Architecture

**Base year: 2017** throughout Dataset 2. All pK series rebased so pK_2017 = 100.

**Inside GPIM recursion:** Account-specific own-series deflator `pK_i = KNC_i / KNR_i * 100`. Never use an external capital goods price index here.

**Aggregate productive stock deflator:** `pK_productive = KNC_productive / KNR_productive * 100`. Derived from summed components — not a weighted average of component deflators.

**Estimation objects — two variants (both built):**
```r
k_Py_t  <- log(KGC_productive_t / (Py_t / 100))              # Shaikh-consistent
k_pK_t  <- log(KGC_productive_t / (pK_productive_t / 100))   # GPIM-strict
y_t     <- log(NVA_NF_t / (Py_t / 100))                      # canonical output
```

**Dataset 1 vs Dataset 2 deflators — DO NOT MIX:**
- Dataset 1 (Shaikh sealed): Py base ~2011=100, pKN from canonical CSV (2005=100)
- Dataset 2 (current vintage): all series 2017=100

---

# 7. Income Accounts

Full NF corporate income decomposition from NIPA T1.14 Lines 17–40. See BEA_LineMap_v1.md §7 for exact line numbers.

**Derived series (computed, not fetched):**
```r
GOS_NF   <- GVA_NF - EC_NF - TPI_NF       # Gross operating surplus
ProfSh   <- NOS_NF / NVA_NF               # Net profit share
WageSh   <- EC_NF / NVA_NF                # Wage share
```

**Internal consistency checks:**
- `NVA_NF == GVA_NF - CCA_NF` for all years
- `GOS_NF == GVA_NF - EC_NF - TPI_NF` for all years

**Specification variants (all built as columns):**

| Column | Numerator | Denominator | Use |
|--------|-----------|-------------|-----|
| `y_t` | NVA_NF | Py | Canonical |
| `y_GVA_t` | GVA_NF | Py | Gross output sensitivity |
| `y_GOS_t` | GOS_NF | Py | Pre-depreciation surplus |
| `y_NOS_t` | NOS_NF | Py | Net operating surplus |

---

# 8. Canonical Validation Values

| Check | Expected value | Tolerance | Note |
|-------|---------------|-----------|------|
| `NVA_NF_1947 / KGC_productive_1947` | ~0.685 | ±0.05 | Rcorp benchmark |
| OLS theta from `log(NVA/KGC) ~ log(KGC)` | ~0.775 | ±0.05 | Capital elasticity |
| `KGC_productive_2011` | Cross-check vs Dataset 1 | — | Vintage gap expected |
| Aggregate SFC violation | 0.000 | <1e-3 | Every year |

---

# 9. Output Files

| File | Content | Phase |
|------|---------|-------|
| `data/processed/kstock_master.csv` | All estimation objects + capital accounts (wide) | Phase 4 |
| `data/processed/income_accounts_NF.csv` | Full NF corporate income decomposition | Phase 4 |
| `data/processed/kstock_accounts_long.csv` | Per-account GPIM outputs (long format) | Phase 4 |

---

# 10. Configuration Toggles (10_config.R)

| Toggle | Default | Effect |
|--------|---------|--------|
| `USE_WEIBULL_RETIREMENT` | TRUE | Weibull rho(tau) — canonical |
| `USE_SHAIKH_BEA1993_RATES` | FALSE | BEA 1993 aggregate retirement rates |
| `USE_1901_WARMUP` | TRUE | GPIM recursion from 1901 investment flows |
| `ADJ1_BEA1993_DEPLETION` | TRUE | Theoretically correct depreciation rate |
| `ADJ2_BEA1993_INITIAL` | TRUE | Lower 1925 initial value (0.793 proxy) |
| `ADJ3_IRS_SCRAPPING` | TRUE | IRS Depression scrapping correction |
| `BASE_YEAR_DEFLATOR` | 2017 | Price index base year |
| `SAMPLE_YEARS` | 1925:2024 | Construction window |
| `EST_YEARS` | 1947:2024 | Estimation window |

---

# 11. What This Dataset Is NOT

- **Not Dataset 1.** The sealed Shaikh replication (2011 BEA vintage, `data/raw/shaikh_data/`) is untouched. Dataset 2 uses current BEA vintage and a different perimeter (NF corporate, not total corporate).
- **Not a replacement for the ARDL estimation.** Dataset 2 provides the capital stock series for robustness and sensitivity analysis. The S0–S3 estimation pipeline continues to use Dataset 1 as canonical.
- **Not a neoclassical production function.** Government transportation enters as a general condition of production (Marx Vol. II, Shaikh Ch. 7), not as a Cobb-Douglas factor input (Aschauer).

---

**Cross-references:**
- BEA_LineMap_v1.md — exact API table/line mappings
- Weibull_Retirement_Distributions.md — Weibull parameter derivation
- Multi-Agent Claude Code Architecture (NB4) — workflow and agent contracts
- GPIM_Formalization_v3.md — theoretical derivation of GPIM rules
- Cointegration_FourPairings_v1.md — deflator choice derivation
