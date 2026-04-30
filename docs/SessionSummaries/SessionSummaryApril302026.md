# HospitalIntelligenceR
## Session Summary — HIT Field Segmentation Build
*April 30, 2026 | For Claude Project Knowledge Repository*

---

## 1. Session Overview

This session built `hit_01_field_segmentation.R` — the first HIT analytics
script and the standalone field characterization deliverable. The script was
built and run in four sections, with console output reviewed between each.
All outputs were produced successfully. A structural registry classification
error was identified at session end requiring a remediation project before
results are finalized.

**Primary accomplishments:**
- `hit_01_field_segmentation.R` built and run to completion
- `hit_01_field_trajectories.csv` written (147 FACs, trajectory scores +
  quadrant classifications)
- `hit_01_segment_summary.csv` written (overall and by hospital type)
- Working indicator set expanded to 15 — ind56 (`TotEmergf2FInhouse`)
  added as service volume indicator for hospitals with thin inpatient volumes
- Quadrant thresholds confirmed at ±5pp cumulative field-adjusted score
- Preliminary findings reviewed and interpreted
- Classification error identified: CHEO (FAC 751) and Sick Kids (FAC 837)
  are incorrectly classified as Specialty — should be Teaching

---

## 2. Indicator Set — Final (15 indicators)

| Group | Indicators |
|-------|-----------|
| Primary analytical | ind01 TotRev, ind02 TotExp, ind05 TotMarginHospital, ind06 PctNonMOHRev |
| Supporting | ind03 OpMargin, ind04 TotMargPSC, ind07 CurrentRatio, ind08 WorkingCap, ind12 pctUPPMOSComp, ind13 pctMDNPStaffComp, ind18 PctContractedOut, ind35 TotFTE |
| Service volume | ind45 AcutePtDays, ind54 TotSurgCases, **ind56 TotEmergf2FInhouse** (new) |

**ind56 design note:** ED visit volume added as secondary service volume
denominator. Primary use: `cost_per_ed_visit` efficiency metric for hospitals
where AcutePtDays is absent or thin (primarily Small Community and Specialty).
Coverage: 124 of 149 FACs. Absence expected and not treated as a data defect.

---

## 3. Analytical Design — Confirmed

**Field adjustment:** Hospital YoY % change in TotRev and TotExp minus field
median YoY % change for that year. Removes sector-wide MOH transfer effects.
COVID signature confirmed in field medians: 2020/2021 revenue +12.1pp,
2023/2024 revenue +11.0pp (second large year — noted for narrative).

**Cumulation:** Six YoY transitions summed per FAC (2018/2019 → 2024/2025).
139 of 147 FACs have all 6 transitions; 8 have fewer due to gap years.

**Thresholds:** ±5pp cumulative. Revenue Q75 = +9.0pp; Expense Q25 = -4.1pp.
Threshold confirmed as a reasonable "meaningful outperformance" bar.

**Quadrant logic:**

| Quadrant | Revenue | Expense |
|----------|---------|---------|
| Revenue-led | > +5pp | Any |
| Expense-led | ≤ +5pp | < −5pp |
| Both | > +5pp | < −5pp |
| Cost pressure | Any | > +5pp |
| Neither | −5 to +5pp | −5 to +5pp |

**Expense sub-classification** (Expense-led and Both only):
- Efficiency-led: cost held below field AND cost per unit improved
- Volume contraction: cost held below field BUT volume fell > 5%
- Efficiency-led (volume declining): cost per unit improved despite volume loss
- Volume data unavailable: no ind45 or ind56 — classification not possible

---

## 4. Preliminary Results (Pre-Reclassification — Do Not Cite)

Results below reflect the current (incorrect) Specialty classification
for CHEO and Sick Kids. They are documented here for reference only.
All findings must be re-run after the registry correction.

**Overall quadrant distribution (n = 147 FACs):**

| Quadrant | n | % |
|----------|---|---|
| Revenue-led | 54 | 36.7% |
| Neither | 48 | 32.7% |
| Expense-led | 30 | 20.4% |
| Cost pressure | 11 | 7.5% |
| Both | 4 | 2.7% |

**By hospital type (pre-correction):**

| Type | Top quadrant | % |
|------|-------------|---|
| Community — Large | Revenue-led | 45.8% |
| Community — Small | Revenue-led | 35.6% |
| Specialty | Expense-led | 57.1% |
| Teaching | Neither | 60.0% |

**Interpretive notes (to be confirmed post-reclassification):**
- Teaching tracking field median (Neither 60%) — scale effect, stable funding
- Specialty Expense-led majority — structural, limited revenue levers
- Community — Small highest Cost pressure (11.9%) — structural funding squeeze
- Revenue-led group has mean expense score +15.8pp — scaling hospitals, not
  margin improvers; distinct from the 4 "Both" hospitals in the narrative
- Service volume data will be needed for readers to fully interpret trajectories
  (flagged for narrative)

---

## 5. Classification Error — CHEO and Sick Kids

**Error:** FACs 751 (CHEO) and 837 (Sick Kids/SickKids) are currently
classified as `hospital_type_group = "Specialty"` in `hospital_registry.yaml`.

**Correct classification:** Both are academic pediatric hospitals with
research mandates and university teaching affiliations. They belong in
`hospital_type_group = "Teaching"`.

**Scope of impact:** The registry is the single source of truth for
`hospital_type_group`. Every downstream output that uses this field is
affected — which is the entire analytical stack:
- Strategy analytics: 01a, 01b, 03b, 03c, 04a, 04b and their narrative documents
- HIT analytics: hit_01_field_segmentation.R (outputs produced this session)

**Remediation:** Separate mini-project scoped below. Priority 1 before
any further HIT analytics work.

---

## 6. Open Items Carried Forward

| Item | Detail | Priority |
|------|--------|----------|
| Reclassification remediation | FACs 751, 837 — full scope in Section 7 | Next session Priority 1 |
| hit_02_strategy_join.R | On hold until reclassification complete | Priority 2 |
| Project Outline update | Section 4 (HIT status) still shows "Not started" | Priority 3 |

---

## 7. Reclassification Mini-Project Scope

### What changes
- `hospital_registry.yaml`: `hospital_type_group` for FACs 751 and 837
  changed from `"Specialty"` to `"Teaching"`

### Downstream cascade (in run order)

| Step | Action | Notes |
|------|--------|-------|
| 1 | Edit `hospital_registry.yaml` | Close file in RStudio first |
| 2 | Re-run `00_prepare_data.R` | Rebuilds hospital_spine.csv and all analytical derivatives |
| 3 | Re-run `01a_plan_volume.R` | Plan volume by type — Teaching n increases |
| 4 | Re-run `01b_direction_types.R` | Theme × type — Teaching and Specialty profiles shift |
| 5 | Re-run `03b_theme_trends.R` | Era trends — small compositional shift |
| 6 | Re-run `03c_theme_by_era_type.R` | Era × type interaction — Specialty shrinks to 12 |
| 7 | Re-run `04a_homogeneity.R` | Core profiles and Jaccard — Teaching diverges further |
| 8 | Re-run `04b_unique_strategies.R` | Distinctive directions — reclassification context |
| 9 | Re-run `hit_01_field_segmentation.R` | Regenerate both HIT output CSVs |
| 10 | Review key findings | Note what changed materially vs pre-correction |
| 11 | Update narrative documents | 01b, 03b, 03c, 04a, 04b narratives where Teaching/Specialty figures are cited |

### Expected directional impact
- Teaching: 15 → 17 hospitals; type profile shifts toward pediatric academic
- Specialty: 14 → 12 hospitals; Expense-led majority likely strengthens
  (CHEO and Sick Kids are large institutions that may not be Expense-led)
- RES prevalence in Teaching likely increases (both hospitals have
  strong research mandates)
- Specialty Expense-led % will change — direction depends on which
  quadrant CHEO and Sick Kids currently fall in (check hit_01_field_trajectories.csv)

### Pre-reclassification anchor (confirmed at session end)

| FAC | Hospital | Current type | Quadrant | cum_adj_rev | cum_adj_exp |
|-----|----------|-------------|----------|-------------|-------------|
| 751 | OTTAWA CHEO CTC | Specialty → Teaching | Revenue-led | +20.4pp | +16.3pp |
| 837 | TORONTO HOSPITAL FOR SICK CHILDREN | Specialty → Teaching | Neither | +1.6pp | +4.9pp |

**Neither hospital is in the Expense-led quadrant.** Expected directional
impact on Specialty after removal: 8 Expense-led of 14 (57.1%) → 8 of 12
(66.7%) — finding strengthens. Teaching profile largely stable: Sick Kids
reinforces Neither majority; CHEO adds one to Revenue-led (3 → 4).

---

## 8. Session End Checklist

- [ ] Upload `SessionSummaryApril302026.md` to knowledge repository
- [ ] Upload `hit_01_field_segmentation.R` to knowledge repository
      (`roles/hit/scripts/`)
- [ ] Push all changes to GitHub
- [ ] Do NOT update narrative documents until reclassification is complete
