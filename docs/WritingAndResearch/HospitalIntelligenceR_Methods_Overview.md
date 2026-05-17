# HospitalIntelligenceR — Project Methods Overview
*May 2026*

---

## Purpose

Ontario's public hospitals operate in one of Canada's most data-rich provincial
health systems. The Ministry of Health publishes annual financial and operational
data for every hospital. Hospitals publish strategic plans, board minutes, and
leadership rosters on their public websites. The Canadian Institute for Health
Information publishes hospital-level quality indicators annually. None of this
data is difficult to find. What has been difficult is collecting it systematically,
at scale, and in a form that allows the kind of cross-hospital, cross-year
comparisons that would make it genuinely useful for research or operational
intelligence.

HospitalIntelligenceR was built to close that gap. It is an R-based data
platform that systematically collects, extracts, classifies, and analyzes
publicly available data from all Ontario public hospitals. The goal is to answer
questions that no single hospital can answer from its own data — questions about
how strategic priorities vary across the sector, whether specific emphases are
associated with better outcomes, and what the sector as a whole looks like at
a given moment. The platform is designed equally for research publication and
for practical intelligence: identifying hospitals with specific strategic
profiles, leadership changes, or performance trajectories of interest.

This document describes the methods underlying the platform — how hospitals are
identified, how data is collected, what roles the platform operates, and how the
analytical layer works.

---

## The Hospital Registry

Every component of the platform is anchored to a single registry file:
`hospital_registry.yaml`. This file contains one entry per Ontario public
hospital and serves as the single source of truth for hospital metadata,
web addresses, and per-role extraction status throughout the project.

The registry currently covers 130 active hospitals, identified by their
Ministry of Health Facility (FAC) code. The FAC code is the primary key
throughout — every data source, every output, and every join is keyed to FAC.
Using the provincial facility code rather than hospital names eliminates the
name-matching problem that plagues any multi-source hospital dataset: names
change, abbreviations vary, and amalgamated entities appear under different
names in different systems. The FAC code is stable.

Hospital types in the registry follow the Ministry of Health classification:
Teaching Hospitals, Community — Large, Community — Small, Specialty, and
a small number of continuing care and psychiatric facilities. After registry
cleaning and the exclusion of three retired FAC codes from pre-merger entities,
the analytical cohort used in current work comprises 17 Teaching hospitals,
43 Community — Large, 48 Community — Small, and 11 Specialty hospitals — 119
hospitals in total for analyses requiring type-group stratification.

The registry is managed through a dedicated R module (`core/registry.R`) and
maintained in YAML format specifically because YAML is human-readable, git-diffable,
and safely editable outside of R. Every time an extraction runs, the registry is
updated to record the outcome — the document found, the date of extraction, the
quality assessment, and the status code. This makes the registry both a metadata
store and an operational log.

---

## Data Collection Architecture

The platform follows a consistent two-phase pattern across all scraping roles.

**Phase 1 — Locate and collect.** A crawler visits each hospital's website,
respects `robots.txt` restrictions, applies rate limiting to avoid server
overload, and downloads the target document — most commonly a PDF, occasionally
HTML. The crawler uses keyword-scored link extraction: rather than following all
links on a page, it scores links by their likely relevance to the target document
type and follows only the most promising candidates. Documents are saved locally
under a FAC-keyed folder structure with version-safe filenames that preserve
earlier versions when a hospital updates its documents.

Hospitals whose websites block automated access via `robots.txt` are excluded
from automated collection and flagged in the registry. Approximately 2–3% of
hospitals in the current registry carry this exclusion. For a small number of
hospitals where automated collection fails but a document is publicly available,
tool-assisted manual capture (PDF download, browser save) is used as a fallback.
Pure manual transcription is not used anywhere in the platform.

**Phase 2 — Extract and structure.** Each downloaded document is submitted to
the Claude API, which reads the content and returns structured JSON. The API
prompt specifies exactly what to extract and enforces verbatim text capture — no
paraphrasing, no condensing, no inference. The extracted data is written to a
per-hospital output file and then merged into a role-level master CSV in long-format
tidy structure, with one row per unit of content (one row per strategic direction,
one row per board member, one row per executive).

PDFs present a particular technical challenge: some PDFs have broken embedded
fonts that produce unreadable character sequences when parsed as text. The
platform detects these cases automatically using a character usability threshold
and routes affected documents to image-mode processing, where the Claude API
reads the document as a rendered image rather than extracted text. A per-hospital
`force_image_mode` flag in the registry allows this override to be set manually
for known problem documents.

---

## Data Collection Roles

The platform is organised into five extraction roles, each targeting a distinct
document type from hospital websites, plus two imported data sources that
require no scraping.

**Strategic Plans (annual).** The strategy role extracts each hospital's current
strategic plan — the plan period dates, the named strategic directions or pillars,
descriptive text for each direction, and key actions or initiatives where available.
This is the most analytically mature role: 129 hospitals have been processed,
producing 576 extracted directions. The extraction enforces exact text from the
plan — the hospital's own words, not a classification or summary. A separate
classification pass (described below) then assigns thematic codes to each direction.
Plans vary considerably in their structure and depth: some hospitals publish
detailed multi-page strategy documents with extensive action plans under each
direction; others publish a single page naming four pillars with a brief descriptor.
The extraction captures what is there.

**Foundational Documents (annual).** This role targets each hospital's foundational
guiding documents — Vision, Mission, Values, and any equivalents such as Purpose,
Principles, or Commitments. Hospitals use widely varying terminology and structures
for these elements, so the extraction is designed to capture the label as used by
the hospital rather than assuming a standard three-element structure. This role
has not yet been built; it is the next role in the development sequence.

**Executive Team (monthly).** This role extracts current executive team membership
from hospital leadership pages — names, titles, and organizational roles. Executive
teams change more frequently than strategic plans, which drives the monthly cadence.
CEO, CNO, and COS appear on both executive and board lists in many hospitals as
ex-officio members; both roles capture them independently. This role has not yet
been built.

**Board of Directors (semi-annual).** This role extracts current board membership
from hospital governance pages — Chair, Vice Chair, and directors. Ontario hospital
board elections follow a September cycle, driving a semi-annual update cadence.
This role has not yet been built.

**Board Meeting Minutes (monthly).** This role downloads and archives published
board meeting minutes as PDFs and is designed to run monthly to capture new
documents as they are posted. A separate extraction pass reads the archived minutes
and produces structured data on topics discussed, motions passed, and decisions
recorded. This is the highest-complexity role in the platform and is planned for
last in the build sequence.

---

## Imported Data Sources

Two data sources are imported rather than scraped.

**Hospital Information Tables (HIT).** The Ontario Ministry of Health publishes
annual financial and operational data for all public hospitals through its Hospital
Information Tool. The HIT data is downloaded manually once per year and processed
into `hit_master.csv` — a long-format file with one row per hospital per reporting
year, covering approximately 55 financial and operational indicators across seven
fiscal years. Because the HIT data uses FAC codes, it joins directly to the
platform registry and to strategy data without a crosswalk.

**CIHI Quality Performance Indicators.** The Canadian Institute for Health
Information publishes hospital-level quality indicators annually. CIHI does not
use FAC codes — its hospital identifier system is independent of the provincial
facility code. Joining CIHI data to the platform therefore requires a FAC-to-CIHI
crosswalk, produced by a separate name-matching system that reconciles hospital
names across the two systems. The crosswalk file lives in the platform's reference
folder; the platform consumes it but does not own the matching logic. CIHI
integration has not yet been implemented.

---

## The Analytical Layer

All roles produce FAC-keyed outputs that join at the analysis layer. The analysis
layer is a set of R scripts that read from the master CSVs and produce summary
statistics, visualizations, and research-ready data frames.

### Strategy Analytics

Strategy analytics is the most complete analytical workstream. The pipeline runs
in a defined sequence from data preparation through four analytical stages.

**Thematic classification.** After extraction, each strategic direction is
submitted to the Claude API for thematic classification using a 10-code taxonomy:
Patient Care and Quality (PAT), Workforce and Culture (WRK), Financial Sustainability
(FIN), Innovation and Technology (INN), Research and Education (RES), Equity and
Inclusion (EDI), Partnerships and Community (PAR), Organizational Development (ORG),
Digital Transformation (DIG), and Environmental Stewardship (ENV). Each direction
receives a primary theme and, where applicable, a secondary theme. Temperature is
set to zero for deterministic output. The classification results were audited for
accuracy before being used in any analysis.

**Temporal and type-group analysis.** Hospitals are grouped into three planning
eras based on plan adoption year: pre-COVID (plans initiated before 2020),
COVID-era (2020–2021), and post-COVID (2022 onward). Theme prevalence, direction
counts, and type-group composition are analyzed across eras to identify shifts
in strategic emphasis. Community — Large, Community — Small, Teaching, and
Specialty hospitals are analyzed as separate groups throughout.

**Homogeneity analysis.** Strategic similarity between hospitals is measured using
Jaccard similarity coefficients on the binary theme presence vectors — a measure
that captures what two hospitals have in common relative to what either addresses.
Within-type-group pairs show higher similarity than cross-type pairs, as expected,
but absolute similarity levels are moderate rather than high: most hospital pairs
share fewer than half of their themes, indicating meaningful variation within
type groups alongside the structural commonalities.

**Distinctive directions.** Within each theme and type-group cell, the direction
text as written by hospitals is submitted to the Claude API to identify directions
that are linguistically or substantively distinctive relative to peers. This
separates generic sector language ("improve patient experience") from directions
that name specific communities, commitments, or strategic repositioning claims.
The analysis identifies 89 distinctive directions across 129 hospitals in the
current-era cohort.

### HIT Financial Analytics

The HIT analytics workstream links financial trajectory data to strategic plan
characteristics. Year-over-year revenue and expense growth rates are computed
from the HIT data and adjusted by subtracting the annual sector median — removing
the common signal from province-wide funding events such as the COVID-era
emergency transfer surge and the post-COVID reconciliation period. The resulting
field-adjusted values measure each hospital's performance relative to its peers
in each year rather than against an absolute standard.

These field-adjusted trajectories are then matched to strategic plan data. A
minimum two-year plan tenure filter ensures that only hospitals with plans in
place long enough to plausibly influence financial outcomes are included in
comparisons. The primary finding to date is a clean null result: hospitals with
strategic plans do not show detectably different revenue or expense trajectories
from hospitals without them, and hospitals that explicitly name financial
sustainability as a strategic priority do not show better cost control or revenue
performance than those that do not. The sector median is a powerful gravitational
force; individual strategic choices operate within it rather than above it.

---

## Design Principles

Several design decisions run throughout the platform and are worth naming explicitly.

**Exact text, not interpretation.** Every extraction prompt enforces verbatim
capture. The platform records what hospitals say, not what a reader infers from
what they say. Classification is a separate step applied after extraction, never
during it. This separation preserves the original text for audit and allows
classification schemes to be revised without re-extraction.

**FAC as the universal key.** Using the provincial facility code throughout
eliminates name-matching ambiguity and makes every data source joinable to
every other without a translation layer. The single exception — CIHI — requires
a dedicated crosswalk precisely because it does not use FAC codes.

**80% success as the operational target.** The platform does not pursue perfect
coverage. A target of 80% or more of robots-allowed hospitals returning usable
results is treated as success for each role. Failures are logged to a structured
CSV for a dedicated review pass. This allows the pipeline to run at scale without
getting stuck on edge cases.

**Null results are findings.** The HIT analytics workstream has produced clean
null results on the primary research questions to date. These are reported as
findings, not as analytical failures. The absence of a detectable plan effect in
financial data is itself informative — it says something about the relationship
between strategic planning and the financial instruments used to evaluate
hospital performance in Ontario.

---

*HospitalIntelligenceR | Methods Overview | May 2026*
*This document covers the platform as of May 2026. Build status reflects work
completed to date; roles marked as not yet built are scoped and sequenced in
the project registry.*
