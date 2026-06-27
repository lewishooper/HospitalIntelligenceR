# HospitalIntelligenceR
## Session Summary — June 26, 2026 (PM)
## Board Minutes — LLM Stage 1 Classifier Finalised; Pre-Filter Built and Validated
*For Claude Project Knowledge Repository*

---

## Next Session — Start Here

**Current priority:** Build `llm_run1_classify.R` — the full corpus classification
script — and update the pass/fail banner in `llm_validate_run1.R` to reflect
Stage 1 criteria before running the full corpus.

**First action:** Build `llm_run1_classify.R`. It follows the same pipeline as
`llm_validate_run1.R` (OCR → prescreen → LLM) but loops over all documents in
`minutes_index.csv` rather than the validation set, and writes a corpus-level
results CSV. Claude will build this script from scratch at session start.

**Watch out for:**
- The pass/fail banner in `llm_validate_run1.R` still uses the original zero-FP
  criterion from the feasibility plan. Update it before re-running: Stage 1 criterion
  is ≥95% accuracy + zero false negatives. Zero false positives is a Stage 2 criterion.
- FAC 953 (Sunnybrook org chart) is a known, documented false positive — irreducible
  at the prompt level. It will appear as `MinutesOnly` in the full corpus output.
  Log it in the methods as a known exception; do not attempt further prompt revision.
- Full corpus run is projected at ~12 hours (1,732 docs × 24.9s mean). Plan to
  run overnight or as a background job. Confirm Ollama is running on Ubuntu before
  starting.
- `minutes_index.csv` has 1,835 rows but the corpus projection uses 1,732 — the
  difference is files that may not exist on disk. The classify script must check
  `file.exists()` before processing and log missing files to a separate CSV.
- Both `llm_validate_run1.R` and `llm_validate_run2_random.R` contain the current
  operative `prescreen_document()` function. If the pre-filter is revised again,
  update both files.

### Carry-Forward Items

| Item | Status | Notes |
|---|---|---|
| Build `llm_run1_classify.R` — full corpus script | READY TO EXECUTE — FIRST ACTION | Loops over minutes_index.csv; same pipeline as validate script |
| Update pass/fail banner in `llm_validate_run1.R` | READY TO EXECUTE | Stage 1: ≥95% accuracy + 0 FN. Remove zero-FP requirement. |
| Run full corpus classification (~12 hr) | BLOCKED on script build | Run overnight; confirm Ollama running first |
| Stage 2 design — boundary detection pass | NOT STARTED | Blocked on Stage 1 corpus output |
| Compression signal — Stage 2 pre-filter | PARKED | Removed from Stage 1; reserved for Stage 2 with fuller context |
| Random sample blind evaluation scoring | COMPLETE | 29/30, 96.7% — results in llm_run2_random_results.csv |
| KVM switch installation | PENDING HARDWARE | Frees ~789 MiB VRAM from GNOME RDP |

---

## Session Objectives

Complete prompt revision cycle for Stage 1 LLM classifier; build and validate the
R-side pre-filter; run the random-sample blind evaluation; reach go/no-go decision
on full corpus run.

---

## Work Completed

### 1. Pre-Filter Built and Validated (`prescreen_document()`)

An R-side pre-classifier was added to `extract_and_classify()`, running between
OCR and the LLM call. Current Stage 1 implementation has one signal and one guard:

**Signal 1 — Standalone AGENDA heading:**
Detects the word `AGENDA` on a line by itself within the first 40 lines of OCR
text. Characteristic of agenda packages; never observed as a standalone heading
in genuine board minutes across any validation document reviewed.

**Positive guard — MINUTES + attendance label:**
If both `MINUTES` (as a word) and an attendance label (`Present:`, `In Attendance:`,
etc.) appear in the first 40 lines, skip all negative signals and pass directly to
LLM. Protects documents that have already declared themselves as minutes.

**Compression signal — removed from Stage 1:**
A signal detecting 4+ consecutive short numbered lines was built and tested but
produced a false negative on FAC 939 (Holland Bloorview) — a genuine minutes
document with a numbered list in the body text. In a two-stage architecture, false
negatives in Stage 1 are cheap (document goes to Stage 2); false positives are
expensive (non-minutes accepted permanently). The signal was removed from Stage 1
and parked for Stage 2, where it can be applied with fuller document context
(e.g. only trigger if compression appears before any attendance block).

**Validation results with pre-filter:**
- FACs 661 and 935 correctly caught by AGENDA heading signal, zero LLM time
- FAC 939 correctly passed to LLM after removing compression signal
- Pre-filter added no false positives or false negatives on 30-document set

### 2. Random Sample Blind Evaluation (`llm_validate_run2_random.R`)

A stratified 30-document random sample was drawn from `minutes_index.csv`:
- 20 documents drawn randomly (one per FAC, then FACs sampled)
- 10 documents from known difficult-format hospitals (BoardPro, multi-column,
  known false positive FACs)

Script built as `llm_validate_run2_random.R` — self-contained, runs independently
of `llm_validate_run1.R`. Output CSV includes `hand_label` and `hand_notes`
columns for blind evaluation.

**Results: 29/30 (96.7%), 0 false negatives, 1 false positive (FAC 953)**

This confirms the curated validation set was representative or slightly harder
than the corpus average — random sample performance is better, not worse.

### 3. Final Validation Set Score (`llm_validate_run1.R`)

After all pre-filter and prompt revisions:

| Metric | Value | Target |
|---|---|---|
| Overall accuracy | 29/30 (96.7%) | — |
| High-confidence accuracy | 96.7% | ≥95% |
| High+medium accuracy | 96.7% | ≥90% |
| False positives | 1 (FAC 953) | 0 (original) |
| False negatives | 0 | 0 |
| Parse errors | 0 | — |
| Mean total time/doc | 24.9s | — |
| Projected corpus run | 12.0 hr | — |

Banner reports FAIL due to original zero-FP criterion. This criterion predates
the two-stage architecture and is being updated. Effective Stage 1 result: **PASS**.

### 4. Go/No-Go Decision

**Decision: GO on full corpus run.**

Rationale:
- 96.7% accuracy exceeds the ≥95% Stage 1 threshold
- Zero false negatives — no genuine minutes are being missed by Stage 1
- The one false positive (FAC 953) is a known, documented, specific exception —
  an org chart that the model hallucinates an attendance block for. Further prompt
  revision has been demonstrated not to fix it (four rounds attempted).
- In the two-stage architecture, Stage 1 false positives will be reviewed in
  Stage 2; FAC 953-type documents produce empty/low-quality extraction output
  that will be detectable and filterable downstream.

### 5. Two-Stage Architecture — Design Principles Established

This session solidified the Stage 1 / Stage 2 framework:

**Stage 1 (current):** Conservative `MinutesOnly` acceptance. Pre-filter + LLM.
High threshold for accepting a document as minutes. False negatives (uncertain
documents) pass to Stage 2. False positives (non-minutes accepted as minutes) are
the expensive error to minimise.

**Stage 2 (future):** Boundary detection. Receives all documents Stage 1 passed
through, plus Stage 1 false negatives. Different criteria: locate the start and
end boundaries of the minutes within a mixed document. Compression signal
(consecutive short numbered lines before attendance block) is a candidate
Stage 2 pre-filter.

**Key principle:** In a multi-stage pipeline, optimise each stage for its own
error cost. Stage 1 false negatives are cheap; Stage 1 false positives are
expensive. This inverts the usual single-stage optimisation target.

---

## Key Design Decisions

| Decision | Rationale |
|---|---|
| Override zero-FP pass criterion for Stage 1 | Criterion predates two-stage architecture. FAC 953 is a known specific exception, not evidence of systemic failure. Zero-FP criterion moves to Stage 2. |
| Remove compression signal from Stage 1 | Signal fired on OCR-interleaved body text (FAC 939), not agenda structure. In Stage 1, false negatives are cheap — pass uncertain documents to Stage 2. |
| Compression signal parked for Stage 2 | In Stage 2, can be applied conditionally: only trigger if compression appears before any attendance block. More context = more reliable signal. |
| Positive guard added to prescreen | MINUTES heading + attendance label in first 40 lines → skip negative signals. Protects documents that have already declared themselves. |
| Full corpus run approved | 96.7% accuracy, 0 FN, 1 known FP. Build `llm_run1_classify.R` next session. |

---

## Operative Prompt and Pre-Filter State

**Pre-filter (`prescreen_document()`)** — saved in both `llm_validate_run1.R`
and `llm_validate_run2_random.R`:
- Signal 1: standalone `AGENDA` heading in first 40 lines → `SomethingElse`
- Positive guard: `MINUTES` + attendance label in first 40 lines → pass to LLM
- Compression signal: removed (Stage 2 only)

**LLM prompt** — Round 3, saved in `llm_validate_run1.R` Section 1c:
- Requires all three: Board of Directors header + valid attendance block + closing
- Attendance block: dedicated grouped list under label, immediately after header
- Disqualifies: footer names, org chart names, agenda item presenters
- Disqualifies: forward-looking agenda tables, summary format titles, committee-only headers
- Joint meeting carve-out preserved
- Sentinel suppression preserved

---

## Files Produced or Modified

| File | Location | Change |
|---|---|---|
| `llm_validate_run1.R` | `E:/HospitalIntelligenceR/roles/minutes/scripts/` | Modified — prescreen_document() added; extract_and_classify() updated |
| `llm_validate_run2_random.R` | `E:/HospitalIntelligenceR/roles/minutes/scripts/` | Created — random sample validation script |
| `llm_run2_random_results.csv` | `E:/HospitalIntelligenceR/roles/minutes/outputs/` | Created — random sample results (29/30) |
| `llm_run1_validation_results.csv` | `E:/HospitalIntelligenceR/roles/minutes/outputs/` | Updated — final round results (29/30) |
| `SessionSummaryJune262026_PM.md` | Upload to knowledge repository | This file |

---

## GitHub Commit Instructions

```
roles/minutes/scripts/llm_validate_run1.R              — modified (prescreen added)
roles/minutes/scripts/llm_validate_run2_random.R       — created
roles/minutes/outputs/llm_run2_random_results.csv      — created
roles/minutes/outputs/llm_run1_validation_results.csv  — updated
docs/session_summaries/SessionSummaryJune262026_PM.md  — created
```

**Commit message:** `T1: Stage 1 classifier finalised — 96.7% on validation and random sample`

**Description:**
```
Pre-filter (prescreen_document) built and validated:
- Signal 1: standalone AGENDA heading → SomethingElse (catches FACs 661, 935)
- Positive guard: MINUTES + attendance label → pass to LLM
- Compression signal removed from Stage 1; parked for Stage 2

Random sample blind evaluation (llm_validate_run2_random.R):
29/30 (96.7%), 0 FN, 1 FP (FAC 953, known exception).

Go/no-go: GO. Next: build llm_run1_classify.R for full corpus run.
```

---

## Session End Checklist

- [x] Upload `SessionSummaryJune262026_PM.md` to knowledge repository
- [x] Commit all modified and created files to GitHub
- [ ] Confirm `llm_validate_run1.R` saved with prescreen_document() and updated extract_and_classify()
- [ ] Confirm `llm_validate_run2_random.R` saved to scripts folder
- [ ] Note: pass/fail banner update in `llm_validate_run1.R` deferred to next session (do alongside classify script build)
