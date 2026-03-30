# Critical-Replication-Shaikh: v2.2 Integration Checklist

**Date:** March 26, 2026  
**Version:** v2.2 (Corrected)

---

## Pre-Integration Review

- [ ] Read `README_REPO_UPDATE.md` (overview of corrections)
- [ ] Review `DATA_INVENTORY_BEA_NIPA.md` (data sourcing + canonical values)
- [ ] Verify you have full BEA CSV files (not partial extracts)

---

## File Placement

### 1. Copy Data Inventory
```bash
cp DATA_INVENTORY_BEA_NIPA.md <repo-root>/
```
- [ ] Placed at repo root (alongside main README)

### 2. Copy BEA Bundle Documentation
```bash
mkdir -p <repo-root>/docs/BEA_FixedAssets_Bundle_v2.2/
cp -r docs/BEA_FixedAssets_Bundle_v2.2/* <repo-root>/docs/BEA_FixedAssets_Bundle_v2.2/
```
- [ ] All 4 files copied to `docs/BEA_FixedAssets_Bundle_v2.2/`

### 3. Verify Data Files
In `<repo-root>/data/`:
- [ ] TableIPP.csv exists (Table 3.1I, 1947–2024)
- [ ] Table__32__.csv exists (Table 3.7I, 1947–2024)
- [ ] All other BEA CSVs present

---

## Code Updates

### Script: `26_S0_redesign_ardl_search.R`

**Check 1: y_nom Configuration**
```r
# Line XX: Verify this is set to VAcorp
y_nom = "VAcorp"  # NOT "GVAcorp"
```
- [ ] y_nom = "VAcorp" confirmed in script

**Check 2: Data Loading Path**
Verify paths match your directory structure:
```r
# Example (adjust to your layout)
table_3_1E <- read.csv("data/BEA_FixedAssets_Section3_Equipment.csv")
table_3_1I <- read.csv("data/BEA_FixedAssets_Section3_IPP.csv")  # 1947–2024
```
- [ ] Paths point to correct full-coverage CSVs

**Check 3: Canonical Value Verification**
Add a sanity check in the script:
```r
# Canonical check for data loading
kgc_1947 <- df$KGCcorp[df$year == 1947]
if (abs(kgc_1947 - 170.58) > 0.01) {
  warning("KGCcorp_1947 unexpected value: ", kgc_1947, " (expected 170.58)")
}
```
- [ ] Canonical check implemented or noted

---

## Configuration Verification

### R Environment & Package Versions

- [ ] ARDL package up to date
- [ ] dynlm package working (for trend() in PSS Case 5)
- [ ] dplyr, ggplot2, kableExtra installed

### ARDL Package: Correct Function Usage

Verify in scripts using bounds testing:
```r
# Correct: exact = TRUE, conditioning on actual sample size T = 65
bounds_f_test(model, case = 5, exact = TRUE)
bounds_t_test(model, case = 5, exact = TRUE)
```
- [ ] `exact = TRUE` confirmed in all bounds tests
- [ ] Sample size explicitly stated (T = 65)

---

## Data Validation

### Step 1: Load Data and Check Dimensions

```r
# In R console or script
source("path/to/26_S0_redesign_ardl_search.R")

# After loading, check:
dim(df)  # Should be 65 rows (1947–2011) or 78 rows (1947–2024)
colnames(df)  # Should include: year, VAcorp, KGCcorp, d1956, d1974, d1980

# Check coverage
range(df$year)  # Should be 1947 2024 (or 1947 2011 if restricting to Shaikh window)
```
- [ ] Data loads without error
- [ ] Dimensions match expected (T=65 for 1947–2011, T=78 for 1947–2024)
- [ ] Key columns present: VAcorp, KGCcorp, deflator

### Step 2: Canonical Value Check

```r
# In R console
df[df$year == 1947, c("year", "VAcorp", "KGCcorp")]
# Expected: KGCcorp = 170.58

df[df$year == 1950, ] %>% 
  mutate(ratio = NVA / KGCcorp) %>% 
  select(year, ratio)
# Expected: ratio ≈ 0.685
```
- [ ] KGCcorp_1947 = 170.58 Bn confirmed
- [ ] NVA/K ratio ≈ 0.685 (or similar) for sanity

### Step 3: No Missing Values

```r
# Check for NAs
colSums(is.na(df))
# Should show 0 for all key columns
```
- [ ] No unexpected NAs in VAcorp, KGCcorp, NVA

---

## Script Execution

### S0: Grid Search (40 Specifications)

```bash
# In R or RStudio
source("26_S0_redesign_ardl_search.R")
```
- [ ] Script runs without major errors
- [ ] Output directory created: `output/CriticalReplication/S0_manualOverride/`
- [ ] Results tables generated (AIC_BIC_dummy, ardl_nodummy, ardl13_dummy)

### Known Issues to Watch

- [ ] Case 5 NA bug: If ARDL with trend() returns NAs, check formula:
  - Trend should be in main formula: `ardl(y ~ trend(year) + ...)`
  - NOT after `|` separator
- [ ] Dummy placement: Structural dummies (d1974, d1980) should be in main formula for LR identification
  - If dummies after `|`, they're SR-only and won't enter cointegrating vector

---

## Documentation Updates

### Main Repo README

Add to your repo's main `README.md`:

```markdown
## Data & Configuration

**BEA Fixed Assets Data (v2.2):**
- Coverage: 1947–2024 (Equipment, Structures, IPP by 96 NAICS industries)
- Configuration: `y_nom = "VAcorp"` (Net output series)
- Deflator: `Py` (GDP implicit price deflator)
- Canonical values: KGCcorp_1947 = 170.58 Bn; NVA/K ≈ 0.685 (1950)

For detailed sourcing, see `DATA_INVENTORY_BEA_NIPA.md`.  
For reference documentation, see `docs/BEA_FixedAssets_Bundle_v2.2/`.
```

- [ ] Main README updated with BEA data section

### Optional: Add Data Audit Note

If you maintain a data audit log:

```markdown
### Data Audit (March 26, 2026)

- Confirmed: Section 3 tables (Equipment, Structures, IPP) cover 1947–2024 (no gap)
- Updated: VAcorp configuration (replaces GVAcorp)
- Verified: KGCcorp_1947 = 170.58 Bn (earlier 141.9 Bn was misread from 1925)
- Corrected: Full-coverage CSVs replace partial extracts
```

- [ ] Data audit notes added (if maintaining log)

---

## Troubleshooting

### Issue: "Could not find column VAcorp"

**Solution:** Verify `y_nom = "VAcorp"` in script. Check CSV has this column. Update old GVAcorp references.

- [ ] Resolved

### Issue: KGCcorp_1947 shows wrong value

**Solution:** Verify you're using the correct BEA table/line. Check CSV sourcing (should be current-cost, not constant-cost). See DATA_INVENTORY_BEA_NIPA.md for sourcing details.

- [ ] Resolved

### Issue: Script runs but results look off

**Solution:** 
1. Check canonical values (KGCcorp_1947, NVA/K ratio)
2. Verify dummies in correct formula position (main, not after `|`)
3. Review ARDL specification (case, exact = TRUE)
4. See NB2 §4 for expected θ range

- [ ] Resolved

---

## Post-Integration Sign-Off

- [ ] All files copied to correct locations
- [ ] Data files verified (dimensions, canonical values, no NAs)
- [ ] Scripts updated and tested
- [ ] Documentation updated
- [ ] README reflects BEA data v2.2
- [ ] Ready to commit to repo

**Date Completed:** ______________  
**Completed By:** ______________

---

## Next Steps After Integration

1. **Re-run Script 26:** S0 redesign grid (40 specifications) with corrected VAcorp
2. **Validate S0–S2 Results:** Check if rank-1 result persists (expected outcome, per notes)
3. **Prepare S3 Testing:** Ready to test θ(Λ) via parametric change at 1974 dummy (VECM framework)
4. **Document Findings:** Cross-stage θ comparison table; cointegration coefficients
5. **GPIM Validation:** If applicable, test SFC rules on 2017–2024 data to justify backward extrapolation

---

**Last Updated:** March 26, 2026
