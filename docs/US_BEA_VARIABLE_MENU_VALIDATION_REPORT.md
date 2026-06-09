# U.S. BEA Variable Menu Validation Report

**Run date:** 2026-06-09

## Scope

This report validates the BEA/NIPA/Fixed Assets provider layer. It does not validate
Chapter 2 GPIM, distributive variables, interaction variables, or econometric results.

Live BEA snapshots were staged for download date(s): 2026-06-09. Raw snapshots are preserved under `data/raw/provider/`.

## Validation Answers

1. Successfully staged required variables: **69 manifest variables**, **9438 annual observations**.
2. Required variables unavailable directly from the locked standard menu: **21**.
3. Required variables needing live fetch, manual mapping, or downstream derivation: **20**.
4. IPP and GOV_TRANS preserved as frontier conditioners and excluded from preferred `K_cap`: **PASS**.
5. ME and NRC tagged `direct_productive_capacity_capital`: **PASS**.
6. Required NIPA Table 7.11 lines present: **PASS**.
   Shaikh formula semantic admissibility: **BLOCKED**.
   Staged T711 rows prove presence and provenance only; the semantic audit does not validate the formula roles.
7. NFC, CORP, FIN, and GOV_TRANS boundaries represented: **PASS**.
8. Official BEA real/price indexes diagnostic rather than GPIM outputs: **PASS**.
9. Downstream analytical ownership documented: **PASS**.
10. Every staged row has table-line-unit-vintage provenance: **PASS**.

### Successfully Staged Required Variables

- `CORP__IPP__cfc_current_cost`
- `CORP__IPP__gross_investment_current_cost`
- `CORP__IPP__net_stock_current_cost`
- `CORP__IPP__net_stock_quantity_index`
- `CORP__ME__cfc_current_cost`
- `CORP__ME__gross_investment_current_cost`
- `CORP__ME__net_stock_current_cost`
- `CORP__ME__net_stock_quantity_index`
- `CORP__NRC__cfc_current_cost`
- `CORP__NRC__gross_investment_current_cost`
- `CORP__NRC__net_stock_current_cost`
- `CORP__NRC__net_stock_quantity_index`
- `CORP__TOTAL__cfc_current_cost`
- `CORP__TOTAL__gross_investment_current_cost`
- `CORP__TOTAL__net_stock_current_cost`
- `CORP__TOTAL__net_stock_quantity_index`
- `CORP_CFC`
- `CORP_COMP`
- `CORP_DIVIDENDS_NET`
- `CORP_GVA`
- `CORP_NET_INT`
- `CORP_NOS`
- `CORP_NVA`
- `CORP_PBT`
- `CORP_PROFITS_IVA_CC`
- `CORP_TRANSFERS_NET`
- `T711_L52`
- `T711_L53`
- `T711_L73`
- `T711_L74`
- `T711_L91`
- `FIN_GVA`
- `T711_L28`
- `T711_L4`
- `T711_L44`
- `GOV_TRANS__HIGHWAYS_STREETS__cfc_current_cost`
- `GOV_TRANS__HIGHWAYS_STREETS__gross_investment_current_cost`
- `GOV_TRANS__HIGHWAYS_STREETS__net_stock_current_cost`
- `GOV_TRANS__HIGHWAYS_STREETS__net_stock_quantity_index`
- `GOV_TRANS__TRANSPORTATION_STRUCTURES__cfc_current_cost`
- `GOV_TRANS__TRANSPORTATION_STRUCTURES__gross_investment_current_cost`
- `GOV_TRANS__TRANSPORTATION_STRUCTURES__net_stock_current_cost`
- `GOV_TRANS__TRANSPORTATION_STRUCTURES__net_stock_quantity_index`
- `NFC__IPP__cfc_current_cost`
- `NFC__IPP__gross_investment_current_cost`
- `NFC__IPP__net_stock_current_cost`
- `NFC__IPP__net_stock_quantity_index`
- `NFC__ME__cfc_current_cost`
- `NFC__ME__gross_investment_current_cost`
- `NFC__ME__net_stock_current_cost`
- `NFC__ME__net_stock_quantity_index`
- `NFC__NRC__cfc_current_cost`
- `NFC__NRC__gross_investment_current_cost`
- `NFC__NRC__net_stock_current_cost`
- `NFC__NRC__net_stock_quantity_index`
- `NFC__TOTAL__cfc_current_cost`
- `NFC__TOTAL__gross_investment_current_cost`
- `NFC__TOTAL__net_stock_current_cost`
- `NFC__TOTAL__net_stock_quantity_index`
- `NFC_CFC`
- `NFC_COMP`
- `NFC_DIVIDENDS_NET`
- `NFC_GVA`
- `NFC_NET_INT`
- `NFC_NOS`
- `NFC_NVA`
- `NFC_PBT`
- `NFC_PROFITS_IVA_CC`
- `NFC_TRANSFERS_NET`

## Required Gaps

### Not Available Directly

- `CORP__IPP__gross_stock_current_cost`
- `CORP__IPP__retirements`
- `CORP__IPP__revaluation_holding_gains`
- `CORP__ME__gross_stock_current_cost`
- `CORP__ME__retirements`
- `CORP__ME__revaluation_holding_gains`
- `CORP__NRC__gross_stock_current_cost`
- `CORP__NRC__retirements`
- `CORP__NRC__revaluation_holding_gains`
- `CORP__TOTAL__gross_stock_current_cost`
- `GOV_TRANS__gross_stock_current_cost`
- `NFC__IPP__gross_stock_current_cost`
- `NFC__IPP__retirements`
- `NFC__IPP__revaluation_holding_gains`
- `NFC__ME__gross_stock_current_cost`
- `NFC__ME__retirements`
- `NFC__ME__revaluation_holding_gains`
- `NFC__NRC__gross_stock_current_cost`
- `NFC__NRC__retirements`
- `NFC__NRC__revaluation_holding_gains`
- `NFC__TOTAL__gross_stock_current_cost`

### Requires Manual Mapping or Live Fetch

- `CORP__current_transfer_payments`
- `CORP__current_transfer_receipts`
- `CORP__dividends_paid`
- `CORP__dividends_received`
- `FIN__current_transfer_payments`
- `FIN__current_transfer_receipts`
- `FIN__dividends_paid`
- `FIN__dividends_received`
- `NFC__current_transfer_payments`
- `NFC__current_transfer_receipts`
- `NFC__dividends_paid`
- `NFC__dividends_received`

### Downstream Construction Only

- `FIN_CFC`
- `FIN_COMP`
- `FIN_DIVIDENDS`
- `FIN_NET_INT`
- `FIN_NOS`
- `FIN_NVA`
- `FIN_PBT`
- `FIN_TRANSFERS`

## Interpretation Lock

- Preferred private productive-capacity capital is `K_cap = K_ME + K_NRC`.
- IPP and government transportation assets remain staged frontier conditioners.
- The preferred transformation object is `theta(omega_t | IPP_t, GOV_TRANS_t)`.
- Wage share is the preferred downstream distributive state; exploitation rate is an alternative proxy.
- The additive alternative `g_Yp = theta*g_Kcap + psi*g_IPP + gamma*g_GOV_TRANS` is not implemented.
- Official BEA quantity and price indexes are diagnostics, not binding GPIM products.
- Gross stock, retirements, revaluation, separate transfer receipts/payments, and separate dividend flows are not imputed here.
- Live BEA metadata identifies `FAAt705` as government investment and `FAAt707` as current-cost average age.
- The audit-time `FAAt707` raw snapshot is retained but excluded from the locked investment menu.

## S30I Diagnostic Readiness

The staged menu separates source behavior by asset, stock/flow family, sector boundary,
and official quantity-index status. This allows the downstream repo to distinguish BEA
series behavior from GPIM implementation, gross/net choices, NFC/CORP boundaries,
ME-NRC composition, IPP treatment, and GOV_TRANS frontier conditioning.

## Handoff to Capacity-Utilization-US_Chile

The downstream analytical repository may import:

- the staged T711 candidate lines
- `data/metadata/us_bea_shaikh_candidate_line_semantic_audit.csv`
- `docs/US_BEA_SHAIKH_LINE_SEMANTIC_AUDIT.md`

It must not construct the following until a documented historical/current semantic crosswalk validates the formula roles:

- `BankMonIntPaid`
- `CorpNFNetImpIntPaid`
- `CorpImpIntAdj_t`
- Shaikh-adjusted value added
- Shaikh-adjusted operating surplus
- Shaikh-adjusted distributive variables

Non-Shaikh downstream work may proceed in later bounded passes, including:

- `K_G_NFC_ME_GPIM`, `K_G_NFC_NRC_GPIM`, `K_G_NFC_KCAP_GPIM`
- `K_N_NFC_ME_GPIM`, `K_N_NFC_NRC_GPIM`, `K_N_NFC_KCAP_GPIM`
- `P_K_NFC_ME_GPIM`, `P_K_NFC_NRC_GPIM`, `IPP_NFC_GPIM`, `GOV_TRANS_GPIM`
- preferred wage-share interactions: `omega_x_Kcap`, `omega_x_ME`, `omega_x_NRC`, `omega_x_ME_NRC_gap`
- alternative exploitation-rate proxies: `e_x_Kcap`, `e_x_ME`, `e_x_NRC`, `e_x_ME_NRC_gap`
- `source_provenance_ledger`

These are not final products of this provider repository. The downstream repo owns
GPIM, interaction variables, admissibility ledgers, and S10/S20/S30.
Shaikh-style adjusted construction remains blocked by the semantic audit.

## Hard Checks

- complete_provenance: **PASS**
- required_table_711_lines: **PASS**
- me_nrc_direct_capital: **PASS**
- ipp_gov_frontier: **PASS**
- all_boundaries_represented: **PASS**
- no_downstream_objects_staged: **PASS**
- official_indexes_diagnostic: **PASS**
- downstream_ownership_documented: **PASS**
