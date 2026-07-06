# HospitalIntelligenceR
## Session Summary — July 05, 2026
## Board Minutes — Summary-Tier Extraction (905, 967, 644, 736) Built and Validated
*For Claude Project Knowledge Repository*

---

## Next Session — Start Here

**SUPERSEDED — see `SessionSummaryJuly062026.md`.** The spot-check called for below surfaced a real bug in FAC 905 (a third opening-statement construction the start gate didn't recognize), which was diagnosed and fixed the same day. That fix, the final four-hospital results, and the current priority (processing the `SomethingElse` remainder, starting with Quinte 957) are recorded there. The block below is left as written for the historical record of what was open at the point this document was first drafted.

**Current priority (as of original draft):** Spot-check the 905 (Oak Valley) and 736 (Newmarket Southlake) extractions from today's full four-hospital run before treating `minutes_extract_summary_results.rds` as final. The no-close-detection design (extract start-to-EOF, no adjournment check) was validated against Cornwall (967) only — today's full run is the first time it's applied to 905 and 736, and that assumption needs the same confirmation Cornwall got before this tier is trusted for analysis.

**First action:** Load `minutes_extract_summary_results.rds`, filter to `fac %in% c("905","736")`, and work through the spot-check protocol in this summary (see "How to Spot-Check 905 and 736" below) before doing anything else with the output.

**Watch out for:**
- The no-close-check design is a deliberate, scoped exception to the project's standing "no silent EOF fallback" principle — it applies only inside `minutes_extract_summary.R`, only for these four FACs. Do not generalize this pattern to `minutes_extract_prescreen.R` or the remainder-batch work without a separate, explicit decision.
- `TEST_FAC`/`TEST_FILENAME` in `minutes_extract_summary.R` should be confirmed back to `NULL` on disk before any future re-run — same discipline as `minutes_extract_prescreen.R`.
- FAC 644 rows in the output carry `is_duplicate_of = "967"` as an informational tag only. This does not apply the registry-level `duplicate_of` tag — that carry-forward item is still open (see table below).
- Today's script assumes 905 and 736 follow the same header/opening-statement patterns identified in Skip's manual sample review (Oak Valley: "called the meeting to order at [time]"; Southlake: "A meeting of the ... Board of Directors was held on..."). If the full run's `no_start_detected` count for either hospital looks high relative to their total document count, the header or opening-statement patterns may need broadening for that hospital specifically, the same way the Cornwall narrative-opening gap was found and fixed today.

### Carry-Forward Items

| Item | Status | Notes |
|---|---|---|
| Spot-check 905 and 736 extractions | **RESOLVED** | See `SessionSummaryJuly062026.md` — a real bug surfaced in 905, was fixed, both hospitals reconfirmed |
| Apply FAC 644 `duplicate_of: 967` tag (registry-level) | READY TO EXECUTE | Still open — see `SessionSummaryJuly062026.md` for the row-level `analytical_include` exclusion now in place at the extraction-output level, which is a separate step from this registry tag |
| Resolve `MinutesSummary` tier assignments | IN PROGRESS | Last touched July 1 AM session; the four-hospital summary-tier corpus this tier assignment draws on is now finalized — see `SessionSummaryJuly062026.md` |
| Apply `minutes_extract_prescreen.R`'s remainder-batch target-set change, test on Quinte (957) | READY TO EXECUTE — **now the current priority** | Designed July 5, not yet run — see `SessionSummaryJuly062026.md` |
| Design `decision_substance` weighting rubric for `MinutesSummary` tier | FUTURE WORKSTREAM | Deferred to master-build time; today's summary-tier extractions are exactly the cases this rubric needs to be designed against |
| LH prior corpus decision (archived data integration) | FUTURE WORKSTREAM | Mandatory pre-step before master build |
| Internal date extraction pass over MinutesOnly corpus | FUTURE WORKSTREAM | Mandatory pre-step before master build |
| Build `minutes_analytical_master.rds` | FUTURE WORKSTREAM | Blocked on all of the above |
| Reconcile hospital-level `SomethingElse` count estimates against `llm_run1_results.csv` | LOW URGENCY | Skip's manual estimate (~220 summary docs, 195 remainder) doesn't match a direct query against `llm_run1_results.csv` (197 summary-tier docs across the four FACs; ~250 remainder before subtracting the 35-doc `agenda_prescreen` batch) — not blocking, but worth a quick reconciliation against `minutes_extraction_by_hospitals.csv` when convenient |

---

## Session Objectives

Build a start-detection gate for the four hospitals identified by Skip's manual review as carrying summary/highlights-style minutes (905 Oak Valley, 736 Newmarket Southlake, 967 Cornwall Community — primary, 644 Cornwall Hotel Dieu — duplicate of 967) rather than full minutes, extract and flag their content as a distinct `summary_minutes` tier, and run the extraction across all four hospitals.

---

## Work Completed

### 1. Summary-tier detection design — `minutes_extract_summary.R`

Built as a new script, not a modification of `minutes_extract_prescreen.R`, following the project's established pattern of duplicating rather than sourcing structural detection functions across role scripts.

**Start gate:** two signals required on the same page, both narrower or different from the three-signal gate used for the `agenda_prescreen` batch:
- `detect_header_page_summary()` — requires a summary/highlights header phrase (e.g. "Board Highlights," "meeting summary") co-occurring with a date, not the standard minutes-header phrase set. Deliberately strict — requires the summary phrase rather than merely allowing it, to isolate this tier from full minutes.
- `detect_meeting_open_page()` — accepts either the formal call-to-order+time construction already used in `minutes_extract_prescreen.R`, or a new narrative "meeting was held" construction.

The name-list signal used in the `agenda_prescreen` gate was dropped by design — summary/highlights documents don't reliably carry a full attendee list.

**End boundary:** no close/adjournment check. See Key Design Decisions.

### 2. Two rounds of correction against real Cornwall (967) output

**Round 1 — call-to-order signal too narrow.** Initial test batch against all 37 FAC 967 `SomethingElse` documents returned 0 `corpus_include`. Diagnostic output showed the header-summary signal firing correctly, but the call-to-order signal never firing — Cornwall's Board Highlights format opens with a narrative sentence ("The Board of Directors held a meeting on October 8, 2020") rather than a formal call-to-order construction. Skip's spot-check confirmed Southlake (736) uses the same narrative pattern in different wording ("A meeting of the ... Board of Directors was held on..."), while Oak Valley (905) genuinely uses the formal "called the meeting to order at [time]" construction.

**Fix:** added `detect_meeting_held_page()` to recognize the narrative construction, and `detect_meeting_open_page()` to accept either construction as the second start-gate signal.

**Round 2 — close detection discarding genuine content.** Re-run against all 37 FAC 967 documents: 3 `no_start_detected` (2 confirmed Annual Meeting documents, out of scope per Skip; 1 additional document to confirm — see Watch Out), and of the 34 that passed the start gate, 0 `corpus_include` — all 34 flagged `no_close_detected`. Skip's manual review confirmed these Board Highlights documents simply end after the highlights content, with no trailing boilerplate or unrelated material a close gate would be protecting against.

**Fix:** removed the close-detection step from this script entirely. Once a start page is detected, extraction runs from `start_idx` to end of document. This is a deliberate, scoped exception to the project's standing "no silent EOF fallback" principle (documented in `minutes_extract_prescreen.R`), justified here by direct manual confirmation that these particular documents have no content after the highlights section worth excluding. It applies only within `minutes_extract_summary.R`.

**Bugs fixed:**

| Bug | Fix Applied |
|---|---|
| `detect_call_to_order_page()` only recognizes the formal "call(ed) to order" + time construction; Cornwall (967/644) and Southlake (736) use a narrative "meeting was held on [date]" opening instead, causing a 0/37 false-negative rate on the FAC 967 test batch | Added `detect_meeting_held_page()`; start gate's second signal (`detect_meeting_open_page()`) now accepts either construction |
| Close-detection step (`detect_close_page()`, unmodified from `minutes_extract_prescreen.R`) flagged 34/34 documents that passed the start gate as `no_close_detected`, discarding genuine summary content that simply ends without adjournment language | Close-detection step removed entirely for this script; extraction runs start-to-EOF, justified by manual confirmation these documents carry no excludable trailing material |

### 3. Validation against FAC 967 (Cornwall Community) — 34/37 confirmed

Final script run against all 37 FAC 967 `SomethingElse` documents: 34 `corpus_include = TRUE`, 3 `no_start_detected`. Of the 3 exclusions, 2 confirmed as Annual Meeting documents (correctly out of scope — different format, not covered by the summary header phrases by design) via the `is_annual_meeting` diagnostic tag added this session. Skip confirmed this result as correct.

### 4. Full run — all four summary-tier hospitals

Extraction run against the full summary-tier target set (905, 967, 644, 736; 197 `SomethingElse` documents across the four hospitals per `llm_run1_results.csv`). Output written to `roles/minutes/outputs/minutes_extract_summary_results.rds`.

**Update:** the 905 count below reflects the corrected result after a third detection-gap fix, made the same day but recorded in `SessionSummaryJuly062026.md` rather than backfilled into the narrative above — that document has the full diagnostic detail. This table is updated here purely to close out the placeholder with final numbers.

| FAC | Hospital | Total docs | `corpus_include TRUE` | `no_start_detected` | of which annual |
|---|---|---|---|---|---|
| 905 | Oak Valley | 69 | 69 (post-fix, see July 6 doc) | 0 | 0 |
| 736 | Newmarket Southlake | 54 | 52 | 2 | 1 |
| 967 | Cornwall Community | 37 | 34 (confirmed) | 3 | 2 |
| 644 | Cornwall Hotel Dieu | 37 | run — excluded from analysis (see July 6 doc) | — | — |

905 and 736 are now confirmed via the round-3 bug fix and reconfirmation run (see July 6 doc). 644 was confirmed to be a byte-identical file duplicate of 967 (same 42 filenames) and is flagged `analytical_include = FALSE` rather than independently re-validated — see July 6 doc for the duplicate verification and the exclusion mechanism.

---

## Key Design Decisions

| Decision | Rationale |
|---|---|
| Built `minutes_extract_summary.R` as a new script rather than modifying `minutes_extract_prescreen.R` | Matches the project's established pattern (`minutes_extract_prescreen.R` itself duplicates rather than sources functions from `minutes_classify.R`); the summary-tier gate is structurally different enough (two signals, not three; no close check) that folding it into the existing script would complicate its logic for no benefit |
| Dropped the name-list signal from the summary-tier start gate | Summary/highlights documents don't reliably carry a full attendee list the way full minutes do; requiring it would under-fire against genuine summary content |
| Required (not merely allowed) a summary/highlights phrase in the header signal | The point of this gate is to isolate the summary tier specifically from full minutes that might incidentally mention "summary" — a looser OR-based header would risk pulling in documents that belong in the main minutes pipeline instead |
| Removed close/adjournment detection entirely for this script, extracting start-to-EOF | Manual review of Cornwall's Board Highlights documents confirmed no trailing content exists past the highlights section; the close gate was discarding 34/34 genuine documents for no protective benefit. Explicitly scoped to this script only — the project's standing "no silent EOF fallback" principle still applies everywhere else, including `minutes_extract_prescreen.R` and the upcoming remainder-batch work |
| Left FAC 644 duplicate handling as a row-level informational flag (`is_duplicate_of`) rather than applying the registry-level tag | Registry-level `duplicate_of` tagging is a distinct carry-forward item scheduled for master-build time; conflating it with today's extraction work risked doing it without the full context that task deserves |

---

## Files Produced or Modified

| File | Location | Change |
|---|---|---|
| `minutes_extract_summary.R` | `E:/HospitalIntelligenceR/roles/minutes/` | Created — summary-tier start-gate detection and extraction for FAC 905, 967, 644, 736; two-round bug fix (narrative call-to-order signal, close-detection removal) |
| `minutes_extract_summary_results.rds` | `E:/HospitalIntelligenceR/roles/minutes/outputs/` | Created — full four-hospital extraction output, 197 documents |
| `SessionSummaryJuly052026.md` | Upload to knowledge repository | This file |

---

## GitHub Commit Instructions

```
roles/minutes/minutes_extract_summary.R                — created
docs/session_summaries/SessionSummaryJuly052026.md      — created
```

**Commit message:** `T2: summary-tier minutes extraction for FAC 905/967/644/736`

**Description:**
```
Added minutes_extract_summary.R: two-signal start gate (header+summary-phrase
+date, AND call-to-order+time OR narrative meeting-held+date) for the four
hospitals identified by manual review as carrying Board Highlights /
meeting-summary style minutes rather than full minutes (905 Oak Valley,
736 Newmarket Southlake, 967 Cornwall Community — primary, 644 Cornwall
Hotel Dieu — duplicate of 967).

Two bugs found and fixed against real FAC 967 (Cornwall) output before the
full run:
1. Initial call-to-order signal only recognized the formal "call(ed) to
   order" + time construction; Cornwall and Southlake use a narrative
   "meeting was held on [date]" opening instead. Added
   detect_meeting_held_page() to cover this; second start-gate signal now
   accepts either construction.
2. Close/adjournment detection (unmodified from minutes_extract_prescreen.R)
   flagged 34/34 documents that passed the start gate as no_close_detected.
   Manual review confirmed these documents simply end after the highlights
   content with no excludable trailing material. Close detection removed
   entirely for this script only — extraction runs start-page-to-EOF. This
   is a deliberate, scoped exception to the project's standing no-silent-
   EOF-fallback principle; it does not apply to minutes_extract_prescreen.R
   or any other script.

Validated 34/37 corpus_include on FAC 967 (3 exclusions: 2 confirmed Annual
Meeting documents, out of scope by design; 1 additional exclusion to
confirm). Full run completed across all four hospitals (197 documents
total). 905 and 736 extractions have not yet been individually spot-checked
against source PDFs — that is the first item for the next session.
```

---

## How to Spot-Check 905 and 736

967 has manual confirmation behind both the narrative-opening fix and the no-close-detection decision. 905 and 736 do not yet — this is the one part of today's design that's only been validated against one of the four hospitals. Before treating `minutes_extract_summary_results.rds` as final:

1. **Load the results and pull a small sample per hospital.**
   ```r
   results <- readRDS("roles/minutes/outputs/minutes_extract_summary_results.rds")
   
   sample_905 <- results |> filter(fac == "905", corpus_include) |> slice_sample(n = 3)
   sample_736 <- results |> filter(fac == "736", corpus_include) |> slice_sample(n = 3)
   ```

2. **For each sampled document, check the start page against the source PDF.** Confirm `minutes_page_start` actually lands on the page where the Board Highlights / meeting-summary content begins — not a page earlier (e.g. a cover page that happens to carry a date) or a page later (missing the opening paragraph). This is the same check that caught the Cornwall narrative-opening gap, just applied to hospitals where the opening-statement wording hasn't been independently confirmed.

3. **Check the end of `full_text` against the source PDF's last page.** Since there's no close-detection step, confirm the document genuinely ends where the OCR text ends — specifically watch for:
   - Trailing pages of unrelated content (a second document scanned into the same PDF, an appendix, a different month's highlights stapled on).
   - A document that's actually longer than what got OCR'd (extraction quietly truncated for a reason unrelated to content, e.g. a PDF conversion issue).

4. **Look for `no_start_detected` documents specifically.** If either hospital's exclusion count looks disproportionate to its total document count, open one or two of the excluded PDFs directly and check whether they're genuinely a different format (like the Cornwall Annual Meetings) or a header/opening-statement wording gap the current patterns don't cover — the same diagnostic step that found the round-1 and round-2 issues on Cornwall.

5. **If 905 or 736 turn up a new pattern gap,** the fix almost certainly belongs in `detect_header_page_summary()` or `detect_meeting_open_page()` — the same functions patched twice already this session — rather than a new detection path. Check there first.

If all of the above look clean on the sampled documents, the four-hospital summary tier is ready to hand off to `MinutesSummary` tier assignment work.

---

## Session End Checklist

- [x] Save as `SessionSummaryJuly052026.md` — confirm `.md` extension before closing
- [x] Upload to Claude Project knowledge repository
- [x] Commit `minutes_extract_summary.R` to GitHub per instructions above
- [x] Spot-check 905 and 736 samples per the protocol above before trusting the full output — resolved via bug fix, see July 6 doc
- [x] Fill in the FAC 905/736/644 rows of the results table above once console output is reviewed
- [x] Resume paused carry-forward items: FAC 644 registry-level duplicate tag, `MinutesSummary` tier resolution, Quinte (957) remainder-batch test — see `SessionSummaryJuly062026.md`
