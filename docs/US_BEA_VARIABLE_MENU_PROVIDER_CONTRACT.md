# U.S. BEA Variable Menu Provider Contract

**Locked:** 2026-06-09

## Purpose

This repository is the source-provider layer for U.S. BEA Fixed Assets and
NIPA ingredients used downstream in Chapter 2. It preserves source observations
and provenance. It does not decide the final analytical dataset.

The analytical authority is:

```text
C:\ReposGitHub\Capacity-Utilization-US_Chile
```

That repository owns S10/S20/S30 construction, GPIM, Shaikh-style income
corrections, distributive variables, interaction variables, admissibility
ledgers, and econometric analysis.

## Theoretical Lock

Preferred productive-capacity capital:

```text
K_cap = K_ME + K_NRC
```

Preferred transformation object:

```text
theta_t = theta(omega_t | IPP_t, GOV_TRANS_t)
```

The wage share is the preferred distributive state variable downstream. The
exploitation rate is retained only as an alternative proxy for distributive
conditions.

The provider must not encode:

```text
g_Yp = theta*g_Kcap + psi*g_IPP + gamma*g_GOV_TRANS
```

IPP and government transportation assets are retained as frontier
conditioners, not direct components of preferred private `K_cap`.

## Role Tags

| Block | Role tag |
| --- | --- |
| Machinery and equipment (`ME`) | `direct_productive_capacity_capital` |
| Nonresidential structures (`NRC`) | `direct_productive_capacity_capital` |
| Intellectual property products (`IPP`) | `frontier_conditioner` |
| Government transportation (`GOV_TRANS`) | `frontier_conditioner` |
| Residential capital | `exclusion_diagnostic` |
| Financial-sector fixed assets | `corporate_boundary_diagnostic` |
| Inventories | `circulation_stockflow_diagnostic` |

## Boundaries

- `NFC`: preferred nonfinancial corporate productive-sector boundary.
- `CORP`: total corporate comparison and Shaikh-accounting boundary.
- `FIN`: financial corporate correction and double-counting diagnostic.
- `GOV_TRANS`: government transportation infrastructure conditioner.

No broader aggregate may silently replace one of these boundaries.

## Fixed-Assets Coverage

The locked menu maps current-cost net stock, official net-stock quantity
indexes, current-cost CFC, and current-cost gross investment for CORP, NFC,
and FIN total fixed assets, ME, NRC, and IPP using BEA Fixed Assets section 4.

The government transportation menu preserves transportation structures and
highways/streets components separately so the downstream aggregate remains
auditable. Government investment is assigned to `FAAt705`; the 2026-06-09 live
BEA metadata check verified `FAAt705` as government investment and `FAAt707` as
current-cost average age.

Current-cost gross stock, retirements, and revaluation/holding gains are
recorded as explicit gaps when no direct standard-table line is available.
Net stock is never relabeled as gross stock.

Official quantity and price indexes are diagnostic. They are not GPIM outputs.

## Income-Accounts Coverage

NIPA Table 1.14 supplies direct CORP and NFC value added, compensation, CFC,
operating surplus, net interest, net transfers, profits, taxes, dividends, and
undistributed-profit ingredients where available. FIN variables are staged
directly only when a distinct line exists; otherwise the ledger identifies the
required downstream derivation or manual mapping.

Separate current-transfer and dividend payment/receipt flows are not inferred
from net lines.

## Imputed-Interest Lock

The provider stages these candidate NIPA Table 7.11 lines with provenance:

```text
L4, L44, L73, L28, L52, L91, L74, L53
```

They are candidate Shaikh-line ingredients only.

The provider does not construct adjusted value added, operating surplus,
profit shares, wage shares, or exploitation ratios.

Line-number existence is not sufficient for Shaikh-style correction
admissibility. The current provider package stages the eight candidate lines
with provenance, but downstream construction of `BankMonIntPaid`,
`CorpNFNetImpIntPaid`, `CorpImpIntAdj_t`, and all Shaikh-adjusted derivatives
is blocked until a documented historical/current semantic crosswalk validates
the formula roles.

## Data Products

The locked manifest is available as CSV and JSON. The staged long file has one
row per annual observation and source variable. The provenance ledger has one
row per manifest variable, including unavailable and downstream-only objects.

Required staged provenance:

- variable and canonical identifiers;
- BEA dataset, table, line, and returned line description;
- sector, asset, and account boundaries;
- frequency, unit, price basis, and stock/flow type;
- role, priority, and downstream dependency;
- download date, vintage, source query, status, notes, and source file.

## Status Semantics

- `staged`: a source line is present in the long provider output.
- `fetched`: a raw snapshot was downloaded but has not yet been staged.
- `not_available`: no direct standard-menu source line is available.
- `requires_manual_mapping`: a live fetch or verified mapping remains open.
- `ambiguous_mapping`: multiple plausible lines remain unresolved.
- `downstream_constructed_only`: ingredients belong here, construction does not.

## Execution

```powershell
Rscript codes/20_fetch_fixed_assets_menu.R
Rscript codes/30_fetch_income_accounts_menu.R
Rscript codes/40_stage_variable_menu_long.R
Rscript codes/90_validate_variable_menu.R
```

Raw snapshots are date-versioned and never overwritten. If `BEA_API_KEY` is
absent, fetch scripts exit cleanly and staging uses preserved extracts where
available.
