# HospitalIntelligenceR
## Session Summary & Development Roadmap

*Last Updated: March 2026 | For Claude Project Knowledge Repository*

---

## 1. Context & Problem Statement

This project emerged from a recognition that several independent web-scraping workflows for Ontario hospitals had been developed in an ad-hoc manner, with significant overlap in infrastructure and significant manual effort required in each. The immediate use cases are extracting hospital strategic plans for research and analysis, and extracting foundational documents (vision/mission/values). Three additional roles — executive team tracking, board of directors tracking, and board meeting minutes archiving — are also in scope.

The goal is a single, well-structured R project (HospitalIntelligenceR) that provides shared scraping infrastructure while keeping each extraction role distinct, organized, and independently maintainable. The longer-term vision includes producing research white papers and, eventually, a B2B offering helping companies identify hospitals that may need their expertise — though the immediate focus is research and analysis.

---

## 2. Key Decisions Made

### 2.1 Architecture

- **Single R Project / single GitHub repository** — one `.Rproj`, one repo, no confusion about where things live.
- **Subfolder-per-role structure** — each extraction role has its own code, prompts, and outputs under `roles/`. Scripts are never more than two levels deep within a role.
- **Shared core infrastructure** — registry, crawler, fetcher, Claude API wrapper, and logger live in `core/` and are used by all roles. No duplication.
- **Role configs as data objects** — each role defines its behaviour (keywords, depth, cadence, schema) in a `config.R` file. Adding a new role means writing a config and a prompt, not touching core.
- **Manual overrides as first-class citizens** — hospitals that cannot be auto-scraped carry an explicit `manual_override` status in the YAML, handled cleanly rather than as exceptions.

### 2.2 Technology Choices

- R-based throughout, using tidyverse-compatible packages.
- Claude API for all content extraction — used for strategic plans, foundational documents, executives, and board members. More effective use of time and resources than bespoke HTML parsers for the variety of content encountered.
- YAML as the single source of truth for the hospital registry (`hospital_registry.yaml`), serving all roles.
- Incremental migration — existing scripts are not discarded but refactored into the new structure once the relevant core module is built and stable.

### 2.3 Registry Consolidation

The legacy setup had two YAML files: `base_hospitals_validated.yaml` (hospital metadata) and `hospital_strategy.yaml` (strategy extraction status). These have been consolidated into a single `registry/hospital_registry.yaml` with a clean per-role status block for each hospital. The old files are retired. A one-off migration script (`dev/migrate_to_registry.R`) was used to merge and map the data.

---

## 3. Architecture Summary

### 3.1 The Five Extraction Roles

| Role | Content Target | Cadence | Content Type |
|---|---|---|---|
| `strategy` | Strategic directions, goals, actions | Annual (or on change) | PDF preferred, HTML fallback |
| `foundational` | Vision, Mission, Values, Purpose — and labels used | On change | HTML preferred, PDF fallback |
| `executives` | CEO, CNO, COS, VPs and equivalent leadership | Monthly | HTML |
| `board` | Board chair, vice chair, directors; ex-officio overlap with executives | 6-month (post-September elections) | HTML |
| `minutes` | Board meeting minutes documents | Monthly | PDF archive |

### 3.2 The Minutes Role — Detail

The minutes role differs from the others in that it manages a **document archive** rather than a current snapshot.

- **Initial run:** Downloads all historically available board minutes from each hospital website — backlog may span several years depending on what the site makes available.
- **Subsequent runs:** Downloads only minutes posted since the last successful run date.
- **Storage:** PDFs saved to a dated folder structure per hospital (`roles/minutes/outputs/pdfs/<FAC>_<NAME>/`). Text extraction is deferred — the role downloads and stores only; analysis is handled separately.
- **Status tracking:** Document-level index per hospital rather than a single `last_extraction_date`. The registry status block for this role tracks `last_run_date`, `documents_downloaded`, `earliest_document_date`, and `latest_document_date`.
- **Scope separation:** The board role tracks current board membership. The minutes role is about the documents themselves — parsing membership from minutes is an analysis-layer concern, not an extraction-layer concern.

### 3.3 Core Module Responsibilities

| Module | Responsibility |
|---|---|
| `registry.R` | Load hospital list from YAML; look up by FAC; update per-role status sections; write YAML; expose `get_hospitals_due(role, date)`. The ONLY module that writes to YAML. |
| `fetcher.R` | HTTP GET with retries; PDF download; HTML retrieval as rvest object; content type detection; configurable rate limiting; robots.txt checking with manual override flag. Returns structured result objects. |
| `crawler.R` | Start from base URL; extract and score links against tier-1/tier-2 keywords; follow links to configurable depth; separate PDF vs HTML handling; track visited URLs. Returns ranked candidate list — does not decide which is correct. |
| `claude_api.R` | Load and populate prompt templates; accept text or PDF (base64 images); API call with retry/backoff; token usage and cost tracking; budget alerts; audit log per call. Does NOT parse Claude responses — that stays in each role. |
| `logger.R` | Timestamped log entries at INFO/WARNING/ERROR levels; role-specific log files; run summary (hospitals attempted, succeeded, failed, cost); CSV of failures for manual review. |

### 3.4 Role Module Pattern

Every role's `extract.R` follows the same seven-step pattern, with differences confined to `config.R` and the prompt file:

1. Call `registry.R` to get hospitals due for this role
2. Call `crawler.R` with role keywords to find candidate URLs
3. Call `fetcher.R` to retrieve content
4. Call `claude_api.R` with role prompt and content
5. Parse Claude's response into the role-specific schema
6. Call `registry.R` to write results back to YAML
7. Call `logger.R` to record the outcome

The minutes role follows a simplified version of this pattern — it uses `fetcher.R` directly without a Claude API call, since the goal is document download rather than content extraction.

### 3.5 Fetcher Result Object

All `fetcher.R` functions return a consistent structured object. Role modules always check `result$success` first before doing anything with the content.

```r
list(
  success       = TRUE/FALSE,
  fac           = "592",
  url           = "https://...",
  content       = <rvest object or text string or NULL>,
  content_type  = "html" / "pdf" / "unknown",
  skip_reason   = NULL / "robots_disallowed" / "http_error" / "pdf_too_large" / "request_error",
  error_message = NULL / "HTTP 404" / <error text>,
  metadata      = list(status_code = 200, file_size_bytes = 12345, local_path = "..."),
  fetched_at    = "2026-03-01 10:23:45"
)
```

---

## 4. Development Sequence

Build order is determined by dependencies. Core modules are built and tested before any role module is started.

| Module | What it enables | Build order | Depends on |
|---|---|---|---|
| `core/registry.R` | YAML access for all modules; FAC lookups; due-date logic | **1 — first** | nothing |
| `core/fetcher.R` | All HTTP work; robots.txt; rate limiting | **1 — first** | nothing |
| `core/crawler.R` | Website navigation; link scoring | **2 — second** | fetcher.R |
| `core/claude_api.R` | API calls; cost tracking; prompt loading | **2 — second** | fetcher.R |
| `core/logger.R` | Consistent logs across all roles | **2 — second** | nothing |
| `roles/strategy/` | First working role; migrates existing extraction scripts | **3 — third** | all core |
| `roles/foundational/` | Second role; similar crawl pattern to strategy | **3 — third** | all core |
| `roles/executives/` | HTML-focused; tests non-PDF path in core | **4** | all core |
| `roles/board/` | HTML-focused; validates executive/board overlap handling | **4** | all core |
| `roles/minutes/` | Archive pattern; no Claude API call; PDF download only | **4 — last role** | all core |
| `orchestrate/run_all.R` | Ties all roles together; scheduling | **5 — last** | all role modules |

---

## 5. Key Constraints and Principles

### 5.1 Data Integrity

- FAC code is the primary key across all data — every record in every output must carry the FAC code for downstream joining.
- `registry.R` is the only module that writes to YAML — no other script touches the registry files directly.
- Manual overrides are tracked explicitly in YAML with `override_reason` fields. They are not treated as errors.

### 5.2 Ethical Scraping

- `robots.txt` is checked and honoured for every domain before crawling.
- A configurable delay (default 2 seconds) between requests is enforced in `fetcher.R`.
- A manual override flag exists per hospital for cases where explicit permission has been obtained.
- Maximum pages per crawl session is capped in `crawler.R` to avoid overwhelming hospital servers.

### 5.3 Cost Management

- All API calls are logged with token counts and cost in `claude_api.R`.
- A session budget alert threshold is configurable — the workflow warns before the budget is exceeded.
- Change detection should be used in refresh cycles to avoid re-processing unchanged content.
- The minutes role has no API cost — it downloads documents only.

---

## 6. Build Status

### Completed

| Module | Status | Notes |
|---|---|---|
| `registry/hospital_registry.yaml` | ✅ Complete | Consolidated from two legacy files; migration script in `dev/` |
| `core/registry.R` | ✅ Complete | All functions built and tested against real data |
| `core/fetcher.R` | ✅ Complete | HTML and PDF fetch tested against FAC 592 |

### In Progress / Up Next

| Module | Status | Notes |
|---|---|---|
| `core/crawler.R` | 🔲 Next | Depends on fetcher.R — ready to build |
| `core/claude_api.R` | 🔲 Next | Can be built in parallel with crawler.R |
| `core/logger.R` | 🔲 Next | No dependencies — can be built any time |

### Not Started

- `roles/strategy/`, `roles/foundational/`, `roles/executives/`, `roles/board/`, `roles/minutes/`
- `orchestrate/run_all.R`

---

## 7. Existing Assets to Migrate

| Existing file | Migrates to | Notes |
|---|---|---|
| `extraction_workflow_v3_no_batching.R` | `roles/strategy/extract.R` | Significant refactor — split into core + role |
| `api_functions_with_images.R` | `core/claude_api.R` | Core API logic migrates here |
| `pdf_image_processor.R` | `core/fetcher.R` | PDF-to-image logic migrates here |
| `progress_functions.R` | `core/logger.R` | Progress tracking migrates here |
| `config_v2.R` | `roles/strategy/config.R` + core paths | Split: role config vs global paths |
| `Phase3_L1_Extraction_V4.1.txt` | `roles/strategy/prompts/strategy_l1.txt` | Rename and move |

---

## 8. Open Design Decisions

- **`leadership_url` field** — currently top-level in the registry, serving as a general-purpose seed URL for executives, board, and foundational crawling. Revisit when building `roles/executives/` — per-role URL fields may be more appropriate depending on crawling behaviour observed.
- **Minutes backlog depth** — "all available" is the intent for the initial run; in practice this is constrained by what each hospital's website exposes. No year cap has been set — revisit if backlog volume becomes a practical problem.
