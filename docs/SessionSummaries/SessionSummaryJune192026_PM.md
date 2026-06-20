# Session Summary — June 19, 2026 (Afternoon)
# Board Minutes Role — Phase 2, Tier 1: Classifier Review and extract_minutes.R Design

---

## Next Session — Start Here

**Current priority:** Design and build `extract_minutes.R` — a page-boundary-based
extractor to replace the structural keyword classifier in `minutes_classify.R`.

Before writing any code, the next session should begin with a short design session
to establish:

1. The definitive header keyword list (from ReviewFile.R evidence)
2. The definitive end-marker keyword list
3. The output schema for the replacement audit file
4. Confirmation that the extractor will be folder-driven, not index-driven

**Also pending from this session — execute before or during next session:**

### Classifier patch: Board Highlights format (READY TO EXECUTE)

FACs 644 and 967 (Cornwall hospitals) publish "Board Highlights" — narrative
summaries without attendance or motion blocks. Currently classified as `agenda`
(incorrect). Two changes to `minutes_classify.R` are designed and ready:

**Change A — Add `detect_board_highlights()` after `detect_report_lead()`:**

```r
detect_board_highlights <- function(text) {
  title_text <- str_to_lower(str_sub(text, 1, 300))
  str_detect(title_text, "board highlights")
}
```

**Change B — Add early exit in `classify_document()` after the `needs_ocr` block:**

```r
  if (detect_board_highlights(text)) {
    return(list(
      doc_class      = "summary_minutes",
      corpus_include = TRUE,
      has_header     = TRUE,
      has_attendance = FALSE,
      has_motions    = FALSE,
      has_close      = FALSE,
      has_consent    = FALSE,
      meeting_type   = "regular"
    ))
  }
```

After edits: re-run full `minutes_classify.R`, paste updated `doc_class` distribution.
Expected: FACs 644 and 967 move from `agenda` to `summary_minutes`.

### FAC 644 corpus exclusion patch (AFTER Board Highlights fix)

FAC 644 is the non-primary Cornwall partner. After reclassification, patch
`minutes_corpus_audit.csv`:
- All FAC 644 rows: `corpus_include = FALSE`, `qa_flags = "partner_duplicate"`
- FAC 967 rows: unchanged, remain in corpus

---

## Work Completed This Session

### 1. ReviewFile.R — built and validated

Diagnostic sampling tool created at:
`E:/HospitalIntelligenceR/roles/minutes/scripts/ReviewFile.R`

Parameters (adjust at top of script):
- `FAC` — hospital to review
- `N_SAMPLE` — files to sample (Inf = all)
- `N_WORDS` — words to display from start of each PDF
- `SEED` — change to reshuffle sample

Features: auto-selects folder with most files when duplicates exist; pulls
classification fields from audit alongside text; preserves PDF structure
(page breaks, line breaks, paragraphs) for visual review.

Key design note: `str_squish()` retained for word counting only; display text
uses `str_trim()` to preserve structure. Structure is an important future signal
for classification and extraction.

### 2. Manual review of FACs 936, 888, 858 — findings documented

**FAC 936 (London Health Sciences):**
- File 1: Correctly classified as `minutes`. Contains amendment note in top-left
  that causes pdftools to interleave two column streams — structural artifact,
  not a classifier failure.
- File 2: Classified as `agenda` — actually a CEO Report. Wrong class name but
  correctly excluded from corpus. Low priority to fix.
- File 3: Correctly classified as `minutes`.

**FAC 888 (New Liskeard Temiskaming Hospital):**
- Files 1 and 2: Classified as `agenda`, excluded from corpus — WRONG. These
  are genuine confirmed minutes with attendance and motions. The motion format
  uses BoardPro software layout (tabular: Decision Date / Mover / Seconder /
  Outcome on separate lines) which the keyword detector does not recognise.
  Attendance uses "Board Members:" and "Attendees:" labels not in current
  `detect_attendance()` patterns.
- File 3: Financial statements — classified as `other`, excluded — CORRECT.

**FAC 858 (Michael Garron / Toronto East General):**
- All documents are "SUMMARY OF THE BOARD OF DIRECTORS" format — narrative
  summaries with decisions recorded but no formal attendance block or motion
  keywords. Currently classified inconsistently as `minutes`, `mixed`, and
  `summary_minutes` across the same document format.
- Files correctly included in corpus throughout; classification label is wrong
  but corpus decision is right.
- One file `NOT IN AUDIT` — see versioning issue below.

### 3. Classifier limitations — diagnosis

The `minutes_classify.R` structural approach has fundamental limitations revealed
by the manual review:

| Issue | Detail |
|---|---|
| Motion detection | Misses BoardPro tabular format (FAC 888), "APPROVED BY GENERAL CONSENT" (FAC 936), and other non-keyword motion styles |
| Attendance detection | Misses "Board Members:" / "Attendees:" / "Apologies:" labels (FAC 888) |
| Bundled documents | CEO reports, financial statements in same PDF as minutes cause `mixed` or wrong classification |
| Summary format | FAC 858 documents classified inconsistently despite identical format |
| Agenda prefix | Some PDFs begin with the meeting agenda before the minutes — header detector fires on agenda page |

**Decision: Replace classifier with `extract_minutes.R`** — a page-boundary-based
extractor. See design section below.

### 4. NOT IN AUDIT investigation — FAC 858 versioning issue

**Finding:** 35 files in FAC 858 extraction folder not in audit. All are
`_yearonly_vN` versions (v2 through v7). Only the base `_yearonly` file per year
was registered in the index and audit.

**Root cause:** FAC 858 website hosts minutes as a single annually-updated PDF
that is replaced/extended each time new minutes are added. Scraper downloaded it
multiple times across runs, creating version suffixes. Only first download was
indexed.

**Implication:** The highest version number per base filename is the most complete
cumulative document. `extract_minutes.R` should deduplicate by keeping the highest
version when building its processing list.

**Action:** No immediate fix needed. Deduplication logic built into `extract_minutes.R`.

### 5. Extraction folder audit — reviewed, cleanup pending

See morning session summary for full details. Cleanup code prepared and verified.
Execute when convenient — low urgency.

---

## extract_minutes.R — Design Specification

### Core principle

A page-boundary-based extractor that either returns minutes text or NA.
Replaces the structural keyword classifier. Treats summaries as a subtype
of minutes (flag only), not a separate class.

### Architecture

**Input:** Folder-driven (reads directly from extraction folders, not index).
Index has known gaps (versioning, late downloads). Folder is ground truth.

**Processing unit:** Individual PDF page (one element per page from
`pdftools::pdf_text()`). Page breaks are structurally encoded — no need to
infer from whitespace.

**Output:** One row per extracted minutes set with:
- `fac`, `hospital_name`, `filename`, `page_start`, `page_end`
- `extraction_flag`: `complete` | `summary` | `partial` | `multi` | `failed`
- `is_summary`: logical
- `has_agenda_prefix`: logical
- `n_minutes_sets`: integer (normally 1; >1 flags multiple sets in one PDF)
- `extracted_text`: full text of the minutes section only

### Detection logic

**Start detection** — fires when ALL of the following present in first 100
words of a page:
- Structural: begins on a new page (inherent in page-by-page processing)
- Header keyword (at least one): Minutes, Summary of Minutes, Summary of the
  Board, Board of Directors, Board Meeting, Open Session, Open Board
- Date signal: any date pattern (month name + year, or YYYY-MM-DD format)

Keywords to flesh out in first iteration based on ReviewFile.R evidence.

**End detection** — fires when ANY of the following present in last 100 words
of a page:
- Adjournment: "adjourned", "meeting adjourned", "there being no further business"
- Next meeting: "next meeting", "next regular meeting", "next board meeting"
- Signature block: "Chair", "Secretary" on separate lines near bottom
- Followed by: page break (inherent) AND no continuation of minutes content

**Fallback end:** If no end marker found within N pages of start, take content
up to next start marker or end of document. N to be calibrated during iteration.

### Handling special cases

**Bundled documents:** Extractor scans all pages; extracts only the minutes
section. Non-minutes pages (CEO report, financials, agenda) are bypassed.

**Agenda prefix:** If start page contains "agenda" in header but not "minutes"
or "summary", flag `has_agenda_prefix = TRUE` and continue scanning for the
actual minutes start.

**Multiple sets:** Loop after finding end — continue scanning for another start.
Flag `n_minutes_sets > 1` and append both extractions.

**Version deduplication:** Per base filename (stripping `_vN` suffix), keep
highest version number only.

**Summary detection:** If header contains "Summary of" or "Highlights" flag
`is_summary = TRUE`. Content otherwise processed identically.

### Development approach

Iterative, sample-based:
1. Start with 5 hospitals representing known format variety (936, 888, 858,
   644/967, one straightforward hospital)
2. Run extractor, review output with `ReviewFile.R` for validation
3. Adjust keyword lists and thresholds
4. Expand to 20 hospitals
5. Expand to full corpus

---

## Key Design Decisions Made This Session

| Decision | Rationale |
|---|---|
| Replace classifier with page-boundary extractor | Structural keyword approach has fundamental limits; page-by-page processing is the correct primitive |
| Folder-driven not index-driven | Index has known gaps from versioning and late downloads; folder is ground truth |
| Summaries are a flag, not a class | FAC 858 evidence: summary documents record real decisions and belong in corpus |
| Iterative sample-based development | Calibrate keyword lists from evidence before full run |
| Keep highest version per base filename | Most complete cumulative document for annually-updated PDFs |
| Structure preservation in ReviewFile.R | Line breaks and page structure are analytical signals, not noise |

---

## Carry-Forward Items

### Partnership governance review — FUTURE WORKSTREAM
Full registry audit for all partnerships; single canonical method; process for
tracking dissolution and merger. Template established: `governance:` block at
entity header level. See morning session summary for full spec.

### Scraper folder naming fix — FUTURE
Build folder names from FAC code only to prevent naming drift on registry name
changes.

### Extraction folder cleanup — LOW URGENCY
12 duplicate empty folders identified; cleanup code ready. Execute when convenient.

### CEO Report / non-minutes misclassification
FAC 936 CEO report classified as `agenda` — wrong label, right corpus decision.
Low priority; `extract_minutes.R` will handle naturally (no minutes header = NA).

### BoardPro motion format
FAC 888 tabular motion layout not detected by current classifier. Documented
for `extract_minutes.R` keyword design — "Decision Date:" is a reliable
BoardPro signal.

---

## Files Modified or Created This Session

| File | Location | Change |
|---|---|---|
| `ReviewFile.R` | `E:/HospitalIntelligenceR/roles/minutes/scripts/` | Created — PDF sampling diagnostic tool |
| `SessionSummaryJune192026_PM.md` | Upload to knowledge repository | This file |

---

## GitHub Commit Instructions

```
roles/minutes/scripts/ReviewFile.R    — created
```

**Commit message:** `T1: ReviewFile.R diagnostic tool`

**Description:**
```
PDF sampling tool for manual classification review. Preserves document
structure (page breaks, paragraphs) for visual inspection. Pulls
classification fields from minutes_corpus_audit.csv alongside text.
Parameters: FAC, N_SAMPLE, N_WORDS, SEED.
```

---

## Session End Checklist

- [ ] Upload `SessionSummaryJune192026_PM.md` to knowledge repository
- [ ] Commit ReviewFile.R to GitHub
- [ ] New thread: begin with design session for extract_minutes.R keyword lists
- [ ] Execute Board Highlights classifier patch (code ready — morning session)
- [ ] Execute FAC 644 corpus exclusion patch after Board Highlights fix confirmed
