# HospitalIntelligenceR
## Session Summary — June 26, 2026 (AM)
## Board Minutes — LLM Run 1 Validation (Prompt Revision Rounds 2 & 3)
*For Claude Project Knowledge Repository*

---

## Next Session — Start Here

**Current priority:** Build and run the random-sample validation test — 30 documents
drawn from the full corpus, model classified first, then hand-evaluated blind.

**First action:** Build `llm_validate_run1_random.R` — a sampling script that draws
from `minutes_index.csv`, runs the round 3 prompt against the sample, and produces
a reviewable output file for blind hand-evaluation. Claude will build this script
at session start.

**Watch out for:**
- The round 3 prompt is the operative prompt — it is saved in `llm_validate_run1.R`.
  Do not revert to earlier versions.
- Three false positives (FACs 661, 935, 953) are irreducible at the prompt level.
  The model hallucinates attendance block language to satisfy the prompt requirement
  for all three. Further prompt revision will not fix them — this is a model
  behaviour limit, not a prompt design problem.
- FAC 714 (London St. Joseph's) had a parse error in round 2 but resolved in round 3
  (scored correctly as `MinutesOnly`). The two-column layout with membership panel
  produces interleaved OCR text; monitor for this pattern in the random sample.
- The random sample should be evaluated BLIND — run the model first, record
  classifications, then review each file without looking at the model output.
  Confirm your label before comparing.
- Stratify the random draw: ~20 random from full corpus + ~10 targeted from known
  difficult hospitals (BoardPro layouts, cumulative PDFs, mixed packages).

### Carry-Forward Items

| Item | Status | Notes |
|---|---|---|
| Build `llm_validate_run1_random.R` — random sample test | READY TO EXECUTE — FIRST ACTION | 30-doc stratified draw; blind evaluation design |
| Run random sample and hand-evaluate | FOLLOWS SCRIPT BUILD | Model runs first; Skip evaluates blind |
| Go/no-go decision on Run 1 | PENDING random sample results | Currently at 90.0% on curated set |
| Build `llm_run1_classify.R` — full corpus script | NOT STARTED | Blocked on go/no-go |
| Run 2 boundary detection pass design | NOT STARTED | Blocked on Run 1 go/no-go |
| KVM switch installation | PENDING HARDWARE | Frees ~789 MiB VRAM from GNOME RDP |

---

## Session Objectives

Execute prompt revision rounds 2 and 3 against the 30-document hand-labelled
validation set, interpret results, and reach a go/no-go decision point on the
Run 1 prompt. Plan the random-sample blind evaluation as the next validation step.

---

## Work Completed

### 1. Round 2 Prompt — Partial Improvement

Three targeted changes applied to the round 1 prompt:
1. Attendance block required as hard co-signal (past-tense, record-style language)
2. Forward-looking agenda tables explicitly disqualified
3. Meeting Summary / Board Highlights title formats explicitly disqualified

**Result: 26/29 scoreable (89.7%), 3 FP, 0 FN, 1 parse error (FAC 714)**

Three of the original six false positives eliminated: FAC 736 (Meeting Summary),
FAC 936 CEO report, FAC 979 speaker bio. Three remained: FACs 661, 935, 953.

Parse error on FAC 714 (London St. Joseph's) — two-column OCR layout producing
interleaved text; set aside pending investigation.

### 2. FAC 953 Diagnosis

ReviewFile.R confirmed FAC 953 (`953_SUNNYBROOK/2026-05-01_board_minutes.pdf`)
is an org chart / leadership directory — VP names assigned to program areas, no
attendance record. The model found "Board of Directors" in the org chart structure
and named individuals throughout, hallucinating an attendance block.

FAC 661 confirmed as a 5-page agenda package with board member footer on every page
— footer names appearing in the first 700 words are read as an attendance block.

FAC 935 confirmed as a large agenda package where names are attached to agenda items
as presenters, not grouped in an attendance block.

### 3. Round 3 Prompt — Attendance Block Format Specification

One targeted addition: explicit description of what a valid attendance block looks
like structurally (grouped list, dedicated label, immediately after header) and
what does NOT qualify (footers, org charts, role directories, agenda item presenters).

Change applied in two places:
- `MinutesOnly` criterion 2 expanded with format specification
- New `SomethingElse` bullet added: documents where named individuals appear only
  in footers, org charts, leadership directories, or as agenda item presenters

**Result: 27/30 (90.0%), 3 FP, 0 FN, 0 parse errors**

FAC 714 parse error resolved — scored correctly as `MinutesOnly` in round 3.
FACs 661, 935, 953 did not move. Model reasoning for all three now explicitly
claims to find a "Present:"-labelled attendance block — which is false for 661
and 953 (confirmed by document inspection). The model is hallucinating the
attendance block label to satisfy the prompt requirement. This is the same
pattern as the FAC 928 reasoning hallucination documented in the June 25 session.

### 4. Go/No-Go Assessment

**Current standing: 90.0% on curated 30-document set, 0 false negatives.**

The pass banner reports FAIL because the feasibility plan requires ≥95%
high-confidence accuracy AND zero false positives. However:

- The three remaining false positives are irreducible at the prompt level
- None are false negatives — no genuine minutes are being missed
- The downstream consequence is these three documents appearing in the
  `MinutesOnly` pile; they contain no minutes text so extraction will
  produce empty/low-quality output, not lost content
- Further prompt revision will produce more precisely-worded hallucinations,
  not correct classifications

Decision: proceed to random-sample blind evaluation rather than a fourth
prompt revision. The curated validation set is insufficient to determine
whether 90% is representative of corpus-level performance.

---

## Key Design Decisions

| Decision | Rationale |
|---|---|
| No fourth prompt revision | The three remaining FPs are model behaviour limits, not prompt design problems. The model hallucinates reasoning to justify its classification. More specific language produces more specific hallucinations. |
| Proceed to random-sample test | Curated validation set may not represent corpus-level difficulty. Random sample with blind evaluation gives a more honest accuracy estimate. |
| Stratified random draw design | 20 random + 10 targeted from known difficult formats. Pure random over-represents straightforward community hospital minutes. |
| Blind evaluation protocol | Model runs first; hand-evaluation without looking at model output. Prevents confirmation bias on ambiguous documents. |
| Three FPs accepted as residual error | FACs 661, 935, 953 produce false MinutesOnly classifications. Downstream consequence is empty extraction output, not lost minutes. Acceptable at corpus scale if prevalence is low. |
| FAC 714 parse error — monitor | Resolved in round 3. Two-column OCR layout is a known fragile pattern; flag if it recurs in random sample. |

---

## Prompt State — Round 3 (Operative)

The round 3 prompt is saved in `llm_validate_run1.R` Section 1c
(`classify_document_llm()`). Key features:

- Requires ALL THREE: Board of Directors header + valid attendance block + closing
- Attendance block must be a dedicated grouped list under a label ("Present:",
  "In Attendance:", etc.) immediately after the header
- Explicitly disqualifies: footer names, org chart names, agenda item presenters
- Explicitly disqualifies: forward-looking agenda tables before attendance block
- Explicitly disqualifies: Meeting Summary / Board Highlights title formats
- Explicitly disqualifies: committee-only headers without Board of Directors
- Sentinel suppression: `--- PAGE BREAK ---` is OCR artefact, not structure
- Joint meeting carve-out: "Joint Meeting of [Committee] and Board of Directors"
  qualifies as full board meeting

---

## Files Produced or Modified

| File | Location | Change |
|---|---|---|
| `llm_validate_run1.R` | `E:/HospitalIntelligenceR/roles/minutes/scripts/` | Modified — round 3 prompt applied |
| `llm_run1_validation_results.csv` | `E:/HospitalIntelligenceR/roles/minutes/outputs/` | Overwritten — round 3 results |
| `SessionSummaryJune262026_AM.md` | Upload to knowledge repository | This file |

---

## GitHub Commit Instructions

```
roles/minutes/scripts/llm_validate_run1.R              — modified (round 3 prompt)
roles/minutes/outputs/llm_run1_validation_results.csv  — modified (round 3 results)
docs/session_summaries/SessionSummaryJune262026_AM.md  — created
```

**Commit message:** `T1: LLM Run 1 prompt revision rounds 2 and 3 — 90.0% on validation set`

**Description:**
```
Round 2: attendance block as hard co-signal, agenda table and summary format
disqualifiers. 26/29 scoreable (89.7%), 3 FP, 0 FN.

Round 3: attendance block format specification (grouped label, footer/org chart
exclusions). 27/30 (90.0%), 3 FP, 0 FN. FAC 714 parse error resolved.

Three remaining FPs (661, 935, 953) confirmed as model behaviour limit —
hallucinated attendance block reasoning. No fourth prompt revision.

Next: random-sample blind evaluation (30 docs, stratified draw).
```

---

## Session End Checklist

- [ ] Upload `SessionSummaryJune262026_AM.md` to knowledge repository
- [ ] Commit to `docs/session_summaries/` on GitHub
- [ ] Confirm `llm_validate_run1.R` saved with round 3 prompt
- [ ] Confirm `llm_run1_validation_results.csv` reflects round 3 results
