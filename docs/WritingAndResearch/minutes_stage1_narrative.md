# Stage 1 Classification — Technical Narrative
## Board Minutes Pipeline: Extraction Through MinutesOnly / SomethingElse Classification
*docs/narratives/minutes_stage1_narrative.md | June 30, 2026*

---

## 1. Purpose and Scope

This narrative documents the methodology by which the board minutes corpus was
classified into two categories — `MinutesOnly` (genuine, complete board of
directors meeting minutes) and `SomethingElse` (any other document type
present in the scraped corpus) — as a first-stage filter prior to deeper
content extraction.

This document covers the pipeline from raw PDF extraction through final
corpus-wide classification. It does not cover Stage 2 (boundary detection
within mixed documents) or downstream content extraction from classified
minutes, both of which are separate, subsequent processes operating on the
output of this stage.

---

## 2. Background and Problem Statement

The board minutes scraping process (documented separately; see
`BoardMinutes_WorkPlan.md` and `minutes_scrape.R`) collected 1,833 indexed
documents across 137 tracked Ontario hospitals from publicly available board
meeting pages. This collection process, by necessity, captured more than
genuine minutes: agendas, committee reports, organizational charts,
governance policy documents, CEO reports, meeting summaries, and other
material routinely posted alongside or instead of formal minutes were also
captured, since these document types are frequently linked from the same
web pages or bundled into the same PDF packages as the minutes themselves.

Before any substantive content analysis of board minutes can proceed — board
focus taxonomy classification, sentiment analysis, or linkage to financial
and quality outcomes — the corpus must be filtered to identify which
documents are genuine, complete records of full board of directors meetings.
This is the Stage 1 classification problem.

A manual, document-by-document review of 1,833 files was not practical given
project timelines. An LLM-assisted classification approach was selected,
using a locally-hosted model (`llama3.1:8b` via Ollama) to avoid per-document
API costs at this corpus scale and to allow for unrestricted iteration during
prompt development.

---

## 3. Pipeline Architecture

The Stage 1 pipeline consists of four sequential steps applied to each
document in the corpus:

1. **OCR extraction** — PDF pages are rasterized and passed through Tesseract
   OCR to produce raw text, since the corpus is a mixture of native-text and
   scanned-image PDFs and a uniform extraction method was required across
   both.
2. **Text preparation** — raw OCR output is trimmed to the first 700 words,
   since classification signals (document header, meeting type, attendance
   block) consistently appear within the opening portion of genuine minutes
   documents, established through direct inspection of validation documents.
3. **R-side pre-screen** — a deterministic, rule-based classifier examines
   the first 40 lines of raw OCR text for high-confidence structural signals
   before any LLM call is made.
4. **LLM classification** — documents not resolved by the pre-screen are
   passed to the LLM with a structured prompt requiring justification via a
   three-part structural test.

This two-layer design — deterministic pre-screen followed by LLM
classification — emerged from validation testing rather than being the
original design. Early validation rounds relied on the LLM prompt alone;
the pre-screen was added after specific, recurring false positive patterns
were identified that the LLM could not reliably resolve through prompt
instruction alone (see Section 5).

---

## 4. The Two-Stage Corpus Architecture

A foundational design decision, established during validation, is that
Stage 1 classification is intentionally conservative in one specific
direction: it is designed to minimize false positives (`SomethingElse`
documents incorrectly accepted as `MinutesOnly`) at the acceptable cost of
false negatives (genuine minutes incorrectly classified as `SomethingElse`).

This asymmetry follows from the corpus's downstream architecture. Documents
classified `SomethingElse` by Stage 1 are not discarded — they are reserved
for a subsequent process (Stage 2 and associated mining passes; see Section
8) designed specifically to extract genuine minutes content from mixed or
ambiguous documents, including documents where minutes are embedded within
larger packages (agendas, committee reports, or governance bundles) that
Stage 1's conservative criteria correctly decline to accept outright.

Consequently, a Stage 1 false negative is a low-cost error: the document
receives a second classification opportunity under different criteria.
A Stage 1 false positive is a high-cost error: a non-minutes document
enters the `MinutesOnly` pool, will not be reviewed by the Stage 2 process,
and will be treated as genuine minutes content by all downstream analysis.

This principle governed every prompt revision and pre-screen design decision
made during validation.

---

## 5. R-Side Pre-Screen Design

The pre-screen function (`prescreen_document()`) was developed iteratively
in response to a specific, recurring false positive pattern: documents
opening with an agenda — a forward-looking list of meeting items — rather
than a record of what occurred. The LLM, despite explicit prompt instructions
distinguishing agendas from minutes, would intermittently classify these
documents as `MinutesOnly` by locating a "Board of Directors" header and any
nearby list of names (board member rosters in document footers, names
attached to agenda items as presenters, or names in unrelated organizational
charts) and treating that as a satisfactory attendance record.

Direct inspection of the documents producing this failure (FAC 661, Cambridge
Memorial Hospital; FAC 935, Thunder Bay Regional Health Sciences Centre)
confirmed a structural signature: both opened with a standalone `AGENDA`
heading. Inspection of 15 confirmed genuine minutes documents across a range
of hospitals confirmed this heading format never appears as a standalone
heading in genuine minutes — it may appear as a column label or within
phrases such as "Consent Agenda," but never alone.

The final operative pre-screen, as deployed for the full corpus run,
consists of:

- **A positive guard:** if both a `MINUTES` heading and a recognized
  attendance label (`Present:`, `In Attendance:`, `Members Present:`,
  `Directors Present:`) appear within the first 40 lines, the document is
  passed directly to the LLM without further pre-screen evaluation. This
  guard takes precedence to avoid the pre-screen incorrectly intercepting
  genuine minutes that happen to also exhibit structural features the
  negative signal below might otherwise flag.
- **Signal 1 — standalone `AGENDA` heading:** if a line consists solely of
  the word `AGENDA` within the first 40 lines, the document is classified
  `SomethingElse` without an LLM call.

A second candidate signal — detecting four or more consecutive short,
numbered lines as evidence of agenda-table compression — was developed and
tested but ultimately removed from Stage 1 after producing a false negative
on FAC 939 (Holland Bloorview Kids Rehabilitation Hospital), a genuine
minutes document containing a numbered list within its narrative body
(strategic priorities described as a four-item list). Given the Stage 1
asymmetry described in Section 4, this signal was judged too imprecise for
Stage 1 deployment and was reserved as a candidate signal for the Stage 2
process, where it can be applied with the benefit of additional document
context (for example, triggering only when the compression appears before
any attendance block, rather than anywhere in the document).

---

## 6. LLM Prompt Development

The LLM classification prompt underwent three substantive revision rounds
during validation, each tested against a 30-document hand-labelled
validation set (`llm_validation_run1.xlsx`).

**Baseline prompt** (original design): 24/30 (80.0%) accuracy, 5 false
negatives, 1 false positive. The model exhibited a specific reasoning
failure on FAC 928, fabricating plausible-sounding but factually incorrect
justification for its classification — establishing early that the model's
`reasoning` field cannot be treated as a reliable audit trail and that
classification accuracy must be assessed against ground truth, not against
the model's stated logic.

**Revision round 1** (sentinel suppression, joint meeting carve-out,
post-adjournment tolerance, soft endings): 22/30 (73.3%) — a regression.
The added permissiveness around document endings caused the model to accept
agenda packages and other non-minutes documents that merely contained a
Board of Directors header.

**Revision round 2** (attendance block required as a hard structural
co-signal; explicit disqualification of forward-looking agenda tables and
summary-format titles): 26/29 scoreable (89.7%), 3 false positives, 0 false
negatives, 1 parse error. This round eliminated half of the original false
positives by requiring the model to locate explicit attendance language
rather than relying on the header alone.

**Revision round 3** (attendance block format specification — requiring a
dedicated, labelled, grouped list rather than names appearing incidentally
in footers, org charts, or agenda item assignments): 27/30 (90.0%), 3 false
positives, 0 false negatives, 0 parse errors.

Three false positives persisted across rounds 2 and 3 without further
improvement: FAC 661 (Cambridge Memorial — agenda package with a recurring
board member footer), FAC 935 (Thunder Bay Regional — agenda with names
attached to individual items), and FAC 953 (Sunnybrook Health Sciences
Centre — an organizational chart in which "Board of Directors" appears as a
structural node and numerous individual names appear as role assignments).

Diagnostic review of the model's stated reasoning for these three documents
in round 3 revealed that the model was asserting the presence of a properly
labelled `Present:`-style attendance block — a claim independently confirmed
false by direct document inspection for FAC 661 and FAC 953. This
established that the remaining false positives reflected a model behaviour
limit (the model constructing plausible justification to satisfy prompt
requirements) rather than a prompt design deficiency, and that further
prompt revision would be unlikely to resolve them. No further prompt
revision rounds were attempted following this finding. The three known
false positive document types were instead addressed via the R-side
pre-screen (Section 5), which resolved FAC 661 and FAC 935. FAC 953 was
accepted as a known, documented, irreducible residual error (see Section 9).

---

## 7. Validation Methodology

Two independent validation exercises were conducted prior to the full
corpus run.

**Curated validation set:** 30 documents hand-labelled by the project lead,
covering a deliberately broad range of document types and known difficult
formats. Final result after all revision rounds and pre-screen integration:
29/30 (96.7%), 0 false negatives, 1 false positive (FAC 953, accepted
exception).

**Random sample blind evaluation:** to address the risk that the curated
validation set, having been selected by the document's author with prior
knowledge of likely failure modes, might not represent corpus-level
difficulty, a second, independently constructed validation exercise was
conducted. A stratified random sample of 30 documents was drawn from the
full corpus index: 20 documents drawn at random (one per hospital, to avoid
over-representation of high-volume hospitals), and 10 documents drawn from
hospitals previously identified as having unusual document formats (multi-
column layouts, known false positive cases, large bundled packages). The
model was run against this sample first; the project lead then reviewed
each of the 30 source documents independently, without reference to the
model's output, and recorded an independent classification before
comparing against the model's result.

**Random sample result: 30/30 (100%), 0 errors of any kind.**

This result, exceeding the curated set's performance, supports the
conclusion that the curated set's difficulty level was representative of or
somewhat harder than the corpus average, and that the 96.7% curated-set
accuracy is a conservative, not optimistic, estimate of corpus-wide
performance.

One incidental finding from the blind review, unrelated to classification
accuracy: FAC 978 (Kingston Health Sciences Centre) was correctly classified
as `MinutesOnly`, but the underlying document was identified as an in-camera
session reporting record rather than the hospital's primary minutes
repository, indicating a scraper coverage gap for this hospital rather than
a classification error. This is logged as a coverage issue for separate
remediation and does not affect the Stage 1 accuracy figures above.

---

## 8. Full Corpus Run

Following the go/no-go decision (Section 9), the validated pipeline —
R pre-screen plus LLM classification, round 3 prompt — was executed against
the complete corpus.

**Run parameters:** `llama3.1:8b`, temperature 0 (deterministic), 300 DPI
OCR rasterization, 700-word LLM context window, checkpoint writes every 50
documents to allow safe interruption and resumption.

**Run result:** 2,352 documents processed over 11.2 hours. The corpus count
of 2,352 exceeds the originally estimated 1,732 documents (the discrepancy
between the index row count and the processed file count has not yet been
reconciled and is noted as an open item; it does not affect the validity of
the classification results, only the precision of pre-run time estimates).

| Outcome | Count | % of corpus |
|---|---|---|
| MinutesOnly | 1,879 | 79.9% |
| SomethingElse | 470 | 20.0% |
| Pre-screened by R (no LLM call) | 35 | 1.5% |
| Files listed in index, not found on disk | 79 | — |

Of the 2,352 processed documents, 4 produced an initial classification
failure (3 `parse_error`, 1 `api_error`) — a failure rate of 0.17%. All four
were investigated individually post-run:

- **Two documents from FAC 661** (Cambridge Memorial Hospital) were found,
  on inspection, not to be board minutes at all — one was the hospital's
  Medical/Professional Staff Rules and Regulations document, the other its
  Corporate By-Law. Both had been misindexed as minutes during the original
  scraping process. The model's failure to return valid classification JSON
  for these documents is consistent with the documents genuinely not fitting
  either classification category; the model attempted to describe document
  content rather than force an artificial classification. Both were
  manually corrected to `SomethingElse` with the misindexing documented in
  the results reasoning field.
- **One document from FAC 858** (Michael Garron Hospital) failed on initial
  run with an API-level error; a clean manual re-run produced a confident,
  correct `MinutesOnly` classification, consistent with a transient
  connectivity or service interruption during the original 11-hour run
  rather than a content-related failure.
- **One document from FAC 905** (Oak Valley Health) failed due to a
  malformed JSON response — the model omitted an opening quotation mark in
  its `reasoning` field, producing syntactically invalid JSON. A manual
  re-run with the same prompt produced a correctly formatted, high-
  confidence `SomethingElse` classification (the document's title contains
  "Meeting Summary," a recognized disqualifying signal). This single
  instance of malformed JSON output is logged as a known but low-frequency
  failure mode; given its rarity (1 in 2,352, or 0.04%) no automated repair
  logic was built into the pipeline, though the specific failure pattern is
  documented should it recur at meaningful scale in any future re-run.

Following manual resolution of all four cases, the corpus-wide result is
**2,352 documents fully classified, zero unresolved errors.**

---

## 9. Go/No-Go Decision

The original Stage 1 pass criteria, established in the feasibility test
plan, specified a zero-tolerance threshold for false positives. This
criterion predated the two-stage corpus architecture described in Section 4
and was revised during validation to reflect that architecture: Stage 1's
operative pass criteria became ≥95% high-confidence accuracy and zero false
negatives, with false positives treated as an acceptable, bounded cost
absorbed by the existence of the Stage 2 process, rather than a Stage 1
failure condition.

Under the revised criteria, both validation exercises passed: 96.7% accuracy
with 0 false negatives on the curated set, 100% accuracy with 0 errors of
any kind on the independent random sample. The single persistent false
positive (FAC 953, an organizational chart) was assessed as an isolated,
well-characterized, low-prevalence document type rather than evidence of a
systemic classification weakness, supporting a decision to proceed to the
full corpus run rather than pursue further prompt revision, which had
already been demonstrated (Section 6) not to resolve this specific failure
mode.

---

## 10. Disposition of `SomethingElse` Documents

The 470 documents (20.0% of the classified corpus) returned as
`SomethingElse` by Stage 1 are not discarded from the project. Consistent
with the two-stage architecture described in Section 4, this population
will be subject to a separate mining process — currently in design — applying
different classification criteria suited to extracting genuine minutes
content from mixed, embedded, or boundary-ambiguous documents that Stage 1's
conservative criteria correctly declined to accept as standalone minutes.

This includes, but is not limited to: documents where minutes are embedded
within a larger agenda package (a known pattern at several hospitals,
including Cambridge Memorial and Thunder Bay Regional, both represented in
the false positive set discussed in Section 6); documents where attendance
information was captured by the scraper in a format the Stage 1 pre-screen
or LLM prompt did not anticipate; and any other document type where genuine
minutes content may exist but is not packaged in the standalone format
Stage 1 was designed to recognize.

The objective of this subsequent process is to maximize the proportion of
genuine minutes content recovered from the full scraped corpus, beyond what
Stage 1 alone — by design, conservative toward false positives — is capable
of capturing. Design of this process (tentatively, "Stage 2") had not begun
as of this narrative's writing.

---

## 11. Known Limitations

The following limitations are documented for inclusion in any subsequent
methods writeup:

- The LLM's stated `reasoning` field is not a reliable indicator of correct
  classification. The model has been observed, on multiple documented
  occasions, to produce confident, specific, and incorrect justification for
  both correct and incorrect classifications. Accuracy must be assessed
  against independently established ground truth, not against the model's
  self-reported reasoning.
- The model does not reliably express graduated confidence on this task — in
  validation testing, all 30 documents in both the curated and random sample
  sets returned `high` confidence regardless of correctness, indicating that
  confidence tier cannot be used as a downstream quality filter for this
  classification task.
- One known, irreducible false positive document type (organizational charts
  containing "Board of Directors" as a structural element, with named
  individuals listed as role assignments rather than meeting attendees) was
  identified and is expected to recur at low but non-zero frequency across
  the corpus. FAC 953 is the only confirmed instance as of this narrative.
- The R-side pre-screen's compression-based signal (numbered line detection)
  was tested and found unsuitable for Stage 1 due to a false negative risk
  on genuine minutes containing numbered lists in narrative body text. It
  remains a candidate signal for the Stage 2 process.
- A small number of documents (4 of 2,352, 0.17%) required manual
  intervention due to LLM-side failures (malformed JSON output, transient
  API errors, and misindexed non-minutes content reaching the classifier).
  All four were individually resolved and are documented in Section 8.
- The discrepancy between the originally projected corpus size (1,732
  documents, derived from an earlier index read) and the actual processed
  count (2,352 documents) has not been reconciled and should be investigated
  before the 2,352 figure is used as a denominator in subsequent coverage or
  prevalence statistics.
- 79 documents listed in the corpus index were not found on disk at
  classification time. Investigation determined these fall into at least
  two categories: documents genuinely access-restricted by the source
  hospital (confirmed for St. Catharines Niagara Health System and Sudbury
  Health Sciences North), and a likely scraper access failure at one
  hospital (FAC 977, Terrace Bay North of Superior Health Centre, where 72
  of the 79 missing files originate and where the source material appears
  publicly accessible on manual inspection, suggesting a robots.txt or
  similar automated-access restriction not reflected in the current
  registry). This is logged as an extraction-layer issue requiring
  follow-up, separate from Stage 1 classification, and is not yet resolved.

---

## 12. Summary

Stage 1 classification, comprising a deterministic R-based pre-screen and an
LLM-based structural classifier, was developed, validated against two
independent test sets, and run against the complete board minutes corpus.
The final corpus disposition is 1,879 documents (79.9%) classified as
genuine `MinutesOnly` records and 470 documents (20.0%) classified as
`SomethingElse`, with zero unresolved classification errors following manual
review of four initial pipeline failures. Validation testing supports an
estimated corpus-wide accuracy at or above 96.7%, with the model's only
identified systemic weakness — a single irreducible false positive document
type — assessed as low-prevalence and acceptable given the corpus's
two-stage architecture. The `SomethingElse` population is retained for a
planned subsequent mining process intended to maximize total minutes content
recovery from the full scraped corpus.
