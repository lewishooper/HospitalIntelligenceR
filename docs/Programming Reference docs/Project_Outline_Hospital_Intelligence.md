# HospitalIntelligenceR — Project Outline

*Last Updated: April 2026*

---

## 1. Purpose

HospitalIntelligenceR is an R-based pipeline for systematically collecting,
extracting, and analyzing strategic and operational data from Ontario hospitals.
It replaces a set of ad-hoc scraping scripts with a single, modular architecture
built on shared infrastructure and a FAC-keyed registry.

The project has two primary end-uses:

- **Research** — producing analytical outputs and white papers on Ontario hospital
  strategy, governance, and performance
- **B2B application** — identifying hospitals that may benefit from specific
  expertise, based on strategic priorities and organizational characteristics

---

## 2. Scope

The project covers approximately 129–133 Ontario hospitals registered in
`hospital_registry.yaml`. The FAC (facility code) is the primary key throughout
— every data source and every output is keyed to FAC.

Seven hospital types are represented:

- Teaching Hospitals
- Large Community Hospitals
- Small Hospitals
- Chronic / Rehab Hospitals
- Psychiatric Hospitals
- Northern Hospitals
- Specialty Hospitals

---

## 3. Architecture

### 3.1 Single R Project, Single Registry

All roles share one R project (`HospitalIntelligenceR`), one GitHub repository,
and one registry file (`hospital_registry.yaml`). The registry is the single
source of truth for hospital metadata and per-role extraction status. Only
`core/registry.R` may write to it.

### 3.2 Core Infrastructure

Shared modules live in `core/` and are used by all roles:

| Module | Purpose |
|---|---|
| `registry.R` | YAML read/write, FAC lookups, status updates |
| `fetcher.R` | HTTP requests, PDF download, HTML retrieval, URL encoding |
| `crawler.R` | robots.txt compliance, rate limiting, keyword-scored link extraction |
| `claude_api.R` | Claude API calls, image-mode rendering, cost tracking, prompt loading |
| `logger.R` | Structured logging, run summaries, audit CSV |

### 3.3 Role Modules

Each extraction role lives in `roles/<role>/` with its own `config.R`,
extraction script(s), prompts, and outputs. Roles are independent and run on
different cadences. They share core infrastructure but do not share code.

### 3.4 Two-Phase Pattern

All scraping roles follow the same two-phase pattern:

**Phase 1 — Locate and collect.** The crawler finds and downloads the target
document (PDF, HTML, or plain text) for each hospital. Output: local files on
disk, registry updated with `local_filename` and `extraction_status`.

**Phase 2 — Extract and structure.** The Claude API reads each document and
returns structured JSON, which is written to a per-role master CSV. Output:
`<role>_master.csv` in long-format tidy CSV, one row per unit of content.

### 3.5 80% Success Threshold

Rather than pursuing perfection per role, the target is ≥80% of robots-allowed
hospitals returning usable results. Failures are logged to CSV for a dedicated
fine-tuning pass. Robots-blocked hospitals are excluded from the denominator.

### 3.6 Key Engineering Decisions

- **YAML over RDS** — The registry remains in YAML for human readability,
  git-diffability, and ease of manual patching. If a queryable operational layer
  is needed in future, SQLite via `RSQLite`/`DBI` is the appropriate addition
  as a separate layer.
- **Exact text extraction** — All Claude API prompts enforce verbatim extraction
  throughout. No paraphrasing or condensing in any extracted field.
- **`force_image_mode` flag** — PDFs with broken embedded fonts that produce
  garbage character counts can be forced into image-mode rendering via a YAML
  flag, bypassing the text-usability threshold.
- **Version-safe file naming** — `.make_local_path()` appends `_v2`, `_v3`,
  etc. rather than overwriting existing files, preserving older documents for
  longitudinal analysis.
- **URL space encoding** — `gsub(" ", "%20", url, fixed = TRUE)` is the
  canonical approach; `URLencode()` corrupts query string delimiters and is
  not used.

---

## 4. Data Sources

### 4.1 Scraped Roles (Phase 1 + Phase 2)

These roles collect documents from hospital websites and extract structured data
via the Claude API.

#### Role 1: Strategic Plans (`strategy`)

**Goal:** Extract the hospital's current strategic plan — plan period, strategic
directions/pillars, descriptive text per direction, and key actions/initiatives.

**Cadence:** Annual, or when a new plan is detected.

**Preferred source:** Downloadable PDF. HTML fallback if no PDF is available.

**Output:** `strategy_master.csv` — long format, one row per strategic direction,
keyed by FAC.

**Status:** Complete. 129 hospitals processed, 581 rows. See Section 5.1 for
analytics status.

**Key fields:** `FAC`, `direction_name`, `direction_text`, `key_actions`,
`direction_type`, `plan_start`, `plan_end`, `plan_classification`,
`extraction_quality`, `source_type`

---

#### Role 2: Foundational Documents (`foundational`)

**Goal:** Extract foundational guiding documents — Vision, Mission, Values, and
any equivalents (Purpose, Principles, etc.) — including the exact labels used
by each hospital.

**Cadence:** On change (checked annually at minimum).

**Preferred source:** Hospital website HTML. PDF fallback from strategic plan if
HTML unavailable.

**Output:** `foundational_master.csv` — one row per foundational element, keyed
by FAC.

**Status:** Not started. Next role to build.

**Note:** Hospitals use widely varying terminology. Extraction must capture the
label as used, not assume standard Vision/Mission/Values structure.

---

#### Role 3: Executive Team (`executives`)

**Goal:** Extract current executive team members — names, titles, and roles.
Typically includes CEO, CNO, COS, and Vice Presidents.

**Cadence:** Monthly.

**Preferred source:** Hospital website HTML (leadership or about page). Starting
point: `leadership_url` field in registry.

**Output:** `executives_master.csv` — one row per executive, keyed by FAC.

**Status:** Not started.

**Note:** In larger hospitals, CEO, CNO, and COS appear on both the executive
list and the board list as ex-officio members. Both roles capture them
independently.

---

#### Role 4: Board of Directors (`board`)

**Goal:** Extract current board membership — Chair, Vice Chair, and directors.
Track changes on a six-month basis following September board elections.

**Cadence:** 6-month (post-September elections).

**Preferred source:** Hospital website HTML (governance pages).

**Output:** `board_master.csv` — one row per board member, keyed by FAC.

**Status:** Not started.

---

#### Role 5: Board Meeting Minutes (`minutes`)

**Goal:** Download and archive all available board meeting minutes as PDFs.
Track new documents monthly.

**Cadence:** Monthly. Initial run downloads all historically available minutes;
subsequent runs download only documents posted since the last successful run.

**Preferred source:** PDF (minutes are almost always published as PDFs).

**Output:** Archived PDFs in `roles/minutes/outputs/pdfs/<FAC>_<n>/`. A separate
extraction pass (Phase 2) produces `minutes_master.csv` with topics, decisions,
and motions.

**Status:** Not started. Highest complexity role — build last.

**Note:** This role has no Claude API cost in Phase 1 — download only. Phase 2
extraction from unstructured minutes text is the most analytically complex
extraction task in the project.

---

### 4.2 External Data Sources (Imported, Not Scraped)

These sources are not scraped from hospital websites. They are imported as
structured reference data and joined to the analysis layer via FAC.

---

#### Source 6: HIT — Hospital Information Tables

**Goal:** Incorporate Ontario Ministry of Health financial data for each hospital
— revenue, expenses, volumes, FTEs, and related indicators.

**Cadence:** Annual. Year-end release is published in May/June. Data is provided
manually by the researcher.

**Acquisition:** Manual download from Ministry of Health. No automated scraping
required.

**Processing:** Minimal — FAC join and standardized column naming. No Claude API
required.

**Output:** `hit_master.csv` — one row per hospital per reporting year, keyed by
FAC.

**Status:** Not started. Low build complexity; implemented as a standalone import
script.

---

#### Source 7: CIHI — Quality Performance Indicators

**Goal:** Incorporate Canadian Institute for Health Information hospital-level
quality performance indicators.

**Cadence:** Annual (CIHI publishes updated indicator sets annually).

**Acquisition:** Manual download from CIHI Your Health System portal, pruned to
Ontario hospitals.

**ID mapping:** CIHI does not use FAC codes and provides no stable hospital
identifier that maps directly to FAC. A FAC-to-CIHI crosswalk is produced by a
separate name-matching R system (external to HospitalIntelligenceR), which
reconciles hospital names across systems after pruning to Ontario hospitals. The
crosswalk is delivered as a reference CSV and lives in `reference/` within the
project. HospitalIntelligenceR consumes the crosswalk; it does not own the
matching logic.

**Output:** `cihi_master.csv` — one row per hospital per indicator per year,
keyed by FAC.

**Status:** Not started. Crosswalk table must be produced first.

---

#### Source 8: QIPs — Quality Improvement Plans

**Goal:** Incorporate annual quality improvement plans submitted by Ontario
hospitals to Health Quality Ontario (HQO).

**Cadence:** Annual.

**Acquisition:** Feasibility under investigation. QIPs were historically available
via a central HQO portal. Current availability and access requirements (including
whether a login is required) need to be confirmed before this source is scoped.

**Status:** Deferred — pending feasibility review. Lowest priority external
source.

---

## 5. Analysis Layer

All roles produce FAC-keyed outputs that join at the analysis layer. The analysis
layer is a set of R analytical scripts in `analysis/scripts/` that read from the
master CSVs and produce outputs (summaries, visualizations, and research-ready
data frames).

### 5.1 Strategy Analytics

Strategy analytics is substantially complete. The table below shows the status
of each analytical workstream.

| Workstream | Scripts | Status |
|---|---|---|
| Data preparation | `00_prepare_data.R`, `00b`–`00h` | Complete |
| Thematic classification | `02_thematic_classify.R` | Complete — 543 directions, 10-code taxonomy |
| Plan volume and direction types | `01a_plan_volume.R`, `01b_direction_types.R` | Complete |
| Thematic trends over time | `03a_explore_plan_years.R`, `03b_theme_trends.R` | Complete — narrative produced |
| Era × hospital type interaction | `03c_theme_by_era_type.R` | Complete — narrative produced |
| Strategic homogeneity | `04a_homogeneity.R` | Scripts and CSVs complete — narrative pending |
| Distinctive directions and outliers | `04b_unique_strategies.R` | Scripts and CSVs complete — narrative pending |
| Board minutes linkage | — | Not started — requires minutes role |
| CIHI quality performance correlation | — | Not started — requires CIHI crosswalk |
| HIT financial performance correlation | — | Not started — requires HIT import |

**Taxonomy:** 10 active codes — PAT, WRK, FIN, INN, RES, EDI, PAR, ORG, DIG,
ENV, QUA. GOV was retired after the first full classification run (only 2
directions assigned; triggered incorrectly on label text).

**Era-assignable cohort:** 114 of 129 hospitals have confirmed plan dates and
are included in temporal analyses. The remaining 15 have missing or
unresolvable dates.

#### Narrative model

Each completed analytical workstream produces two documents:

- **Technical narrative** — methodologically complete, flat in tone, lives in
  `docs/writing_and_research/`. This is the authoritative record of what was
  done and found.
- **Publication narrative** — practitioner-facing, written in Skip's voice per
  `docs/writing_and_research/style_guide.md`. Shorter, leads with findings,
  omits methodological detail. Lives in `docs/writing_and_research/`.

These are distinct documents, not summaries of each other. The publication
narrative is a different piece of writing that covers the same analysis.

### 5.2 Cross-Role Analysis (Future)

Once multiple roles are complete, the analysis layer will support cross-role
questions such as:

- Does executive team stability predict strategic consistency?
- Do hospitals whose board minutes address strategic themes explicitly perform
  differently?
- Is there alignment between foundational documents (vision/mission) and stated
  strategic priorities?

---

## 6. Build Sequence

| Priority | Workstream | Status |
|---|---|---|
| Now | Strategy analytics — 04a/04b narratives | Active |
| Next | Foundational documents role (Phase 1 + Phase 2) | Not started |
| Then | HIT import script | Not started |
| Then | CIHI crosswalk integration | Not started |
| Later | Executives role | Not started |
| Later | Board role | Not started |
| Last | Board minutes role | Not started |
| Last | QIPs (pending feasibility) | Deferred |

---

## 7. Key Operational Rules

- **YAML registry discipline is critical.** Close the YAML file in RStudio
  before any patch script runs and before uploading to the repository. RStudio
  will overwrite disk changes if the file is open when the "file changed on
  disk" prompt appears.
- **No manual transcription.** Human effort for unobtainable content is limited
  to tool-based capture (snipping tool, browser save, PDF download). If content
  cannot be captured by a tool, the hospital receives a terminal status.
- **Python-based YAML inspection is more reliable than R-based reads** for bulk
  FAC state verification, bypassing R's `load_registry()` caching.
- **Session-end checklist:** YAML upload, deletion of superseded session files,
  retention of all session summaries, GitHub push, close YAML in RStudio.
- **Repository files are not auto-updated.** Changes made locally in RStudio
  are not reflected in the project knowledge repository until explicitly
  re-uploaded.

---

## 8. Repository Structure

```
HospitalIntelligenceR/
├── CLAUDE_WORKING_PREFERENCES.md
├── core/
│   ├── registry.R
│   ├── fetcher.R
│   ├── crawler.R
│   ├── claude_api.R
│   └── logger.R
├── analysis/
│   ├── scripts/
│   ├── data/                          # Gitignored
│   └── outputs/
│       ├── figures/
│       └── tables/
├── roles/
│   ├── strategy/
│   │   ├── config.R
│   │   ├── extract.R
│   │   ├── phase2_extract.R
│   │   ├── prompts/strategy_l1.txt
│   │   └── outputs/
│   │       ├── extractions/
│   │       ├── pdfs/
│   │       └── logs/
│   ├── foundational/
│   ├── executives/
│   ├── board/
│   └── minutes/
├── reference/
│   └── cihi_fac_crosswalk.csv
├── registry/
│   └── hospital_registry.yaml
├── docs/
│   ├── programming_reference/
│   │   ├── Project_Outline_Hospital_Intelligence.md   # This file
│   │   ├── ProjectStructureAndSetup.md
│   │   ├── StrategyPipelineReference.md
│   │   ├── yaml_registry_reference.md
│   │   ├── ExtractionGuidelines.md
│   │   ├── SOP_new_strategic_plan.md
│   │   └── strategy_role_future_plans.md
│   ├── writing_and_research/
│   │   ├── style_guide.md
│   │   ├── 03b_narrative.md
│   │   ├── 03c_narrative.md
│   │   ├── 04a_narrative.md           # Pending
│   │   └── 04b_narrative.md           # Pending
│   ├── prompts/
│   │   └── theme_classify_prompt.txt
│   └── session_summaries/
├── orchestrate/
│   └── run_all.R
└── dev/                               # Gitignored scratch space
```

---

*This document is maintained in `docs/programming_reference/` and should be
updated when major architectural decisions change, new roles are added, or
analytical workstream status changes.*
