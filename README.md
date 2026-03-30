# Critical-Replication-Shaikh
### Chapter 1 — Track A: Critical Replication of Shaikh (2016)
**Dissertation**: *A Historical Trace of Capacity Utilization Measurements*
**Author**: Diego Polanco | UMass Amherst | Supervisor: Michael Ash

## Overview
Three-stage specification audit of Shaikh (2016) ARDL estimation of productive capacity, US corporate sector. Central estimand: capital elasticity θ in `ln Y = a + b·t + θ·ln K + ε`.

## Three-Stage Results
| Stage | Method | θ | Status |
|-------|--------|---|--------|
| S0 | ARDL(2,4) Case II, T=61 | 0.749 | ✅ Complete |
| S1 | 500-spec grid → 14 admissible | 0.592 [0.43, 0.79] | ✅ Complete |
| S2 bivariate | VECM rank r=1 | [0.88, 0.91] | ✅ Complete |
| S3 | Gregory-Hansen / Bai-Perron | — | 🔲 Pending |

## Locked Data Decisions
| Decision | Value |
|----------|-------|
| Capital series | KGCcorp (BEA gross current-cost) |
| Deflator | pIGcorpbea |
| Output | VAcorp |
| Sample | T=61 (1947–2007) |

## Structure
- `codes/` — pipeline scripts 10–99
- `data/raw/` — Shaikh canonical series (do not modify)
- `output/CriticalReplication/figures/` — fig_*.png + fig_*.pdf
- `docs/` — methodology notes and handoffs

## Branch Strategy
- `main`: validated results only
- Feature branches per stage: merge only after validation gate (corr ≥ 0.90)
