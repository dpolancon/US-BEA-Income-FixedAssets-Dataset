# V1 Release Notes

Final status: `V1_PROVIDER_DATASET_RELEASE_CREATED_NO_DOWNSTREAM_IMPORT`

## What V1 Contains

- `V1_SOURCE_PANEL_LONG.csv`: long-form staged provider source observations plus S20E metadata/status rows.
- `V1_VARIABLE_MENU.csv`: source and candidate menu with allowed/prohibited uses.
- `V1_CONCEPT_REGISTRY.csv`: account ladder and sector-boundary concepts from S20E-CL.
- `V1_SOURCE_METADATA_LEDGER.csv`: provider provenance and line-matching readiness metadata.
- `V1_CANDIDATE_STATUS_LEDGER.csv`: candidate statuses and construction/handoff permissions.
- `V1_BLOCKED_PARKED_LEDGER.csv`: blocked, parked, and out-of-scope objects.
- `V1_DOWNSTREAM_CONSUMPTION_CONTRACT.md`: future Chapter 2 import contract.
- `V1_VALIDATION_CHECKS.csv`: release validation checks.

## What V1 Excludes

V1 excludes adjusted Shaikh variables, constructed corporate Shaikh adjusted GVA/GOS/NOS, adjusted wage/profit shares, model-input panels, provider handoffs, Shiny apps, econometrics, GPIM reconstruction, theta estimation, productive capacity, utilization, and accumulated q.

## Relation To Skill And Research Artifact

The Stock-Flow Labour-Value Accounting Skill informs classification, gate language, and candidate statuses. The research artifact provides dissertation-facing framing and source hygiene. Neither authorizes construction by itself.

## Relation To S20E Conceptual Work

S20E-CL remains `S20E_CL_CONCEPTUAL_LEDGER_COMPLETE_NO_CONSTRUCTION`. Shaikh-adjusted corporate objects remain documentation/reconciliation candidates only.

## Downstream Risks

The main downstream risks are premature candidate graduation, mechanical Appendix 6.7 line-number reuse, treating finance as productive capital, commercial-capital blur, and direct model use before a Chapter 2 import/validation pass.

## No-Construction Boundary

This V1 release is provider-side data and metadata only. It does not construct adjusted Shaikh series or perform downstream modelling.
