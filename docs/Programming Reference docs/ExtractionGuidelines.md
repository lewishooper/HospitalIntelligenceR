# Extraction Guidelines
## HospitalIntelligenceR

*Last Updated: March 2026*

---

## 1. Purpose

This document outlines the general purpose and guidelines for extracting data from Ontario hospital websites. It covers all five extraction roles, shared principles, and known issues. It does not contain implementation code — that lives in the role modules under `roles/`.

---

## 2. Registry

The single source of truth for hospital data is `registry/hospital_registry.yaml`. It contains all 133 Ontario hospitals with the following structure per entry:

```yaml
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
    strategy: { ... }
    foundational: { ... }
    executives: { ... }
    board: { ... }
    minutes: { ... }
```

The FAC code is the primary key across all data. Every output record from every role must carry the FAC code for downstream joining. Only `core/registry.R` may write to this file.

---

## 3. Extraction Roles

The five roles are independent and run on different cadences. They share core infrastructure but have separate code, prompts, and outputs.

### Role 1: Strategic Plans (`strategy`)

**Goal:** Extract the hospital's current strategic plan — the dates covered, key directions, descriptive text for each direction, and planned actions.

**Cadence:** Annual, or when a new plan is detected.

**Preferred source:** Downloadable PDF. HTML fallback if no PDF is available.

**Notes:** Strategic plans are commonly presented as both a web page and a downloadable PDF. The PDF is always preferred as it contains the complete formatted document. Approximately 80% of hospitals have a discoverable PDF via automated crawling; the remainder require manual URL provision.

---

### Role 2: Foundational Documents (`foundational`)

**Goal:** Extract foundational guiding documents — Vision, Mission, Values, and any equivalents (Purpose, Principles, Strategic Priorities, etc.) — including the exact labels used by each hospital.

**Cadence:** On change (checked annually at minimum).

**Preferred source:** Hospital website HTML. PDF fallback (e.g. from strategic plan) if not available on the website.

**Notes:** Hospitals vary in what they call these documents. The extraction must capture the label used, not assume standard terminology. Vision/Mission/Values is the most common pattern but is not universal.

---

### Role 3: Executive Team (`executives`)

**Goal:** Extract current executive team members — names, titles, and roles. Typically includes CEO, CNO, COS, and Vice Presidents. Smaller hospitals may include Directors and Managers.

**Cadence:** Monthly.

**Preferred source:** Hospital website HTML (leadership or about page).

**Notes:** The `leadership_url` field in the registry is the recommended starting point for crawling. Larger hospitals separate executive and board lists; smaller hospitals may combine them. See overlap note in Section 4.

---

### Role 4: Board of Directors (`board`)

**Goal:** Extract current board membership — Board Chair, Vice Chair, and directors. Track changes on a six-month basis following September board elections.

**Cadence:** 6-month (post-September elections).

**Preferred source:** Hospital website HTML.

**Notes:** The CEO, CNO, and COS are ex-officio board members and will appear in both the executives and board lists for larger hospitals. In smaller hospitals, a single combined list may serve both roles. See overlap note in Section 4.

---

### Role 5: Board Meeting Minutes (`minutes`)

**Goal:** Download and archive all available board meeting minutes as PDFs. Track new documents on a monthly basis.

**Cadence:** Monthly. Initial run downloads all historically available minutes; subsequent runs download only documents posted since the last successful run.

**Preferred source:** PDF (board minutes are almost always published as PDFs).

**Content handling:** Download and store only. Text extraction and analysis are deferred to the analysis layer — this role is an archive, not a parser.

**Storage structure:** `roles/minutes/outputs/pdfs/<FAC>_<NAME>/` with filenames preserving the original document date where determinable.

**Status tracking:** Document-level — the registry tracks `last_run_date`, `documents_downloaded`, `earliest_document_date`, and `latest_document_date` rather than a single extraction status.

**Notes:** The minutes role has no Claude API cost — it downloads documents only. The depth of historical backlog varies by hospital; some sites keep only 12 months of archives, others keep many years.

---

## 4. Known Overlaps and Issues

### Strategic Plans and Foundational Documents

Many hospitals include Vision, Mission, and Values within their strategic plan PDF as well as on their website. The website is always the preferred source for foundational documents. Extraction from the strategic plan PDF is a fallback only.

### Executives and Board of Directors

In larger hospitals, CEO, CNO, and COS appear on both the executive list and the board list as ex-officio members. In smaller hospitals, a single combined list may contain both executives and board members. Role modules should handle this gracefully — do not treat duplicate appearances as errors.

### Minutes and Board Membership

Board minutes may contain information about board membership changes. Parsing membership from minutes is an analysis-layer concern and is out of scope for the minutes extraction role.

---

## 5. Overall Extraction Principles

**robots.txt compliance:** The extraction process checks and honours `robots.txt` rules for every domain before crawling. A per-hospital override flag exists in the registry for cases where explicit permission has been obtained from the hospital.

**Rate limiting:** A configurable delay (default 2 seconds) is enforced between all outbound requests in `core/fetcher.R`. Maximum pages per crawl session is capped in `core/crawler.R`.

**Structured results:** All fetch operations return a consistent result object with a `success` flag. Role modules always check `result$success` before processing content — robots blocks, HTTP errors, and timeouts are all handled through the same code path.

**Cost awareness:** All Claude API calls are logged with token counts and estimated cost. A configurable budget alert threshold warns before session spend is exceeded. The minutes role incurs no API cost.

**FAC code integrity:** Every output record carries the FAC code. This is non-negotiable — it is the join key for all downstream analysis.

**Manual overrides:** Hospitals that cannot be auto-scraped carry an explicit `manual_override` status in the registry with a documented reason. These are not treated as failures.

---

## 6. Implementation Environment

- **Language:** R, using RStudio
- **Project root:** `E:/HospitalIntelligenceR`
- **API:** Claude API via `core/claude_api.R`
- **Registry:** `registry/hospital_registry.yaml` — single file, single writer (`core/registry.R`)
- **Documentation:** All docs in `docs/` as markdown files
