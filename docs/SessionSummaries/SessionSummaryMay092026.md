# Session Summary — May 9, 2026
## HospitalIntelligenceR

---

## Session Focus

Build and execute `hit_02_strategy_join.R` — the first script to link HIT
financial trajectory data to strategy theme classifications at the FAC level.
Produces the core analytical dataset for all downstream strategy-performance
linking analysis.

---

## What Was Accomplished

### 1. hit_02_strategy_join.R — Built and Executed

Script built from scratch and run section by section with console verification
at each pause point. All four output CSVs written successfully.

**Script location:** `roles/hit/scripts/hit_02_strategy_join.R`

**Inputs:**
- `roles/hit/outputs/hit_01_field_trajectories.csv` (133 rows)
- `analysis/data/strategy_classified.csv` (574 rows, 125 FACs)
- `analysis/data/hospital_spine.csv` (134 rows)

**Outputs written to `roles/hit/outputs/`:**

| File | Rows | Description |
|------|------|-------------|
| `hit_02_strategy_joined.csv` | 133 | One row per FAC — trajectories + theme flags + plan context |
| `hit_02_theme_quadrant.csv` | 97 | Theme × quadrant distribution with mean trajectory scores |
| `hit_02_type_summary.csv` | 5 | Mean/median trajectory scores by hospital_type_group |
| `hit_02_era_quadrant.csv` | 11 | Plan era × quadrant distribution |

**Confirmed dimensions:**
- Analytical core (full strategy + trajectory data, excl. structural outliers): **118 hospitals**
- Structural outliers retained in joined file but excluded from summary denominators: **2** (FACs 854, 971)
- Trajectory FACs without any strategy data: **15**
- Strategy FACs not in HIT cohort: **1** (FAC 983 — HPHA, no clean transitions after amalgamation flag)

---

### 2. Section-by-Section Verification

**Section 1 — Trajectories:** 133 FACs, quadrant counts confirmed against May 3
session summary. `outlier_flag` absent from hit_01 output — derived cleanly from
`STRUCTURAL_OUTLIER_FACS` constant as designed.

**Section 2 — Strategy aggregation:** strategy_classified loaded at 574 rows ×
33 cols, 125 unique FACs. 547 classified directions across 119 FACs; 27
unclassified rows across 6 FACs. Six FACs with strategy records but no
classified directions received skeleton rows with `has_strategy_data = FALSE`:
FACs 732, 854, 900, 938, 971, 977.

Plan era distribution (125 strategy FACs):

| Era | n |
|-----|---|
| Current (≥ 2023) | 98 |
| COVID (2020–2022) | 20 |
| Pre-COVID (≤ 2019) | 5 |
| NA | 2 |

**Section 3 — Join coverage:**

| Group | n |
|-------|---|
| Trajectory FACs with strategy data | 118 |
| Trajectory FACs without strategy data | 15 |
| Strategy FACs not in trajectories | 1 (FAC 983) |

The 15 without strategy data split into two distinct groups — `has_strategy_data = FALSE`
(6 skeleton rows: known thin/robots-blocked FACs) and `has_strategy_data = NA`
(9 FACs entirely absent from strategy pipeline: 682, 699, 719, 910, 927, 930,
933, 966, 981). FACs 699, 719, 910, 930 are the known YAML-status-pending
carry-forwards.

**Section 4 — Analytical summaries:** All three cross-tabulations computed
without error. Key outputs noted below.

---

### 3. First-Cut Analytical Findings

Three findings of analytical interest from Section 4, to be developed in
subsequent sessions:

**Finding 1 — FIN null result (primary linking question, first cut).**
Hospitals with at least one FIN-classified direction and those without show
nearly identical quadrant distributions (Revenue-led: 34.6% vs. 33.3%;
Neither: 36.5% vs. 36.4%; Expense-led: 17.3% vs. 16.7%). Mean cum_adj_rev
is modestly higher for the Revenue-led cell among With-FIN hospitals (17.8
vs. 12.4), but the overall pattern does not differentiate. Interpretation
question: does a FIN direction reflect financial ambition or financial stress
response? Directionality relative to plan_period_start and trajectory timing
requires investigation before a narrative conclusion can be drawn.

**Finding 2 — Specialty cumulative trajectory negative on both axes.**
Community — Large: mean rev +6.2, mean exp +4.1.
Teaching: mean rev +4.0, mean exp +0.8.
Community — Small: mean rev +3.4, mean exp +2.0.
**Specialty: mean rev −3.1, mean exp −5.6** — the only type group with
negative mean scores on both dimensions. Consistent with the Expense-led
dominance finding from hit_01 (66.7% Expense-led) and extends it: Specialty
hospitals' cumulative trajectory is running in reverse relative to the sector
median across the full seven-year window, not just a single-year effect.

**Finding 3 — COVID-era plan holders show elevated Expense-led incidence.**
Hospitals with COVID-era plans (2020–2022, n=19) are Expense-led at 36.8%
versus 13.8% for Current-era hospitals (n=94). Neither is dominant at 42.1%
for COVID-era. Causal direction is ambiguous — plan vintage may reflect the
disruption period itself rather than any plan-driven effect.

---

## Key Decisions and Design Notes

**`outlier_flag` column absent from hit_01 output.** The flag is embedded in
the quadrant label "Structural outlier" in `hit_01_field_trajectories.csv` but
not as a separate boolean column. hit_02 derives it from the
`STRUCTURAL_OUTLIER_FACS` constant (`c("854", "971")`). If hit_01 is rebuilt,
adding an explicit `outlier_flag` boolean to the output would remove this
dependency.

**FAC 983 (HPHA) absent from trajectories.** After the amalgamation flag
exclusion in hit_01, HPHA had no clean transitions (its consolidated reporting
only began in 2024/2025) and produced no trajectory row. This is the correct
treatment. FAC 983 has strategy data (retained in `strategy_fac_full`) but
does not appear in the joined output.

**Ad hoc exploration deferred to next session.** The FIN directionality
question and Teaching financial divergence check will be explored ad hoc
before committing to a `hit_03` script design. The joined dataset is the
working file for this exploration.

---

## Files Created This Session

| File | Status |
|------|--------|
| `roles/hit/scripts/hit_02_strategy_join.R` | New — complete |
| `roles/hit/outputs/hit_02_strategy_joined.csv` | New — 133 rows, 56 cols |
| `roles/hit/outputs/hit_02_theme_quadrant.csv` | New — 97 rows |
| `roles/hit/outputs/hit_02_type_summary.csv` | New — 5 rows |
| `roles/hit/outputs/hit_02_era_quadrant.csv` | New — 11 rows |

---

## Carry-Forward Items

| Item | Priority | Notes |
|------|----------|-------|
| FIN directionality exploration — does FIN direction precede or follow financial stress? | High | Ad hoc from `hit_02_strategy_joined.csv`; requires plan_period_start relative to trajectory timing |
| Teaching financial divergence check — does 04a strategic divergence track with financial divergence? | High | Ad hoc; type_summary output is the starting point |
| PAT/ACC direction vs. volume recovery first cut | High | Ad hoc from joined file |
| `hit_03` script design — scope and outputs TBD | High | Follows ad hoc exploration |
| Add explicit `outlier_flag` boolean to hit_01 output | Low | Removes constant dependency in hit_02; non-blocking |
| YAML status updates for FACs 699, 719, 910, 930 | Low | Known pending carry-forward |
| HitProjectGuidelinesRev2.md — add hit_02 to script architecture | Low | Document the new script |
| Volume figure — confirm ind59 presence in data | Medium | From May 3 carry-forward; unresolved |

---

## Open Questions

| Question | Context |
|----------|---------|
| Does holding a FIN direction precede or follow financial deterioration? | FIN null result requires temporal analysis — plan start date vs. trajectory directionality |
| Does Teaching strategic divergence (04a) manifest as financial trajectory divergence? | type_summary shows Teaching rev +4.0, exp +0.8 — closer to Neither; needs deeper cut |
| What explains the 9 strategy-absent FACs? | 699, 719, 910, 930 are YAML-pending; 927, 933, 966, 981, 682 need checking |
| Is the COVID-era Expense-led spike plan-driven or period-driven? | Vintage confounded with disruption period — needs careful framing in narrative |

---

*Next session: ad hoc exploration of FIN directionality and Teaching financial
divergence from `hit_02_strategy_joined.csv`, then design hit_03.*
