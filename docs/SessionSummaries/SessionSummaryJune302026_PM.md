# HospitalIntelligenceR
## Session Summary — June 30, 2026
## Board Minutes — Stage 2 Planning and Analytics Architecture
*For Claude Project Knowledge Repository*

---

## Next Session — Start Here

**Current priority:** Review the output of `llm_run1_fulltext_scan.R` and use it
to finalize the SomethingElse tier decisions, particularly for the
`summary_highlights` and `agenda_prescreen` buckets.

**First action:** Paste the Section 4 console summary from `llm_run1_fulltext_scan.R`
into chat. The key table is the by-bucket signal count (n_motion, n_decision,
n_boundary by bucket). From there, identify: (a) which agenda_prescreen documents
have boundary signals (embedded minutes candidates), and (b) whether summary_highlights
documents show decision language sufficient to warrant the MinutesSummary tier.

**Watch out for:**
- The full-text scan re-OCRs 419 documents — it will take time. If it hasn't
  finished, check whether a checkpoint CSV exists at
  `roles/minutes/outputs/llm_run1_fulltext_scan.csv` and review partial results.
- Cornwall FAC 644/967 duplication: Section 2 of the scan script flags these.
  Review the output before making any count-based decisions — the summary_highlights
  bucket has ~74 Cornwall documents that likely collapse to ~37 unique.
- Do not start building `minutes_analytical_master.rds` until the full-text scan
  is reviewed and tier decisions are made.

### Carry-Forward Items

| Item | Status | Notes |
|---|---|---|
| Review `llm_run1_fulltext_scan.R` output | READY TO EXECUTE | First action next session — paste Section 4 summary table |
| Assign final tiers to SomethingElse population | IN PROGRESS | Blocked on full-text scan results |
| LH prior corpus: locate dataframe, assess format and FAC overlap | FUTURE WORKSTREAM | Immediately after Stage 2 complete |
| LH lexicon: extract 16-area term lists from archived R project | FUTURE WORKSTREAM | Required before W3 (board foci) can begin |
| Internal date extraction pass over MinutesOnly corpus | FUTURE WORKSTREAM | Pre-Step 3 before master build |
| Build `minutes_analytical_master.rds` | FUTURE WORKSTREAM | Pre-Step 4; depends on all pre-steps |
| `find_partners.R` — detect Cornwall 644/967 duplicate minutes | LOW URGENCY | Build after master; needed before corpus counts finalised |

---

## Session Objectives

This was a planning and architecture session, not a build session. The objectives
were to: (1) scope the Stage 2 SomethingElse review, separating the three
distinct problems within it; (2) decide on inclusion criteria for summary/highlights
documents; (3) design a full-text scan script to answer both questions with evidence
rather than preview-text guesses; and (4) establish the analytics architecture
(data standard, analytical master, workstream definitions) for the board minutes
analytics programme before any analytical work begins.

---

## Work Completed

### 1. SomethingElse population bucketing

Ran a keyword-based bucketing pass on the 471 SomethingElse documents using
reasoning text and text_preview from `llm_run1_results.csv`. Results:

| Bucket | n |
|---|---|
| summary_highlights | 200 |
| other_uncertain | 131 |
| mentions_minutes_other (reclassified to other_uncertain) | 45 |
| report_to_board | 45 |
| agenda_prescreen | 35 |
| agenda_other | 8 |
| governance_doc | 4 |
| bylaw | 3 |
| org_chart | ~0 |

Key finding: motion language scan against text_preview returned only 1 hit
(FAC 732), suggesting embedded-minutes packages are not common. Full-text
scan will confirm or revise this.

### 2. Point 2 decision — MinutesSummary tier

Agreed that a `MinutesSummary` tier is appropriate for Board Highlights /
Meeting Summary documents, based on the following:

- Attendance is not a current analytical requirement
- Primary uses are board foci, content mining, and decision tracking
- Summary documents record decisions, though language may be declarative
  ("the Board approved...") rather than formal motion wording
- Eligibility: W4 (topic mining), W5 (sentiment), W6A (general alignment).
  Not W3 (board foci requires full minutes structure). W6B TBD.

### 3. Point 1 decision — agenda_prescreen correction

Corrected an error in earlier planning: `agenda_prescreen` and `agenda_other`
documents are **primary Point 1 candidates**, not clean true-negatives. A
document that opens with a standalone AGENDA heading may have genuine minutes
embedded from page 2 onward. These buckets must be in the full-text scan.
Only bylaw/org_chart/governance_doc (7 documents) are excluded as definitionally
non-minutes.

### 4. Full-text scan script built

`llm_run1_fulltext_scan.R` produced. Scans 419 of 471 SomethingElse documents
(excludes 7 bylaw/org_chart/governance_doc). Three signals:

- **motion_pattern:** moved/seconded/carried/motion/resolved
- **decision_pattern:** "the Board approved/endorsed/agreed/directed/ratified"
- **boundary_pattern:** Called to order / Present: / In Attendance: / Members Present: / Directors Present:

The boundary_pattern is the key signal for agenda_prescreen — documents with
an embedded minutes section will have these labels even though the prescreen
fired on the opening page. Section 4 of the script produces a by-bucket
summary table. Script is currently running.

### 5. Analytics architecture established

**Data storage standard:** R dataframes in `.rds` format are the project
standard for all analytical data. CSV is acceptable for human-review lists,
patch logs, and collaborator exports only. This is now documented in
`CLAUDE_WORKING_PREFERENCES.md` Section 14.

**Analytical master:** `minutes_analytical_master.rds` is the single spine
for all board minutes workstreams. Schema defined (15 mandatory columns).
All workstream scripts filter from it — no script defines its own inclusion
criteria. Documented in `CLAUDE_WORKING_PREFERENCES.md` Section 15.

**Annual refresh design:** `scrape_date` and `data_source` fields in master
support annual corpus additions and potential integration of external data
sources (LH prior corpus, hospital-contributed data).

**Workplan document:** `BoardMinutes_AnalyticsWorkPlan.md` created as the
decisions-and-constraints register for the analytics programme.

**Six analytical workstreams defined:**
- W1: Corpus demographics
- W2: Word frequencies and bigrams
- W3: Board foci / riverbed analysis (requires LH lexicon)
- W4: Content and topic mining (LDA + Ollama labelling)
- W5: NRC EmoLex sentiment analysis
- W6A: General strategy alignment
- W6B: Hospital-specific strategy linkage (three-tier methodology)

**Pipeline pre-steps defined** (must be completed before any workstream):
1. Stage 2 complete
2. LH prior corpus decision
3. Internal date extraction
4. Build minutes_analytical_master.rds

---

## Key Design Decisions

| Decision | Rationale |
|---|---|
| MinutesSummary tier created for Board Highlights / Meeting Summary documents | Attendance not currently required; content-mining workstreams can use these. Keeps them accessible without polluting MinutesOnly tier. |
| agenda_prescreen / agenda_other included in full-text scan | These are Point 1 candidates, not true-negatives — a document opening with AGENDA may have embedded minutes. Error in earlier planning corrected. |
| Only bylaw / org_chart / governance_doc (7 docs) excluded from full-text scan | These describe what the document is cover-to-cover; no embedded minutes possible. |
| R `.rds` format as project data standard | Preserves column types (including character FAC), directly loadable, easier to inspect interactively than CSV. |
| `minutes_analytical_master.rds` as single analytical spine | Prevents inconsistent n-counts across workstreams and publications. All scripts filter from master, not from raw pipeline outputs. |
| LH prior corpus decision deferred to immediately after Stage 2 | Must be decided before master is built — retrofitting a second data source breaks reproducibility. |
| Internal date extraction as mandatory pre-step before master build | Scraper dates are not reliable for analytical date-based filtering. Internal dates are almost always present in genuine minutes. |

---

## Files Produced or Modified

| File | Location | Change |
|---|---|---|
| `llm_run1_fulltext_scan.R` | `E:/HospitalIntelligenceR/roles/minutes/` | Created — full-text scan of 419 SomethingElse candidates |
| `BoardMinutes_AnalyticsWorkPlan.md` | `E:/HospitalIntelligenceR/roles/minutes/docs/` | Created — decisions and constraints register for analytics programme |
| `CLAUDE_WORKING_PREFERENCES.md` | `E:/HospitalIntelligenceR/` | Modified — added Section 14 (data storage standard) and Section 15 (minutes analytical master schema) |
| `SessionSummaryJune302026_PM.md` | Upload to knowledge repository | This file |

---

## GitHub Commit Instructions

```
roles/minutes/llm_run1_fulltext_scan.R              — created
roles/minutes/docs/BoardMinutes_AnalyticsWorkPlan.md — created
CLAUDE_WORKING_PREFERENCES.md                        — modified (sections 14, 15 added)
docs/session_summaries/SessionSummaryJune302026_PM.md — created
```

**Commit message:** `docs: board minutes analytics architecture and Stage 2 full-text scan`

**Description:**
```
Stage 2 planning session. SomethingElse population bucketed (471 docs).
MinutesSummary tier decision made. Full-text scan script built for 419
SomethingElse candidates (motion, decision, boundary signals). Analytics
architecture established: data storage standard (.rds), analytical master
schema, six workstream definitions, four pipeline pre-steps. Working
preferences updated with Sections 14 and 15.
```

---

## Session End Checklist

- [ ] Confirm `llm_run1_fulltext_scan.R` has completed (or checkpoint exists)
- [ ] Save this file as `SessionSummaryJune302026_PM.md` — confirm `.md` extension
- [ ] Upload `SessionSummaryJune302026_PM.md` to Claude Project knowledge repository
- [ ] Upload updated `CLAUDE_WORKING_PREFERENCES.md` to Claude Project knowledge repository
- [ ] Upload `BoardMinutes_AnalyticsWorkPlan.md` to Claude Project knowledge repository
- [ ] Commit all four files to GitHub (see commit instructions above)
