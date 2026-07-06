# HospitalIntelligenceR
## Session Summary — July 06, 2026
## Board Minutes — Summary-Tier Workstream Closed Out; Handoff to SomethingElse Remainder
*For Claude Project Knowledge Repository*

---

## Next Session — Start Here

**Current priority:** Process the remainder of the `SomethingElse` bucket using the strict same-page 3-signal start gate already validated in `minutes_extract_prescreen.R` (header+date, name-list, call-to-order+time). The target-set change needed to build this remainder list (excluding 941, 975, and the four summary-tier FACs, and excluding the 35 already-handled `agenda_prescreen` documents) was designed July 5 but has not yet been run.

**First action:** Run the modified `minutes_extract_prescreen.R` Section 1 (remainder target-set logic — see July 5 chat record or reconstruct from the exclusion list below if not already saved to the script on disk) with `TEST_FAC <- "957"` (Quinte) and no `TEST_FILENAME`, so all 4 remaining Quinte `SomethingElse` documents run in one pass. Review the `print_page_diagnostics()` output per document — Quinte's known pattern (minutes buried after reports/other content earlier in the same file) is untested against the same-page 3-signal requirement.

**Watch out for:**
- Quinte's pattern — reports preceding minutes within a single file — may mean header, name-list, and call-to-order don't all land on the same physical page the way they do in a document that opens directly with minutes. If the same-page requirement proves too strict for this pattern, that's a design conversation to have explicitly (same rigor as the summary-tier gate redesign), not a quick patch.
- The summary-tier corpus (905/967/644/736) is now closed and should not be touched by remainder-batch work — `SUMMARY_FACS` must stay in the remainder script's exclusion list so these documents aren't processed twice under two different gates.
- `TEST_FAC`/`TEST_FILENAME` discipline applies here too — confirm both are reverted to `NULL` before any full remainder-batch run, same as every other script in this pipeline.

### Carry-Forward Items

| Item | Status | Notes |
|---|---|---|
| Quinte (957) remainder test batch | READY TO EXECUTE | **Current priority** — see above |
| Full `SomethingElse` remainder batch (~250 docs before excluding `agenda_prescreen`'s 35) | BLOCKED | Blocked on Quinte test confirming the same-page gate holds for the buried-minutes pattern |
| Apply FAC 644 `duplicate_of: 967` tag (registry-level, in `hospital_registry.yaml`) | READY TO EXECUTE | Still open. Distinct from the `analytical_include` row-level exclusion applied this session — that solves the double-counting problem in the extraction output; the registry tag is the separate, durable metadata record |
| Resolve `MinutesSummary` tier assignments | READY TO EXECUTE | The four-hospital summary-tier corpus this depends on is now final and clean (905, 736, 967 confirmed; 644 correctly excluded via `analytical_include`) |
| Design `decision_substance` weighting rubric for `MinutesSummary` tier | FUTURE WORKSTREAM | Deferred to master-build time |
| LH prior corpus decision (archived data integration) | FUTURE WORKSTREAM | Mandatory pre-step before master build |
| Internal date extraction pass over MinutesOnly corpus | FUTURE WORKSTREAM | Mandatory pre-step before master build |
| Build `minutes_analytical_master.rds` | FUTURE WORKSTREAM | Blocked on all of the above |
| Reconcile hospital-level `SomethingElse` count estimates against `llm_run1_results.csv` | LOW URGENCY | Carried forward unresolved from July 5 |

---

## Session Objectives

Diagnose and fix a bug surfaced when running the summary-tier extraction (`minutes_extract_summary.R`) at full scale against FAC 905, confirm final results across all four summary-tier hospitals, empirically verify the FAC 644/967 duplicate relationship at the file level, and add an exclusion mechanism so duplicate content doesn't propagate into future analysis. Close out the summary-tier workstream and hand off to the `SomethingElse` remainder-batch work as the next priority.

---

## Work Completed

### 1. Third detection-gap bug — active-voice call-to-order construction (FAC 905)

Running the full FAC 905 batch (69 documents) surfaced a failure on `2023-06-15_board_minutes.pdf`: `header_summary=TRUE`, `meeting_open=FALSE`, despite the page containing an unambiguous match on manual read — "Mike Arnew, Chair, called the meeting to order at 5:00 p.m. on June 15, 2023."

**Root cause:** `detect_call_to_order_page()`'s regex (`call(ed)? to order`) requires "call(ed)" and "to order" to sit immediately adjacent. CMH and Windsor's documents (which this pattern was originally built against, in `minutes_extract_prescreen.R`) use a **passive** construction — "the meeting **was called to order** at..." — where the words are adjacent. Oak Valley uses an **active** construction — "**called the meeting to order** at..." — where "the meeting" sits between "called" and "to order," so the exact-adjacency pattern never matched.

This is a latent gap in `minutes_extract_prescreen.R`'s original pattern too, just never surfaced there because none of that script's validated documents happened to use the active form. No change was made to `minutes_extract_prescreen.R` — that script is already validated and closed; the fix was scoped to `minutes_extract_summary.R` only.

**Bugs fixed:**

| Bug | Fix Applied |
|---|---|
| `detect_call_to_order_page()` required exact adjacency between "call(ed)" and "to order," matching only the passive construction ("was called to order"). Oak Valley's active construction ("called the meeting to order") was never recognized despite being unambiguous on manual read | Regex broadened to `call(ed)?\s(?:[a-z]+\s){0,3}to order`, tolerating up to 3 intervening lowercase words between "call(ed)" and "to order" |

### 2. Final confirmed results — all four summary-tier hospitals

Re-ran FAC 905 after the fix: **69/69 `corpus_include`, 0 exclusions.** Reconfirmed FAC 736 (previously working, re-checked after the 905 fix in case the broadened regex changed anything downstream): **52/54, 2 exclusions (1 confirmed Annual Meeting, 1 other)** — unchanged from the pre-fix result, as expected since 736's documents didn't depend on the narrower call-to-order pattern. FAC 644 confirmed run.

| FAC | Hospital | Total docs | `corpus_include TRUE` | Exclusions |
|---|---|---|---|---|
| 905 | Oak Valley | 69 | 69 | 0 |
| 736 | Newmarket Southlake | 54 | 52 | 2 (1 annual, 1 other) |
| 967 | Cornwall Community | 37 | 34 | 3 (2 annual, 1 other) |
| 644 | Cornwall Hotel Dieu | 37 | run — excluded from analysis via `analytical_include` | — |

A zero-exclusion result on 905 (69/69) is worth a light mental flag going forward — it's the cleanest of the four hospitals, and the broadened call-to-order pattern is also the most permissive of the detection changes made this workstream. If a future spot-check on 905 content turns up a false positive (a start page detected that isn't genuinely the opening of a summary document), this pattern is the first place to look.

### 3. FAC 644 / 967 duplicate relationship — empirically verified

Skip flagged a concern: are we adding duplicate content into the results? Checked directly against `llm_run1_results.csv` by comparing filenames between the two FACs.

**Result: 42/42 filenames identical between FAC 644 and FAC 967.** This is not two hospitals independently producing similar-format minutes — it is the same 42 source PDFs, catalogued under two different FAC codes (Cornwall Community and Cornwall Hotel Dieu operate under a shared board and shared minutes). This upgrades the project record's prior note ("644 is a duplicate carrying an explicit deferral note") from an assumption to a directly confirmed fact at the file level.

**Consequence:** running the summary extraction separately on 644 and 967 produces two full sets of duplicate rows in the output. Left unaddressed, any downstream analysis (tier assignment, master build) would double-count every Cornwall document.

### 4. `analytical_include` exclusion flag added

Rather than deleting FAC 644's rows outright (which would lose the OCR/extraction as a provenance cross-check — both passes agree, which is itself a useful confirmation the pipeline behaves consistently on identical input), an `analytical_include` column was added to `minutes_extract_summary_results.rds`:

```r
results <- results |>
  mutate(
    analytical_include = corpus_include & !(fac == "644" & !is.na(is_duplicate_of))
  )
```

`corpus_include` remains the honest, unmodified record of what the extraction gate found. `analytical_include` is the column any downstream script — `MinutesSummary` tier assignment, eventually the master build — should filter on. Skip confirmed FAC 644 rows now read `analytical_include = FALSE` in the saved output.

### 5. Data-flow clarification — no write-back occurred

Skip asked whether the summary-tier results had been "handed off" or "transferred" into `results_all`. Confirmed this has not happened, and clarified why the question doesn't quite apply the way it might sound:

- `results_all` in `minutes_extract_summary.R` is an in-memory variable only, rebuilt fresh from `llm_run1_results.csv` each run — never written back to disk.
- `llm_run1_results.csv` (Stage 1 classification) is untouched by this workstream.
- `minutes_extract_summary_results.rds` (the actual extraction output) remains a standalone file — not merged into anything yet.

The eventual merge of `agenda_prescreen`, summary-tier, and remainder-batch extractions into a single corpus is what `minutes_analytical_master.rds` is for — still a future workstream, blocked on the other mandatory pre-steps.

---

## Key Design Decisions

| Decision | Rationale |
|---|---|
| Scoped the active-voice call-to-order fix to `minutes_extract_summary.R` only, left `minutes_extract_prescreen.R` unmodified | `minutes_extract_prescreen.R` is already validated and closed against its own 35-document batch; the active-construction gap is latent there too but hasn't caused a confirmed failure, and reopening a closed, validated script for an untriggered theoretical gap isn't warranted right now |
| Kept FAC 644's extracted rows in the output rather than dropping them, added `analytical_include` as a separate filter column instead | Preserves `corpus_include` as an honest per-document detection record and keeps the 644/967 dual-pass agreement as a provenance cross-check, while still giving downstream scripts a single clean column to filter on so duplicates can't leak into analysis by accident |
| Treated the FAC 644/967 file-level duplicate finding as empirically confirmed rather than re-asserting the prior assumption | Direct comparison against `llm_run1_results.csv` (42/42 identical filenames) is stronger evidence than the previously-recorded assumption; worth updating the project record to reflect verified fact rather than inference |

---

## Files Produced or Modified

| File | Location | Change |
|---|---|---|
| `minutes_extract_summary.R` | `E:/HospitalIntelligenceR/roles/minutes/` | Modified — broadened `detect_call_to_order_page()` to tolerate intervening words between "call(ed)" and "to order" (active-voice construction) |
| `minutes_extract_summary_results.rds` | `E:/HospitalIntelligenceR/roles/minutes/outputs/` | Overwritten — final four-hospital run (905: 69/69, 736: 52/54, 967: 34/37, 644: run and flagged `analytical_include = FALSE`); `analytical_include` column added |
| `SessionSummaryJuly052026.md` | Knowledge repository | Updated — placeholder results table filled in, superseded pointer added to "Next Session — Start Here," carry-forward items marked resolved where applicable |
| `SessionSummaryJuly062026.md` | Upload to knowledge repository | This file |

---

## GitHub Commit Instructions

```
roles/minutes/minutes_extract_summary.R                — modified
docs/session_summaries/SessionSummaryJuly052026.md      — modified
docs/session_summaries/SessionSummaryJuly062026.md      — created
```

**Commit message:** `T2: fix active-voice call-to-order gap, close out summary-tier workstream`

**Description:**
```
Fixed detect_call_to_order_page() in minutes_extract_summary.R: the regex
required exact adjacency between "call(ed)" and "to order," matching only a
passive construction ("was called to order"). Oak Valley (FAC 905) uses an
active construction ("called the meeting to order at [time]"), which the
adjacency requirement never matched. Broadened to tolerate up to 3
intervening lowercase words. Same latent gap likely exists in
minutes_extract_prescreen.R (built against passive-construction documents
only) but is untriggered there and was left unmodified — that script is
already validated and closed.

Reconfirmed all four summary-tier hospitals after the fix: 905 (69/69,
0 exclusions), 736 (52/54, 2 exclusions unchanged from pre-fix), 967
(34/37, previously confirmed), 644 (run, excluded from analysis).

Verified FAC 644/967 duplicate relationship empirically: 42/42 identical
filenames between the two FACs in llm_run1_results.csv — confirms these are
the same source documents catalogued under two FAC codes, not independently
similar content. Added analytical_include column to
minutes_extract_summary_results.rds so downstream scripts (tier assignment,
master build) filter out FAC 644 without losing the raw corpus_include
record or the dual-pass provenance cross-check.

This closes the summary-tier extraction workstream. Next priority is
processing the SomethingElse remainder (target-set change designed July 5,
Quinte 957 test batch not yet run).
```

---

## Session End Checklist

- [ ] Save as `SessionSummaryJuly062026.md` — confirm `.md` extension before closing
- [ ] Upload to Claude Project knowledge repository (both this file and the updated `SessionSummaryJuly052026.md`)
- [ ] Commit `minutes_extract_summary.R` and both session summaries to GitHub per instructions above
- [ ] Confirm `analytical_include` column was saved to `minutes_extract_summary_results.rds` on disk via `saveRDS()`, not left as a transient in-session object
- [ ] Run Quinte (957) remainder test batch — see "Next Session — Start Here"
- [ ] Resume: FAC 644 registry-level `duplicate_of` tag, `MinutesSummary` tier resolution
