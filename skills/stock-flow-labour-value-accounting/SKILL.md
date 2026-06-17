---
name: stock-flow-labour-value-accounting
description: Protocol for translating labour-value accounting concepts into BEA/NIPA variable candidates while checking stock-flow consistency, double accounting, sector boundaries, finance/banking treatment, and candidate status. Use for GVA, VA/NVA, GOS, NOS, corporate profits, net interest, imputed interest, compensation, CFC, taxes less subsidies, transfers, corporate/NFC/business boundaries, and Shaikh/Tonak-inspired national-account corrections.
---

# Stock-Flow Labour-Value Accounting Check

## Purpose

Use this Skill as a protocol/checklist for translating labour-value accounting concepts into BEA/NIPA candidates. It does not decide theory. It forces each candidate to document what it measures, where it sits in the accounts, what it may be used for, and which gates it must pass before any downstream construction is considered.

## When To Use

Use this Skill when working with:

- GVA, VA/NVA, GOS, NOS, and corporate profits.
- Net interest, imputed interest, compensation, CFC, taxes less subsidies, and transfers.
- Corporate, nonfinancial corporate, financial corporate, noncorporate, or business-wide sector boundaries.
- Shaikh/Tonak-inspired national-account corrections.
- BEA/NIPA candidate searches that need theory-aware accounting discipline.

## When Not To Use

Do not use this Skill to:

- Construct adjusted Shaikh time series or model-input panel variables.
- Create provider handoffs or authorize downstream use.
- Run econometrics, reconstruct GPIM, estimate theta, productive capacity, utilization, or accumulated q.
- Create a Shiny app.
- Treat Shaikh-side labels as official BEA/FRED variable names.
- Mechanically replicate historical Appendix 6.7 line numbers.

## Theoretical Hierarchy

1. Stock-flow consistency in labour-value theory governs the check.
2. Shaikh and Tonak provide theoretical inspiration for productive/nonproductive distinctions.
3. Shaikh 2016 Appendix 6.7 is a benchmark empirical example to replicate conceptually, not mechanically.
4. Banking and finance are not productive capital. They may express claims on surplus, monopoly power, or transfer/appropriation channels.
5. BEA/NIPA and SNA official accounting are operational accounting terrain, not theoretical authority.
6. The BEA API guide defines operational retrieval rules.
7. Deep-research synthesis may strengthen exposition and workflow design, but it is not authority by itself.
8. Qwen research is subordinate: use it only for plausible searches and hypotheses requiring validation.
9. Commercial capital remains blurred and must be flagged as an accepted limitation, not silently solved.

## Two Governing Laws

1. Stock-flow consistency: every candidate must preserve its position in the GVA -> GOS -> NOS account ladder.
2. No double accounting: the same surplus, transfer, financial claim, interest flow, or decomposition object must not be counted twice.

## Account Ladder

Use the ladder as an accounting discipline:

- GVA is the production-account top object.
- GOS is below GVA after compensation and production taxes less subsidies.
- NOS is below GOS after CFC.
- Corporate profits, net interest, imputed interest, and transfers are decomposition, property-income, claim, transfer, or correction objects. They are not substitutes for GVA, GOS, or NOS.

## Official Accounting Grammar

Official accounts may define financial services and FISIM as output. That official treatment does not settle the labour-value interpretation. GVA, GOS, NOS, profits, interest, and transfers sit in different account positions. GOS and NOS are operating-surplus residuals, not corporate profits. Profits and interest are downstream decompositions or claims, not objects to add back into NOS.

## Net Of What

Require every candidate to state:

- What it is net of.
- What it is not net of.
- Whether it is gross or net of CFC.
- Whether it is a flow, residual, transfer, financial claim, or accounting correction.

Current definitions:

- GVA is net of intermediate inputs, not net of compensation, taxes less subsidies, CFC, actual interest, or profits.
- GOS is net of compensation and taxes less subsidies, gross of CFC, and not equivalent to corporate profits.
- NOS is net of CFC, not net of actual interest, and not equivalent to after-interest profit.
- Corporate profits are a downstream profit-type decomposition of NOS. Do not add them to NOS.
- Net interest direction must be stated as interest paid minus interest received, or the current BEA line-specific net direction if different.

## Boundary Checks

For every candidate, identify:

- Sector boundary: corporate, nonfinancial corporate, financial corporate, noncorporate, business-wide, household, government, or mixed.
- Legal-form boundary: corporate, noncorporate, household, government, or not a BEA legal-form boundary.
- Whether financial corporate lines are present.
- Whether commercial capital is blurred.
- Whether the candidate can replace an existing baseline. Default answer: no, unless explicitly authorized outside this Skill.

## BEA API Operational Rule

Do not search for Shaikh labels as BEA variables. Search by official BEA/NIPA concepts and metadata: datasets, parameters, table names, line descriptions, frequencies, and years. Shaikh acronyms such as `BankNetIntPaid`, `NFNetImpIntPaid`, `CorpImpIntAdj`, and `BusImpIntAdj` are conceptual labels, not API names. Current BEA line matching is subordinate to conceptual classification.

## Finance And Banking Treatment

Do not treat finance or banking as productive capital. Financial corporate interest, receipts, imputed services, and related lines may be:

- claim_on_surplus;
- monopoly_power_channel;
- transfer_appropriation_channel;
- correction_ingredient_only;
- mixed_review.

They must not be treated as newly produced productive value. If a candidate uses financial corporate lines, route it through a double-accounting gate and a productive-value-claim check.

If financial-service or imputed-interest lines are present, also apply the `financial_intermediation_imputation_gate`: state whether each line is official-accounting output, a correction ingredient, a claim on surplus, a monopoly-power channel, or a transfer/appropriation channel. Do not let official FISIM/output treatment become a labour-value productive-value claim.

## Commercial-Capital Limitation

Commercial capital is not silently solved by BEA/NIPA legal-form categories. Flag it as blurred when a candidate crosses business-wide, corporate, noncorporate, wholesale/retail, or circulation-activity boundaries. Use `THEORETICALLY_MIXED_REVIEW_REQUIRED` when the object is conceptually plausible but the boundary is unresolved.

## Candidate Questions

Every candidate must answer:

- What does this object measure?
- What is it net of?
- What is it not net of?
- Which sector boundary does it belong to?
- Is it a stock, flow, residual, transfer, claim, or correction?
- Does it preserve the GVA -> GOS -> NOS ladder?
- Does it count the same flow twice?
- Does it treat finance as productive value?
- Is commercial capital blurred?
- What use is allowed?
- What use is prohibited?
- What is the candidate status?

## Candidate Statuses

Use only these statuses unless a project-specific ledger extends them:

- `READY_AS_BASELINE`
- `READY_AS_ROBUSTNESS_CANDIDATE`
- `DOCUMENTATION_AND_RECONCILIATION_CANDIDATE`
- `THEORETICALLY_MIXED_REVIEW_REQUIRED`
- `BLOCKED_DOUBLE_COUNTING_RISK`
- `BLOCKED_STOCK_FLOW_INCONSISTENT`

Current expected classification from S20E-CL-PATCH:

- `WAGE_SHARE_UNADJUSTED_NFC_GVA_BASELINE` = `READY_AS_BASELINE`
- `CORP_IMPUTED_INTEREST_ADJ` = `DOCUMENTATION_AND_RECONCILIATION_CANDIDATE`
- `CORP_SHAIKH_OPERATING_LADDER_RECONCILIATION_BUNDLE` = `DOCUMENTATION_AND_RECONCILIATION_CANDIDATE`
- business-wide Shaikh objects = `THEORETICALLY_MIXED_REVIEW_REQUIRED`
- adding corporate profits to NOS = `BLOCKED_STOCK_FLOW_INCONSISTENT` or `BLOCKED_DOUBLE_COUNTING_RISK`

## Required Ledgers

Maintain these ledgers or their project-specific equivalents:

- Conceptual account ladder ledger.
- Sector boundary ledger.
- Stock-flow consistency gate.
- Double-accounting gate.
- Candidate menu.
- Line-matching readiness ledger.
- Graduation criteria ledger.
- Validation ledger.

Use bundled schema files in `schema/` and CSV templates in `templates/` when starting a new check.

## Source Hygiene

Do not use Qwen as authority. Do not use public web summaries as authority for Shaikh/Tonak theory. Do not use old Appendix 6.7 line numbers mechanically. Do not use the deep-research report as authority by itself. Use deep research only to improve exposition, identify missing checks, and point to official/accounting sources for later verification.

## Forbidden Moves

Do not:

- Construct adjusted variables.
- Create model-input panels.
- Create a provider handoff.
- Run regressions or econometrics.
- Reconstruct GPIM or estimate theta.
- Construct productive capacity, utilization, or accumulated q.
- Create Shiny outputs.
- Copy source PDFs or quote long copyrighted passages.
- Treat Shaikh labels such as `BankNetIntPaid`, `NFNetImpIntPaid`, `CorpImpIntAdj`, or `BusImpIntAdj` as official BEA/FRED variable names.

## Output Expectations

At completion, report:

- Files created or changed.
- Candidate status summary.
- Stock-flow gate summary.
- Double-accounting gate summary.
- Whether any candidate graduated.
- Whether any handoff was created.
- Validation result.
- Final status.

If no construction is authorized, make that explicit.
