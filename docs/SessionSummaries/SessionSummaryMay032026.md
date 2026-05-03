# Session Summary — May 3, 2026
## HospitalIntelligenceR

---

## Session Focus

HIT scope remediation — completing the registry and strategy pipeline fixes
identified in the April 30 session, re-running the full strategy analytical
stack, updating all affected narratives, and building the first two HIT
publication figures.

---

## What Was Accomplished

### 1. Registry YAML Edits — Complete

FACs 653 (Englehart), 696 (Kirkland), and 813 (Stratford General) marked
`retired: true` in `hospital_registry.yaml`. `merged_into` and `merger_hit_year`
fields added to each:

| FAC | merged_into | merger_hit_year |
|-----|-------------|-----------------|
| 653 | 982 | 2021/2022 |
| 696 | 982 | 2021/2022 |
| 813 | 983 | 2024/2025 |

Registry now contains **134 active hospitals**.

### 2. Strategy Pipeline Fixes — Complete

Two changes to `00_prepare_data.R`:

**Change 1 — Retired flag filter in spine build (Section 4):**
```r
spine_registry <- map(registry_raw$hospitals, function(h) {
  if (isTRUE(h$retired)) return(NULL)
  ...
})
```

**Change 2 — Retired FAC row filter in master_analytical (Section 7):**
```r
master_analytical <- master_analytical %>%
  filter(!is.na(hospital_type_group))
```
This drops the 15 direction rows for FACs 653/696/813 that remain in
`strategy_master.csv` but are now absent from the registry.

`00_prepare_data.R` confirmed output:
- Registry: 134 hospitals
- Dropped: 15 rows for retired FACs
- Analytical master: 574 rows, 125 unique FACs
- Spine: 134 rows

### 3. Strategy Pipeline Re-run — Complete

Full sequence run: `00_prepare_data.R` → `00c_build_strategy_classified.R`
→ `01b` → `03b` → `03c` → `04a` → `04b`

**Post-remediation strategy cohort (full):**

| Type group | n |
|------------|---|
| Teaching | 17 |
| Community — Large | 43 |
| Community — Small | 48 |
| Specialty | 11 |
| **Total** | **119** |

Current era (2024–2026): 65 hospitals.

CHEO (751) and SickKids (837) now correctly classified as Teaching throughout
all outputs. FACs 653/696/813 absent from all analytics. FAC 973 (2015 plan)
is the only era-excluded hospital — expected.

04b: 99 distinctive directions across 25 API cells, $0.19 USD.

### 4. Narrative Updates — Complete

All four strategy narratives rewritten with corrected cohort figures:

- `03b_narrative.md` — era breakdown 13/38/63 → 12/41/65; theme prevalence
  table fully updated; WRK +15.8pp, RES +23.3pp, EDI +14.8pp confirmed
- `03c_narrative.md` — Teaching 17 full/12 current, Specialty 11/8;
  WRK Teaching Current updated to 75% (n=12); RES composition artefact
  conclusion strengthened with corrected Teaching/Specialty split
- `04a_narrative.md` — all three lenses updated; Community — Large current
  Jaccard 0.498, Teaching divergence −0.034 delta confirmed
- `04b_narrative.md` — 99 distinctive directions; Women's College, UHN, and
  Heart Institute replace Sinai Health as Teaching headline outliers; CAMH
  remains Specialty headline

### 5. HIT Guidelines Updated — Complete

`HitProjectGuidelines.md` updated with:
- Section 5 (new) — Scope filter documentation with R pattern and rationale
- Section 6 (new) — Amalgamation year transition flags with full table
- Section 7 — Script architecture updated with hit_01 and re-run sequence
- Section 10 — Known items updated; HIT-only disposition, retired FACs,
  contaminated transitions marked resolved; UHN and alliances remain open

### 6. HIT Scope Remediation Narrative — Regenerated

`HIT_Scope_Remediation_Narrative.md` regenerated with accurate completion
status. Steps 1, 2, 7 marked complete; Steps 3, 4, 5 marked pending with
exact code patterns. Pre-remediation anchor data documented in Section 6.

### 7. HIT Scope Filter — Complete (Step 3 of Remediation)

Step 1b added to `hit_01_field_segmentation.R` immediately after indicator
filter. Confirmed output:

```
Registry FACs:            134
FACs before scope filter: 149
FACs after scope filter:  134
FACs removed:             15 (HIT-only + retired pre-merger)
```

### 8. HIT Amalgamation Flags — Complete (Step 4 of Remediation)

Investigated and confirmed: FACs 982 and 983 produce no contaminated
transitions in `yoy_adj` because MOH starts reporting consolidated entities
from scratch — no lag is possible for the amalgamation year. The
`anti_join` correctly removes 0 rows; flags are retained in output for
transparency.

### 9. Structural Outliers Identified and Flagged

FAC 854 (SA Grace) and FAC 971 (Sudbury St. Joseph's Continuing Care)
identified as structural outliers with cumulative revenue and expense scores
of ~99pp and ~102pp respectively. Revenue and expenses nearly tripled
2018–2025 driven by COVID-era funded expansion — transitional care /
hospital-at-home programs absorbing ALC and complex discharge patients.

Treatment: flagged as `outlier_flag = TRUE` in output, classified as
"Structural outlier" quadrant, excluded from quadrant percentage calculations.
Whether expansion is permanent is under investigation — classification will
be revisited if MOH confirms program continuity.

### 10. HIT Field Segmentation Re-run — Complete (Step 5 of Remediation)

`hit_01_field_segmentation.R` run to completion. Output:

**Quadrant distribution (131 hospitals, excluding 2 structural outliers):**

| Quadrant | n | % |
|----------|---|---|
| Revenue-led | 45 | 34.4% |
| Neither | 45 | 34.4% |
| Expense-led | 26 | 19.8% |
| Cost pressure | 11 | 8.4% |
| Both | 4 | 3.1% |
| Structural outlier | 2 | 1.5% |

**By type — key findings:**
- Community — Large: Revenue-led dominant (46.8%)
- Community — Small: Most distributed; elevated Cost pressure (12.3%)
- Specialty: Expense-led dominant (66.7%) — structurally coherent
- Teaching: Neither dominant (58.8%) — expected given scale and field median anchoring

**Outputs written:**
- `roles/hit/outputs/hit_01_field_trajectories.csv` — 133 rows
- `roles/hit/outputs/hit_01_segment_summary.csv` — 26 rows

### 11. Publication Figures — Built

**`fig_hit_field_medians.R`** — Sector-wide median YoY % change in total
revenue and total expenses across six transitions. Revenue solid teal,
expense dashed orange, COVID corridor annotated. Title: "Comparison of
Year over Year Revenue and Expense". Full fiscal year labels on x-axis.

**`fig_hit_volume_trends.R`** — Sector-wide median clinical volume indexed
to 2018/2019 = 100. Four indicators: Acute Inpatient Days (ind45), Total
Surgical Cases (ind54), Total ED Visits (ind56), Total Ambulatory Visits
(ind59 — present in data TBC). Standalone script — re-reads hit_master.csv
and applies scope filter independently. Same COVID corridor and fiscal year
x-axis treatment as field medians figure.

---

## Key Learnings and Decisions

**Retirement pattern — MOH starts fresh on amalgamation.** When hospitals
merge, MOH starts reporting the new consolidated entity as a new FAC from
scratch rather than continuing the predecessor's series. No contaminated
transition exists in the data; the anti_join approach is defensive but
correct.

**Small-denominator problem in percentage-based YoY.** Percentage-based
cumulative trajectory scores are sensitive to small-base hospitals with
funded expansions. Structural outlier flagging is the right treatment when
the underlying dynamic is a provincial program investment rather than
organic performance. Revisit classification annually.

**Specialty Expense-led finding (66.7%)** is the most analytically
distinctive type-stratified HIT finding to date. Structurally coherent —
chronic care and mental health hospitals have more stable cost bases and are
being compared against a field median anchored by the larger acute population.

**Core linking question confirmed:** Do strategic directions influence
financial and clinical performance? Tractable now that `hit_01_field_trajectories.csv`
and `strategy_classified.csv` share a FAC key. First cuts: FIN directions vs.
expense trajectories; PAT/ACC directions vs. volume recovery.

---

## Files Updated This Session

| File | Status |
|------|--------|
| `registry/hospital_registry.yaml` | Modified — FACs 653, 696, 813 retired |
| `analysis/scripts/00_prepare_data.R` | Modified — retired flag filter + row drop |
| `roles/strategy/outputs/extractions/strategy_master_analytical.csv` | Rebuilt |
| `analysis/data/hospital_spine.csv` | Rebuilt — 134 rows |
| `analysis/data/strategy_classified.csv` | Rebuilt |
| `roles/hit/scripts/hit_01_field_segmentation.R` | Modified — scope filter, amalgamation flags, structural outlier flags |
| `roles/hit/outputs/hit_01_field_trajectories.csv` | New — 133 rows |
| `roles/hit/outputs/hit_01_segment_summary.csv` | New — 26 rows |
| `docs/writing_and_research/03b_narrative.md` | Updated |
| `docs/writing_and_research/03c_narrative.md` | Updated |
| `docs/writing_and_research/04a_narrative.md` | Updated |
| `docs/writing_and_research/04b_narrative.md` | Updated |
| `roles/hit/HitProjectGuidelines.md` | Updated |
| `docs/writing_and_research/HIT_Scope_Remediation_Narrative.md` | Regenerated |
| `roles/hit/scripts/fig_hit_field_medians.R` | New |
| `roles/hit/scripts/fig_hit_volume_trends.R` | New |

---

## Carry-Forward Items

| Item | Priority | Notes |
|------|----------|-------|
| `hit_02_strategy_join.R` — join trajectories to strategy classifications | High | Next script in sequence |
| FIN direction vs. expense trajectory analysis | High | Core linking question — first cut |
| PAT/ACC direction vs. volume recovery analysis | High | Second linking cut |
| Volume figure review — confirm ind59 presence in data | Medium | Console output will confirm on first run |
| Weighted cases — CIHI HMDB / DAD linkage | Medium | Better clinical volume denominator; not in HIT Global |
| UHN 2023/24→2024/25 transition size check | Medium | WestPark scale vs UHN — contamination decision |
| `HIT_Scope_Remediation_Narrative.md` — update Step 5 status | Low | Mark complete after confirming figures |
| FAC 600 Atikokan reclaim | Low | Non-blocking — separate workstream |

---

## Open Questions

| Question | Context |
|----------|---------|
| Is SA Grace / Sudbury St. Joseph's COVID program permanent? | If MOH confirms continuation, reclassify from structural outlier to Revenue-led |
| Does ind59 (Total Ambulatory Visits) have data in hit_master? | Volume figure will confirm on first run |
| Is Teaching WRK Current (75%, n=12) plan architecture or genuine deprioritization? | Requires direction-level reading in Teaching hospitals |
| Will Rural Roads / Huron Health pairs consolidate in 2025/26 HIT data? | Monitor next annual download |

---

*Next session: begin hit_02_strategy_join.R and first strategy-performance linkage analysis.*
