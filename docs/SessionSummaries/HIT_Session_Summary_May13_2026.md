# HIT Analytics — Session Summary
**Date:** May 13, 2026
**Project:** HospitalIntelligenceR — HIT Analytics Workstream
**Next script target:** Year-level HIT data rebuild → high-level descriptive table (with/without strategic plan)

---

## 1. What Was Accomplished This Session

### hit_02_strategy_join.R — Confirmed Working
- The correct input to hit_02 is `roles/hit/outputs/hit_01_field_trajectories.csv` (hit_01 output), NOT `hit_master.csv`
- A previously broken redesign version was discarded; the original working script was restored
- Section 6 (three figures) was appended to the working script and is now part of the canonical version
- Figures written to `roles/hit/outputs/figures/`:
  - `fig_hit02_a_fin_quadrant.png` — FIN theme × quadrant (primary linking figure)
  - `fig_hit02_b_type_trajectory.png` — Type group trajectory dumbbell
  - `fig_hit02_c_era_quadrant.png` — Plan era × quadrant

### Key Findings from hit_02 Output

**FIN theme prevalence**
- 52 of 118 hospitals with classified strategy data have at least one FIN primary direction (44.1%)
- This is high enough that FIN is not a differentiating signal — it is a broadly reactive label

**FIN theme × financial trajectory (4a) — Null result**
The quadrant distributions for FIN vs. non-FIN hospitals are nearly identical:

| Quadrant | With FIN | Without FIN |
|---|---|---|
| Neither | 36.5% | 36.4% |
| Revenue-led | 34.6% | 33.3% |
| Expense-led | 17.3% | 16.7% |
| Cost pressure | 7.7% | 10.6% |
| Both | 3.8% | 3.0% |

Having a FIN strategic direction has no detectable association with landing in a better financial trajectory quadrant. This is itself a publishable finding.

**Hospital type × trajectory (4b) — The real story**
| Type Group | n | Mean Rev Trajectory | Mean Exp Trajectory | % Revenue-led |
|---|---|---|---|---|
| All | 131 | +3.9 | +1.9 | 34.4% |
| Community — Large | 47 | +6.2 | +4.1 | 46.8% |
| Community — Small | 55 | +3.4 | +2.0 | 30.9% |
| Teaching | 17 | +4.0 | +0.8 | 23.5% |
| Specialty | 12 | -3.1 | -5.6 | 16.7% |

Key observations:
- Community Large is the standout performer — pulling away from the field on both dimensions
- Specialty hospitals are losing ground on both revenue and expense — warrants separate investigation
- Teaching hospitals show a revenue/expense split: decent revenue improvement (+4.0) but near-zero expense trajectory (+0.8). Revenue improvement without cost discipline is a distinct finding

**Plan era × quadrant (4c) — Macro story, not strategy story**
- COVID-era plans dominated by Neither (42%) and Expense-led (37%) — reflects the disruption environment
- Current-era plans led by Revenue-led (37%) and Neither (35%) — reflects the recovery environment
- Pre-COVID plans only n=5 — not interpretable
- Caution: plan era × quadrant is substantially a *when the plan was active* story, not a strategy content story

**Interpretive framing established:**
Hospital type predicts financial trajectory far better than strategy theme content. The research question reframes productively as: does strategy content reflect or diverge from the structural constraints that actually determine financial outcomes by type group?

---

## 2. Next Analytical Step — High-Level Descriptive Table

### Objective
A simple two-row summary table:
- Row 1: Hospitals WITH a strategic plan (in place ≥ 2 years)
- Row 2: Hospitals WITHOUT a strategic plan

### Columns
1. Total # of hospitals
2. Average cumulative change in Revenue (post-plan-start)
3. Average cumulative change in Expense (post-plan-start)

### Key Design Decisions (agreed this session)

**Two-year minimum plan tenure** — A hospital's plan must have been in place for at least two full fiscal years to be included in the "with plan" group's financial calculations. Plans active less than two years are excluded from the primary comparison (note in table footnote). This is a methodological assumption to ensure a comparable observation window.

**Measurement window anchoring:**
- "With plan" hospitals: revenue/expense change measured from plan start year forward
- "No plan" hospitals: revenue/expense change measured over the full available window
- This asymmetry must be stated explicitly in the table footnote

**Field adjustment:** Changes should be field-adjusted (hospital YoY % change minus field median YoY % change for that year) to remove sector-wide MOH transfer effects — especially important for 2020/2021–2022/2023 COVID years

### What This Requires — Year-Level HIT Data Rebuild

The hit_02 summary output does not have year-level data. A rebuild of the year-level file is needed.

**Required fields (one row per FAC × fiscal_year):**

| Field | Source | Notes |
|---|---|---|
| `fac` | HIT import | Character throughout |
| `fiscal_year` | HIT import | Format: "2022/2023" |
| `hospital_type_group` | hospital_spine.csv | |
| `ind01` | HIT | Total Revenue |
| Total Expense indicator | HIT | Confirm indicator code from GlobalIndicatorLkup |
| `ind06` | HIT | % Non-MOH Revenue — needed to derive MOH revenue |
| `ind05` | HIT | Total Margin, PSC 1 (lead margin indicator) |
| `ind04` | HIT | Total Margin, all PSCs (gap monitor for multi-program operators) |
| ER visits | HIT | Clinical indicator |
| Acute patient days | HIT | Clinical indicator; also needed for cost-per-patient-day |

**Derived fields (calculate in script, not in source file):**
- `moh_revenue = ind01 × (1 - ind06 / 100)`
- `cost_per_patient_day = TotExp / AcutePtDays`

**Note on file provenance:** The year-level HIT file was originally assembled by merging multiple sources. It may not have been saved as a standalone intermediate file. It will need to be rebuilt from the raw HIT import. The rebuild script should follow the same pattern as the existing HIT import pipeline.

---

## 3. Standing Design Decisions (Locked)

These were established in prior sessions and remain in force:

| Decision | Detail |
|---|---|
| FIN treatment definition | `primary_theme == "FIN"` for at least one direction per hospital; secondary theme excluded; sensitivity check deferred |
| Fiscal year bridge rule | `plan_start_year = Y` → first treatment year `"Y/Y+1"`; transition year `"Y-1/Y"` excluded (conservative) |
| Lead margin indicator | `ind05` (TotMarginHospital, PSC 1); `ind04` retained to monitor gap |
| MOH revenue derivation | `TotRev × (1 − PctNonMOHRev / 100)` — no direct MOH revenue indicator exists |
| FAC type | Character throughout — coerced on load, no exceptions |
| Structural outliers | FACs 854 and 971 retained in joined output but excluded from percentage calculations |
| Analysis window | Dynamic derivation — picks up 2025/2026 data release automatically on re-run |
| Service volume companion | `cost_per_patient_day` must accompany expense trajectory (expense reductions via service contraction ≠ efficiency improvement) |

---

## 4. File Reference

| File | Location | Status |
|---|---|---|
| `hit_01_field_trajectories.csv` | `roles/hit/outputs/` | ✓ Exists — hit_01 output |
| `hit_02_strategy_joined.csv` | `roles/hit/outputs/` | ✓ Exists — this session's primary output |
| `hit_02_theme_quadrant.csv` | `roles/hit/outputs/` | ✓ Exists |
| `hit_02_type_summary.csv` | `roles/hit/outputs/` | ✓ Exists |
| `hit_02_era_quadrant.csv` | `roles/hit/outputs/` | ✓ Exists |
| `fig_hit02_a/b/c_*.png` | `roles/hit/outputs/figures/` | ✓ Exists |
| `strategy_classified.csv` | `analysis/data/` | ✓ Exists — direction-level strategy data |
| `hospital_spine.csv` | `analysis/data/` | ✓ Exists — FAC scope and type reference |
| `hitmaster.csv` | `roles/hit/outputs/` | ✓ EXISTS — long format, one row per FAC × fiscal_year × indicator; no hospital_type_group (join from spine) |
| `GlobalIndicatorLkup.rds` | TBD | Reference for indicator codes — confirm expense indicator code at session open |

---

## 5. Workflow Note

**Process lesson from this session:** When returning to a script that already exists in the project, always paste or upload the current file at the start of the session. Memory captures design intent and decisions; it does not capture what was actually coded and confirmed working. The reference source of truth for active scripts is the file on disk.

**Session indexing lag:** The May 12 session was not retrievable via memory search at the start of this session — recent sessions index with a lag of roughly 24 hours. If a prior session's decisions are critical, paste the summary at thread open.

---

## 6. Opening Instructions for Next Session

Paste this document at the start of the next thread, then:

1. Year-level HIT file confirmed: `roles/hit/outputs/hitmaster.csv` — long format, one row per FAC × fiscal_year × indicator. No hospital_type_group column; join from `analysis/data/hospital_spine.csv`
2. Confirm the indicator codes for Total Expense, ER visits, and Acute Patient Days from `GlobalIndicatorLkup.rds` (Revenue = ind01, % Non-MOH Revenue = ind06, Margin PSC1 = ind05, Margin all PSC = ind04 — confirm expense)
3. First deliverable: a pivot/join script that reshapes `hitmaster.csv` to one row per FAC × fiscal_year, joins hospital_type_group from spine, and produces the fields in Section 2
4. Second deliverable: the two-row high-level descriptive table (with/without strategic plan, ≥2 years tenure) with field-adjusted revenue and expense change
5. Subsequent iterations will drill down by hospital type group, then by theme

---
*Session summary prepared May 13, 2026 — HospitalIntelligenceR HIT Analytics Workstream*
ER visits=ind56,acute inpatient days=ind45,