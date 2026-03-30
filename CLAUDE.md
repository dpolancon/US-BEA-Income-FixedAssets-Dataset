# CLAUDE.md — Critical-Replication-Shaikh
## Chapter 1: Track A — Critical Replication of Shaikh (2016)

**Dissertation**: *A Historical Trace of Capacity Utilization Measurements*
**Author**: Diego Polanco | UMass Amherst | Supervisor: Michael Ash
**Last updated**: 2026-03-15

---

## 1. What this repo is

This is the Chapter 1 empirical pipeline. The object is a three-stage
specification audit of Shaikh (2016) ARDL estimation of productive capacity
for the US corporate sector (S0 faithful replication → S1 model uncertainty
→ S2 VECM system identification).

This is NOT Track B. Track B lives in Capacity-Utilization-US_Chile.

---

## 2. Locked data decisions — NEVER modify without explicit instruction

These four decisions are fixed. Any sensitivity run that changes one must
create a new named data object, not silently overwrite:

| Decision | Locked value |
|----------|-------------|
| Data source | data/raw/Shaikh_canonical_series_v1.csv |
| Capital series | KGCcorp (BEA gross current-cost) |
| Deflator | pIGcorpbea (investment deflator) |
| Output series | VAcorp (corporate value added) |
| Sample | T=61 (1947-2007) |

DO NOT:
- Modify codes/10_config.R data_shaikh, y_nom, k_nom, or p_index fields
- Create or reference data/processed/corporate_sector_dataset.csv
- Switch deflator to Py (GDP implicit price deflator)
- Switch output series to GVAcorp or GVA_nfc without explicit instruction

---

## 3. Branch strategy — NEVER push directly to main

- main: validated results only — requires S7 validation gate (corr >= 0.90)
- Active work: always on a named feature branch
- Naming: track-a-{stage}-{label} (e.g. track-a-s3-gregory-hansen)
- Merge to main only after validation gate passes and Diego approves

DO NOT auto-merge pull requests. Always stop and ask for review.

---

## 4. Three-stage architecture

| Stage | Script | Status |
|-------|--------|--------|
| S0 | codes/20_S0_shaikh_faithful.R | Complete |
| S1 | codes/21_S1_ardl_geometry.R | Complete |
| S2 bivariate | codes/22_S2_vecm_bivariate.R | Complete |
| S2 trivariate | codes/23_S2_vecm_trivariate.R | Complete |
| S3 | codes/26_S3_regime_break.R | Pending |

Key results locked in RESULTS_BRIEF.md:
- S0: theta = 0.749, Case II, ARDL(2,4), T=61
- S1: IC consensus ARDL(1,3) Case II, theta-bar = 0.592, range [0.43, 0.79]
- S2 bivariate: all 4 ICs -> theta in [0.88, 0.91]
- S2 trivariate: ~2% admissibility — bivariate is inference boundary

---

## 5. Repo structure

codes/
  10_config.R               <- LOCKED — do not modify data decisions
  20_S0_shaikh_faithful.R   <- S0 faithful replication
  21_S1_ardl_geometry.R     <- S1 500-spec grid
  22_S2_vecm_bivariate.R    <- S2 bivariate VECM
  23_S2_vecm_trivariate.R   <- S2 trivariate VECM
  24_manifest_runner.R      <- pipeline orchestrator
  40-49_*.R                 <- GDP and capital stock series
  50-55_*.R                 <- corporate sector series
  98_ardl_helpers.R         <- ARDL helpers
  99_figure_protocol.R      <- save_png_pdf_dual() — use this, not ggsave
  99_utils.R                <- shared utilities
data/raw/                   <- source of truth — do not modify
output/CriticalReplication/ <- all outputs go here
docs/                       <- methodology notes

---

## 6. What NOT to do

- Do not modify 10_config.R locked decisions
- Do not reference corporate_sector_dataset.csv
- Do not push directly to main
- Do not auto-merge pull requests — always stop for Diego review
- Do not use asymptotic PSS critical values — exact=TRUE on all bounds tests
- Do not run Track B code — that lives in Capacity-Utilization-US_Chile
- Do not use ad-hoc ggsave — always save_png_pdf_dual() from 99_figure_protocol.R
- All deliverable documents: .md files only — never Word/docx
