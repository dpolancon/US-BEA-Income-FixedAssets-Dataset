# Variable Scope & GPIM Extension Map

**Repo**: US-BEA-Income-FixedAssets-Dataset
**Date**: 2026-04-04
**Purpose**: Full inventory of available variables + GPIM-extensible frontier

---

## A. INCOME ACCOUNTS (NIPA Table 1.14, Lines 17–40)

### A1. Output Variables — Nonfinancial Corporate

| Variable | Description | Source |
|----------|-------------|--------|
| `GVA_NF` | Gross value added, NF corporate | T1.14 L17 |
| `NVA_NF` | Net value added, NF corporate | T1.14 L19 |
| `CCA_NF` | Consumption of fixed capital | T1.14 L18 |
| `GVAcorpnipa` | Total corporate GVA (unadjusted) | T1.14 L1 |
| `VAcorpnipa` | Total corporate NVA (unadjusted) | T1.14 L3 |
| `GVAcorp` | Corporate GVA + imputed interest adj | Derived |
| `VAcorp` | Corporate NVA: GVAcorp − DEPCcorp | Derived |

### A2. Labor Income

| Variable | Description | Source |
|----------|-------------|--------|
| `EC_NF` | Employee compensation (wages + fringe) | T1.14 L20 |
| `ECcorp` | Total corporate employee compensation | T1.14 L4 |
| `Wages_NF` | Pure wage component | Derived |
| `Supplements_NF` | Employer contributions | Derived |

### A3. Taxes & Transfers

| Variable | Description | Source |
|----------|-------------|--------|
| `TPI_NF` | Taxes on production/imports less subsidies | T1.14 L23 |
| `Tcorp` | Total corporate taxes | T1.14 L7 |
| `CorpTax_NF` | Corporate income taxes | T1.14 L28 |
| `BusTransfer_NF` | Business transfer payments | T1.14 L26 |

### A4. Surplus / Profit

| Variable | Description | Source |
|----------|-------------|--------|
| `NOS_NF` | Net operating surplus | T1.14 L24 |
| `GOS_NF` | Gross operating surplus: GVA − EC − TPI | Derived |
| `Profits_IVA_CC_NF` | Corporate profits with IVA + CCAdj | T1.14 L27 |
| `PAT_IVA_CC_NF` | Profits after tax with IVA + CCAdj | T1.14 L29 |
| `PBT_NF` | Profits before tax | T1.14 L32 |
| `PAT_NF` | Profits after tax | T1.14 L33 |
| `Pcorp` | Total corporate profits | T1.14 L11 |
| `NOScorp` | Total corporate operating surplus | Derived |

### A5. Interest, Dividends & Adjustments

| Variable | Description | Source |
|----------|-------------|--------|
| `NetInt_NF` | Net interest paid | T1.14 L25 |
| `BankMonIntPaid` | Banking imputed interest | T7.11 |
| `CorpNFNetImpIntPaid` | Corp NF net imputed interest | T7.11 |
| `CorpImpIntAdj` | Shaikh imputed interest adjustment | Derived |
| `Dividends_NF` | Dividend payments | T1.14 L30 |
| `Retained_IVA_CC_NF` | Retained earnings with IVA + CCAdj | T1.14 L31 |
| `Retained_NF` | Retained earnings, pure | T1.14 L34 |
| `IVA_NF` | Inventory valuation adjustment | T1.14 L35 |
| `CCAdj_NF` | Capital consumption adjustment | T1.14 L36 |
| `DEPCcorp` | Corporate depreciation | Derived from SFC |

### A6. Distributional Shares

| Variable | Description | Formula |
|----------|-------------|---------|
| `ProfSh_NF` | Profit share | NOS_NF / NVA_NF |
| `WageSh_NF` | Wage share | EC_NF / NVA_NF |
| `exploit_rate` | Rate of exploitation | NOScorp / ECcorp |
| `profit_share` | Profit share (total corp) | Pcorp / VAcorp |
| `rcorp` | Profit rate | Pcorp / lag(KNCcorp) |

---

## B. CAPITAL STOCK SERIES

### B1. Corporate Aggregate (Dataset 1 — Sealed)

| Variable | Description | BEA Table |
|----------|-------------|-----------|
| `KGCcorp` | **Gross current-cost stock** (LOCKED for ARDL) | FAAt601 |
| `KNCcorpbea` | Net current-cost stock | FAAt601 |
| `KNRcorpbea` | Net chain-type quantity index | FAAt602 |
| `KNRIndxcorpbea` | Chain-type index (2017=100) | FAAt602 |
| `KNHcorpbea` | Net historical-cost stock (validation) | FAAt603 |
| `IGCcorpbea` | Gross investment, current-cost | FAAt607 |

### B2. GPIM-Derived Capital Variables

| Variable | Description | Formula |
|----------|-------------|---------|
| `pKN` | Own-price deflator | KNCcorpbea / KNRIndxcorpbea × 100 |
| `KNRcorp` | Real net stock | KNCcorp / pKN |
| `KGRcorp` | Real gross stock | KGCcorp / pKN |
| `IG_R_net` | Real gross investment | IGCcorpbea / pKN |
| `DEPCcorpbea` | Current-cost depreciation | I − ΔK (SFC identity) |
| `dcorpstar` | GPIM depreciation rate | D_t / (pK_t × K^R_{t−1}) |
| `dcorp_WL` | Whelan-Liu depreciation rate | D_t / K_{t−1} |

### B3. Asset-Type Decomposition (BEA Table 2.x — Private by Type)

For each asset class **i ∈ {ME, NRC, RC, IP}** plus composites:

| Suffix pattern | Description |
|---------------|-------------|
| `{i}_K_net_cc` | Net stock, current-cost |
| `{i}_K_net_chain` | Net stock, chain-type index |
| `{i}_K_net_real` | Net stock, GPIM-deflated real |
| `{i}_K_gross_cc` | Gross stock, current-cost |
| `{i}_K_gross_real` | Gross stock, GPIM-deflated real |
| `{i}_IG_cc` | Investment, current-cost |
| `{i}_IG_real` | Investment, real |
| `{i}_D_cc` | Depreciation, current-cost |
| `{i}_D_real` | Depreciation, real |
| `{i}_Ret_cc` | Retirements, current-cost |
| `{i}_Ret_real` | Retirements, real |
| `{i}_p_K` | Own-price deflator |

**Composites**: `NR` (ME+NRC), `TOTAL_PRODUCTIVE` (ME+NRC, excludes RC), `TOTAL_WITH_RC`, `TOTAL_ALL`

### B4. Government Transportation Infrastructure (FAAt701/FAAt705)

| Variable | Description |
|----------|-------------|
| `KNC_gov_trans` | Net current-cost stock |
| `KNR_gov_trans` | Real net stock |
| `KGC_gov_trans` | Gross current-cost stock |
| `KGR_gov_trans` | Real gross stock |
| `IG_cc_gov_trans` / `IG_R_gov_trans` | Investment (nominal / real) |
| `pK_gov_trans` | Own-price deflator |
| `z_gov_trans` | Depreciation rate |
| `rho_gov_trans` | Retirement rate (Weibull L=60, α=1.3) |

Sub-components: highways/streets, air, land, water transport.

### B5. Dataset 2 Four-Account System (kstock_master.csv)

| Account | Scope | Weibull (L, α) |
|---------|-------|-----------------|
| A: NF Corp Structures | `_NF_struct` | (30, 1.6) |
| B: NF Corp Equipment | `_NF_equip` | (14, 1.7) |
| C: Gov Transport | `_gov_trans` | (60, 1.3) |
| D: NF Corp IPP | `_NF_IPP` | TBD (parked) |
| E: Financial Corporate | `_fin_corp` | TBD (parked) |

Each account carries: KNC, KNR, KGC, KGR, IG_cc, IG_R, pK, z, rho.

**Aggregate**: `KGC_productive` = NF corporate + gov transport (primary K for extended Y:K).

---

## C. OUTPUT-CAPITAL RATIOS

| Variable | Numerator | Denominator | Use |
|----------|-----------|-------------|-----|
| `R_GVA_KGC` | GVAcorp | KGCcorp | Dataset 1 standard (gross-gross) |
| `R_NVA_KGC` | NVA_NF | KGCcorp | **Locked for cointegration** (net-gross) |
| `R_GVA_KNC` | GVAcorp | KNCcorp | Gross-net variant |
| `R_NVA_KNC` | NVA_NF | KNCcorp | Net-net variant |

---

## D. DEFLATORS & MACRO AGGREGATES

| Variable | Description | Source |
|----------|-------------|--------|
| `Py` | GDP implicit price deflator (2017=100) | FRED A191RD3A086NBEA |
| `pKN` | Corporate capital own-price deflator | BEA FAA derived |
| `gdp_nominal` | Nominal GDP | FRED GDPA |
| `gdp_real_2017` | Real GDP (2017$) | Derived |
| `gnp_nominal` | Nominal GNP | FRED GNPA |
| `nfia` | Net factor income from abroad | Derived |

---

## E. SFC VALIDATION METRICS

| Variable | Description | Tolerance |
|----------|-------------|-----------|
| `residual` | K_t − (K_{t−1} + I_t − D_t) | — |
| `pct_residual` | residual / K_actual | — |
| Net SFC | Per-account identity | 1e-4 |
| Real SFC | GPIM-deflated identity | 1e-4 |
| Aggregate SFC | Cross-account totals | 1e-3 |

---

## F. ADJUSTMENT TOGGLES (Shaikh Appendix 6.8)

| Toggle | What it does | Affects |
|--------|-------------|---------|
| `ADJ1_BEA1993_DEPLETION` | Uses pre-1997 depreciation rates | dcorpstar |
| `ADJ2_BEA1993_INITIAL` | Scales 1925 opening stock by IRS/BEA ratio (0.793) | K(1925) |
| `ADJ3_IRS_SCRAPPING` | Sharper retirement during 1929–1933 | rho_t |

---

## G. GPIM EXTENSION FRONTIER

Everything below can be constructed from the **same two BEA inputs** (KNC + IG) per account, applying the GPIM stock-flow identity: K_t = K_{t−1} + I_t − D_t, with own-price deflation pK = KNC/KNR.

### G1. Accounts Ready to Activate

| Extension | BEA Source | Status | What it yields |
|-----------|-----------|--------|----------------|
| **NF Corporate IPP** (Account D) | FAAt601 IPP lines | Architecture exists, Weibull TBD | Software/R&D capital separate from tangible |
| **Financial Corporate** (Account E) | FAAt601 financial lines | Architecture exists, Weibull TBD | Financial vs. nonfinancial capital split |
| **Residential Capital** | FAAt201 RC lines | Data extracted, excluded from TOTAL_PRODUCTIVE | Housing stock for expanded wealth analysis |

### G2. Sectoral Extensions (Same GPIM Method, New BEA Sections)

| Extension | BEA Table | Inputs Needed | GPIM Application |
|-----------|-----------|---------------|-----------------|
| **By industry** (manufacturing, mining, utilities, etc.) | FAAt301–FAAt305 (Section 3) | KNC + IG per industry | Industry-level K construction with own pK per sector |
| **Government non-transport** (education, health, defense) | FAAt701–FAAt705 remaining lines | KNC + IG per gov function | Broader social infrastructure stock |
| **State & local government** | FAAt706–FAAt710 | KNC + IG per state/local function | Decentralized public capital |
| **Consumer durables** | FAAt801–FAAt805 (Section 8) | KNC + IG for durables | Household capital stock (Marxian extended reproduction) |

### G3. Deepening Within Existing Accounts

| Extension | Method | Value Added |
|-----------|--------|-------------|
| **Sub-asset Weibull calibration** | Separate (L, α) for software, R&D, artistic originals within IPP | More accurate retirement profiles for fast-depreciating intangibles |
| **Vintage-specific depreciation** | Track d*(τ) by cohort age, not aggregate d* | Age-composition effects on measured depreciation |
| **Cross-country GPIM** | Apply same KNC+IG → pK → K^R method to OECD/EU KLEMS data | International comparison of productive capital with consistent deflation |
| **Real depreciation rates** | z* = D / (pK × K^R_{t−1}) computed for each new account | Correct for inflation bias in nominal depreciation |
| **Gross-net gap analysis** | Track (KGC − KNC) / KGC over time per account | Measures "paper depreciation" accumulation — proxy for vintage structure |

### G4. Analytical Ratios Extensible via GPIM

| New Ratio | Formula | Interpretation |
|-----------|---------|----------------|
| Y/K by asset type | NVA_NF / KGC_{ME,NRC,IP} | Which asset class drives capacity? |
| Sectoral profit rates | NOS_industry / KNC_industry | Cross-industry rate equalization tests |
| Public/private K ratio | KGC_gov / KGC_NF_corp | Crowding-in vs. crowding-out dynamics |
| Equipment-structure ratio | KGC_NF_equip / KGC_NF_struct | Technical composition of capital |
| Real investment share | IG_R_i / Σ IG_R | Asset-type investment mix over time |
| Aggregate vintage age | τ̄_t per account (Weibull recursion) | Mean age of capital — modernization proxy |

### G5. What GPIM Rules Require for Any Extension

To extend to a new account or sector, you need exactly:

1. **KNC** (current-cost net stock) — from BEA Fixed Assets
2. **IG** (current-cost gross investment) — from BEA Fixed Assets
3. **KNR or chain-type index** — from BEA Fixed Assets (for pK derivation)
4. **Weibull (L, α)** — from BEA documentation or calibration
5. **Cold-start year** — earliest year with reliable KNC + IG data

The GPIM then mechanically produces: pK, K^R, K^G (real gross), D (real depreciation), z* (depreciation rate), ρ (retirement rate), and full SFC validation residuals. No external price index enters the capital-side construction.

### G6. Boundary: What GPIM Cannot Do

| Limitation | Why |
|-----------|-----|
| Labor input measurement | GPIM is capital-side only; hours/employment require separate data |
| TFP estimation | Requires production function assumption GPIM deliberately avoids |
| Financial asset valuation | GPIM applies to fixed reproducible assets, not equities/bonds |
| Land and natural resources | Non-reproducible — no SFC identity applies |
| Inventory capital | BEA inventories follow different accounting (LIFO/FIFO), not SFC-compatible |

---

## H. FILE MAP (Processed Data)

| File | Years | Key Variables |
|------|-------|---------------|
| `corp_kstock_series.csv` | 1925–2024 | KNCcorp, KGCcorp, DEPCcorp, dcorpstar |
| `corp_output_series.csv` | 1929–2024 | GVAcorp, VAcorp, NOScorp, ECcorp, Pcorp |
| `income_accounts_NF.csv` | 1929–2024 | GVA_NF, NVA_NF, NOS_NF, EC_NF, full decomposition |
| `utilization_ratios.csv` | 1929–2024 | R_GVA_KGC, R_NVA_KGC, exploit_rate, profit_share |
| `kstock_private_current_cost.csv` | 1925–2024 | Asset-type K/IG/D (nominal) |
| `kstock_private_gpim_real.csv` | 1925–2024 | Asset-type K/IG/D (GPIM real) |
| `kstock_government.csv` | 1925–2024 | Gov transport K, IG, D, pK |
| `kstock_master.csv` | 1925–2024 | All four accounts + aggregates |
| `price_deflators.csv` | 1925–2024 | Asset-type pK indices |
| `gdp_us_1925_2024.csv` | 1925–2024 | GDP, GNP, Py |
| `stock_flow_validation.csv` | 1925–2024 | SFC identity audit trail |
