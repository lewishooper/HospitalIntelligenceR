# Strategy Role — Future Plans & Known Issues
*HospitalIntelligenceR | docs/strategy_role_future_plans.md*
*Created April 9, 2026 | For the next major strategy role iteration (~2027)*

---

## Purpose

This document captures issues, limitations, and improvement ideas identified
during the Phase 1 and Phase 2 builds of the strategy role. None of these
items require immediate action — the analytical phase is underway and stability
is more important than improvement at this stage. These are inputs for the next
major iteration of the strategy role.

This document should be reviewed and updated at the start of any future
strategy role rebuild.

---

## 1. Research Strategic Plan Contamination

### Problem
The Phase 1 crawler uses keyword scoring to identify strategic plan documents.
"Research strategic plan" scores similarly to "hospital strategic plan," causing
the crawler to capture affiliated research institute plans instead of the
hospital's own plan.

Confirmed affected hospitals (discovered April 2026 audit):
- FAC 976 — Sinai Health System (Lunenfeld-Tanenbaum Research Institute plan captured)
- FAC 714 — St. Joseph's Health Care London (Lawson Research plan captured)
- FAC 961 — University of Ottawa Heart Institute (research document captured)

This is primarily a risk for Teaching hospitals and hospitals with named research
affiliates. Community and Small hospitals are unlikely to have affiliated research
institutes publishing standalone strategic plans.

### Candidate Mitigations
- Add negative scoring in the crawler for documents where "research" appears as
  a leading modifier in the document title or filename.
- Add a Teaching hospital flag in Phase 1 that triggers mandatory human review of
  the selected document before it is accepted.
- Introduce a lightweight document-type classification step in Phase 1: after
  download, send the first page to the API with a binary prompt ("Is this a
  hospital operational strategic plan or a research/academic plan?") and reject
  research plans automatically.

### Priority
Medium. Affects a small number of hospitals but they tend to be high-profile
Teaching hospitals where accurate extraction is most important for the analysis.

---

## 2. Summary Document vs. Full Plan

### Problem
Some hospitals publish both a summary ("highlights") version and a full strategic
plan document. The crawler cannot distinguish these without content inspection.
In the April 2026 audit, FAC 941 had a summary document; the full plan was
available and preferred.

The full plan is generally preferred because:
- It contains more strategic directions and richer direction descriptions.
- It is more likely to include plan period dates, mission, and vision statements.
- Summary documents may omit themes present in the full plan.

### Candidate Mitigations
- Flag PDFs below a page threshold (e.g., < 5 pages) for review before accepting.
- Add filename scoring: documents with "summary," "highlights," "at-a-glance," or
  "overview" in the filename or title should score lower than full plan documents.
- Where both exist on the same page, prefer the longer document.

### Priority
Low. Affects a small number of hospitals and the analytical impact is modest —
summary documents typically capture the main themes even if direction count is lower.

---

## 3. Duplicate and Orphan Folders

### Problem
Manual operations outside the pipeline can create folders on disk that do not
correspond to any registry entry. In the April 2026 audit, a folder labelled `954`
was found on disk; FAC 954 does not exist in the YAML registry. The folder was
deleted manually.

This risk will increase as more manual operations are performed (e.g., re-downloads,
corrections, new plan acquisitions).

### Candidate Mitigations
- A short audit script that lists all folders in `roles/strategy/outputs/pdfs/`,
  extracts the FAC prefix from each folder name, and flags any FAC that is not
  present in the registry.
- Run this audit script at the start of each Phase 2 batch run or as a standalone
  periodic check.

### Priority
Low. Easy to implement; worth building before the next Phase 1 refresh.

---

## 4. Image PDF Handling

### Current State
Image-based PDFs are handled via the `force_image_mode` YAML flag and a
PDF-to-PNG rendering pipeline within `phase2_extract.R`. This works well for
PDFs where every page is an image.

### Known Limitations
- Pages with mixed content (some text, some image) may still produce thin
  extractions if the text portion clears the `is_text_usable()` threshold.
- Manual capture workarounds (Windows Clip/transpose) produce inconsistent
  text quality and require human judgment to assess usability.
- The image-mode API call is significantly more expensive than text mode.

### Candidate Improvements
- A lower text-usability threshold for PDFs known to have mixed content.
- A per-hospital `image_page_range` YAML field to restrict image-mode to known
  image pages while using text mode for text pages.
- A quality check: if `phase2_quality` returns `thin` for a PDF that has been
  previously attempted, automatically trigger image-mode on the next run without
  requiring a `force_image_mode` flag.

### Priority
Low. Current tooling handles the majority of cases. The remaining edge cases
are addressable by the existing manual triage process.

---

## 5. Duplicate Hospital Detection

### Problem
The registry does not currently have a formal mechanism for flagging when two
FACs may refer to the same physical hospital or when a hospital has reorganized
and one of its legacy FAC entries is now redundant. In the April 2026 audit,
the spurious FAC 954 folder was found on disk — while this was an artifact of
a manual error rather than a true registry duplicate, it illustrates the broader
risk.

### Candidate Mitigations
- Add a `status: inactive` or `status: merged` flag to the registry for FACs
  that are no longer active hospitals.
- A detection heuristic: flag pairs of FACs where `base_url` values match — this
  would catch cases where one physical hospital has two FAC entries.

### Priority
Low. Affects registry integrity more than analytical output in the short term.

---

## 6. Document Source Preference Hierarchy

### Current State
The pipeline accepts the first high-scoring document it finds. There is no
explicit preference hierarchy beyond the crawler's scoring function.

### Proposed Hierarchy (for future implementation)
When multiple candidate documents are found for a hospital, the pipeline should
prefer them in this order:

1. Full strategic plan PDF from the hospital's own website
2. Full strategic plan PDF from an affiliated organization's website
3. Full strategic plan HTML page (scraped as text)
4. Summary/highlights document when full plan is unavailable
5. Email-supplied document (when website document is inaccessible)

This hierarchy is currently applied informally during manual triage. Formalizing
it in the crawler scoring logic would reduce the need for human review.

### Priority
Medium. Most useful if a systematic Phase 1 refresh is planned.

---

## 7. Registry Housekeeping Fields

### Observation
Some YAML fields have accumulated that are informally used but not formally
defined. Examples: `strategy_url` (set for some hospitals but not all),
`override_notes` (used in some entries), `review_date` (set for one hospital
but not standardized).

### Recommendation
Before the next major strategy role iteration, standardize all YAML field
definitions in `docs/yaml_registry_reference.md`. Decide which optional fields
are officially supported and which are deprecated.

### Priority
Low. Covered by the YAML registry reference document planned for the foundational
documents role phase.

---


## Review Schedule

This document should be reviewed:
- Before beginning any Phase 1 refresh run
- At the start of the next major strategy role build iteration
- When a new extraction failure pattern emerges that does not fit existing categories

*Last updated: April 9, 2026*

This is where I am going to put items that I have discovered after this document was written
These will need to be formated etc at some point, but for now its being kept simple


Capturing names. The system is designed to capture names from inside the pdf/strategic plan
however in some cases thats not possible so it should default to capturing the names of the folders

we should also capture the name of the plan if possible

