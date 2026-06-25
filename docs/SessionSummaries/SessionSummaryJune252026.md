# HospitalIntelligenceR
## Session Summary — June 25, 2026
## Board Minutes — LLM Run 1 Validation (Prompt Revision Round 1)
*For Claude Project Knowledge Repository*

---

## Next Session — Start Here

**Current priority:** Score the revised prompt results and determine whether the
prompt overcorrected. The comparison run at session end showed 10 classification
changes between the original and revised prompt — 4 expected flips plus 6
unexpected flips on previously-correct `SomethingElse` documents (FACs 661, 935,
936 ×2, 953, 979). The revised prompt results are in memory but were not fully
scored before the session ended. Start by scoring them.

**First action:** With the revised prompt results (`results` object) in memory,
run the Section 5 scoring block and paste the false positives and false negatives
output here. That is the only thing needed to determine next steps — do not
proceed to a second prompt revision until this scoring is in hand.

**Watch out for:**
- The run2/run1 comparison at session end was misleading. `run2` loaded the
  original CSV from disk while `run1` held the revised prompt results in memory.
  The 10 "mismatches" are prompt differences, not drift. Repeatability was
  confirmed separately at 30/30 identical classifications on the original prompt.
- The revised prompt results CSV may not have been written to disk before the
  session ended. If `results` is not in memory, the revised prompt run will need
  to be re-executed. The revised prompt is in `llm_validate_run1.R` as saved
  at session end.
- Six documents flipped from `SomethingElse` to `MinutesOnly` unexpectedly.
  Before concluding the prompt overcorrected, check whether any of these are
  genuine reclassifications (i.e. documents you would accept as `MinutesOnly`
  on review). FAC 661 in particular — review the hand-label notes.

### Carry-Forward Items

| Item | Status | Notes |
|---|---|---|
| Score revised prompt results (Section 5 on current `results`) | READY TO EXECUTE — FIRST ACTION | Paste false positives and false negatives |
| Determine whether prompt overcorrected on FACs 661, 935, 936, 953, 979 | READY TO EXECUTE | Follows scoring above |
| Second prompt revision if needed | PENDING SCORING | Only if overcorrection confirmed |
| Run 1 go/no-go decision | BLOCKED on scoring | Target: ≥90% high+medium, zero committee FP |
| `llm_run1_classify.R` — full corpus script | NOT STARTED | Blocked on go/no-go |
| Run 2 boundary detection pass | NOT STARTED | Blocked on Run 1 go/no-go |
| KVM switch installation | PENDING HARDWARE | Frees ~789 MiB VRAM from GNOME RDP |

---

## Session Objectives

Reconstruct the four core LLM pipeline functions from the June 22 sessions,
build the Run 1 validation harness (`llm_validate_run1.R`), run it against the
30-document hand-labelled set, interpret the results, and execute a first prompt
revision round targeting the identified failure modes.

---

## Work Completed

### 1. Core Functions Reconstructed

Four functions rebuilt and integrated into `llm_validate_run1.R`:

`extract_text_ocr()` — rasterises PDF pages via `pdf_convert()`, runs Tesseract
OCR, collapses pages with `--- PAGE BREAK ---` sentinel. Temp PNGs cleaned up
via `on.exit()`.

`prepare_for_llm()` — trims to `max_words = 700` using word count on squished
text but trimming on original to preserve structure for the model.

`classify_document_llm()` — sends prompt to Ollama with `temperature = 0`,
handles the Ollama JSON envelope, strips markdown fences, returns parsed
classification/confidence/reasoning. Sentinel values returned on API or parse
failure rather than crashing the loop.

`extract_and_classify()` — wrapper timing OCR and LLM stages separately to
feed the speed benchmark.

### 2. Path Bug Fixed

Section 4 of the validation harness constructed `pdf_path` as
`file.path(EXTRACT_DIR, row$local_path)`, prepending the extracted directory
prefix a second time. `local_path` already contains the full relative path from
the project root. Fix: use `row$local_path` directly as `pdf_path`.

### 3. Original Prompt — Run 1 Results

30 documents scored. All responses at high confidence (no medium or low).

| Metric | Result | Target |
|---|---|---|
| Overall accuracy | 24/30 (80.0%) | — |
| High-confidence accuracy | 80.0% | ≥95% |
| High + medium combined | 80.0% | ≥90% |
| False positives (SE→MO) | 1 | 0 |
| False negatives (MO→SE) | 5 | — |

Error analysis:

| FAC | Expected | Got | Failure Mode |
|---|---|---|---|
| 736 | SomethingElse | MinutesOnly | Correct classification — summary format should be SE |
| 905 | SomethingElse | MinutesOnly | Correct classification — summary format should be SE |
| 596 | MinutesOnly | SomethingElse | Joint meeting header ("Finance Committee and Board of Directors") triggered committee exclusion rule |
| 663 | MinutesOnly | SomethingElse | `--- PAGE BREAK ---` sentinel interpreted as evidence of mixed document |
| 790 | MinutesOnly | SomethingElse | Soft ending (no explicit adjournment) combined with page markers |
| 928 | MinutesOnly | SomethingElse | Hallucination — model fabricated that Chief of Staff and Medical Staff Reports appeared after adjournment; they were within the minutes body at item 7 |

### 4. Repeatability Confirmed

Re-ran the same 30 documents without changes: 30/30 identical classifications.
Practical determinism confirmed on GTX 1060 with `temperature = 0`.

### 5. FAC 928 Hallucination Investigation

`ReviewFile.R` output for FAC 928 confirmed clean, readable OCR. The model
received "Chief of Staff Report was included in the package" at agenda item 7
(before closed session at item 8) and fabricated the reasoning that these
reports appeared after adjournment. This is a reasoning error, not an OCR
problem. Implication: the `reasoning` field is not a reliable audit trail —
it is plausible-sounding text, not a verified description.

### 6. Prompt Revision Round 1

Four targeted changes made to the prompt in `classify_document_llm()`:

1. **Sentinel suppression** — explicit instruction that `--- PAGE BREAK ---` is
   an OCR artefact carrying no structural meaning.
2. **Joint meeting carve-out** — "Joint Meeting of [Committee] and Board of
   Directors" is a full board meeting; committee exclusion applies only when the
   header names a committee without Board of Directors.
3. **Reports within vs. attached** — reports referenced or tabled within the
   minutes body are part of the record; only physically separate documents
   outside the opening/closing boundaries disqualify.
4. **Soft endings** — the opening header and attendance block are the primary
   structural test; absence of an explicit adjournment line does not disqualify.

Revised prompt run completed. Comparison against original results showed 10
classification changes (expected: 4). Six unexpected flips on `SomethingElse`
documents require scoring to determine whether overcorrection occurred. Session
ended before full scoring was complete.

---

## Key Design Decisions

| Decision | Rationale |
|---|---|
| Soft endings → `MinutesOnly` | Opening header and attendance block are the primary structural test; a missing adjournment line does not override a clear opening. Documents ending on business items without explicit adjournment are genuine minutes. |
| Summary format minutes → `SomethingElse` | Board Highlights, Meeting Summary formats belong in the Run 2 population. They lack the full formal record structure regardless of whether structural signals are partially present. |
| `reasoning` field not used for audit | FAC 928 confirmed the model can produce confident, specific, and incorrect reasoning. The classification label is the operative output; reasoning is indicative only. |
| Repeatability gate passed before prompt revision | 30/30 identical on re-run confirms noise floor is zero on this hardware; prompt revision results can be interpreted without confounding from model drift. |

---

## Files Produced or Modified

| File | Location | Change |
|---|---|---|
| `llm_validate_run1.R` | `E:/HospitalIntelligenceR/roles/minutes/scripts/` | Created — four core functions + Run 1 validation harness; revised prompt applied at session end |
| `llm_run1_validation_results.csv` | `E:/HospitalIntelligenceR/roles/minutes/outputs/` | Created — original prompt scored results (30 documents) |
| `SessionSummaryJune252026.md` | Upload to knowledge repository | This file |

---

## GitHub Commit Instructions

```
roles/minutes/scripts/llm_validate_run1.R    — created
roles/minutes/outputs/llm_run1_validation_results.csv    — created
docs/session_summaries/SessionSummaryJune252026.md    — created
```

**Commit message:** `T1: LLM Run 1 validation harness and prompt revision round 1`

**Description:**
```
Reconstructed four core LLM pipeline functions (extract_text_ocr,
prepare_for_llm, classify_document_llm, extract_and_classify).
Built llm_validate_run1.R and ran against 30-document hand-labelled set.
Original prompt: 80% accuracy (24/30). Repeatability confirmed 30/30.
FAC 928 hallucination investigated via ReviewFile.R — reasoning field
flagged as unreliable audit trail.
Prompt revision round 1 applied targeting four failure modes.
Revised prompt results require scoring at next session start.
```

---

## Session End Checklist

- [x] Confirm `llm_validate_run1.R` saved to `roles/minutes/scripts/` with revised prompt
- [x] Confirm `llm_run1_validation_results.csv` written to `roles/minutes/outputs/`
- [x] Save revised prompt results to `llm_run1_validation_results_rev1.csv` if `results` still in memory
- [x] Upload `SessionSummaryJune252026.md` to knowledge repository
- [x] Commit to `docs/session_summaries/` on GitHub
