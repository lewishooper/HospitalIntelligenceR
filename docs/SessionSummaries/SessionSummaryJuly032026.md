# HospitalIntelligenceR
## Session Summary — July 03, 2026
## Board Minutes Pipeline — Stage 2 Prescreen Extraction
*For Claude Project Knowledge Repository*

---

## Next Session — Start Here

**Current priority:** Classify the 6 `no_start_detected` documents from today's full batch run — now identified below — as either true negatives (agenda-only, no embedded minutes) or a new format variant the start-detection gate hasn't seen yet.

**The 6 documents:**

| FAC | Hospital | Filename |
|---|---|---|
| 661 | Cambridge Memorial Hospital | `2024-06-26_board_minutes_v2.pdf` |
| 661 | Cambridge Memorial Hospital | `2024-06-05_board_minutes.pdf` |
| 933 | Windsor Regional Hospital | `2024-07-01_board_minutes_v4.pdf` |
| 933 | Windsor Regional Hospital | `2023-06-01_board_minutes_v2.pdf` |
| 933 | Windsor Regional Hospital | `UNKNOWN_DATE_001_board_minutes.pdf` |
| 939 | Toronto Holland Bloorview Kids | `2023-06-01_board_minutes.pdf` |

**Notable pattern:** all 3 Windsor Regional (933) `agenda_prescreen` documents failed — the entire hospital's cohort, not a scattered subset. When one hospital fails uniformly across all its documents, that's characteristic of a systematic format difference specific to that hospital rather than random OCR noise (contrast with CMH's isolated `170Oh` glitch, which affected some but not all CMH documents). Leading hypothesis: Windsor's attendee names may be printed in ALL CAPS (e.g. "J. SMITH"), which the current name pattern cannot match — both the full-name and initial-based alternatives require at least one lowercase letter (`[A-Z][a-z]+`). Unconfirmed until diagnostics are run.

The two additional CMH failures and the second Holland Bloorview document (different from the already-confirmed true-negative Holland Bloorview document) should each be checked independently — do not assume the new Holland Bloorview document is also a true negative just because the previously-tested one was.

**First action:** Run the existing diagnostic block in test mode against a Windsor document first, to confirm or rule out the all-caps hypothesis:

```r
TEST_FAC      <- "933"
TEST_FILENAME <- "2024-07-01_board_minutes_v4.pdf"
```

Review the printed page-level diagnostics (header/names/call_to_order booleans + raw OCR snippet) the same way as CMH's debugging today — actual OCR text, not assumptions. Then repeat for the two CMH documents and the new Holland Bloorview document.

**Watch out for:**
- Today's session found three independent format/OCR bugs across just 6 test documents (colon-only time format, full-name-only name pattern, O/0 OCR confusion). Don't assume any of these 6 are clean true negatives without checking — the pattern so far is "looks like a true negative, turns out to be a quirk."
- If Windsor confirms the all-caps hypothesis, the fix is a targeted addition to `name_pattern` (an all-caps alternative, e.g. `[A-Z]{2,}\.?\s?[A-Z]{2,}`), diagnosed and tested the same way as today's fixes — not a guess applied blind.

### Carry-Forward Items

| Item | Status | Notes |
|---|---|---|
| Classify the 6 `no_start_detected` documents (2 CMH, 3 Windsor Regional, 1 Holland Bloorview) | READY TO EXECUTE | Windsor's 3-for-3 failure suggests a systematic format issue (leading hypothesis: all-caps names) rather than 3 unrelated true negatives — test Windsor first |
| Spot-check sample of the 29 `corpus_include TRUE` extractions | READY TO EXECUTE | Beyond the 6 already manually verified (CMH 661 x2, TBay 935 x2, + 2 untested hospitals) |
| Design `decision_substance` weighting rubric for MinutesSummary tier | FUTURE WORKSTREAM | Deferred to master-build time per existing plan; should be extensible |
| LH prior corpus decision (archived data integration) | FUTURE WORKSTREAM | Mandatory pre-step before `minutes_analytical_master.rds` build |
| Internal date extraction from minutes documents | FUTURE WORKSTREAM | Mandatory pre-step before `minutes_analytical_master.rds` build |
| Build `minutes_analytical_master.rds` | FUTURE WORKSTREAM | Blocked on all of the above; closes Stage 2 once complete |

---

## Session Objectives

Debug `minutes_extract_prescreen.R`'s start-detection logic, which had one untested candidate fix (call-to-order + clock-time as sole anchor) carried over from the prior session. Redesign the start gate around Skip's structural observation that real minutes open with a specific sequence — new page, header with date, attendance block with a real name list, call to order — then validate against known failure cases before running the full 35-document `agenda_prescreen` batch.

---

## Work Completed

### 1. Start-detection gate redesign

Replaced the single-signal call-to-order+time start gate with a strict, same-page combination of three independent structural signals:

- `detect_header_page()` — header phrase (e.g. "minutes of," "board of directors") co-occurring with an actual date on the page. A bare header phrase alone was rejected as a sufficient signal, since agenda cover pages carry the same boilerplate.
- `detect_name_list_near()` — an attendance keyword ("present," "in attendance," "regrets," etc.) with a real run of proper names nearby (`min_names = 5`), not just the bare keyword. The bare keyword alone had previously matched agenda item titles like "Regrets" with zero actual names attached.
- `detect_call_to_order_page()` — "call(ed) to order" co-occurring with a clock time within ~150 characters (carried over from prior session, now integrated into the combined gate rather than used alone).

All three are required on the **same page** — deliberately strict, since single-signal gates in two earlier rounds both proved insufficient against real false positives (agenda pages, a motions-summary document, a slide deck).

### 2. Iterative debugging against real documents

Single-document test mode (`TEST_FAC` / `TEST_FILENAME`) was run against CMH 661 and Thunder Bay 935 across multiple document dates. Three independent bugs were found and fixed, each traced to actual tesseract OCR output rather than manually-transcribed reference text — a diagnostic print block (`print_page_diagnostics()`, active only when `TEST_FAC` is set) was added specifically to make this possible.

**Bugs fixed:**

| Bug | Fix Applied |
|---|---|
| Time pattern only recognized colon+am/pm format ("5:06 p.m.") | Broadened to also match military time with "h"/"hrs"/"hours" suffix ("1700h," "1700 hours") and bare HH:MM |
| Name pattern only recognized full first+last names ("Patricia Lang"); found zero matches on CMH's initial-based attendee format ("L.Woeller," "Dr. W. Lee") despite 13 real attendees on the page | Added an initial-based alternative to the name pattern, matched alongside the full-name pattern |
| OCR sporadically misread "0" as "o" in military time ("1700h" → "170oh"), traced to a font-substitution issue with the source PDF's embedded 'AmsiPro' font | Added a normalization step, scoped only to the narrow ±150-character call-to-order matching window, that converts a lowercase "o" sitting between two digits (or a digit and "h") back to "0" |

### 3. Validation and full batch run

Single-document tests passed 6/6 with both start and end pages manually confirmed correct against source PDF review: CMH 661 (2024-03-06, 2026-06-03), Thunder Bay 935 (2024-10-02, 2025-10-01), plus 2 additional documents from previously-untested hospitals. Holland Bloorview (939) correctly returned `no_start_detected` as a confirmed true negative (agenda-only document, no embedded minutes).

Full batch run against all 35 `agenda_prescreen` documents:

| Outcome | Count |
|---|---|
| Total processed | 35 |
| `corpus_include TRUE` | 29 |
| `no_start_detected` (needs manual review) | 6 |
| `no_close_detected` (needs manual review) | 0 |
| `file_missing` | 0 |
| `ocr_failed` | 0 |

Zero `no_close_detected` results validate that the close-detection logic carried over from the prior session (page-level, no percentage-slicing, no EOF fallback) is holding up well across the full batch.

---

## Key Design Decisions

| Decision | Rationale |
|---|---|
| Start detection requires all three structural signals (header+date, attendance+names, call-to-order+time) on the same page, with no page-window tolerance | Two earlier single-signal or looser designs both produced real false positives (agenda pages, a motions-summary document, a slide deck). Skip confirmed same-page strictness over a 2-page window given the false-positive history. |
| `min_names` threshold set to 5 | Skip's choice, to be tuned further if OCR-garbled names on lower-quality scans start under-detecting real attendance blocks. Comfortably above the 1-2 stray capitalized words a false match (e.g. an agenda title) would produce. |
| Diagnostic print block (`print_page_diagnostics()`) gated on `TEST_FAC` only | Keeps full-batch runs clean and avoids doubling OCR cost across 35 documents; only needed during single-document debugging. |
| No EOF fallback on close detection (retained from prior session) | Consistent with the existing project principle — ambiguous cases are flagged via `qa_flag` for manual review rather than silently resolved. |
| Bugs diagnosed from actual OCR output, not manually-transcribed reference text | A hand-typed transcription of a PDF page does not reflect real tesseract character-recognition errors (digit/letter confusion, font-substitution artifacts). All three bugs this session were only correctly diagnosed once real OCR output was inspected directly. |

---

## Files Produced or Modified

| File | Location | Change |
|---|---|---|
| `minutes_extract_prescreen.R` | `E:/HospitalIntelligenceR/roles/minutes/scripts/` | Modified — replaced single-signal start gate with strict same-page 3-signal gate; added `detect_header_page()`, `detect_name_list_near()`, `print_page_diagnostics()`; fixed time-pattern, name-pattern, and OCR-normalization bugs |
| `minutes_extract_prescreen_results.rds` | `E:/HospitalIntelligenceR/roles/minutes/outputs/` | Created — full 35-document extraction results (29 `corpus_include TRUE`, 6 flagged for manual review) |
| `SessionSummaryJuly032026.md` | Upload to knowledge repository | This file |

---

## GitHub Commit Instructions

```
roles/minutes/scripts/minutes_extract_prescreen.R    — modified
docs/session_summaries/SessionSummaryJuly032026.md   — created
```

**Commit message:** `fix: strict same-page start-detection gate for minutes_extract_prescreen, validated on full batch`

**Description:**
```
Replaced single-signal call-to-order start gate with a strict same-page
combination of header+date, attendance+name-list, and call-to-order+time
signals. Fixed three independent bugs found during single-document testing:
time pattern too narrow (military "h" format), name pattern too narrow
(initial-based attendee format), and OCR 0/o digit confusion tied to a
font-substitution issue on one source PDF. Validated 6/6 on single-document
tests; full 35-document batch run yielded 29 corpus_include TRUE, 6
no_start_detected flagged for manual review, 0 no_close_detected.
```

---

## Session End Checklist

- [ ] Save as `SessionSummaryJuly032026.md` — confirm `.md` extension before closing
- [ ] Upload to Claude Project knowledge repository
- [ ] Commit to `docs/session_summaries/` on GitHub
- [ ] Pull the FAC/filename list for the 6 `no_start_detected` documents (snippet above) and classify each before starting new work next session
- [ ] Spot-check 3–5 of the 29 `corpus_include TRUE` extractions against source PDFs
