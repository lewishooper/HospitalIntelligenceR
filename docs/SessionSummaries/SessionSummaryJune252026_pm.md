# HospitalIntelligenceR
## Session Summary — June 25, 2026
## Board Minutes — LLM Run 1 Validation (Two Prompt Revision Rounds)
*For Claude Project Knowledge Repository*

---

## Next Session — Start Here

**Current priority:** Execute prompt revision round 2 for Run 1 classification.
The revised prompt has three targeted changes identified at session end. Write,
run against the 30-document validation set, and score.

**First action:** Open `llm_validate_run1.R`. Replace the prompt in
`classify_document_llm()` with the round 2 version (to be built at next session
start). Run full script. Score Section 5 output.

**Watch out for:**
- The validation set (`llm_validation_run1.xlsx`) has been corrected: seq_num 15
  (FAC 905) is now `SomethingElse`; seq_num 21 (FAC 936 UNKNOWN_DATE_004) is now
  `MinutesOnly`. These corrections are live in the file. Do not revert.
- Repeatability confirmed at 30/30 on this hardware with `temperature = 0`.
  This does not need to be re-tested.
- The `reasoning` field from the model is not a reliable audit trail — FAC 928
  demonstrated the model can produce confident, specific, and incorrect reasoning.
  Score on classification label only.
- OCR max time of 223s on FAC 661 is an outlier — large scanned package.
  Not a bug; expected for that document type.

### Carry-Forward Items

| Item | Status | Notes |
|---|---|---|
| Prompt revision round 2 | READY TO EXECUTE — FIRST ACTION | Three targeted changes identified — see Key Design Decisions below |
| Run 1 go/no-go decision | PENDING round 2 scoring | Target ≥90% high+medium, zero false negatives |
| `llm_run1_classify.R` — full corpus build | NOT STARTED | Blocked on go/no-go |
| Run 2 boundary detection pass | NOT STARTED | Blocked on Run 1 go/no-go |
| KVM switch installation | PENDING HARDWARE | Frees ~789 MiB VRAM from GNOME RDP |

---

## Session Objectives

Reconstruct the four core LLM pipeline functions from June 22, build and run the
Run 1 validation harness against the 30-document hand-labelled set, interpret
results, execute prompt revision round 1, identify overcorrection, correct
validation set labelling errors, and re-run to establish a clean baseline for
round 2.

---

## Work Completed

### 1. Core Functions Reconstructed and Harness Built

Four functions rebuilt and integrated into `llm_validate_run1.R`:
`extract_text_ocr()`, `prepare_for_llm()`, `classify_document_llm()`,
`extract_and_classify()`. See June 22 session summary for function specifications.

**Bugs fixed:**

| Bug | Fix Applied |
|---|---|
| Path double-prepend in Section 4 | `pdf_path <- file.path(EXTRACT_DIR, row$local_path)` replaced with `pdf_path <- row$local_path` — local_path already contains the full relative path |

### 2. Repeatability Confirmed

Re-ran 30 documents without changes: 30/30 identical classifications.
Practical determinism confirmed on GTX 1060 with `temperature = 0`.
This is noted in the methods record and does not need re-testing.

### 3. Original Prompt — Baseline Results

All 30 documents returned `high` confidence. No medium or low responses observed
across either run. This is a model behaviour pattern to note for the methods
writeup — the model does not express uncertainty on this task.

| Metric | Result | Target |
|---|---|---|
| Overall accuracy | 24/30 (80.0%) | — |
| High-confidence accuracy | 80.0% | ≥95% |
| False positives (SE→MO) | 1 | 0 |
| False negatives (MO→SE) | 5 | — |

### 4. FAC 928 Hallucination Investigation

`ReviewFile.R` on FAC 928 confirmed clean OCR. Model received "Chief of Staff
Report was included in the package" at agenda item 7 (before closed session at
item 8) and fabricated reasoning that these reports appeared after adjournment.
Pure reasoning error, not an OCR problem. The `reasoning` field is not a
reliable audit trail.

### 5. Prompt Revision Round 1 — Overcorrected

Four changes applied: sentinel suppression, joint meeting carve-out,
post-adjournment report tolerance, soft endings.

Result: 22/30 (73.3%) — worse than baseline. The soft-ending and
post-adjournment tolerance rules were too permissive, causing the model to
accept agenda packages and non-minutes documents with board headers.

### 6. Validation Set Corrections

Two labelling errors identified and corrected in `llm_validation_run1.xlsx`:

| seq_num | FAC | File | Old label | New label | Reason |
|---|---|---|---|---|---|
| 15 | 905 | 2021-06-16_board_minutes.pdf | MinutesOnly | SomethingElse | Summary format; confirmed SomethingElse per design intent |
| 21 | 936 | UNKNOWN_DATE_004_board_minutes.pdf | SomethingElse | MinutesOnly | Genuine board minutes; original labelling error |

### 7. Clean Baseline — Corrected Validation Set, Revised Prompt

Full script re-run with corrected validation set and revised prompt:

| Metric | Result | Target |
|---|---|---|
| Overall accuracy | 24/30 (80.0%) | — |
| High-confidence accuracy | 80.0% | ≥95% |
| False positives (SE→MO) | 6 | 0 |
| False negatives (MO→SE) | 0 | — |

Zero false negatives is the strongest result of the session — the model is not
missing genuine minutes. All errors are false positives driven by a single
failure mode: overreliance on "Board of Directors" heading without requiring
a genuine attendance block as a co-signal.

**False positive breakdown:**

| FAC | Document type | Failure mode |
|---|---|---|
| 661 | Agenda + reports package | Board header accepted without attendance block |
| 736 | Meeting Summary format | Board header + adjournment sufficient for model |
| 935 | Big package — agenda preamble in first 700 words | Board header + agenda item 8 "ADJOURNMENT" read as adjournment signal |
| 936 | Monthly CEO Report | "BOARD OF DIRECTORS" in report title block |
| 953 | Org structure chart | "Board of Directors" appears in org chart |
| 979 | Speaker bio | "President and CEO" read as board meeting signal |

---

## Key Design Decisions

| Decision | Rationale |
|---|---|
| Summary format minutes → `SomethingElse` | Board Highlights, Meeting Summary formats belong in Run 2 population regardless of partial structural signals present |
| FAC 905 reclassified to `SomethingElse` in validation set | Ambiguous document; "Meeting Summary" header and absence of attendance block place it in summary format class |
| FAC 936 UNKNOWN_DATE_004 reclassified to `MinutesOnly` | Original labelling error; document is genuine London Health Sciences board minutes |
| Prompt round 2 — three targeted changes identified | (1) Require attendance block as hard co-signal with board header; (2) explicitly disqualify forward-looking agenda tables; (3) explicitly disqualify Meeting Summary / Board Highlights title formats |
| Soft-ending rule reverted | Round 1 showed this was too permissive — agenda packages with "ADJOURNMENT" as a future agenda item were accepted as MinutesOnly |
| Post-adjournment report tolerance reverted | Also too permissive in round 1; original boundary language restored |
| Notes field confirmed not used by LLM | `hand_label_notes` is loaded for analyst reference only; never passed to model |

---

## Files Produced or Modified

| File | Location | Change |
|---|---|---|
| `llm_validate_run1.R` | `E:/HospitalIntelligenceR/roles/minutes/scripts/` | Created — four core functions + validation harness; round 1 revised prompt applied |
| `llm_validation_run1.xlsx` | `E:/HospitalIntelligenceR/roles/minutes/outputs/` | Modified — two label corrections (seq_num 15 and 21) |
| `llm_run1_validation_results.csv` | `E:/HospitalIntelligenceR/roles/minutes/outputs/` | Created — final run results (corrected validation set, revised prompt) |
| `SessionSummaryJune252026.md` | Upload to knowledge repository | This file |

---

## GitHub Commit Instructions

```
roles/minutes/scripts/llm_validate_run1.R              — created
roles/minutes/outputs/llm_validation_run1.xlsx         — modified (two label corrections)
roles/minutes/outputs/llm_run1_validation_results.csv  — created
docs/session_summaries/SessionSummaryJune252026.md     — created
```

**Commit message:** `T1: LLM Run 1 validation harness — baseline and prompt revision round 1`

**Description:**
```
Rebuilt four core LLM pipeline functions. Built and ran llm_validate_run1.R
against 30-document hand-labelled set. Repeatability confirmed 30/30.
FAC 928 hallucination documented — reasoning field flagged as unreliable.
Round 1 prompt revision overcorrected (73.3%). Two validation set labelling
errors corrected (FAC 905, FAC 936 UNKNOWN_DATE_004).
Clean baseline: 24/30 (80%), zero false negatives, 6 false positives.
Failure mode identified: overreliance on board header without attendance
block co-signal. Round 2 prompt changes specified for next session.
```

---

## Session End Checklist

- [ ] Confirm `llm_validate_run1.R` saved to `roles/minutes/scripts/` with round 1 revised prompt
- [ ] Confirm `llm_validation_run1.xlsx` saved with two label corrections
- [ ] Confirm `llm_run1_validation_results.csv` written to `roles/minutes/outputs/`
- [ ] Upload `SessionSummaryJune252026.md` to knowledge repository
- [ ] Commit to `docs/session_summaries/` on GitHub
