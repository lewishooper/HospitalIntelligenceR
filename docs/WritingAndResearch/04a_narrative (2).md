# Strategic Homogeneity in Ontario Hospital Strategic Plans
## Ontario Public Hospitals — Theme Breadth, Core Profile Alignment, and Pairwise Similarity
*HospitalIntelligenceR | Analysis 04a | April 2026*

---

## Overview

This analysis asks whether Ontario hospital strategic plans are effectively the
same — whether the thematic portfolios hospitals choose are so similar across
the sector that the plans are functionally interchangeable, or whether meaningful
differentiation exists within and across hospital type groups.

The question is posed in two temporal scopes: the full usable cohort (all plan
eras, 2018–2026) and the Current era only (plan start years 2024–2026). The full
cohort provides a stable baseline with more statistical power; the Current era
reflects the most recent strategic moment and is the primary policy-relevant
window. A three-era breakdown (Pre-COVID / Early Recovery / Current) was
considered but not pursued: the Pre-COVID group contains only 13 hospitals,
which is too small to produce reliable core profiles or pairwise Jaccard
statistics. Running three scopes would place a numerically weak estimate
alongside two robust ones and invite false precision. The two-scope design
is intentional.

Three complementary lenses address the homogeneity question:

**Lens 1 — Theme breadth:** How many themes does a typical hospital cover, and
how much does this vary within and across type groups?

**Lens 2 — Core profile alignment:** For each hospital type group, which themes
constitute the modal consensus, and how closely does each hospital match that
consensus?

**Lens 3 — Pairwise Jaccard similarity:** Treating each hospital's theme set as
a binary vector, how similar are any two hospitals to one another — within the
same type group, and across type groups?

---

## Data and Method

**Cohort:** 122 Ontario public hospitals with usable classified directions form
the full cohort. The Current era cohort contains 68 hospitals with plan start
years 2024–2026. Both scopes include hospitals across all four type groups:
Teaching, Community — Large, Community — Small, and Specialty.

**Unit of analysis:** Hospital. Each hospital is represented as a binary theme
vector — a set of 10 possible themes, with each theme marked present or absent
based on whether at least one direction from that hospital was classified to that
theme using its **primary theme** classification. Secondary theme classifications
are not used in this analysis.

**Theme count and extraction depth:** A hospital's theme count is bounded below
by its direction count — a hospital with only two extracted directions cannot
cover more than two primary themes regardless of what it has written. Thin
extractions therefore compress the breadth distribution toward the lower end,
making the sector appear marginally more homogeneous than it may be in practice.
This caveat applies most acutely to hospitals with partial-quality extractions.

**Core profile definition:** For each hospital type group, themes present in
50% or more of hospitals in that group are designated as core. The 50% threshold
is a methodological choice; themes at 45–55% prevalence straddle the boundary
and should be treated as marginal consensus rather than strong consensus. A
hospital "fully matches" the core profile if it has every core theme for its
type group. Missing core themes are counted per hospital.

**Jaccard similarity:** For every pair of hospitals within a given scope, Jaccard
similarity is computed as:

> Jaccard(A, B) = |A ∩ B| / |A ∪ B|

where A and B are each hospital's set of present themes. The intersection is the
number of themes both hospitals share; the union is the total number of distinct
themes present in either hospital. Jaccard = 1.0 means identical theme portfolios;
Jaccard = 0 means no shared themes at all. A value of 0.5 means the two hospitals
share half their combined theme coverage.

As a concrete example: if Hospital A covers WRK, PAT, PAR, and FIN (4 themes)
and Hospital B covers WRK, PAT, INN, and RES (4 themes), the intersection is
{WRK, PAT} = 2, the union is {WRK, PAT, PAR, FIN, INN, RES} = 6, and the Jaccard
similarity is 2/6 = 0.33. Jaccard is the appropriate measure here because it
normalizes for set size — a hospital covering 3 themes and one covering 8 themes
can be compared on a common scale without penalizing either for its portfolio size.

Pairs are categorized as within-type (both hospitals in the same type group) or
between-type (hospitals in different type groups). Summary statistics are reported
by pair type and scope.

**Scope comparison:** Full cohort and Current era results are reported in parallel
for all three lenses. Delta statistics (Current era − Full cohort) flag where the
Current era differs meaningfully from the historical baseline.

---

## Lens 1: Theme Breadth

### Summary statistics

| Scope | Type group | n | Mean themes | Median | SD | Range |
|-------|------------|---|-------------|--------|----|-------|
| Full cohort | Teaching | 15 | 4.6 | 5.0 | 1.35 | 3–7 |
| Full cohort | Community — Large | 44 | 4.4 | 4.0 | 1.48 | 2–8 |
| Full cohort | Community — Small | 50 | 4.1 | 4.0 | 1.08 | 2–7 |
| Full cohort | Specialty | 13 | 4.4 | 5.0 | 0.87 | 3–5 |
| Full cohort | All types | 122 | 4.3 | 4.0 | 1.25 | — |
| Current era | Teaching | 10 | 4.4 | 4.5 | 1.43 | 3–7 |
| Current era | Community — Large | 21 | 4.9 | 5.0 | 1.64 | 3–8 |
| Current era | Community — Small | 27 | 4.2 | 4.0 | 1.36 | 2–7 |
| Current era | Specialty | 10 | 4.7 | 5.0 | 0.67 | 3–5 |
| Current era | All types | 68 | 4.5 | 5.0 | 1.40 | — |

### Interpretation

The central finding across both scopes is that Ontario hospitals are concentrated
in a 4–5 theme band. The full cohort overall mean is 4.3 themes; the Current era
mean is 4.5 themes. The median shifts from 4 to 5 between scopes, suggesting a
modest broadening in the Current era rather than a structural change in
distribution.

Specialty hospitals are the most internally consistent group. Their standard
deviation is 0.87 in the full cohort and narrows to 0.67 in the Current era,
with a range bounded at 3–5 in both scopes. This reflects the more constrained
mandate of Specialty hospitals — mission specificity limits strategic dispersion.

Community — Large hospitals show the widest within-group spread in the Current
era (SD 1.64, range 3–8). This is the only type group where some hospitals reach
8 themes, approaching the upper limit of the 10-code taxonomy. The wider spread
is consistent with the 03c finding that this group is in a period of active
strategic expansion, particularly around RES and INN themes.

Teaching hospitals have comparable dispersion in both scopes (SD 1.35 full,
1.43 current). The minimum breadth in the Teaching group is 3 themes in both
scopes — no Teaching hospital covers fewer than 3 primary themes. Despite this
floor, the Teaching group contains the widest range of strategic orientations,
driven by hospitals with distinctly specialized missions (detailed in Analysis
04b).

The practical implication of the breadth analysis alone is limited. A hospital
with 4 themes and a hospital with 6 themes may be covering the same core
territory — the identity of the themes matters more than the count. Lenses 2
and 3 address this directly.

---

## Lens 2: Core Profile Alignment

### Core profiles by type group

Core themes are those present in ≥50% of hospitals within a type group. Core
profiles differ between scopes because the hospital sample within each type
group changes across eras, and because some themes have shifted in adoption
rate over time.

**Full cohort core profiles:**

| Type group | n | Core themes (≥50% prevalence) |
|------------|---|-------------------------------|
| Teaching | 15 | RES (93%), WRK (79%), PAT (57%), EDI (57%) |
| Community — Large | 44 | WRK (98%), PAT (86%), PAR (72%) |
| Community — Small | 50 | WRK (87%), PAR (82%), PAT (73%), FIN (58%) |
| Specialty | 13 | WRK (85%), PAT (85%), RES (69%), ACC (54%) |

**Current era core profiles:**

| Type group | n | Core themes (≥50% prevalence) |
|------------|---|-------------------------------|
| Teaching | 10 | RES (88%), WRK (75%), PAT (50%), EDI (50%), PAR (50%) |
| Community — Large | 21 | WRK (100%), PAT (86%), PAR (81%), INN (52%) |
| Community — Small | 27 | WRK (91%), PAT (70%), PAR (74%), FIN (57%) |
| Specialty | 10 | WRK (90%), PAT (90%), RES (70%), FIN (50%) |

**WRK and PAT are the two sector-wide universal core themes** — present in
the core profile of every type group in both scopes. WRK (Workforce & People)
is the highest-prevalence theme in every group; PAT (Patient Care & Quality)
is consistently second. No other theme achieves universal core status across
all type groups in both scopes. These two themes form the strategic floor of
the Ontario hospital sector.

Two structural changes are notable between scopes. First, INN (Innovation &
Digital Health) enters the Community — Large core profile in the Current era,
crossing the 50% threshold for the first time. This is consistent with the 03b
finding of broad INN growth across the sector. Second, the Teaching core profile
expands from 4 to 5 themes as PAR crosses 50% in the Current era. However, PAT,
EDI, and PAR all sit at exactly 50% in the Current era Teaching group — marginal
consensus, not strong consensus. These should be read as emerging inclusions
rather than established norms.

Specialty hospitals show a profile shift: ACC (present in 54% of the full cohort)
falls below 50% in the Current era and exits the core, replaced by FIN. This
reflects genuine compositional change within the Specialty group across eras.

### Modal match summary

| Scope | Type group | n | Core size | Full match % | Miss ≤1 % | Miss ≤2 % | Mean missing |
|-------|------------|---|-----------|-------------|-----------|-----------|--------------|
| Full cohort | Community — Large | 44 | 3 | 56.8 | 95.5 | 100.0 | 0.48 |
| Full cohort | Teaching | 15 | 4 | 40.0 | 60.0 | 100.0 | 1.00 |
| Full cohort | Community — Small | 50 | 4 | 34.0 | 70.0 | 92.0 | 1.04 |
| Full cohort | Specialty | 13 | 4 | 15.4 | 76.9 | 100.0 | 1.08 |
| Current era | Community — Large | 21 | 4 | 42.9 | 76.2 | 100.0 | 0.81 |
| Current era | Community — Small | 27 | 4 | 40.7 | 59.3 | 85.2 | 1.15 |
| Current era | Specialty | 10 | 4 | 30.0 | 80.0 | 90.0 | 1.00 |
| Current era | Teaching | 10 | 5 | 20.0 | 30.0 | 80.0 | 1.70 |

### Interpretation

**Community — Large** is the most conformist group in the full cohort — 57%
full match against a compact 3-theme core, and 96% of hospitals missing at
most one core theme. In the Current era, INN entering the core expands the
core set to 4 themes, dropping full match to 43% and raising mean missing
from 0.48 to 0.81. This is a mechanical consequence of a newly entered core
theme rather than a sign of strategic divergence: hospitals that were
previously full matches are now flagged as missing INN.

**Community — Small** is stable across scopes. The 4-theme core (WRK, PAT,
PAR, FIN) is unchanged, full match is 34–41%, and mean missing holds at
1.04–1.15. This group is in a stable equilibrium around its core — neither
converging toward full adoption nor diverging away from it.

**Specialty** shows improved conformism in the Current era (full match 15% →
30%) driven by ACC exiting the core profile. With a more achievable 4-theme
core (WRK, PAT, RES, FIN), the group looks more conformist — but this reflects
profile redefinition rather than hospitals actually changing their strategies.

**Teaching** is the most structurally divergent group in the Current era. Its
core set is the largest of any group (5 themes), yet only 20% of Teaching
hospitals fully match it. Mean missing is 1.70 per hospital — the highest of
any group in either scope — and only 30% of Teaching hospitals miss just one
or fewer core themes. The Teaching group contains hospitals with genuinely
distinct strategic orientations that do not conform to a common template
(detailed in Analysis 04b).

One interpretive caution applies across groups: some hospitals classified as
missing PAT have patient care content distributed throughout their plans rather
than named as a standalone strategic direction. This is a plan architecture
choice — hospitals with compact 3–4 direction structures often embed patient
care content within directions named for performance, partnerships, or access
— rather than evidence of genuine deprioritization. Where this is the plausible
explanation for a missing core theme, it is noted in Analysis 04b.

---

## Lens 3: Pairwise Jaccard Similarity

### Summary statistics

| Scope | Pair type | n pairs | Mean | Median | SD | >0.50 % | >0.67 % |
|-------|-----------|---------|------|--------|----|---------|---------|
| Full cohort | Community — Large | 946 | 0.459 | 0.429 | 0.183 | 46.5 | 11.2 |
| Full cohort | Community — Small | 1,225 | 0.456 | 0.429 | 0.214 | 46.6 | 11.9 |
| Full cohort | Teaching | 105 | 0.440 | 0.400 | 0.187 | 40.0 | 14.3 |
| Full cohort | Specialty | 78 | 0.411 | 0.429 | 0.185 | 34.6 | 3.8 |
| Full cohort | Between types | 5,027 | 0.391 | 0.400 | 0.192 | 34.2 | 6.5 |
| Current era | Community — Large | 210 | 0.488 | 0.500 | 0.167 | 51.0 | 11.4 |
| Current era | Community — Small | 351 | 0.429 | 0.400 | 0.221 | 41.6 | 11.7 |
| Current era | Specialty | 45 | 0.428 | 0.429 | 0.204 | 35.6 | 4.4 |
| Current era | Teaching | 45 | 0.393 | 0.375 | 0.166 | 33.3 | 6.7 |
| Current era | Between types | 1,627 | 0.389 | 0.400 | 0.190 | 33.6 | 5.6 |

### Full cohort vs. Current era delta

| Pair type | Full cohort | Current era | Delta | Direction |
|-----------|-------------|-------------|-------|-----------|
| Community — Large | 0.459 | 0.488 | +0.029 | Converging |
| Community — Small | 0.456 | 0.429 | −0.027 | Diverging |
| Specialty | 0.411 | 0.428 | +0.017 | Converging |
| Teaching | 0.440 | 0.393 | −0.047 | Diverging |
| Between types | 0.391 | 0.389 | −0.002 | No meaningful change |

### Interpretation

The sector-level Jaccard picture is one of moderate similarity. Mean pairwise
similarity across within-type pairs ranges from 0.39 to 0.49, with roughly a
third to half of pairs exceeding 0.50. Pairs exceeding Jaccard 0.67 — a
threshold at which two hospitals share two-thirds or more of their combined
theme coverage — are rare in every group (4–14%), confirming that near-identical
theme portfolios are uncommon even within type groups.

**Community — Large** is the most internally similar group in both scopes and
is converging (+0.029 delta). The Current era median reaches exactly 0.50.
This is consistent with Lens 2: a compact, near-universally shared core, now
augmented by INN as an emerging consensus theme, is producing mild within-group
convergence.

**Teaching** is diverging sharply (−0.047 delta), dropping from the highest
within-type mean in the full cohort (0.440) to the lowest in the Current era
(0.393). In the full cohort, Teaching hospitals are actually the most similar
to one another of any type group. In the Current era that position inverts —
Teaching falls to last place, and its mean (0.393) is within 0.004 of the
between-type mean (0.389). Teaching hospitals in the Current era are nearly
as different from each other as hospitals of entirely different types are from
one another. This near-parity with the between-type mean is the sharpest
expression of within-group divergence in the dataset, and it is driven by
hospitals whose specialized mandates produce theme portfolios that diverge
substantially from Teaching group norms (see Analysis 04b).

**Community — Small** is diverging (−0.027 delta) with the highest SD of any
within-type group in the Current era (0.221). Some Community — Small pairs are
very similar — hospitals sharing all 4 core themes, including several pairs
that share a plan document and score Jaccard = 1.0 by construction. Others
share only 1–2 themes. This bimodal character is not captured by the mean alone.

**Between-type similarity** (0.389–0.391) is lower than within-type similarity
for Community — Large, Community — Small, and Teaching in the full cohort,
confirming that type group membership is associated with modestly higher
within-group similarity. The effect is 0.05–0.07 points in the full cohort —
real but not large. In the Current era, Teaching within-type collapses to
within 0.004 of between-type, the sharpest deviation from this pattern in
the dataset.

---

## Cross-Lens Synthesis

The three lenses converge on a consistent picture of moderate, differentiated
homogeneity:

**The sector occupies a moderate homogeneity band.** Hospitals are not
interchangeable, but they are not strategically distinct either. Most hospitals
cover 4–5 themes from a 10-code taxonomy, with the majority of within-type
pairs sharing 40–50% of their theme content. This is consistent with a sector
subject to shared institutional pressures — regulatory environment, funding
structure, accreditation, provincial policy signals — that produce convergent
thematic coverage without producing identical plans.

**WRK and PAT form the sector floor.** Workforce and patient care are the only
two themes present in the core profile of every type group in both scopes. Every
other theme is type-specific, era-specific, or both. This universal foundation
places a floor on pairwise similarity — nearly all hospitals share at least
these two themes, which mechanically elevates sector-wide Jaccard means above
what they would be in a more fragmented sector.

**Within-type similarity is real but modest.** Community — Large is the most
internally cohesive group in both scopes. Community — Small and Specialty occupy
a stable middle range. Teaching is the exception and is moving in the wrong
direction — diverging in the Current era to the point where within-group
similarity is indistinguishable from cross-type similarity.

**The Current era shows two diverging trajectories.** Community — Large is
converging toward a stable 4-theme template, now including INN. Teaching is
diverging: the largest core of any group (5 themes), the lowest full match
(20%), and Jaccard parity with between-type comparisons. These are not
contradictory — they reflect genuinely different dynamics. Community — Large
hospitals are conforming to an emerging sector consensus; Teaching hospitals
are differentiating, at least in the Current era cohort.

---

## Interpretive Limits

**Binary representation discards direction count and weight.** The theme vector
treats a hospital with 10 WRK directions identically to one with a single WRK
direction. This is appropriate for the homogeneity question as posed (is the
theme present?) but does not capture depth of strategic investment.

**Core profile definition is threshold-dependent.** Themes at the 50% boundary
represent marginal consensus. The Teaching group's Current era PAT, EDI, and
PAR themes — all at exactly 50% — are borderline inclusions. Small changes in
cohort composition would move these in or out of the core.

**Shared strategic plans inflate within-group similarity.** Several Community —
Small hospital pairs share a single plan document and will produce Jaccard = 1.0
by construction, inflating the within-group mean for that type. Their
contribution is not separately removed from the reported statistics.

**Thin extractions may understate breadth.** Theme count is bounded by direction
count. Hospitals with partial extractions may appear less thematically broad than
their full plans would show. This affects the lower tail of the breadth
distribution more than the central tendency.

---

## Outputs

| File | Description |
|------|-------------|
| `analysis/outputs/tables/04a_breadth_summary.csv` | Theme breadth by type group and scope (mean, median, SD, range) |
| `analysis/outputs/tables/04a_core_profile_by_type.csv` | Theme-level prevalence by type group, with core profile flag; both scopes |
| `analysis/outputs/tables/04a_modal_match_summary.csv` | Core profile match summary by type group and scope |
| `analysis/outputs/tables/04a_jaccard_summary.csv` | Pairwise Jaccard summary by pair type and scope |
| `analysis/outputs/tables/04a_jaccard_pairwise.csv` | Full pairwise matrix with FAC codes, type groups, Jaccard, intersection, and union |
| `analysis/outputs/figures/04a_breadth_distribution.png` | Dot strip of theme counts by type group and scope |
| `analysis/outputs/figures/04a_jaccard_heatmap.png` | Jaccard mean heatmap by type-group pair |
| `analysis/outputs/figures/04a_jaccard_density.png` | Density plot of pairwise Jaccard by pair type and scope |
