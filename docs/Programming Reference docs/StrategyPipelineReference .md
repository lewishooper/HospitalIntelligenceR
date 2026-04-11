# HospitalIntelligenceR — Strategy Pipeline: Full Step Reference
*Last Updated: April 2026 | For Claude Project Knowledge Repository*

This document describes every step in the strategy pipeline from initial document
discovery through analytical reporting. It includes all patches and corrections
applied to date, and the purpose of each step. For historical findings from
specific audit runs, see the relevant session summaries and patch log CSVs.

---

## PHASE 1 — Locate & Download

### Step 1 — Web crawl and download (`roles/strategy/extract.R`)

**Purpose:** For each hospital in the registry, find and download its strategic
plan document. Starting from `base_url` (or `strategy_url` if set), the crawler
scores outbound links against strategic plan keywords, follows high-scoring links
up to depth 2, and downloads the best candidate as a local PDF or saves HTML.

**Inputs:** `registry/hospital_registry.yaml`

**Outputs:**
- `roles/strategy/outputs/pdfs/<FAC_FOLDER>/<FAC>_<YYYYMMDD>.pdf` (or .txt / .html)
- Registry updated: `local_filename`, `content_url`, `extraction_status: downloaded`

**Key registry fields written:**
- `content_url` — source URL always recorded even for manual downloads
- `local_filename` — filename on disk; Phase 2 uses this to find the file
- `extraction_status: downloaded` — signals file is ready for Phase 2
- `manual_override: yes` — set when human intervention was required
- `force_image_mode: yes` — set when PDF has broken fonts
- `strategy_url` — optional direct seed URL bypassing home-page crawl

**Notes:**
- Robots-blocked hospitals are excluded and tracked separately
- Version-safe filenames (`_v2`, `_v3`) preserve older plans for longitudinal use
- URL spaces encoded via `gsub(" ", "%20", url, fixed = TRUE)` — not `URLencode()`
- For hospitals where the plan is an image PDF embedded in HTML with no
  downloadable file, manual OCR capture to `.txt` is the fallback path;
  set `content_type: txt` and `manual_override: yes` in YAML

**When adding or replacing a plan document**, follow the procedure in
`docs/programming_reference/SOP_new_strategic_plan.md`.

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

**Content-reading paths:**
- `.pdf` → `pdftools::pdf_text()` (text mode)
- `.pdf` with broken fonts or `force_image_mode: yes` → `pdf_render_page()` + vision API
- `.txt` → `readLines()`
- `html_only` → live `rvest` fetch from `content_url`

**Image-mode DPI fallback:** 150 → 100 → 72 (triggered on HTTP 413)

**Key prompt rules (strategy_l1.txt):**
- Extract dates from document content only — not file metadata or publication date
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
this output — never directly from the raw extraction. Re-run after any Phase 2
change before running any downstream script.

**Inputs:**
- `roles/strategy/outputs/extractions/strategy_master.csv`
- `registry/hospital_registry.yaml`

**Outputs:**
- `analysis/data/strategy_master_analytical.csv` — direction-level, ~581 rows
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

**When to run:** Once after the full thematic classification run
(`02_thematic_classify.R`). Safe to re-run — corrections matched by FAC +
direction name, idempotent.

**Corrections applied:**
- FAC 882 "Accountability": GOV → FIN primary, FIN → ORG secondary
- FAC 932 "Fostering Bold Leadership": GOV → PAR primary, PAR → RES secondary

**Inputs/Outputs:** Overwrites `analysis/data/theme_classifications.csv` in place.

---

### Step 5 — Plan period date audit (`analysis/scripts/00e_audit_plan_dates.R`)

**Purpose:** Read-only audit of all `plan_period_start` and `plan_period_end`
values. Flags implausible dates that may result from API hallucination or wrong
documents. Review console output and `00e_flagged_dates.csv` before running `00f`.

**Flags checked:**
- Start before 2015 (too old for active plan)
- Start after current year (future)
- Start equals end year (zero-length plan)
- Start after end (impossible)
- Span > 11 years (unusually long)
- End before 2020 (likely expired or wrong document)
- Precise full dates (YYYY-MM-DD) — verify these are explicit in document

**Inputs:** `hospital_spine.csv` + `strategy_master_analytical.csv`
**Output:** Console report + `analysis/outputs/tables/00e_flagged_dates.csv`

*This step is read-only. Do not proceed to `00f` without reviewing its output.*

---

### Step 6 — Plan period date corrections (`analysis/scripts/00f_patch_plan_dates.R`)

**Purpose:** Apply confirmed corrections to `plan_period_start` /
`plan_period_end` in the analytical outputs. Corrections are applied at the
analytical layer — the raw extraction in `strategy_master.csv` is preserved
for audit.

**Logic:** Correction table is maintained inside the script. If both
`new_start_raw` and `new_end_raw` are NA for a FAC, all date fields are
explicitly nulled out. Otherwise individual fields are overwritten.

**Inputs/Outputs:** Overwrites both `strategy_master_analytical.csv` and
`hospital_spine.csv` in place.

**After running:** Re-run `00c`, `03a`, `03b`, `03c`, `04a`, `04b` to rebuild
all downstream outputs.

---

### Step 7 — Missing date recovery (`analysis/scripts/00g_fetch_missing_dates.R`)

**Purpose:** For hospitals with missing `plan_period_start` or `plan_period_end`
after initial extraction, send the document to the Claude API with a targeted
date-focused prompt. Produces a review CSV for human confirmation before any
patch is applied.

**Inputs:**
- `analysis/data/hospital_spine.csv` — identifies hospitals with missing dates
- Local PDF/TXT files from Phase 1

**Output:** `analysis/outputs/tables/00g_date_review.csv` — proposed dates with
confidence ratings and API notes, for human review

*This step is read-only. Review `00g_date_review.csv` before running `00h`.*

---

### Step 8 — Missing date patch (`analysis/scripts/00h_patch_missing_dates.R`)

**Purpose:** Apply confirmed date corrections from the `00g` review to the raw
`strategy_master.csv`. Unlike `00f` (which patches the analytical layer), this
step patches the upstream raw master so that corrections survive a full pipeline
re-run from `00_prepare_data.R`.

**Inputs:**
- `analysis/outputs/tables/00g_date_review.csv` — reviewed and confirmed dates
- `roles/strategy/outputs/extractions/strategy_master.csv`

**Outputs:**
- `roles/strategy/outputs/extractions/strategy_master.csv` — patched in place
- `analysis/outputs/tables/00h_patch_log.csv` — audit log of all changes applied

**After running:** Re-run from `00_prepare_data.R` to rebuild the full
analytical stack.

---

### Step 9 — Build strategy classified (`analysis/scripts/00c_build_strategy_classified.R`)

**Purpose:** Merge `strategy_master_analytical.csv` with `theme_classifications.csv`
to produce the single wide-format analytical table used by all reporting scripts.

**Inputs:**
- `analysis/data/strategy_master_analytical.csv`
- `analysis/data/theme_classifications.csv`

**Output:** `analysis/data/strategy_classified.csv`

---

### Step 10 — Thematic classification (`analysis/scripts/02_thematic_classify.R`)

**Purpose:** Send each strategic direction name to the Claude API for thematic
classification using the 10-code taxonomy. One API call per direction row.

**Active taxonomy (10 codes):**
PAT, WRK, FIN, INN, RES, EDI, PAR, ORG, DIG, ENV, QUA

**Inputs:**
- `analysis/data/strategy_master_analytical.csv`
- `docs/prompts/theme_classify_prompt.txt`

**Output:** `analysis/data/theme_classifications.csv`

**Notes:**
- GOV was initially included but retired after the first full run (see Step 4)
- Classification is on direction name only — not description or key actions
- One primary theme + optional secondary theme per direction
- Use Sonnet (not Opus) for cost efficiency on this task

---

### Step 11 — Plan volume and direction types (`analysis/scripts/01a_plan_volume.R`, `01b_direction_types.R`)

**Purpose:** Descriptive summaries of the extraction corpus — plan counts by
hospital type, direction counts per hospital, and direction type distributions.

**Inputs:** `analysis/data/strategy_classified.csv`
**Outputs:** Figures and summary tables in `analysis/outputs/`

---

### Step 12 — Thematic trends over time (`analysis/scripts/03a_explore_plan_years.R`, `03b_theme_trends.R`)

**Purpose:** Analyse how theme prevalence has shifted across planning eras.
`03a` explores the plan year distribution and defines era boundaries. `03b`
produces theme prevalence by era and generates trend figures.

**Era-assignable cohort:** 114 of 129 hospitals (hospitals with confirmed plan
start dates). The remaining 15 have missing or unresolvable dates and are
excluded from temporal analyses.

**Inputs:** `analysis/data/strategy_classified.csv`, `analysis/data/hospital_spine.csv`
**Outputs:** Figures and summary tables; narrative in `docs/writing_and_research/03b_narrative.md`

---

### Step 13 — Era × hospital type interaction (`analysis/scripts/03c_theme_by_era_type.R`)

**Purpose:** Examine how theme prevalence varies across the combination of
planning era and hospital type group. Includes WRK/RES interaction analysis.

**Inputs:** `analysis/data/strategy_classified.csv`, `analysis/data/hospital_spine.csv`
**Outputs:**
- `analysis/outputs/tables/03c_theme_prevalence_era_type.csv`
- `analysis/outputs/tables/03c_wrk_res_interaction.csv`
- `analysis/outputs/tables/03c_era_type_composition.csv`
- Figures and narrative in `docs/writing_and_research/03c_narrative.md`

---

### Step 14 — Strategic homogeneity (`analysis/scripts/04a_homogeneity.R`)

**Purpose:** Measure how similar Ontario hospitals are in their strategic theme
portfolios. Produces modal theme profiles per hospital type, Jaccard pairwise
similarity across all hospital pairs, and modal match rates.

**Inputs:** `analysis/data/strategy_classified.csv`, `analysis/data/hospital_spine.csv`
**Outputs:**
- `analysis/outputs/tables/04a_breadth_summary.csv`
- `analysis/outputs/tables/04a_core_profile_by_type.csv`
- `analysis/outputs/tables/04a_modal_match_summary.csv`
- `analysis/outputs/tables/04a_jaccard_summary.csv`
- `analysis/outputs/tables/04a_jaccard_pairwise.csv`
- Figures; narrative pending in `docs/writing_and_research/04a_narrative.md`

---

### Step 15 — Distinctive directions and outlier hospitals (`analysis/scripts/04b_unique_strategies.R`)

**Purpose:** Identify strategic directions that stand out as genuinely distinctive,
and hospitals that diverge most from their peer group profiles.

**Inputs:** `analysis/data/strategy_classified.csv`, `analysis/data/hospital_spine.csv`
**Outputs:**
- `analysis/outputs/tables/04b_distinctive_directions.csv`
- `analysis/outputs/tables/04b_theme_outliers.csv`
- `analysis/outputs/tables/04b_peripheral_adopters.csv`
- Figures; narrative pending in `docs/writing_and_research/04b_narrative.md`

---

## SUPPORTING REGISTRY ACTIONS (applied as needed)

These are standing notes on hospitals with non-standard pipeline histories.

### FAC 682 — Hornepayne Community Hospital
- **Status:** No strategic plan available
- **History:** Downloaded document was an HR plan, not a strategic plan.
  Email outreach attempted with follow-up — no response received.
- **YAML:** `extraction_status: complete`, `manual_override: yes`,
  `phase2_status: no_plan`, `needs_review: no`
- **Analytical:** Both date fields nulled via `00f`

### FAC 739 — Nipigon District Memorial Hospital
- **Status:** Extracted via manual OCR path
- **History:** Strategic plan is an image PDF embedded in an HTML page — no
  downloadable file available. Standard text extraction and HTML scraping both
  fail. Manual OCR capture via Windows Clip saved as `.txt`.
- **YAML:** `content_type: txt`, `local_filename: 739_20260409.txt`,
  `manual_override: yes`, `override_reason: Image PDF embedded in HTML — manual OCR capture`

### FAC 946 — Kincardine South Bruce Grey
- **Status:** Extracted via image mode
- **History:** Plan has vision/mission on text pages and strategic priorities
  on image pages. Text-mode extraction was thin; `force_image_mode: yes` set.
- **YAML:** `force_image_mode: yes`, `needs_review: no`

### FAC 953 — Sunnybrook Health Sciences ("Invent 2030")
- **Status:** Date corrected
- **History:** API returned end year (2030) as `plan_period_start`. Correct
  start is 2025.
- **Analytical:** Corrected via `00f`

---

## RECOMMENDED EXECUTION ORDER (full pipeline from scratch)

```r
# Phase 1
TARGET_MODE <- "all"
source("roles/strategy/extract.R")

# Phase 2
TARGET_MODE <- "all"
source("roles/strategy/phase2_extract.R")

# Analytical layer — data preparation and date audit
source("analysis/scripts/00_prepare_data.R")
source("analysis/scripts/00e_audit_plan_dates.R")   # READ-ONLY — review before proceeding
source("analysis/scripts/00f_patch_plan_dates.R")   # update correction table first
source("analysis/scripts/00g_fetch_missing_dates.R") # READ-ONLY — review before proceeding
source("analysis/scripts/00h_patch_missing_dates.R") # patches raw strategy_master.csv
source("analysis/scripts/00_prepare_data.R")         # re-run after 00h

# Classification
source("analysis/scripts/02_thematic_classify.R")
source("analysis/scripts/00d_patch_gov_corrections.R")
source("analysis/scripts/00c_build_strategy_classified.R")

# Reporting scripts
source("analysis/scripts/01a_plan_volume.R")
source("analysis/scripts/01b_direction_types.R")
source("analysis/scripts/03a_explore_plan_years.R")
source("analysis/scripts/03b_theme_trends.R")
source("analysis/scripts/03c_theme_by_era_type.R")
source("analysis/scripts/04a_homogeneity.R")
source("analysis/scripts/04b_unique_strategies.R")
```

**Key rules:**
- `00e` and `00g` are read-only audit steps — review their output before running
  the corresponding patch scripts
- `00h` patches the raw `strategy_master.csv`; always re-run `00_prepare_data.R`
  immediately after
- After any Phase 2 re-run, restart the analytical sequence from `00_prepare_data.R`
- After `00f`, re-run `00c`, `03a`, `03b`, `03c`, `04a`, `04b` to rebuild
  all downstream outputs
