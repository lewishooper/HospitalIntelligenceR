# HospitalIntelligenceR
## Session Summary — Phase 2 Full Run & Validation
*March 27, 2026 | For Claude Project Knowledge Repository*

---

## 1. Session Overview

This session completed Phase 2 validation across all three input paths (PDF, HTML, TXT), resolved a persistent type-mismatch bug in the master CSV merge, and executed the first full 129-hospital Phase 2 run. The run completed successfully in 44.6 minutes at a cost of $3.04. 113 of 129 hospitals succeeded on first pass (87.6%).

---

## 2. Bug Fixed — Master CSV Type Mismatch

The `strategy_master.csv` merge block in `phase2_extract.R` failed across three successive runs due to type inference mismatches when `read.csv()` loaded the existing master. The errors surfaced one column at a time:

1. `fac` — loaded as integer, new rows were character
2. `plan_period_start` — loaded as integer (year values like 2024), new rows were character
3. `direction_number` — loaded as character (after `colClasses = "character"` fix), new rows were integer
4. A stray `}` bracket was introduced during incremental patching, causing a parse error

**Final fix applied** in `roles/strategy/phase2_extract.R` Step 4:

```r
existing <- read.csv(master_path, stringsAsFactors = FALSE,
                     colClasses = "character")
existing$direction_number <- suppressWarnings(as.integer(existing$direction_number))
```

All columns read as character to suppress type inference; `direction_number` explicitly restored to integer before `bind_rows()`. This is the only integer column in the schema. Fix is stable — confirmed across two clean runs.

---

## 3. Input Path Validation — All Three Paths Confirmed

All three input paths were validated before the full run.

| Path | FAC | Hospital | Result | Notes |
|------|-----|----------|--------|-------|
| PDF | 592 | Lennox & Addington | ✅ Full | 3 directions |
| HTML | 932 | Bruyère Health | ✅ Partial | 5 directions, vision truncated |
| HTML | 936 | London Health Sciences | ✅ Full | 3 directions + 3 enablers correctly classified |
| HTML | 850 (original) | Runnymede HC | ⚠️ Thin | Image-embedded HTML — content problem not pipeline problem |
| TXT | 850 (re-run) | Runnymede HC | ✅ Partial | 4 directions after manual text capture |
| TXT | 900 | Fort Frances Riverside | ⚠️ Thin | 350-character fragment only |

**FAC 850 registry update:** `extraction_status` changed from `html_only` to `downloaded`; `local_filename` updated to `Strategy_202512_850.txt`; `content_type` updated to `txt`. This routes the pipeline to the local file rather than the live URL.

**HTML path note:** FAC 850's registry contains a `local_filename` entry (a browser-print PDF) but the pipeline correctly ignores it when `extraction_status == "html_only"`. After the registry update the TXT file is used instead.

---

## 4. Full Run Results

**Run ID:** 20260327_195516
**Attempted:** 129 | **Succeeded:** 113 | **Failed:** 16
**Success rate:** 87.6%
**Total cost:** $3.04
**Elapsed:** 44.6 minutes

### Quality breakdown

| extraction_quality | source_type | Hospitals | Directions |
|--------------------|-------------|-----------|------------|
| full | pdf | 74 | 359 |
| full | html | 1 | 6 |
| partial | pdf | 17 | 72 |
| partial | html | 1 | 5 |
| partial | txt | 3 | 12 |
| thin | pdf | 16 | 28 |
| thin | txt | 1 | 4 |
| **TOTAL usable (full + partial)** | | **96** | **454** |

96 hospitals with usable structured content on first pass. 17 thin are primarily image-based PDFs or wrong-document downloads — expected and addressable in the fine-tuning pass.

---

## 5. The 16 Failed FACs

### 5a — Content Read Errors (13): File Not Found on Disk

The registry points to files that do not exist at the expected path. Many have `_HTML.pdf` suffixes indicating browser-print PDFs that were registered but never saved to disk.

| FAC | Hospital | Missing File |
|-----|----------|-------------|
| 619 | Brockville General | Strategy_202512_619_HTML.pdf |
| 732 | Kemptville District | Strategy_202512_732_HTML.pdf |
| 745 | Orillia Soldiers Memorial | Strategy_202512_745_HTML.pdf |
| 771 | Peterborough Regional Health Centre | Strategy_202512_771.pdf |
| 800 | Hawkesbury District General | Strategy_202512_800_HTML.pdf |
| 854 | Toronto Salvation Army Grace | Strategy_202512_854.pdf |
| 938 | Dysart et al Haliburton Health Services | Strategy_202512_938.pdf |
| 939 | Toronto Holland Bloorview Kids | 939_20260101.pdf |
| 958 | Ottawa The Ottawa Hospital | 958_20260323.pdf |
| 968 | Huntsville Muskoka Algonquin HC | 968_20260323.pdf |
| 969 | Ontario Shores | 969_20260322.pdf |
| 971 | Sudbury St. Joseph's Continuing Care | Strategy_202512_971.pdf |
| 977 | Terrace Bay North of Superior HC | Strategy_202512_977.pdf |

**Action:** Locate or re-acquire each file and place in the correct folder, or update the registry to the correct filename. Re-run as a batch once resolved.

### 5b — Parse Errors (3): Claude Responded in Prose Instead of JSON

These three hospitals had near-empty or unreadable PDF text. Claude ignored the JSON-only instruction and responded in prose ("I don't see any document content" / "I notice that the text you've provided"). `fromJSON()` then failed on the prose response.

| FAC | Hospital |
|-----|----------|
| 648 | (to be confirmed from registry) |
| 650 | (to be confirmed from registry) |
| 941 | (to be confirmed from registry) |

**Root cause:** The `.is_text_usable()` threshold (200 non-whitespace characters) is not preventing the API call — these documents are passing the threshold with garbage characters but containing no real text.

**Fix required in `phase2_extract.R`:** Short-circuit to a `thin` result before calling the API when text is below a higher meaningful threshold, rather than sending it to Claude and hoping the JSON instruction holds. See Section 7, Priority 1.

---

## 6. Thin Hospital Triage

17 hospitals returned `extraction_quality = "thin"`. Categorised by cause:

### Empty or whitespace PDF (wrong file or failed download)
FACs: 666, 282, 826, 890, 907, 964
- Document appears empty or contains only whitespace/formatting characters
- Action: Locate correct strategic plan document and re-download

### Wrong document type downloaded
FACs: 656, 963 (org chart — same Wellington Health Care Alliance file registered twice), 704 (Multi-Year Accessibility Plan), 718 (Strategic Energy Management Plan), 736 (Annual Report 2023-24 — new plan in development), 942 (Accessibility Plan), 959 (Energy Conservation Plan)
- Action: Manual search for actual strategic plan document; update registry

### Press release or plan fragment
FACs: 199 (press release announcing plan), 900 (350-character fragment)
- Action: Locate full plan document

### Incomplete scan / blank pages
FAC: 946 (South Bruce Grey — vision present but mission/values on blank pages)
- Action: Review PDF; may need re-download or image-mode

**Note:** FACs 656 and 963 both return identical org chart extraction notes for Wellington Health Care Alliance. Registry likely has the same wrong file registered for two separate FAC entries — check YAML.

---

## 7. Next Session Action Plan

### Priority 1 — Parse-error guard fix in `phase2_extract.R`

Add a short-circuit in the hospital processing loop: if `.is_text_usable()` returns FALSE (or a new higher threshold is not met), write a `thin` result row directly without calling the API. This prevents prose responses from breaking JSON parsing.

Proposed logic after the `.is_text_usable()` check:

```r
if (!.is_text_usable(content_result$text)) {
  # Write thin result directly — do not call API
  df <- .build_thin_row(fac, source_type, Sys.Date(),
                        "Text too short or empty — skipped API call")
  # write CSV, update registry, log, next
}
```

A `.build_thin_row()` helper constructs a single-row data frame with all plan-level fields as NA and `extraction_quality = "thin"`.

### Priority 2 — Resolve the 13 missing-file FACs

For each FAC in the file-not-found list:
1. Check what is actually on disk in the expected folder
2. If a file exists under a different name, update `local_filename` in the registry
3. If no file exists, re-acquire (re-download PDF or re-capture HTML/TXT)
4. Confirm `extraction_status` is set correctly (`downloaded` not `html_only` for local files)

### Priority 3 — Re-run all 16 failed FACs

Once Priority 1 and 2 are addressed:

```r
TARGET_MODE <- "facs"
TARGET_FACS <- c("619","648","650","732","745","771","800",
                 "854","938","939","941","958","968","969","971","977")
source("roles/strategy/phase2_extract.R")
```

### Priority 4 — Thin hospital triage

Work through the 17 thin hospitals category by category:
- Empty PDFs: locate correct files
- Wrong document type: manual search and registry update
- Fragments: locate full document
- After re-acquisition, re-run as a batch

### Priority 5 — HTML hospital manual review

Two HTML-sourced hospitals are in the master. A third (FAC 850) was converted to TXT.

```r
master[master$source_type == "html",
       c("fac", "hospital_name_self_reported", "extraction_quality", "extraction_notes")] |>
  unique()
```

Review FAC 932 (Bruyère) truncated vision and FAC 936 (LHSC) nested heading format — both are fine-tuning pass candidates, not blockers.

### Priority 6 — Fine-tuning pass planning

Once the re-runs are complete, assess remaining thin hospitals for image-mode retry candidates. Review FAC 936 nested heading format issue for a prompt update.

---

## 8. Files Changed This Session

| File | Change |
|------|--------|
| `roles/strategy/phase2_extract.R` | Fixed Step 4 master CSV merge: `colClasses = "character"` + `direction_number` integer coercion. Resolved stray bracket from incremental patching. |
| `hospital_registry.yaml` | FAC 850: `extraction_status` → `downloaded`; `local_filename` → `Strategy_202512_850.txt`; `content_type` → `txt`; `override_reason` updated |

---

## 9. Session End Checklist

- [ ] Upload this session summary to project knowledge repository
- [ ] Upload updated `roles/strategy/phase2_extract.R` to project knowledge repository
- [ ] Push all changes to GitHub
- [ ] Close YAML file in RStudio before next session begins
