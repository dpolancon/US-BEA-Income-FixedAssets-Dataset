# U.S. BEA Shaikh Candidate-Line Semantic Audit

**Audit date:** 2026-06-09  
**Scope:** NIPA Table 7.11 candidate ingredients only  
**Decision:** Downstream construction is blocked pending a legacy-to-current semantic crosswalk.

## Audit Boundary

This audit does not construct `BankMonIntPaid`, `CorpNFNetImpIntPaid`,
`CorpImpIntAdj`, adjusted income accounts, distributive variables, or any
Chapter 2 analytical object. It tests whether the eight currently staged line
numbers still carry semantics compatible with their proposed formula roles.

Line-number existence is not evidence of semantic continuity across BEA
revisions.

## Sources Inspected

- `data/raw/provider/2026-06-09/NIPA_T71100.csv`
- `data/staged/us_bea_variable_menu_long.csv`
- `data/metadata/us_bea_variable_menu_locked.csv`
- `data/metadata/us_bea_source_provenance_ledger.csv`
- Live BEA NIPA API metadata for `T71100`, annual frequency, 2024 observation

The current API response identifies Table 7.11 as *Interest Paid and Received
by Sector and Legal Form of Organization*, last revised September 26, 2025.
The inspected API response was produced June 9, 2026 at 19:53:58.613 UTC.

The API exposes line number, description, series code, unit multiplier, note
references, and release notes, but no explicit parent identifier. Hierarchies
below are therefore inferred from ordered parent lines and BEA's embedded line
formulas. API `UNIT_MULT=6` means the staged values are in millions of current
dollars; the published table display note describes billions of dollars.

## Candidate Findings

| Candidate | Current meaning | Semantic status | Formula admissibility |
| --- | --- | --- | --- |
| `T711_L4` | Financial corporate monetary interest paid | `verified_current_equivalent` | Individually admissible |
| `T711_L44` | Imputed interest paid by banks, credit agencies, and investment companies | `plausible_but_narrower_than_legacy` | Blocked pending crosswalk |
| `T711_L73` | Federal government imputed interest received | `line_exists_but_semantics_unclear` | Blocked |
| `T711_L28` | Financial corporate monetary interest received | `verified_current_equivalent` | Individually admissible |
| `T711_L52` | State and local government imputed interest paid, first block | `line_exists_but_semantics_unclear` | Blocked |
| `T711_L91` | Government imputed interest paid, second block | `plausible_but_broader_than_legacy` | Blocked pending crosswalk |
| `T711_L74` | State and local government imputed interest received | `not_currently_admissible` | Blocked |
| `T711_L53` | Rest-of-world imputed interest paid | `not_currently_admissible` | Blocked |

All eight lines exist in the current release. Existence is the only conclusion
that can be drawn uniformly across the set.

## BankMonIntPaid Candidate Block

Lines 4 and 28 retain clear, symmetric financial-corporate monetary-interest
meanings. They can serve as provider ingredients for paid and received
monetary interest.

Line 44 is narrower: it covers banks, credit agencies, and investment
companies within the financial branch. It excludes other financial
subsectors, so it is a proxy unless a historical crosswalk establishes that
this narrower scope is the intended legacy object.

Lines 73 and 52 are federal and state/local government branches in different
imputed-interest directions. Line 91 is a broad government aggregate in the
second imputed-interest-paid block. Their roles in a bank monetary-interest
formula are not established by current descriptions or hierarchy. The
six-term candidate formula is therefore not currently admissible.

## CorpNFNetImpIntPaid Candidate Block

The current L74/L53 pair fails the sector test:

- L74 is state and local government imputed interest received.
- L53 is rest-of-world imputed interest paid.

Neither line is a nonfinancial-corporate item. L53 also begins in 1986, while
the other candidates generally begin in 1946. The pair cannot be treated as a
proxy for nonfinancial-corporate net imputed interest.

## Downstream Decision

Construction of `CorpImpIntAdj_t` is **blocked**.

It may be reconsidered only after a documented legacy-to-current crosswalk
verifies historical line descriptions or series codes and identifies current
NFC-equivalent paid and received lines. Any future use of L44 or L91 must state
their narrower or broader scope explicitly.

The provider remains able to stage these observations as candidate source
lines. Staged status means the data exist and have provenance; it does not mean
they are semantically admissible for the Shaikh-style formula.

## Re-Lock Condition

The provider package is not ready to be re-locked for downstream construction
of the Shaikh correction. It is ready for downstream import only as a
candidate-line provider with the correction blocked. Re-locking the correction
requires resolving L44, L73, L52, L91, L74, and L53 through a documented
historical crosswalk.
