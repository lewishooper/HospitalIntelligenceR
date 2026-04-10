# HospitalIntelligenceR — Strategy Pipeline: Full Step Reference
*April 4, 2026 | For Claude Project Knowledge Repository*

This document describes every step in the strategy pipeline from initial document
discovery through thematic classification. It includes all patches and corrections
applied to date, and the purpose of each step.

---

## PHASE 1 — Locate & Download

### Step 1 — Web crawl and download (`roles/strategy/extract.R`)

**Purpose:** For each hospital in the registry, find and download its strategic
plan document. Starting from `base_url` (or `strategy_url` if set), the crawler
scores outbound links against strategic plan keywords, follows high-scoring links
up to depth 2, and downloads the best candidate as a local PDF or saves HTML.

**Inputs:** `registry/hospital_registry.yaml`

**Outputs:**
- `roles/strategy/outputs/<FAC_FOLDER>/<FAC>_<YYYYMMDD>.pdf` (or .txt / .html)
- Registry updated: `local_filename`, `content_url`, `extraction_status: downloaded`

**Key registry fields written:**
- `content_url` — source URL always recorded even for manual downloads
- `local_filename` — filename on disk; Phase 2 uses this to find the file
- `extraction_status: downloaded` — signals file is ready for Phase 2
- `manual_override: yes` — set when human intervention was required
- `force_image_mode: yes` — set when PDF has broken fonts (e.g. FAC 946, 959)
- `strategy_url` — optional direct seed URL bypassing home-page crawl

**Notes:**
- Robots-blocked hospitals are excluded and tracked separately
- Version-safe filenames (`_v2`, `_v3`) preserve older plans for longitudinal use
- URL spaces encoded via `gsub(" ", "%20", url, fixed = TRUE)` — not `URLencode()`

---

## PHASE 2 — Extract & Structure

### Step 2 — Claude API extraction (`roles/strategy/phase2_extract.R`)

**Purpose:** For each hospital with a local file, read the document content and
send it to the Claude API with a structured extraction prompt. Parse the JSON
response into long-format rows (one row per strategic direction).

**Inputs:**
- Local files from Phase 1 (PDF, TXT, or HTML)
- `roles/strategy/prompts/strategy_l1.txt` — extraction prompt
- `registry/hospital_registry.yaml` — for file paths and flags

**Outputs:**
- `roles/strategy/outputs/extractions/<FAC>_extracted.csv` — per-hospital
- `roles/strategy/outputs/extractions/strategy_master.csv` — all hospitals combined
- Registry updated: `phase2_status`, `phase2_quality`, `phase2_n_dirs`, `phase2_date`

**Three content-reading paths:**
- `.pdf` → `pdftools::pdf_text()` (text mode)
- `.pdf` with broken fonts or `force_image_mode: yes` → `pdf_render_page()` + vision API
- `.txt` / `.csv` → `readLines()`
- `html_only` → live `rvest` fetch from `content_url`

**Image-mode DPI fallback:** 150 → 100 → 72 (triggered on HTTP 413)

**Key prompt rules (strategy_l1.txt):**
- Extract dates FROM document content only — not file metadata or publication date
- If only end year stated (e.g. "Vision 2030"), return null for start, not a guess
- Do not infer or calculate start year from any metadata
- Return null rather than guess for any missing field

**Registry flags that affect Phase 2 behaviour:**
- `force_image_mode: yes` — bypass text usability check, always use vision API
- `manual_override: yes` + `extraction_status: complete` — skip reprocessing
- `extraction_status: downloaded` — eligible for processing

---

## ANALYTICAL LAYER

### Step 3 — Data preparation (`analysis/scripts/00_prepare_data.R`)

**Purpose:** Join Phase 2 extraction output with registry reference fields to
build the canonical analytical master dataset. All downstream scripts read from
this output — never directly from the raw extraction.

**Inputs:**
- `roles/strategy/outputs/extractions/strategy_master.csv`
- `registry/hospital_registry.yaml`

**Outputs:**
- `analysis/data/strategy_master_analytical.csv` — direction-level, ~580 rows
- `analysis/data/hospital_spine.csv` — hospital-level, one row per hospital

**Key transformations:**
- `plan_period_start` / `plan_period_end` parsed from raw strings (YYYYMMDD,
  ISO, and 4-digit year-only formats); raw strings retained as `_raw` fallback
- 7 hospital types collapsed to 4 analytical groups via `hospital_type_map`
- `plan_start_year` derived from parsed start date (used in temporal analysis)
- `plan_period_parse_ok` flag marks rows where start date parsed successfully

---

### Step 4 — GOV reclassification patch (`analysis/scripts/00d_patch_gov_corrections.R`)

**Purpose:** Apply manual corrections for two directions misclassified as GOV
(governance). GOV was retired from the taxonomy after the full classification run
revealed it was triggering incorrectly on label text rather than content.

**When to run:** Once after the full thematic classification run (`02_thematic_classify.R`).
Safe to re-run — corrections matched by FAC + direction name, idempotent.

**Corrections applied:**
- FAC 882 "Accountability": GOV → FIN primary, FIN → ORG secondary
- FAC 932 "Fostering Bold Leadership": GOV → PAR primary, PAR → RES secondary

**Inputs/Outputs:** Overwrites `analysis/data/theme_classifications.csv` in place.

---

### Step 5 — Plan period date audit (`analysis/scripts/00e_audit_plan_dates.R`)

**Purpose:** Read-only audit of all plan_period_start and plan_period_end values.
Flags implausible dates that may result from API hallucination or wrong documents.

**Flags checked:**
- Known correction (FAC 953)
- Start before 2015 (too old for active plan)
- Start after current year (future)
- Start equals end year (zero-length)
- Start after end (impossible)
- Span > 11 years (unusually long — threshold set after confirming legitimate 10-year plans)
- End before 2020 (likely expired/wrong document)
- Precise full dates (YYYY-MM-DD) — verify these are explicit in document

**Inputs:** `hospital_spine.csv` + `strategy_master_analytical.csv` (joined for raw strings)
**Output:** Console report + `analysis/outputs/tables/00e_flagged_dates.csv`

**Findings from April 4 audit:**
- FAC 953: start was 2030 (end date) — corrected to 2025
- FAC 682: dates from wrong document — nulled out
- FACs 606, 632, 736, 858: 9–10 year spans confirmed legitimate in documents
- FACs 726, 939: 7-year spans confirmed legitimate
- FACs 732, 739, 946: thin extractions but dates confirmed from real content
- FAC 973: 2015–2018 plan is genuinely old — legitimate historical plan
- FAC 980: 2019–2026 plan not yet expired — legitimate

---

### Step 6 — Plan period date corrections (`analysis/scripts/00f_patch_plan_dates.R`)

**Purpose:** Apply confirmed corrections to plan_period_start / plan_period_end
in the analytical outputs. Corrections applied here rather than by re-running
Phase 2 — raw extraction is preserved for audit; analytical layer is corrected.

**Corrections applied:**
- FAC 953: start `2030` → `2025` (API hallucinated end year as start)
- FAC 682: both dates nulled out (wrong document, no plan available)

**Logic:** If both new_start_raw and new_end_raw are NA for a FAC, all date
fields are explicitly nulled out (not skipped). Otherwise individual fields
are overwritten.

**Inputs/Outputs:** Overwrites both `strategy_master_analytical.csv` and
`hospital_spine.csv` in place.

**After running:** Re-run `00c`, `03a`, `03b` to rebuild downstream outputs.

---

### Step 7 — Build strategy classified (`analysis/scripts/00c_build_strategy_classified.R`)

**Purpose:** Merge `strategy_master_analytical.csv` with `theme_classifications.csv`
to produce the single wide-format analytical table used by all reporting scripts.

**Inputs:**
- `analysis/data/strategy_master_analytical.csv`
- `analysis/data/theme_classifications.csv`

**Output:** `analysis/data/strategy_classified.csv`

---

### Step 8 — Thematic classification (`analysis/scripts/02_thematic_classify.R`)

**Purpose:** Send each strategic direction name to the Claude API for thematic
classification using the 11-code taxonomy. One API call per direction row.

**Taxonomy (11 codes):**
PAT, WRK, FIN, INN, RES, EDI, PAR, ORG, DIG, ENV, QUA

**Inputs:**
- `analysis/data/strategy_master_analytical.csv`
- `analysis/scripts/theme_classify_prompt.txt`

**Output:** `analysis/data/theme_classifications.csv`

**Notes:**
- GOV was initially included but retired after the first full run (see Step 4)
- Classification is direction-name only — not description or key actions
- One primary theme + optional secondary theme per direction

---

## SUPPORTING REGISTRY ACTIONS (applied as needed)

### FAC 682 — Hornepayne Community Hospital
- **Status:** No strategic plan available
- **History:** Downloaded document was an HR plan, not a strategic plan.
  Email outreach attempted with follow-up — no response received.
- **YAML:** `extraction_status: complete`, `manual_override: yes`,
  `phase2_status: no_plan`, `needs_review: no`
- **Analytical:** Both date fields nulled via `00f`

### FAC 946 — Kincardine South Bruce Grey
- **Status:** Thin extraction — correct document, image-mode pages
- **History:** Clear 2026–2030 plan with vision/mission on text pages;
  strategic priorities on image pages not captured by text extraction.
- **YAML:** `force_image_mode: yes` added, `needs_review: no`
- **Next action:** Targeted Phase 2 re-run

### FAC 953 — Sunnybrook ("Invent 2030")
- **Status:** Corrected
- **History:** API returned end year (2030) as plan_period_start.
  Correct start is 2025.
- **Analytical:** Corrected via `00f` in `strategy_master_analytical.csv`
  and `hospital_spine.csv`

---

## RECOMMENDED EXECUTION ORDER (full pipeline from scratch)

```r
# Phase 1
TARGET_MODE <- "all"
source("roles/strategy/extract.R")

# Phase 2
TARGET_MODE <- "all"
source("roles/strategy/phase2_extract.R")

# Analytical layer
source("analysis/scripts/00_prepare_data.R")
source("analysis/scripts/00e_audit_plan_dates.R")   # review output before proceeding
source("analysis/scripts/00f_patch_plan_dates.R")
source("analysis/scripts/02_thematic_classify.R")
source("analysis/scripts/00d_patch_gov_corrections.R")
source("analysis/scripts/00c_build_strategy_classified.R")
source("analysis/scripts/01a_plan_volume.R")
source("analysis/scripts/01b_direction_types.R")
source("analysis/scripts/03a_explore_plan_years.R")
source("analysis/scripts/03b_theme_trends.R")
```

*Note: `00e` is read-only — review console output and update `00f` corrections
table before running `00f`. After any Phase 2 re-run, restart from `00_prepare_data.R`.*
