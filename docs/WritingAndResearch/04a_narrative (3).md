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

**Lens 1 — Theme breadth:** How many distinct themes does a hospital cover,
and how much does this vary within and across type groups?

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
based on whether at least one direction from that hospital was classified to
that theme.

**Primary theme only — rationale:** Each strategic direction receives a primary
theme classification (the classifier's definitive judgment of what the direction
is fundamentally about) and an optional secondary theme (a weaker signal that
the direction also touches a second area). This analysis uses primary themes
only for three reasons. First, primary theme is the higher-confidence signal —
two analysts would more often agree on the primary than the secondary
classification. Second, including secondary themes mechanically inflates apparent
thematic breadth and pairwise similarity by construction: every direction with
a secondary theme now contributes two registrations, regardless of how
substantively that second theme is addressed. Third, primary-only produces a
conservative estimate of homogeneity — if hospitals look similar under this more
restrictive definition, the finding is robust; if they look different, the
secondary-inclusive analysis would only reinforce that conclusion.

A sensitivity analysis using both primary and secondary themes was conducted and
is reported in the Interpretive Limits section.

**Theme count and direction count:** Under primary-theme-only, a hospital's
theme count is bounded above by its direction count — a hospital with four
directions can register at most four distinct primary themes. In practice, for
hospitals with diverse strategic directions, primary theme count closely
approximates direction count. This means the breadth figures reported below
are best interpreted as the number of distinct strategic themes a hospital
addresses as primary priorities, not as an independent measure of thematic
scope. The sensitivity analysis (primary+secondary) provides a broader estimate
of thematic coverage.

**Core profile definition:** For each hospital type group, themes present in
50% or more of hospitals in that group are designated as core. The 50% threshold
is a methodological choice; themes at 45–55% prevalence straddle the boundary
and should be treated as marginal consensus rather than strong consensus. A
hospital "fully matches" the core profile if it has every core theme for its
type group. Core profiles are computed on primary themes only, consistent with
the main analysis.

**Jaccard similarity:** For every pair of hospitals within a given scope, Jaccard
similarity is computed as:

> Jaccard(A, B) = |A ∩ B| / |A ∪ B|

where A and B are each hospital's set of present primary themes. The intersection
is the number of themes both hospitals share; the union is the total number of
distinct themes present in either hospital. Jaccard = 1.0 means identical theme
portfolios; Jaccard = 0 means no shared themes at all.

As a concrete example: if Hospital A covers WRK, PAT, PAR, and FIN (4 themes)
and Hospital B covers WRK, PAT, INN, and RES (4 themes), the intersection is
{WRK, PAT} = 2, the union is {WRK, PAT, PAR, FIN, INN, RES} = 6, and Jaccard
= 2/6 = 0.33. Jaccard normalizes for set size — a hospital covering 3 themes
and one covering 8 themes are compared on a common scale without penalizing
either for portfolio size.

Pairs are categorized as within-type (both hospitals in the same type group) or
between-type (hospitals in different type groups). Summary statistics are
reported by pair type and scope.

**Scope comparison:** Full cohort and Current era results are reported in
parallel. Delta statistics (Current era − Full cohort) flag where the Current
era differs meaningfully from the historical baseline.

---

## Lens 1: Theme Breadth

### Summary statistics (primary themes only)

| Scope | Type group | n | Mean distinct themes | Median | SD | Range |
|-------|------------|---|----------------------|--------|----|-------|
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

The column header reads "mean distinct primary themes" rather than "mean themes"
to be precise: this figure counts the number of different primary theme codes
present across a hospital's directions, not the total number of directions. For
the sensitivity estimate including secondary themes, mean coverage rises to
6.0–7.1 across type groups — see Interpretive Limits.

### Interpretation

Ontario hospitals are concentrated in a 4–5 distinct primary theme band across
both scopes. The full cohort overall mean is 4.3; the Current era mean is 4.5.
The median shifts from 4 to 5 between scopes, suggesting a modest broadening
in recent plans rather than a structural change in distribution.

Specialty hospitals are the most internally consistent group in both scopes.
Their standard deviation narrows from 0.87 (full cohort) to 0.67 (Current era),
with a range bounded at 3–5 in both. Mission specificity in Specialty hospitals
appears to limit strategic dispersion — they cover a consistently narrow thematic
band relative to other groups.

Community — Large hospitals show the widest within-group spread in the Current
era (SD 1.64, range 3–8). This is the only type group where some hospitals reach
8 distinct primary themes, approaching the upper limit of the 10-code taxonomy.
The wider spread is consistent with the 03c finding that this group is in a
period of active strategic expansion, particularly around RES and INN themes.

Teaching hospitals show comparable dispersion in both scopes (SD 1.35 full,
1.43 current). No Teaching hospital in the cohort covers fewer than 3 distinct
primary themes in either scope, but the group contains the widest range of
strategic orientations — from narrowly mission-focused hospitals to those
addressing 7 themes. This heterogeneity is examined further in Analysis 04b.

The practical implication of breadth alone is limited: a hospital with 4 primary
themes and one with 6 may be covering the same core territory if the identities
of those themes differ. Lenses 2 and 3 address this directly.

---

## Lens 2: Core Profile Alignment

### Core profiles by type group (primary themes)

Core themes are those present in ≥50% of hospitals within a type group. Core
profiles differ between scopes because the hospital sample within each type
group changes across eras and because theme adoption rates have shifted over
time.

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

All prevalence figures are based on primary theme classifications only.

**WRK and PAT are the two sector-wide universal core themes** — present in the
core profile of every type group in both scopes. WRK (Workforce & People) is
the highest-prevalence theme in every group; PAT (Patient Care & Quality) is
consistently second. No other theme achieves universal core status across all
type groups in both scopes. These two themes form the strategic floor of the
Ontario hospital sector.

Two structural changes are notable between scopes. First, INN (Innovation &
Digital Health) enters the Community — Large core profile in the Current era,
crossing the 50% threshold for the first time. This does not necessarily mean
community hospitals have just discovered digital health — Teaching hospitals
likely addressed INN in earlier plan cycles as typical early adopters of
technology themes. What the data shows is that INN has now diffused broadly
enough within Community — Large hospitals specifically to cross the consensus
threshold in the Current era. Second, the Teaching core profile expands from
4 to 5 themes as PAR crosses 50% in the Current era. However, PAT, EDI, and
PAR all sit at exactly 50% in the Current era Teaching group — marginal
consensus, not strong consensus. A single hospital moving either way would
shift these in or out of the core.

Specialty hospitals show a profile shift: ACC (present in 54% of the full
cohort) falls below 50% in the Current era and exits the core, replaced by FIN.
This reflects genuine compositional change within the Specialty group across
eras rather than a taxonomy artifact.

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
full match against a compact 3-theme core, with 96% of hospitals missing at
most one core theme. In the Current era, INN entering the core expands the
core set to 4 themes, dropping full match to 43% and raising mean missing from
0.48 to 0.81. This is a mechanical consequence of a newly entered core theme:
hospitals that were previously full matches are now flagged as missing INN.
The underlying conformism of the group has not changed; the definition of
conformism has.

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
any group in either scope — and only 30% of Teaching hospitals miss one or
fewer core themes. The Teaching group contains hospitals with genuinely distinct
strategic orientations that do not conform to a common template, detailed in
Analysis 04b.

One interpretive caution applies across groups: some hospitals classified as
missing PAT have patient care content distributed throughout their plans rather
than named as a standalone strategic direction. This is a plan architecture
choice — hospitals with compact 3–4 direction structures often embed patient
care content within directions named for performance, partnerships, or access
— rather than evidence of genuine deprioritization. Where this is the plausible
explanation for a missing core theme, it is noted in Analysis 04b.

---

## Lens 3: Pairwise Jaccard Similarity

### Summary statistics (primary themes)

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
primary theme coverage — are rare in every group (4–14%).

The 4–14% high-similarity tail is not primarily a shared-plan artifact. Only
three hospital pairs in the dataset share a single plan document (FAC 813/983
Stratford–Huron Perth, FAC 597/626 Almonte–Carleton Place, FAC 593/824 Four
Counties–Tillsonburg), representing 6 hospitals out of 122. These pairs produce
Jaccard = 1.0 by construction and contribute to the upper tail, but they are
too few to drive a 4–14% above-0.67 rate across groups containing hundreds or
thousands of pairs. The high-similarity pairs reflect genuine thematic overlap
among independently planning hospitals, not plan-sharing artifacts.

**Community — Large** is the most internally similar group in both scopes and
is converging (+0.029 delta). The Current era median reaches exactly 0.50. This
is consistent with Lens 2: a compact, near-universally shared core, now
augmented by INN as an emerging consensus theme, is producing mild within-group
convergence.

**Teaching** is diverging sharply (−0.047 delta), dropping from the highest
within-type mean in the full cohort (0.440) to the lowest in the Current era
(0.393). In the full cohort, Teaching hospitals are the most similar to one
another of any type group. In the Current era that position inverts — Teaching
falls to last, and its mean (0.393) is within 0.004 of the between-type mean
(0.389). Teaching hospitals in the Current era are nearly as different from each
other as hospitals of entirely different types are from one another. This
near-parity with the between-type mean is the sharpest expression of
within-group divergence in the dataset. It is driven by hospitals whose
specialized mandates produce theme portfolios that diverge substantially from
Teaching group norms, detailed in Analysis 04b. Note that this finding is
sensitive to the primary-theme-only choice: the secondary-inclusive sensitivity
analysis shows Teaching current era Jaccard rising to 0.594, narrowing the gap
with Community — Large (0.634) substantially — see Interpretive Limits.

**Community — Small** is diverging (−0.027 delta) with the highest SD of any
within-type group in the Current era (0.221). The distribution is not unimodal:
some pairs — including shared-plan hospitals — score at or near 1.0, while
others share only 1–2 themes. The mean (0.429) sits between these clusters and
should not be taken as a representative value for any individual pair.

**Between-type similarity** (0.389–0.391) is lower than within-type similarity
for Community — Large, Community — Small, and Teaching in the full cohort,
confirming that type group membership is associated with modestly higher
within-group similarity. The effect is 0.05–0.07 points in the full cohort —
real but not large. In the Current era, Teaching within-type similarity
collapses to within 0.004 of between-type, the sharpest deviation from the
expected pattern in the dataset.

---

## Cross-Lens Synthesis

The three lenses together show that Ontario hospital strategic plans are
similar enough to reflect shared sector pressures, but different enough
that no single template describes the sector. The sector is not homogeneous;
it is not fragmented either. Hospitals cluster around a common thematic
core — WRK and PAT universally, with type-group-specific additions — while
retaining variation in which additional themes they address and how
specifically they frame them.

**WRK and PAT form the sector floor.** Workforce and patient care are the only
two themes present in the core profile of every type group in both scopes.
Every other theme is type-specific, era-specific, or both. This universal
foundation places a floor on pairwise similarity — nearly all hospitals share
at least these two primary themes, which mechanically elevates sector-wide
Jaccard means above what they would be in a genuinely fragmented sector.

**Within-type similarity is real but modest.** Community — Large is the most
internally cohesive group in both scopes. Community — Small and Specialty
occupy a stable middle range. Teaching is the exception: most cohesive in the
full cohort, least cohesive in the Current era, with within-group Jaccard
approaching parity with between-type comparisons.

**The Current era shows two diverging trajectories.** Community — Large is
converging toward a stable 4-theme template. Teaching is diverging: the largest
core of any group (5 themes), the lowest full match (20%), and Jaccard near
parity with between-type comparisons. These reflect genuinely different dynamics
— conformism in one group, differentiation in another — playing out
simultaneously in the Current era.

**Theme count closely tracks direction count under primary-only.** The 4–5
theme band reported in Lens 1 approximates the typical number of strategic
directions hospitals write, not an independent measure of thematic scope.
The secondary-inclusive breadth figures (6.0–7.1 themes) are a broader but
methodologically noisier estimate of coverage. Both are valid characterizations
of different things: primary-only measures primary strategic priorities;
primary+secondary measures total thematic territory touched.

---

## Interpretive Limits

**Primary theme only — sensitivity analysis.** The main analysis uses primary
theme classifications only. A sensitivity analysis including secondary themes
was conducted to assess robustness. Results:

*Breadth (full cohort):* Mean distinct themes rises from 4.1–4.6 (primary-only)
to 6.0–6.8 (primary+secondary) across type groups — an increase of approximately
2 themes per hospital on average. This confirms that secondary themes contribute
material additional thematic coverage beyond primary themes alone.

*Jaccard similarity:* Including secondary themes raises mean within-type Jaccard
from 0.41–0.46 (primary-only, full cohort) to 0.56–0.60 (primary+secondary,
full cohort), and from 0.39–0.49 (primary-only, Current era) to 0.56–0.63
(primary+secondary, Current era). The +0.12–0.20 increase is systematic across
all groups and scopes, reflecting the mechanical effect of adding shared
secondary themes.

*Group rankings:* The relative ordering of type groups by similarity is broadly
preserved under both approaches, with one important exception. The Teaching
divergence finding — the main directional conclusion of Lens 3 — is materially
weaker with secondary themes included. Primary-only Teaching current era Jaccard
(0.393) is the clear outlier, near parity with between-type similarity (0.389).
Secondary-inclusive Teaching current era Jaccard (0.594) is within 0.040 of
Community — Large (0.634) — a modest rather than dramatic gap. Readers should
treat the Teaching divergence finding as directionally robust but magnitude-
sensitive to the theme inclusion choice.

**Core profile definition is threshold-dependent.** Themes at the 50% boundary
represent marginal consensus. The Teaching group's Current era PAT, EDI, and
PAR — all at exactly 50% — are borderline inclusions. Small changes in cohort
composition would move these in or out of the core.

**Shared strategic plans inflate within-group similarity.** Three Community —
Small hospital pairs share a plan document and produce Jaccard = 1.0 by
construction. Their contribution to the within-group mean is not separately
removed from the reported statistics, though as noted in Lens 3, they are
insufficient in number to drive the group-level summary statistics.

**PAT missing-core flags may reflect plan architecture.** Some hospitals
classified as missing PAT distribute patient care content across multiple
directions rather than naming it as a standalone priority. This is a structural
choice, not evidence of deprioritization. It is most common among hospitals
with compact 3–4 direction plans and is examined case-by-case in Analysis 04b.

---

## Outputs

| File | Description |
|------|-------------|
| `analysis/outputs/tables/04a_breadth_summary.csv` | Primary theme breadth by type group and scope (mean, median, SD, range) |
| `analysis/outputs/tables/04a_core_profile_by_type.csv` | Primary theme prevalence by type group, with core profile flag; both scopes |
| `analysis/outputs/tables/04a_modal_match_summary.csv` | Core profile match summary by type group and scope |
| `analysis/outputs/tables/04a_jaccard_summary.csv` | Pairwise Jaccard summary by pair type and scope (primary themes) |
| `analysis/outputs/tables/04a_jaccard_pairwise.csv` | Full pairwise matrix with FAC codes, type groups, Jaccard, intersection, and union |
| `analysis/outputs/figures/04a_breadth_distribution.png` | Dot strip of primary theme counts by type group and scope |
| `analysis/outputs/figures/04a_jaccard_heatmap.png` | Jaccard mean heatmap by type-group pair |
| `analysis/outputs/figures/04a_jaccard_density.png` | Density plot of pairwise Jaccard by pair type and scope |
