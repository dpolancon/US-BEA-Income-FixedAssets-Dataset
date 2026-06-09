# U.S. BEA Variable Menu Execution Report

**Execution date:** 2026-06-09

## Result

The repository now has an active provider-only architecture on branch
`feature/us-bea-variable-menu-provider-lock`.

- Locked manifest variables: 175
- Staged source variables: 94
- Staged annual observations: 9,438
- Coverage: 1901-2025
- Required variables staged: 69
- Validation hard checks: all pass

## Files Created

- `codes/10_bea_api_helpers.R`
- `codes/20_fetch_fixed_assets_menu.R`
- `codes/30_fetch_income_accounts_menu.R`
- `codes/40_stage_variable_menu_long.R`
- `codes/90_validate_variable_menu.R`
- `data/metadata/us_bea_variable_menu_locked.csv`
- `data/metadata/us_bea_variable_menu_locked.json`
- `data/metadata/us_bea_source_provenance_ledger.csv`
- `data/staged/us_bea_variable_menu_long.csv`
- `docs/US_BEA_VARIABLE_MENU_PROVIDER_CONTRACT.md`
- `docs/US_BEA_VARIABLE_MENU_VALIDATION_REPORT.md`

Live raw snapshots were added under `data/raw/provider/2026-06-09/`.

## Files Modified

- `README.md`
- `AGENTS.md`
- `CLAUDE.md`

Tracked pre-lock analytical scripts were moved without deletion to
`codes/_legacy/provider_prelock_2026-06-09/`.

## Variables Fetched

Live BEA snapshots were fetched for:

- Fixed Assets: `FAAt401`, `FAAt402`, `FAAt404`, `FAAt407`
- Government Fixed Assets: `FAAt701`, `FAAt702`, `FAAt703`, `FAAt705`
- NIPA: `T11400`, `T71100`

The eight locked Table 7.11 lines are staged: L4, L44, L73, L28, L52, L91,
L74, and L53.

`FAAt707` was fetched during table-mapping verification. Live BEA metadata
identifies it as current-cost average age, not investment. Its raw snapshot is
retained under the no-delete rule but excluded from the locked investment menu.

## Not Available Directly

Twenty-one required manifest variables are explicit direct-availability gaps:

- current-cost gross stock at NFC/CORP asset boundaries;
- retirements for NFC/CORP ME, NRC, and IPP;
- revaluation/holding gains for NFC/CORP ME, NRC, and IPP;
- government transportation current-cost gross stock.

No net-stock series was relabeled as gross stock.

## Unresolved Mappings

Twelve required separate-flow variables still require verified NIPA mappings:

- NFC/CORP/FIN current-transfer payments and receipts;
- NFC/CORP/FIN dividends paid and received.

Eight FIN income variables are marked `downstream_constructed_only` because
they require transparent CORP/NFC differencing or another verified source.

## Downstream Next Step

The downstream repo should import the provider menu, provenance ledger, staged
long file, and Shaikh semantic audit. GPIM and non-Shaikh source-of-truth
construction may proceed in later bounded passes. Shaikh-style adjusted income
construction is blocked until the semantic crosswalk validates the Table 7.11
formula roles.

The downstream source-of-truth design prefers wage share as the distributive
state variable. Exploitation rate is retained only as an alternative proxy.
