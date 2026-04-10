# HospitalIntelligenceR
## Project Structure & Setup Guide

*Last Updated: April 2026*

---

## 1. Overview

HospitalIntelligenceR is a single R project and GitHub repository containing a
configurable web-scraping engine for Ontario hospitals. It replaces several ad-hoc
scripts with a structured, modular architecture composed of shared core
infrastructure and five distinct role modules.

The project is designed to be built incrementally — core first, then roles one at
a time.

All five extraction roles (Strategic Plans, Foundational Documents, Executives,
Board of Directors, Board Minutes) operate on the same 133 Ontario hospitals using
the same FAC-keyed registry, but each role has its own code, prompts, and outputs
within its subfolder.

---

## 2. Environment Setup

### 2.1 R and RStudio

Ensure you have R 4.3+ and RStudio installed. The project uses `source()` style
loading — no formal package installation required.

### 2.2 Required R Packages

```r
install.packages(c(
  "httr2",        # HTTP requests
  "rvest",        # HTML parsing
  "pdftools",     # PDF to text
  "yaml",         # YAML read/write
  "dplyr",        # Data manipulation
  "purrr",        # Functional tools
  "stringr",      # String processing
  "lubridate",    # Date handling
  "jsonlite",     # JSON for API calls
  "logger",       # Structured logging
  "robotstxt",    # robots.txt parsing
  "ggplot2",      # Graphics
  "tidyr",        # Data frame reshaping
  "scales"        # Numeric formatting and axis scaling
))
```

### 2.3 GitHub Repository

Repository name: `HospitalIntelligenceR`. Initialize with a README. Clone to your
local machine. Working directory is `E:/HospitalIntelligenceR`.

---

## 3. Folder Structure

Empty folders require a placeholder file (`.gitkeep`) to be tracked by Git.

```
HospitalIntelligenceR/
│
├── CLAUDE_WORKING_PREFERENCES.md      # Session orientation for Claude
│
├── core/                              # Shared infrastructure used by all roles
│   ├── registry.R                     # YAML read/write, FAC lookups, status updates
│   ├── crawler.R                      # robots.txt, rate limiting, link extraction
│   ├── fetcher.R                      # HTTP, PDF download, HTML retrieval
│   ├── claude_api.R                   # API calls, cost tracking, prompt loading
│   └── logger.R                       # Logging, error capture, run summaries
│
├── analysis/                          # Strategy analytics layer
│   ├── scripts/                       # Analytical R scripts
│   │   ├── 00_prepare_data.R          # Canonical data prep — run first after any Phase 2 change
│   │   ├── 00b_explore_directions.R
│   │   ├── 00c_build_strategy_classified.R
│   │   ├── 00d_patch_gov_corrections.R
│   │   ├── 00e_audit_plan_dates.R
│   │   ├── 00f_patch_plan_dates.R
│   │   ├── 00g_fetch_missing_dates.R
│   │   ├── 00h_patch_missing_dates.R
│   │   ├── 01a_plan_volume.R
│   │   ├── 01b_direction_types.R
│   │   ├── 02_thematic_classify.R
│   │   ├── 03a_explore_plan_years.R
│   │   ├── 03b_theme_trends.R
│   │   ├── 03c_theme_by_era_type.R
│   │   ├── 04a_homogeneity.R
│   │   └── 04b_unique_strategies.R
│   ├── data/                          # Intermediate analytical CSVs (gitignored)
│   └── outputs/
│       ├── figures/                   # .png outputs, 300 DPI, 7×5 inches
│       └── tables/                    # Summary CSVs
│
├── roles/
│   ├── strategy/                      # Strategic plan extraction (annual)
│   │   ├── config.R
│   │   ├── extract.R                  # Phase 1 — crawl and download
│   │   ├── phase2_extract.R           # Phase 2 — Claude API extraction
│   │   ├── prompts/
│   │   │   └── strategy_l1.txt
│   │   └── outputs/
│   │       ├── extractions/           # Per-hospital CSVs + strategy_master.csv
│   │       ├── pdfs/                  # Downloaded PDFs, organised by FAC folder
│   │       └── logs/
│   │
│   ├── foundational/                  # Vision / Mission / Values (on change)
│   │   ├── config.R
│   │   ├── extract.R
│   │   ├── prompts/
│   │   └── outputs/
│   │
│   ├── executives/                    # Executive team (monthly)
│   │   ├── config.R
│   │   ├── extract.R
│   │   ├── prompts/
│   │   └── outputs/
│   │
│   ├── board/                         # Board of directors (6-month, post-September)
│   │   ├── config.R
│   │   ├── extract.R
│   │   ├── prompts/
│   │   └── outputs/
│   │
│   └── minutes/                       # Board meeting minutes archive (monthly)
│       ├── config.R
│       ├── extract.R
│       ├── prompts/
│       └── outputs/
│           ├── pdfs/                  # Downloaded minutes PDFs, organised by hospital
│           └── logs/
│
├── registry/
│   └── hospital_registry.yaml         # Single source of truth — all 133 hospitals
│
├── reference/
│   └── cihi_fac_crosswalk.csv         # FAC-to-CIHI ID crosswalk (external matching system)
│
├── orchestrate/                       # Built last — ties roles together
│   └── run_all.R
│
├── docs/
│   ├── programming_reference/         # Technical orientation documents
│   │   ├── ProjectStructure.md        # This file
│   │   ├── Project_Outline_Hospital_Intelligence.md
│   │   ├── StrategyPipelineReference.md
│   │   ├── yaml_registry_reference.md
│   │   ├── ExtractionGuidelines.md
│   │   ├── SOP_new_strategic_plan.md
│   │   └── strategy_role_future_plans.md
│   │
│   ├── writing_and_research/          # Narrative documents and writing aids
│   │   ├── style_guide.md             # Publication voice — reference before drafting
│   │   ├── 03b_narrative.md           # Thematic trends — technical narrative
│   │   ├── 03c_narrative.md           # Era × type interaction — technical narrative
│   │   ├── 04a_narrative.md           # Homogeneity — technical narrative (pending)
│   │   └── 04b_narrative.md           # Distinctive directions — technical narrative (pending)
│   │
│   ├── prompts/                       # Tracked analytical prompt assets
│   │   └── theme_classify_prompt.txt
│   │
│   └── session_summaries/             # Per-session markdown summaries
│       └── SessionSummary_YYYYMMDD.md
│
├── dev/                               # Scratch/sandbox — gitignored, never production
│   └── sandbox.R
│
├── .gitignore
├── HospitalIntelligenceR.Rproj
└── README.md
```

---

## 4. Registry File

The single registry file is `registry/hospital_registry.yaml`. It consolidates
what were previously two separate files (`base_hospitals_validated.yaml` and
`hospital_strategy.yaml`).

For full field definitions, ownership rules, and safe editing procedures, see
`docs/programming_reference/yaml_registry_reference.md`.

### Structure per hospital entry

```yaml
hospitals:
  - FAC: '592'
    name: NAPANEE LENNOX & ADDINGTON
    hospital_type: Small Hospital
    base_url: https://lacgh.napanee.on.ca
    base_url_validated: yes
    robots_allowed: yes
    last_validated: '2025-11-28'
    leadership_url: https://web.lacgh.napanee.on.ca/about/governance/
    notes: ''
    status:
      strategy:
        last_search_date: '2026-03-24'
        content_url: https://lacgh.napanee.on.ca/wp-content/uploads/2025/08/LAH0004-Strat-Plan-Layout-and-Design-DIGITAL.pdf
        content_type: pdf
        local_folder: 592_NAPANEE_LENNOX_ADDINGTON
        local_filename: 592_20260324.pdf
        last_extraction_date: '2026-02-03'
        extraction_status: downloaded
        manual_override: no
        override_reason: ''
        needs_review: no
        phase2_status: extracted
        phase2_date: '2026-03-28'
        phase2_quality: full
        phase2_n_dirs: 3
      foundational:
        last_extraction_date: ''
        extraction_status: pending
        manual_override: no
        override_reason: ''
        needs_review: no
      executives:
        last_extraction_date: ''
        extraction_status: pending
        manual_override: no
        override_reason: ''
        needs_review: no
      board:
        last_extraction_date: ''
        extraction_status: pending
        manual_override: no
        override_reason: ''
        needs_review: no
      minutes:
        last_run_date: ''
        documents_downloaded: 0
        earliest_document_date: ''
        latest_document_date: ''
        extraction_status: pending
        manual_override: no
        override_reason: ''
        needs_review: no
```

**Important:** `registry.R` is the only module that writes to this file. For
manual edits (corrections, overrides), follow the procedure in
`docs/programming_reference/yaml_registry_reference.md` and close the file in
RStudio before running any patch script.

**Note on `leadership_url`:** Currently a top-level field serving as a
general-purpose seed URL for executives, board, and foundational crawling.
Revisit when building `roles/executives/` and `roles/board/` — per-role URL
fields may be more appropriate at that point.

---

## 5. .gitignore Configuration

```
# Outputs — large data files, not for version control
roles/*/outputs/
analysis/data/

# Dev/sandbox
dev/

# R environment
.Rhistory
.RData
.Rproj.user/

# Sensitive config
config_secrets.R
.env
```

---

## 6. RStudio Project File

Open RStudio → File → New Project → Existing Directory → point to
`HospitalIntelligenceR/` root. This creates `HospitalIntelligenceR.Rproj`.
Commit this file to Git.

---

## 7. Build Sequence

Core modules are built and tested before any role module is started.

| Module | Build order | Depends on |
|---|---|---|
| `core/registry.R` | 1 — first | nothing |
| `core/fetcher.R` | 1 — first | nothing |
| `core/crawler.R` | 2 — second | fetcher.R |
| `core/claude_api.R` | 2 — second | fetcher.R |
| `core/logger.R` | 2 — second | nothing |
| `roles/strategy/` | 3 — third | all core |
| `roles/foundational/` | 3 — third | all core |
| `roles/executives/` | 4 | all core |
| `roles/board/` | 4 | all core |
| `roles/minutes/` | 4 — last role | all core |
| `orchestrate/run_all.R` | 5 — last | all roles |

For the strategy analytics execution order, see
`docs/programming_reference/StrategyPipelineReference.md`.

---

## 8. Files Migrated From Legacy Setup

| Legacy file | New location | Notes |
|---|---|---|
| `base_hospitals_validated.yaml` | `registry/hospital_registry.yaml` | Merged with hospital_strategy.yaml; renamed |
| `hospital_strategy.yaml` | retired | Data migrated into hospital_registry.yaml |
| `Phase3_L1_Extraction_V4.1.txt` | `docs/programming_reference/` | Renamed and moved |
| `ExtractionGuidelines.md` | `docs/programming_reference/` | Updated |
| `extraction_workflow_v3_no_batching.R` | `roles/strategy/extract.R` | Significant refactor |
| `api_functions_with_images.R` | `core/claude_api.R` | Core API logic |
| `pdf_image_processor.R` | `core/fetcher.R` | PDF handling |
| `progress_functions.R` | `core/logger.R` | Progress tracking |
| `config_v2.R` | `roles/strategy/config.R` + core paths | Split: role config vs global paths |
