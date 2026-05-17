# HIT Analytics — Session Summary
**Date:** May 15, 2026
**Project:** HospitalIntelligenceR — HIT Analytics Workstream
**Next session agenda:** Interpret FIN vs. non-FIN tables (c/d); decide next analytical step

---

## 1. Starting Point

Opened with the May 13 session summary attached. Two indicator codes supplied at session open to complete the field list established May 13:

- `ind45` = Total Acute Inpatient Days (`AcutePtDays`)
- `ind56` = Total Emergency Visits Face-to-Face In-House (`TotEmergF2FInhouse`)

All other indicator codes (ind01, ind02, ind05, ind06) and design decisions were carried forward from May 13 without change.

---

## 2. What Was Built This Session

### hit_03_plan_comparison.R

New script built from scratch this session. Purpose: reshape `hit_master.csv` to wide format, compute field-adjusted year-over-year revenue and expense changes, classify hospitals by strategic plan status, apply the two-year tenure filter, compute cumulative hospital-level trajectory scores, and output all intermediate and summary files.

**Sections:**

| Section | Content |
|---------|---------|
| 1 | Load hit_master.csv; apply spine scope and indicator filter |
| 2 | Pivot wide: one row per FAC × fiscal_year; join hospital_type_group from spine; derive moh_revenue |
| 3 | Compute field-adjusted YoY revenue and expense changes; write hit_03_year_level.csv |
| 4 | Load strategy plan dates from strategy_classified.csv; collapse to FAC level |
| 5 | Apply two-year tenure filter; report classification counts |
| 6 | Compute cumulative field-adjusted changes within plan-anchored windows |
| 7 | Build two-row summary table; write hit_03_plan_comparison.csv |
| 8 | Type-stratified supporting breakdown; write hit_03_type_breakdown.csv |
| 9 | FIN theme decomposition within with-plan group; add fin_flag to hospital-level file |

### fig_hit03_plan_tables.R

Publication table script built this session. Produces four flextable PNG outputs per `figure_standards.md` Section 11. `std_flextable()` function defined once and shared across all four tables. Single shared footnote block with both SDs cited.

### hit_03_technical_narrative.md

Full technical methodology document written and revised this session. Covers all analytical decisions from data sourcing through interpretive boundaries.

---

## 3. Bugs Encountered and Resolved

### Bug 1 — Date parsing failure in plan_period_start (critical)

**What happened:** `read_csv()` with `col_guess()` parsed `plan_period_start` as a Date class. The subsequent `as.integer()` call converted Date objects to their numeric storage value (days since 1970-01-01), producing plan_start_year values like 16436, 17532, etc. rather than calendar years.

**Silent consequence:** The broken year strings (e.g. `"16436/16437"`) sort lexicographically below every `"20XX/20XX"` fiscal year string. The `fiscal_year >= plan_first_fy` window filter therefore passed all six available transition years into every hospital's measurement window regardless of actual plan vintage. All 112 with-plan hospitals appeared to meet the two-year tenure threshold, and the plan-anchored measurement window was effectively ignored.

**Fix:**
```r
# Before (broken)
plan_start_year = as.integer(min(as.integer(plan_period_start), na.rm = TRUE))

# After (correct)
plan_start_year = as.integer(format(min(plan_period_start, na.rm = TRUE), "%Y"))
```

**Detection:** Step 5 showed `plan_start_year` values of 16436–20454 in the short-tenure exclusion list. Immediate diagnostic confirmed `class(strat_raw$plan_period_start)` returned `"Date"`.

### Bug 2 — Stale file on disk (critical)

**What happened:** The date fix was applied to the session output file but was never propagated to the project script at `roles/hit/scripts/hit_03_plan_comparison.R`. Subsequent runs via `source()` continued executing the unpatched version, writing the 111/112-hospital result to disk each time. Clearing the R environment and re-sourcing (the standard clean-run protocol) made no difference because the fix was absent from the sourced file.

**Detection:** After `rm(list = ls())` and `source()`, Step 5 still reported 112. Checking the project script directly confirmed the date fix line was not present.

**Fix:** Replaced `roles/hit/scripts/hit_03_plan_comparison.R` entirely with the corrected session output file.

**Process lesson:** When a bug fix is made in a session output file, explicitly confirm the fix has been copied to the project script before running. Verifying console output alone is insufficient — the file on disk can remain stale.

---

## 4. Confirmed Population Counts

After both bugs resolved, clean run confirmed:

| Group | N | Notes |
|-------|---|-------|
| With plan, meets ≥2-year tenure | 55 | Primary comparison group; 2015–2023 plan vintage |
| With plan, short tenure | 65 | Primarily 2024–2026 plan vintage; excluded from primary tables |
| No strategic plan | 10 | Full HIT window; access barriers not confirmed plan absence |

FIN decomposition within the 55 with-plan hospitals:

| FIN Group | N | % of with-plan |
|-----------|---|----------------|
| Primary emphasis on finance | 24 | 43.6% |
| No primary emphasis on finance | 31 | 56.4% |

The 43.6% FIN prevalence is consistent with the sector-wide rate from hit_02 (44.1% across 118 hospitals), confirming the 55-hospital with-plan group is not disproportionately FIN-heavy.

---

## 5. Field Medians (Confirmed Correct)

| Transition Year | Field Median Rev YoY | Field Median Exp YoY | N FACs |
|-----------------|---------------------|---------------------|--------|
| 2019/2020 | +3.6pp | +3.9pp | 128 |
| 2020/2021 | +11.8pp | +9.2pp | 128 |
| 2021/2022 | +1.8pp | +4.3pp | 128 |
| 2022/2023 | +4.5pp | +8.0pp | 129 |
| 2023/2024 | +11.0pp | +9.5pp | 129 |
| 2024/2025 | +5.3pp | +6.3pp | 129 |

The 2020/2021 and 2023/2024 spikes (MOH emergency transfers and post-COVID reconciliation respectively) are correctly captured and differenced out at the hospital level by the field adjustment. The field adjustment is computed across all 130 scope hospitals before any plan-group or FIN-group splits are applied.

---

## 6. Key Analytical Results

### Plan vs. no plan (Tables a/b)

| Group | N | Mean Rev (adj.) | Median Rev (adj.) | SD Rev | Mean Exp (adj.) | Median Exp (adj.) | SD Exp |
|-------|---|-----------------|-------------------|--------|-----------------|-------------------|--------|
| With strategic plan (≥2 yrs) | 55 | +1.0pp | +1.9pp | 6.7pp | +0.3pp | +0.4pp | 6.6pp |
| No strategic plan | 10 | −1.9pp | −1.9pp | 15.8pp | −2.4pp | −2.1pp | 9.8pp |

**Interpretive notes:**
- The with-plan group shows left skew (mean < median on both dimensions) — a small number of with-plan hospitals with strongly negative trajectories pull the mean below the typical hospital's experience. Median is the lead statistic.
- The no-plan group SD (15.8pp revenue, 9.8pp expense) is too large relative to n=10 for the mean to carry statistical weight. Mean and median are identical at −1.9pp for revenue, indicating no single outlier is driving the result, but the 95% CI spans roughly −12pp to +8pp.
- Type composition check: no-plan group has 50% Community Large vs. 42% in the with-plan group. Community Large showed the strongest trajectories in hit_02. This composition difference biases against the observed gap, reinforcing the directional finding.
- Three structural caveats apply — measurement window asymmetry, selection into planning, no-plan group size — making these tables descriptive baselines rather than estimates of a plan effect.

### FIN vs. non-FIN (Tables c/d)

Tables produced and confirmed clean at session close. Interpretation deferred to next session.

---

## 7. Publication Tables Produced

All four tables written to `roles/hit/outputs/figures/publication/` at 300 DPI per figure_standards.md:

| File | Description |
|------|-------------|
| `tbl_hit03_a_revenue.png` | Plan vs. no plan — field-adjusted cumulative revenue |
| `tbl_hit03_b_expense.png` | Plan vs. no plan — field-adjusted cumulative expense |
| `tbl_hit03_c_fin_revenue.png` | FIN vs. non-FIN within with-plan group — revenue |
| `tbl_hit03_d_fin_expense.png` | FIN vs. non-FIN within with-plan group — expense |

Tables a/b share a single footnote block citing both revenue and expense SDs for the no-plan group. Tables c/d carry a separate footnote scoped to the 55-hospital with-plan population.

---

## 8. Technical Narrative Revisions (hit_03_technical_narrative.md)

Four corrections applied to the narrative this session:

1. **FAC 701** named as Richmond Hill Mackenzie Health in the outlier exclusion table
2. **Cost-per-patient-day** derivation removed from Section 2 — field is in the year-level output but plays no role in the plan comparison tables being documented
3. **Median vs. mean justification** added at the end of Section 3 — left skew explanation with specific numbers preceding the cumulative change definition
4. **Shared footnote** — footnote 4 updated to cite both revenue (15.8pp) and expense (9.8pp) SDs, making a single footnote block serviceable for both tables a and b

---

## 9. Structural Outliers (Confirmed — All Sessions)

| FAC | Hospital | Reason |
|-----|----------|--------|
| 854 | SA Grace Toronto | COVID-era transitional care expansion |
| 971 | Sudbury St. Joseph's Continuing Care | COVID-era transitional care expansion |
| 701 | Richmond Hill Mackenzie Health | Large capital construction onboarding |
| 938 | Haliburton Health Services (Dysart et al) | Amalgamation / MOHLTC review period |

Excluded before field median calculations. Applied at the analytics layer — `hit_master.csv` is never modified.

**FAC 983 (Huron Perth Healthcare Alliance):** merged entity, passes tenure filter, absent from HIT data under consolidated FAC code. Excluded from all financial trajectory analysis; noted in table footnotes.

---

## 10. File Reference (End of Session State)

| File | Location | Status |
|------|----------|--------|
| `hit_03_plan_comparison.R` | `roles/hit/scripts/` | ✓ Corrected (date fix) + Section 9 (FIN) |
| `fig_hit03_plan_tables.R` | `roles/hit/scripts/` | ✓ Extended — Sections c/d added |
| `hit_03_technical_narrative.md` | `docs/` | ✓ Revised — 4 corrections applied |
| `hit_03_year_level.csv` | `roles/hit/outputs/` | ✓ 901 rows — FAC × fiscal_year wide format |
| `hit_03_hospital_level.csv` | `roles/hit/outputs/` | ✓ 65 rows — fin_flag and fin_group added |
| `hit_03_plan_comparison.csv` | `roles/hit/outputs/` | ✓ Two-row plan summary |
| `hit_03_fin_comparison.csv` | `roles/hit/outputs/` | ✓ New — FIN decomposition summary |
| `hit_03_type_breakdown.csv` | `roles/hit/outputs/` | ✓ Type × plan group supporting output |
| `tbl_hit03_a_revenue.png` | `roles/hit/outputs/figures/publication/` | ✓ Produced |
| `tbl_hit03_b_expense.png` | `roles/hit/outputs/figures/publication/` | ✓ Produced |
| `tbl_hit03_c_fin_revenue.png` | `roles/hit/outputs/figures/publication/` | ✓ Produced |
| `tbl_hit03_d_fin_expense.png` | `roles/hit/outputs/figures/publication/` | ✓ Produced |

---

## 11. Opening Instructions for Next Session

Paste this document at the start of the next thread, then:

1. **FIN vs. non-FIN interpretation** — paste the console output from the fin_comparison step (or the table numbers directly) and interpret tables c/d. Expected null result consistent with hit_02, but confirm before framing.
2. **Decide next analytical step** — three options on the table:
   - (a) Type-stratified breakdown of the 55 with-plan hospitals (Community Large / Small / Teaching / Specialty × plan trajectory)
   - (b) Plan vintage cohort analysis — split the 55 by plan start year cohort (pre-COVID / COVID-era / post-COVID) to directly address the measurement window asymmetry identified as a limitation
   - (c) Move to publication narrative drafting using the findings to date
3. **Confirm script locations** — verify that both `hit_03_plan_comparison.R` and `fig_hit03_plan_tables.R` in the project match the corrected session output versions before any further runs

---

*Session summary prepared May 15, 2026 — HospitalIntelligenceR HIT Analytics Workstream*
*Scripts produced: `hit_03_plan_comparison.R` → `fig_hit03_plan_tables.R`*
*Next script target: TBD pending next session agenda decision*
