# Unique and Outlier Strategies in Ontario Hospital Strategic Plans
## Ontario Public Hospitals — Outlier and Distinctiveness Analysis
*HospitalIntelligenceR | Analysis 04b | April 2026*

---

## Overview

Analysis 04a established that Ontario hospital strategic plans occupy a moderate
homogeneity band: similar enough to suggest shared institutional pressures,
different enough that no single template describes the sector. This analysis
identifies where the differentiation lives — which hospitals deviate from their
type group's consensus, and which strategic directions, as written by hospitals
themselves, are genuinely unusual relative to peers addressing the same theme.

Two analytical parts address this:

**Part 1 — Theme-level outlier identification (pure R):** Using the type-group
core profiles established in 04a, hospitals are flagged for three types of
deviation: missing one or more core themes for their type group, adopting themes
that fewer than 25% of their peers include (peripheral adoption), or lacking
both of the sector-wide core themes (WRK and PAT).

**Part 2 — Direction-level distinctiveness (Claude API):** Within each theme ×
hospital type cell, the direction names and descriptions as written by hospitals
are submitted to the Claude API. The API identifies which directions use generic
sector language and which are unusual, specific, or distinctive relative to peers
in the same cell.

**A critical distinction runs through both parts.** Part 1 operates entirely at
the **theme level** — on the standardized primary theme classifications assigned
by this project, not on the hospitals' own words. Part 2 operates at the
**direction level** — on the text hospitals actually wrote. A hospital that
appears unremarkable at the theme level may have written directions that are
linguistically or substantively distinctive, and vice versa. Both levels are
necessary to answer the uniqueness question fully.

---

## Data and Method

**Cohort:** 68 Ontario public hospitals in the Current era (plan start 2024–2026),
producing 331 usable classified directions across 28 eligible theme × type cells.
This is the primary analysis population. Part 1 also produces full-cohort (n=122)
results as a reference scope.

**Directions and themes:** Strategic directions are the named priorities, pillars,
or goals in each hospital's plan — written by the hospital in its own language.
Themes (WRK, PAT, PAR, etc.) are the standardized primary theme classifications
assigned by this project in Analysis 02. Part 1 works with themes; Part 2 works
with directions.

**Outlier scoring (Part 1):** Each hospital receives a composite outlier score:
one point per missing core theme, one point per peripheral theme adopted, and
three additional points for lacking both sector-wide core themes (WRK and PAT).
Higher scores indicate greater deviation from the type-group consensus.

**Peripheral theme threshold:** A theme is considered peripheral for a type group
if fewer than 25% of hospitals in that group include it as a primary theme.
Peripheral adoption signals a discretionary strategic choice — the hospital is
addressing something most of its peers are not.

**Part 2 API approach:** For each theme × type cell with five or more directions,
a single Claude API call receives the full list of direction names and descriptions
for that cell and identifies generic versus distinctive directions. All 28 eligible
cells were successfully processed in a clean environment. Temperature was set to
0 for deterministic output. Total cost: $0.21 USD.

**Classification boundary caveat:** Some hospitals are classified as missing PAT
(Patient Care & Quality) because their plans distribute patient care content
across multiple directions rather than naming it as a standalone strategic
priority. This is a plan structure choice, not evidence of genuine deprioritization.
It is most common among hospitals with compact 3–4 direction plans. Where plan
architecture is the plausible explanation for a missing core theme, it is noted
in the findings below.

---

## Part 1: Theme-Level Outliers

### Missing core themes

Most hospitals in every type group are missing at least one core theme for their
type in the Current era:

| Type | n | Missing ≥1 core theme | % |
|------|---|----------------------|---|
| Teaching | 10 | 8 | 80% |
| Community — Large | 21 | 12 | 57% |
| Community — Small | 27 | 16 | 59% |
| Specialty | 10 | 7 | 70% |

These rates are high enough to indicate that missing a core theme is not itself
a strong outlier signal — it describes the majority experience in most groups.
The more meaningful question is how many core themes are missing and which ones.
A hospital missing only INN (a newly entered Community — Large core theme) is
substantively different from one missing WRK, PAT, and PAR simultaneously.

**The INN effect in Community — Large.** Seven of the twelve Community — Large
hospitals missing a core theme are missing INN only. INN entered the Community —
Large core profile only in the Current era, meaning it crossed the 50% threshold
recently. These hospitals are not strategic laggards — they are simply earlier in
adoption of a theme that has recently become consensus. This should not be treated
as meaningful outlier behaviour.

**The PAT missing-core pattern — plan architecture, not deprioritization.** A
substantial number of Current era hospitals are classified as missing PAT.
Spot-checking confirms that for most, patient care content exists throughout their
plans but is embedded within other direction types rather than named as a
standalone priority. This is most common among hospitals with compact 3–4
direction structures. The hospitals genuinely missing PAT-equivalent content are
likely fewer than the raw count suggests.

**The most credible theme-level outliers** are those with high composite scores
driven by multiple missing core themes across different theme categories, not
solely the INN or PAT effects:

| FAC | Hospital | Type | Score | Missing | Peripheral |
|-----|----------|------|-------|---------|------------|
| 611 | Blind River North Shore HN | Comm — Small | 8 | WRK, PAT, PAR | EDI, ORG |
| 592 | Napanee Lennox & Addington | Comm — Small | 7 | WRK, PAR, FIN | EDI |
| 948 | Toronto CAMH | Specialty | 7 | WRK, PAT, FIN | EDI |
| 862 | Toronto Women's College | Teaching | 6 | WRK, PAT, PAR | — |
| 947 | Toronto UHN | Teaching | 6 | WRK, EDI | INF |
| 961 | Ottawa Heart Institute | Teaching | 6 | WRK, PAR, EDI | — |
| 624 | Campbellford Memorial | Comm — Small | 6 | PAT, PAR, FIN | — |
| 739 | Nipigon District Memorial | Comm — Small | 6 | PAT, PAR, FIN | — |

**Blind River North Shore HN (FAC 611)** is the strongest theme-level outlier in
the dataset with a score of 8 — missing all three of the sector-wide and Community
— Small core themes (WRK, PAT, PAR) while adopting both EDI and ORG as peripheral
themes. The ORG adoption (organizational culture and identity) alongside missing
WRK and PAR suggests a hospital in an active period of internal repositioning.
The plan architecture caveat applies: with a compact plan structure, some of this
may reflect direction design rather than genuine strategic absence.

**CAMH (FAC 948)** is the most structurally distinctive Specialty hospital.
Missing WRK, PAT, and FIN while adopting EDI as a peripheral theme, its plan
is organized around its mental health and addictions mandate in a way that does
not map cleanly to the general Specialty hospital taxonomy. This is expected
given CAMH's highly specialized scope — it is not a general acute hospital and
its strategic priorities reflect that difference. The EDI peripheral adoption is
consistent with CAMH's emphasis on health equity in mental health service
delivery.

**Women's College Hospital (FAC 862)** is distinctive at the Teaching level —
missing WRK, PAT, and PAR with a score of 6. Its plan is organized around its
mandate as an ambulatory care and health equity institution rather than a
general Teaching hospital template. Part 2 confirms this: its most distinctive
directions are in EDI ("Move the Needle on Health Equity") and RES ("Lead the
New Era of Sex and Gender in Health"), both reflecting its specific institutional
identity rather than general Teaching hospital norms.

**Ottawa Heart Institute (FAC 961)** is a Teaching hospital organized entirely
around its cardiac specialty mandate. Missing WRK, PAR, and EDI, its theme
profile reflects a single-specialty focus unusual among Teaching peers. Part 2
confirms this — its distinctive directions in PAT, RES, and ACC all explicitly
name cardiac care and the Heart Institute's specialized role.

**The remote and northern Community — Small hospitals** (FAC 784 Manitoulin,
FAC 964 Sioux Lookout, FAC 592 Napanee, FAC 611 Blind River) cluster as outliers
for contextually coherent reasons. Sioux Lookout and Manitoulin adopt INN and EDI
as peripheral themes — unusual for Community — Small hospitals — in ways that
reflect their Indigenous-serving mandates. Napanee and Blind River show high
missing-core scores partly due to compact plan structures and partly due to
genuine focus differences. These are not random outliers; they reflect specific
community contexts.

### Peripheral theme adopters

Forty-three percent of Current era Community — Large hospitals and 40% of Specialty
hospitals adopt at least one peripheral theme. The most analytically interesting
peripheral adoptions:

**ACC (Access & Care Delivery) in Community — Large:** Five Community — Large
hospitals include ACC as a peripheral theme. ACC is a core theme for Specialty
hospitals but not for Community — Large, suggesting some larger community hospitals
are taking on an access mandate — particularly regional referral and tertiary
service expansion — more typical of specialized peers. FAC 701 (Mackenzie Health)
and FAC 771 (Peterborough Regional) both include explicit regional access
commitments.

**EDI (Equity, Diversity & Inclusion) in Community — Small:** Four Community —
Small hospitals adopt EDI peripherally. In the majority of cases the adoption is
geographically motivated — hospitals serving populations where equity and cultural
safety are operationally relevant in ways that differ from the sector average.

**ORG (Organizational Culture) in Community — Large and Community — Small:**
Multiple hospitals across both groups adopt ORG peripherally. ORG is the lowest-
prevalence theme across the dataset. Its appearance as a peripheral adoption
consistently signals explicit organizational identity work — hospitals that are
in periods of internal renewal, restructuring, or repositioning.

### Sector core (WRK + PAT) absence

Twenty-nine percent of Current era hospitals (20 of 68) are missing at least one
of WRK or PAT — the two universal sector-core themes. This figure requires
interpretation in light of the plan architecture caveat: for many of these
hospitals, particularly those with compact 3–4 direction plans, patient care or
workforce content is present but not structured as a named standalone direction.
The hospitals genuinely absent from both WRK and PAT primary themes (FAC 611
Blind River, FAC 862 Women's College, FAC 948 CAMH) are the most credible
cases of genuine deviation from the sector floor.

---

## Part 2: Direction-Level Distinctiveness

### Coverage and approach

All 28 eligible theme × type cells were successfully processed, covering 109
distinctive directions identified from 331 total current-era directions. The API
evaluated directions as written by hospitals — their own words, labels, and
descriptions — and flagged those that deviate from the generic sector language
typical of each cell.

An important methodological note: the API flags linguistic or substantive
specificity as the marker of distinctiveness. A direction that names a specific
population, geography, program, or commitment is flagged; one that uses standard
sector vocabulary ("improve patient experience," "foster a culture of excellence")
is not. Linguistic distinctiveness does not always mean strategic uniqueness —
a hospital that names its capital project is more specific, but the underlying
strategy may be identical to peers. The directions flagged here are more specific
than average, not necessarily more strategically ambitious.

### Sector-wide patterns in generic directions

Across all cells, the API consistently identified a set of generic direction
archetypes — directions that could appear in virtually any Ontario hospital plan:

- WRK: "Invest in our people," "Foster a culture of excellence," "Attract and
  retain talented staff"
- PAT: "Deliver exceptional patient-centred care," "Improve the patient
  experience," "Advance quality and safety"
- PAR: "Build strong partnerships," "Advance integrated care," "Collaborate with
  community partners"
- FIN: "Ensure financial sustainability," "Strengthen our fiscal foundation,"
  "Steward our resources responsibly"

These directions are generic not because they are wrong but because they commit
to nothing specific. They are the strategic equivalent of a mission statement —
broadly true, universally applicable, and analytically interchangeable across
hospitals.

### Notable distinctive directions by theme

**WRK — Workforce & People (16 distinctive directions)**

The most common basis for a distinctive WRK direction is a specific philosophical
or cultural commitment rather than a generic workforce statement. Two hospitals —
FAC 813 (Stratford General) and FAC 983 (Huron Perth Healthcare Alliance) — use
the identical phrase "Nothing for you, without you" as an organizing principle.
These hospitals share a plan, which the API correctly identified without being
told. FAC 709 (Listowel Memorial) commits explicitly to "a culture of kindness,"
which is specific cultural language not found in peer plans. FAC 942 (Hamilton
Health Sciences) aspires to become the "top Canadian hospital to build an
impactful career" — an unusually competitive workforce positioning statement.
FAC 753 (Ottawa Montfort) frames its workforce strategy as competitive
positioning against the healthcare labour shortage, explicitly naming the
external context driving the direction.

**PAT — Patient Care & Quality (20 distinctive directions)**

The most distinctive PAT directions commit to a specific improvement mechanism
or name a specific population. FAC 592 (Napanee) commits to annually identifying
1–2 specific areas or units requiring quality improvement transformation — unusual
operational specificity for a strategic direction. FAC 784 (Manitoulin) explicitly
names "culturally safe healthcare" in its patient experience direction, which is
substantively distinctive for a hospital serving Indigenous communities. FAC 827
(Baycrest) names "World-Class Dementia Care" — both the population specificity
and the ambition level are unusual. FAC 972 (Waypoint) explicitly names its
populations: "those living with mental illness, addiction and older adults with
complex needs."

Among Community — Large hospitals, FAC 982 (Blanche River Health) states that
"the system should work for people rather than people navigating the system" — a
philosophical stance that inverts the standard patient-centred framing. FAC 632
(North York General) claims "global impact" as a community hospital aspiration,
which is an unusually ambitious scope.

**RES — Research & Academic (13 distinctive directions)**

The most distinctive RES finding at the Community — Large level is FAC 606
(Barrie RVH), which explicitly commits to becoming a "regional academic health
sciences centre" and "full-scale teaching hospital and research institute." This
is the most ambitious repositioning claim by any non-Teaching hospital in the
dataset — a community hospital explicitly stating an aspiration to become a
Teaching hospital equivalent in research and academic mission.

Among Teaching hospitals, FAC 862 (Women's College) produces the most
substantively specific RES direction: "Lead the New Era of Sex and Gender in
Health" — a narrowly defined research niche that is not addressed by any other
Teaching hospital in the dataset. FAC 953 (Sunnybrook) commits to "Personalized
& Precise Treatments" using precision medicine approaches. FAC 961 (Ottawa Heart
Institute) frames its research direction entirely around cardiac-specific
breakthroughs, reflecting its single-specialty mandate.

Among Specialty hospitals, FAC 837 (SickKids) commits to "advancing the era of
Precision Child Health" — positioning the hospital as a leader of a specific
healthcare movement rather than simply conducting research. FAC 948 (CAMH)
explicitly integrates patient and family involvement in the research and
discovery process, which is distinctive for a mental health specialty context.

**INN — Innovation & Digital Health (11 distinctive directions)**

The most distinctive INN directions use specific, committal language rather than
generic digital transformation vocabulary. FAC 736 (Southlake Regional) produces
two distinctive directions: "data is the most important strategic asset we have
after people" and "Digital health is health" — philosophical positioning
statements that go beyond standard innovation language. FAC 701 (Mackenzie
Health) explicitly positions itself as "a leader in digital health" and commits
to "world-class" outcomes. FAC 606 (Barrie RVH) emphasizes technology that is
"not just smarter, but also kinder" — an emotional framing for digital health
that is unusual in the dataset.

Among Specialty hospitals, SickKids links its innovation strategy explicitly to
"Project Horizon" campus redevelopment, creating a physical-digital integration
narrative specific to that institution. FAC 932 (Bruyère Hospital) frames digital
innovation as enabling its specific Academic Health Sciences Centre role.

**PAR — Partnerships & Community (18 distinctive directions)**

Distinctive PAR directions typically specify the nature or depth of partnership
rather than using generic collaboration language. FAC 968 (Muskoka Algonquin
Healthcare) references the "Made-in-Muskoka Healthcare model" by name — the
most geographically distinctive partnership direction in the dataset. FAC 793
(St. Thomas Elgin General) commits to "co-designing services" rather than simply
collaborating. FAC 858 (Michael Garron Toronto East General) positions itself as
a "leader" in integrated care rather than a participant. FAC 947 (UHN) positions
itself as a "powerful solutions partner" with an explicit advocacy role — an
unusual framing for hospital partnerships that extends beyond the care delivery
mandate.

**FIN — Financial Sustainability (9 distinctive directions)**

The most notable FIN finding is the emergence of environmental sustainability
as a paired strategic commitment. Three Community — Large hospitals (FAC 736
Southlake, FAC 763 Pembroke, FAC 606 Barrie) explicitly link financial
sustainability with environmental stewardship in the same direction. SickKids
(FAC 837) frames financial sustainability around "safeguarding the future of
children" — connecting fiscal health to its core pediatric mission. FAC 611
(Blind River) uses the metaphor "making sure our tank is full so we can continue
to serve our communities" — colloquial language that is distinctive in a
strategic planning context.

**ACC — Access & Care Delivery (10 distinctive directions)**

Among Teaching hospitals, FAC 753 (Ottawa Montfort) produces two distinctive ACC
directions: an explicit commitment to expanding French-language services, and a
specific proactive approach to serving a growing and aging population. Both
reflect Montfort's francophone mandate in ways that are not replicated by any
other Teaching hospital. FAC 961 (Ottawa Heart Institute) commits to extending
specialized cardiac care into community settings — distinctive for a specialty-
focused Teaching hospital.

Among Community — Small hospitals, FAC 624 (Campbellford Memorial) explicitly
commits to "setting a new standard for rural care delivery outside the traditional
hospital setting." FAC 964 (Sioux Lookout) names "Mental Health & Addictions" as
an ACC direction — unusual specificity for a small community hospital and
reflective of its northern Indigenous-serving context.

**EDI — Equity, Diversity & Inclusion (3 distinctive directions)**

FAC 862 (Women's College) uses "Move the Needle on Health Equity" — action-
oriented language with an implied measurability commitment uncommon in EDI
directions. FAC 959 (Health Sciences North) frames equity through "social
accountability" and explicitly names creating an environment "free of racism,
discrimination, and all forms of bias." FAC 753 (Ottawa Montfort) also frames
EDI through social accountability, consistent with its francophone institutional
identity.

**Language as identity — francophone hospitals**

Ottawa Montfort (FAC 753) produces distinctive directions across five themes
(ACC, EDI, PAR, RES, WRK) — the broadest multi-theme distinctive footprint of
any hospital in the dataset. Its distinctiveness is coherent: the French-language
mandate, the social accountability framing, and the specific demographic context
of Ottawa's francophone population appear consistently across its directions.
This is not random linguistic variation — it reflects genuine institutional
identity that maps clearly onto a specific community mandate.

---

## Cross-Part Synthesis

Several hospitals appear as notable in both Part 1 (theme-level) and Part 2
(direction-level) analyses, reinforcing their distinctiveness from two independent
vantage points:

**CAMH (FAC 948)** is the most structurally distinctive Specialty hospital at
the theme level (missing WRK, PAT, and FIN; adopting EDI peripherally) and
produces a distinctive RES direction that explicitly integrates patient and
family involvement in research. Its plan is organized around its mental health
mandate in a way that does not map to general hospital strategic norms at either
the theme or the direction level.

**Women's College Hospital (FAC 862)** is a high-scoring theme-level outlier
(missing WRK, PAT, PAR) and produces distinctive directions in EDI and RES that
directly reflect its ambulatory care and health equity mandate. Its two most
distinctive directions — "Move the Needle on Health Equity" and "Lead the New
Era of Sex and Gender in Health" — articulate a specific institutional identity
that is not replicated by any other Teaching hospital.

**Ottawa Heart Institute (FAC 961)** is a theme-level outlier (missing WRK, PAR,
EDI) and produces distinctive directions in PAT, ACC, and RES that name cardiac
care explicitly. The two findings are consistent: it is a single-specialty
Teaching hospital whose strategic plan reflects that specialization rather than
the general Teaching hospital template.

**Ottawa Montfort (FAC 753)** does not appear as a high-scoring theme-level
outlier (score of 5, missing PAT and PAR) but produces distinctive directions
across five themes. Its distinctiveness is concentrated in the direction text
rather than the theme portfolio. Montfort's plan is not unusual in what themes
it addresses — it is unusual in how it addresses them, with consistent
francophone and social accountability framing throughout.

**Barrie RVH (FAC 606)** does not appear as a theme-level outlier — its portfolio
conforms to Community — Large norms — but produces distinctive directions across
five themes (PAT, RES, INN, WRK, FIN). Its RES direction's explicit aspiration
to become an academic health sciences centre is the most ambitious repositioning
claim by any community hospital in the dataset. Its distinctiveness is entirely
at the direction level, not the theme level.

**Blind River North Shore HN (FAC 611)** is the highest-scoring theme-level
outlier (score 8) but produces only two distinctive Part 2 directions (FIN:
"Making sure our tank is full"; ORG: "CLARIFY" — an organizational identity
clarification direction). Its outlier status is primarily structural — it reflects
a compact plan with an unusual theme portfolio — rather than linguistically
distinctive writing.

**The northern and Indigenous-serving hospitals** (Sioux Lookout FAC 964,
Manitoulin FAC 784) appear in both parts: peripheral theme adopters at the theme
level, with direction text that names culturally safe care, mental health and
addictions, and population health strategies specific to their communities. Their
distinctiveness is coherent — it reflects real differences in the populations
they serve, not random strategic choices.

---

## Interpretive Limits

**Linguistic distinctiveness ≠ strategic uniqueness.** The Part 2 analysis
identifies directions that use more specific, committal, or unusual language than
peers. This does not mean the underlying strategy is genuinely different. A
hospital that labels its infrastructure investment "Campus Transformation" and
names an Ontario Government funding source is more specific than one that writes
"invest in our facilities" — but both are investing in facilities. The direction
text captures ambition and specificity of articulation; it does not capture
whether the hospital actually executes differently.

**Shared plans inflate within-group similarity.** Several hospital pairs share a
single strategic plan (FAC 813/983 Stratford-Huron Perth, FAC 597/626 Almonte-
Carleton Place, FAC 593/824 Four Counties-Tillsonburg). These pairs appear
near-identical at both the theme and direction level. The "Nothing for you,
without you" shared language between Stratford and Huron Perth is a plan-sharing
artefact, not evidence of independent strategic convergence.

**The classification boundary affects Part 1 interpretation.** As noted in the
Data and Method section, some PAT-missing flags reflect plan architecture rather
than genuine deprioritization. The outlier scores for several Community — Small
hospitals with compact plan structures should be interpreted with this caveat.

**A note on FAC 976 Sinai Health System.** A prior version of this analysis
incorrectly identified Sinai as the strongest theme-level outlier, based on a
stale extraction that had classified 9 research strategy directions from an
incorrect source document. Following re-extraction from the correct current
strategic plan and re-classification, Sinai's profile is (PAT, WRK, FIN, RES)
— a conformist Teaching hospital plan covering all four full-cohort Teaching core
themes. Sinai does not appear as a theme-level outlier in the correct data and
produces one direction-level distinctive direction in the PAR theme. This
correction materially changes the outlier narrative; the current document reflects
the corrected data.

---

## Implications for Future Analysis

**CAMH, Women's College, and Ottawa Heart Institute** warrant case-study treatment
in any publication using this dataset. They are the clearest examples of Teaching
and Specialty hospitals whose strategic plans reflect a genuinely distinct
institutional identity rather than adherence to the sector template. Their
distinctiveness is analytically defensible from two independent lenses.

**Barrie RVH's academic repositioning claim** is the most analytically interesting
community hospital direction in the dataset. If this aspiration is pursued, it
would represent a structural shift in how a Community — Large hospital defines
its mandate. It warrants monitoring in future plan cycles.

**The financial-environmental integration pattern** (three Community — Large
hospitals linking FIN and environmental stewardship) is a nascent trend not
captured by the 03b/03c temporal analyses. It appeared only in Current era plans
and may signal an emerging strategic norm.

**Ottawa Montfort's francophone distinctiveness** and the northern and
Indigenous-serving hospitals' population-mandate alignment are the clearest
examples in the dataset of hospitals whose written directions directly reflect
the specific communities they serve. This is an analytically important category
for any work on health equity and strategic planning.

---

## Outputs

| File | Description |
|------|-------------|
| `analysis/outputs/tables/04b_theme_outliers.csv` | Hospital-level outlier flags, scores, and missing/peripheral theme detail (both scopes) |
| `analysis/outputs/tables/04b_peripheral_adopters.csv` | Hospital-level peripheral theme adoption detail (both scopes) |
| `analysis/outputs/tables/04b_distinctive_directions.csv` | 109 distinctive directions with FAC, hospital name, type group, theme, direction text, and API reason |
| `analysis/outputs/figures/04b_outlier_map.png` | Scatter plot: missing core (y) vs peripheral adopted (x), coloured by type group, faceted by scope |
| `logs/04b_api_log.csv` | API call log: cell, status, n distinctive, tokens, cost |
