# Board Minutes — Phase 2 Analysis Work Plan
## HospitalIntelligenceR

*Prepared June 2026 | Follows Phase 1 archive completion (57 hospitals, ~2,431 index rows)*
*This plan is a living document. A planning session at the end of each tier will add
detail to the next tier before work begins.*
*Last updated: June 13, 2026 — Stage 2 secondary extraction and in-camera quarantine
added following T1-S2 corpus audit results.*

---

## 1. Overview and Analytical Framework

Phase 1 produced a structured archive of board meeting minutes PDFs from 57 Ontario
hospitals. Phase 2 extracts analytical value from that archive across three tiers.

Each tier has a distinct analytical purpose and produces outputs that are prerequisites
for the next. The tiers are sequential by design. Tier 2 and Tier 3 details will be
confirmed and extended at the close of the preceding tier, when the actual shape of
the data is known.

| Tier | Name | Core question | Primary method |
|---|---|---|---|
| 1 | Audit and Classification | What do we actually have? | Structural heuristics + NLP |
| 2 | Board Foci and Sentiment | Where do boards focus their attention, and what is the tone? | NLP dictionary scoring + NRC EmoLex |
| 3 | Concordance | Do boards deliberate in alignment with their strategic plans and stated values? | Language matching (no taxonomy required) |

**The core analytical boundary, established in Tier 1 and respected throughout:**
All Tier 2 and Tier 3 analysis operates exclusively on documents confirmed as board
meeting minutes. Agendas, CEO reports, committee reports, presentations, embedded
materials, and in-camera records are excluded from the analytical corpus. This boundary
is enforced once and does not require re-examination downstream.

**Prior work this builds on:**

Hooper (2020) established the foundational methodology from 22 Ontario hospitals and
700+ meetings: foci taxonomy, NRC EmoLex sentiment, and the riverbed graphic. Hooper
(2021, unpublished) extended this to 36 hospitals and 1,500 meetings and tested whether
board focus on finance or quality is associated with measurable outcomes. The result was
predominantly null: increased board focus does not significantly improve financial or
quality outcomes for hospitals as a group.

The current project extends both papers: larger cohort (57 hospitals), more recent data,
pandemic-era coverage, and a new analytical dimension (concordance between board
deliberation and strategic plans). It applies to the full Ontario public hospital sector
rather than a curated subset.

---

## 2. Outputs Summary

### Tier 1

```
roles/minutes/outputs/
    minutes_corpus_audit.csv    one row per PDF; classification and QA flags
    minutes_master.csv          one row per confirmed meeting; corpus_include = TRUE only
    minutes_coverage.csv        one row per hospital per year; temporal coverage summary
```

### Tier 2

```
roles/minutes/outputs/
    minutes_foci.csv            one row per meeting; proportional foci scores across focus areas
    minutes_sentiment.csv       one row per meeting; NRC EmoLex sentiment scores
```

### Tier 3

```
roles/minutes/outputs/
    minutes_concordance.csv     one row per hospital per year; concordance scores
```

*Tier 3 schema to be finalized at the Tier 2 planning session.*

---

## 3. Tier 1 — Audit and Classification

### 3.1 Purpose

The PDFs collected in Phase 1 were retrieved by link text and URL pattern, not document
content. A proportion will be agendas, mixed packages containing minutes plus embedded
reports, or other non-minutes materials that passed the filename filter. Tier 1 resolves
this before any analysis runs, producing a clean and confirmed corpus.

Tier 1 has five steps: text extraction, document classification, secondary extraction
from mixed and rejected documents, metadata extraction, and temporal coverage mapping.
An in-camera quarantine review is conducted before any Tier 2 analysis begins.

### 3.2 Step 1 — Text extraction

Extract text from every PDF using pdftools::pdf_text(). Output is a character vector,
one element per page. Pages are concatenated with a section marker to preserve page
boundary information for later use.

Two immediate quality signals emerge at this step:

- Word count: Flags thin documents. Thin documents are not automatically excluded.
  A one-page special meeting with a complete structural pattern is valid. Thinness is
  a flag for review, not an exclusion criterion.
- Encoding success: PDFs returning empty or garbage text are scanned/image-based and
  cannot be processed by the NLP pipeline. These are flagged needs_ocr and set aside.
  They may be recoverable in a future session but are not blocking for Tier 1 completion.

### 3.3 Step 2 — Document classification (Stage 1)

**The classification problem:** What is this document?

The primary classifier is structural. Board minutes follow a consistent and identifiable
pattern across Ontario hospitals:

1. Header block: Title containing "minutes", "board meeting", "open session", or
   equivalent. Usually includes meeting date, location, and type. Located in the first
   200 words.
2. Attendance block: Named members or a count. Ontario hospitals use at least eight
   distinct attendance block formats — from "Members Present" headings to inline quorum
   confirmations to sub-hospital name headers (MICs group) to right-margin membership
   sidebars. The classifier covers all confirmed variants.
3. Deliberation body: Agenda items with recorded outcomes including motion language,
   discussion summaries, and approvals. The deliberation body is the defining feature
   of minutes as distinct from all other document types.
4. Close: "The meeting was adjourned at [time]" or "Next meeting: [date]".

A document with all four structural blocks is classified as confirmed minutes. A document
missing the deliberation body is classified as agenda, report, or other.

**Document typology (Stage 1 classifier):**

| Class | Description | Corpus include? |
|---|---|---|
| minutes | Confirmed board meeting minutes, standalone | Yes |
| summary_minutes | Minutes with header and attendance intact but no recorded motions; valid abbreviated record | Yes |
| mixed | Package containing minutes plus other material (CEO report, financials, presentations) | Yes — pending Stage 2 page-range extraction |
| agenda | Agenda only; no recorded deliberation | No |
| report | CEO report, committee report, presentation, financial statement | No |
| needs_ocr | Image-based PDF; text extraction failed | Deferred |
| other | Unclassifiable, non-English, or structural signals present but insufficient | No — Stage 2 may recover some |

**T1-S2 corpus audit results (June 13, 2026):**

| doc_class | n | corpus_include |
|---|---|---|
| minutes | 1,553 | TRUE |
| mixed | 131 | TRUE (pending Stage 2) |
| summary_minutes | 49 | TRUE |
| **Total corpus** | **1,733** | **TRUE** |
| agenda | 261 | FALSE |
| other | 214 | FALSE |
| needs_ocr | 120 | FALSE |
| file_missing | 79 | FALSE |
| report | 24 | FALSE |
| **Total excluded** | **698** | **FALSE** |

Archive total: 2,431 PDFs across 62 hospitals.

**Primary classification logic — structural:**

Detection is regex-based on the extracted text. Script: `minutes_classify.R`.
Output: `minutes_corpus_audit.csv`.

**Secondary confirmation — deliberation term density:**

Deliberation term density (count per 1,000 words) is computed as a secondary signal.
A document with the correct structural pattern but very low deliberation density is
flagged for manual review rather than hard-classified.

**Special meeting handling:**

Document length is not a disqualifier. A one-page special meeting with header,
attendance, one motion, and adjournment is a complete and valid document.

**Consent agenda detection:**

A consent agenda appearing as a single line item approved by a single motion with no
discussion text following it is flagged with has_consent_agenda = TRUE. The proportion
of agenda items passing through consent (where countable) is recorded as
consent_agenda_pct. This field is an analytical variable in its own right; see
Section 3.7.

### 3.4 Step 3 — Secondary extraction from rejected documents (Stage 2)

**Why Stage 2 is required:**

The Stage 1 classifier correctly identified 698 documents as `corpus_include = FALSE`.
However, 27 hospitals have all or most of their minutes in mixed packages — bundled PDFs
where minutes content is preceded or followed by CEO reports, committee reports,
financials, or presentation decks. Without Stage 2, these hospitals would have zero or
severely degraded corpus representation, introducing systematic hospital-level bias in
Tiers 2 and 3.

**Design:**

`minutes_extract_mixed.R` operates on the 698 rejected files. It reads each PDF
page-by-page using `pdftools::pdf_text()` and applies the existing structural detection
functions (`detect_header()`, `detect_close()`, `detect_report_lead()`) to identify:

- The page on which the minutes section begins (header regex fires)
- The page on which the minutes section ends (close regex fires, followed by report
  markers indicating new non-minutes content begins)

The extracted page range is written to `minutes_page_start` and `minutes_page_end`
fields in the audit. For Tier 2, text passed to the foci scorer is trimmed to this
page range only — mixed packages are never physically split.

Documents where a minutes page range is successfully identified are re-evaluated:
if the extracted range passes the structural classifier, `corpus_include` is updated
to TRUE and `doc_class` is updated to `mixed_extracted`.

**Hospitals with zero Stage 1 corpus contribution requiring Stage 2 priority:**

| FAC | Hospital | Files in index | Notes |
|---|---|---|---|
| 977 | TERRACE BAY NORTH OF SUPERIOR HC | 72 | Robots-blocked in Phase 1; files not downloaded |
| 644 | Cornwall Hospital CORNWALL HOTEL DIEU | 42 | Summary format — Stage 2 priority |
| 967 | CORNWALL COMMUNITY | 42 | Summary format — Stage 2 priority |
| 941 | Humber River Hospital | 23 | Stage 2 priority |
| 662 | GERALDTON DISTRICT HOSPITAL | 1 | Single file; Stage 2 review |
| 975 | MISSISSAUGA TRILLIUM HEALTH PARTNER | 1 | Single file; Stage 2 review |

FAC 977 is a known Phase 1 gap (robots-blocked); the remaining five are Stage 2 targets.
Before building `minutes_extract_mixed.R`, manually open one file from FACs 644 and 967
to confirm their format — both have 42 files and zero corpus contribution, which is
anomalous and may indicate a PDF layout issue rather than a mixed-package issue.

**Script:** `minutes_extract_mixed.R`
**Input:** `minutes_corpus_audit.csv` (rows where `corpus_include = FALSE`)
**Output:** Updated `minutes_corpus_audit.csv` with `minutes_page_start`,
`minutes_page_end`, and revised `corpus_include` and `doc_class` for recovered documents.

### 3.5 Step 4 — In-camera document identification and quarantine

**Why this step is mandatory:**

Publishing analysis derived from in-camera board deliberation would be a serious ethical
and reputational risk. In-camera sessions in Ontario hospitals cover topics explicitly
excluded from public disclosure: litigation strategy, labour relations, individual
personnel matters, and privileged legal advice. Even indirect signals derived from NLP
analysis of in-camera content must not appear in any published output.

**Scope:**

The Stage 1 classifier assigns `meeting_type = in_camera` to 116 documents across 31
hospitals. However, diagnostic review confirmed that the majority of these are false
positives — open-session minutes containing a standard motion to move in-camera during
the meeting (e.g. "Moved to move in camera at 8:45 pm... Moved to return to open session
at 9:10 pm"). The `extract_meeting_type()` function fires on "in camera" appearing in the
document header region even when the document itself is an open-session record.

**Required fix to `minutes_classify.R`:**

Tighten the `in_camera` detection in `extract_meeting_type()` to avoid false positives
from routine in-camera motion language in open-session minutes. Candidate approaches:

- Restrict match to the first 300 characters only (title line), not the full 1,500-
  character header region
- Require "in camera" or "closed session" to appear in the document title without
  "open session" also present in the same region
- Require the absence of standard open-session structural signals (attendance block,
  motions) for an in-camera classification to stand

The fix is applied in `minutes_classify.R` and the audit re-run before quarantine review.

**Quarantine procedure:**

After the regex fix is applied:

1. Extract all rows where `meeting_type = in_camera` from the updated audit
2. Manual review of each file: is this a true standalone in-camera record, or an
   open-session document with an in-camera motion?
3. True in-camera records: set `corpus_include = FALSE`, `qa_flags = "in_camera_quarantine"`
4. Open-session documents mislabelled: correct `meeting_type` to `regular` or `special`
5. Document the final count of quarantined documents in the Phase 2 methods section
6. In-camera quarantined documents are never passed to Tier 2 or Tier 3

**Note on partial in-camera content:**

Some open-session minutes contain a brief in-camera segment embedded within the record
(e.g. "The Board moved in camera at 8:15 pm... The Board returned to open session at
8:45 pm. No reportable matters."). These documents are NOT quarantined. The in-camera
segment itself contains no recorded deliberation — the return-to-open-session notation
is the entire in-camera record. These documents remain `corpus_include = TRUE`.

### 3.6 Step 5 — Metadata extraction

For all documents with `corpus_include = TRUE`:

Meeting date: Extracted from the header block, the first date-pattern match in the
first 300 words, cross-validated against the filename date. Discrepancies > 30 days
are flagged date_conflict for manual review. FAC 927 has four files with yearonly
placeholder dates in filenames; actual dates are recovered here from document content.

Meeting type assigned by keyword match on document title or first paragraph:

| Keyword pattern | Type assigned |
|---|---|
| "Regular Board Meeting", "Public Board Meeting", "Open Session" | regular |
| "Special Board Meeting", "Special Meeting of the Board" | special |
| "Annual General Meeting", "Annual Meeting" | annual |
| Standalone in-camera record (post-quarantine review) | in_camera |
| No match | unknown |

**Script:** `minutes_extract_t1.R`

### 3.7 Step 6 — Temporal coverage mapping

Once minutes_master.csv is produced, the first analytical output of Tier 1 is a
coverage map: which hospitals have continuous records, which have gaps, and what the
date distribution looks like across the pandemic era.

Coverage is assessed by hospital and year. Thin coverage is defined as fewer than
three confirmed meetings in a calendar year for a hospital with an active minutes URL.
Hospitals meeting monthly should have 10-12 meetings per year; quarterly boards, four.

The coverage map determines which hospitals and time periods are eligible for temporal
trend analysis in Tier 2. Gap classification deferred from Phase 1 is completed here.

**Scripts:** `minutes_coverage.R`, `minutes_build_master.R`

### 3.8 Consent agenda as a standalone analytical thread

The consent agenda warrants separate treatment beyond classification. It is a procedural
tool used by boards to approve routine items in a single motion without discussion.
The analytical interest is in its use as a governance signal:

- High consent agenda use may indicate a well-functioning board efficiently disposing
  of routine business, or a board not actively scrutinizing management reporting.
- Items pulled off consent for discussion are a direct signal of active board attention.
  Where minutes record consent agenda pulls, these are flagged.
- Trend over time: is consent agenda use increasing? Is active deliberation on
  substantive items decreasing proportionally?

T1-S2 audit finding: consent agenda use is near-universal in the confirmed corpus —
35 of 37 corpus-include documents in the T1-S1 labelled sample used a consent agenda.
Detection must capture non-standard labels including "Items for Approval" and "Items
on Consent."

Hooper (2020) noted that consent agenda use can inadvertently hide governance activity
from benchmarking analysis. A hospital recording everything through consent will appear
lower-focus in foci analysis than one recording individual discussion. This is a known
limitation to document in Tier 2.

### 3.9 Tier 1 output schemas

**minutes_corpus_audit.csv** — one row per PDF:

| Field | Notes |
|---|---|
| fac | Always character |
| filename | From minutes_index.csv |
| doc_class | Classification result |
| corpus_include | TRUE / FALSE |
| word_count | Post-extraction word count |
| has_header | Logical |
| has_attendance | Logical |
| has_motions | Logical |
| has_close | Logical |
| has_consent_agenda | Logical |
| meeting_type | regular / special / annual / in_camera / unknown |
| minutes_page_start | First page of minutes section (Stage 2; mixed packages) |
| minutes_page_end | Last page of minutes section (Stage 2; mixed packages) |
| is_thin | Logical; word_count < 100 |
| qa_flags | Pipe-delimited: thin, yearonly_date, version_suffix, file_missing, in_camera_quarantine, date_conflict |

**minutes_master.csv** — corpus_include = TRUE rows only, one row per confirmed meeting:

| Field | Notes |
|---|---|
| fac | Always character |
| hospital_name | From registry |
| hospital_type_group | Teaching / Community Large / Community Small / Specialty |
| meeting_date | From document content |
| meeting_year | Derived |
| meeting_type | regular / special / annual / unknown |
| source_pdf | Canonical filename |
| doc_class | minutes / summary_minutes / mixed / mixed_extracted |
| word_count | Post-cleaning |
| has_consent_agenda | Logical |
| qa_flags | Any remaining flags |

**minutes_coverage.csv** — one row per hospital per year:

| Field | Notes |
|---|---|
| fac | Always character |
| hospital_name | From registry |
| hospital_type_group | Type group |
| year | Calendar year |
| n_meetings | Confirmed meetings in that year |
| coverage_status | full / thin / gap / pre_archive |

### 3.10 Files to build — Tier 1

| File | Location | Purpose | Status |
|---|---|---|---|
| minutes_classify.R | roles/minutes/scripts/ | Stage 1 structural classifier; produces minutes_corpus_audit.csv | ✓ Complete — fix in_camera regex before Stage 2 |
| minutes_extract_mixed.R | roles/minutes/scripts/ | Stage 2 page-range extraction from mixed/rejected documents | To build — T1-S3 |
| minutes_extract_t1.R | roles/minutes/scripts/ | Date and type extraction from confirmed corpus | To build — T1-S4 |
| minutes_coverage.R | roles/minutes/scripts/ | Temporal coverage map; produces minutes_coverage.csv | To build — T1-S5 |
| minutes_build_master.R | roles/minutes/scripts/ | Assembles minutes_master.csv from Tier 1 outputs | To build — T1-S5 |

### 3.11 Build sequence — Tier 1 (updated)

| Session | Work | Deliverable |
|---|---|---|
| T1-S1 | Hand-label 39 PDFs (stratified sample); calibrate structural classifier regex patterns | Labelled sample; regex patterns confirmed ✓ |
| T1-S2 | Build minutes_classify.R; run on full archive; iterate attendance regex; review exclusion counts | minutes_corpus_audit.csv ✓ |
| T1-S3 | Fix in_camera regex in minutes_classify.R; build minutes_extract_mixed.R; run Stage 2 on 698 rejected files; conduct in-camera quarantine review | Updated minutes_corpus_audit.csv; in-camera documents quarantined |
| T1-S4 | Build minutes_extract_t1.R; extract date and type from confirmed corpus; resolve FAC 927 date gaps | Date/type fields populated; conflict flags reviewed |
| T1-S5 | Build minutes_coverage.R and minutes_build_master.R; produce coverage map; classify gaps | minutes_master.csv; minutes_coverage.csv |
| T1-S6 | Review outputs; manual triage of flagged documents; finalize corpus; Tier 2 planning session | Clean corpus confirmed; Tier 2 plan updated |

**Tier 1 estimated sessions: 6** (revised from 5; Stage 2 extraction and in-camera
quarantine add one session)
**Tier 1 completion signal:** minutes_master.csv produced; corpus confirmed as open-session
minutes only; in-camera quarantine complete; coverage map complete; Tier 2 plan confirmed.

---

## 4. Tier 2 — Board Foci and Sentiment

*Detail below reflects current design intent. The Tier 1 planning session will confirm,
adjust, or extend this section before build begins.*

### 4.1 Purpose

Tier 2 answers two questions: where do boards focus their attention, and what is the
overall tone of the board over time? These are descriptive and comparative — the outputs
benchmark each hospital against the sector and against itself across time. The two
analytical streams (foci and sentiment) are independent and can be built in parallel once
the corpus is confirmed.

### 4.2 Foci — taxonomy and measurement

**Validated baseline: Hooper (2020) foci taxonomy.** The focus areas were derived from
700+ Ontario hospital board meetings using LDA topic modelling and literature review.
This is the validated starting point. The strategy taxonomy (WRK, PAT, FIN, etc.) is
not used for Tier 2 — it was designed for strategic planning language and does not cover
governance-specific foci such as compliance, medical staff, and consent agenda.

**The 15 substantive focus areas:**

| Code | Focus Area | Notes |
|---|---|---|
| FIN | Finance | Consistently the highest-focus area (~17-25%) |
| QUAL | Quality | Legally mandated under ECFAA; substantially lower focus than Finance |
| STR | Strategy | Strategic plan discussion, monitoring, approval |
| COMP | Compliance | Legal and regulatory obligations |
| POL | Policy and Bylaw | Board policy review and approvals |
| MVV | Mission, Vision and Values | Foundational document references |
| MGT | Management Related | Highly variable; includes CEO reports where discussed |
| MED | Medical Staff | Appointments, credentialling, MAC liaison |
| GOV | Governance and Recruitment | Board composition, committee structure, appointments |
| COM | Community and Patients | Community accountability, patient experience |
| HIS | Health Information System | IT governance and data reporting |
| EXEC | Executive Committee | Between-meeting decisions referred to full board |
| CA | Consent Agenda | Tracked separately as analytical variable |
| INC | In-Camera | Volume measured only; no content available |
| PROC | Procedural | Routine process items; excluded from substantive denominator |

**Measurement approach — dictionary-based scoring:**

LDA was used in Hooper (2020) to develop lexicon terms; it is not the operational
measurement method here. For each meeting, the frequency of curated lexicon terms per
focus area is computed, normalized by document length, and converted to proportional
scores. This is auditable: which terms fired and how many is traceable for any meeting.

R implementation: tidytext::unnest_tokens() joined to a custom lexicon data frame,
grouped by focus area.

Denominator: word count of minutes text post-cleaning, excluding PROC content. For
mixed_extracted documents, denominator is the word count of the extracted page range
only — not the full bundled package. Agenda item headings appearing in the body text
are weighted at 1.5x their word count, reflecting that explicit agenda naming signals
intentional board attention.

**AI validation:** After NLP baseline is complete, a 15-20% random sample of meetings
is run through the Claude API using a purpose-built foci extraction prompt. NLP and AI
outputs are compared on the held-out sample. Where systematic divergence appears (> 15
percentage points on any focus area for > 20% of sampled meetings), the lexicon is
adjusted. Each output row is labelled with a method field.

**Primary analytical outputs:**

- Riverbed graphic: mean foci proportions and 20th-80th percentile bands across the
  57-hospital cohort; replicates and extends Hooper (2020)
- Individual hospital overlays on the sector riverbed
- Temporal trend by focus area across the pandemic era
- Consent agenda trend over time by hospital type

### 4.3 Sentiment — NRC EmoLex

**Tool: NRC EmoLex (National Research Council Canada, 2016).** This is the validated
tool used in Hooper (2020) and the appropriate baseline for Ontario hospital board
minutes. The EmoLex defines word associations across eight emotions and two sentiments
(positive, negative). For this analysis, trust, positive, and negative are the three
primary dimensions, consistent with Hooper (2020).

**Healthcare domain modification (required):** Several terms carry false emotional signal
in a healthcare governance context and must be excluded before scoring. Common examples:
"hospital" (NRC assigns trust; meaningless here), "discharge" (NRC assigns negative;
clinical procedure in context). The modification follows Hooper (2020). The exclusion
list is documented in the lexicon file for reproducibility.

**Scoring:** Sentiment rate per 1,000 words per meeting. A three-meeting rolling average
is applied for trend analysis; individual meeting scores are too noisy to interpret alone.

**Extension beyond Hooper (2020):** The current dataset covers 2015-2026 and includes
the pandemic period. Testing whether trust, positive, and negative sentiment shifted
during COVID-19 is a direct analytical contribution. The prior observation that declining
trust and positive sentiment may precede unexpected CEO turnover will be retested with
the expanded dataset.

### 4.4 Files to build — Tier 2

| File | Location | Purpose |
|---|---|---|
| minutes_lexicon.R | roles/minutes/scripts/ | Governance-domain lexicon per focus area; NRC EmoLex healthcare exclusions |
| minutes_foci_nlp.R | roles/minutes/scripts/ | Dictionary scoring; produces foci proportions per meeting |
| minutes_sentiment.R | roles/minutes/scripts/ | NRC EmoLex scoring with healthcare modification |
| minutes_foci_ai.R | roles/minutes/scripts/ | AI validation on held-out sample; comparison to NLP baseline |
| minutes_foci_prompt.txt | roles/minutes/prompts/ | Foci extraction prompt for AI validation pass |
| minutes_foci_figures.R | roles/minutes/scripts/ | Riverbed graphic; overlays; temporal trends |
| minutes_sentiment_figures.R | roles/minutes/scripts/ | Sentiment trend figures; pandemic-era comparison |

### 4.5 Build sequence — Tier 2

| Session | Work | Deliverable |
|---|---|---|
| T2-S1 | Build minutes_lexicon.R; construct focus-area term lists from Hooper (2020) and manual review of 20 sampled meetings; document NRC EmoLex healthcare exclusions | minutes_lexicon.csv; exclusion list |
| T2-S2 | Build minutes_foci_nlp.R; run dictionary scoring on full corpus; spot-check 10 meetings manually | NLP foci baseline |
| T2-S3 | Build minutes_sentiment.R; run NRC EmoLex scoring with healthcare modification | Sentiment scores per meeting |
| T2-S4 | Build minutes_foci_ai.R and prompt; run AI validation on held-out sample; adjust lexicon if needed | Comparison table; method labels finalized |
| T2-S5 | Build figures: riverbed graphic, hospital overlays, temporal foci trends, sentiment trends | minutes_foci.csv final; minutes_sentiment.csv final; analytical figures |
| T2-S6 | Review findings; document analytical observations; Tier 3 planning session | Tier 3 plan confirmed and detailed |

**Tier 2 estimated sessions: 6**
**Tier 2 completion signal:** minutes_foci.csv and minutes_sentiment.csv produced;
riverbed graphic produced; sector-level findings documented; Tier 3 plan confirmed.

---

## 5. Tier 3 — Concordance

*Detail below reflects current design intent. The Tier 2 planning session will confirm,
extend, and add session-level detail before build begins.*

### 5.1 Purpose

Tier 3 asks a different question than Tier 2. Tier 2 describes what boards do and
benchmarks them against the sector. Tier 3 asks whether what boards do is aligned with
what their hospitals said they would prioritize — in their strategic plans and in their
foundational documents.

This is an evaluative question, not a descriptive one. The output is a concordance score
per hospital, measuring whether board deliberation language reflects the hospital's own
stated priorities.

### 5.2 Approach — language matching, not taxonomy

Tier 3 uses direct language matching rather than a taxonomic approach. The question is:
does the actual language of the strategic plan appear in the board's deliberations?

This is more direct and more honest than cosine similarity of theme vectors. Two hospitals
might both score high on "Strategy" in the foci analysis while deliberating on completely
different things. Language matching is hospital-specific and plan-specific — it measures
whether this board used this plan's language, not whether the board and plan share a
category label.

A taxonomic crosswalk between the Hooper (2020) foci and the strategy taxonomy codes is
not required for Tier 3 and will not be built unless a specific analytical purpose
emerges at the Tier 2 planning session.

**Tier 3a — Strategy concordance:**

For each hospital in the confirmed corpus:

1. Extract content terms from strategy_classified.csv: direction names, stated priorities,
   distinctive phrases from the active strategic plan.
2. Build a per-hospital strategic lexicon of 20-50 terms, weighted by distinctiveness.
   Common terms (care, quality, community) are down-weighted; specific terms (digital
   health strategy, regional stroke pathway) are up-weighted.
3. Score each confirmed meeting against that hospital's lexicon: count of lexicon term
   occurrences per 1,000 words.
4. Aggregate to annual concordance scores per hospital.
5. Analyse over time: does concordance increase after plan adoption? Does it decay as
   plans age? Does it differ by hospital type or era?

The quality of this analysis depends on the specificity of the strategic plan text.
Hospitals with vague, generic plans will produce weak term lists and uninformative
concordance scores. This is a known and acceptable limitation — and may itself be an
analytical observation.

**Tier 3b — MVV concordance:**

Same language-matching approach applied to Mission, Vision, and Values statements.
Requires the foundational documents role to be at least partially complete. Hooper (2020)
flagged this as a priority extension: preliminary work showed significant variation in
how much boards reflect their own MVV language in deliberations. This project quantifies
that variation at scale.

**Tier 3c — Replication of the focus-outcome null result:**

Hooper (2021, unpublished) found no significant beneficial relationship between board
focus intensity on finance or quality and measurable outcomes for all hospitals as a
group. The current dataset enables direct replication with a larger cohort (57 vs 36
hospitals), a more recent time period, and the pandemic era as a natural experiment.

HIT data (hit_strategy_analytical.csv) is already available for the finance dimension.
Quality outcome data will require CIHI linkage or MOH data and is assessed at the Tier
2 planning session.

### 5.3 Dependencies

| Dependency | Required for | Status |
|---|---|---|
| minutes_master.csv and minutes_foci.csv | All Tier 3 work | Built in Tiers 1 and 2 |
| strategy_classified.csv | Tier 3a strategy concordance | Available |
| Foundational documents role (MVV extraction) | Tier 3b MVV concordance | Not yet built |
| CIHI quality outcome data | Tier 3c quality outcome replication | Not yet obtained |
| hit_strategy_analytical.csv | Tier 3c finance outcome replication | Available |

### 5.4 Files and build sequence — Tier 3

*To be detailed at the Tier 2 planning session. Expected files:*

| File | Location | Purpose |
|---|---|---|
| minutes_concordance_lexicon.R | roles/minutes/scripts/ | Per-hospital strategic term extraction and weighting |
| minutes_concordance.R | roles/minutes/scripts/ | Language-matching concordance scoring |
| minutes_concordance_figures.R | roles/minutes/scripts/ | Concordance visualizations; outcome regression |

**Tier 3 estimated sessions: 5-8** (wider range reflects unresolved MVV dependency)
**Tier 3 completion signal:** minutes_concordance.csv produced; strategy and MVV
concordance scores available per hospital per year; outcome regression documented.

---

## 6. Known Risks and Mitigations

| Risk | Likelihood | Mitigation |
|---|---|---|
| Mixed packages with minutes embedded in larger documents | Confirmed | Stage 2 extraction (minutes_extract_mixed.R) handles this; 27 hospitals affected |
| In-camera documents inadvertently included in corpus | Low post-fix | in_camera regex fix + manual quarantine review before Tier 2 |
| Scanned PDFs not readable by pdftools | Low-Moderate | needs_ocr flag; 120 files across 16 hospitals; deferred; not blocking |
| Special meetings misclassified as thin or incomplete | Low | Extraction quality is independent of length; structural pattern is the classifier |
| Consent agenda use hiding substantive governance activity | Known | Documented as limitation; has_consent_agenda field captures it |
| NLP lexicon terms insufficient for current Ontario minutes | Moderate | 20-document manual review before lexicon finalization; AI validation is the backstop |
| NRC EmoLex healthcare modifications incomplete | Low | Exclusion list documented and iteratively refined during T2-S1 |
| Strategic plan language too generic for language matching | Moderate | Distinctive term weighting down-weights common terms; limitation documented per hospital |
| Foundational documents role not ready for Tier 3b | Moderate | Tier 3a proceeds independently; Tier 3b deferred until MVV available |
| JS-required hospitals (7 FACs) not yet in archive | Known gap | Tiers 2 and 3 proceed with 57-hospital corpus; JS hospitals added if RSelenium session completed |
| FACs 644, 967 have 42 files each with zero corpus contribution | Requires investigation | Manual file review before Stage 2 build to confirm format |

---

## 7. Planning Checkpoints

**End of Tier 1 — planning session agenda:**
- Review corpus composition after Stage 2: what proportion recovered from mixed packages
- Review in-camera quarantine results: final count and hospital distribution
- Review coverage map: which hospitals and years are eligible for trend analysis
- Review consent agenda prevalence: how common, how variable across hospitals
- Confirm or adjust Tier 2 foci taxonomy and lexicon build approach
- Confirm NRC EmoLex healthcare exclusion list
- Adjust Tier 2 session estimates based on confirmed corpus size

**End of Tier 2 — planning session agenda:**
- Review riverbed findings: where does this cohort sit relative to Hooper (2020)?
- Review sentiment findings: is a pandemic signal visible?
- Confirm Tier 3 language-matching design; assess per-hospital plan specificity
- Assess MVV dependency: is foundational documents role sufficiently advanced?
- Assess CIHI data availability for quality outcome replication
- Add session-level detail to Tier 3 build sequence

---

## 8. Prior Literature

| Paper | Relevance |
|---|---|
| Hooper, L. (2020). Measuring Boards Using Quantitative Tools from Natural Language Processing. Healthcare Quarterly 23(3). | Direct methodological predecessor. Foci taxonomy, NRC EmoLex approach, riverbed graphic, 22 Ontario hospital baseline. |
| Hooper, L. (2021, unpublished). Measuring Board Impact on Hospital Finance and Quality. | 36 hospitals, 1,500 meetings. Focus-outcome null result. Key finding to replicate and extend. |
| National Research Council Canada (NRC). (2016). The Sentiment and Emotion Lexicons. | Source of NRC EmoLex sentiment tool. |
| Auditor General of Ontario. (2008). Ministry of Health and Long-Term Care: Hospital Board Governance. | Policy context; established need for board performance benchmarking. |

---

## 9. Carry-Forward Notes

- FAC 927 has four files with yearonly placeholder dates in filenames; actual dates
  recovered in Tier 1 Step 5 from document content.
- Gap classification deferred from Phase 1 is completed in Tier 1 Step 6.
- The minutes scrape log from Phase 1 was overwritten during re-runs; minutes_index.csv
  is the authoritative record of what was collected.
- Consent agenda analysis is a potentially high-value standalone analytical thread.
  Near-universal use confirmed in T1-S2 sample (35/37 corpus-include documents).
  Track carefully from Tier 1 onward; detection must capture non-standard labels.
- FAC 977 (TERRACE BAY NORTH OF SUPERIOR HC): 72 files in index, zero downloaded.
  Robots-blocked in Phase 1. Excluded from corpus; note in coverage map.
- FACs 644 and 967 (Cornwall hospitals): 42 files each, zero Stage 1 corpus contribution.
  Requires manual file inspection before Stage 2 build.
- The in-camera false-positive rate in the Stage 1 classifier is high. The regex fix
  in T1-S3 is required before any meeting_type = in_camera counts are reported.
- The language-matching approach for Tier 3 is more powerful for hospitals with
  specific, concrete strategic plans. Result quality will vary with plan quality;
  document this per hospital in the output.
- The operational vs. ceremonial framing — whether strategic plans shape board
  deliberation or sit unused — is the highest-value finding the minutes role can produce.

---

*Work plan prepared June 2026 — HospitalIntelligenceR*
*Board Minutes Role | Phase 2 Analysis | Living document — detail added at end of each tier*
*Last updated June 13, 2026 — T1-S2 complete; Stage 2 extraction and in-camera quarantine added*
