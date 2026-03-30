# Methodological Brief — Chapter 3 Critical Replication

## Overview

This pipeline implements a three-stage informational robustness analysis of
Shaikh's (2016, Table 6.7.14) capacity utilization estimation for the US
corporate sector, 1947–2011. The core economic relationship is the long-run
cointegrating regression between real log output (lnY) and real log capital
(lnK), from which the capital-output ratio θ and derived capacity utilization
series u_hat are recovered.

The three stages progressively expand the specification space:

| Stage | Method | Specifications | Purpose |
|-------|--------|---------------:|---------|
| S0 | ARDL(2,4) — PSS bounds | 5 (cases 1–5) | Faithful replication of Shaikh's published result |
| S1 | ARDL lattice — PSS bounds | 500 | Specification geometry and informational robustness |
| S2 | Johansen VECM — trace test | 144 (48 + 96) | System-based cointegration cross-validation |

---

## Stage 0: Faithful ARDL Replication

### Economic Model

The long-run equilibrium is:

    lnY_t = a + θ · lnK_t + Σ c_j · d_j(t) + u_t

where θ is the capital-output elasticity (capacity utilization parameter),
d_j are structural break dummies at 1956, 1974, and 1980, and u_t is the
equilibrium error. The target values from Shaikh Table 6.7.14 are:
θ = 0.6609, a = 2.1782, c_d74 = −0.8548.

### Estimation

- **Method**: Pesaran, Shin & Smith (2001) ARDL bounds testing
- **Lag structure**: ARDL(p=2, q=4) — 2 lags of lnY, 4 lags of lnK
- **Deterministic terms**: Swept across all 5 PSS cases:
  - Case 1: No intercept, no trend
  - Case 2: Restricted intercept, no trend
  - Case 3: Unrestricted intercept, no trend
  - Case 4: Unrestricted intercept, restricted trend
  - Case 5: Unrestricted intercept, unrestricted trend
- **Software**: R package `ARDL` (Natsiopoulos & Tserkezos)

### Admissibility Gate

- **F-bounds test**: Joint significance of the lagged-level terms. The model
  passes if the F-statistic exceeds the upper bound at the 10% level
  (p-value < 0.10).
- **t-bounds test** (cases 3, 5): Individual significance of the
  error-correction term.

### Key Outputs

- Long-run multipliers (θ, a, dummy coefficients) with delta-method SEs
- Capacity utilization series: u_hat = exp(lnY − a − θ·lnK − Σ c_j·d_j)
- Potential output: Y_p = exp(a + θ·lnK + Σ c_j·d_j)

### Shock Type Toggle

Break dummies at 1956, 1974, 1980 can be configured as:
- **Permanent** (step): d_j(t) = 1{t ≥ year_j} — institutional regime shift
- **Transitory** (impulse): d_j(t) = 1{t = year_j} — one-time shock

Controlled by `CONFIG$SHOCK_TYPE` in `10_config.R`. The permanent specification
corresponds to Shaikh's original formulation.

---

## Stage 1: ARDL Specification Geometry

### Specification Grid

S1 expands the single ARDL(2,4) to a full 500-specification lattice:

| Dimension | Values | Count |
|-----------|--------|------:|
| AR lags (p) | 1, 2, 3, 4, 5 | 5 |
| DL lags (q) | 1, 2, 3, 4, 5 | 5 |
| PSS case | 1, 2, 3, 4, 5 | 5 |
| Dummy subset (s) | s0={}, s1={d74}, s2={d56,d74}, s3={d56,d74,d80} | 4 |
| **Total** | | **500** |

Each specification is estimated as a standalone ARDL(p,q) model with
the PSS bounds testing procedure applied.

### Admissibility Gate

A specification is **admissible** if the F-bounds test rejects the null of
no levels relationship at the 10% significance level.

### Information Criteria

Five information criteria are computed for each admissible specification:

| Criterion | Formula | Reference |
|-----------|---------|-----------|
| AIC | −2ℓ + 2k | Akaike (1974) |
| BIC | −2ℓ + k·ln(T) | Schwarz (1978) |
| HQ | −2ℓ + 2k·ln(ln(T)) | Hannan & Quinn (1979) |
| ICOMP | −2ℓ + 2·C₁(Σ̂) | Bozdogan (1990) |
| ICOMP_Misspec | −2ℓ + 2·C₁(Σ̂_HC) | Bozdogan (2016) |

where C₁(Σ̂) is the maximum-entropy complexity of the estimated covariance
matrix, and Σ̂_HC is the heteroskedasticity-consistent (HC3) covariance.
ICOMP penalizes both the number and interdependence of parameters.

### Frontier Construction

The **F^(0.20) fattened frontier** selects the bottom 20% of admissible
specifications by AIC. This "fattened" (as opposed to single-point) frontier
captures the informational neighborhood of the best-fitting models, providing
a robustness band for θ and u_hat rather than a single point estimate.

### Key Outputs

- Full lattice: 500 rows with all IC values, θ, α, F-test results
- Admissible set: specifications passing the F-bounds gate
- F^(0.20) frontier: the informational core
- Theta distribution and utilization band across the frontier
- IC winners: the specification minimizing each of the 5 criteria

---

## Stage 2: Johansen VECM System Identification

### Economic Motivation

S2 re-estimates the cointegrating relationship using the Johansen (1991)
maximum-likelihood VECM framework. This provides a system-based
cross-validation of the single-equation ARDL results from S0/S1. The VECM
treats all variables as endogenous and jointly estimates the cointegrating
vector(s) and adjustment parameters.

### Model Structure

The VECM representation is:

    ΔX_t = Π·X_{t-1} + Σ Γ_i·ΔX_{t-i} + Φ·D_t + ε_t

where Π = α·β' has reduced rank r (the cointegration rank), β contains the
cointegrating vectors, and α the adjustment (loading) coefficients.

### Two Systems

#### Bivariate (m=2)

- **State vector**: X_t = (lnY, lnK)'
- **Grid**: p ∈ {1,2,3,4} × d ∈ {d0,d1,d2,d3} × h ∈ {h0,h1,h2}
- **Rank**: r = 1 (one cointegrating vector)
- **Total specifications**: 4 × 4 × 3 = 48

The `d` dimension controls which step dummies enter: d0 = none, d1 = {d74},
d2 = {d56, d74}, d3 = {d56, d74, d80}. The `h` dimension controls the
deterministic specification: h0 = no constant in cointegrating equation,
h1 = restricted constant, h2 = restricted constant + restricted trend.

#### Trivariate (m=3)

- **State vector**: X_t = (lnY, lnK, e)' where e = exploitation rate
- **Grid**: p ∈ {1,2,3,4} × d ∈ {d0,d1,d2,d3} × h ∈ {h0,h1,h2} × r ∈ {1,2}
- **Total specifications**: 4 × 4 × 3 × 2 = 96

The trivariate system adds the exploitation rate to test the classical
political economy hypothesis that profitability conditions feed back into
capital accumulation and capacity utilization.

### Triple Admissibility Gate

A VECM specification must pass all three gates to be admissible:

1. **Convergence**: The Johansen ML algorithm must converge without error.
2. **Rank consistency**: The Johansen trace test must support the assumed
   rank r at the 5% significance level. Specifically, the trace test must
   reject H₀: rank = r−1 and fail to reject H₀: rank = r.
3. **Companion-matrix stability**: All eigenvalues of the companion matrix
   must lie inside the unit circle (modulus < 1), ensuring the VECM is
   dynamically stable.

### Omega_20 Frontier

Analogous to S1's F^(0.20), the **Omega_20 frontier** selects the bottom
20% of admissible specifications by −2·log-likelihood (neg2logL). This
identifies the informational core of the VECM specification space.

### P8 Rotation Diagnostic (m=3, r=2 only)

For trivariate specifications with rank r=2, the pipeline applies the P8
rotation diagnostic: regress the exploitation rate e on estimated capacity
utilization u_hat from the first cointegrating vector. The reserve-army
hypothesis predicts λ < 0 (higher utilization depresses the exploitation
rate through labor market tightening). Sign consistency is recorded for
each r=2 specification.

### Theta Recovery

From the normalized cointegrating vector β = (1, −θ, ...)':

    lnY = θ·lnK + ...

θ is recovered as the negative of the lnK coefficient in the normalized
first cointegrating vector. Capacity utilization is then:

    u_hat = exp(lnY − θ·lnK − deterministic terms)

### Key Outputs

- Full lattice (48 + 96 specs) with convergence, rank, stability diagnostics
- Admissible sets for m=2 and m=3
- Omega_20 frontiers with θ distributions and utilization bands
- IC winners (AIC, BIC, HQ, ICOMP) for each system
- Rotation check table for r=2 trivariate specs

---

## Cross-Stage Synthesis

The pack script (80_pack_ch3_replication.R) reads all public CSVs from
S0/S1/S2 and produces:

- **TAB_CROSS_theta_comparison**: θ estimates across all stages for direct
  comparison of the single-equation and system-based approaches
- **fig_CROSS_synthesis**: Visual synthesis of the three-stage results

This cross-stage comparison is the core deliverable of the informational
robustness exercise: if θ is stable across the ARDL and VECM specification
spaces, the capacity utilization estimate is informationally robust.

---

## Software and Reproducibility

| Component | Version/Package |
|-----------|----------------|
| ARDL estimation | R package `ARDL` (Natsiopoulos & Tserkezos) |
| VECM estimation | R package `tsDyn` (Di Narzo, Aznarte, Stigler) |
| Johansen trace test | R package `urca` (Pfaff) |
| Information criteria | Custom `98_ardl_helpers.R` (ICOMP via Bozdogan 1990) |
| Pipeline orchestration | `24_manifest_runner.R` with manifest audit trail |
| Seed | 123456 (fixed for all stochastic operations) |
| Sample | 1947–2011 (T = 65 observations, 61 effective after differencing) |

---

## References

- Akaike, H. (1974). A new look at the statistical model identification. *IEEE Trans. Automatic Control*, 19(6).
- Bozdogan, H. (1990). On the information-based measure of covariance complexity and its application to the evaluation of multivariate linear models. *CSDA*, 9(2).
- Bozdogan, H. (2016). Information complexity and multivariate learning. In *Springer Handbook of Computational Statistics*.
- Hannan, E.J. & Quinn, B.G. (1979). The determination of the order of an autoregression. *JRSS-B*, 41(2).
- Johansen, S. (1991). Estimation and hypothesis testing of cointegration vectors in Gaussian vector autoregressive models. *Econometrica*, 59(6).
- Pesaran, M.H., Shin, Y. & Smith, R.J. (2001). Bounds testing approaches to the analysis of level relationships. *JASA*, 16(3).
- Schwarz, G. (1978). Estimating the dimension of a model. *Annals of Statistics*, 6(2).
- Shaikh, A. (2016). *Capitalism: Competition, Conflict, Crises*. Oxford University Press.
