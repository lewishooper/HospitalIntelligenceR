# Unique and Outlier Strategies in Ontario Hospital Strategic Plans
## Ontario Public Hospitals — Outlier and Distinctiveness Analysis
*HospitalIntelligenceR | Analysis 04b | April 2026*

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

**Cohort:** 62 Ontario public hospitals in the Current era (plan start 2024–2026),
producing 313 usable classified directions. This is the primary analysis population.
Part 1 also produces full-cohort (n=115) results as a reference scope.

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
a single Claude API call receives the full list of direction names and descriptions
for that cell and identifies generic versus distinctive directions. Twenty-one of
23 eligible cells were successfully processed (two cells had transient API errors;
their results are absent from the output table but were partially captured in a
prior run). Temperature was set to 0 for deterministic output. Total cost: $0.17 USD.

**Classification boundary caveat:** Several hospitals appear to be missing core
themes (particularly PAT — Patient Care & Quality) because their plans use an
architectural approach that distributes patient care content across multiple
directions rather than naming it as a standalone priority. This is a plan structure
choice, not evidence of genuine deprioritization. The spot-check of FAC 813
(Stratford General) and FAC 983 (Huron Perth) confirmed that PAT content is present
throughout their plans; their three-direction structure (People, Partnerships,
Performance) simply does not map cleanly to the taxonomy's expectation of a named
PAT direction. This caveat applies to several Community — Small hospitals with
compressed plan structures. Where plan architecture is the plausible explanation
for a missing core theme, it is noted in the findings below.

---

## Part 1: Theme-Level Outliers

### Missing core themes

The majority of hospitals in every type group are missing at least one core theme
for their type in the Current era:

| Type | n | Missing ≥1 core theme | % |
|------|---|----------------------|---|
| Teaching | 8 | 7 | 88% |
| Community — Large | 21 | 12 | 57% |
| Community — Small | 23 | 13 | 56% |
| Specialty | 10 | 7 | 70% |

These rates are high enough to indicate that "missing a core theme" is not itself
a strong outlier signal — it describes the majority experience in most groups. The
more meaningful question is how many core themes are missing and which ones. A
hospital missing one peripheral-adjacent core theme (e.g., INN for Community —
Large) is substantively different from a hospital missing four (e.g., FAC 976
Sinai Health missing WRK, PAT, PAR, and EDI).

**The INN effect in Community — Large.** Seven of the twelve Community — Large
hospitals missing a core theme are missing INN (Innovation & Digital Health) only.
INN entered the Community — Large core profile only in the Current era (see 04a),
meaning it crossed the 50% threshold recently. The hospitals missing INN are not
strategic laggards — they are simply earlier in adoption of a theme that has recently
become consensus. This should not be treated as meaningful outlier behaviour.

**The PAT missing-core pattern — plan architecture, not deprioritization.** Fifteen
of 62 Current era hospitals are classified as missing PAT. Spot-checking confirms
that for most of these hospitals, patient care content exists throughout their plans
but is embedded within other direction types (ACCESS, PARTNERSHIPS, PERFORMANCE)
rather than named as a standalone direction. This is most common in hospitals with
compact 3–4 direction plans. The hospitals genuinely missing PAT-equivalent content
are likely few; identifying them would require direction-level reading beyond what
the theme classification can resolve.

**The most credible theme-level outliers** are those with high composite scores
driven by multiple missing core themes across different theme categories, not just
the INN or PAT effects described above:

| FAC | Hospital | Type | Score | Missing | Peripheral |
|-----|----------|------|-------|---------|------------|
| 976 | Toronto Sinai Health System | Teaching | 7 | WRK, PAT, PAR, EDI | — |
| 948 | Toronto Addiction & Mental Health (CAMH) | Specialty | 7 | WRK, PAT, FIN | EDI |
| 592 | Napanee Lennox & Addington | Comm — Small | 7 | WRK, PAR, FIN | EDI |
| 611 | Blind River North Shore Health Network | Comm — Small | 7 | WRK, PAT, PAR | EDI |
| 947 | Toronto University Health Network (UHN) | Teaching | 6 | WRK, EDI | INF |
| 624 | Campbellford Memorial Hospital | Comm — Small | 6 | PAT, PAR, FIN | — |

**Sinai Health (FAC 976)** is the most structurally distinctive hospital at the
theme level. Missing WRK, PAT, PAR, and EDI — four of the five Teaching core themes
— its plan is organized almost entirely around research, academic mission, and
institutional development. Part 2 confirms this: four of the Teaching × RES
distinctive directions belong to Sinai, including commitments to global scientific
leadership, a new research facility, and a formal "Sinai Health Research" enterprise.
Sinai's strategic plan reads less like a Teaching hospital plan and more like a
research institute plan. This is substantively coherent given Sinai's specific
institutional identity but represents genuine strategic differentiation.

**CAMH (FAC 948)** is the most structurally distinctive Specialty hospital. Missing
WRK, PAT, and FIN while adopting EDI as a peripheral theme, its plan is organized
around its mental health and addictions mandate in a way that does not map cleanly
to the general hospital taxonomy. This is expected given CAMH's highly specialized
scope — it is not a general acute hospital and its strategic priorities reflect that
difference. The EDI peripheral adoption is consistent with CAMH's emphasis on
health equity in mental health service delivery.

**The remote and northern Community — Small hospitals** (FAC 784 Manitoulin,
FAC 964 Sioux Lookout, FAC 592 Napanee, FAC 611 Blind River) cluster as outliers
for different reasons. Sioux Lookout and Manitoulin adopt INN and EDI as peripheral
themes — unusual for Community — Small hospitals — in ways that reflect their
Indigenous-serving mandates (culturally safe care, digital health as access equity).
Napanee and Blind River show high missing-core scores partly due to plan architecture
(small plan size, compressed direction structure) and partly due to genuine focus
differences. These are not random outliers; they reflect specific community contexts.

### Peripheral theme adopters

Forty-three percent of Current era Community — Large hospitals and 40% of Specialty
hospitals adopt at least one peripheral theme — themes present in fewer than 25%
of their type group. The most common peripheral adoptions:

**ACC (Access & Care Delivery) in Community — Large:** Five Community — Large
hospitals include ACC as a peripheral theme. This is notable because ACC is a core
theme for Community — Small hospitals, suggesting some larger community hospitals
are taking on an access mandate more typical of smaller regional peers. FAC 701
(Mackenzie Health) and FAC 771 (Peterborough Regional) both include explicit
regional access commitments in their plans.

**EDI (Equity, Diversity & Inclusion) in Community — Small:** Four Community —
Small hospitals adopt EDI peripherally. In three of the four cases (Manitoulin,
Sioux Lookout, Napanee, Blind River), the EDI adoption is geographically motivated
— these hospitals serve populations where equity and cultural safety are operationally
relevant in a way that differs from the sector average.

**ORG (Organizational Culture) in Community — Large:** Two Community — Large
hospitals (FAC 763 Pembroke Regional, FAC 982 Blanche River Health) adopt ORG
peripherally. ORG is the lowest-prevalence theme across the dataset and its
appearance signals explicit organizational identity work — both hospitals appear
to be in periods of internal renewal or repositioning.

---

## Part 2: Direction-Level Distinctiveness

### Coverage and approach

Twenty-one theme × type cells were successfully processed, covering 89 distinctive
directions identified from 313 total current-era directions. The API evaluated
directions as written by hospitals — their own words, labels, and descriptions —
and flagged those that deviate from the generic sector language typical of each cell.

An important methodological note: the API flags linguistic or substantive specificity
as the marker of distinctiveness. A direction that names a specific population,
geography, program, or commitment is flagged; one that uses standard sector
vocabulary ("improve patient experience," "foster a culture of excellence") is not.
Linguistic distinctiveness does not always mean strategic uniqueness — a hospital
that names its capital project is more specific, but the underlying strategy
(invest in infrastructure) may be identical to peers. The directions flagged here
are more specific than average, not necessarily more strategically ambitious.

### Sector-wide patterns in generic directions

Across all cells, the API consistently identified a set of generic direction
archetypes — directions that could appear in virtually any Ontario hospital plan.
The most common generic patterns:

- WRK: "Invest in our people," "Foster a culture of excellence," "Attract and
  retain talented staff"
- PAT: "Deliver exceptional patient-centred care," "Improve the patient experience,"
  "Advance quality and safety"
- PAR: "Build strong partnerships," "Advance integrated care," "Collaborate with
  community partners"
- FIN: "Ensure financial sustainability," "Strengthen our fiscal foundation,"
  "Steward our resources"

These directions are generic not because they are wrong but because they commit to
nothing specific. They are the strategic equivalent of a mission statement — broadly
true, universally applicable, and analytically interchangeable across hospitals.

### Notable distinctive directions by theme

**WRK — Workforce & People (16 distinctive directions)**

The most common basis for a distinctive WRK direction is a specific philosophical
or cultural commitment rather than a generic workforce statement. Two hospitals —
FAC 813 (Stratford General) and FAC 983 (Huron Perth Healthcare Alliance) — use
the identical phrase "Nothing for you, without you" as an organizing principle for
their workforce strategy. These hospitals share a plan, which the API correctly
identified without being told. FAC 784 (Manitoulin) uses "Provider Experience"
framing — explicitly mirroring patient experience language — as a distinctive
structural choice. FAC 704 (Erie Shores Leamington) positions itself as a "Chosen
Workplace," an unusually competitive framing for a small community hospital.
FAC 709 (Listowel Memorial) commits explicitly to a "culture of kindness," which
is specific cultural language not found in peer plans.

**PAT — Patient Care & Quality (18 distinctive directions)**

The most distinctive PAT directions are those that either commit to a specific
improvement mechanism or name a specific population. FAC 592 (Napanee) commits
to "annually identifying 1–2 areas or units that require specific quality improvement
transformation" — an unusual operational specificity for a strategic direction.
FAC 784 (Manitoulin) explicitly names "culturally safe healthcare" in its patient
experience direction, which is substantively distinctive for a hospital serving
Indigenous communities in northern Ontario. FAC 827 (Baycrest) names "World-Class
Dementia Care" — both the population specificity and the ambition level are unusual.
FAC 972 (Waypoint) explicitly names its populations: "those living with mental
illness, addiction and older adults with complex needs."

Among Community — Large hospitals, FAC 982 (Blanche River Health) states that
"the system should work for people rather than people navigating the system" — a
philosophical stance that inverts the standard patient-centred care framing in a
memorable and distinctive way. FAC 632 (North York General) claims "global impact"
as an aspiration, which is an unusually ambitious scope for a community hospital.

**RES — Research & Academic (16 distinctive directions)**

RES produces the most concentrated distinctive directions in a single hospital.
Sinai Health (FAC 976) generates four distinctive Teaching × RES directions in a
single plan: global scientific leadership positioning, commitment to a new research
facility, creation of a formal "Sinai Health Research" enterprise, and a cultural
transformation direction to make research integral to organizational identity.
Taken together, these directions constitute a qualitatively different type of
research strategy — more structured, more institutionally ambitious, and more
explicitly organized than peer Teaching hospitals.

SickKids (FAC 837) commits to "advancing the era of Precision Child Health" —
positioning the hospital as a leader of a specific research paradigm rather than
simply conducting research. FAC 790 (Hotel Dieu St. Catharines) targets rehabilitation
research specifically, which is a narrow specialty focus uncommon among Specialty
peers. FAC 948 (CAMH) explicitly integrates patient and family involvement in the
research and discovery process, which is distinctive for a mental health specialty
context.

Among Community — Large hospitals, FAC 606 (Barrie RVH) explicitly commits to
becoming a "regional academic health sciences centre" and "full-scale teaching
hospital and research institute." This is the most ambitious repositioning claim
by any non-Teaching hospital in the dataset — a community hospital explicitly
stating an aspiration to become a Teaching hospital equivalent.

**INN — Innovation & Digital Health (9 distinctive directions)**

The most distinctive INN directions use specific, committal language rather than
generic digital transformation vocabulary. FAC 736 (Southlake Regional) produces
two distinctive directions: "data is the most important strategic asset we have
after people" and "Digital health is health" — both philosophical positioning
statements that go beyond standard innovation language. FAC 701 (Mackenzie Health)
claims leadership in digital health and specifically names AI and smart technologies.
FAC 606 (Barrie RVH) emphasizes technology that is "not just smarter, but also
kinder" — an emotional framing for digital health that is unusual in the dataset.

Among Specialty hospitals, SickKids links its innovation strategy explicitly to
"Project Horizon" campus redevelopment, which creates a physical-digital integration
narrative specific to that institution. FAC 932 (Bruyère Hospital) frames digital
innovation as enabling its specific Academic Health Sciences Centre role.

**PAR — Partnerships & Community (15 distinctive directions)**

Distinctive PAR directions are typically those that specify the nature or depth of
the partnership rather than using generic collaboration language. FAC 968
(Muskoka Algonquin Healthcare) references the "Made-in-Muskoka Healthcare model"
by name — a locally specific framing that is the most geographically distinctive
partnership direction in the dataset. FAC 793 (St. Thomas Elgin General) commits
to "co-designing services" rather than just collaborating. FAC 858 (Michael Garron
Toronto East General) positions itself as a "leader" in integrated care rather than
a participant. FAC 781 (Thunder Bay St. Joseph's) explicitly commits to regional
leadership in specialized care delivery, which is specific to its geographic role.

**FIN — Financial Sustainability (5 distinctive directions)**

The most notable FIN finding is the emergence of environmental sustainability as
a paired strategic commitment. Three Community — Large hospitals (FAC 736 Southlake,
FAC 763 Pembroke, and implicitly FAC 606 Barrie) explicitly link financial
sustainability with environmental stewardship in the same direction. SickKids (FAC 837)
frames financial sustainability around "safeguarding the future of children" —
connecting fiscal health to its core pediatric mission. FAC 611 (Blind River) uses
the metaphor "making sure our tank is full so we can continue to serve our
communities" — colloquial language that is distinctive in a strategic planning context.

**Language as identity — francophone hospitals**

Two directions are written entirely in French: FAC 978 (Kingston Health Sciences,
formerly Hotel Dieu Kingston) has both a RES direction and a WRK direction in
French, reflecting its francophone mandate. These are structurally distinctive in
the dataset regardless of content — the language itself signals a specific
institutional identity and community commitment not shared by other hospitals
in the cohort.

---

## Cross-Part Synthesis

Several hospitals appear as notable in both Part 1 (theme-level) and Part 2
(direction-level) analyses, reinforcing their distinctiveness from two independent
vantage points:

**Sinai Health (FAC 976)** is the strongest overall outlier. At the theme level,
its plan is missing four of five Teaching core themes. At the direction level, it
produces four distinctive RES directions organized around a coherent research
enterprise vision. The two findings are consistent: Sinai is a research institution
with clinical operations, and its strategy reflects that identity more than it
reflects the Teaching hospital template.

**CAMH (FAC 948)** is distinctively organized at the theme level (missing WRK,
PAT, FIN) and produces a distinctive RES direction that integrates patient and
family involvement in research. Its plan is organized around its mental health
mandate in a way that is coherent but does not map to general hospital strategic
norms.

**Baycrest (FAC 827)** is unremarkable at the theme level (missing RES only) but
produces two of the most content-specific PAT directions in the Specialty group,
naming dementia care and geriatric care explicitly. Its distinctiveness is in the
direction text, not the theme portfolio.

**Barrie RVH (FAC 606)** does not appear as a theme-level outlier — its portfolio
conforms to Community — Large norms — but produces distinctive directions across
PAT, RES, INN, and WRK. Its RES direction's explicit aspiration to become an
academic health sciences centre is the most ambitious repositioning claim by any
community hospital in the dataset. Its distinctiveness is entirely in the direction
text.

**The northern and Indigenous-serving hospitals** (Sioux Lookout FAC 964, Manitoulin
FAC 784) appear in both parts: peripheral theme adopters at the theme level, with
direction text that names culturally safe care, mental health and addictions, and
population health strategies specific to their communities. Their distinctiveness
is coherent — it reflects real differences in the populations they serve, not random
strategic choices.

---

## Interpretive Limits

**Linguistic distinctiveness ≠ strategic uniqueness.** The Part 2 analysis identifies
directions that use more specific, committal, or unusual language than peers. This
does not mean the underlying strategy is genuinely different. A hospital that labels
its infrastructure investment "Campus Transformation" and names an Ontario Government
funding source is more specific than one that writes "invest in our facilities" —
but both are investing in facilities. The direction text captures ambition and
specificity of articulation; it does not capture whether the hospital actually
executes differently.

**Shared plans inflate within-group similarity.** Several hospital pairs share a
single strategic plan (FAC 813/983 Stratford-Huron Perth, FAC 597/626 Almonte-
Carleton Place, FAC 593/824 Four Counties-Tillsonburg). These pairs will appear
as near-identical at both the theme and direction level. The "Nothing for you,
without you" shared language between Stratford and Huron Perth is a plan-sharing
artefact, not evidence of independent strategic convergence.

**The classification boundary affects Part 1 interpretation.** As noted in the
Data and Method section, some PAT-missing flags reflect plan architecture rather
than genuine deprioritization. The outlier scores for several Community — Small
hospitals should be interpreted with this caveat in mind.

**Part 2 coverage is not complete.** Two cells (Teaching × WRK, Community — Large
× FIN and INF) failed in this run due to API rate limits. Their results from a
prior run are available but not incorporated into the 89-direction table used here.
The qualitative findings from those cells — particularly the Teaching × WRK cell —
are noted where relevant from the prior run's output.

---

## Implications for Future Analysis

**Sinai Health, CAMH, and Baycrest warrant case-study treatment** in any publication
using this dataset. They are the clearest examples of hospitals whose strategic
plans reflect a genuinely distinct institutional identity rather than adherence to
the sector template. Their distinctiveness is analytically defensible from two
independent lenses.

**Barrie RVH's repositioning claim** (aspiring to academic health sciences centre
status) is the most analytically interesting community hospital direction in the
dataset. If this aspiration is pursued, it would represent a structural shift in
how a Community — Large hospital defines its mandate. It warrants monitoring in
future plan cycles.

**The financial-environmental integration pattern** (three Community — Large
hospitals linking FIN and environmental sustainability) is a nascent trend not
captured by the 03b/03c temporal analyses. It appeared only in Current era plans
and may signal an emerging strategic norm.

**The francophone and Indigenous-serving hospital directions** are the clearest
examples of population-mandate alignment in the dataset — hospitals whose written
directions directly reflect the specific communities they serve. This is an
analytically important category for any work on health equity and strategic planning.

---

## Outputs

| File | Description |
|------|-------------|
| `analysis/outputs/tables/04b_theme_outliers.csv` | Hospital-level outlier flags, scores, and missing/peripheral theme detail (both scopes) |
| `analysis/outputs/tables/04b_peripheral_adopters.csv` | Hospital-level peripheral theme adoption detail (both scopes) |
| `analysis/outputs/tables/04b_distinctive_directions.csv` | 89 distinctive directions with FAC, hospital name, type group, theme, direction text, and API reason |
| `analysis/outputs/figures/04b_outlier_map.png` | Scatter plot: missing core (y) vs peripheral adopted (x), coloured by type group, faceted by scope |
| `logs/04b_api_log.csv` | API call log: cell, status, n distinctive, tokens, cost |
