# BoardMinutes_AnalyticsWorkPlan.md
# Board Minutes Analytics — Master Decisions and Constraints Register

*Created: June 30, 2026*
*Role: minutes*
*Location: `E:/HospitalIntelligenceR/roles/minutes/docs/BoardMinutes_AnalyticsWorkPlan.md`*
*Upload to Claude Project knowledge repository. Commit to GitHub under the same path.*

---

## Purpose of This Document

This is the **decisions and constraints register** for the board minutes analytics
workstreams. It is not a task list. It records:

- Scope boundaries and what is explicitly out of scope
- Analytic definitions that will be cited in methods sections
- Architecture decisions and the rationale behind them
- Dependencies between workstreams
- Open questions that must be resolved before a workstream can begin

Session summaries track what happened. This document tracks why decisions were made.
Update it when a durable decision is made, not at session end as an afterthought.

---

## Corpus Overview

The board minutes corpus is assembled from publicly available PDF documents
scraped from Ontario hospital websites. It is designed for annual refresh, with
new hospitals and a year's worth of minutes added each December.

**Current corpus state (as of June 30, 2026):**
- Stage 1 classification complete: 1,881 MinutesOnly / 471 SomethingElse
- Stage 2 in progress: resolving SomethingElse population
- `minutes_analytical_master.rds` not yet built — depends on Stage 2 completion
- Internal date extraction not yet done — depends on Stage 2 completion

---

## Analytical Master — Design Decisions

### Single spine principle
All workstream scripts filter from `minutes_analytical_master.rds`. No script
defines its own inclusion criteria independently. This ensures consistent
hospital and document counts across all analyses and publications.

**Rationale:** Without a single spine, different workstreams will produce
different n-counts for the same nominal corpus. This is unacceptable in a
multi-paper publication series where figures must be reconcilable.

### Document tiers
Three tiers are recognised in the master:

| Tier | Definition |
|---|---|
| `MinutesOnly` | Full board minutes meeting all three Stage 1 structural criteria (header, attendance block, closing). The primary analytical tier. |
| `MinutesSummary` | Board Highlights / Meeting Summary documents: dated, authored by the board, record substantive content and decisions but lack a formal attendance block. Eligible for content-mining workstreams but not attendance analysis. |
| `SomethingElse` | All other documents — agendas, reports to the board, governance documents, etc. Excluded from all analytical corpora. |

**Decision date:** June 30, 2026.
**Rationale:** Attendance is not a current analytical requirement (board foci,
content mining, and decision tracking do not require it). MinutesSummary
documents carry sufficient signal for the current workstreams. Attendance analysis
is deferred to a future workstream at which point eligibility criteria will be
reviewed.

### Date field precedence
`doc_date` in the master is the **internal meeting date** extracted from document
content — not the scraper-derived date. Scraper dates are preserved as
`scrape_date` for provenance but are not used for any date-based analytical filter.

**Rationale:** Scraper dates reflect when a document was found online, which
may be months after the meeting. Internal dates are almost always present in
genuine minutes; absence of an internal date is itself a classification signal.

**Implication:** Internal date extraction is a required pre-step before building
the master. This is a pending workstream (see Section: Pipeline Pre-Steps).

### Annual refresh and provenance
Every record carries `scrape_date` and `data_source`. This supports:
- Cohort identification across annual refresh cycles
- Integration of the LH prior corpus (if decided)
- Potential future integration of hospital-contributed unpublished data

`data_source` values: `scrape_current`, `lh_prior`, `hospital_contributed`

### Version locking for publications
At each paper submission, the master is snapshotted with a dated suffix
(e.g. `minutes_analytical_master_v1_jun2026.rds`). The submitted paper's
figures and tables are reproducible against the named snapshot. The live
master retains its canonical name and continues to be updated.

---

## Pipeline Pre-Steps (Required Before Analytical Work Begins)

These must be completed in order. No analytical workstream starts until all
three are done.

### Pre-Step 1 — Complete Stage 2 classification
Resolve the 471 SomethingElse documents. Assign final tiers
(MinutesOnly, MinutesSummary, SomethingElse). The full-text scan script
`llm_run1_fulltext_scan.R` is currently running.

**Status:** In progress (June 30, 2026)
**Output:** Updated `llm_run1_results.csv` with resolved tiers; list of
documents promoted to MinutesSummary tier.

### Pre-Step 2 — LH prior corpus decision
Locate the LH prior corpus dataframe and assess: format, hospital overlap
with current registry FACs, date range coverage. Decide whether to integrate
as a `lh_prior` data_source tier or treat as a validation/comparison dataset.

**Status:** Deferred to immediately after Pre-Step 1.
**Constraint:** This decision must be made before building the master —
retrofitting a second data source breaks reproducibility for any workstream
already run.

### Pre-Step 3 — Internal date extraction
Run a date extraction pass over all MinutesOnly (and MinutesSummary, if any)
documents to populate `doc_date` from document content. Likely a lightweight
R + regex pass; LLM fallback for documents where regex fails.

**Status:** Not started.
**Output:** `doc_date` column added to index; feeds directly into master build.

### Pre-Step 4 — Build `minutes_analytical_master.rds`
Construct the master dataframe with all mandatory columns (see
`CLAUDE_WORKING_PREFERENCES.md` Section 15). Assign workstream eligibility
flags. Commit to GitHub. Lock corpus v1.

**Status:** Not started. Depends on Pre-Steps 1–3.

---

## Workstream Definitions and Constraints

### W1 — Corpus Demographics

**Purpose:** Describe the minutes corpus for the methods section and for
internal verification before analytical work begins.

**Scope:**
- Hospital coverage: unique FACs with ≥1 document in master, by tier
- Timespan by hospital: min/max `doc_date` per FAC — visualised as a
  horizontal Gantt-style timeline, sorted by `hospital_type_group`
- Discontinued hospitals: flag FACs where most recent `doc_date` is before
  January 2024; distinguish scraper gap from genuine discontinuation by
  cross-referencing registry (closed/merged hospitals)
- Word count distribution: from `word_count` field in classification results.
  Test normality; report median and IQR if skewed. Stratify by type group.
- Meeting frequency: meetings per hospital per year; flag COVID-era gaps (2020)

**Eligibility:** All documents in `MinutesOnly` tier of master. MinutesSummary
reported separately if included.

**Tools:** Pure R. No LLM.
**Reliability note:** Word count comes from the OCR pipeline; some variation
reflects OCR quality rather than true document length. Flag this in methods.

---

### W2 — Word Frequencies and Bigrams

**Purpose:** Descriptive language landscape of the corpus. Supports methods
section and provides qualitative grounding for W3 (foci) and W4 (topics).

**Scope:**
- Unigram and bigram frequency analysis, full corpus and by `hospital_type_group`
- Pre-processing: stop word removal (standard + domain), name removal
  (philipperemy name dataset, consistent with LH prior work), lemmatization
- Two outputs: full-corpus word cloud; type-group comparison panel

**Tools:** R (`tidytext`, `ggwordcloud`, `textstem`). No LLM.
**Constraint:** Pre-processing decisions must match the LH prior methodology
for any comparison to be valid. Confirm domain stop word list and name dataset
with LH before running.

---

### W3 — Board Foci (Riverbed Analysis)

**Purpose:** Replicate and extend the LH 2020 riverbed analysis to the full
Ontario corpus (119+ hospitals, 2015–2025). Primary publishable output of the
board minutes analytics workstream.

**Scope:**
- Apply the 16-area board foci taxonomy to score each meeting document
- Produce riverbed graphic at sector level and by `hospital_type_group`
- Compare pre-pandemic (≤2019), pandemic (2020–2022), and post-pandemic
  (2023+) eras

**Critical dependency:** The 16-area lexicon (term lists per focus area)
from LH prior work. Must be extracted from the archived R project before
this workstream can begin.

**Eligibility:** `in_foci_corpus == TRUE` in master. Minimum eligibility
criteria to be defined when lexicon is in hand — likely ≥3 meetings per
hospital within the analysis period.

**Tools:** R (term-frequency scoring against lexicon). No LLM.
**Reliability:** Report coverage rate (% of total tokens matching any focus
area term). Report IQR of hospital-level scores per focus as stability indicator.

---

### W4 — Content and Topic Mining

**Purpose:** Discover latent topics within the corpus; describe what boards
are actually discussing within and across focus areas. Methodologically
distinct from W3 — W3 applies a pre-defined taxonomy, W4 discovers structure.

**Scope:**
- LDA topic modelling on full MinutesOnly corpus
- Topic number selection via perplexity/coherence scores
- Topic labelling via Ollama (llama3.1:8b) — given top-10 terms per topic
- Track topic prevalence over time and by `hospital_type_group`

**Eligibility:** `in_topic_corpus == TRUE` in master.

**Tools:** R (`topicmodels`), Ollama for topic labelling. No Claude API cost.
**Reliability:** Report topic coherence scores. Manual validation of 20-document
top-topic assignments before accepting results.

---

### W5 — Sentiment Analysis (NRC EmoLex)

**Purpose:** Track sentiment (positive, negative, trust) over time across
the corpus. Extend the LH 2020 analysis to the pandemic and post-pandemic
periods.

**Scope:**
- Per-meeting NRC EmoLex scoring (positive, negative, trust — consistent
  with LH prior work)
- Domain adaptation: apply same exclusion list as LH prior work; document
  any additions
- Smoothed time series by hospital and by `hospital_type_group`
- 3-meeting rolling average (per LH 2020 recommendation)
- Pandemic-era analysis: test for measurable sentiment shift 2020–2022

**Eligibility:** `in_sentiment_corpus == TRUE` in master.

**Tools:** R (`syuzhet` or direct NRC lexicon join). No LLM.
**Reliability:** Between-hospital ICC on sentiment scores to control for
recording style variation. This is the primary validity concern for sentiment
analysis (noted in LH 2020 Limitations).

---

### W6A — General Strategy Alignment

**Purpose:** Does the language boards use in meetings reflect the thematic
categories from the Ontario Hospital Strategic Plans paper? Corpus-level
question — no per-hospital matching required.

**Scope:**
- Apply strategy theme lexicons (from `02_thematic_classify.R` taxonomy)
  to meeting text
- Score each meeting for presence/intensity of each strategy theme
- Compare distribution of board language across themes to distribution of
  strategic priorities sector-wide

**Eligibility:** `in_strategy_corpus == TRUE` in master. All MinutesOnly
documents eligible.

**Tools:** R (term-frequency scoring against strategy taxonomy). No LLM.

---

### W6B — Hospital-Specific Strategy Linkage

**Purpose:** For hospitals with both a dated strategic plan and contemporaneous
minutes, is strategy language appearing in board discussions and decisions?

**Scope:**
- Identify FACs in `in_strategy_linked_corpus` (strategy plan period overlaps
  with at least some minutes by `doc_date`)
- Three-tier methodology applied sequentially, stopping when sufficient signal
  is found:
  1. **Term overlap (R):** Key noun phrases from strategic plan scored in
     contemporaneous vs. non-contemporaneous minutes
  2. **Semantic similarity (R + embeddings):** Cosine similarity between
     strategic plan sections and minutes passages — more robust to paraphrasing
  3. **LLM classification (Ollama → Claude API spot-check):** Per-hospital
     classification of whether specific board decisions reference strategic
     priorities

**Cost control:** Ollama handles bulk classification. Claude API used only
for blind validation sample (same methodology as Stage 1 validation).
Estimated API cost to be calculated before any Claude API calls are made.

**Reliability:** Blind manual validation at each tier before accepting results.
Same pass/fail threshold as Stage 1: ≥95% accuracy, zero false negatives on
the "strategy-linked" label.

---

## Open Questions

| Question | Blocks | Status |
|---|---|---|
| LH prior corpus: format and FAC overlap? | Pre-Step 2, W3 | Pending — discuss with LH after Stage 2 |
| LH lexicon: extractable from archived R project? | W3 | Pending — locate archive |
| MinutesSummary inclusion: which workstreams? | Master build | Decided: W4, W5, W6A. Not W3 (foci require full minutes structure). W6B TBD. |
| Minimum meeting count for foci eligibility? | W3 | Pending — set after lexicon in hand |
| Domain stop word list: match LH prior exactly? | W2, W3, W5 | Pending — confirm with LH |
| Semantic similarity toolchain for W6B Tier 2? | W6B | Pending — evaluate `text` package vs. alternatives |

---

## Workstream Sequencing and Dependencies

```
Pre-Step 1 (Stage 2)
  └── Pre-Step 2 (LH decision)
        └── Pre-Step 3 (date extraction)
              └── Pre-Step 4 (build master)
                    ├── W1 (demographics)       ← no further dependencies
                    ├── W2 (word frequencies)   ← confirm LH stop word list first
                    ├── W3 (board foci)         ← requires LH lexicon
                    ├── W4 (topic mining)       ← no further dependencies
                    ├── W5 (sentiment)          ← confirm LH domain adaptation
                    ├── W6A (general alignment) ← requires strategy taxonomy
                    └── W6B (hospital-specific) ← requires W6A complete
```

W1 and W4 can begin as soon as the master is built — no lexicon or prior-work
dependency. W3 is blocked on the LH lexicon. W2, W5, W6A, W6B require
methodological alignment with prior work before running.

---

## Publication Targets

| Paper | Primary workstreams | Target submission |
|---|---|---|
| Board Governance Patterns in Ontario Hospitals (2015–2025) | W1, W2, W3, W5 | TBD — depends on corpus completion |
| Strategy and Governance Alignment | W6A, W6B | TBD — follows first paper |

Each paper submission triggers a master snapshot (see Section 14 of
`CLAUDE_WORKING_PREFERENCES.md`).
