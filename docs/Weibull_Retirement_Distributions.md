# Weibull Retirement Distributions
## Formalization, Sources, and Parameter Decision for Dataset 2

**Date:** 2026-03-26 | **Updated:** 2026-03-27
**Status:** Parameters locked. Initialization corrected. Future extensions flagged.
**Scope:** NF corporate aggregate, Government transportation infrastructure, NF corporate IPP.

> **2026-03-27 updates:** (1) tau_bar initialization corrected from L/2 (balanced-growth assumption) to cold-start recursion from 1901. (2) p_lag boundary assumption documented. (3) NF_corp account is an aggregate (no E/S/IPP sub-line split available from FAAt601). See §1.6 and §1.7.

---

# 1. Formalization of the Weibull Retirement Distribution

## 1.1 Why a retirement distribution is needed

The GPIM construction of gross capital stock requires an assumption about the **retirement rate** — the fraction of the installed capital stock that physically exits production in each period. This is conceptually distinct from the depreciation rate, which governs value attrition in the net stock. A machine that depreciates to zero accounting value may still operate at full productive capacity until it is retired. The gross stock tracks installed physical capacity; it falls only when assets are removed from service.

The retirement rate ρ(τ) is not directly observed. BEA reports net stocks and investment flows. Everything else is derived. The retirement pattern — the distribution of asset lifetimes around a mean — must be assumed.

Three families of assumptions have been used in the literature:

1. **Simultaneous exit (SE):** All assets retire exactly at age T. Widely recognized as the most unrealistic assumption (Blades 2001; Nomura 2005).
2. **Geometric (infinite lives):** Assets never fully retire. Adopted by BEA post-1997 (Fraumeni 1997). Makes gross stock computation impossible.
3. **Bell-shaped distributions:** Retirements distributed around mean service life T̄. Used by BEA pre-1997 and by Shaikh (2016) via ADJ1.

Dataset 2 uses the **Weibull distribution** — a flexible two-parameter family that nests the exponential (α = 1) and approximates the Winfrey S-3 bell-shaped curve for α ∈ [1.5, 3.5].

## 1.2 The Weibull distribution — complete formalization

Let τ denote the age of an asset cohort. The Weibull distribution is parameterized by:
- **α > 0:** shape parameter (governs the hazard profile)
- **λ > 0:** scale parameter (governs the spread of the distribution)

**Probability density function:**
$$f(\tau) = \alpha \lambda^{-\alpha} \tau^{\alpha - 1} \exp\left[-\left(\frac{\tau}{\lambda}\right)^\alpha\right]$$

**Survival function** (fraction still in service at age τ):
$$S(\tau) = \exp\left[-\left(\frac{\tau}{\lambda}\right)^\alpha\right]$$

**Hazard function** (instantaneous retirement rate at age τ):
$$h(\tau) = \frac{\alpha}{\lambda}\left(\frac{\tau}{\lambda}\right)^{\alpha - 1}$$

**Mean service life:**
$$\bar{T} = \lambda \cdot \Gamma\left(1 + \alpha^{-1}\right)$$

**Scale parameter derived from mean service life L and shape α:**
$$\lambda = \frac{L}{\Gamma(1 + \alpha^{-1})}$$

This is the operational formula: L and α are inputs; λ is derived.

## 1.3 Shape parameter interpretation

| α range | Hazard profile | Interpretation |
|---------|---------------|----------------|
| α < 1 | Decreasing | "Infant mortality" — implausible for physical capital |
| α = 1 | Constant | Exponential — geometric depreciation special case |
| 1 < α < 2.6 | Regressively increasing | Risk rises at decreasing rate. Right-skewed. Most physical assets. |
| α ≈ 2.6–3.7 | Approximately symmetric | Approximates Winfrey S-3 curve |
| α > 3.7 | Negatively skewed | Tight clustering near mean service life |

## 1.4 The GPIM retirement recursion

The gross real stock evolves as:
$$K^{GR}_{i,t} = IG^R_{i,t} + (1 - \rho_{i,t}) \cdot K^{GR}_{i,t-1}$$

where $\rho_{i,t}$ is the period-t aggregate retirement rate, computed as the Weibull hazard evaluated at the investment-weighted mean age of the stock:

$$\rho_{i,t} = h(\bar{\tau}_{i,t}) = \frac{\alpha_i}{\lambda_i}\left(\frac{\bar{\tau}_{i,t}}{\lambda_i}\right)^{\alpha_i - 1}$$

**rho_t is time-varying.** $\bar{\tau}_{i,t}$ is tracked via the mean-age recursion at every period (see §1.6). The retirement rate is recomputed annually — it is not a scalar constant.

## 1.5 Log-linear estimation of Weibull parameters

Following Nomura (2005), the cumulative hazard function has a log-linear form:
$$\ln H(\tau) = \beta + \alpha \ln \tau$$

where β = −α ln λ. This makes OLS on observed discard data straightforward. Nomura (2005) uses this to estimate (α, λ) per asset class from the 2002-SASD survey.

## 1.6 Mean-age recursion and initialization — CORRECTED 2026-03-27

**The balanced-growth problem:** The standard initialization $\bar{\tau}_0 = L/2$ asserts a balanced-growth ergodic vintage distribution — it assumes the stock is already in the steady state it would reach under constant investment growth. This is the closure the unbalanced growth framework rejects.

**Correct initialization under GPIM + unbalanced growth:**

Cold start at 1901: $\bar{\tau}_{1901} = 0$, $K^{GR}_{1901} = 0$.

Mean-age recursion during warmup (1901–1924):
$$\bar{\tau}_{t+1} = \frac{\bar{\tau}_t \cdot (1 - \rho_t) \cdot K^{GR,R}_t}{(1 - \rho_t) \cdot K^{GR,R}_t + IG^R_t} + 1$$

Survivors age 1 year; new investment enters at age 0 and dilutes $\bar{\tau}$ proportional to its share. $\rho_t$ is itself time-varying during warmup — computed from $\bar{\tau}_t$ at each step.

`warmup_from_investment()` returns both $K^{GR,R}_{1925}$ and $\bar{\tau}_{1925}$. Post-warmup recursion initializes from $\bar{\tau}_{1925}$ — the historically accumulated age distribution from 24 years of actual investment flows.

$L/2$ fallback only used when warmup data is unavailable (documented, never hit in practice with `USE_1901_WARMUP = TRUE`).

## 1.7 p_lag boundary assumption — 2026-03-27

The current-cost recursion:
$$K_t = IG_t + z^*_t \cdot K_{t-1} \quad \text{where} \quad z^*_t = (1 - z_t)\frac{p^K_t}{p^K_{t-1}}$$

requires $p^K_{t-1}$ at the first observation year (1925). Since BEA chain-type quantity indexes begin in 1925, $p^K_{1924}$ does not exist. The pipeline sets $p^K_{1924} = p^K_{1925}$, implying zero price change at the 1924–1925 boundary.

**This is not an equilibrium assumption.** It is a boundary condition imposed by data availability.

The initialization error propagates as:
$$\Delta K_t = \Delta K_0 \cdot \prod_{s=1}^{t} z^*_s$$

contracting each period by $z^*_s$. Since $z^*_s < 1$ holds when $z_s > g_{p^K,s}/(1 + g_{p^K,s})$ — confirmed for the US corporate sector across the full sample — the error converges to zero. **No constant convergence rate can be stated without imposing balanced growth.** Under the unbalanced growth framework, the contraction rate is itself time-varying, governed by the historical sequence of $z^*_t$ values. The error is negligible within the estimation window (1947–2024).

---

# 2. Three Sources for Parameterization

## 2.1 Source 1 — Shaikh (2016) ADJ1: BEA 1993 Finite Service Lives

BEA published *Fixed Reproducible Tangible Wealth in the United States, 1925–89* in 1993. Shaikh (2016, Appendix 6.7) reinstates the pre-1997 BEA methodology via ADJ1.

**Implicit L recovered from Shaikh:**

$T_{\text{implicit}} = 1/z_{SL}$. From Shaikh Appendix Figure 6.7.5, aggregate BEA 1993 corporate depreciation rate z ≈ 0.062 → T_implicit ≈ 16 yr (mix-weighted aggregate).

Decomposed:
- Structures: z ≈ 0.033–0.040 → T ≈ 25–30 yr
- Equipment: z ≈ 0.070–0.100 → T ≈ 10–14 yr
- Gov transport: not in Shaikh corporate scope

**What Shaikh gives:** Implicit L for structures and equipment. No α parameter.

**Key reference:** Shaikh, A. (2016). *Capitalism: Competition, Conflict, Crises.* Oxford University Press. Appendix 6.7–6.8.

## 2.2 Source 2 — Fraumeni (1997): BEA Post-1997 Geometric Depreciation Rates

Fraumeni (1997) Table 3 documents service lives T used in the pre-1997 BEA methodology.

**NF corporate structures:**

| Asset | T (yr) | δ | R |
|-------|--------|---|---|
| Industrial buildings | 31 | 0.0314 | 0.9747 |
| Office buildings | 36 | 0.0247 | 0.8892 |
| Commercial warehouses | 40 | 0.0222 | 0.8892 |
| Other commercial buildings | 34 | 0.0262 | 0.8892 |
| All other nonfarm buildings | 38 | 0.0249 | 0.8990 |

Investment-weighted average: **T ≈ 36 yr**

**NF corporate equipment:**

| Asset | T (yr) | δ | R |
|-------|--------|---|---|
| General industrial equipment | 16 | 0.1072 | 1.7150 |
| Farm tractors | 14 | 0.1452 | 2.0330 |
| Construction tractors | 10 | 0.1550 | 1.5498 |
| Agricultural machinery | 14 | 0.1179 | 1.6500 |
| Trucks/buses | 9–14 | 0.12–0.17 | 1.7252 |

Investment-weighted average: **T ≈ 14 yr**

**Government nonresidential structures:**

| Asset | T (yr) | δ | R |
|-------|--------|---|---|
| Highways and streets | 60 | 0.0152 | 0.9100 |
| Air transportation | 50 | 0.0182 | 0.9100 |
| Conservation and development | 60 | 0.0152 | 0.9100 |
| Other government nonresidential | 60 | 0.0152 | 0.9100 |

Government transportation weighted average: **T ≈ 58–60 yr**

**What Fraumeni gives:** L for all accounts. No α parameter.

**Key reference:** Fraumeni, B.M. (1997). The Measurement of Depreciation in the U.S. National Income and Product Accounts. *Survey of Current Business*, July, 7–23.

## 2.3 Source 3 — Nomura (2005): Empirically Estimated Weibull Parameters

Japan ESRI 2002-SASD survey: directly observed scrapping events, 66 asset categories. Log-linear cumulative hazard estimation. Case-3 (bias-adjusted value weights) is preferred.

**Structures (Nomura assets 60–66):**

| Asset | α Case-1 | T̄ Case-1 | α Case-3 | T̄ Case-3 |
|-------|----------|----------|----------|----------|
| Storehouses (61) | 1.62 | 17.7 | 1.72 | 39.9 |
| Office buildings (62) | 1.47 | 15.6 | 1.81 | 24.9 |
| Factories (64) | 1.56 | 17.8 | 1.69 | 29.4 |
| Road and parking areas (65) | 1.29 | 11.7 | 1.28 | 19.8 |

Non-residential weighted average: **α ≈ 1.6, T̄ ≈ 25–30 yr (Case-3)**

**Equipment / general machinery (Nomura assets 13–33):**

| Asset | α Case-1 | T̄ Case-1 | α Case-3 | T̄ Case-3 |
|-------|----------|----------|----------|----------|
| Metal machine tools (14) | 1.67 | 17.7 | 2.12 | 18.4 |
| Metal processing machinery (15) | 1.29 | 14.9 | 1.61 | 19.9 |
| Construction machinery (18) | 1.39 | 11.3 | 1.82 | 15.0 |
| Chemical machinery (21) | 1.36 | 14.0 | 1.91 | 29.4 |

General machinery weighted average: **α ≈ 1.7, T̄ ≈ 14–20 yr (Case-3)**

**Roads (Nomura asset 65):** α = 1.28 (Case-3), T̄ = 19.8 yr

> ⚠️ **Cross-country caveat:** Nomura's road T̄ reflects Japanese urban road replacement cycles. US highway design life ≈ 60 yr (AASHTO). Retain Fraumeni T = 60 yr for US; retain Nomura α = 1.3 for shape.

**What Nomura gives:** α for all accounts. T̄ for structures and equipment consistent with Fraumeni; T̄ for roads NOT applicable to US.

**Key reference:** Nomura, K. (2005). Duration of Assets: Examination of Directly Observed Discard Data in Japan. *KEO Discussion Paper No. 99.* Keio Economic Observatory / ESRI.

---

# 3. Three-Source Triangulation and Final Parameter Decision

## 3.1 Source contribution matrix

| Source | Provides L? | Provides α? | Gov transport? | Key limitation |
|--------|------------|------------|----------------|----------------|
| Shaikh ADJ1 | Yes (implicit) | No | No | Mix-weighted; no shape param |
| Fraumeni (1997) | Yes (explicit) | No | Yes (T=60yr) | Geometric framework; no retirement dist. |
| Nomura (2005) | Yes (T̄) | Yes (direct fit) | Warning (Japan roads) | Cross-country transferability |

## 3.2 Cross-source comparison

| Account | Fraumeni L | Shaikh implicit L | Nomura T̄ (C3) | Nomura α (C3) | Decision |
|---------|-----------|------------------|--------------|---------------|---------|
| NF corporate structures | 36 yr | ~25–30 yr | ~25–30 yr | ~1.6 | **L=30, α=1.6** |
| NF corporate equipment | 14 yr | ~10–14 yr | ~14–20 yr | ~1.7 | **L=14, α=1.7** |
| Gov transportation | 60 yr | N/A | 12–20 yr (Japan) | ~1.3 | **L=60, α=1.3** |

## 3.3 Locked parameter table

| Account | L (yr) | α | λ = L/Γ(1+α⁻¹) | Primary source |
|---------|--------|---|----------------|----------------|
| NF corporate structures | **30** | **1.6** | 30/Γ(1.625) ≈ 33.0 | Fraumeni T, Shaikh implicit, Nomura α |
| NF corporate equipment | **14** | **1.7** | 14/Γ(1.588) ≈ 15.3 | All three sources consistent |
| Gov transportation | **60** | **1.3** | 60/Γ(1.769) ≈ 68.4 | Fraumeni T (US design life), Nomura α |

Γ values: Γ(1.625) ≈ 0.909; Γ(1.588) ≈ 0.914; Γ(1.769) ≈ 0.877.

> **Note on NF_corp in Dataset 2:** FAAt601 (Section 6) is legal form only — no E/S/IPP sub-line breakdown under Nonfinancial corporate is available from any single BEA table. The pipeline uses the NF corporate aggregate with a single mix-weighted (L, α) pair. The locked parameters above (L=30 structures, L=14 equipment) inform the aggregate L=22 used in `10_config.R` as an investment-weighted average. This is a known approximation.

## 3.4 Toggle architecture in 10_config.R

```r
USE_WEIBULL_RETIREMENT   <- TRUE    # Option B: Weibull (L, alpha) — canonical
USE_SHAIKH_BEA1993_RATES <- FALSE   # Option A: Shaikh BEA 1993 aggregate rates — sensitivity

WEIBULL_PARAMS <- list(
  structures    = list(L = 30, alpha = 1.6),
  equipment     = list(L = 14, alpha = 1.7),
  gov_transport = list(L = 60, alpha = 1.3)
)
```

---

# 4. Future Extensions (Parked/Flagged)

## 4.1 Time-varying service lives — PARKED

L(t) and α(t) as functions of observable proxies. Equipment: L(t) proxied by ICT share of investment. Structures: L(t) proxied by commercial RE price cycles. Requires vintage-level capital stock tracking.

## 4.2 Sub-asset Weibull heterogeneity — PARKED

Single (L, α) per account replaced by investment-share-weighted average of sub-type parameters from Fraumeni Table 3 + Nomura. Makes ρ_t endogenously time-varying from asset composition.

## 4.3 US-specific retirement data — FLAGGED

No equivalent US SASD survey exists. Closest: Oliner (1996), Powers (1988), OTA studies (1990, 1991). Replace Nomura α with US estimates where available.

## 4.4 IPP sub-component parameterization — PARKED

| IPP sub-type | L (yr) | α | Source |
|---|---|---|---|
| Prepackaged software | 3 | 2.5 | Fraumeni; Nomura asset 38 |
| Custom/own-account software | 5 | 2.0 | BEA assumption; Oliner (1992) |
| Business R&D | 8 | 1.5 | Nadiri & Prucha (1996) |
| Entertainment originals | 10 | 1.5 | BEA assumption |

## 4.5 Government transportation sub-type decomposition — FLAGGED

Single account (L=60, α=1.3) could be split by transport mode using Table 7.5 investment shares. Relevant for post-1956 Interstate Highway buildout and post-1980 airport expansion shift.

## 4.6 GPIM error propagation under unbalanced growth — BRANCH OPEN

The standard half-life formula (τ_half = ln(2)/ln(1/z*)) requires constant z* — a balanced-growth assumption. Under unbalanced growth the correct propagation is ΔK_t = ΔK_0 · ∏ z*_s. Characterizing convergence bounds without imposing balanced growth is an open methodological question. See stub page in Notion.

---

# 5. Key References

- **Shaikh, A. (2016).** *Capitalism: Competition, Conflict, Crises.* Oxford University Press. Appendix 6.7–6.8.
- **Fraumeni, B.M. (1997).** The Measurement of Depreciation in the U.S. National Income and Product Accounts. *Survey of Current Business*, July, 7–23.
- **Nomura, K. (2005).** Duration of Assets: Examination of Directly Observed Discard Data in Japan. *KEO Discussion Paper No. 99.* Keio Economic Observatory / ESRI.
- **Hulten, C.R. and Wykoff, F.C. (1981b).** The Measurement of Economic Depreciation. In Hulten (ed.), *Depreciation, Inflation, and the Taxation of Income from Capital.* Urban Institute Press, 81–125.
- **Meinen, G., Verbiest, P., and Wolf, P.P. (1998).** Perpetual Inventory Method — Service lives, Discard Patterns and Depreciation Methods. Canberra Group on Capital Stock Statistics.
- **Winfrey, R. (1967).** Statistical Analysis of Industrial Property Retirements. Bulletin 125, Revised. Iowa Engineering Research Institute.
- **Blades, D. (2001).** Measuring Capital. OECD Manual.
- **Bureau of Economic Analysis (1993).** *Fixed Reproducible Tangible Wealth in the United States, 1925–89.* U.S. GPO.
- **Nadiri, M.I. and Prucha, I.R. (1996).** Estimation of the Depreciation Rate of Physical and R&D Capital in U.S. Manufacturing. *Economic Inquiry*, 24, 43–56.
- **Powers, S.G. (1988).** The Role of Capital Discards in Multifactor Productivity Measurement. *Monthly Labor Review*, June, 27–35.
