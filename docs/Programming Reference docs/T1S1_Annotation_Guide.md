# T1-S1 Hand-Labelling Annotation Guide
## Board Minutes — Phase 2, Tier 1, Session 1

*HospitalIntelligenceR | June 2026*

---

## Purpose

This guide describes each annotation column in `t1s1_sample.xlsx`. The completed
annotations become the gold standard against which `minutes_classify.R` is validated
before it runs on the full 1,800+ file archive.

Open each PDF at the path in `local_path`, review its content, and fill in the eight
annotation columns described below. When in doubt, record your reasoning in
`analyst_notes` — the ambiguous cases are the most valuable ones.

---

## Column Definitions

---

### `doc_class`

**What it captures:** The primary document type — what this file actually is.

**Allowed values:**

| Value | Meaning |
|---|---|
| `minutes` | Board meeting minutes — a record of what was decided and discussed |
| `agenda` | Meeting agenda only — lists items to be discussed, no record of decisions |
| `mixed` | A bundled package containing minutes plus other material (reports, financials, presentations) where the minutes component is the lead document |
| `report` | A standalone report (CEO report, financial statements, committee report) with no minutes content |
| `other` | Anything that doesn't fit the above — bylaws, policies, annual reports, etc. |

**Example values:** `minutes`, `agenda`, `mixed`, `report`, `other`

**Note:** `mixed` is distinct from `minutes`. A mixed package may be corpus-includable
if the minutes portion is clearly the lead document and structurally intact — but it
requires a judgment call recorded in `analyst_notes`.

---

### `is_corpus_include`

**What it captures:** Whether this document should be included in the analytical
corpus (i.e., carried forward into Tier 2 foci and sentiment analysis).

**Allowed values:** `TRUE` or `FALSE`

**Decision rules:**
- `TRUE` if `doc_class` is `minutes` and the document has a complete or near-complete
  structural pattern (header + attendance + at least some motion/resolution content)
- `TRUE` if `doc_class` is `mixed` and the minutes component leads the document and
  is structurally intact — record the judgment in `analyst_notes`
- `FALSE` if `doc_class` is `agenda`, `report`, or `other`
- `FALSE` if the document is image-based and unreadable (flag as `needs_ocr` in
  `analyst_notes`)
- `FALSE` if the document is genuinely empty or corrupted

**Example values:** `TRUE`, `FALSE`

**Important:** A document can be `doc_class = minutes` and still be `FALSE` if it
is so thin or corrupted that no usable content can be extracted. A one-page special
meeting with a complete structural pattern is `TRUE` — length is not a disqualifier.

---

### `has_header_block`

**What it captures:** Whether the document contains a recognizable header block in
the first 200 words — the opening section that identifies the meeting.

**Allowed values:** `TRUE` or `FALSE`

**What to look for:** A header block typically contains most of the following:
- A title referencing the meeting type: *"Minutes of the Regular Meeting of the Board
  of Directors"*, *"Open Session Board Meeting"*, *"Board Meeting Minutes"*
- The meeting date
- The location or notation that the meeting was held virtually
- The meeting type (regular, special, annual, in-camera)

**Example values:** `TRUE`, `FALSE`

**Example header text:**
> *Minutes of the Open Session of the Regular Meeting of the Board of Directors of
> Napanee Lennox & Addington Hospital, held on Tuesday, January 7, 2025, in the
> Boardroom.*

---

### `has_attendance`

**What it captures:** Whether the document contains an attendance or quorum block
listing who was present at the meeting.

**Allowed values:** `TRUE` or `FALSE`

**What to look for:** A section headed by any of the following (or similar):
- *Members Present*, *Board Members Present*
- *In Attendance*, *Also Present*
- *Regrets*, *Absent* (these typically follow the present list)
- A numerical quorum statement: *"Quorum confirmed: 8 of 11 members present"*

Named individuals are common but not required — some hospitals record attendance
as a count only.

**Example values:** `TRUE`, `FALSE`

**Example attendance text:**
> *Members Present: J. Smith (Chair), M. Jones, P. Williams, R. Chen, A. Patel*
> *Regrets: T. Brown*
> *Staff: CEO, CFO, Chief of Staff*

---

### `has_motions`

**What it captures:** Whether the document contains at least one recorded motion
or resolution — evidence that decisions were made and recorded.

**Allowed values:** `TRUE` or `FALSE`

**What to look for:** Any of the following patterns:
- *"Moved by... Seconded by... Carried"* (or *Defeated*)
- *"MOTION: That the Board..."*
- *"RESOLVED THAT..."*
- *"BE IT RESOLVED..."*
- A formal consent agenda approval block: *"Motion to approve consent agenda items
  1–7 as presented. Moved: J. Smith. Seconded: M. Jones. Carried."*

A single motion is sufficient to mark `TRUE`. Agendas will typically have `FALSE`
here; minutes almost always have `TRUE`.

**Example values:** `TRUE`, `FALSE`

**Example motion text:**
> *Moved by J. Smith, seconded by P. Williams, that the minutes of the December 3,
> 2024 meeting be approved as circulated. CARRIED.*

---

### `has_consent_agenda`

**What it captures:** Whether the meeting used a consent agenda — a block of
routine items approved together in a single motion rather than discussed individually.

**Allowed values:** `TRUE` or `FALSE`

**Why this matters:** Consent agenda usage is an analytical variable in Tier 2,
not just a QA flag. Hospitals that use consent agendas concentrate their recorded
deliberation on substantive items; hospitals that do not may show different foci
patterns simply due to procedural differences. This field must be tracked from
the labelling session onward.

**What to look for:**
- An explicit section heading: *"Consent Agenda"*, *"Consent Items"*
- A motion approving multiple items together: *"Motion to approve consent items
  4.1 through 4.8 as circulated"*
- A notation: *"The following items were approved on consent:"* followed by a list

**Example values:** `TRUE`, `FALSE`

**Example consent agenda text:**
> *4.0 Consent Agenda*
> *Moved by R. Chen, seconded by A. Patel, that the Board approve consent agenda
> items 4.1 (Minutes of November 5, 2024), 4.2 (CEO Report), and 4.3 (Quality
> Report) as circulated. CARRIED.*

---

### `meeting_type`

**What it captures:** The type of board meeting recorded in this document.

**Allowed values:**

| Value | Meaning |
|---|---|
| `regular` | A scheduled regular meeting of the full board |
| `special` | A called special meeting, typically for a specific purpose |
| `annual` | Annual General Meeting (AGM) or Annual Meeting of the Corporation |
| `in_camera` | An in-camera or closed session record (rare as a standalone file) |
| `unknown` | Cannot be determined from the document |

**Example values:** `regular`, `special`, `annual`, `in_camera`, `unknown`

**Note:** Special meetings are often short (sometimes one page) but are valid
corpus documents if structurally intact. Do not exclude on length alone.

---

### `analyst_notes`

**What it captures:** Free-text observations that do not fit the structured columns.
This is the most important column for ambiguous cases.

**When to use it:**
- Document is `doc_class = mixed` — describe what the non-minutes content is and
  how much of the file it occupies (e.g., *"Minutes occupy pp. 1–4; CEO report
  pp. 5–18; financials pp. 19–32"*)
- Document is image-based and unreadable — note `needs_ocr`
- File appears to be a duplicate of another file in the archive — note the suspected
  duplicate filename
- Unusual structural patterns that the classifier will need to handle — describe them
- Consent agenda present but in an unusual format — describe it
- Meeting date in document differs from the filename date — note both
- Any observation that would help write a more accurate regex pattern

**Example values:**
- `"Mixed package — minutes pp. 1–3, CEO report pp. 4–12. Minutes structurally complete; corpus_include TRUE on minutes portion only."`
- `"Image-based PDF — zero readable text. needs_ocr."`
- `"No formal motion language used — decisions recorded as 'The Board agreed that...'. has_motions marked TRUE on this basis."`
- `"Consent agenda present but labelled 'Items for Approval' rather than 'Consent Agenda'."`
- `"Special meeting, one page. Header and quorum statement intact. No motions — discussion only, no votes taken."`

---

## Quick Reference

| Column | Type | Key question |
|---|---|---|
| `doc_class` | Category | What kind of document is this? |
| `is_corpus_include` | TRUE/FALSE | Does it belong in the analytical corpus? |
| `has_header_block` | TRUE/FALSE | Is there a recognizable meeting header in the first 200 words? |
| `has_attendance` | TRUE/FALSE | Is there an attendance or quorum block? |
| `has_motions` | TRUE/FALSE | Is there at least one recorded motion or resolution? |
| `has_consent_agenda` | TRUE/FALSE | Was a consent agenda used? |
| `meeting_type` | Category | Regular / Special / Annual / In-camera / Unknown |
| `analyst_notes` | Free text | Anything ambiguous, unusual, or worth flagging |

---

*Completed annotations feed directly into the regex pattern design for `minutes_classify.R`.*
*The ambiguous cases are the most valuable — record your reasoning, not just the decision.*
