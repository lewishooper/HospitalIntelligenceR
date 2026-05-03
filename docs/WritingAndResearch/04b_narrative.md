# Unique and Outlier Strategies in Ontario Hospital Strategic Plans
## Ontario Public Hospitals — Outlier and Distinctiveness Analysis
*HospitalIntelligenceR | Analysis 04b | May 2026*

---

## Overview

Analysis 04a established that Ontario hospital strategic plans occupy a moderate
homogeneity band: similar enough to suggest shared institutional pressures, varied
enough that genuine differentiation exists. This analysis identifies where that
differentiation lives — which hospitals deviate from their type group's consensus,
and which strategic directions, as written by hospitals themselves, are genuinely
unusual relative to peers addressing the same theme.

Two analytical parts address this:

**Part 1 — Theme-level outlier identification (pure R):** Using the type-group
core profiles established in 04a, hospitals are flagged for three types of
deviation: missing one or more core themes for their type group, adopting themes
that fewer than 25% of their peers include, or lacking both of the sector-wide
core themes (WRK and PAT).

**Part 2 — Direction-level distinctiveness (Claude API):** Within each theme ×
hospital type cell, the direction names and descriptions as written by hospitals
are submitted to the Claude API. The API identifies which directions use generic
sector language and which are unusual, specific, or distinctive relative to peers
in the same cell.

**A critical distinction runs through both parts.** Part 1 operates entirely at
the **theme level** — on the standardized classifications assigned by this project,
not on the hospitals' own words. Part 2 operates at the **direction level** — on
the text hospitals actually wrote. A hospital that appears unremarkable at the theme
level may have written directions that are linguistically or substantively distinctive,
and vice versa. Both levels are necessary to answer the uniqueness question fully.

---

## Data and Method

**Cohort:** 65 Ontario public hospitals in the Current era (plan start 2024–2026),
producing 316 usable classified directions. This is the primary analysis population.
Part 1 also produces full-cohort (n=119) results as a reference scope.

**Directions and themes:** Strategic directions are the named priorities, pillars,
or goals in each hospital's plan — written by the hospital in its own language.
Themes (WRK, PAT, PAR, etc.) are the standardized classifications assigned by this
project in Analysis 02. Part 1 works with themes; Part 2 works with directions.

**Outlier scoring (Part 1):** Each hospital receives a composite outlier score:
one point per missing core theme, one point per peripheral theme adopted, and
three additional points for lacking both sector-wide core themes (WRK and PAT).
Higher scores indicate greater deviation from the type-group consensus.

**Peripheral theme threshold:** A theme is considered "peripheral" for a type group
if fewer than 25% of hospitals in that group include it. Peripheral theme adoption
is a signal of discretionary strategic choice — the hospital is doing something
most of its peers are not.

**Part 2 API approach:** For each theme × type cell with five or more directions,
a single Claude API call received the full list of direction names and descriptions
for that cell and identified generic versus distinctive directions. Twenty-five of
38 eligible cells met the five-direction threshold and were processed. Temperature
was set to 0 for deterministic output. Total cost: $0.19 USD.

**Classification boundary caveat:** Several hospitals appear to be missing core
themes (particularly PAT — Patient Care & Quality) because their plans use an
architectural approach that distributes patient care content across multiple
directions rather than naming it as a standalone priority. This is a plan structure
choice, not evidence of genuine deprioritization. Hospitals with compact 3–4 direction
structures that embed patient care within performance, partnerships, or access
directions are the most commonly affected. Where plan architecture is the plausible
explanation for a missing core theme, it is noted in the findings below.

---

## Part 1: Theme-Level Outliers

### Missing core themes

The majority of hospitals in every type group are missing at least one core theme
for their type in the Current era:

| Type | n | Missing ≥1 core theme | % |
|------|---|----------------------|---|
| Teaching | 12 | 9 | 75% |
| Community — Large | 20 | 15 | 75% |
| Community — Small | 25 | 21 | 84% |
| Specialty | 8 | 6 | 75% |

These rates are high enough to indicate that "missing a core theme" is not itself
a strong outlier signal — it describes the majority experience across all groups.
The more meaningful question is how many core themes are missing and which ones.
A hospital missing one recently-entered core theme (e.g., INN or RES for Community
— Large) is substantively different from a hospital missing three or four foundational
ones.

**The INN and RES effect in Community — Large.** Of the fifteen Community — Large
hospitals missing a core theme, the majority are missing INN or RES — both of which
entered the Community — Large core profile only in the Current era by crossing the
50% threshold for the first time. The hospitals missing these themes are not strategic
laggards; they are simply at or below the median on themes that have only recently
achieved consensus status. This should not be treated as meaningful outlier behaviour.

**The PAT missing-core pattern — plan architecture, not deprioritization.** Sixteen
of 65 Current era hospitals are classified as missing PAT. Spot-checking consistently
finds that patient care content exists throughout these hospitals' plans but is embedded
within other direction types (Access, Partnerships, Performance) rather than named as
a standalone direction. This is most common in hospitals with compact 3–4 direction
plans. The hospitals genuinely absent of PAT-equivalent content are likely few;
identifying them would require direction-level reading beyond what the theme
classification resolves.

**The most credible theme-level outliers** are those with high composite scores
driven by multiple missing core themes across different theme categories — not
solely the INN/RES adoption lag or the PAT architecture effect:

| FAC | Hospital | Type | Score | Missing | Peripheral |
|-----|----------|------|-------|---------|------------|
| 611 | Blind River North Shore Health Network | Comm — Small | 9 | WRK, PAT, PAR, ACC | EDI, ORG |
| 592 | Napanee Lennox & Addington | Comm — Small | 8 | WRK, PAR, FIN, ACC | EDI |
| 662 | Geraldton District Hospital | Comm — Small | 7 | PAT, FIN, ACC | INF |
| 948 | Toronto Addiction & Mental Health (CAMH) | Specialty | 7 | WRK, PAT, FIN | EDI |
| 624 | Campbellford Memorial Hospital | Comm — Small | 7 | PAT, PAR, FIN | INF |
| 862 | Toronto Women's College Hospital | Teaching | 6 | WRK, PAT, PAR | — |
| 947 | Toronto University Health Network (UHN) | Teaching | 6 | WRK, EDI | INF |
| 961 | Ottawa Heart Institute | Teaching | 6 | WRK, PAR, EDI | — |

**CAMH (FAC 948)** is the most structurally distinctive Specialty hospital. Missing
WRK, PAT, and FIN — three of five Specialty core themes — its plan is organized around
its mental health and addiction mandate rather than the general hospital strategic
template. Part 2 confirms this: CAMH's distinctive directions in the RES and WRK cells
reflect patient-centered research and workforce approaches specific to its mental health
identity.

**Women's College Hospital (FAC 862)** is the most structurally unusual Teaching
hospital in the Current era. Missing WRK, PAT, and PAR — three of five Teaching core
themes — its plan concentrates heavily on equity, research, and gender-specific health
priorities that reflect its specialized mandate as Ontario's only independent academic
ambulatory hospital. This is coherent institutionally but represents genuine deviation
from Teaching group norms.

**UHN (FAC 947)** presents a different outlier profile. Missing WRK and EDI, with INF
as a peripheral adoption, UHN's plan is organized around transformative patient
experiences, system advocacy, and research leadership — a mandate-forward structure
that distributes what other hospitals call workforce into other strategic frames. Its
scale and complexity as the province's largest research hospital system are reflected
in an unusually distinctive strategic architecture.

**Ottawa Heart Institute (FAC 961)** is the most mandate-specific Teaching outlier.
Missing WRK, PAR, and EDI, its plan focuses almost entirely on cardiac care excellence,
community reach of specialized cardiac services, and cardiac research — a coherent
expression of its role as a highly specialized referral centre rather than a general
teaching hospital.

### Peripheral theme adopters

| Type | n | Has peripheral theme | % |
|------|---|---------------------|---|
| Teaching | 12 | 1 | 8% |
| Community — Large | 20 | 5 | 25% |
| Community — Small | 25 | 13 | 52% |
| Specialty | 8 | 2 | 25% |

Community — Small hospitals are the most frequent adopters of peripheral themes
(52%, n=13). The most common peripheral themes in this group are INF, INN, EDI,
and ORG — all themes with low Community — Small prevalence (generally under 20%).
Peripheral adoption in this group often correlates with geographic specificity: the
hospitals adopting INN, INF, or ORG are frequently those serving distinctive
communities (northern, Indigenous-serving, or bilingual), where the peripheral theme
reflects a real programmatic commitment.

### Sector core (WRK + PAT) absence

| Scope | n | Missing WRK | Missing PAT | Missing both |
|-------|---|-------------|-------------|--------------|
| Current era | 65 | 6 | 16 | 19 (29%) |
| Full cohort | 119 | 12 | 27 | 35 (29%) |

The 29% sector-core absence rate is stable across both scopes. Missing PAT is far
more common than missing WRK, consistent with the plan-architecture explanation:
patient care content is more commonly embedded in other directions than workforce
content. The six hospitals missing WRK (FACs 592, 611, 862, 947, 961, and 948)
represent a mix of plan-architecture effects and genuine strategic distinctiveness
requiring case-by-case interpretation.

---

## Part 2: Direction-Level Distinctiveness

### Coverage and scope

Twenty-five theme × type cells with five or more directions were submitted to the
Claude API. Thirteen cells fell below the threshold and were skipped. A total of
99 distinctive directions were identified across 316 current-era directions processed.
This represents approximately one in three directions being flagged as distinctive
— a high rate that should be interpreted carefully. The API was calibrated to identify
directions notable relative to their immediate cell peers, not absolute rarity across
the full dataset. Many of the 99 flagged directions use language that is distinctive
within their cell but would not be considered unusual if compared across all hospitals
in the cohort.

**Distribution by theme:**

| Theme | Distinctive directions |
|-------|----------------------|
| PAT | 20 |
| WRK | 17 |
| PAR | 13 |
| RES | 13 |
| INN | 11 |
| ACC | 10 |
| FIN | 7 |
| INF | 5 |
| EDI | 3 |

**Distribution by type group:**

| Type group | Distinctive directions |
|------------|----------------------|
| Community — Large | 34 |
| Teaching | 27 |
| Community — Small | 27 |
| Specialty | 11 |

The Specialty group's lower count (11) reflects two facts: fewer cells met the
five-direction threshold (Specialty is the smallest type group in the Current era,
n=8), and the highly specialized mandates of Specialty hospitals make even their
more generic-sounding directions contextually distinctive. The Teaching group's
27 distinctive directions span a wide range of institutional identities, from
cardiac-specialized to paediatric to francophone to multi-site academic.

### Key findings by theme

**WRK — Workforce & People (17 distinctive directions)**

Distinctive WRK directions are those that embed specific commitments — to named
employee populations, particular cultural values, or concrete positioning goals —
rather than the generic "attract, retain, and develop our people" language that
dominates the theme. The most substantively specific are FAC 753 (Montfort), which
explicitly frames workforce strategy as innovation in response to healthcare labour
shortage context, and FAC 942 (Hamilton Health Sciences), which commits to becoming
"the top Canadian hospital to build an impactful career" — a specific competitive
positioning that most hospitals avoid. Several Community — Small hospitals are notable
for extending workforce directions beyond staff: FAC 739 (Nipigon) integrates
community stakeholders into its workforce culture framework, and FAC 784 (Manitoulin)
applies "Provider Experience" terminology that mirrors patient experience frameworks.

**PAT — Patient Care & Quality (20 distinctive directions)**

PAT yields the largest count of distinctive directions, consistent with it being the
theme where hospitals most frequently attempt to differentiate their patient-facing
language. Specialty hospitals produce several of the most content-specific PAT
directions: FAC 827 (Baycrest) names dementia care and geriatric care explicitly
rather than using generic quality improvement language; FAC 972 (Waypoint) identifies
three specific vulnerable populations (mental illness, addiction, complex older adults)
in a single direction. Among Teaching hospitals, FAC 961 (Heart Institute)'s direction
"Your heart is in the right place" and FAC 751 (CHEO)'s emphasis on evidence-based
pediatric care are the most institutionally specific. Community — Small hospitals
FAC 592 (Napanee) and FAC 800 (Hawkesbury) stand out for directions that commit to
specific communication strategies and care focus rather than aspirational quality
language.

**RES — Research & Academic (13 distinctive directions)**

Teaching hospitals dominate distinctive RES directions, as expected. The most
ambitious are FAC 837 (SickKids), which commits to leading "the era of precision
child health" — a specific emerging field — and FAC 862 (Women's College), which
focuses on sex and gender health research as a distinctive niche. Among Community
— Large hospitals, FAC 606 (Barrie RVH) is the most analytically interesting: its
RES direction explicitly commits to becoming "a regional academic health sciences
centre" — a significant repositioning claim for a community hospital that would
represent a structural shift in its mandate if pursued. FAC 979 (Scarborough Health
Network) targets research specifically at Scarborough's community health needs,
making its research direction geographically and demographically specific.

**INN — Innovation & Digital Health (11 distinctive directions)**

Community — Large hospitals produce the most distinctive INN directions, driven
by hospitals that have moved beyond aspirational digital language to specific
commitments. FAC 736 (Southlake) states "data is the most important strategic asset
we have" and frames digital health through the philosophical claim "Digital health is
health." FAC 701 (Mackenzie Health) claims leadership positioning in digital health
with specific AI and smart technology references. SickKids (FAC 837) links its INN
direction to its specific capital redevelopment project ("Project Horizon"), grounding
digital innovation in a concrete institutional context.

**PAR — Partnerships & Community (13 distinctive directions)**

Distinctive PAR directions typically specify the nature or depth of the partnership
rather than using generic collaboration language. FAC 968 (Muskoka Algonquin
Healthcare) references the "Made-in-Muskoka Healthcare model" — the most geographically
specific partnership framing in the dataset. FAC 947 (UHN) positions itself as a
"powerful solutions partner" with an ecosystem advocacy role — an assertive system
leadership stance that is unusual among Teaching hospital partnership directions.
Among Community — Small hospitals, FAC 684 (Rural Roads) produces two distinctive
directions that commit to organizational integration rather than general collaboration.

**FIN — Financial Sustainability (7 distinctive directions)**

The most notable FIN finding is the emergence of environmental sustainability as a
paired strategic commitment. FAC 736 (Southlake) and FAC 763 (Pembroke Regional)
explicitly link financial sustainability with environmental stewardship in the same
named direction. FAC 837 (SickKids) frames financial sustainability around
"safeguarding the future of children" — connecting fiscal health to its core
paediatric mission. FAC 611 (Blind River) uses the metaphor "making sure our tank
is full so we can continue to serve our communities" — colloquial language that is
distinctive in a strategic planning context.

**Language as identity — francophone hospitals**

FAC 753 (Montfort) produces distinctive directions across multiple themes that
explicitly name its francophone mandate: its ACC direction commits to expanding
French-language services, and its EDI direction frames social accountability toward
the communities it serves in specifically francophone terms. These directions are
structurally distinctive in the dataset regardless of content — the institutional
identity is visible in the strategy text itself.

---

## Cross-Part Synthesis

Several hospitals appear as notable in both Part 1 (theme-level) and Part 2
(direction-level) analyses, reinforcing their distinctiveness from two independent
vantage points:

**CAMH (FAC 948)** is distinctively organized at the theme level (missing WRK, PAT,
FIN from Specialty core) and produces distinctive directions in RES that integrate
patient and family involvement in research and care model transformation. Its plan
reflects its mental health and addiction mandate in a way that is institutionally
coherent but does not map to general hospital strategic norms.

**Women's College Hospital (FAC 862)** is the most theme-level-unusual Teaching
hospital (missing WRK, PAT, PAR) and produces distinctive directions in RES and EDI
that name sex and gender health research and equity advancement as explicit strategic
commitments. The two lenses are consistent: this hospital's strategy reflects a
genuinely distinct institutional identity, not a poorly constructed plan.

**UHN (FAC 947)** appears at the theme level as a notable outlier (missing WRK and
EDI) and produces distinctive directions in PAR (ecosystem advocacy) and PAT
(transformative experiences) that reflect its scale and complexity. Its distinctiveness
is coherent — a hospital of UHN's size and mandate produces qualitatively different
strategic language.

**Ottawa Heart Institute (FAC 961)** is the most mandate-specific Teaching outlier
at the theme level and produces distinctive directions in ACC (community cardiac reach),
PAT (world-leading cardiac interventions), and RES (cardiac research and innovation).
Both lenses confirm that this hospital's strategic plan reads as a cardiac specialty
institution, not a general teaching hospital.

**Barrie RVH (FAC 606)** does not appear as a theme-level outlier — its portfolio
conforms to Community — Large norms — but produces distinctive directions across
PAT, RES, INN, and WRK. Its RES direction's explicit aspiration to become a regional
academic health sciences centre is the most ambitious repositioning claim by any
Community — Large hospital in the dataset. Its distinctiveness is entirely in the
direction text.

**The northern and Indigenous-serving hospitals** (Sioux Lookout FAC 964, Manitoulin
FAC 784) appear in both parts: peripheral theme adopters at the theme level (adopting
INN, INF, and EDI that most Community — Small peers do not), with direction text that
names culturally safe care, mental health and addictions, and population health
strategies specific to their communities. Their distinctiveness is coherent — it
reflects real differences in the populations they serve, not random strategic choices.

---

## Interpretive Limits

**Linguistic distinctiveness ≠ strategic uniqueness.** The Part 2 analysis identifies
directions that use more specific, committal, or unusual language than peers. This
does not mean the underlying strategy is genuinely different. A hospital that labels
its infrastructure investment "Campus Transformation" is more specific than one that
writes "invest in our facilities" — but both are investing in facilities. The direction
text captures ambition and specificity of articulation; it does not capture whether
the hospital actually executes differently.

**The 99-direction count reflects cell-relative distinctiveness.** The API was asked
to identify directions unusual within each theme × type cell. Approximately one in
three directions was flagged, which is high for a concept typically reserved for
genuine rarity. Many flagged directions are distinctive within their cell but would
not stand out if compared across the full dataset. The qualitative descriptions in the
CSV should be read alongside this caveat.

**Shared strategic plans inflate within-group similarity.** Two Community — Small
hospital pairs share a single strategic plan document (FAC 597/626 Almonte–Carleton
Place, FAC 593/824 Four Counties–Tillsonburg). These pairs will appear as near-identical
at both the theme and direction level. Shared plan language should be identified and
noted where it appears in the distinctive directions table.

**The classification boundary affects Part 1 interpretation.** As noted in the Data
and Method section, some PAT-missing flags reflect plan architecture rather than
genuine deprioritization. The outlier scores for several Community — Small hospitals
should be interpreted with this caveat in mind.

---

## Implications for Future Analysis

**CAMH, Women's College Hospital, and the Ottawa Heart Institute warrant case-study
treatment** in any publication using this dataset. They are the clearest examples
of hospitals whose strategic plans reflect a genuinely distinct institutional identity
rather than adherence to the sector template. Their distinctiveness is analytically
defensible from two independent lenses.

**Barrie RVH's repositioning claim** (aspiring to academic health sciences centre
status) is the most analytically interesting community hospital direction in the
dataset. If this aspiration is pursued, it would represent a structural shift in
how a Community — Large hospital defines its mandate. It warrants monitoring in
future plan cycles.

**The financial-environmental integration pattern** (FAC 736 Southlake and FAC 763
Pembroke explicitly linking FIN and environmental sustainability) is a nascent pattern
not captured by the 03b/03c temporal analyses. It appeared only in Current era plans
and may signal an emerging strategic norm.

**The francophone and Indigenous-serving hospital directions** (Montfort FAC 753,
Manitoulin FAC 784, Sioux Lookout FAC 964) are the clearest examples of population-
mandate alignment in the dataset — hospitals whose written directions directly reflect
the specific communities they serve. This is an analytically important category for
any work on health equity and strategic planning.

---

## Outputs

| File | Description |
|------|-------------|
| `analysis/outputs/tables/04b_theme_outliers.csv` | Hospital-level outlier flags, scores, and missing/peripheral theme detail (both scopes) |
| `analysis/outputs/tables/04b_peripheral_adopters.csv` | Hospital-level peripheral theme adoption detail (both scopes) |
| `analysis/outputs/tables/04b_distinctive_directions.csv` | 99 distinctive directions with FAC, hospital name, type group, theme, direction text, and API reason |
| `analysis/outputs/figures/04b_outlier_map.png` | Scatter plot: missing core (y) vs peripheral adopted (x), coloured by type group, faceted by scope |
| `logs/04b_api_log.csv` | API call log: cell, status, n distinctive, tokens, cost |
