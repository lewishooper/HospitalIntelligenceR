# HospitalIntelligenceR
## Session Summary — July 08, 2026
## Board Minutes Pipeline — MinutesOnly Validation, Cleanup, Stage 2 Extraction Complete
*For Claude Project Knowledge Repository*

---

## Next Session — Start Here

**Current priority:** Extend `minutes_merge_corpus.R` to fold in `minutes_extract_minutesonly_clean.rds` as a fourth tier (`"minutesonly"`), producing a single merged corpus across all four extraction pipelines for the first time.

**First action:** Add a fourth `load_tier()` call to `minutes_merge_corpus.R` pointing at `minutes_extract_minutesonly_clean.rds`. Confirm its column set against `COMMON_COLS` — this file carries a `word_count` column the other three tiers do not; decide whether to add it to the common schema or drop it at merge time. Re-run the merge and confirm the same "no fac+filename overlap across tiers" sanity check passes with four tiers instead of three.

**Watch out for:**
- `minutes_extract_minutesonly_clean.rds` (1,864 documents) is the correct input for this — NOT `minutes_extract_minutesonly_results.rds` (1,881, pre-cleanup). Using the wrong file would reintroduce the 17 confirmed-excluded documents (FAC 644 duplicates, FAC 978 in-camera-only records, and 5 individually-confirmed non-minutes documents from FAC 661/701/953).
- Once the four-tier merge is done, this is still NOT `minutes_analytical_master.rds` — that name remains reserved for after internal date extraction and the LH prior corpus decision are both resolved.

### Carry-Forward Items

| Item | Status | Notes |
|---|---|---|
| Fold `minutes_extract_minutesonly_clean.rds` into `minutes_merge_corpus.R` as a fourth tier | READY TO EXECUTE | See "First action" above |
| Follow-up with Kingston Health Sciences (FAC 978) | FUTURE WORKSTREAM | Confirmed via manual review of the entire FAC 978 folder: Kingston conducts board business primarily in camera; filed minutes contain only a redacted "Report on In-Camera Matters" — a list of decisions approved, with no discussion or narrative content. This is a structural governance pattern, not an extraction defect — no script fix would recover content that was never filed publicly. Excluded from the analytical corpus entirely (whole hospital, all documents). Possible future options: request full/unredacted minutes directly from Kingston, or treat as a separate governance case study rather than attempt inclusion in the standard corpus. |
| Build motion-extraction logic for FAC 888's (New Liskeard Temiskaming) structured motion format | FUTURE WORKSTREAM | Confirmed genuine minutes, but uses a formal structured field format (Decision Date / Mover / Seconder / Outcome, whitespace-heavy) rather than the narrative "moved by... seconded by... carried" prose `detect_motions()` looks for. Not a corpus-inclusion problem — these documents are correctly included — but the future motion/decision-extraction workstream will need a second extraction pattern for this format specifically. |
| Add negative-signal keyword check to `detect_header()` / `classify_document()` | FUTURE WORKSTREAM, next data-renewal pass | Confirmed via this session's review that documents opening with "Organizational Structure," "Medical Structure," "Organizational Chart," or similar are reliably non-minutes (Sunnybrook, Cambridge Memorial org/medical charts). Proposed for the next full data-renewal cycle: treat presence of these terms early in a document as a disqualifying signal, overriding an otherwise-passing header match. Deliberately not built this session — low volume (2 documents found) doesn't justify a mid-cycle script change. |
| Investigate/generalize OCR handling for table-bordered attendance rosters | LOW URGENCY | FAC 638/723 (MICs Group) minutes use a bordered-table attendance format that OCRs into gridline noise (tildes, stray letters) rather than clean text. Confirmed the surrounding substantive minutes content reads cleanly — this affects only the attendance/roster block, which is not analytically important per project scope. No action needed unless a future workstream specifically needs clean attendance data from these documents. |
| Reconcile filename-based document dating with internal header-date extraction | FUTURE WORKSTREAM (already logged July 7) | Reinforced again this session: FAC 701's excluded community-report document used the same `_yearonly` placeholder-dating filename pattern already seen on FAC 939's non-minutes documents. Further confirmation that the planned internal-date-extraction pre-step (date from header text, not filename) is the right design. |
| Formal accuracy estimate for the extraction pipeline | TABLED | Raised and set aside this session — initial framing (a single overall accuracy percentage) wasn't well-specified. If revisited, the discussed approach was: draw a random sample from the ~1,816 "has motion language" documents (not keyword-targeted) for a real, defensible accuracy estimate, since the 62-document review just completed was a targeted highest-risk sample and cannot be extrapolated to the full corpus. |

---

## Session Objectives

Validate the overnight `minutes_extract_minutesonly.R` run (~1,881 documents, the Stage 1 `MinutesOnly` population) before trusting it, using the `doc_class` QA-tag breakdown and a motion-language screen to surface documents at risk of being genuine non-minutes content despite passing `corpus_include`. Resolve every flagged case through manual document review, and produce a cleaned, corpus-ready output file.

---

## Work Completed

### 1. Overnight `MinutesOnly` run — initial results

1,881 documents processed (2 more than the ~1,879 estimate — not investigated further, immaterial). 1,878 `corpus_include`, 3 `ocr_failed`, 0 `low_word_count`. `doc_class` breakdown: 1,684 `minutes`, 127 `other`, 37 `summary_minutes`, 30 `agenda` — reconciling exactly against `corpus_include` (1,684+127+37+30 = 1,878).

The 157 non-`"minutes"` `doc_class` tags (127 "other" + 30 "agenda") were flagged as worth investigating before trusting the run, since `classify_document()`'s attendance check only scans the first 40% of a document's characters — a design inherited from when it ran against already-boundary-trimmed extractions, potentially producing false tags against full untrimmed `MinutesOnly` documents.

### 2. Doc_class sample review — mixed findings

A random sample of 6 flagged documents (3 "agenda," 3 "other") found: 2 genuine organizational-chart-only documents (Sunnybrook, Cambridge Memorial) mislabeled by content, not label — i.e. real corpus-inclusion errors, not QA-tag artifacts; 1 confirmed genuine Board Highlights document (FAC 644, correctly included, mislabeled only); 2 confirmed genuine minutes using non-standard attendance formatting (checkmark rosters, bordered tables) that `detect_attendance()`'s keyword-only matching doesn't recognize; 1 confirmed genuine minutes (Sarnia Bluewater).

### 3. Corpus-wide motion-language screen — the real validation step

Since the doc_class sample surfaced two genuine false positives (not just labeling issues), ran a full-corpus screen for the presence of any motion/substantive language (`moved by|seconded by|carried|adjourned|resolved that|be it resolved`) across all 1,878 `corpus_include` documents. 62 documents came back with zero matches anywhere in the full text — the complete highest-risk population for this validation pass, not a further sample.

**Resolution of all 62, by hospital:**

| FAC | Hospital | n | Finding |
|---|---|---|---|
| 858 | Michael Garron | 24 | Confirmed summary-tier (no motion narrative by format design) — already known |
| 967 | Cornwall Community | 5 | Confirmed genuine Board Highlights — already known |
| 736 | Newmarket Southlake | 1 | Confirmed genuine — a second, independent occurrence of the already-confirmed summary-tier format, surfacing via the MinutesOnly bucket rather than SomethingElse |
| 936 | London Health Sciences | 1 | Confirmed genuine board minutes |
| 888 | New Liskeard Temiskaming | 16 | Confirmed genuine — uses a formal structured Mover/Seconder/Decision-Date/Outcome motion format, not narrative prose; `detect_motions()` simply doesn't recognize this format |
| 644 | Cornwall Hotel Dieu | 5 | Confirmed duplicate of FAC 967 — excluded (whole hospital) |
| 978 | Kingston Health Sciences | 5 (full folder manually reviewed) | Confirmed structural non-starter — see Key Design Decisions. Excluded (whole hospital) |
| 661 | Cambridge Memorial | 2 | 1 agenda-with-reports/no-minutes, 1 organizational chart. Excluded (document-level) |
| 701 | Richmond Hill Mackenzie | 1 | Community report, not minutes. Excluded (document-level) |
| 953 | Sunnybrook | 2 | 1 organizational-structure chart, 1 medical-structure chart. Excluded (document-level) |

### 4. `minutes_minutesonly_cleanup.R` built and run

New script applying the confirmed exclusions above to `minutes_extract_minutesonly_results.rds`: whole-hospital exclusion for FAC 644 and 978 (all documents for each, not only the ones lacking motion language), plus five specific `fac`+`filename` document-level exclusions (661×2, 701×1, 953×2). Output: `minutes_extract_minutesonly_clean.rds`.

**Result:** 1,881 → 1,864 documents (17 removed, 0.9%).

---

## Key Design Decisions

| Decision | Rationale |
|---|---|
| FAC 978 (Kingston Health Sciences) excluded entirely from the analytical corpus | Manual review of the full FAC 978 folder confirmed a structural governance pattern, not a data-quality defect: Kingston conducts board business primarily in camera and files only a redacted "Report on In-Camera Matters" — a list of approved decisions with no discussion content. This does not serve the project's core analytical goal (what the board said and did), and no extraction fix could recover discussion content that was never filed publicly |
| FAC 888 (New Liskeard Temiskaming) retained despite zero motion-language matches | Manual review confirmed genuine minutes using a formal structured field format (Decision Date/Mover/Seconder/Outcome) rather than narrative prose — a real document, just one `detect_motions()` isn't built to recognize. Flagged as a distinct future motion-extraction pattern rather than corrected in this script |
| Whole-hospital exclusion (FAC 644, 978) applied at the FAC level, not filtered per-document | Both exclusions are structural properties of the hospital/record (duplicate cataloguing; in-camera-only governance), not properties of individual documents — some documents from these hospitals may contain motion language and would otherwise have passed the screen, but excluding them individually would leave a partial, misleadingly-legitimate-looking record for a hospital that shouldn't be represented in the corpus at all |
| Negative-signal keyword check for `detect_header()` deferred to the next full data-renewal cycle rather than built now | Only 2 documents (of 1,878) were confirmed org/medical-chart false positives this session — low enough volume that a mid-cycle script change isn't justified; better bundled with other refinements at the next renewal |
| Formal corpus accuracy estimate tabled rather than answered from the 62-document review alone | That review was a targeted highest-risk sample (documents lacking motion language specifically) and cannot be honestly extrapolated to the ~96.7% of the corpus that did contain motion language and was never individually checked. A defensible estimate would require a genuine random sample from the unchecked population |

---

## Files Produced or Modified

| File | Location | Change |
|---|---|---|
| `minutes_minutesonly_cleanup.R` | `E:/HospitalIntelligenceR/roles/minutes/` | Created — applies confirmed whole-hospital and document-level exclusions |
| `minutes_extract_minutesonly_clean.rds` | `E:/HospitalIntelligenceR/roles/minutes/outputs/` | Created — 1,864 documents, cleaned MinutesOnly tier, ready to merge |
| `SessionSummaryJuly082026.md` | Upload to knowledge repository | This file |

---

## GitHub Commit Instructions

```
roles/minutes/minutes_minutesonly_cleanup.R                  — created
roles/minutes/outputs/minutes_extract_minutesonly_clean.rds  — created
docs/session_summaries/SessionSummaryJuly082026.md            — created
```

**Commit message:** `T2: MinutesOnly validation and cleanup — Stage 2 extraction complete across all four tiers`

**Description:**
```
Validated the overnight minutes_extract_minutesonly.R run (1,881
documents) via a corpus-wide motion-language screen, surfacing 62
documents with zero motion/substantive language matches as the complete
highest-risk population for manual review.

Confirmed via document review: FAC 858/967/736 (summary-tier format), FAC
888 (genuine minutes using a structured Mover/Seconder/Outcome motion
format not recognized by detect_motions()), and FAC 936 as genuine
inclusions.

Confirmed FAC 978 (Kingston Health Sciences) as a structural non-starter —
board business conducted primarily in camera, filed minutes contain only a
redacted decision-outcome list with no discussion content. Excluded
entirely from the analytical corpus (whole hospital), logged as a future
follow-up rather than a defect to fix.

Confirmed FAC 644 as the already-known duplicate of FAC 967 (also present
independently in the MinutesOnly bucket) — excluded entirely.

Confirmed 5 individual document-level false positives across FAC 661/701/
953 (agenda-with-reports, organizational/medical structure charts,
community report) — excluded at the document level.

Built minutes_minutesonly_cleanup.R applying all of the above. Result:
1,881 -> 1,864 documents (17 removed, 0.9%). This completes manual
validation of all four SomethingElse/MinutesOnly-derived extraction
tiers (prescreen, summary, remainder, minutesonly) — first time the full
Stage 2 extraction has been carried through validation end to end.
```

---

## Session End Checklist

- [x] Upload this file to Claude Project knowledge repository
- [x] Commit all files listed above to GitHub per instructions
- [ ] Extend `minutes_merge_corpus.R` for the fourth tier (next session's first action)
