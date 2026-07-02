# HospitalIntelligenceR
## Session Summary — July 02, 2026
## Board Minutes — minutes_extract_prescreen.R Build and Two Rounds of Debugging
*For Claude Project Knowledge Repository*

---

## Next Session — Start Here

**Current priority:** Validate the call-to-order + time anchor (the third start-detection approach tried this session) against the five documents where the prior two approaches failed, before running the script on the full 35-document set.

**First action:** Run `minutes_extract_prescreen.R` in single-document test mode (`TEST_FAC` / `TEST_FILENAME`) against each of: CMH 661 (`2024-11-06_board_minutes.pdf`), CMH 661 (the file that picked up the motions-summary page — filename not yet confirmed, identify from `llm_run1_fulltext_scan.csv`), TBay 935 (`2025-04-02_board_minutes.pdf`), TBay 935 (the slide-deck false-start file — filename not yet confirmed), and Holland Bloorview (FAC not yet confirmed — identify from the original 35-document run). Inspect `minutes_page_start`, `minutes_page_end`, and the first ~200 characters of `full_text` for each against a manual read of the source PDF.

**Watch out for:**
- The script has NOT been run since this rewrite. Everything below is design work only — the call-to-order anchor is untested.
- Two prior start-detection approaches were tried and rejected this session (see Key Design Decisions). Do not revert to header-alone or header+attendance without a specific reason — both were empirically shown to produce false positives on agenda pages, a motions-summary document, and a slide deck.
- If the call-to-order anchor fails on any of the five test cases, do not patch incrementally without seeing the actual extracted text first — the prior two rounds of "looks reasonable" fixes both turned out to have real per-page bugs invisible from the QA-flag counts alone.
- `filename` values for three of the five test cases (CMH 661 motions-summary doc, TBay 935 slide-deck doc, Holland Bloorview) were referenced conversationally but not recorded precisely — confirm exact filenames from `llm_run1_fulltext_scan.csv` before setting `TEST_FILENAME`.

### Carry-Forward Items

| Item                                                         | Status            | Notes                                                        |
| ------------------------------------------------------------ | ----------------- | ------------------------------------------------------------ |
| Validate call-to-order anchor on 5 known failure cases       | READY TO EXECUTE  | Test mode built for exactly this; see First Action above     |
| Run full 35-document batch                                   | BLOCKED           | Blocked on the validation above passing cleanly              |
| Review `no_start_detected` / `no_close_detected` flagged docs | FUTURE WORKSTREAM | Depends on full batch run; expect a manual review export similar to `llm_run1_manual_review.R` |
| Confirm `bucket` column exists in `llm_run1_fulltext_scan.csv` with `agenda_prescreen` value | ASSUMED CONFIRMED | User-provided sample row from `llm_run1_results.csv` confirmed `local_path` format; `llm_run1_fulltext_scan.csv`'s `bucket` column itself has not been directly inspected, only inferred from `llm_run1_manual_review.R` header comments |
| Tag FAC 644 as `duplicate_of: 967`                           | READY TO EXECUTE  | Carried forward from July 1 AM session; apply at master build |
| Design `decision_substance` weighting field                  | FUTURE WORKSTREAM | Carried forward from July 1 AM session; deferred to master build |
| LH prior corpus: locate dataframe, assess format and FAC overlap | FUTURE WORKSTREAM | Carried forward — blocked on Stage 2 completion, which is itself blocked on this extraction script |
| Internal date extraction pass over MinutesOnly corpus        | FUTURE WORKSTREAM | Carried forward from July 1 AM session                       |
| Build `minutes_analytical_master.rds`                        | FUTURE WORKSTREAM | Blocked on this extraction script's successful completion    |

---

## Session Objectives

Design and build `minutes_extract_prescreen.R` — the extraction script for the 35 `agenda_prescreen` documents, the last blocker before Stage 2 of the board minutes pipeline is complete. Goal was a working standalone script producing full extracted text (not just page pointers) for downstream workstreams.

---

## Work Completed

### 1. Initial script build

Built `minutes_extract_prescreen.R` reusing `detect_header()` / `detect_close()` from `minutes_classify.R` (duplicated inline, since `minutes_classify.R` is not safely sourceable). Design decisions made before coding: standalone script (not folded into `minutes_extract_mixed.R`); output captures full extracted text per document, not just a page-range pointer, since downstream workstreams (W4 topic mining, W5 sentiment) need actual text; input resolved via join between `llm_run1_fulltext_scan.csv` (bucket == "agenda_prescreen") and `llm_run1_results.csv` (for `local_path`); output as `.rds` per project data standard.

First run completed on all 35 documents: 22 `corpus_include = TRUE`, 12 `no_close_detected`, 0 `no_header_detected`, 0 `file_missing`, 0 `ocr_failed`.

### 2. First bug round — percentage-slicing applied per-page

Manual spot-check of the first run's cross-tab (`count(qa_flag, corpus_include, doc_class)`) revealed the corpus_include=FALSE documents were not clean true-negatives as assumed. User's manual review of source PDFs found: all 35 documents were starting extraction on page 1 (the agenda page itself, not the embedded minutes); a Cambridge document with a clear termination motion and a Thunder Bay document with a clear adjournment were both flagged `no_close_detected` despite having obvious endings.

**Bugs fixed:**

| Bug                                                          | Fix Applied                                                  |
| ------------------------------------------------------------ | ------------------------------------------------------------ |
| `detect_header()` fires on the agenda cover page's own title boilerplate, always returning page 1 as start | Added `detect_attendance_page()` co-occurrence requirement within a 3-page window (later superseded — see Round 2) |
| `detect_close()` and `detect_attendance()` use percentage-based slicing (`first 40%`, `last 15%`) valid only for whole-document text; applied per-page, real endings/attendance blocks outside that literal character slice were missed | Added `detect_close_page()` and `detect_attendance_page()` — page-level variants with no percentage slicing, checking the full page text |
| Silent EOF fallback on close detection risked over-extraction into trailing report/financial content | Removed EOF fallback; `no_close_detected` now always routes to manual review flag |

### 3. Second bug round — header+attendance still too promiscuous

Single-document test mode was added (`TEST_FAC` / `TEST_FILENAME` config toggle, separate `_TEST.rds` output path) to allow rapid iteration on individual documents rather than re-running the full 35 for each fix. User then hand-tested the Round 1 fix against five specific documents: CMH 661 (two files) and TBay 935 (two files), plus a spot-check on Holland Bloorview from the original run.

Findings: the header+attendance co-occurrence gate from Round 1 was still producing false starts. CMH 661 picked up an agenda page (page 2, not page 3 where the real agenda content ended) because the agenda page's own boilerplate satisfied both header and the loose attendance regex (`\\bpresent\\b`, `\\bregrets\\b` matching agenda item *titles* with no context) — and because start landed there, `detect_close_page()` then matched "Termination" as an agenda line item, not a real adjournment sentence, producing a clean-looking but entirely wrong result with no qa_flag at all. A second CMH 661 file picked up a motions-summary document (a document listing motions coming forward, not the minutes themselves) for the same reason. Both TBay 935 files showed the same pattern — one picked up a slide deck, the other a numbered list — both bypassing the real minutes content (which began on page 17 in one case) due to the same promiscuous gate. Holland Bloorview — a document that is agenda-only with no embedded minutes — still produced an extraction rather than a `no_start_detected` flag, confirming the gate had no real specificity.

Close detection (Round 1's `detect_close_page()` fix) performed correctly across all five spot-checked cases — this round only affected start detection.

**Bugs fixed:**

| Bug                                                          | Fix Applied                                                  |
| ------------------------------------------------------------ | ------------------------------------------------------------ |
| header+attendance co-occurrence satisfied by agenda title boilerplate and agenda item titles with no narrative context (e.g. "Regrets" as a line-item label) | Replaced with `detect_call_to_order_page()` — requires "call(ed) to order" to co-occur with an actual clock time (`\\d{1,2}:\\d{2}\\s*(a\\.?m\\.?\|p\\.?m\\.?)`) within ~150 characters. A real minutes narrative sentence has this; an agenda line item, slide deck, or motions-summary document does not. |
| Attendance signal discarded entirely as a gate, but still useful as a diagnostic | Retained as `attendance_nearby` — an informational (non-gating) output column, checked in a 2-page window from the confirmed start |

**Status at end of session:** the call-to-order anchor is implemented but not yet tested against the five known failure cases. Script was rewritten in full and will be saved without running, per user's end-of-day timing.

---

## Key Design Decisions

| Decision                                                     | Rationale                                                    |
| ------------------------------------------------------------ | ------------------------------------------------------------ |
| Standalone script, not folded into `minutes_extract_mixed.R` | Shares detection-function logic but differs in input population, schema, and downstream target from the Tier 1 mixed-package pattern; keeping them separate avoids entangling two independently-closed pipeline stages. |
| Output captures full extracted text (`full_text` column), not just page pointers | Deviation from the Tier 1 `minutes_extract_mixed.R` pattern, which only wrote page markers. `minutes_analytical_master.rds` needs to serve topic-mining and sentiment workstreams that require actual text, not a range to re-fetch later. |
| No EOF fallback on close detection                           | Round 1 finding: silent EOF fallback risks pulling in trailing report/financial content. A document with no detected close is a real signal worth a human look, not something to paper over with a guessed boundary. |
| Header+attendance rejected as the start gate; replaced with call-to-order + clock-time anchor | Empirically shown (five hand-checked documents) to produce false positives on agenda pages, a motions-summary document, and a slide deck — including one fully spurious extraction from an agenda-only document. Call-to-order + time is a narrower, narrative-specific signal that boilerplate and line-item titles don't satisfy. |
| Attendance signal retained as informational only, not a gate | Round 2 showed it's too promiscuous as a gate on its own, but still useful as a cross-check column when spot-reviewing individual extraction results. |
| Continue debugging in R rather than route to Ollama/Claude API | Both failure rounds traced to concrete, fixable code defects (invalid slicing applied at the wrong granularity; an overly broad gate), not to a task requiring language understanding beyond what deterministic pattern matching can do. |
| Single-document test mode added, with separate `_TEST.rds` output path | Enables rapid iteration on individual known-problem documents without re-running the full 35-document OCR batch for every fix, and without the test output silently overwriting a prior full-batch result. |

---

## Files Produced or Modified

| File                          | Location                                          | Change                                                       |
| ----------------------------- | ------------------------------------------------- | ------------------------------------------------------------ |
| `minutes_extract_prescreen.R` | `E:/HospitalIntelligenceR/roles/minutes/scripts/` | Created, then rewritten twice within this session (percentage-slicing fix, then start-gate replacement). Not yet run in its current form — user will save and run next session. |
| `SessionSummaryJuly022026.md` | Upload to knowledge repository                    | This file                                                    |

---

## GitHub Commit Instructions