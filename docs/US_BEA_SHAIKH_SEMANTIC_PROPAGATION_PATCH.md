# U.S. BEA Shaikh Semantic Propagation Patch

**Patch date:** 2026-06-09

## Purpose

The candidate-line semantic audit showed that all eight staged NIPA Table 7.11
lines exist, but the complete Shaikh-style formula is not semantically
admissible under the current BEA release. This patch propagates that result
through the provider contract, validation report, execution report, and locked
metadata.

## Files Patched

- `codes/10_bea_api_helpers.R`
- `codes/90_validate_variable_menu.R`
- `data/metadata/us_bea_variable_menu_locked.csv`
- `data/metadata/us_bea_variable_menu_locked.json`
- `data/metadata/us_bea_source_provenance_ledger.csv`
- `docs/US_BEA_VARIABLE_MENU_PROVIDER_CONTRACT.md`
- `docs/US_BEA_VARIABLE_MENU_VALIDATION_REPORT.md`
- `docs/US_BEA_VARIABLE_MENU_EXECUTION_REPORT.md`

## Locks

- T711 line presence and provenance: `PASS`.
- Shaikh formula semantic admissibility: `BLOCKED`.
- `BankMonIntPaid`, `CorpNFNetImpIntPaid`, `CorpImpIntAdj_t`, and all
  Shaikh-adjusted derivatives remain blocked pending a documented
  historical/current semantic crosswalk.
- Wage share (`omega_t`) is the preferred downstream distributive state.
- Exploitation rate (`e_t`) is retained only as an alternative proxy.

No BEA fetch was run. Raw and staged observations were not regenerated or
modified.
