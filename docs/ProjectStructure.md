# HospitalIntelligenceR
## Project Structure & Setup Guide

*Last Updated: March 2026*

---

## 1. Overview

HospitalIntelligenceR is a single R project and GitHub repository containing a configurable web-scraping engine for Ontario hospitals. It replaces several ad-hoc scripts with a structured, modular architecture composed of shared core infrastructure and five distinct role modules.

The project is designed to be built incrementally — core first, then roles one at a time.

All five extraction roles (Strategic Plans, Foundational Documents, Executives, Board of Directors, Board Minutes) operate on the same 133 Ontario hospitals using the same FAC-keyed registry, but each role has its own code, prompts, and outputs within its subfolder.

---

## 2. Environment Setup

### 2.1 R and RStudio

Ensure you have R 4.3+ and RStudio installed. The project uses `source()` style loading — no formal package installation required.

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
  "robotstxt"     # robots.txt parsing
))
```

### 2.3 GitHub Repository

Repository name: `HospitalIntelligenceR`. Initialize with a README. Clone to your local machine. Working directory is `E:/HospitalIntelligenceR`.

---

## 3. Folder Structure

Empty folders require a placeholder file (`.gitkeep`) to be tracked by Git.

```
HospitalIntelligenceR/
│
├── core/                          # Shared infrastructure used by all roles
│   ├── registry.R                 # YAML read/write, FAC lookups, status updates
│   ├── crawler.R                  # robots.txt, rate limiting, link extraction
│   ├── fetcher.R                  # HTTP, PDF download, HTML retrieval
│   ├── claude_api.R               # API calls, cost tracking, prompt loading
│   └── logger.R                   # Logging, error capture, run summaries
│
├── roles/
│   ├── strategy/                  # Strategic plan extraction (annual)
│   │   ├── config.R
│   │   ├── extract.R
│   │   ├── prompts/
│   │   │   └── strategy_l1.txt
│   │   └── outputs/
│   │       ├── extracted/
│   │       └── logs/
│   │
│   ├── foundational/              # Vision / Mission / Values (on change)
│   │   ├── config.R
│   │   ├── extract.R
│   │   ├── prompts/
│   │   └── outputs/
│   │
│   ├── executives/                # Executive team (monthly)
│   │   ├── config.R
│   │   ├── extract.R
│   │   ├── prompts/
│   │   └── outputs/
│   │
│   ├── board/                     # Board of directors (6-month, post-September)
│   │   ├── config.R
│   │   ├── extract.R
│   │   ├── prompts/
│   │   └── outputs/
│   │
│   └── minutes/                   # Board meeting minutes archive (monthly)
│       ├── config.R
│       ├── extract.R
│       ├── prompts/
│       └── outputs/
│           ├── pdfs/              # Downloaded minutes PDFs, organised by hospital
│           └── logs/
│
├── registry/
│   └── hospital_registry.yaml     # Single source of truth — all 133 hospitals
│
├── orchestrate/                   # Built last — ties roles together
│   └── run_all.R
│
├── docs/
│   ├── ExtractionGuidelines.md
│   ├── ProjectStructure.md        # This file
│   ├── SessionSummary.md
│   └── protocols/
│       └── Phase3_L1_Extraction_V4.1.txt
│
├── dev/                           # Scratch/sandbox — gitignored, never production
│   └── sandbox.R
│
├── .gitignore
├── HospitalIntelligenceR.Rproj
└── README.md
```

---

## 4. Registry File

The single registry file is `registry/hospital_registry.yaml`. It consolidates what were previously two separate files (`base_hospitals_validated.yaml` and `hospital_strategy.yaml`).

### Structure per hospital entry

```yaml
hospitals:
  - FAC: '592'
    name: NAPANEE LENNOX & ADDINGTON
    hospital_type: Small Hospital
    base_url: https://web.lacgh.napanee.on.ca
    base_url_validated: yes
    robots_allowed: yes
    last_validated: '2025-11-28'
    leadership_url: https://web.lacgh.napanee.on.ca/about/governance/
    notes: ''
    status:
      strategy:
        last_search_date: '2026-01-19'
        content_url: https://example.com/strategy.pdf
        content_type: pdf
        local_folder: 592_NAPANEE_LENNOX_ADDINGTON
        local_filename: Strategy_202601_592.pdf
        last_extraction_date: '2026-02-03'
        extraction_status: complete
        manual_override: yes
        override_reason: Downloaded from manually provided URL
        needs_review: no
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

**Important:** `registry.R` is the only module that writes to this file.

**Note on `leadership_url`:** Currently a top-level field serving as a general-purpose seed URL for executives, board, and foundational crawling. Revisit when building `roles/executives/` and `roles/board/` — per-role URL fields may be more appropriate at that point.

---

## 5. .gitignore Configuration

```
# Outputs — large data files, not for version control
roles/*/outputs/

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

Open RStudio → File → New Project → Existing Directory → point to `HospitalIntelligenceR/` root. This creates `HospitalIntelligenceR.Rproj`. Commit this file to Git.

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

---

## 8. Files Migrated From Legacy Setup

| Legacy file | New location | Notes |
|---|---|---|
| `base_hospitals_validated.yaml` | `registry/hospital_registry.yaml` | Merged with hospital_strategy.yaml; renamed |
| `hospital_strategy.yaml` | retired | Data migrated into hospital_registry.yaml |
| `Phase3_L1_Extraction_V4.1.txt` | `docs/protocols/` | Renamed and moved |
| `ExtractionGuidelines.md` | `docs/` | Updated |
| `extraction_workflow_v3_no_batching.R` | `roles/strategy/extract.R` | Significant refactor |
| `api_functions_with_images.R` | `core/claude_api.R` | Core API logic |
| `pdf_image_processor.R` | `core/fetcher.R` | PDF handling |
| `progress_functions.R` | `core/logger.R` | Progress tracking |
| `config_v2.R` | `roles/strategy/config.R` + core paths | Split: role config vs global paths |
