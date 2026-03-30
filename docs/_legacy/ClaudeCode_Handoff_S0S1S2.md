# Claude Code Handoff: Chapter 3 Critical Replication — S0/S1/S2
## Consolidated Implementation Package
## Version: v2 (2026-03-11) — All sessions through IC audit
## UMass Heterodox Macroeconomics | Dissertation Chapter 3

---

## HOW TO USE THIS DOCUMENT

This is a single self-contained handoff for Claude Code. It has three parts:

- **PART I — ARCHITECTURAL REDESIGN** (Preamble): repo structure, repair sequence, design principles
- **PART II — FILE TRIAGE**: disposition of every existing R file, with what to keep/absorb/obliterate
- **PART III — MODEL SPEC**: full S0/S1/S2 implementation spec with code templates, locked decisions, and package notes

Read all three parts before touching any file. Execute Part I repair sequence first,
then implement Part III model spec. Part II governs what to preserve from existing files.

**Companion files to upload alongside this document:**
- All 12 existing R files (as context — do not execute, read first)
- `report_brief_ShaikhCI.pdf` (Shaikh canonical values reference)

---

# Claude Code Handoff: Repo Redesign + S0/S1/S2 Implementation
## Critical Replication Pipeline — Architectural Redesign v2
## Date: 2026-03-11

---

## PART A: ARCHITECTURAL REDESIGN

### A.1 Design Principles

1. The `20`-series is exclusively for Shaikh's critical replication (S0/S1/S2).
   No packaging logic, no manifest writing, no schema repair inside these scripts.
2. All shared helpers live in `99_utils.R` (general R utilities: I/O, logging,
   path helpers) and `98_ardl_helpers.R` (ARDL/VECM/envelope-specific logic).
   The `20`-series scripts source helpers; they do not define them.
3. A separate results wrapper (`80_pack_ch3_replication.R`) consumes declared
   public outputs from the `20`-series and builds all paper-facing tables and
   figures for Chapter 3. Strict consumer: CONTRACT ERROR on missing input,
   no fallbacks, no heuristic discovery.
4. `24_manifest_runner.R` is the sole orchestrator and sole manifest writer
   for the `20`-series. No stage script writes to the manifest.
5. `26_crosswalk_tables.R` is OBLITERATED. The crosswalk was an attempt to
   reduce S1 ARDL and S2 VECM to a single-dimensional comparison metric.
   The three-stage architecture makes this unnecessary: S0/S1/S2 outputs are
   compared directly through their tracked objects (theta, u_hat, beta, alpha),
   not through a collapsed crosswalk.
6. The `30`-series is reserved for the reduced-rank VECM (Chapter 4).
   Do not create any `30`-series files now.

### A.2 Target File Structure

```
codes/
  10_config.R                    ← unchanged: paths, global params
  99_utils.R                     ← general helpers: I/O, logging, path utils
  98_ardl_helpers.R              ← NEW: ARDL/VECM/envelope/complexity helpers
                                    Absorbs logic from 24_ and 25_
                                    Sources: tsDyn (VECM, lineVar), urca (ca.jo),
                                             ARDL package (bounds tests)

  # --- SHAIKH CRITICAL REPLICATION (20-series) ---
  20_S0_shaikh_faithful.R        ← S0: fixed-spec ARDL(2,4) faithful replication
  21_S1_ardl_geometry.R          ← S1: full ARDL lattice + fattened frontier
  22_S2_vecm_bivariate.R         ← S2 m=2: bivariate VECM system
  23_S2_vecm_trivariate.R        ← S2 m=3: trivariate VECM + rotation check

  # --- ORCHESTRATION ---
  24_manifest_runner.R           ← sole runner + sole manifest writer for 20-series

  # --- RESULTS PACKAGING ---
  80_pack_ch3_replication.R      ← consumes public outputs from 20-23,
                                    builds all paper-facing tables and figures
                                    for Chapter 3. Strict consumer, no fallbacks.

  # --- OBLITERATED ---
  # 24_complexity_penalties.R    → absorbed into 98_ardl_helpers.R
  # 25_envelope_tools.R          → absorbed into 98_ardl_helpers.R
  # 26_crosswalk_tables.R        → OBLITERATED (crosswalk architecture dropped)
  # 27_run_stage4_all.R          → renamed + redesigned as 24_manifest_runner.R
  # 28_pack_ARDL_ShaikhRep...    → replaced by 80_pack_ch3_replication.R
  # 29_pack_VECM_S1_deep.R       → replaced by 80_pack_ch3_replication.R

  # --- FUTURE (Chapter 4, do not create now) ---
  # 30_S3_reduced_rank_vecm.R
  # 31_...
  # 85_pack_ch4_reduced_rank.R

output/
  CriticalReplication/
    S0_faithful/
      csv/
        S0_spec_report.csv           ← LR coefficients, IC, diagnostics at m0
        S0_utilization_series.csv    ← u_hat, yp_hat, year (annual)
        S0_fivecase_summary.csv      ← five-case RMSE + IC comparison
      figures/                       ← diagnostic figures (not paper-ready)
    S1_geometry/
      csv/
        S1_lattice_full.csv          ← full 500-spec grid
        S1_admissible.csv            ← A_S1: specs passing F-bounds gate
        S1_frontier_F020.csv         ← F^(0.20): bottom 20% AIC admissible
        S1_frontier_u_band.csv       ← pointwise u_hat band across F^(0.20)
        S1_frontier_theta.csv        ← theta distribution across F^(0.20)
    S2_vecm/
      csv/
        S2_m2_admissible.csv         ← A_S2 for m=2
        S2_m2_omega20.csv            ← Omega_20 for m=2
        S2_m3_admissible.csv         ← A_S2 for m=3
        S2_m3_omega20.csv            ← Omega_20 for m=3
        S2_rotation_check.csv        ← rotation admissibility (see A.4)
    ResultsPack/
      tables/
      figures/
    Manifest/
      RUN_MANIFEST_ch3.md            ← written by 24_manifest_runner.R only
      logs/
```

### A.3 Helper file strategy

`98_ardl_helpers.R` owns:
- Complexity metrics: `compute_complexity_record()` with canonical column names
  (`k_total`, `ICOMP`, `ICOMP_Misspec`). No alias columns. Ever.
- Envelope tools: admissibility gate functions, frontier extraction, band computation
- Bounds test wrappers around `ARDL::bounds_f_test()` and `ARDL::bounds_t_test()`
- IC contour geometry for fit-complexity plane
- VECM triple admissibility gate (convergence + rank + companion stability)
- tsDyn wrappers: `VECM()` for restricted estimation, `lineVar()` for unrestricted VAR
- Rotation check function (see A.4)

`99_utils.R` owns:
- File I/O helpers (read/write CSV with schema validation)
- Path construction utilities
- Logging helpers
- CONTRACT ERROR utility:
  ```r
  assert_file <- function(path) {
    if (!file.exists(path))
      stop("CONTRACT ERROR: expected file not found: ", path)
    invisible(path)
  }
  ```

### A.4 Rotation check admissibility criterion

This governs `S2_rotation_check.csv` and applies to all specs in `Omega_20_m3`
with `r = 2`.

**Theoretical basis (from P8 + theoretical estimation blueprint):**

The two cointegrating vectors recovered from the Johansen canonical correlation
decomposition are unidentified rotations. Separating the capacity transformation
relation from the reserve-army relation requires imposing the rotation prior:

```
e_t = μ + λ * û_t + Σ_h κ_h * DM_{h,t},    λ < 0
```

where `û_t = y_t - θ̂*k_t - â` is the capacity utilization residual from the
first cointegrating relation, and `e_t = log(Profshcorp_t)`.

**Transmission chain that licenses λ < 0:**

1. Okun closure: `g_u = λ_O * g_v` — rising utilization raises the employment rate
2. Phillips/distributive conflict: `v_t ↑ → ω_t ↑` — tighter labor markets raise
   the wage share
3. Exploitation rate: `e_t = (1 - ω_t)/ω_t → e_t ↓` when `ω_t ↑`

Therefore: `u_t ↑ → v_t ↑ → ω_t ↑ → e_t ↓`, which implies `λ < 0`.

This is not a Johansen restriction. It is the economic prior that disciplines
the canonical rotation. It must be satisfied empirically as a sign restriction
on the OLS estimate of λ. The reduced-rank VECM in Chapter 4 supplies the
structural completion that S2 approximates.

**Implementation in `23_S2_vecm_trivariate.R`:**

```r
# For each spec in Omega_20_m3 with r=2:
rotation_check <- function(spec, df) {
  # û_t from first cointegrating vector (capacity transformation relation)
  u_resid <- spec$coint_resids[, 1]

  # Rotation prior regression
  rot_df <- data.frame(e = df$e, u_hat = u_resid,
                       d56 = df$d56, d74 = df$d74, d80 = df$d80)
  lm_rot <- lm(e ~ u_hat + d56 + d74 + d80, data = rot_df)

  lambda     <- coef(lm_rot)["u_hat"]
  lambda_se  <- sqrt(vcov(lm_rot)["u_hat", "u_hat"])
  lambda_t   <- lambda / lambda_se
  lambda_p   <- pnorm(lambda_t)    # one-tailed p-value, H1: lambda < 0

  # NO admissibility gate on rotation at this stage.
  # All Omega_20_m3 specs with r=2 are passed through.
  # lambda, lambda_t, lambda_p are pure diagnostics — reported in
  # S2_rotation_check.csv for post-hoc inspection. Admissibility
  # criteria will be defined after reviewing empirical results.

  list(
    m = spec$m, r = spec$r, p = spec$p, d = spec$d, h = spec$h,
    lambda         = lambda,
    lambda_se      = lambda_se,
    lambda_t       = lambda_t,
    lambda_p       = lambda_p
    # rot_admissible: deferred — no gate defined at this stage
  )
}
```

**Output schema for `S2_rotation_check.csv`:**

| Column | Description |
|---|---|
| `m`, `r`, `p`, `d`, `h` | Specification tuple |
| `lambda` | Estimated coefficient on û_t in rotation regression |
| `lambda_se` | Standard error |
| `lambda_t` | t-statistic |
| `lambda_p` | One-tailed p-value, H1: λ < 0 |

**No admissibility gate on rotation at this stage.** All Omega_20_m3 specs
with r=2 are carried through. `lambda`, `lambda_t`, and `lambda_p` are
reported as pure diagnostics. Gate criteria will be defined after reviewing
empirical results and coefficient significance. The rotation check exists
to inform Chapter 4 reduced-rank restrictions, not to filter S2 output.

### A.5 tsDyn and lineVar

The `98_ardl_helpers.R` file should document the following function usage:

**VECM estimation (restricted):**
```r
library(tsDyn)
# VECM() for Johansen-restricted system with r cointegrating vectors
vecm_fit <- VECM(X, lag = p - 1, r = r,
                 estim = "ML",        # maximum likelihood
                 include = d_det,     # "none", "const", "trend"
                 exogen = dum_mat)    # dummy matrix or NULL
```

**Stability check via VAR companion matrix:**
```r
# VARrep() converts a fitted VECM to its VAR representation (tsDyn-native)
# companionMat() does NOT exist in tsDyn — do not use
var_mat <- VARrep(vecm_fit)        # returns VAR coefficient matrix
eig_mod <- Mod(eigen(var_mat)$values)
stable  <- all(eig_mod <= 1 + 1e-3)  # no explosive roots; tolerance for numerics
```

**Rank tests:**
```r
library(urca)
# ecdet must come from the d_branches lookup table — do NOT pass d_det string directly
# See §3.5 d_branches for the canonical (include, LRinclude, ecdet) mapping
jo <- ca.jo(X, type = "trace", ecdet = d$ecdet, K = p_lag, dumvar = dum_mat)
# ecdet="none"  → no restricted LR terms (Cases I, III, V)
# ecdet="const" → restricted constant in LR (Case II)
# K = VAR lag order = VECM lag + 1
```

**Flag for Claude Code**: The tsDyn/lineVar documentation and the ARDL package
vignette should be uploaded to the project knowledge base before implementing
`22_S2_vecm_bivariate.R` and `23_S2_vecm_trivariate.R`. Request these from the
user if not already in context.

---

## PART B: REPAIR SEQUENCE (execute in order)

### Step 1 — Absorb 24_ and 25_ into 98_ardl_helpers.R
Create `98_ardl_helpers.R`. Move all logic from `24_complexity_penalties.R`
and `25_envelope_tools.R` into it. Fix the alias collision: canonical names
only (`k_total`, `ICOMP`, `ICOMP_Misspec`). Delete alias-column additions from `21`.

### Step 2 — Obliterate 26_crosswalk_tables.R
Delete the file. Remove all references to it from `27_run_stage4_all.R`.

### Step 3 — Create 24_manifest_runner.R
Rename `27_run_stage4_all.R` → `24_manifest_runner.R`.
Update script registry to: `20_S0`, `21_S1`, `22_S2_m2`, `23_S2_m3`, `80_pack`.
Remove stage-local manifest appenders from `20`, `21`, `22`, `23`.
Make `24_manifest_runner.R` the sole manifest writer.

### Step 4 — Freeze public output filenames in 20_S0
Align `20_S0_shaikh_faithful.R` to write exactly:
- `S0_spec_report.csv`
- `S0_utilization_series.csv`
- `S0_fivecase_summary.csv`
No other outputs required by downstream.

### Step 5 — Create 80_pack_ch3_replication.R
Strict consumer of S0/S1/S2 public CSVs.
CONTRACT ERROR on any missing input. No fallbacks.

### Step 6 — Smoke test
```r
required <- c(
  "codes/10_config.R", "codes/99_utils.R", "codes/98_ardl_helpers.R",
  "codes/20_S0_shaikh_faithful.R", "codes/21_S1_ardl_geometry.R",
  "codes/22_S2_vecm_bivariate.R", "codes/23_S2_vecm_trivariate.R",
  "codes/24_manifest_runner.R", "codes/80_pack_ch3_replication.R"
)
missing <- required[!file.exists(required)]
if (length(missing) > 0) stop("SMOKE TEST FAILED: ", paste(missing, collapse=", "))
cat("All registered scripts present.\n")
```

---

## PART C: MODEL IMPLEMENTATION

After Steps 1–6 pass, implement the full model pipeline per `S0S1S2_CodePrompt_v1.md`.
All locked modeling decisions in that document apply unchanged.

---

## LOCKED ARCHITECTURAL DECISIONS

| Decision | Value |
|---|---|
| 20-series scope | Shaikh critical replication only (S0/S1/S2) |
| 24_ | `24_manifest_runner.R` — sole runner and manifest writer |
| 26_ | OBLITERATED — crosswalk architecture dropped |
| Helper ownership | `98_ardl_helpers.R` for ARDL/VECM logic; `99_utils.R` for general utils |
| Public output filenames | Fixed — see A.2. Never change without version bump |
| Fallback logic | Forbidden in packaging. CONTRACT ERROR on missing input |
| Rotation admissibility | DEFERRED — no gate. lambda reported as diagnostic only. Gate defined post-results. |
| Rotation theoretical prior | Okun → Phillips/distributive conflict → e_t ↓ when u_t ↑ |
| tsDyn functions | VECM() for restricted; lineVar() for unrestricted companion check |
| 30-series | Reserved for reduced-rank VECM Chapter 4. Do not create now |

---

_CodePrompt_Preamble_v2 | Session 5 | 2026-03-11_
_Supersedes: CodePrompt_Preamble_RepoRedesign_v1.md_
_Pair with: S0S1S2_CodePrompt_v1.md (model spec)_


---
---

# PART II — FILE TRIAGE

# Code Triage — Redesign Disposition
## S0/S1/S2 Pipeline | 2026-03-11

---

## Critical Discoveries (read before anything else)

### D1 — `compute_complexity_record` exists TWICE with different signatures
- `24_complexity_penalties.R`: takes `(model_class, logLik, k_total, vcov_mat, T_eff, extra)`
  — wraps ICOMP/ICOMP_Misspec computation
- `99_utils.R`: takes `(exercise, model_class, window, ..., ICOMP_pen, ICOMP_Misspec_pen, AIC, BIC, ...)`
  — is a row-builder that expects pre-computed IC values
- `21` sources `24_` version. `22` sources both — collision at runtime.
- **Resolution**: both go away. `98_ardl_helpers.R` gets ONE `make_spec_row()` function
  with signature `(p, q, case, s, logLik, k_total, T_eff, vcov_mat, sandwich_mat=NULL)`
  that computes AIC, BIC, HQ, ICOMP, ICOMP_Misspec (see §3.5 locked decisions for formulas).

### D2 — `ic_eta` in `23_VECM_S2.R` → DROP ENTIRELY

`ic_eta` is a custom parameterized criterion, not a formal IC. Drop it.
`ETA_GRID` drops with it. The IC uncertainty argument uses only the five
formal criteria: AIC, BIC, HQ, ICOMP, ICOMP_Misspec. These each select a
coordinate in (k, -2logL) space — that dispersion IS the H0 proof.
No custom eta-weighted penalties.

**Correction to earlier triage: ICOMP and ICOMP_Misspec are reinstated as formal ICs.
  NOTE: 'RICOMP' is not a standardized acronym in the literature (Bozdogan & Pamukçu 2016
  do not use it). The object is the misspecification-resistant ICOMP using the sandwich
  covariance estimator: ICOMP_Misspec = -2logL + 2*C1(F^{-1} R F^{-1}).**
They were tossed as envelope-plane axes (ICOMP_pen/ICOMP_Misspec_pen replacing k_total
on the x-axis of the fit-complexity plane). That's still dropped.
But ICOMP = -2*logL + 2*C1(F^{-1}) and ICOMP_Misspec = -2*logL + 2*C1(F^{-1} R F^{-1}) as per-spec scalar IC values
sitting alongside AIC/BIC/HQ in the tangency figure — those stay.
The C1(Σ) computation logic in `24_` is therefore still needed.

### D3 — Step dummies vs impulse dummies
`20_shaikh_ardl_replication.R` line 77: `as.integer(df$year >= yy)` → STEP dummies.
In ARDL levels, a step dummy D^step = I(t >= t_0) captures a PERMANENT level shift
in the capacity benchmark from t_0 onward. In ECM reparameterization, this is the
correct form for Shaikh's structural breaks (1956, 1974, 1980 are permanent shifts,
not one-year blips). The LR multipliers c_1=-0.855, c_2=-0.743, c_3=-0.478 are
permanent shift magnitudes. Step dummies are correct. The code prompt's earlier
mention of "impulse dummies" was wrong — keep step dummies as in `20`.

### D4 — `q_profiles_for_p` in `23` encodes S2 short-run memory allocation
```r
q_profiles_for_p(p) → tibble(q_tag, qY, qK, qE)
# sym: qY=qK=qE=p; Y_only: qK=qE=0; K_only: qY=qE=0; etc.
```
This is the `q` dimension of the S2 lattice — asymmetric short-run lag allocation
across state variables. Migrate to `98_ardl_helpers.R`. It replaces the vague
`q_tags` we had in the S2 lattice definition.

### D5 — `admissible_gate` in `99_utils.R` is from the old framework
It checks condition number (kappa) of the restricted design matrix. Not needed
for our triple gate (convergence + rank + stability). Archive, do not migrate.

### D6 — `basis_build_rawpowers_qr` etc. are Chapter 4 material
The polynomial exploitation rate basis (QR-orthogonalized powers of e).
Keep in `99_utils.R` but mark with `# CH4:` prefix. Do not touch now.

---

## File-by-File Disposition

### `10_config.R` → KEEP, minor update

Keep everything. Add new output paths for the redesigned structure:
```r
OUT_CR = list(
  S0_faithful  = "output/CriticalReplication/S0_faithful",
  S1_geometry  = "output/CriticalReplication/S1_geometry",
  S2_vecm      = "output/CriticalReplication/S2_vecm",
  results_pack = "output/CriticalReplication/ResultsPack",
  manifest     = "output/CriticalReplication/Manifest"
)
```
Remove: exercise_a/b/c/d/crosswalk paths (obliterated).
Keep: WINDOWS_LOCKED, DET_PAIRS, DSR_SET, DLR_SET, P_MIN, P_MAX_EXPLORATORY,
      seed, SINK_POLICY, bootstrap params, LR_ENGINE.

---

### `99_utils.R` → KEEP, mark Ch4 sections

**Keep as-is:**
- `%||%`
- `resolve_include`, `resolve_LRinclude`, `det_tag_from` — tsDyn parameter translators
- `qr_ortho_basis` — used in S2 m=3
- `gate_check_min_T` — feasibility guard
- `now_stamp` — logging
- `safe_write_csv`, `safe_read_csv` — I/O
- `tsdyn_loglik`, `sigma_hat_ml`, `tsdyn_loglik_safe2` — VECM log-likelihood
- `fit_sigma0_var_diff` — unrestricted VAR for companion matrix
- `det_count`, `k_sr`, `k_lr`, `k_total_rr` — parameter counting for `ic_eta`
- `pic_components` — parameterized IC (DROP — depends on ic_eta which is dropped; see D2)
- `preflight_vecm_spec` — sanity check before estimation
- `as_fail_record`, `truncate_msg` — structured failure capture
- `det_pairs` — deterministic pair enumeration

**Mark with `# CH4:` and leave untouched:**
- `basis_build_rawpowers_qr`
- `basis_apply_rawpowers_qr`
- `basis_apply_rawpowers`

**Remove:**
- `compute_complexity_record` (both the 99_utils version and the 24_ version —
  replaced by `make_spec_row()` in `98_ardl_helpers.R`)
- `admissible_gate` (kappa gate, old framework)
- All manifest append utilities that write to stage4 manifest:
  `results_pack_manifest_path`, `append_results_pack_export_log`,
  `stage4_manifest_log_path`, `append_stage4_spec_log`
  → manifest writing moves to `24_manifest_runner.R` exclusively
- `table_as_is`, `export_table_bundle` — packaging logic, moves to `80_pack`

---

### `24_complexity_penalties.R` → ABSORBED into `98_ardl_helpers.R`

**Keep and migrate to `98_ardl_helpers.R`:**
- `sanitize_vcov()` — defensive utility
- `stable_logdet()` — numerically stable log-determinant
- `compute_c1_core()` — computes C1(Σ) = (k/2)*log(tr(Σ)/k) - (1/2)*log|Σ|
- `compute_icomp_penalty()` — ICOMP_pen = 2*C1(Σ), feeds ICOMP IC value
- `compute_icomp_misspec_penalty()` — 2*C1(F^{-1} R F^{-1}), sandwich vcov

These are needed because ICOMP = -2*logL + ICOMP_pen is a FORMAL IC (stays).
What is dropped: using ICOMP_pen or ICOMP_Misspec_pen as the x-axis of envelope planes.
The fit-complexity plane x-axis is always k_total (number of parameters).

**Drop:**
- `compute_complexity_record()` — replaced by `make_spec_row()`

After migration, `24_complexity_penalties.R` as a standalone file is **obliterated**.

---

### `25_envelope_tools.R` → PARTIALLY ABSORBED into `98_ardl_helpers.R`

**Keep logic (migrate to `98_ardl_helpers.R`):**
- `extract_envelope()` — Pareto frontier extraction: essential for S1.1/S2.1 figures

**Drop entirely:**
- `canonicalize_envelope_schema()` — alias collision guard no longer needed
  once `make_spec_row()` owns canonical names
- `write_envelope_plane()` — its figure logic is for ICOMP/ICOMP_Misspec planes we dropped;
  S1/S2 figures are now specified in `98_ardl_helpers.R` figure functions

After migration, `25_envelope_tools.R` as a standalone file is **obliterated**.

---

### `20_shaikh_ardl_replication.R` → BECOMES `20_S0_shaikh_faithful.R`

**Keep (move as-is):**
- All local helpers (lines 76–183): `make_step_dummies`, `rebase_to_year_to_100`,
  `extract_bt`, `get_lr_table_with_scaled_dummies`, `extract_lr_row`,
  `extract_alpha_from_uecm`, `compute_u_from_lr`
  → These are good and self-contained. Source `98_ardl_helpers.R` instead of
  redefining if any overlap, otherwise keep local.
- Estimation loop (lines 288–339): `run_one_case()` + `lapply(CASES, ...)`
- Contest table builder (lines 344–384): `contest` tibble — keep structure
- Coefficient table builder (lines 390–405): `coef_tbl` — keep
- u-series builder (lines 410–416): `u_cases` — keep
- Figure (lines 423–466): keep, update to match S0 viz spec

**Add (new):**
- Fit-complexity seed point export for Figure S0_4:
  ```r
  s0_fitcomplexity <- data.frame(
    k_total   = length(coef(results[[3]]$fit)),  # Case III
    neg2logL  = -2 * as.numeric(logLik(results[[3]]$fit)),
    AIC       = AIC(results[[3]]$fit),
    BIC       = BIC(results[[3]]$fit),
    spec      = "ARDL(2,4)_CaseIII_{d56,d74,d80}"
  )
  safe_write_csv(s0_fitcomplexity, file.path(CSV_DIR, "S0_fitcomplexity_seed.csv"))
  ```
- RMSE vs Shaikh series computation and export

**Remove:**
- Manifest append block (lines 472–496) → manifest is `24_manifest_runner.R` only

**Rename output CSVs to fixed canonical names:**
- `SHAIKH_ARDL_case_contest_shaikh_window.csv` → `S0_spec_report.csv`
- `SHAIKH_ARDL_u_cases_shaikh_window.csv`      → `S0_utilization_series.csv`
- `SHAIKH_ARDL_coef_table_shaikh_window.csv`   → `S0_fivecase_summary.csv`

---

### `21_CR_ARDL_grid.R` → BECOMES `21_S1_ardl_geometry.R`

**Current state:** Only grids (p,q) — no case toggle, no dummy structure toggle.
Missing 3 of 4 lattice dimensions. Also has the alias collision bug.

**Keep:**
- Basic grid loop skeleton
- Data loading (consistent with `20`)
- AIC/BIC/HQ computation (lines 128–131: AIC_val, BIC_val, HQ_val, AICc_val)

**Extend (this is where most new work goes):**
- Full lattice: add `case` (1:5) and `s` (s0/s1/s2/s3) dimensions to grid loop
- Dummy structure toggle: use `make_step_dummies()` per `s` tag
- Bounds F-test per spec: `ARDL::bounds_f_test(fit, case = case_id)`
- Admissibility flag: `F_bounds > upper CV at 5%`
- LR coefficient extraction per spec: `theta_hat`, `s_K = q/(p+q)`
- u_hat series per admissible spec
- Fattened frontier F^(0.20): bottom 20% of AIC among admissible
- Pareto frontier: use migrated `extract_envelope()`
- IC tangency winners: which spec minimizes each of AIC, BIC, HQ?
- Three required figures: S1.1, S1.2, S1.3

**Remove:**
- ICOMP_pen/ICOMP_Misspec_pen alias additions (lines 154–155 and 134–135)
- ICOMP/ICOMP_Misspec envelope planes (lines 201–217)
- Manifest append (lines 225–244)
- `write_envelope_plane()` calls for ICOMP planes

---

### `22_VECM_S1.R` → BECOMES `22_S2_vecm_bivariate.R`

**Keep:**
- Data loading (`load_shaikh_window()`)
- VECM estimation core via tsDyn
- Companion root stability check
- Log-likelihood extraction (`tsdyn_loglik`)
- Parameter counting (`k_sr`, `k_lr`, `k_total_rr`)
- `q_profiles_for_p()` concept (formalize and move to `98_ardl_helpers.R`
  or keep local — either way, make it explicit)
- LR/SR deterministic branch loop structure

**Drop:**
- `ic_eta` and `ETA_GRID` → not formal ICs, dropped entirely (see D2)

**Add:**
- Triple admissibility gate (convergence + rank via `ca.jo` + stability)
- Omega_20 construction (bottom 20% by -2*logL)
- IC tangency winners: which spec minimizes each of AIC, BIC, HQ, ICOMP, ICOMP_Misspec
- Three required figures: S2.1, S2.2, S2.3 (parallel to S1)

**Remove:**
- ICOMP/ICOMP_Misspec columns and envelope planes
- `ic_eta` and `ETA_GRID` (custom criterion, not formal IC — dropped)
- Manifest append
- `compute_complexity_record()` calls → replace with `make_spec_row()`

---

### `23_VECM_S2.R` → BECOMES `23_S2_vecm_trivariate.R`

**Keep:**
- `ic_eta()` → migrate to `98_ardl_helpers.R`
- `q_profiles_for_p()` → formalize in `98_ardl_helpers.R`
- `cell_id()` → keep as naming utility
- m=3 state vector construction `X3 = cbind(lnY, lnK, e)`
- alpha/beta extraction from tsDyn VECM
- `build_restricted_design()` — used in rotation prior regression

**Add:**
- Rotation check: pure diagnostic, no gate (as locked)
- S2_rotation_check.csv output

**Remove:**
- ICOMP/ICOMP_Misspec columns
- `compute_complexity_record()` calls
- Manifest append

---

### `26_crosswalk_tables.R` → OBLITERATED

No migration needed. The crosswalk architecture is dropped.

---

### `27_run_stage4_all.R` → BECOMES `24_manifest_runner.R`

Rewrite almost entirely. Keep only:
- The idea of a script registry
- The status table pattern

New behavior: sole manifest writer, sole runner, smoke test before execution.

---

### `28_pack_ARDL_ShaikhRep_and_Grid.R` + `29_pack_VECM_S1_deep.R`
→ Logic migrated to `80_pack_ch3_replication.R`

Packaging logic preserved but reorganized as strict consumer.
No fallback discovery. CONTRACT ERROR on missing inputs.

---

## New File: `98_ardl_helpers.R`

Consolidates from `24_`, `25_`, and fragments in `22_`/`23_`:

```
98_ardl_helpers.R contents:
  # --- Migrated from 24_ ---
  sanitize_vcov()
  stable_logdet()
  compute_c1_core()         # C1(Sigma) = (k/2)*log(tr/k) - 0.5*log|Sigma|
  compute_icomp_penalty()   # ICOMP_pen = 2*C1(Sigma) — feeds ICOMP IC
  compute_icomp_misspec_penalty()  # 2*C1(F^{-1} R F^{-1}) — Bozdogan & Pamukcu (2016)

  # --- Canonical spec row builder (replaces both compute_complexity_record) ---
  make_spec_row()           # (p, q, case, s, logLik, k_total, T_eff, vcov_mat, sandwich_mat=NULL)
                          # vcov_mat    = vcov(model)          → feeds ICOMP = -2logL + 2*C1(F^{-1})
                          # sandwich_mat = F^{-1} R F^{-1}    → feeds ICOMP_Misspec
                          # If sandwich_mat is NULL, ICOMP_Misspec column is NA
                          # returns: AIC, BIC, HQ, AICc, ICOMP, ICOMP_Misspec, neg2logL, k_total
                            # returns: AIC, BIC, HQ, AICc, ICOMP, ICOMP_Misspec, neg2logL, k_total

  # --- Migrated from 25_ ---
  extract_envelope()        # Pareto frontier in fit-complexity plane

  # --- Migrated from 23_ ---
  q_profiles_for_p()        # S2 short-run memory allocation profiles
  # ic_eta: DROPPED — not a formal IC

  # --- New: figure functions ---
  plot_fitcomplexity_cloud()  # S1.1 / S2.1
  plot_ic_tangencies()        # S1.2 / S2.2
  plot_informational_domain() # S1.3 / S2.3
```

---

## Summary: What Moves Where

| Old file | Disposition | Target |
|---|---|---|
| `10_config.R` | Update paths | `10_config.R` |
| `99_utils.R` | Prune, mark Ch4 | `99_utils.R` |
| `24_complexity_penalties.R` | Partial migrate | `98_ardl_helpers.R` → obliterate |
| `25_envelope_tools.R` | Partial migrate | `98_ardl_helpers.R` → obliterate |
| `20_shaikh_ardl_replication.R` | Refactor | `20_S0_shaikh_faithful.R` |
| `21_CR_ARDL_grid.R` | Extend + fix | `21_S1_ardl_geometry.R` |
| `22_VECM_S1.R` | Refactor + extend | `22_S2_vecm_bivariate.R` |
| `23_VECM_S2.R` | Refactor + extend | `23_S2_vecm_trivariate.R` |
| `26_crosswalk_tables.R` | OBLITERATE | — |
| `27_run_stage4_all.R` | Rewrite | `24_manifest_runner.R` |
| `28_pack_ARDL_ShaikhRep_and_Grid.R` | Migrate logic | `80_pack_ch3_replication.R` |
| `29_pack_VECM_S1_deep.R` | Migrate logic | `80_pack_ch3_replication.R` |

---

_(See PART III of this document for full model spec.)_


---
---

# PART III — MODEL SPEC

## CONTEXT

This is a dissertation replication project in heterodox macroeconomics. The goal is to
replicate and stress-test Shaikh (2016)'s corporate capacity utilization measure using
three estimation stages: S0 (faithful replication), S1 (ARDL specification geometry),
and S2 (VECM system identification). All three stages share the same data objects and
escalate the identification environment. Produce a single well-structured R project
with one script per stage plus a shared data preparation script.

---

## PART 0: DATA PREPARATION SCRIPT (`00_data_prep.R`)

### 0.1 Series required

All series are annual, US corporate sector, approx. 1947–2009 (T≈63).
The data must already be available as a CSV or Excel file provided by the user.
Assume the file is named `shaikh_data.csv` with the following columns
(or as close to this as the user provides):

| Column | Description |
|---|---|
| `year` | Year |
| `GVAcorp` | Corrected corporate gross value added (imputed-interest adjusted) |
| `KGCcorp` | Corrected corporate gross capital stock (GPIM-adjusted, with inventories) |
| `P` | Common deflator: GDP implicit price deflator (NIPA Table 1.1.9, line 1) |
| `Profshcorp` | Corrected corporate profit share (for S2 m=3 only) |
| `u_shaikh` | Shaikh's published utilization series (Appendix Figure 6.6.1) — for RMSE diagnostic |

### 0.2 Transformations

```r
# Real log series (common deflator applied to both)
y <- log(GVAcorp / P)   # ln(GVAcorp_t / p_t)
k <- log(KGCcorp / P)   # ln(KGCcorp_t / p_t)
e <- log(Profshcorp)    # ln(Profshcorp_t) — S2 m=3 only

# Dummy variables (impulse dummies, = 1 in named year only)
d56 <- as.integer(year == 1956)
d74 <- as.integer(year == 1974)   # NOTE: 1974, not 1973
d80 <- as.integer(year == 1980)
```

### 0.3 Critical constraint
Output `y` and capital `k` MUST use the same deflator `P`. Never apply separate
deflators. This is the profit-rate-consistency identification constraint from
Shaikh (2016) Appendix 6.6.

---

## PART 1: S0 — FAITHFUL REPLICATION (`20_S0_shaikh_faithful.R`)

### 1.1 Objective
Reconstruct Shaikh's ARDL(2,4) corporate capacity utilization benchmark as faithfully
as possible. Hold all design choices at Shaikh's reported values. Produce:
- Bounds admissibility result (three-level: F-bounds, t-bounds, RMSE)
- Recovered productive capacity benchmark `yp_hat`
- Recovered utilization series `u_hat`
- Five-case deterministic comparison
- All output tables and figures for Chapter 3

### 1.2 Package
Use the `ARDL` package (Natsiopoulos & Tzeremes 2022, CRAN).
```r
library(ARDL)
library(dplyr)
library(ggplot2)
```

### 1.3 Benchmark specification
Fixed at Shaikh's reported tuple: `m0 = (p=2, q=4, case=3, dummies={d56, d74, d80})`

```r
# Build the ARDL(2,4) model — Case III: unrestricted intercept, no trend
# Dependent variable: y (log real corporate output)
# Forcing variable: k (log real corporate capital)
# Dummies: d56, d74, d80 entered as fixed regressors

ardl_s0 <- ardl(y ~ k | d56 + d74 + d80, order = c(2, 4), data = df)
# CRITICAL: use | separator (not +) for fixed regressors (dummies)
# | syntax: dummies are frozen — NOT lagged, NOT counted in order vector
```

### 1.4 Bounds admissibility — three levels

**Level 1 (primary gate): F-bounds test**
```r
bounds_f <- bounds_f_test(ardl_s0, case = 3)
# case=3: unrestricted intercept, no trend (PSS Case III)
# H0: phi1 = phi2 = 0 (no long-run level relationship)
# Compare F-statistic to PSS (2001) critical values, Table CI(iii)
```

**Level 2 (robustness diagnostic): t-bounds test**
```r
bounds_t <- bounds_t_test(ardl_s0, case = 3)
# Report but do NOT use as admissibility gate
# Shaikh omits this test (footnote 16: low power)
```

**Level 3 (replication quality): RMSE vs Shaikh published series**
```r
# Compute after recovering u_hat — see 1.6 below
rmse_s0 <- sqrt(mean((u_hat - u_shaikh)^2, na.rm = TRUE))
# Non-zero RMSE may reflect deflator gap, not specification error
```

### 1.5 Long-run coefficient recovery
```r
lr <- multipliers(ardl_s0, type = "lr")
# Extracts: theta_hat (capital LR elasticity), a_hat (intercept),
#           c_d74, c_d56, c_d80 (dummy LR multipliers)

# Canonical values to verify against (from Shaikh Table 6.7.14):
# theta_hat = 0.6609
# a_hat     = 2.1782
# c_d74     = -0.8548
# c_d56     = -0.7428
# c_d80     = -0.4780
# AIC       = -319.38
# BIC       = -296.16
# R^2       = 0.9992
# log-lik   = 170.6901
```

### 1.6 Capacity benchmark and utilization recovery
```r
# Long-run capacity benchmark (Case III: intercept + capital + dummies, no trend)
yp_hat <- lr$intercept + lr$k * k + lr$d56 * d56 + lr$d74 * d74 + lr$d80 * d80

# Utilization recovered residually
u_hat <- exp(y - yp_hat)

# Short-run capital memory share (tracked object)
# s_K = q / (p + q) = 4 / (2 + 4) = 0.667 at m0
s_K_s0 <- 4 / (2 + 4)
```

### 1.7 Five-case comparison
Run the same ARDL(2,4) with dummies {d56,d74,d80} for all five PSS cases.
For each case: report F-bounds result, long-run theta_hat, RMSE vs Shaikh series.

```r
cases <- 1:5
results_5case <- lapply(cases, function(c) {
  m <- ardl(y ~ k + d56 + d74 + d80, order = c(2,4), case = c, data = df)
  f <- bounds_f_test(m, case = c)
  lr_c <- multipliers(m, type = "lr")
  yp_c <- # recover benchmark for this case (include trend if case 4 or 5)
  u_c  <- exp(y - yp_c)
  rmse_c <- sqrt(mean((u_c - u_shaikh)^2, na.rm = TRUE))
  list(case=c, F_stat=f$statistic, F_pval=f$p.value,
       theta=lr_c$k, AIC=AIC(m), BIC=BIC(m), RMSE=rmse_c)
})
```

### 1.8 Required output tables

**Table 1 — PSS deterministic cases** (already in LaTeX; R produces numeric fills):
For each case: F-statistic, lower/upper critical values at 5%, admissible (Y/N)

**Table 2 — Bounds test results at m0**:
| Test | Statistic | Lower CV 5% | Upper CV 5% | Decision |
F-bounds and t-bounds for Case III at ARDL(2,4)

**Table 3 — Five-case RMSE**:
| Case | theta_hat | AIC | RMSE vs Shaikh | Admissible |

### 1.9 Required figures

**Figure S0_1** (`fig_S0_utilization_replication.pdf`) — Utilization replication:
- Series: `u_hat` (replicated, solid blue) vs `u_shaikh` (published, black dashed)
- x-axis: year 1947–2011; y-axis: utilization rate (0.60–1.20)
- Vertical lines at d56 (1956), d74 (1974), d80 (1980), labeled
- RMSE annotated in figure or caption
- Caption must note: non-zero RMSE may reflect deflator gap (NIPA 1.1.9
  vs Shaikh's undisclosed p_t), not specification error

**Figure S0_2** (`fig_S0_capacity_benchmark.pdf`) — Capacity benchmark decomposition:
- Series: `y` (observed log real output) vs `yp_hat` (capacity benchmark)
- Gap shading between the two series represents ln(u_hat)
- Vertical lines at d56, d74, d80 — show level shifts in benchmark
- Annotate long-run slope: theta_hat = 0.6609

**Figure S0_3** (`fig_S0_fivecase_comparison.pdf`) — Five-case utilization comparison:
- Panel of 5 small multiples (one per PSS case)
- Each panel: case-specific u_hat (solid) + Shaikh's published series (grey reference)
- Admissible cases: solid color line; inadmissible: dashed + annotation "fails F-bounds"
- Case III panel marked ★; RMSE reported per panel
- Purpose: assess whether Case III is an outlier or representative of the case family

**Figure S0_4** (`fig_S0_fitcomplexity_s0point.pdf`) — Fit-complexity seed point:
- Single point at (k0, -2*logL0) = (11, -341.38)
  where k0 = 11 params (Table 6.7.14), -2*logL0 = -2 * 170.6901
- x-axis: k(m) number of parameters; y-axis: -2*log L(m)
- AIC iso-contour (slope = 2) and BIC iso-contour (slope = log(T))
  both passing through the S0 point
- Annotation: "S0: ARDL(2,4), Case III, {d56, d74, d80}"
- NOTE: this figure is a FORWARD-LOOKING SEED. It plants m0 in an
  otherwise empty plane. S1 populates the cloud around it.
  The IC geometry question — where does m0 sit relative to IC tangencies
  and the frontier? — is ANSWERED IN S1 (Figure S1.2), not here.

---

## PART 2: S1 — ARDL SPECIFICATION GEOMETRY (`21_S1_ardl_geometry.R`)

### 2.1 Objective
Map the full ARDL specification lattice L_S1 = {(p, q, c, s)}, apply bounds admissibility
screening, build the fit-complexity cloud, identify the fattened frontier F^(0.20),
and track five inferential objects across the frontier.

### 2.2 Lattice dimensions
```
p ∈ {1, 2, 3, 4, 5}       — lag order on y (output)
q ∈ {1, 2, 3, 4, 5}       — lag order on k (capital)
c ∈ {1, 2, 3, 4, 5}       — PSS deterministic case (Cases I–V)
s ∈ {s0, s1, s2, s3}      — dummy structure:
    s0: no dummies
    s1: {d74} only
    s2: {d74, d80}
    s3: {d56, d74, d80}    ← Shaikh's benchmark structure
```

Total grid: 5 × 5 × 5 × 4 = 500 specifications.

### 2.3 Grid estimation
```r
library(ARDL)
library(purrr)

dummy_sets <- list(
  s0 = NULL,
  s1 = "d74",
  s2 = c("d74", "d80"),
  s3 = c("d56", "d74", "d80")
)

grid <- expand.grid(p=1:5, q=1:5, case=1:5, s=names(dummy_sets))

results_s1 <- pmap(grid, function(p, q, case, s) {
  dums <- dummy_sets[[s]]
  formula <- if (is.null(dums)) {
    as.formula("y ~ k")
  } else {
    # Use | to separate fixed regressors (dummies not lagged, not in order)
    as.formula(paste("y ~ k |", paste(dums, collapse=" + ")))
  }
  tryCatch({
    m <- ardl(formula, order = c(p, q), case = case, data = df)
    f_test <- bounds_f_test(m, case = case)
    lr <- long_run(m)
    list(
      p=p, q=q, case=case, s=s,
      F_stat = f_test$statistic,
      F_lower_5 = f_test$critical_values["5%", "lower"],
      F_upper_5 = f_test$critical_values["5%", "upper"],
      admissible = f_test$statistic > f_test$critical_values["5%", "upper"],
      inconclusive = (f_test$statistic > f_test$critical_values["5%", "lower"] &
                      f_test$statistic <= f_test$critical_values["5%", "upper"]),
      theta = lr$k,
      AIC = AIC(m),
      BIC = BIC(m),
      loglik = logLik(m)[1],
      n_params = length(coef(m)),
      yp_hat = # recover capacity benchmark series
      u_hat  = # recover utilization series
      s_K    = q / (p + q)
    )
  }, error = function(e) NULL)
})
```

### 2.4 Admissibility gate
```r
# Keep only specifications where F-statistic EXCEEDS upper bound (strict)
# Treat inconclusive region as non-admissible for clean frontier analysis
# Flag m0 explicitly regardless
A_S1 <- filter(results_s1_df, admissible == TRUE)
```

### 2.5 Fit-complexity plane and IC contours
```r
# Map each admissible spec to fit-complexity coordinates
# x-axis: k(m) = number of estimated parameters
# y-axis: -2 * log-likelihood

# IC as linear iso-penalty contours:
# AIC contour: -2*logL + 2*k = constant  → slope = -2 in (k, -2logL) space
# BIC contour: -2*logL + log(T)*k = constant → slope = -log(T)

# Plot:
# - scatter of admissible specs in fit-complexity plane
# - AIC and BIC tangency contours
# - m0 (Shaikh's point) highlighted
# - fattened frontier F^(0.20) highlighted
```

### 2.6 Fattened frontier F^(0.20)
```r
# Define as bottom 20% of AIC values among admissible specs
# (run separately for AIC and BIC — note if they differ)
q20_AIC <- quantile(A_S1$AIC, 0.20)
F_020 <- filter(A_S1, AIC <= q20_AIC)

# Flag whether m0 falls within F^(0.20)
m0_in_frontier <- (filter(A_S1, p==2, q==4, case==3, s=="s3")$AIC <= q20_AIC)
```

### 2.7 Five tracked objects across F^(0.20)
For every specification in F^(0.20), extract and store:
1. `theta` — long-run capital elasticity
2. `u_hat` — utilization time series (store as matrix: T rows × |F^(0.20)| cols)
3. `s_K` = q/(p+q) — short-run capital memory share
4. `case` — deterministic case index
5. `s` — dummy structure label

Stability assessment:
```r
# Range of theta across F^(0.20)
theta_range <- range(F_020$theta)
theta_sd    <- sd(F_020$theta)

# Band of utilization series: pointwise min/max and median
u_mat   <- do.call(cbind, F_020$u_hat)
u_med   <- apply(u_mat, 1, median)
u_lower <- apply(u_mat, 1, min)
u_upper <- apply(u_mat, 1, max)
```

### 2.8 Required figures

The three S1 figures form a sequential IC-uncertainty argument:
S1.1 establishes the cloud geometry; S1.2 proves H0 (IC picks differ);
S1.3 delivers H1 (the credible region as an object, not a point).

**Figure S1.1** (`fig_S1_global_frontier.pdf`) — Global Frontier:
- x-axis: k_total (number of estimated parameters)
- y-axis: -2*log L
- All m in A_S1: light grey points
- Pareto non-dominated set highlighted (distinct color/shape)
- m0 (Shaikh's point): starred marker
- Color coding by deterministic case c or dummy structure s
- Argumentative function: admissible ARDL specs form a structured cloud,
  not a single point. Motivates S1 as geometry, not search.

**Figure S1.2** (`fig_S1_ic_tangencies.pdf`) — IC Tangency Points (H0 proof):
- Background: full admissible cloud in light grey
- Pareto frontier overlaid as dark line
- AIC, BIC, HQ, ICOMP, ICOMP_Misspec winners: each marked with distinct
  symbol AND color — all five visible simultaneously
- m0 starred
- Legend: all five IC criteria labeled
- ICOMP_Misspec = ICOMP with sandwich vcov: C1(F^{-1} R F^{-1}) — Bozdogan & Pamukçu (2016)
- Argumentative function: EACH IC SELECTS A DIFFERENT COORDINATE
  in fit-complexity space. This is the visual proof of H0 —
  IC is a coordinate selector under uncertainty, not a unique truth.
  IC winners disperse across the frontier, not cluster at one point.
- DIAGNOSTIC FLAG: if all five ICs select the same or adjacent point,
  H0 visual argument weakens — log this before finalizing figure.
  NOTE: The question "where does m0 sit relative to IC tangencies?"
  is answered HERE, not in S0.

**Figure S1.3** (`fig_S1_informational_domain.pdf`) — Informational Domain F^(0.20) (H1):
- Background: full admissible cloud in light grey
- F^(0.20) highlighted as shaded region or outlined cluster
- Pareto frontier overlaid
- Annotation: n specifications in F^(0.20); IC quantile cutoff labeled
- Optional: show F^(0.20) variants side-by-side for AIC vs BIC vs HQ
- Argumentative function: H1 — the credible specification region
  is a band, not a point. All specs in F^(0.20) are epistemically
  equivalent under IC uncertainty. Object-bundle inference follows.

**Supplementary outputs** (not primary paper figures — produced for diagnostics):
- theta_hat distribution across F^(0.20): density + vertical line at 0.6609
- Utilization band: pointwise median +/- range of u_hat across F^(0.20),
  Shaikh's published series overlaid
- s_K distribution across F^(0.20): histogram of q/(p+q)

---

## PART 3: S2 — VECM SYSTEM IDENTIFICATION (`22_S2_vecm_bivariate.R` + `23_S2_vecm_trivariate.R`)

### 3.1 Objective
Re-estimate the long-run restriction as a system property using Johansen VECM.
Two system sizes: m=2 (bivariate) and m=3 (trivariate with exploitation proxy).
Build specification lattice L_S2, apply triple admissibility gate, identify
informational domain Omega_20, track six objects.

### 3.2 Package
```r
library(tsDyn)   # Stigler (2020) — vec2var, VECM()
library(vars)    # VAR/VECM support
library(urca)    # ca.jo() for Johansen trace/max-eigenvalue tests
```

### 3.3 System dimensions

**m=2 system:**
```r
X2 <- cbind(y, k)   # state vector: (ln Y_t, ln K_t)'
r2 <- 1             # cointegration rank: 1
# One cointegrating vector identifies the capacity transformation relation
```

**m=3 system:**
```r
X3 <- cbind(y, k, e)   # state vector: (ln Y_t, ln K_t, ln e_t)'
r3 <- 2                # cointegration rank: 2
# r=2: capacity transformation + reserve-army relations
# e = log(Profshcorp) as empirical proxy for log rate of exploitation
```

### 3.4 Specification lattice L_S2
```
m ∈ {2, 3}         — system dimension
r ∈ {1} if m=2, {1,2} if m=3  — cointegration rank
p ∈ {1, 2, 3, 4}   — lag depth (VAR lag order; VECM uses p-1 lags of differences)
d ∈ {d0,d1,d2,d3}  — deterministic branch:
    d0: no deterministic terms
    d1: constant restricted to long-run (Johansen type="const", estim="ML")
    d2: unrestricted constant
    d3: unrestricted constant + trend
h ∈ {h0, h1, h2}   — historical shock structure:
    h0: no dummies
    h1: {d74}
    h2: {d56, d74, d80}
```

### 3.5 VECM estimation and triple admissibility gate

#### Deterministic branch lookup table
```r
# d_branches: named list mapping each det. branch to its three required arguments.
# All three must be set consistently in VECM() and ca.jo().
d_branches <- list(
  d0 = list(include="none",  LRinclude="none",  ecdet="none"),  # no det terms
  d1 = list(include="none",  LRinclude="const", ecdet="const"), # restricted const (Johansen Case II)
  d2 = list(include="const", LRinclude="none",  ecdet="none"),  # unrestricted const (Johansen Case III)
  d3 = list(include="both",  LRinclude="none",  ecdet="none")   # unrestricted const+trend (Johansen Case V)
)
# NOTE: rank.test() from tsDyn does not support exogenous regressors (dummies).
# ca.jo() with dumvar= is used for all rank tests throughout the grid.
```

```r
results_s2 <- list()

for (m_dim in c(2, 3)) {
  X        <- if (m_dim == 2) X2 else X3
  rank_set <- if (m_dim == 2) 1L else 1:2

  for (r_rank in rank_set) {
    for (p_lag in 1:4) {
      for (d_name in names(d_branches)) {
        d <- d_branches[[d_name]]

        for (h_name in c("h0","h1","h2")) {
          h_vars <- list(h0=NULL, h1="d74", h2=c("d56","d74","d80"))[[h_name]]

          tryCatch({
            # Align dummy matrix to estimation sample (tail T_eff rows)
            T_full  <- nrow(X)
            T_eff_p <- T_full - (p_lag - 1)
            dum_mat <- if (!is.null(h_vars)) {
              as.matrix(df[tail(seq_len(T_full), T_eff_p), h_vars, drop=FALSE])
            } else NULL

            # Estimate VECM (Johansen ML)
            # lag = ECM lags = VAR lag order - 1
            vecm_fit <- VECM(X,
                             lag       = p_lag - 1,
                             r         = r_rank,
                             estim     = "ML",
                             include   = d$include,
                             LRinclude = d$LRinclude,
                             exogen    = dum_mat)

            # === TRIPLE ADMISSIBILITY GATE ===

            # Gate 1: Convergence
            converged <- !any(is.na(unlist(coef(vecm_fit)))) &&
                         !any(is.nan(unlist(coef(vecm_fit))))

            # Gate 2: Rank consistency (Johansen trace test via urca::ca.jo)
            # K = VAR lag order = p_lag; VECM lag = p_lag - 1
            # ca.jo teststat ordering in trace test:
            #   teststat[1] = H0: rank <= m-1 (near-full rank hypothesis)
            #   teststat[m] = H0: rank <= 0   (null of no cointegration)
            # To test "rank >= r_rank", reject H0: rank < r_rank
            #   correct index = m_dim - r_rank + 1
            jo      <- ca.jo(X, type="trace", ecdet=d$ecdet,
                             K=p_lag, dumvar=dum_mat)
            idx_rk  <- m_dim - r_rank + 1
            rank_ok <- (jo@teststat[idx_rk] > jo@cval[idx_rk, "5pct"])

            # Gate 3: Stability — no explosive roots in VAR companion matrix
            # VARrep() is the tsDyn-native function for VAR representation.
            # companionMat() does NOT exist in tsDyn.
            # For correctly-specified rank, m-r unit roots exist by construction;
            # the independent check is absence of explosive roots (modulus > 1).
            # Tolerance 1e-3: numerical noise on 63-obs estimation sample.
            var_mat <- VARrep(vecm_fit)
            eig_mod <- Mod(eigen(var_mat)$values)
            stable  <- all(eig_mod <= 1 + 1e-3)

            admissible <- converged & rank_ok & stable

            if (admissible) {
              beta_hat  <- coefB(vecm_fit)   # cointegrating vectors (m x r)
              alpha_hat <- coefA(vecm_fit)   # adjustment/loading matrix (m x r)

              ll    <- logLik(vecm_fit)[1]
              T_eff <- attr(logLik(vecm_fit), "nobs")  # effective sample size
              k_tot <- length(unlist(coef(vecm_fit)))

              # Recover utilization from first cointegrating vector
              # beta[:,1] normalized via Phillips triangular representation (tsDyn default)
              coint_resid <- as.numeric(X %*% coefB(vecm_fit)[, 1])
              u_hat_s2    <- exp(coint_resid - mean(coint_resid))

              # s_K: capital short-run memory share (system analogue of q/(p+q))
              # Implement as: sum_i ||Gamma_i[k-col,]||_F / sum_i ||Gamma_i||_F

              results_s2 <- append(results_s2, list(list(
                m         = m_dim,
                r         = r_rank,
                p         = p_lag,
                d         = d_name,
                h         = h_name,
                admissible= TRUE,
                beta      = beta_hat,
                alpha     = alpha_hat,
                loglik    = ll,
                k_total   = k_tot,
                T_eff     = T_eff,
                u_hat     = u_hat_s2,
                neg2logL  = -2 * ll,
                AIC       = -2*ll + 2*k_tot,
                BIC       = -2*ll + log(T_eff)*k_tot,
                HQ        = -2*ll + 2*log(log(T_eff))*k_tot
              )))
            }
          }, error = function(e) NULL)
        }
      }
    }
  }
}
```
### 3.6 Informational domain Omega_20
```r
# Bottom 20% of admissible specs by -2*logL (equivalently, highest logL)
results_s2_df <- bind_rows(results_s2)
A_S2 <- filter(results_s2_df, admissible == TRUE)

# Separate Omega_20 by system dimension
q20_logL_m2 <- quantile(A_S2_m2$neg2logL, 0.20)
q20_logL_m3 <- quantile(A_S2_m3$neg2logL, 0.20)

Omega_20_m2 <- filter(A_S2, m==2, neg2logL <= q20_logL_m2)
Omega_20_m3 <- filter(A_S2, m==3, neg2logL <= q20_logL_m3)
```

### 3.7 Six tracked objects across Omega_20
For every spec in Omega_20 extract:
1. `beta` — cointegrating vector(s)
2. `u_hat` — implied utilization series
3. `alpha` — adjustment speed matrix
4. `s_K` — capital-side short-run memory share
5. `d` — deterministic closure structure
6. `h` — historical shock architecture

Stability assessment (same structure as S1):
```r
# For m=2:
beta_1_range  <- range(sapply(Omega_20_m2, function(x) x$beta[2,1]))  # capital loading
u_band_m2_med <- # pointwise median of u_hat across Omega_20_m2
u_band_m2_range <- # pointwise min/max

# For m=3:
# Track whether second cointegrating vector emerges stably
# Track rotation diagnostic: sign of lambda in P8
# hat_e_t = mu + lambda * hat_u_t + sum kappa_h * DM_h,t
# lambda < 0 required for canonical rotation prior
```

### 3.8 P8 rotation diagnostic
After extracting Omega_20 cointegrating vectors, run the rotation prior regression:
```r
# For each spec in Omega_20_m3 with r=2:
# Run: e_t = mu + lambda * u_hat_t + sum_h kappa_h * DM_h,t
# Check: lambda < 0 (sign restriction encoding the reserve-army prior)
# This is NOT a Johansen restriction — it is a post-estimation rotation check

rotation_check <- lapply(Omega_20_m3_r2, function(spec) {
  lm_rot <- lm(e ~ spec$u_hat + d74 + d80 + d56, data=df)
  list(lambda=coef(lm_rot)["spec$u_hat"],
       lambda_sign=sign(coef(lm_rot)["spec$u_hat"]),
       sign_consistent = coef(lm_rot)["spec$u_hat"] < 0)
})
```

### 3.9 Required figures

The three S2 figures are PARALLEL to S1.1–S1.3, extended to the VECM system.
Same IC-uncertainty argument, now in system identification space.
System dimension (m=2 vs m=3) is a visual dimension in all three figures.

**Figure S2.1** (`fig_S2_global_frontier.pdf`) — Global Frontier:
- x-axis: k_total; y-axis: -2*log L
- All m in A_S2: points colored/shaped by system dimension
  (m=2: one color; m=3: another)
- Pareto non-dominated set overlaid as frontier line
- Argumentative function: admissible VECM specs form a structured cloud.
  Two system sizes occupy different regions of fit-complexity space —
  m=3 buys fit at higher complexity cost.

**Figure S2.2** (`fig_S2_ic_tangencies.pdf`) — IC Tangency Points (H0 proof):
- Background: full admissible cloud in light grey
- Pareto frontier overlaid
- AIC, BIC, HQ, ICOMP, ICOMP_Misspec winners: distinct symbol + color
- m=2 and m=3 winners shown separately if they differ
- Argumentative function: same as S1.2 — IC selects different coordinates.
  Key additional question: do IC winners concentrate in m=2 or m=3?
  This is diagnostic for whether the trivariate extension is warranted
  by the data or only by complexity-penalized criteria.
- DIAGNOSTIC FLAG: if IC winners cluster near same point, H0 weakens — log.

**Figure S2.3** (`fig_S2_informational_domain.pdf`) — Informational Domain Omega_20 (H1):
- Background: full admissible cloud in light grey
- Omega_20 highlighted as shaded region
- Optional: split Omega_20 by m=2 vs m=3 within same plot
- Annotation: n specs in Omega_20; quantile cutoff labeled
- Argumentative function: H1 in system space — the credible VECM region
  is a band. Does Omega_20 span both m=2 and m=3, or collapse to one?
  This determines whether system extension is robustly supported.

**Supplementary outputs** (diagnostics, not primary paper figures):
- beta_k (capital loading) distribution across Omega_20_m2:
  density + vertical line at S0 theta_hat = 0.6609
- Utilization band: m=2 vs m=3 panels, Shaikh overlaid on both
- alpha matrix heatmap: for a representative spec in Omega_20,
  show which variable bears the error-correction burden

---

## PART 4: PROJECT STRUCTURE AND OUTPUT

### 4.1 File structure
```
/replication_ch3/
  00_data_prep.R
  20_S0_shaikh_faithful.R
  21_S1_ardl_geometry.R
  22_S2_vecm_bivariate.R
  23_S2_vecm_trivariate.R
  data/
    shaikh_data.csv
  output/
    tables/
      S0_table2_bounds.tex
      S0_table3_fivecase.tex
      S1_frontier_summary.tex
      S2_admissibility_summary.tex
    figures/
      fig_S0_utilization_replication.pdf
      fig_S0_capacity_benchmark.pdf
      fig_S0_fivecase_comparison.pdf
      fig_S0_fitcomplexity_s0point.pdf
      fig_S1_fitcomplexity_cloud.pdf
      fig_S1_theta_distribution.pdf
      fig_S1_utilization_band.pdf
      fig_S1_sK_distribution.pdf
      fig_S2_fitcomplexity_m2.pdf
      fig_S2_fitcomplexity_m3.pdf
      fig_S2_beta_stability_m2.pdf
      fig_S2_utilization_band.pdf
      fig_S2_alpha_heatmap.pdf
  results/
    S0_results.rds
    S1_grid.rds
    S2_grid.rds
```

### 4.2 All figures: style requirements
- Use `ggplot2` with a clean minimal theme (`theme_minimal()`)
- Color scheme: single color for main series, grey for bands/clouds
- Shaikh's published series: always in black dashed
- Replicated series: always in solid blue
- Save all figures as PDF at 7×5 inches, 300 DPI
- All axis labels in LaTeX-compatible notation (use `latex2exp` or `expression()`)

### 4.3 All LaTeX tables
- Use `xtable` or `kableExtra` for LaTeX output
- Stars: *** p<0.01, ** p<0.05, * p<0.10
- Note rows for RMSE, deflator gap acknowledgment, m0 flagging

---

## LOCKED DECISIONS — DO NOT DEVIATE

| Decision | Value |
|---|---|
| Dummy year for oil shock | d74 (1974), NOT d73 |
| ARDL dummy syntax | Use `y ~ k | d56 + d74 + d80` (pipe), NOT `y ~ k + d56 + d74 + d80` (plus) |
| ARDL long-run extraction | `multipliers(m, type="lr")` — `long_run()` does NOT exist in the package |
| Dummy set at S0 | {d56, d74, d80} |
| Deflator | GDP implicit price deflator (NIPA 1.1.9 line 1) |
| Bounds t-test | Report but NOT an admissibility gate |
| S0 filter acknowledgment | If F-bounds fails all five cases, acknowledge ARDL operates as filter |
| s_K definition | q/(p+q) for S0/S1; system analogue for S2 |
| F^(0.20) criterion | Bottom 20% of AIC among admissible (run BIC separately) |
| Omega_20 criterion | Bottom 20% of -2*logL among admissible |
| P8 rotation prior | lambda < 0 in hat_e = mu + lambda*hat_u + dummies; post-estimation check only |
| Formal IC set | AIC, BIC, HQ, ICOMP, ICOMP_Misspec — no ic_eta, no RICOMP, no custom criteria |
| ICOMP formula | −2logL + 2·C₁(F̂⁻¹); C₁(Σ)=(k/2)log(tr(Σ)/k)−(1/2)log|Σ| — Bozdogan (1990) |
| ICOMP_Misspec | −2logL + 2·C₁(F̂⁻¹R̂F̂⁻¹); sandwich vcov — Bozdogan & Pamukçu (2016) |
| RICOMP | EXCLUDED — requires robust M/S/MM estimation, incompatible with Johansen ML and (k,−2logL) plane — Güney et al. (2021) JCAM 398 |
| VECM package | tsDyn (Stigler 2020) for estimation; urca (ca.jo) for rank tests |
| Profshcorp | Enters S2 m=3 only; dormant in S0 and S1 |
| S1 fence bug | The S1 CodeVizContract has a pre-existing code fence block bug — if encountered, fix and proceed |

---

## CANONICAL BENCHMARK VALUES FOR VERIFICATION

At the end of `20_S0_shaikh_faithful.R`, print a verification block:

```r
cat("=== S0 VERIFICATION vs SHAIKH TABLE 6.7.14 ===\n")
cat("theta_hat:", round(lr$k, 4), "| Target: 0.6609\n")
cat("a_hat:    ", round(lr$intercept, 4), "| Target: 2.1782\n")
cat("c_d74:    ", round(lr$d74, 4), "| Target: -0.8548\n")
cat("c_d56:    ", round(lr$d56, 4), "| Target: -0.7428\n")
cat("c_d80:    ", round(lr$d80, 4), "| Target: -0.4780\n")
cat("AIC:      ", round(AIC(ardl_s0), 4), "| Target: -319.3801\n")
cat("BIC:      ", round(BIC(ardl_s0), 4), "| Target: -296.1605\n")
cat("loglik:   ", round(logLik(ardl_s0)[1], 4), "| Target: 170.6901\n")
cat("R2:       ", round(summary(ardl_s0)$r.squared, 4), "| Target: 0.9992\n")
cat("RMSE vs Shaikh:", round(rmse_s0, 6), "\n")
cat("==============================================\n")
```

---

_Prompt version: S0S1S2_CodePrompt_v1 | Session 5 | 2026-03-10_
_Source authorities: S0_ShaikhCanonical_Reference_v1.md, S0_MasterBrief_v1.md,_
_S0_EmpiricalStrategy_v2.md, S1_MasterBrief_v1_annotated.md,_
_S1_RawMaterials_v1.md, S2_MasterBrief_v2.md, S2_RawMaterials_v3.md_
_All locked decisions from session transcript apply._

---

## APPENDIX A: PACKAGE SPECIFICATIONS

### A.1 ARDL Package (v0.2.4 — Natsiopoulos & Tzeremes 2024)

**Reference:** Natsiopoulos, K., & Tzeremes, N. G. (2024). ARDL: an R package for ARDL models and cointegration. *Computational Economics*, 64(3), 1757–1773.

#### Key functions

```r
# MODEL ESTIMATION
ardl(formula, data, order, start = NULL, end = NULL)
# formula: use | to separate fixed regressors (dummies, trend):
#   y ~ k | d56 + d74 + d80       ← dummies fixed, not lagged
#   y ~ k + trend(y) | d56        ← dynlm trend() syntax
# order: numeric vector, length = number of NON-fixed variables
#   order = c(p, q) for ARDL(p, q) with one forcing variable
# Returns object of class c("dynlm", "lm", "ardl")

uecm(ardl_object)     # Unrestricted ECM form
recm(ardl_object, case)  # Restricted ECM (ECT as single term)

# LONG-RUN COEFFICIENTS
multipliers(object, type = "lr", vcov_matrix = NULL, se = FALSE)
# type = "lr" → long-run (total) multipliers with SEs, t-stats, p-values
# type = "sr" or 0 → short-run (impact) multipliers
# type = integer → delay/interim multipliers at that horizon
# Returns data.frame: estimate, std.error, t-statistic, p-value
# Access: multipliers(m, type="lr")["k", "Estimate"] → theta_hat

# COINTEGRATING EQUATION
coint_eq(object, case)
# Returns numeric vector: the cointegrating residual series
# Equivalent to: fitted values of the long-run equilibrium

# BOUNDS TESTS
bounds_f_test(object, case, alpha = NULL, pvalue = TRUE,
              exact = FALSE, R = 40000, test = "F", vcov_matrix = NULL)
# Returns htest object with:
#   $statistic       — F-statistic value
#   $p.value         — asymptotic p-value (or exact if exact=TRUE)
#   $tab             — data.frame: stat, lower bound, upper bound, alpha, pvalue
#   $PSS2001parameters — PSS table critical values (rounded)
#   $null.value      — c(k, T) used in the test
# alpha: if NULL, only p-value returned; if 0.05, bounds at 5% added
# exact=TRUE: finite-sample simulation (set.seed() beforehand; slow)
# IMPORTANT: bounds_f_test is a Wald test on UECM parameters

bounds_t_test(object, case, alpha = NULL, pvalue = TRUE,
              exact = FALSE, R = 40000, vcov_matrix = NULL)
# Returns t-statistic for the lagged dependent variable coefficient
# NOT applicable for case = 2 or case = 4 (restricted intercept/trend)
# Use as robustness diagnostic only — not an admissibility gate

# PSS CASES — consistent across ardl(), bounds_f_test(), coint_eq():
# Case 1 (or "n"):    no intercept, no trend
# Case 2 (or "rc"):   restricted intercept (enters LR only), no trend
# Case 3 (or "uc"):   unrestricted intercept, no trend      ← SHAIKH CASE
# Case 4 (or "ucrt"): unrestricted intercept, restricted trend
# Case 5 (or "ucut"): unrestricted intercept, unrestricted trend

# IC extraction (standard lm methods work):
AIC(ardl_m)   # Akaike (standard formula: -2*logL + 2*k)
BIC(ardl_m)   # Bayesian
logLik(ardl_m)  # returns logLik object; [1] extracts scalar
length(coef(ardl_m))  # number of estimated parameters
```

#### Critical usage note — dummy syntax
```r
# CORRECT (pipe separator — dummies are fixed, not part of lag order):
ardl(y ~ k | d56 + d74 + d80, order = c(2, 4), data = df)

# WRONG (plus separator — dummies would be lagged, treated as forcing vars):
ardl(y ~ k + d56 + d74 + d80, order = c(2, 4), data = df)
# This would require order = c(p, q_k, q_d56, q_d74, q_d80) — incorrect
```

#### Long-run coefficient access pattern
```r
lr <- multipliers(ardl_s0, type = "lr")
theta_hat <- lr["k", "Estimate"]       # capital LR elasticity
a_hat     <- lr["(Intercept)", "Estimate"]  # intercept (Case III)
c_d74     <- lr["d74", "Estimate"]     # d74 LR multiplier
c_d56     <- lr["d56", "Estimate"]     # d56 LR multiplier
c_d80     <- lr["d80", "Estimate"]     # d80 LR multiplier
```

---

### A.2 tsDyn Package (Stigler 2020)

**Reference:** Stigler, M. (2020). Nonlinear time series in R: Threshold cointegration with tsDyn. In *Handbook of Statistics* (Vol. 42, pp. 229–264). Elsevier.

#### Key functions

```r
# VECM ESTIMATION
VECM(data, lag, r = 1,
     include = c("const", "trend", "none", "both"),
     estim   = c("2OLS", "ML"),
     LRinclude = c("none", "const", "trend", "both"),
     exogen = NULL,
     beta   = NULL)
# data:     matrix or ts object, columns = variables (oldest row first)
# lag:      ECM lags = VAR lag order - 1
#           If VAR(p), then VECM uses lag = p-1 lags of differences
# r:        cointegrating rank
# include:  deterministic terms in SHORT-RUN equation
#   "const" = unrestricted intercept (maps to Johansen Case III)
#   "none"  = no short-run deterministic terms
#   "trend" = unrestricted trend
#   "both"  = unrestricted intercept + trend
# LRinclude: deterministic terms RESTRICTED to long-run (cointegrating eq)
#   "const" = restricted constant (maps to Johansen Case II)
#   "trend" = restricted trend (maps to Johansen Case IV)
#   "none"  = no restricted LR terms (default)
# estim:    "ML" = Johansen MLE (use this); "2OLS" = Engle-Granger two-step
# exogen:   matrix of exogenous regressors (same rows as data after lag trimming)
#           rows must align with estimation sample, not full data
# beta:     pre-specified cointegrating vector (if NULL, estimated)
# Returns:  object of class c("VECM", "nlVar")

# DETERMINISTIC BRANCH MAPPING (d parameter in L_S2 lattice):
# d0 (no terms):         include="none",  LRinclude="none"
# d1 (const in LR only): include="none",  LRinclude="const"  [Johansen Case II]
# d2 (unrestr. const):   include="const", LRinclude="none"   [Johansen Case III]
# d3 (const + trend):    include="both",  LRinclude="none"   [Johansen Case V]

# COEFFICIENT EXTRACTION (use tsDyn functions, NOT base coef()):
coefB(vecm_fit)   # beta: cointegrating vectors, dim = (m x r)
coefA(vecm_fit)   # alpha: adjustment (loading) matrix, dim = (m x r)
coefPI(vecm_fit)  # Pi = alpha %*% t(beta): reduced-form LR matrix

# RANK SELECTION (tsDyn native — alternative to ca.jo from urca)
rank.select(data, lag.max = 10,
            include = c("const","trend","none","both"))
# Returns AIC, BIC, HQ-optimal (rank, lag) pairs simultaneously
# More convenient than ca.jo for grid scanning

rank.test(vecm_fit)
# Johansen trace and max-eigenvalue tests on an existing VECM object
# More intuitive output than ca.jo

# LAG SELECTION
lags.select(data, lag.max = 10,
            include = c("const","trend","none","both"),
            fitMeasure = c("SSR","LL"), sameSample = TRUE)
# Returns AIC/BIC/HQ across lag values

# IC EXTRACTION:
AIC(vecm_fit)
BIC(vecm_fit)
logLik(vecm_fit)   # scalar log-likelihood

# DOWNSTREAM ANALYSIS (via conversion to vars package):
# tsDyn:::vec2var.tsDyn(vecm_fit) converts to vars vec2var object
# Enables: fevd(), serial.test(), arch.test() from vars package
```

#### Exogen argument — critical alignment
```r
# exogen must be a matrix aligned to the ESTIMATION SAMPLE (after lag trimming)
# If VECM uses lag=1 on T=63 obs, estimation sample has T-1=62 rows
# Build correctly:
T_eff <- nrow(X) - (p_lag - 1)   # rows used in estimation
dum_mat <- if (!is.null(h_dum)) {
  as.matrix(df[tail(seq_len(nrow(df)), T_eff), h_dum, drop = FALSE])
} else NULL
vecm_fit <- VECM(X, lag = p_lag - 1, r = r_rank,
                 estim = "ML", include = d_det,
                 LRinclude = LRinclude_val,
                 exogen = dum_mat)
```

---

### A.3 urca Package — ca.jo() for Johansen Tests

```r
ca.jo(x, type = c("trace", "eigen"),
      ecdet = c("none", "const", "trend"),
      K = 2,             # VAR lag order (NOT VECM lags)
      spec = "longrun",  # or "transitory"
      dumvar = NULL)     # matrix of dummy variables
# ecdet: "none"=no restricted LR terms, "const"=restricted constant (Case II),
#        "trend"=restricted trend (Case IV)
# K: VAR lag order. VECM lag = K-1.
# Aligns with Johansen cases: ecdet="none"+no trend → Case III (unrestricted const)

# Results access:
jo_result <- ca.jo(X, type="trace", ecdet="none", K=p_lag, dumvar=dum_mat)
jo_result@teststat   # trace statistics — ordering: teststat[1]=H0:rank<=m-1, teststat[m]=H0:rank<=0
jo_result@cval       # critical values matrix, same ordering
# CORRECT admissibility check: reject H0: rank < r  →  use index (m - r + 1)
# idx <- m_dim - r_rank + 1
# teststat[idx] > cval[idx, "5pct"]
# WARNING: teststat[r_rank] > cval[r_rank, "5pct"] is WRONG for standard (m=2, r=1) cases

# NOTE on ecdet mapping from tsDyn include/LRinclude:
# tsDyn include="const", LRinclude="none" → ca.jo ecdet="none"  (Case III)
# tsDyn include="none",  LRinclude="const"→ ca.jo ecdet="const" (Case II)
# tsDyn include="both",  LRinclude="none" → ca.jo ecdet="none"  (Case V with trend)
```

---

_Package specs appendix added: v2 | 2026-03-11_
_Sources: ARDL v0.2.4 manual; NatsiopoulosTzeremes2024; tsDyn manual; Stigler2020_
