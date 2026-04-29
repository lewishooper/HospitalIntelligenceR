# HIT Analytics — Project Plan
## HospitalIntelligenceR
*April 2026 | docs/programming_reference/*

---

## 1. Overview and Analytical Goal

This workstream joins `hit_master.csv` (Ontario Ministry of Health financial
indicators, 7 fiscal years, 137 registry-matched FACs) to the strategy analytics
outputs to test whether a hospital's strategic emphasis on financial performance
is associated with — and potentially predictive of — actual financial improvement.

The analytical program has three distinct layers. The first is purely descriptive
and strategy-agnostic: characterizing financial performance trajectories across
the field. The second is correlational: comparing hospitals with and without a
FIN strategic emphasis. The third is quasi-experimental: testing whether FIN
adoption predicts subsequent improvement relative to the field trend.

These layers are deliberately sequenced. The field characterization in Step 3
is the reference frame that makes the strategy comparison in Steps 4–6
interpretable. Results from each layer inform the design of the next.

---

## 2. Analytical Questions

The following questions are addressed in order. Each is more causally demanding
than the prior, and each depends on a clean answer from the prior step.

**Question A — Association.** Do hospitals with FIN-coded strategic directions
show stronger financial performance indicators in aggregate? This is a
cross-sectional comparison that establishes whether there is any signal to
pursue before investing in the more demanding longitudinal design.

**Question B — Sequence.** What was each hospital's financial position before
FIN adoption, and what did it look like after? This establishes temporal ordering
— a necessary (but not sufficient) condition for causal inference.

**Question C — Performance relative to field.** Did FIN-emphasis hospitals
improve financially at a faster rate than non-FIN hospitals during the same
period, net of the sector-wide MOH revenue environment? This is the central
causal question, answered by field-adjusted change scores rather than raw
before/after comparisons.

**Question D — Mechanism.** Where improvement occurred, was it driven by
expense control, revenue growth, or both? For hospitals where both contributed,
what was the proportional split?

**Question E — Field normalization.** MOH transfer revenues increase
sector-wide in most years, creating a rising-tide effect. Individual hospital
changes must be normalized against the field median year-over-year change before
any hospital-level conclusions are drawn. This is not a separate question — it
is a methodological requirement embedded in questions C and D.

---

## 3. Prerequisite — Indicator Mapping

Before any analytical script is written, the 55 active HIT indicators must be
reviewed and a working classification established. The analysis depends on
identifying at minimum:

- **Total revenue** — and ideally MOH/government transfer revenue as a
  separate line from patient-pay and other revenue
- **Total expenses** — and ideally labour versus non-labour split
- **Net surplus or deficit** — or a margin proxy if a direct surplus field
  is not present

This mapping is Step 1 and is blocking for all subsequent steps. The indicator
names are in `GlobalIndicatorLkup.rds` (`FullName` and `ShortName` columns).
The session begins with reviewing this lookup and agreeing on a working
indicator classification before any code is written.

A secondary enrichment option exists: the Ministry PDF manual
(`HIT_Global Indicator Manual_2425Q3_1_1.docx`) contains richer metadata
including units, direction of improvement, and category groupings. Parsing
this via the Claude API would enable more precise composite indicator analysis
and is worth considering if the RDS names alone are ambiguous for our purposes.
This is a session-start decision.

---

## 4. Step Sequence

### Step 1 — Indicator Review and Classification

**Goal:** Produce a working indicator classification table identifying which of
the 55 active HIT indicators map to revenue, expenses, surplus/deficit, and
potentially volume or FTE concepts relevant to the analysis.

**Input:** `GlobalIndicatorLkup.rds` (74 rows, 4 columns: `ind`, `FullName`,
`ShortName`, `PageNumber`)

**Output:** A working classification table — agreed in session before any code
is written. Not a formal deliverable; captured in session notes. Will inform
the indicator filter applied in all downstream scripts.

**Session action:** Skip pastes the indicator list at session start. Claude
and Skip review and agree on classification before proceeding.

---

### Step 2 — Define Treatment Variable and Fiscal-Year Bridge

**Goal:** Establish clean, reproducible definitions for the two design elements
that underpin all subsequent analysis.

**Treatment definition.** FIN-emphasis treatment is defined as: a hospital had
at least one FIN-coded direction in its active strategic plan. This maps
directly to `strategy_classified.csv`. A hospital is treated for the duration
of its plan period. Hospitals with no plan in the analytical window, or with
unknown plan dates, are excluded from the temporal analysis.

**Fiscal-year bridging rule.** Strategy plan dates are calendar years.
HIT fiscal years run April 1 – March 31 and are labeled as `YYYY/YYYY`
(e.g. `2022/2023`). The bridge rule is: a plan with `plan_start_year = Y`
maps to HIT fiscal year `Y/Y+1` as its first treatment year. Pre-treatment
is all HIT years before `Y/Y+1`. Post-treatment is `Y/Y+1` through the year
corresponding to `plan_end_year`.

**Output:** No script in this step — decisions are documented and embedded
in the join script in Step 3.

---

### Step 3 — Field Financial Performance Segmentation

*This is the standalone descriptive workstream — strategy-agnostic. It is also
the reference frame for all subsequent comparative analysis.*

**Goal:** Characterize Ontario hospital financial performance trajectories from
2018/2019 through 2024/2025. Identify which hospitals improved financially
over the period, and classify the gross mechanism of improvement as revenue-led,
expense-led, or both.

**Design.** Each hospital is scored on two dimensions over the full analysis
window using field-adjusted year-over-year change (hospital YoY % change minus
field median YoY % change for that year). This normalization removes sector-wide
MOH transfer effects — critically important for 2020/2021 through 2022/2023
when COVID-era transfers inflated revenue across the board.

Revenue trajectory and expense trajectory are each classified as improving,
flat, or declining (thresholds to be set at session time based on the
distribution). The combination produces a segmentation with the following
analytically meaningful quadrants:

- **Revenue-led improvement** — top-line grew materially, expenses tracked
  or lagged
- **Expense-led improvement** — cost control was the primary driver, revenue
  roughly flat relative to field
- **Both** — both revenue and expense improvement contributed. For hospitals
  in this quadrant, a proportional decomposition is computed:
  `revenue share = Δrevenue contribution / (Δrevenue + Δcost savings)`
- **Neither** — flat or deteriorating performance relative to field

**Script:** `hit_01_field_segmentation.R`

**Outputs:**
- `hit_01_field_trajectories.csv` — one row per FAC with revenue trajectory
  score, expense trajectory score, quadrant classification, and proportional
  metric for the "both" quadrant
- `hit_01_segment_summary.csv` — count and percentage of hospitals per
  quadrant, by hospital type group

**Figures:** A baseball graph (sorted lollipop) showing field-adjusted
cumulative financial change per hospital is a natural output here, consistent
with the figure standards established in `fig_hit_rev_change.R`. A 2×2
quadrant chart showing hospital counts per segment is the natural summary
figure for the LinkedIn piece.

**Narrative:** This step produces a standalone deliverable — both a technical
narrative and a publication-facing LinkedIn post. The LinkedIn post angle is:
"Here is how Ontario hospitals actually improved their finances — and which
lever they pulled." The segmentation finding is the story; the proportional
decomposition for "both" hospitals adds texture.

---

### Step 4 — Build Strategy-HIT Analytical Join

**Goal:** Produce the master analytical dataset joining strategy classifications
to HIT financial performance. All subsequent scripts read from this joined
dataset — it is the analytical equivalent of `strategy_master_analytical.csv`
for the strategy-only analysis.

**Join logic.** Three-way join:

1. `strategy_classified.csv` provides FIN treatment flag, plan period dates,
   and hospital type group by FAC
2. `hit_master.csv` provides financial indicator values by FAC and fiscal year
3. The fiscal-year bridge (Step 2) determines whether each HIT year is
   pre-treatment, during-treatment, or post-treatment for each hospital

**Key design decision:** Hospitals with no usable plan dates (the 15 hospitals
excluded from temporal analysis in the strategy work) are excluded from the
pre/post analysis but can be included in the cross-sectional comparison if
their HIT data is present.

**Script:** `hit_02_strategy_join.R`

**Output:** `hit_strategy_analytical.csv` — one row per FAC × fiscal year ×
indicator, with FIN treatment flag, treatment phase (pre/during/post), plan
dates, and hospital type group joined in. FAC as character throughout.

---

### Step 5 — Cross-Sectional Comparison (Question A)

**Goal:** Test whether FIN-emphasis hospitals show systematically different
financial performance in aggregate, without regard to timing.

**Design.** Summarize each hospital's mean financial performance on the
identified indicators across all available years. Compare FIN vs non-FIN
hospitals on these summary metrics. Stratify by hospital type group —
Teaching and Community hospitals have structurally different financial profiles
and should not be pooled without justification.

**Script:** `hit_03_fin_crosssection.R`

**Output:** `hit_03_fin_crosssection.csv` — summary statistics by FIN status
and hospital type group. Visualization TBD at session time.

---

### Step 6 — Pre/Post with Field Adjustment (Questions B, C, E)

**Goal:** Test whether FIN adoption is followed by financial improvement
relative to the field trend. This is the central quasi-experimental analysis.

**Design.** For each FIN-adopting hospital, compute field-adjusted change in
the key financial indicators from pre-treatment to post-treatment. Compare to
the field-adjusted change for non-FIN hospitals over the same calendar window.

The comparison group is hospitals without FIN emphasis in the same era (Pre-2020
or Post-2020, using the era definitions from the strategy analytics). This
controls for secular time trends within era.

A critical confound must be explicitly acknowledged: hospitals in worse
financial positions are more likely to adopt a FIN emphasis, so poor
pre-treatment performance is expected by construction. The analytically
interesting signal is whether FIN hospitals improved *faster* than similarly-
situated non-FIN hospitals — not whether they improved at all.

**Script:** `hit_04_fin_prepost.R`

**Output:** `hit_04_fin_prepost.csv` — pre/post change scores (raw and
field-adjusted) by FIN status, era, and hospital type group.

---

### Step 7 — Expense vs Revenue Decomposition (Question D)

**Goal:** For hospitals that showed financial improvement, classify whether
the improvement was revenue-driven, expense-driven, or both — and compute
the proportional split for dual-mechanism hospitals.

This step applies the same decomposition logic as Step 3 but scoped to
FIN-emphasis hospitals specifically, enabling a direct comparison: do FIN
hospitals pull a different lever than the field as a whole?

**Script:** `hit_05_decomposition.R`

**Output:** `hit_05_decomposition.csv` — mechanism classification and
proportional metric per FIN hospital, with comparison to field baseline
from Step 3.

---

## 5. Script Naming and Location

All HIT analytics scripts live in `roles/hit/scripts/`. Naming follows the
step sequence:

| Script | Step | Description |
|--------|------|-------------|
| `hit_import.R` | — | Import — complete |
| `hit_validate.R` | — | Validation — complete |
| `hit_01_field_segmentation.R` | 3 | Field-level financial segmentation |
| `hit_02_strategy_join.R` | 4 | Strategy-HIT analytical join |
| `hit_03_fin_crosssection.R` | 5 | Cross-sectional FIN vs non-FIN |
| `hit_04_fin_prepost.R` | 6 | Pre/post field-adjusted analysis |
| `hit_05_decomposition.R` | 7 | Expense vs revenue decomposition |

Output CSVs go to `roles/hit/outputs/`. Figure scripts, when built, follow
the figure standards in `docs/figure_standards.md` and the Baseball graph
convention established in `fig_hit_rev_change.R`.

---

## 6. Key Design Constraints

**FAC as character throughout.** Every script in this workstream must coerce
`fac` to character immediately on load. HIT FACs come from a CSV where they
may read as integer. Numeric FAC causes join failures and ggplot continuous
scale errors. No exceptions.

**Field normalization is not optional.** MOH transfer revenues increased
substantially in 2020/2021 through 2022/2023. Any year-over-year comparison
that does not subtract the field median for that year will find spurious
"improvement" in every hospital during the COVID transfer window. All change
scores in Steps 3, 5, and 6 use field-adjusted values.

**Hospital type stratification.** Teaching and community hospitals are not
directly comparable on financial metrics — scale, funding model, and mandate
differ materially. All comparative analyses stratify by `hospital_type_group`
or explicitly justify pooling.

**Confound acknowledgment.** The relationship between poor financial
performance and FIN adoption is directional by design — hospitals in trouble
adopt financial strategies. Pre-treatment performance differences between FIN
and non-FIN hospitals are expected and do not invalidate the analysis.
The analysis is designed around change relative to field, not absolute levels.

**12 HIT-only FACs.** FACs 600, 601, 605, 613, 633, 680, 687, 765, 792, 801,
855, 908 are present in HIT but not in the registry. These do not affect any
analysis — they have no strategy data and will drop naturally on the join.
They are retained in `hit_master.csv` but are not in scope for this workstream.

---

## 7. Deliverables

| Deliverable | Type | Step |
|---|---|---|
| Working indicator classification table | Session notes | 1 |
| `hit_01_field_trajectories.csv` | Analytical CSV | 3 |
| `hit_01_segment_summary.csv` | Analytical CSV | 3 |
| Field segmentation — technical narrative | Markdown | 3 |
| Field segmentation — LinkedIn post | Publication narrative | 3 |
| `hit_strategy_analytical.csv` | Analytical CSV (join) | 4 |
| `hit_03_fin_crosssection.csv` | Analytical CSV | 5 |
| `hit_04_fin_prepost.csv` | Analytical CSV | 6 |
| `hit_05_decomposition.csv` | Analytical CSV | 7 |
| HIT analytics — technical narrative | Markdown | Post Step 7 |
| HIT analytics — publication narrative | Markdown | Post Step 7 |

---

## 8. Open Items Before First Session

The following items must be resolved at or before session start:

- **Indicator review** — Skip pastes the `GlobalIndicatorLkup.rds` contents
  (or reads them in session) so financial performance indicators can be
  identified and agreed before any code is written
- **Indicator manual decision** — decide whether to parse
  `HIT_Global Indicator Manual_2425Q3_1_1.docx` for richer metadata before
  beginning, or proceed with RDS names alone
- **Cohort confirmation** — confirm the strategy-side cohort: how many of the
  137 HIT-matched FACs also have strategy data and confirmed plan dates?
  This determines the pre/post analysis sample size

---

*This document lives in `docs/programming_reference/`. Update when analytical
design decisions are revised or step outputs change.*
