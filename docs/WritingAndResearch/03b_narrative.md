# Strategic Theme Prevalence by Plan Era
## Ontario Public Hospitals — Temporal Analysis
*HospitalIntelligenceR | Analysis 03b | May 2026*

---

## Overview

This analysis examines whether the thematic composition of Ontario hospital strategic
plans has shifted across three plan eras spanning 2018–2026. The central question is
not whether hospitals write about different things in absolute terms, but whether the
*emphasis* placed on particular strategic themes has changed meaningfully over time —
and specifically, whether the disruption of the COVID-19 pandemic left a detectable
signature in how Ontario hospitals frame their strategic priorities.

---

## Data and Method

**Cohort:** 118 Ontario public hospitals with full or partial quality strategic plan
extractions, robots-allowed, and a parseable plan start year falling within the 2018–2026
window. One hospital with a plan start year outside this window is excluded (FAC 973,
historical 2015 plan).

**Unit of analysis:** Hospital. The metric reported is the percentage of hospitals in
each era that have at least one strategic direction classified to a given theme. This
*hospital prevalence* measure captures whether a theme is becoming more or less
commonly adopted across the sector — distinct from the *direction share* measure used
in Analysis 01b, which captures a theme's relative weight within an individual plan.

**Era definitions:**

| Era | Plan start years | n hospitals |
|-----|-----------------|-------------|
| Pre-COVID | 2018–2021 | 12 |
| Early Recovery | 2022–2023 | 41 |
| Current | 2024–2026 | 65 |

**Thematic taxonomy:** Ten active codes (GOV retired). Directions classified using
the Claude Sonnet API against a structured 10-code taxonomy.

**Plan date sourcing:** Plan start years derive from Phase 2 extraction. Where the
extraction prompt returned a null start year but a clear end year, a five-year horizon
assumption was applied (start = end − 4) for six hospitals. For a further eight hospitals,
dates were sourced from document titles, hospital websites, or direct email confirmation
from hospitals.

**Interpretive caution — Pre-COVID n:** The Pre-COVID group contains only 12 hospitals.
Point estimates for this era carry wide implicit uncertainty intervals. Directional
patterns are plausible and consistent with the literature, but should not be treated
as statistically robust. All temporal findings are framed as changing emphasis within
this cross-sectional dataset, not as causal trends.

---

## Theme Prevalence by Era

| Theme | Pre-COVID | Early Recovery | Current | Pre→Current shift |
|-------|-----------|----------------|---------|-------------------|
| WRK — Workforce & People | 75.0% | 92.7% | 90.8% | **+15.8 pp** |
| PAT — Patient Care & Quality | 75.0% | 80.5% | 75.4% | +0.4 pp |
| PAR — Partnerships & Community | 66.7% | 65.9% | 63.1% | −3.6 pp |
| FIN — Financial Sustainability | 50.0% | 41.5% | 44.6% | −5.4 pp |
| ACC — Access & Care Delivery | 33.3% | 31.7% | 40.0% | +6.7 pp |
| INN — Innovation & Digital Health | 25.0% | 19.5% | 35.4% | +10.4 pp |
| RES — Research & Academic | 16.7% | 14.6% | 40.0% | **+23.3 pp** |
| INF — Infrastructure & Operations | 16.7% | 22.0% | 26.2% | +9.5 pp |
| ORG — Organizational Culture | 16.7% | 9.8% | 10.8% | −5.9 pp |
| EDI — Equity, Diversity & Inclusion | 8.3% | 31.7% | 23.1% | **+14.8 pp** |

---

## Key Findings

### 1. Workforce (WRK) — The dominant post-COVID signal

The most striking finding is the sharp rise in workforce theme prevalence from the
Pre-COVID era to Early Recovery, which is then sustained at near-identical levels
into the Current era. In Pre-COVID plans, three in four hospitals included at least
one workforce direction. By Early Recovery, this had risen to more than nine in ten
— and Current plans show virtually identical prevalence (90.8%).

The pattern suggests a step-change rather than a gradual drift. Workforce moved from
a common but not universal strategic priority to what is now effectively a sector-wide
concern. This is consistent with the well-documented post-COVID staffing crisis in
Ontario hospitals — acute nursing shortages, burnout-driven attrition, and intensified
competition for clinical labour across the province. The fact that prevalence in
Current plans does not retreat from the Early Recovery peak suggests the sector has
not yet resolved these pressures and does not expect to in the near term.

WRK is the only theme that can be characterized as near-universal in current Ontario
hospital strategic planning.

### 2. Rank stability at the top — PAT, PAR, and FIN hold their positions

While WRK moved dramatically, the next three themes — Patient Care & Quality (PAT),
Partnerships & Community (PAR), and Financial Sustainability (FIN) — show remarkable
rank stability across all three eras. They occupy positions 2, 3, and 4 in every era,
and none show a shift exceeding 7 percentage points in either direction.

This stability is substantively meaningful. It suggests that the core of Ontario
hospital strategic planning — patient experience, system partnerships, and financial
viability — has not been displaced by post-COVID priorities. Hospitals added workforce
emphasis on top of an existing strategic foundation rather than reshuffling their
priorities. This is consistent with the accountability framework interpretation: QIPs,
Ontario Health agreements, and HSAA requirements create structural pressure to maintain
PAT and FIN as strategic commitments regardless of the external environment.

### 3. Research & Academic (RES) — The largest aggregate shift

RES shows the largest aggregate Pre-COVID → Current shift in the dataset at +23.3
percentage points (16.7% → 40.0%), and also the most unusual temporal pattern: a
modest dip in Early Recovery (14.6%) followed by a strong recovery in Current plans
(40.0%).

At the aggregate level the trajectory appears to describe a V-shape. However, Analysis
03c demonstrates that this aggregate pattern is a composition artefact and should not
be read as a sector-wide trend. When disaggregated by hospital type, RES proves to be
structurally stratified: near-universal in Teaching and Specialty hospitals across all
eras, newly emerging in Community — Large hospitals in the Current era, and absent in
Community — Small hospitals throughout. The aggregate fluctuation reflects which hospital
types happen to be writing plans in each era, not a genuine sector-wide ebb and flow
in research emphasis. The substantively correct interpretation of the RES finding is
developed in 03c.

### 4. Equity, Diversity & Inclusion (EDI) — A spike and partial retreat

EDI shows a distinctive pattern: near-absent in Pre-COVID plans (8.3%), it spiked
sharply in the Early Recovery era (31.7%), then retreated partially in Current plans
(23.1%). The Pre-COVID → Current shift of +14.8 percentage points falls just below
the 15-point threshold used here to identify major shifts, but the Early Recovery spike
is the largest single-era movement of any theme in either direction.

The Early Recovery spike aligns plausibly with the social equity conversation that
intensified in 2020–2021 following both the COVID-19 pandemic's disproportionate
impact on racialized communities and the broader social movement context of that period.
The partial retreat in Current plans does not necessarily indicate deprioritization.
It may reflect normalization — equity commitments that were newly foregrounded in
2022–2023 plans may now be embedded within other strategic directions (particularly
PAT and WRK) rather than standing as separate named directions.

### 5. Innovation (INN) and Infrastructure (INF) — Consistent upward trajectories

Both INN and INF show consistent upward trajectories from Pre-COVID through Current,
though neither as dramatically as WRK or RES. Innovation & Digital Health rises from
25.0% to 35.4% (+10.4 pp), and Infrastructure & Operations from 16.7% to 26.2%
(+9.5 pp). Both remain well below the sector-wide core themes in prevalence but have
meaningfully broadened their reach across the cohort.

The INN rise is consistent with the broader digital health transformation narrative
across the Ontario health system. The INF rise likely reflects post-COVID facility
investment backlogs and digital infrastructure needs exposed by the rapid shift to
virtual care during the pandemic.

### 6. Organizational Culture (ORG) — Consistently low and stable

ORG is the lowest-prevalence theme in every era and shows minimal net change across
the period (16.7% → 9.8% → 10.8%). Explicit organizational culture directions are
not a common feature of Ontario hospital strategic planning. Culture content is more
often addressed implicitly within WRK directions rather than named as a standalone
priority.

---

## Summary of Confirmed Shifts (Pre-COVID → Current)

Two themes cross the 15 percentage point threshold from Pre-COVID to Current:

- **RES +23.3 pp** — the largest aggregate shift; interpret as type-composition effect (see 03c)
- **WRK +15.8 pp** — sector-wide step-change; the most robust behavioural signal in the dataset

One additional theme shows a substantial but sub-threshold shift worth narrative attention:

- **EDI +14.8 pp** — spike in Early Recovery, partial retreat in Current; net gain meaningful

---

## Methodological Notes for Reporting

**Cross-sectional design:** This analysis compares different hospitals' plans from
different years. It is not a panel study tracking the same hospitals over time.
Conclusions should be framed as "the thematic composition of plans written in [era]
differs from plans written in [era]" rather than "hospitals changed their strategic
priorities over time."

**Pre-COVID small n:** With 12 hospitals in the Pre-COVID group, percentage-point
shifts from that baseline carry substantial uncertainty. The WRK finding (+15.8 pp)
is robust enough that it would remain a large shift even with considerable sampling
variability. RES and EDI are more sensitive to the composition of the Pre-COVID group.

**Five-year horizon assumption:** Six hospitals received imputed plan start years
based on a five-year horizon from a known end year. The assumption is consistent with
standard Ontario hospital planning cycles and is documented in the patch log.

**Plan date sourcing variation:** Plan dates derive from multiple sources of varying
reliability — direct document extraction (most reliable), document titles, hospital
websites, email confirmation, and the five-year horizon assumption. This heterogeneity
in date quality is an acknowledged limitation of the temporal analysis.

---

## Next Steps

This analysis establishes the temporal baseline for the strategy role. Three directions
follow naturally:

1. **Era × hospital type interaction** — do the WRK and RES trends hold uniformly
   across Teaching, Community Large, Community Small, and Specialty hospitals, or are
   they concentrated in specific segments? (Addressed in Analysis 03c.)

2. **CIHI linkage** — once the CIHI crosswalk is in place, test whether hospitals
   with explicit quality (PAT) and access (ACC) directions show different performance
   trajectories on relevant CIHI indicators.

3. **Board minutes linkage** — when the minutes role is built, test whether the
   strategic themes identified here appear in board deliberations, as the Denis et al.
   literature predicts they may not.
