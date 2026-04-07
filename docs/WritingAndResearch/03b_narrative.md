# Strategic Theme Prevalence by Plan Era
## Ontario Public Hospitals — Temporal Analysis
*HospitalIntelligenceR | Analysis 03b | April 2026*

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

**Cohort:** 114 Ontario public hospitals with full or partial quality strategic plan
extractions, robots-allowed, and a parseable plan start year falling within the 2018–2026
window. Two hospitals with plan start years outside this window are excluded (FAC 973,
historical 2015 plan; FAC 953, classified start year 2030 — a data artefact).

**Unit of analysis:** Hospital. The metric reported is the percentage of hospitals in
each era that have at least one strategic direction classified to a given theme. This
*hospital prevalence* measure captures whether a theme is becoming more or less
commonly adopted across the sector — distinct from the *direction share* measure used
in Analysis 01b, which captures a theme's relative weight within an individual plan.

**Era definitions:**

| Era | Plan start years | n hospitals |
|-----|-----------------|-------------|
| Pre-COVID | 2018–2021 | 13 |
| Early Recovery | 2022–2023 | 38 |
| Current | 2024–2026 | 63 |

**Thematic taxonomy:** Ten active codes (GOV retired). Directions classified using
the Claude Sonnet API against a structured 10-code taxonomy.

**Plan date sourcing:** Plan start years derive from Phase 2 extraction. Where the
extraction prompt returned a null start year but a clear end year, a five-year horizon
assumption was applied (start = end − 4) for six hospitals. For a further eight hospitals,
dates were sourced from document titles, hospital websites, or direct email confirmation
from hospitals. Four hospitals in the usable cohort remain without parseable plan
dates and are excluded from this analysis.

**Interpretive caution — Pre-COVID n:** The Pre-COVID group contains only 13 hospitals.
Point estimates for this era carry wide implicit uncertainty intervals. Directional
patterns are plausible and consistent with the literature, but should not be treated
as statistically robust. All temporal findings are framed as changing emphasis within
this cross-sectional dataset, not as causal trends.

---

## Theme Prevalence by Era

| Theme | Pre-COVID | Early Recovery | Current | Pre→Current shift |
|-------|-----------|----------------|---------|-------------------|
| WRK — Workforce & Culture | 69.2% | 92.1% | 91.9% | **+22.7 pp** |
| PAT — Patient Experience & Quality | 69.2% | 81.6% | 75.8% | +6.6 pp |
| PAR — Partnerships & Integration | 61.5% | 68.4% | 67.7% | +6.2 pp |
| FIN — Financial Sustainability | 46.2% | 42.1% | 46.8% | +0.6 pp |
| ACC — Access & Care Delivery | 30.8% | 31.6% | 35.5% | +4.7 pp |
| RES — Research & Academic | 23.1% | 10.5% | 38.7% | **+15.6 pp** |
| INN — Innovation & Digital Health | 23.1% | 21.1% | 33.9% | +10.8 pp |
| INF — Infrastructure & Operations | 15.4% | 23.7% | 30.6% | **+15.2 pp** |
| ORG — Organizational Culture | 15.4% | 7.9% | 14.5% | −0.9 pp |
| EDI — Equity, Diversity & Inclusion | 7.7% | 31.6% | 21.0% | +13.3 pp |

---

## Key Findings

### 1. Workforce (WRK) — The dominant post-COVID signal

The most striking finding is the sharp rise in workforce theme prevalence from the
Pre-COVID era to Early Recovery, which is then sustained at near-identical levels
into the Current era. In Pre-COVID plans, roughly seven in ten hospitals included
at least one workforce direction. By Early Recovery, this had risen to more than nine
in ten — and Current plans show virtually identical prevalence (91.9%).

The pattern suggests a step-change rather than a gradual drift. Workforce moved from
a common but not universal strategic priority to what is now effectively a sector-wide
concern. This is consistent with the well-documented post-COVID staffing crisis in
Ontario hospitals — acute nursing shortages, burnout-driven attrition, and intensified
competition for clinical labour across the province. The fact that prevalence in
Current plans does not retreat from the Early Recovery peak suggests the sector has
not yet resolved these pressures and does not expect to in the near term.

WRK is the only theme that can be characterized as near-universal in current Ontario
hospital strategic planning.

### 2. Rank stability at the top — PAT, PAR, FIN hold their positions

While WRK moved dramatically, the next three themes — Patient Experience & Quality
(PAT), Partnerships & Integration (PAR), and Financial Sustainability (FIN) — show
remarkable rank stability across all three eras. They occupy positions 2, 3, and 4
in every era, and none show a shift exceeding 7 percentage points in either direction.

This stability is substantively meaningful. It suggests that the core of Ontario
hospital strategic planning — patient experience, system partnerships, and financial
viability — has not been displaced by post-COVID priorities. Hospitals added workforce
emphasis on top of an existing strategic foundation rather than reshuffling their
priorities. This is consistent with the accountability framework interpretation: QIPs,
Ontario Health agreements, and HSAA requirements create structural pressure to maintain
PAT and FIN as strategic commitments regardless of the external environment.

### 3. Research & Academic (RES) — A V-shaped recovery

RES shows the most unusual temporal pattern in the dataset: a sharp dip in the Early
Recovery era (10.5%) followed by a strong recovery in Current plans (38.7%). In the
Pre-COVID era, roughly one in four hospitals included a research or academic direction.
This fell to approximately one in ten in Early Recovery plans before rising to nearly
two in five in the most current plans.

The Early Recovery dip is plausible on its face — hospitals under acute operational
pressure from COVID-19 may have deprioritized research and academic activities in
favour of stabilization priorities. The subsequent recovery in Current plans may reflect
both the normalization of operations and the renewed strategic importance of clinical
research partnerships, particularly given Ontario Health's emphasis on academic health
networks and the Teaching hospital sector's expanded footprint in Current-era planning.

It should be noted that RES is disproportionately a Teaching hospital theme, and the
distribution of hospital types across eras is not perfectly balanced. Three of the four
Teaching hospitals with parseable plan dates are in the Current era, which may
contribute mechanically to the recovery in RES prevalence. This composition effect
should be examined before drawing strong conclusions about the RES trajectory.

### 4. Infrastructure (INF) and Innovation (INN) — Gradual but consistent rise

Both INF and INN show consistent upward trajectories from Pre-COVID through Current,
though neither as dramatically as WRK. Infrastructure & Operations rises from 15.4%
to 30.6% (+15.2 pp), and Innovation & Digital Health from 23.1% to 33.9% (+10.8 pp).

The INF rise likely reflects a combination of post-COVID facility investment backlogs,
digital infrastructure needs exposed by the rapid shift to virtual care during the
pandemic, and Ontario Health's capital planning priorities. The INN rise is consistent
with the broader digital health transformation narrative — electronic health records,
virtual care platforms, and AI-enabled clinical decision support have moved from
peripheral to mainstream strategic concerns in the sector.

### 5. Equity, Diversity & Inclusion (EDI) — A spike and partial retreat

EDI shows a distinctive pattern: near-absent in Pre-COVID plans (7.7%), it spiked
sharply in the Early Recovery era (31.6%), then retreated partially in Current plans
(21.0%). The Early Recovery spike aligns plausibly with the social equity conversation
that intensified in 2020–2021 following both the COVID-19 pandemic's disproportionate
impact on racialized communities and the broader social movement context of that period.

The partial retreat in Current plans does not necessarily indicate that hospitals have
deprioritized equity. It may reflect normalization — equity language and commitments
that were newly foregrounded in 2022–2023 plans may now be embedded within other
strategic directions (particularly PAT and WRK) rather than standing as separate
named directions. This possibility warrants closer examination at the direction
description level before concluding that equity emphasis has genuinely declined.

### 6. Organizational Culture (ORG) — Consistently low and stable

ORG is the lowest-prevalence theme in every era and shows minimal change across the
period (15.4% → 7.9% → 14.5%). This is consistent with the decision — previously
noted — to consider retiring or consolidating ORG. Its low prevalence suggests that
explicit organizational culture directions are not a common feature of Ontario hospital
strategic planning, with culture more often addressed implicitly within WRK directions.

---

## Summary of Confirmed Shifts (Pre-COVID → Current)

Three themes cross the 15 percentage point threshold from Pre-COVID to Current:

- **WRK +22.7 pp** — the clearest and most robust signal in the dataset
- **INF +15.2 pp** — consistent upward trajectory across all three eras
- **RES +15.6 pp** — V-shaped pattern; composition effects may contribute

Two additional themes show substantial but sub-threshold shifts worth narrative attention:

- **EDI +13.3 pp** — spike in Early Recovery, partial retreat in Current
- **INN +10.8 pp** — consistent upward trend, moderated from earlier estimates

---

## Methodological Notes for Reporting

**Cross-sectional design:** This analysis compares different hospitals' plans from
different years. It is not a panel study tracking the same hospitals over time.
Conclusions should be framed as "the thematic composition of plans written in [era]
differs from plans written in [era]" rather than "hospitals changed their strategic
priorities over time."

**Pre-COVID small n:** With 13 hospitals in the Pre-COVID group, percentage-point
shifts from that baseline carry substantial uncertainty. The WRK finding (+22.7 pp)
is robust enough that it would remain a large shift even with considerable sampling
variability. RES and INF are more sensitive to the composition of the Pre-COVID group.

**Five-year horizon assumption:** Six hospitals received imputed plan start years
based on a five-year horizon from a known end year. These hospitals contribute to
the Current era (five hospitals: 942, 959, 975, and others) and Early Recovery era
(one hospital: 662). The assumption is consistent with standard Ontario hospital
planning cycles and is documented in the patch log.

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
   they concentrated in specific segments?

2. **CIHI linkage** — once the CIHI crosswalk is in place, test whether hospitals
   with explicit quality (PAT) and access (ACC) directions show different performance
   trajectories on relevant CIHI indicators.

3. **Board minutes linkage** — when the minutes role is built, test whether the
   strategic themes identified here appear in board deliberations, as the Denis et al.
   literature predicts they may not.
