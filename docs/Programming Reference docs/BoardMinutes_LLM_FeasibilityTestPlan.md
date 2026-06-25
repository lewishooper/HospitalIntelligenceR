# Board Minutes — Local LLM Feasibility Test Plan
## HospitalIntelligenceR | Board Minutes Role

*Prepared June 23, 2026 | Revised June 23, 2026*
*Purpose: Evaluate whether a locally-hosted LLM (llama3.1:8b via Ollama) can reliably (1) classify board minutes documents as MinutesOnly vs. SomethingElse, and (2) locate the minutes boundary within mixed documents — in a form consumable by the existing R pipeline. A go/no-go decision concludes the evaluation.*

---

## 1. Context and Decision Being Evaluated

The current Phase 2 build plan calls for `extract_minutes.R`, a keyword-boundary
extractor that identifies minutes text within PDFs using structural signals
(begin/end keywords, page boundaries, date patterns). Design is complete and
a pilot set of 5 hospitals has been identified for validation.

Two sessions (June 21–22, 2026) evaluated an alternative: use a locally-hosted
LLM to classify documents and locate minutes boundaries, replacing the keyword
extractor. Infrastructure is in place: Ollama running llama3.1:8b on a GTX 1060
6 GB, called over the LAN from R on Windows. First smoke test produced one
correct and one incorrect classification from two documents.

This plan defines the structured evaluation required before a go/no-go decision.

---

## 2. Two-Pass Architecture

The evaluation is structured around two distinct LLM passes with different
prompts and different populations. This design respects VRAM constraints on the
GTX 1060 and keeps each LLM task narrow and testable.

**Run 1 — Universal classification pass:** Every document in the corpus
(1,732 documents) is sent to the LLM with a single question: is this document
purely board meeting minutes (`MinutesOnly`), or does it contain other content
(`SomethingElse`)? No extraction is attempted. If a document is `MinutesOnly`,
the LLM is done with it — R handles all downstream text processing using the
existing `pdftools::pdf_text()` pipeline.

**Run 2 — Boundary detection pass (SomethingElse documents only):** A second,
differently-prompted LLM pass runs only on documents classified as `SomethingElse`
in Run 1. The question shifts from "what is this document?" to "where do the board
meeting minutes begin and end within this document?" R then captures the identified
page range using `pdftools::pdf_text()` and writes it to the output schema.

Both passes use Tesseract OCR as the uniform text extraction method. This adds
latency but eliminates conditional branching based on whether a PDF has a text
layer. OCR quality is consistent and predictable; the alternative — detecting
text-layer vs. scanned PDFs mid-pipeline — adds complexity that is not worth
the speed gain.

Both passes must also distinguish a full board meeting from a committee meeting.
Committee minutes are a common corpus contaminant and must not be classified as
board minutes. This distinction is explicit in both prompts.

---

## 3. Benefits and Risks

### Benefits

**Handles format diversity naturally.** The corpus spans at least 8 distinct
attendance block formats, BoardPro tabular motion layouts, summary-style minutes,
Board Highlights formats, and bundled multi-document PDFs. The keyword extractor
requires per-hospital tuning for these cases. The LLM reads the document
semantically and is less sensitive to surface format variation.

**Reduces keyword maintenance burden.** The extraction design file currently
tracks 19 FAC-specific rows with 23 begin keywords and 30 end keywords, and will
grow as more hospitals are added. The LLM approach eliminates most of this
hospital-by-hospital vocabulary management.

**Run 2 replaces `minutes_extract_mixed.R` naturally.** The planned secondary
extraction pass for mixed documents is an exact match for Run 2 — rather than
building a second keyword extractor, the LLM handles boundary detection
semantically.

**VRAM usage is bounded.** Because Run 1 does classification only (no extraction),
inference per document is fast and the context sent to the model is small (first
700 words). Run 2 sends more context but runs on a fraction of the corpus — only
the SomethingElse documents identified in Run 1.

### Risks and Issues

**Accuracy is unproven at scale.** The smoke test produced one error in two
documents. The failure mode was the model conflating "committee reports embedded
within minutes" with "a mixed package" — a prompt design problem, not a model
capability problem. But it illustrates that prompt wording requires careful
validation before running against 1,732 documents.

**Committee meeting contamination.** Hospital archives routinely contain minutes
from Finance Committee, Quality Committee, Joint Conference Committee, and other
standing committees. These look structurally similar to full board minutes —
they have headers, attendance blocks, and adjournment language. Both Run 1 and
Run 2 prompts must explicitly instruct the model to classify committee meetings
as SomethingElse / outside the minutes boundary, not as board minutes. This is
a known and manageable risk but requires deliberate prompt attention.

**OCR latency.** Using Tesseract for all documents is the right decision for
consistency, but it is slower than `pdftools::pdf_text()`. The speed benchmark
in Section 8 will quantify the total projected time for the full corpus and
confirm it is acceptable.

**Run 2 context window constraints.** For boundary detection in long documents,
the model needs enough context to find where minutes begin and end. The strategy
(send first N pages + last N pages with a note that the document is longer) is
sufficient for most cases but will not handle documents where minutes are
embedded in the middle of a long package. Those are flagged for manual review.

**Prompt sensitivity.** Small changes in prompt wording can have large effects
at corpus scale. Both prompts are validated against a hand-labelled set before
any batch run. The validation gate is mandatory — do not skip it.

**Reproducibility.** LLM outputs are non-deterministic by default. Setting
`temperature = 0` in the Ollama call body produces deterministic output. This
must be confirmed in testing — the same document should return the same result
on re-run.

---

## 4. Run 1 — Classification Pass

### 4.1 Task Definition

Every document is classified as one of two labels:

- `MinutesOnly` — the document is a record of a **full board meeting** and
  contains nothing else (or contains only embedded content that is part of the
  minutes record, such as committee reports presented to the board). R handles
  all downstream text processing; no further LLM involvement.
- `SomethingElse` — the document is an agenda, a mixed package, a committee
  meeting record, a CEO report, a presentation, or any other document type.
  Routes to Run 2.

### 4.2 Run 1 Prompt

```r
run1_prompt <- paste0(
  "You are classifying hospital governance documents.\n\n",
  "Classify the document below as one of two types:\n\n",
  "- MinutesOnly: The document is a record of a FULL BOARD OF DIRECTORS meeting ",
  "with a clear beginning and a clear end. The beginning is marked by a header ",
  "containing 'Board of Directors', a past meeting date, and an attendance or ",
  "present list. The end is marked by an adjournment statement or a signature ",
  "block (Chair, Secretary). Everything between the beginning and the end is ",
  "part of the minutes record — committee reports, CEO updates, delegations, ",
  "and presentations tabled at the meeting are all part of the record and do ",
  "not disqualify the document. The test is structural: does the document open ",
  "with the start of the minutes and close with the end of the minutes, with ",
  "nothing outside those boundaries?\n\n",
  "- SomethingElse: Any document that has content outside the minutes boundaries. ",
  "This includes: documents that begin with an agenda before the minutes start; ",
  "documents that have attached reports, appendices, or other material after the ",
  "adjournment; committee meeting minutes (Finance Committee, Quality Committee, ",
  "or any sub-committee — these are not full Board of Directors meetings); ",
  "standalone agendas; CEO or executive reports; or any document where the ",
  "minutes are only a section within a larger package.\n\n",
  "IMPORTANT: Committee meeting minutes are SomethingElse even if they look ",
  "structurally similar to board minutes. Confirm that the header says ",
  "'Board of Directors' — not a committee name.\n\n",
  "Respond ONLY with valid JSON — no other text, no markdown:\n",
  '{\"classification\": \"MinutesOnly or SomethingElse\", ',
  '\"confidence\": \"high or medium or low\", ',
  '\"reasoning\": \"one sentence\"}\n\n',
  "Document text:\n", text
)
```

### 4.3 Ollama Call Settings

```r
body <- list(
  model   = "llama3.1:8b",
  prompt  = run1_prompt,
  stream  = FALSE,
  options = list(temperature = 0)
)
```

`temperature = 0` is mandatory for reproducibility. Confirm in testing that
re-running the same document returns the same result.

### 4.4 Text Preparation for Run 1

Use the existing `prepare_for_llm()` function with `max_words = 700`. For
classification, the first 700 words are sufficient — the header, meeting type,
and attendance block (which distinguish full board from committee meetings and
from non-minutes documents) appear within the first page.

### 4.5 Validation Set

Build a hand-labelled set of 30 documents before running the model. Do not
label after seeing model output.

| Stratum | Count | Notes |
|---|---|---|
| MinutesOnly — clean, simple header | 6 | FAC 592 Napanee — straightforward format |
| MinutesOnly — embedded committee reports | 4 | Must not trigger SomethingElse |
| MinutesOnly — summary style (Board Highlights) | 4 | FAC 967 Cornwall |
| SomethingElse — agenda | 5 | Forward-looking documents |
| SomethingElse — mixed package | 5 | Agenda + attached reports |
| SomethingElse — committee minutes | 4 | Finance, Quality, or other committee |
| SomethingElse — CEO report or presentation | 2 | Non-minutes documents |

The committee minutes stratum (row 6) is deliberately included. This is the
highest-risk misclassification category given structural similarity to board
minutes, and it must be explicitly tested.

Draw from the 5 pilot hospitals: FACs 592, 888, 858, 967, 661. Use `ReviewFile.R`
to inspect and confirm labels before recording them.

```r
validation_set <- data.frame(
  fac              = character(),
  file             = character(),
  expected         = character(),   # "MinutesOnly" or "SomethingElse"
  stratum          = character(),   # from the table above
  hand_label_notes = character()
)
```

### 4.6 Scoring

```r
run1_results <- data.frame(
  fac        = character(),
  file       = character(),
  stratum    = character(),
  expected   = character(),
  got        = character(),
  confidence = character(),
  correct    = logical(),
  reasoning  = character()
)
```

Score by confidence stratum and by document stratum. A pass requires:

- ≥95% accuracy at high confidence
- ≥90% accuracy at high + medium confidence combined
- No systematic misclassification of committee minutes as MinutesOnly (zero
  tolerance — this is a known risk and the prompt was written to address it)

If Run 1 fails after two prompt revision rounds, revert to the keyword extractor.

---

## 5. Run 2 — Boundary Detection Pass

### 5.1 Task Definition

Run 2 applies only to documents classified as `SomethingElse` in Run 1. The
task shifts from classification to boundary detection: find the page range where
full board meeting minutes begin and end within the document. R then captures
that range using `pdftools::pdf_text()`.

Documents in the `SomethingElse` population that contain no board minutes at
all (pure agendas, CEO reports, presentations) should return `null` for both
boundary fields.

### 5.2 Run 2 Prompt

```r
run2_prompt <- paste0(
  "You are locating board meeting minutes within a hospital governance document.\n\n",
  "The document below may be a mixed package containing multiple sections: ",
  "an agenda, attached reports, committee minutes, and possibly the minutes ",
  "of a full Board of Directors meeting.\n\n",
  "Your task: identify the page numbers where the FULL BOARD OF DIRECTORS ",
  "meeting minutes BEGIN and END.\n\n",
  "The page text is divided by markers formatted as:\n",
  "--- PAGE N ---\n\n",
  "Board of Directors minutes begin with a header that includes 'Board of ",
  "Directors', a past meeting date, and an attendance or present list. They ",
  "end at an adjournment statement, a signature block (Chair, Secretary), or ",
  "the start of a distinctly different document section.\n\n",
  "IMPORTANT: Do NOT identify committee meeting minutes (Finance Committee, ",
  "Quality Committee, Joint Conference Committee, or any other sub-committee). ",
  "Only the full Board of Directors meeting qualifies.\n\n",
  "If no full Board of Directors minutes are present, return null for both ",
  "page fields.\n\n",
  "Respond ONLY with valid JSON — no other text, no markdown:\n",
  '{\"minutes_start_page\": integer or null, ',
  '\"minutes_end_page\": integer or null, ',
  '\"confidence\": \"high or medium or low\", ',
  '\"reasoning\": \"one sentence\"}\n\n',
  "Document:\n", paged_text
)
```

### 5.3 Text Preparation for Run 2

Run 2 requires more document context than Run 1. Format the text with explicit
page markers so the model can return page numbers:

```r
prepare_paged_text <- function(pages, max_pages_each_end = 4) {
  n <- length(pages)
  if (n <= max_pages_each_end * 2) {
    # Short document — send all pages
    idx <- seq_len(n)
    note <- ""
  } else {
    # Long document — send first and last N pages
    idx <- c(seq_len(max_pages_each_end),
             seq(n - max_pages_each_end + 1, n))
    note <- sprintf(
      "[NOTE: This document has %d pages. Showing pages 1-%d and %d-%d only.]\n\n",
      n, max_pages_each_end, n - max_pages_each_end + 1, n
    )
  }
  page_blocks <- lapply(idx, function(i) {
    sprintf("--- PAGE %d ---\n%s", i, pages[[i]])
  })
  paste0(note, paste(page_blocks, collapse = "\n\n"))
}
```

`max_pages_each_end = 4` is the starting value. Adjust based on validation
results if boundary signals are not appearing within the first/last 4 pages.

Documents where minutes are embedded in the middle of a long package (not near
the beginning or end) are flagged `needs_manual_review` in the output and
excluded from the accuracy calculation. These are an expected edge case — not
a failure mode.

### 5.4 Validation Set for Run 2

Build a separate hand-labelled set of 20 `SomethingElse` documents drawn from
the Run 1 validation population and extended as needed. For each document,
record the expected start and end page by manual inspection using `ReviewFile.R`.

```r
run2_validation <- data.frame(
  fac                  = character(),
  file                 = character(),
  expected_start_page  = integer(),
  expected_end_page    = integer(),
  contains_minutes     = logical(),   # FALSE for pure agendas / CEO reports
  hand_label_notes     = character()
)
```

### 5.5 Scoring

```r
run2_results <- data.frame(
  fac                  = character(),
  file                 = character(),
  expected_start_page  = integer(),
  got_start_page       = integer(),
  expected_end_page    = integer(),
  got_end_page         = integer(),
  confidence           = character(),
  pages_correct        = logical(),
  needs_manual_review  = logical(),
  qa_notes             = character()
)
```

Pass criteria:

- ≥90% of documents with minutes present have correct page boundaries (±1 page
  tolerance for genuinely ambiguous boundaries)
- Documents correctly returning `null` when no board minutes are present count
  as correct

---

## 6. Phase 3 — Pipeline Integration Check

**Prerequisite:** Both Run 1 and Run 2 must meet their pass criteria.

Verify that LLM-derived outputs integrate with the existing pipeline schema:

- Output schema matches or extends `minutes_corpus_audit.csv` — downstream
  scripts must not require modification
- `fac` column is character type throughout — coerce immediately on load
- `corpus_include` flag logic is preserved — `MinutesOnly` maps to
  `corpus_include = TRUE`; `SomethingElse` with no minutes found maps to
  `corpus_include = FALSE`; `SomethingElse` with minutes located maps to
  `corpus_include = TRUE` with a `boundary_source = "llm_run2"` flag
- All LLM calls logged via `init_logger(role = "minutes")` with document
  filename, classification result, confidence, and latency per call

Run the integration check against all documents from the 5 pilot hospitals
(not just the validation samples) and confirm a clean output file.

---

## 7. Go/No-Go Decision Criteria

| Evaluation step | Pass | Fail | Hybrid option |
|---|---|---|---|
| Run 1 — Classification | ≥90% accuracy; zero committee-as-MinutesOnly errors | <90% after two prompt revisions | — |
| Run 2 — Boundary detection | ≥90% correct page boundaries | <90% after architecture revision | Run 1 adopted; keyword extractor handles Run 2 population |
| Phase 3 — Integration | Clean pipeline output | Schema conflicts after patching | — |

**If Run 1 fails:** Revert fully to keyword extractor path. Resume `extract_minutes.R`
build from the June 21 carry-forward list.

**If Run 1 passes but Run 2 fails:** Adopt the LLM for classification (replacing
`minutes_classify.R`); retain the keyword extractor for boundary detection on
mixed documents (the original `minutes_extract_mixed.R` design). This is a
viable hybrid — the LLM handles the classification problem it is well-suited for;
R handles the extraction problem it is well-suited for.

**If both pass:** Full LLM two-pass pipeline adopted. `minutes_classify.R` and
the planned `minutes_extract_mixed.R` are both replaced.

---

## 8. Speed and Cost Benchmarking

Record for each document in the validation runs:

- OCR time (seconds) — `proc.time()` around `extract_text_ocr()` call
- LLM inference time (seconds) — `proc.time()` around `req_perform()` call
- Total time per document

From these, compute:

- Mean and max OCR time
- Mean and max inference time per pass (Run 1 and Run 2 separately — Run 2
  sends more context and will be slower)
- Projected total Run 1 time at observed rates × 1,732 documents
- Projected total Run 2 time at observed rates × estimated SomethingElse count
- VRAM headroom during batch runs — check `nvidia-smi` mid-validation

The keyword extractor completes the full corpus in seconds. The LLM pipeline
will take hours. That is acceptable if accuracy justifies it, but the benchmark
must be documented and confirmed before committing to a full corpus run.

---

## 9. R Script Deliverables

If the evaluation passes (fully or in hybrid form), the following scripts
are produced:

| Script | Purpose |
|---|---|
| `llm_run1_classify.R` | Run 1 — OCR + classify every document as MinutesOnly / SomethingElse |
| `llm_run2_boundaries.R` | Run 2 — OCR + locate minutes page boundaries in SomethingElse documents |
| `llm_validate.R` | Validation harness — runs both passes against labelled sets; scores accuracy |

Scripts live at `E:/HospitalIntelligenceR/roles/minutes/scripts/`.

If the evaluation fails entirely, the June 21 keyword extractor path resumes
with no changes to the existing script inventory.

---

## 10. Ubuntu Reference Commands

```bash
# Ollama status
sudo systemctl status ollama

# Restart Ollama (after config changes)
sudo systemctl restart ollama

# GPU / VRAM status
nvidia-smi

# Confirm model loaded
ollama ps

# Firewall status
sudo ufw status

# Stop GNOME RDP (run after KVM installed)
sudo systemctl stop gnome-remote-desktop
sudo systemctl disable gnome-remote-desktop

# Disable sleep (run after KVM installed)
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
```

---

*Prepared June 23, 2026 — HospitalIntelligenceR | Board Minutes Role*
*Revised June 23, 2026 — Two-pass architecture; OCR uniform across all documents*
*Go/no-go decision concludes the evaluation; hybrid outcome explicitly allowed*
