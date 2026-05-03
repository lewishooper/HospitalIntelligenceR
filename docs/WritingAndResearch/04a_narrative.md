# Strategic Homogeneity in Ontario Hospital Strategic Plans
## Ontario Public Hospitals — Theme Breadth, Core Profile Alignment, and Pairwise Similarity
*HospitalIntelligenceR | Analysis 04a | May 2026*

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
considered but not pursued: the Pre-COVID group contains only 12 hospitals,
which is too small to produce reliable core profiles or pairwise Jaccard
statistics. The two-scope design is intentional.

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

**Cohort:** 119 Ontario public hospitals with usable classified directions form
the full cohort. The Current era cohort contains 65 hospitals with plan start
years 2024–2026. Both scopes include hospitals across all four type groups:
Teaching, Community — Large, Community — Small, and Specialty.

**Type group composition:**

| Type group | Full cohort | Current era |
|------------|-------------|-------------|
| Teaching | 17 | 12 |
| Community — Large | 43 | 20 |
| Community — Small | 48 | 25 |
| Specialty | 11 | 8 |

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
restrictive definition, the finding is robust.

A sensitivity analysis using both primary and secondary themes was conducted and
is reported in the Interpretive Limits section.

**Core profile definition:** For each hospital type group, themes present in
50% or more of hospitals in that group are designated as core. The 50% threshold
is a methodological choice; themes at 45–55% prevalence straddle the boundary
and should be treated as marginal consensus rather than strong consensus. A
hospital "fully matches" the core profile if it has every core theme for its
type group.

**Jaccard similarity:** For every pair of hospitals within a given scope, Jaccard
similarity is computed as:

> Jaccard(A, B) = |A ∩ B| / |A ∪ B|

where A and B are each hospital's set of present primary themes. Jaccard = 1.0
means identical theme portfolios; Jaccard = 0 means no shared themes at all.
Pairs are categorized as within-type (both hospitals in the same type group) or
between-type (hospitals in different type groups).

---

## Lens 1: Theme Breadth

### Summary statistics (primary themes only)

| Scope | Type group | n | Mean themes | Median | SD | Range |
|-------|------------|---|-------------|--------|----|-------|
| Full cohort | Teaching | 17 | 4.65 | 5.0 | 1.27 | 3–7 |
| Full cohort | Community — Large | 43 | 4.42 | 4.0 | 1.48 | 2–8 |
| Full cohort | Community — Small | 48 | 4.04 | 4.0 | 1.03 | 2–7 |
| Full cohort | Specialty | 11 | 4.27 | 5.0 | 0.90 | 3–5 |
| Full cohort | All types | 119 | 4.29 | 4.0 | 1.24 | — |
| Current era | Teaching | 12 | 4.50 | 5.0 | 1.31 | 3–7 |
| Current era | Community — Large | 20 | 5.00 | 5.0 | 1.62 | 3–8 |
| Current era | Community — Small | 25 | 4.04 | 4.0 | 1.31 | 2–7 |
| Current era | Specialty | 8 | 4.62 | 5.0 | 0.74 | 3–5 |
| Current era | All types | 65 | 4.49 | 5.0 | 1.39 | — |

### Interpretation

Ontario hospitals are concentrated in a 4–5 distinct primary theme band across
both scopes. The full cohort overall mean is 4.3; the Current era mean is 4.5.
The median shifts from 4 to 5 between scopes, suggesting a modest broadening
in recent plans rather than a structural change in distribution.

Specialty hospitals are the most internally consistent group in both scopes.
Their standard deviation narrows from 0.90 (full cohort) to 0.74 (Current era),
with a range bounded at 3–5 in both. Mission specificity in Specialty hospitals
appears to limit strategic dispersion — they cover a consistently narrow thematic
band relative to other groups.

Community — Large hospitals show the widest within-group spread in the Current
era (SD 1.62, range 3–8). This is the only type group where some hospitals reach
8 distinct primary themes. The wider spread is consistent with the 03c finding
that this group is in a period of active strategic expansion, particularly around
RES and INN themes.

Teaching hospitals show comparable dispersion in both scopes (SD 1.27 full, 1.31
current). No Teaching hospital in the cohort covers fewer than 3 distinct primary
themes, but the group contains hospitals with genuinely distinct strategic orientations
— from narrowly mission-focused institutions to those addressing 7 themes. This
heterogeneity is examined further in Analysis 04b.

---

## Lens 2: Core Profile Alignment

### Core profiles by type group (primary themes)

Core themes are those present in ≥50% of hospitals within a type group.

**Full cohort core profiles:**

| Type group | n | Core themes (≥50% prevalence) |
|------------|---|-------------------------------|
| Teaching | 17 | RES, WRK, PAT, EDI |
| Community — Large | 43 | WRK, PAT, PAR |
| Community — Small | 48 | WRK, PAR, PAT, FIN |
| Specialty | 11 | WRK, PAT, RES, ACC |

**Current era core profiles:**

| Type group | n | Core themes (≥50% prevalence) |
|------------|---|-------------------------------|
| Teaching | 12 | RES, WRK, PAT, EDI, PAR |
| Community — Large | 20 | WRK, PAT, PAR, INN, RES |
| Community — Small | 25 | WRK, PAT, PAR, FIN, ACC |
| Specialty | 8 | WRK, PAT, RES, FIN, ACC |

**WRK and PAT are the two sector-wide universal core themes** — present in the
core profile of every type group in both scopes. WRK (Workforce & People) is
the highest-prevalence theme in every group; PAT (Patient Care & Quality) is
consistently second. No other theme achieves universal core status across all
type groups in both scopes. These two themes form the strategic floor of the
Ontario hospital sector.

Two structural changes are notable between scopes. First, INN (Innovation &
Digital Health) and RES (Research & Academic) both enter the Community — Large
core profile in the Current era. INN crossing the 50% threshold reflects broad
diffusion of digital health strategy across the community sector. RES crossing 50%
is the Current-era analog of the 03c finding: Community — Large hospitals are now
including research and academic directions at sufficient prevalence that the theme
has crossed into consensus territory for that group. Second, the Teaching core
profile expands from 4 to 5 themes as PAR crosses 50% in the Current era.

The Community — Small current core adds ACC (Access & Care Delivery) relative to
the full cohort. Specialty's current core shifts from ACC to FIN — reflecting
genuine compositional change within the Specialty group, where a smaller (n=8) and
more specialized Current-era sample aligns differently on access versus financial
sustainability directions.

### Modal match summary

| Scope | Type group | n | Core size | Full match % | Miss ≤1 % | Miss ≤2 % | Mean missing |
|-------|------------|---|-----------|-------------|-----------|-----------|--------------|
| Full cohort | Teaching | 17 | 4 | 41.2 | 64.7 | 100.0 | 0.94 |
| Full cohort | Community — Large | 43 | 3 | 58.1 | 95.3 | 100.0 | 0.47 |
| Full cohort | Community — Small | 48 | 4 | 31.2 | 68.8 | 91.7 | 1.08 |
| Full cohort | Specialty | 11 | 4 | 18.2 | 72.7 | 100.0 | 1.09 |
| Current era | Teaching | 12 | 5 | 25.0 | 33.3 | 83.3 | 1.58 |
| Current era | Community — Large | 20 | 5 | 25.0 | 65.0 | 85.0 | 1.25 |
| Current era | Community — Small | 25 | 5 | 16.0 | 40.0 | 80.0 | 1.72 |
| Current era | Specialty | 8 | 5 | 25.0 | 37.5 | 75.0 | 1.62 |

### Interpretation

**Community — Large** is the most conformist group in the full cohort — 58%
full match against a compact 3-theme core, with 95% of hospitals missing at
most one core theme. In the Current era, INN and RES entering the core expands
the core set to 5 themes, dropping full match to 25% and raising mean missing
from 0.47 to 1.25. This is partly a mechanical consequence of newly entered core
themes: hospitals that were previously full matches are now flagged as missing INN
or RES. The underlying conformism of the group on its established themes (WRK, PAT,
PAR) has not changed; the definition of conformism has expanded.

**Community — Small** is broadly stable across scopes. The 4-theme full cohort
core (WRK, PAR, PAT, FIN) grows to 5 in the Current era with the addition of ACC.
Full match sits at 31% (full) and 16% (current) — low in both cases, indicating
that Community — Small hospitals commonly cover the modal themes but diverge on
one or two. Mean missing holds at approximately 1.1 across both scopes.

**Specialty** shows improved apparent conformism moving from full to current scope
at the full-match level (18% → 25%), but with a larger core set (4 → 5 themes)
and higher mean missing (1.09 → 1.62). The core redefinition — dropping ACC, adding
FIN and expanding to 5 themes — reflects genuine compositional change within the
Specialty group. The smaller Current-era sample (n=8) produces more volatile estimates.

**Teaching** is the most structurally divergent group in the Current era. Its
core set is the largest of any group (5 themes), yet only 25% of Teaching hospitals
fully match it. Mean missing is 1.58 per hospital and only 33% of Teaching hospitals
miss one or fewer core themes. The Teaching group contains hospitals with genuinely
distinct strategic orientations that do not conform to a common template, detailed
in Analysis 04b.

One interpretive caution applies across groups: some hospitals classified as
missing PAT have patient care content distributed throughout their plans rather
than named as a standalone strategic direction. This is a plan architecture
choice — hospitals with compact 3–4 direction structures often embed patient
care content within directions named for performance, partnerships, or access
— rather than evidence of genuine deprioritization.

---

## Lens 3: Pairwise Jaccard Similarity

### Summary statistics (primary themes)

| Scope | Pair type | n pairs | Mean | Median | SD | >0.50 % | >0.67 % |
|-------|-----------|---------|------|--------|----|---------|---------|
| Full cohort | Community — Large | 903 | 0.462 | 0.429 | 0.183 | 47.2 | 11.3 |
| Full cohort | Teaching | 136 | 0.458 | 0.429 | 0.192 | 44.1 | 15.4 |
| Full cohort | Community — Small | 1,128 | 0.451 | 0.400 | 0.216 | 45.7 | 12.5 |
| Full cohort | Specialty | 55 | 0.396 | 0.400 | 0.195 | 36.4 | 3.6 |
| Full cohort | Between types | 4,799 | 0.390 | 0.400 | 0.192 | 34.0 | 6.5 |
| Current era | Community — Large | 190 | 0.498 | 0.500 | 0.162 | 53.7 | 12.1 |
| Current era | Teaching | 66 | 0.424 | 0.400 | 0.182 | 37.9 | 9.1 |
| Current era | Community — Small | 300 | 0.420 | 0.400 | 0.225 | 39.7 | 12.7 |
| Current era | Specialty | 28 | 0.398 | 0.429 | 0.221 | 35.7 | 3.6 |
| Current era | Between types | 1,496 | 0.387 | 0.400 | 0.190 | 33.4 | 5.5 |

### Full cohort vs. Current era delta

| Pair type | Full cohort | Current era | Delta | Direction |
|-----------|-------------|-------------|-------|-----------|
| Community — Large | 0.462 | 0.498 | +0.036 | Converging |
| Teaching | 0.458 | 0.424 | −0.034 | Diverging |
| Community — Small | 0.451 | 0.420 | −0.031 | Diverging |
| Specialty | 0.396 | 0.398 | +0.002 | No meaningful change |
| Between types | 0.390 | 0.387 | −0.003 | No meaningful change |

### Interpretation

The sector-level Jaccard picture is one of moderate similarity. Mean pairwise
similarity across within-type pairs ranges from 0.40 to 0.50, with roughly a
third to half of pairs exceeding 0.50. Pairs exceeding Jaccard 0.67 — a
threshold at which two hospitals share two-thirds or more of their combined
primary theme coverage — are rare in every group (4–15%).

**Community — Large** is the most internally similar group in both scopes and
is converging (+0.036 delta). The Current era median reaches exactly 0.50, with
54% of pairs exceeding that threshold. This is consistent with Lens 2: a compact
historically shared core now augmented by INN and RES as emerging consensus themes
is producing mild within-group convergence.

**Teaching** presents the sharpest divergence in the dataset (−0.034 delta),
moving from the second-highest within-type mean in the full cohort (0.458) to
the lowest in the Current era (0.424). Teaching hospitals in the Current era have
within-group Jaccard only 0.037 above the between-type mean (0.387) — a gap
smaller than in any other within-type group. Within-group similarity is the
expected consequence of shared type norms; when within-type Jaccard approaches
between-type Jaccard, type-group membership provides minimal predictive information
about strategic similarity. The Teaching divergence reflects hospitals whose
specialized mandates — cardiac, geriatric, paediatric, francophone, mental health
adjacent — produce theme portfolios that differ substantially from the Teaching
group central tendency. These hospitals are examined case by case in Analysis 04b.

**Community — Small** is diverging (−0.031 delta), with the highest SD of any
within-type group in the Current era (0.225). The distribution is not unimodal:
some pairs — including shared-plan hospitals — score at or near 1.0, while others
share only 1–2 themes. The mean (0.420) sits between these clusters and should
not be taken as a representative value for any individual pair.

**Specialty** shows minimal change across scopes (+0.002 delta). With only 8
hospitals in the Current era, the Specialty pair count (n=28) is the smallest
within-type group, and the summary statistics carry wider uncertainty than those
for Community groups.

**Between-type similarity** (0.387–0.390) is lower than within-type similarity
for all groups in the full cohort, confirming that type group membership is
associated with modestly higher within-group similarity. The effect is 0.06–0.07
points — real but not large. The narrowing of the Teaching within/between gap in
the Current era is the sharpest expression of within-group divergence in the
dataset.

---

## Cross-Lens Synthesis

The three lenses together show that Ontario hospital strategic plans are
similar enough to reflect shared sector pressures, but different enough
that no single template describes the sector. The sector is not homogeneous;
it is not fragmented either. Hospitals cluster around a common thematic
core — WRK and PAT universally, with type-group-specific additions — while
retaining variation in which additional themes they address.

**WRK and PAT form the sector floor.** Workforce and patient care are the only
two themes present in the core profile of every type group in both scopes.
Every other theme is type-specific, era-specific, or both. This universal
foundation places a floor on pairwise similarity: nearly all hospitals share
at least these two primary themes, which mechanically elevates sector-wide
Jaccard means above what they would be in a genuinely fragmented sector.

**Within-type similarity is real but modest.** Community — Large is the most
internally cohesive group in both scopes. Community — Small and Specialty
occupy a stable middle range. Teaching is the exception: among the most cohesive
groups in the full cohort, the most divergent in the Current era.

**The Current era shows two diverging trajectories.** Community — Large is
converging toward a stable 5-theme template anchored by WRK, PAT, PAR, INN, and
RES. Teaching is diverging: the largest core of any group (5 themes), the joint-lowest
full match (25%), and within-type Jaccard approaching parity with between-type
comparisons. These reflect genuinely different dynamics — conformism in one segment,
differentiation in another — playing out simultaneously.

---

## Interpretive Limits

**Primary theme only — sensitivity analysis.** The main analysis uses primary
theme classifications only. A sensitivity analysis including secondary themes
was conducted. Including secondary themes raises mean within-type Jaccard from
0.40–0.46 (primary-only, full cohort) to approximately 0.56–0.60
(primary+secondary, full cohort). The relative ordering of type groups by
similarity is broadly preserved, but the Teaching divergence finding is
materially weaker with secondary themes included — the gap to Community — Large
narrows substantially. Readers should treat the Teaching divergence finding as
directionally robust but magnitude-sensitive to the theme inclusion choice.

**Core profile definition is threshold-dependent.** Themes at the 50% boundary
represent marginal consensus. The Teaching group's Current era PAR — at or near
50% — is a borderline inclusion. Small changes in cohort composition would move
this in or out of the core.

**Shared strategic plans inflate within-group similarity.** Two Community —
Small hospital pairs share a plan document (FAC 597/626 Almonte–Carleton Place,
FAC 593/824 Four Counties–Tillsonburg) and produce Jaccard = 1.0 by construction.
Their contribution to the within-group mean is not separately removed from the
reported statistics, though they are insufficient in number to drive the group-level
summary statistics.

**PAT missing-core flags may reflect plan architecture.** Some hospitals
classified as missing PAT distribute patient care content across multiple
directions rather than naming it as a standalone priority. This is a structural
choice most common among hospitals with compact 3–4 direction plans and is
examined case by case in Analysis 04b.

---

## Outputs

| File | Description |
|------|-------------|
| `analysis/outputs/tables/04a_breadth_summary.csv` | Primary theme breadth by type group and scope |
| `analysis/outputs/tables/04a_core_profile_by_type.csv` | Primary theme prevalence by type group, with core profile flag; both scopes |
| `analysis/outputs/tables/04a_modal_match_summary.csv` | Core profile match summary by type group and scope |
| `analysis/outputs/tables/04a_jaccard_summary.csv` | Pairwise Jaccard summary by pair type and scope |
| `analysis/outputs/tables/04a_jaccard_pairwise.csv` | Full pairwise matrix with FAC codes, type groups, Jaccard, intersection, and union |
| `analysis/outputs/figures/04a_breadth_distribution.png` | Dot strip of primary theme counts by type group and scope |
| `analysis/outputs/figures/04a_jaccard_heatmap.png` | Jaccard mean heatmap by type-group pair |
| `analysis/outputs/figures/04a_jaccard_density.png` | Density plot of pairwise Jaccard by pair type and scope |
