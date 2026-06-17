# Stock-Flow Labour-Value Accounting Skill

This Skill provides a protocol for checking labour-value accounting concepts before translating them into BEA/NIPA candidates. It exists to keep dissertation data work consistent with stock-flow accounting, no-double-accounting discipline, and clear productive/nonproductive boundary flags.

It supports a reproducible accounting protocol for translating labour-value concepts into official-account data candidates. It helps document what each candidate measures, what it is net of, which sector boundary it uses, what financial/transfer risks it carries, and whether it is ready, blocked, or only a documentation/reconciliation candidate.

It is based on the S20E-CL-PATCH conceptual schema and is meant to support future provider-side source discovery, ledger design, and Shiny app planning. It can help structure future app controls and validation panels, but it does not create a Shiny app. The same schemas can later serve as the backend for a Shiny app with tabs for source tables, concept map, sector boundaries, candidate variables, stock-flow checks, double-counting checks, and export.

This is not a BEA line-number replication tool. It is a protocol for theory-aware national-account variable construction.

It is not a claim to produce "the true Shaikh series." It does not construct adjusted Shaikh variables, create model-input panels, authorize provider handoffs, run econometrics, reconstruct GPIM, estimate theta, or decide theory as an AI authority.

BEA API operational rule: do not search for Shaikh labels as BEA variables. Search by official BEA/NIPA concepts and metadata, including datasets, parameters, table names, line descriptions, frequencies, and years. Current BEA line matching remains subordinate to conceptual classification.
