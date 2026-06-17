# Stock-Flow Labour-Value Accounting

Title: Stock-Flow Labour-Value Accounting: A Reproducible Protocol for Translating Shaikh-Tonak Concepts into BEA/NIPA Candidates

## 1. Purpose

This artifact presents a reproducible protocol for translating labour-value accounting concepts into official-account data candidates. It is designed for provider-side documentation, future Skill use, later Shiny app framing, and dissertation-method appendix development.

This is not a BEA line-number replication tool. It is not a claim to produce "the true Shaikh series." It is not authorization to construct adjusted variables. It is a conceptual and operational framework for deciding what each candidate measures, how it fits the accounts, which risks it carries, and whether it is ready, blocked, or only a documentation/reconciliation candidate.

## 2. Theoretical Hierarchy

The hierarchy is:

1. Stock-flow labour-value consistency governs the protocol.
2. Shaikh and Tonak provide theoretical inspiration for productive/nonproductive distinctions.
3. Shaikh 2016 Appendix 6.7 is a benchmark empirical example to replicate conceptually, not mechanically.
4. Banking and finance are not productive capital in this protocol; they may express claims on surplus, monopoly power, or transfer/appropriation channels.
5. BEA/NIPA and SNA official accounting are operational terrain, not theoretical authority.
6. The BEA API guide defines operational retrieval rules.
7. Qwen and deep-research synthesis are subordinate: use them only for plausible searches, hypotheses, exposition, or checks that require validation.

## 3. Two Governing Laws

The first law is stock-flow consistency. Every candidate must sit coherently inside the account ladder:

`GVA -> GOS -> NOS -> profit / interest / rent / transfer decompositions`

The second law is no double accounting. The same surplus, transfer, financial claim, interest flow, or decomposition object must not be counted twice. A candidate that uses both payer-side and receiver-side interest flows must show whether those are distinct correction ingredients or mirror views of the same transfer.

## 4. Account Ladder

GVA is gross value added. It is net of intermediate inputs and is not profit. It is not net of compensation, taxes less subsidies, CFC, actual interest, or corporate profits.

GOS is gross operating surplus. It sits below GVA after compensation and taxes less subsidies. It is gross of CFC and is not corporate profit.

NOS is net operating surplus. It sits below GOS after CFC. It is not after-interest profit and must not be treated as corporate profits.

Corporate profits are a downstream profit-type decomposition. They are not an add-back to NOS.

Net interest is a property-income or claim object. Its direction must be stated as interest paid minus interest received, or the current BEA line-specific net direction if different.

Imputed interest and financial-service imputations may be official-accounting output or allocation objects. In this protocol they may be correction ingredients or claims, not productive value by default.

Compensation is the labour-income component of the income account. CFC is the bridge between gross and net surplus. Taxes less subsidies are part of the GVA-to-GOS allocation. Transfers are redistribution or appropriation flows, not production-account value added.

## 5. Shaikh And Tonak Foundation

Shaikh and Tonak motivate the distinction between activities that create new wealth and activities that use, transfer, circulate, administer, protect, or appropriate existing surplus. Official accounts may classify military, bureaucratic, financial, and circulation activities as production. The labour-value framework asks a different question: whether the activity creates new value or is better treated as a transfer, claim, circulation cost, or correction.

This protocol does not solve every theoretical boundary. Commercial capital remains blurred in the current operationalization and must be flagged rather than silently absorbed into a clean productive boundary.

## 6. Shaikh 2016 Appendix 6.7 Benchmark

Appendix 6.7 is a benchmark example, not a mechanical line-number recipe. Its value is conceptual: it shows how Shaikh-style national-account corrections can be organized through corporate and business income-account objects. It does not authorize reusing old BEA line numbers in current releases.

Important caveats:

- Historical BEA table structures and line meanings may differ from current releases.
- GDP/GNP, domestic/business, corporate/business, and NFC/corporate boundaries are distinct and must not be silently substituted.
- The operating-surplus ladder must remain coherent: GVA flows through GOS and NOS rather than jumping directly to profits.
- Business-sector restrictions and wage-equivalent logic require separate boundary review.
- Imputed-interest correction is a conceptual problem before it is a line-matching problem.
- Current-release line matching requires concept-first review of metadata, signs, frequency, units, years, and sector definitions.

## 7. Finance, Banking, And Imputed-Interest Correction

Banking and finance are not productive capital in this protocol. Financial corporate lines may be correction ingredients, claims on surplus, monopoly-power channels, or transfer/appropriation channels.

Official FISIM/output treatment does not settle the labour-value interpretation. Official accounts may record financial services as output; this protocol still requires a labour-value classification before any candidate is used. Financial-service and imputed-interest lines must pass the `financial_intermediation_imputation_gate` and the double-accounting gate.

The core risks are:

- treating financial income or interest receipts as newly created productive value;
- counting the same interest flow from both payer and receiver sides;
- adding a downstream profit or interest decomposition back into NOS;
- using an imputed-interest correction as a constructed adjusted series before human review.

## 8. BEA API Operational Crosswalk

Do not search for Shaikh acronyms as BEA variables. Search official BEA/NIPA concepts and metadata. Use metadata-first discovery:

- datasets;
- parameters;
- table names;
- line descriptions;
- frequencies;
- units;
- years.

Only after metadata discovery should candidates be mapped to conceptual objects and ledger statuses.

Acronym-to-concept clarification:

- `BankNetIntPaid` = conceptual financial corporate net interest paid object, not an API name.
- `NFNetImpIntPaid` = conceptual nonfinancial corporate/business net imputed interest object, not an API name.
- `CorpImpIntAdj` = conceptual corporate imputed-interest adjustment formula, not an API name.
- `BusImpIntAdj` = conceptual business imputed-interest adjustment formula, not an API name.

Current BEA line matching is subordinate to conceptual classification.

## 9. Candidate Statuses

Use the Skill statuses:

- `READY_AS_BASELINE`
- `READY_AS_ROBUSTNESS_CANDIDATE`
- `DOCUMENTATION_AND_RECONCILIATION_CANDIDATE`
- `THEORETICALLY_MIXED_REVIEW_REQUIRED`
- `BLOCKED_DOUBLE_COUNTING_RISK`
- `BLOCKED_STOCK_FLOW_INCONSISTENT`

Current classification:

- `WAGE_SHARE_UNADJUSTED_NFC_GVA_BASELINE` = `READY_AS_BASELINE`
- `CORP_IMPUTED_INTEREST_ADJ` = `DOCUMENTATION_AND_RECONCILIATION_CANDIDATE`
- `CORP_SHAIKH_OPERATING_LADDER_RECONCILIATION_BUNDLE` = `DOCUMENTATION_AND_RECONCILIATION_CANDIDATE`
- business-wide Shaikh objects = `THEORETICALLY_MIXED_REVIEW_REQUIRED`
- adding corporate profits to NOS = blocked by stock-flow inconsistency and double-counting risk

No candidate status is changed by this research artifact.

## 10. Skill And Shiny Implications

The Skill is a reasoning/check protocol. It tells a future agent how to classify concepts, require ledger fields, apply gates, and report candidate statuses without constructing adjusted variables.

A future Shiny app could be an exploration interface over the same backend schemas. Possible tabs include source tables, concept map, sector boundaries, candidate variables, stock-flow checks, double-counting checks, line-matching readiness, and export.

The provider repo backend remains: fetch, classify, check, status, and export only when authorized. This pass does not create a Shiny app.

## 11. Current Limits

No adjusted Shaikh series has been constructed. No provider handoff is authorized. No regression use is authorized. Commercial capital remains blurred and must be flagged. Qwen and deep-research claims require validation against the source hierarchy. Current-release BEA matching remains candidate-level, not final.

The most important unresolved issues are conceptual classification, sign convention, sector boundary, financial/intermediation interpretation, and whether any documentation/reconciliation candidate could ever graduate after human review.

## 12. Conclusion

This project contributes a reproducible accounting protocol for translating labour-value concepts into official national-account candidates while preserving stock-flow consistency, avoiding double counting, and separating productive value creation from financial claims, transfers, and accounting corrections.
