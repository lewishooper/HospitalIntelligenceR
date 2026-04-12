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
window.

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

**Cohort:** 115 Ontario public hospitals with usable classified directions form
the full cohort. The Current era cohort contains 62 hospitals with plan start
years 2024–2026. Both scopes include hospitals across all four type groups:
Teaching, Community — Large, Community — Small, and Specialty.

**Unit of analysis:** Hospital. Each hospital is represented as a binary theme
vector — a set of 10 possible themes, with each theme marked present or absent
based on whether at least one direction from that hospital was classified to that
theme.

**Core profile definition:** For each hospital type group, themes present in
50% or more of hospitals in that group are designated as core. A hospital "fully
matches" the core profile if it has every core theme for its type group. Missing
core themes are counted per hospital; the mean across the group is reported.

**Jaccard similarity:** For every pair of hospitals in a given scope, Jaccard
similarity is computed as the intersection of their theme sets divided by the
union. Jaccard = 1.0 means identical theme portfolios; Jaccard = 0 means no
shared themes. Pairs are categorized as within-type (both hospitals in the same
type group) or between-type (hospitals in different type groups). Summary
statistics are reported by pair type.

**Scope comparison:** Full cohort and Current era results are reported in
parallel for all three lenses. Delta statistics (Current era − Full cohort) flag
where the Current era differs meaningfully from the historical baseline.

---

## Lens 1: Theme Breadth

### Summary statistics

| Scope | Type group | n | Mean themes | Median | SD | Range |
|-------|------------|---|-------------|--------|-----|-------|
| Full cohort | Teaching | 14 | 4.4 | 5.0 | 1.74 | 1–7 |
| Full cohort | Community — Large | 43 | 4.4 | 4.0 | 1.50 | 2–8 |
| Full cohort | Community — Small | 45 | 4.2 | 4.0 | 1.06 | 2–7 |
| Full cohort | Specialty | 13 | 4.4 | 5.0 | 0.87 | 3–5 |
| Full cohort | All types | 115 | 4.3 | 4.0 | 1.30 | — |
| Current era | Teaching | 8 | 4.1 | 4.5 | 1.36 | 2–6 |
| Current era | Community — Large | 21 | 4.9 | 5.0 | 1.64 | 3–8 |
| Current era | Community — Small | 23 | 4.4 | 4.0 | 1.34 | 2–7 |
| Current era | Specialty | 10 | 4.7 | 5.0 | 0.67 | 3–5 |
| Current era | All types | 62 | 4.6 | 5.0 | 1.37 | — |

### Interpretation

The central finding across both scopes is that Ontario hospitals are concentrated
in a 4–5 theme band. The full cohort overall mean is 4.3 themes; the Current era
mean is 4.6 themes, a modest upward shift. The median moves from 4 to 5 between
scopes, suggesting a slight broadening in the Current era rather than a structural
change in distribution.

Specialty hospitals are the most internally consistent group. Their standard
deviation is 0.87 in the full cohort and narrows to 0.67 in the Current era, and
their range is bounded at 3–5 in both scopes. This reflects the more constrained
mandate of Specialty hospitals — mission specificity appears to limit strategic
dispersion.

Community — Large hospitals show the widest within-group spread in the Current era
(SD 1.64, range 3–8). This is the only type group where some hospitals reach 8
themes — at the upper limit of the 10-code taxonomy. The Community — Large SD is
notably wider in the Current era than the full cohort (1.64 vs. 1.50), consistent
with the 03c finding that this group is in a period of strategic expansion,
particularly around RES and INN themes.

Teaching hospitals show a slight reduction in mean breadth in the Current era
(4.4 → 4.1) and the widest SD of any type in the full cohort (1.74). This is
partially driven by Sinai Health (FAC 976), whose Current era plan covers only
2 themes (the minimum in the Current era dataset), and by CAMH (FAC 948), which
also has a narrow profile. The Teaching group is substantively heterogeneous in
breadth in a way the other groups are not.

The practical implication: theme count alone is not a strong homogeneity signal.
A hospital with 4 themes and a hospital with 6 themes may be covering the same
core territory — the identity of the themes matters more than the count. Lenses
2 and 3 address this directly.

---

## Lens 2: Core Profile Alignment

### Core profiles by type group

Core themes are those present in ≥50% of hospitals within a type group. Core
profiles differ between scopes because the composition of each type group's
hospital sample changes across eras.

**Full cohort core profiles:**

| Type group | Core themes (≥50% prevalence) |
|------------|-------------------------------|
| Teaching | WRK (79%), PAT (57%), RES (93%), EDI (57%) |
| Community — Large | WRK (98%), PAT (86%), PAR (72%) |
| Community — Small | WRK (87%), PAT (73%), PAR (82%), FIN (58%) |
| Specialty | WRK (85%), PAT (85%), RES (69%), ACC (54%) |

**Current era core profiles:**

| Type group | Core themes (≥50% prevalence) |
|------------|-------------------------------|
| Teaching | WRK (75%), PAT (50%), PAR (50%), RES (88%), EDI (50%) |
| Community — Large | WRK (100%), PAT (86%), PAR (81%), INN (52%) |
| Community — Small | WRK (91%), PAT (70%), PAR (74%), FIN (57%) |
| Specialty | WRK (90%), PAT (90%), FIN (50%), RES (70%) |

Two structural changes are notable. First, INN (Innovation & Digital Health) enters
the Community — Large core profile in the Current era, having not been present in
the full cohort core. This is consistent with the 03b finding of broad INN growth
across the sector and the 03c finding that Community — Large hospitals are  at the
leading edge of that adoption. Second, the Teaching core profile expands from 4 to
5 themes (PAR crosses 50% in the Current era), though at exactly the 50% threshold —
this is a marginal crossing rather than a robust consensus.

WRK (Workforce & People) is the one theme present in the core profile of every
type group in both scopes. It is the only sector-wide universal core theme.

### Modal match summary

| Scope | Type group | n | Core size | Full match % | Miss ≤1 % | Miss ≤2 % | Mean missing |
|-------|------------|---|-----------|-------------|-----------|-----------|--------------|
| Full cohort | Community — Large | 43 | 3 | 58.1 | 97.7 | 100 | 0.44 |
| Full cohort | Teaching | 14 | 4 | 42.9 | 57.1 | 85.7 | 1.14 |
| Full cohort | Community — Small | 45 | 4 | 35.6 | 71.1 | 93.3 | 1.00 |
| Full cohort | Specialty | 13 | 4 | 15.4 | 76.9 | 100 | 1.08 |
| Current era | Community — Large | 21 | 4 | 42.9 | 76.2 | 100 | 0.81 |
| Current era | Community — Small | 23 | 4 | 43.5 | 60.9 | 87.0 | 1.09 |
| Current era | Specialty | 10 | 4 | 30.0 | 80.0 | 90.0 | 1.00 |
| Current era | Teaching | 8 | 5 | 12.5 | 25.0 | 87.5 | 1.88 |

### Interpretation

**Community — Large** is the most conformist group in the full cohort — both
in absolute terms (58% full match) and in the tightness of the distribution
(97.7% miss ≤1 core theme, with a 3-theme core set). Their core profile is
compact and near-universally shared. In the Current era, this conformism is
partially disrupted by INN entering the core: the core set expands to 4 themes,
full match drops to 43%, and mean missing rises from 0.44 to 0.81. This is a
mechanical consequence of a newly entered core theme — hospitals that were
previously full matches are now missing INN — rather than a sign of strategic
divergence.

**Community — Small** is consistent across scopes. The 4-theme core is stable
(WRK, PAT, PAR, FIN), full match is 36–44%, and mean missing holds at 1.0–1.1.
This group appears to be in a stable equilibrium around its 4-theme core — neither
converging toward full adoption nor diverging away from it.

**Specialty** shows a notable shift in the Current era core (RES replaces ACC;
FIN enters). The core size remains 4, full match improves from 15% to 30%, and
mean missing is stable at ~1.0. The low full-match rate in the full cohort (15%)
was driven partly by the ACC inclusion in the full cohort core — a theme that
Specialty hospitals hold at 54% prevalence, meaning nearly half the group lacked
it. With ACC removed from the Current era core (below 50%), conformism improves.

**Teaching** is the most structurally divergent group in the Current era. The
core set is the largest (5 themes) but full match is the lowest (12.5% — one
hospital of eight). Mean missing is 1.88 per hospital, and only 25% of hospitals
miss just one or fewer core themes. The Teaching group's increasing core set size,
combined with low conformism, indicates that no single strategic template dominates
this group in the Current era. This is consistent with the Sinai Health and CAMH
findings from Analysis 04b: the Teaching group contains hospitals with genuinely
distinct strategic orientations that do not conform to a common template.

---

## Lens 3: Pairwise Jaccard Similarity

### Summary statistics

| Scope | Pair type | n pairs | Mean Jaccard | Median | SD | >0.50 % | >0.67 % |
|-------|-----------|---------|-------------|--------|-----|---------|---------|
| Full cohort | Community — Large | 903 | 0.469 | 0.429 | 0.179 | 48.4 | 11.7 |
| Full cohort | Community — Small | 990 | 0.465 | 0.429 | 0.215 | 47.6 | 12.4 |
| Full cohort | Specialty | 78 | 0.411 | 0.429 | 0.185 | 34.6 | 3.8 |
| Full cohort | Teaching | 91 | 0.405 | 0.375 | 0.200 | 36.3 | 12.1 |
| Full cohort | Between types | 4,493 | 0.389 | 0.400 | 0.196 | 34.4 | 6.6 |
| Current era | Community — Large | 210 | 0.488 | 0.500 | 0.167 | 51.0 | 11.4 |
| Current era | Community — Small | 253 | 0.435 | 0.400 | 0.225 | 41.1 | 12.6 |
| Current era | Specialty | 45 | 0.428 | 0.429 | 0.204 | 35.6 | 4.4 |
| Current era | Between types | 1,355 | 0.395 | 0.400 | 0.187 | 34.2 | 5.5 |
| Current era | Teaching | 28 | 0.357 | 0.354 | 0.164 | 28.6 | 0.0 |

### Full cohort vs. Current era delta

| Pair type | Full cohort | Current era | Delta | Direction |
|-----------|-------------|-------------|-------|-----------|
| Community — Large | 0.469 | 0.488 | +0.019 | Converging |
| Community — Small | 0.465 | 0.435 | −0.030 | Diverging |
| Specialty | 0.411 | 0.428 | +0.017 | Converging |
| Teaching | 0.405 | 0.357 | −0.048 | Diverging |
| Between types | 0.389 | 0.395 | +0.006 | No meaningful change |

### Interpretation

The sector-level Jaccard picture is one of moderate similarity. The overall
mean of 0.39–0.49 across pair types, with roughly a third to half of pairs
exceeding 0.50, indicates that hospitals share a meaningful common thematic
core but are not interchangeable. Pairs exceeding Jaccard 0.67 — a threshold
suggesting two-thirds or more of themes are shared — are consistently rare
across all pair types (3–12%), confirming that near-identical theme portfolios
are uncommon even within type groups.

**Community — Large** is the most internally similar group in both scopes and
shows a converging trend (+0.019 delta). This is consistent with the Lens 2
finding: a compact, near-universally shared core profile, combined with INN
entry into the core in the Current era, is producing mild within-group
convergence. The Current era median for Community — Large pairs reaches exactly
0.50 — the midpoint of the Jaccard scale.

**Teaching** is the most internally divergent group in the Current era, and is
diverging (−0.048 delta). The Current era Teaching mean (0.357) falls below the
between-type mean (0.395), meaning that Teaching hospitals are on average less
similar to each other than hospitals of different types are to one another. This
is a notable finding. It is not a sampling artefact — it reflects genuine
strategic divergence within the Teaching group, driven by the distinct
orientations of Sinai Health, CAMH, and UHN relative to peer Teaching hospitals.
No Teaching pairs in the Current era exceed Jaccard 0.67.

**Community — Small** is diverging (−0.030 delta). The standard deviation for
this group is the highest of any within-type group (0.225 in the Current era),
indicating wide dispersion. Some Community — Small pairs are very similar
(several share all 4 core themes); others share only 1–2 themes. This bimodal
character — some tight clusters of similar hospitals alongside genuine outliers
— is not captured by the mean alone.

**Between-type similarity** (0.389–0.395) is lower than within-type similarity
for Community — Large, Community — Small, and Teaching across both scopes,
confirming that type group membership is associated with modestly higher
within-group similarity. The effect is not large — within-type means are only
0.04–0.09 higher than between-type — but it is consistent. The exception is
Current era Teaching, where within-type similarity falls below the between-type
mean.

---

## Cross-Lens Synthesis

The three lenses converge on a consistent picture of moderate, differentiated
homogeneity:

**The sector occupies a moderate homogeneity band.** Hospitals are not
interchangeable, but they are not strategically distinct either. Most hospitals
in most type groups cover 4–5 themes from a 10-code taxonomy, with the majority
of theme-set pairs sharing 40–50% of their content. This is consistent with a
sector subject to shared institutional pressures — regulatory environment, funding
structure, accreditation requirements, provincial policy signals — that produce
convergent thematic coverage without producing identical plans.

**Within-type similarity is real but modest.** Community — Large hospitals are
the most internally cohesive: compact core profile, high full-match rates, and
the highest within-group Jaccard mean. Community — Small and Specialty occupy a
middle range. Teaching is the exception — the least internally cohesive in the
Current era and the group where the between-type analogy fails (within-type
similarity is lower than between-type).

**The Current era shows two diverging trajectories.** Community — Large is
converging toward a stable 4-theme template, now including INN. Teaching is
diverging: its core profile is larger than any other group (5 themes), full match
is the lowest (12.5%), and Jaccard similarity is declining. These are not
contradictory findings — they reflect genuinely different dynamics in the two
groups. Community — Large hospitals are conforming to an emerging consensus;
Teaching hospitals are differentiating, at least in the Current era cohort.

**Theme breadth is not a reliable homogeneity proxy.** A hospital that covers
5 themes may have 4 of the sector's universal core themes plus one peripheral
theme, making it highly conformist by Lens 2 and 3 measures. Another hospital
covering 5 themes may have 2 core themes and 3 peripheral ones, making it an
outlier. The number of themes alone does not distinguish these cases — the
identity of the themes does.

---

## Interpretive Limits

**Binary representation discards direction count and weight.** The theme vector
used in all three lenses treats a hospital with 12 WRK directions identically to
one with a single WRK direction. This is appropriate for the homogeneity question
as posed (is the theme present?) but does not capture depth of strategic investment.

**Core profile definition is threshold-dependent.** The 50% threshold for core
designation is a methodological choice. Themes at 45–55% prevalence are not
meaningfully different from 50% — the Teaching PAT, PAR, and EDI themes (each
at exactly 50% in the Current era) represent marginal consensus, not strong
consensus. Results near this boundary should be interpreted with that caveat.

**Shared strategic plans inflate within-type similarity.** Several hospital pairs
share a single plan document (FAC 813/983 Stratford-Huron Perth, FAC 597/626
Almonte–Carleton Place, FAC 593/824 Four Counties–Tillsonburg). These pairs
will produce Jaccard = 1.0 and inflate the Community — Small within-group mean.
Their contribution to the pairwise summary is noted but not separately removed
from the reported statistics.

**Small Current era Teaching n.** With 8 Teaching hospitals in the Current era
cohort, the 28 pairs represent limited statistical ground. The Teaching divergence
finding is directionally consistent with the Lens 2 results, but the Jaccard
summary for this group should be interpreted with the small-n caveat applied to
all Current era Teaching findings.

---

## Outputs

| File | Description |
|------|-------------|
| `analysis/outputs/tables/04a_breadth_summary.csv` | Theme breadth by type group and scope (mean, median, SD, range) |
| `analysis/outputs/tables/04a_core_profile_by_type.csv` | Theme-level prevalence by type group, with core profile flag; both scopes |
| `analysis/outputs/tables/04a_modal_match_summary.csv` | Core profile match summary by type group and scope |
| `analysis/outputs/tables/04a_jaccard_summary.csv` | Pairwise Jaccard summary by pair type and scope |
| `analysis/outputs/tables/04a_jaccard_pairwise.csv` | Full pairwise matrix (8,446 pairs) with FAC codes, type group, Jaccard, intersection, and union |
| `analysis/outputs/figures/04a_breadth_distribution.png` | Dot strip of theme counts by type group and scope |
| `analysis/outputs/figures/04a_jaccard_heatmap.png` | Jaccard mean heatmap by type-group pair |
| `analysis/outputs/figures/04a_jaccard_density.png` | Density plot of pairwise Jaccard by pair type and scope |
