# Board Meeting Minutes Role — Work Plan
## HospitalIntelligenceR

*Prepared May 2026 | For Monday/Tuesday development sessions*

---

## 1. Role Overview

The minutes role downloads and archives Ontario hospital board meeting minutes as PDFs, then extracts structured content for analysis. It is the highest-complexity extraction role in the project and has been deliberately sequenced last. Core infrastructure — fetcher.R, crawler.R, claude_api.R, registry.R, logger.R — is fully built and shared across all roles.

The role has two distinct phases, each with its own completion milestone:

| Phase | Goal | Claude API cost | Completion signal |
|---|---|---|---|
| Phase 1 | Download and archive all available minutes PDFs | None | Archive complete; registry updated for all reachable hospitals |
| Phase 2 | Extract structured content from archived PDFs | Moderate | minutes_master.csv produced; analysis scripts running |

Phase 1 can begin immediately. Phase 2 follows once Phase 1 achieves reasonable coverage.

---

## 2. What the Role Produces

### Phase 1 outputs

```
roles/minutes/outputs/pdfs/<FAC>_<HOSPITAL_SLUG>/
    YYYY-MM-DD_board_minutes.pdf       (one file per meeting)
    YYYY-MM-DD_board_minutes_v2.pdf    (if duplicates detected)
roles/minutes/outputs/minutes_index.csv  (one row per document)
```

`minutes_index.csv` columns: `fac`, `hospital_name`, `doc_date`, `doc_year`, `filename`, `source_url`, `download_date`, `file_size_kb`, `status`

YAML registry updates per hospital (minutes block):

```yaml
minutes:
  last_run_date: '2026-06-02'
  status: complete
  documents_downloaded: 18
  earliest_document_date: '2022-01-01'
  latest_document_date: '2026-04-15'
  notes: ''
```

### Phase 2 outputs

```
roles/minutes/outputs/minutes_master.csv
roles/minutes/outputs/minutes_topics.csv
roles/minutes/outputs/minutes_motions.csv
```

`minutes_master.csv`: one row per meeting, structured fields (date, hospital, meeting type, attendees present, quorum met, agenda item count, flagged topics).

`minutes_topics.csv`: one row per identified topic or agenda item, with theme classification (WRK, PAT, FIN, etc. aligned with strategy taxonomy).

`minutes_motions.csv`: one row per motion or resolution, with outcome (carried / defeated / tabled).

---

## 3. Files to Build

### Phase 1 — Archive

| File | Location | Purpose |
|---|---|---|
| `minutes_config.R` | `roles/minutes/` | Role config: keywords, output paths, rate limit, depth |
| `minutes_discover.R` | `roles/minutes/scripts/` | Find minutes page URL per hospital; updates registry `minutes_url` |
| `minutes_scrape.R` | `roles/minutes/scripts/` | Fetch PDF links from minutes page; download and name each file |
| `minutes_validate.R` | `roles/minutes/scripts/` | Coverage report; flag failed, robots-blocked, and zero-document hospitals |

### Phase 2 — Extraction

| File | Location | Purpose |
|---|---|---|
| `minutes_extract.R` | `roles/minutes/scripts/` | pdftools text extraction; pre-processing; Claude API call |
| `minutes_prompt.txt` | `roles/minutes/prompts/` | Extraction prompt for meeting content |
| `minutes_classify.R` | `roles/minutes/scripts/` | Strategy theme tagging on extracted topics |
| `minutes_build.R` | `roles/minutes/scripts/` | Assemble minutes_master.csv and topic/motion CSVs |

---

## 4. Registry Fields Required

Add to the YAML status block for each hospital (minutes section):

```yaml
minutes_url: ''           # Direct URL to minutes listing page (populated by minutes_discover.R)
minutes_status: pending   # pending / complete / robots_blocked / zero_docs / manual_override
last_run_date: ''
documents_downloaded: 0
earliest_document_date: ''
latest_document_date: ''
notes: ''
```

`minutes_url` is the key field enabling the scraper. Discovery populates it; subsequent runs use it directly.

---

## 5. Phase 1 — Build Sequence

### Session 1 — Reconnaissance and config

Before writing any code, manually inspect 15-20 hospital minutes pages across the four type groups. Specifically check:

- How hospitals label and organize their minutes (board minutes, public board meeting minutes, governance documents, meeting archives)
- Whether minutes are listed as HTML links on a page or embedded in a document library
- Whether links go directly to PDFs or to intermediate landing pages
- Whether hospitals publish full minutes, highlights only, or in-camera/public splits
- Depth of historical backlog (some sites keep 12 months, others keep 5+ years)

Document findings as a spot-check table before writing `minutes_config.R`. This reconnaissance shapes every design decision downstream.

Then write `minutes_config.R`. Key fields:

```r
MINUTES_CONFIG <- list(
  role = "minutes",
  output_dir = "roles/minutes/outputs",
  pdf_dir = "roles/minutes/outputs/pdfs",
  index_file = "roles/minutes/outputs/minutes_index.csv",
  rate_limit_seconds = 3,          # Slightly higher than strategy (minutes pages are larger)
  max_depth = 3,                   # Allow one redirect hop beyond the minutes listing page
  max_pdfs_per_hospital = 60,      # Hard cap; flag if exceeded
  keywords = c(
    "board minutes", "board meeting minutes", "minutes of", "meeting minutes",
    "public board", "governance", "board of directors", "open session"
  ),
  skip_keywords = c(
    "agenda", "notice", "presentation", "slide", "report", "financial statement"
  ),
  filename_pattern = "^\\d{4}[-_]\\d{2}[-_]\\d{2}",  # Prefer datestamped files
  robots_respect = TRUE
)
```

### Session 2 — Discovery script

Build `minutes_discover.R`. This script takes the `base_url` from the registry and crawls to find the minutes listing page. The listing page URL is saved back to the registry as `minutes_url`.

The crawler must handle:
- Direct links from the governance or board page (most common)
- Sites where minutes are under "About > Board of Directors > Meeting Minutes" (two or three hops)
- Document library widgets (some hospitals use SharePoint or similar; these require different link extraction)
- Missing minutes pages — hospital either doesn't publish or uses a non-discoverable structure

Output: YAML updated with `minutes_url` for all reachable hospitals. Log failures and unresolved cases.

The strategy role's crawler.R is the starting point. The minutes discovery is shallower (fewer hops) but needs better keyword matching to avoid false positives (e.g. agenda PDFs, annual reports, financial statements).

### Session 3 — Downloader script

Build `minutes_scrape.R`. Starting from `minutes_url` in the registry, this script:

1. Fetches the listing page
2. Extracts all PDF links matching the minutes pattern
3. Filters out skip_keywords matches
4. Downloads each PDF with rate limiting
5. Names files using extracted or inferred dates (`YYYY-MM-DD_board_minutes.pdf`)
6. Writes one row to `minutes_index.csv` per downloaded document
7. Updates the YAML status block

Filename date inference is the hardest part. Hospitals name their files inconsistently. Attempt in order: (a) date in URL, (b) date in link text, (c) date in PDF filename, (d) leave as `UNKNOWN_DATE_nnn.pdf` and flag for manual review.

Robots compliance is enforced via the existing `fetcher.R` infrastructure. Hospitals that block robots get status `robots_blocked` in the YAML and are deferred.

### Session 4 — Test run and debug

Run `minutes_discover.R` and `minutes_scrape.R` on a test cohort of 20 hospitals across all four type groups (5 per type). Review results:

- Discovery success rate (expected: 60-75% automated; remainder require manual URL provision)
- Download count distribution (flag hospitals with zero PDFs despite successful discovery)
- Filename quality (how many required manual date inference)
- Any robots blocks or HTTP errors

Document issues as a punch list before the full cohort run.

### Session 5 — Full cohort Phase 1 run

Run on all 134 active hospitals. Track:

- Total documents downloaded
- Robots-blocked hospitals (these go to a deferred list; consider email outreach later)
- Zero-document hospitals (distinguish: minutes page exists but empty vs. no page found)
- Manual URL provision required (add `minutes_url` directly to YAML for known cases)

Target completion: Phase 1 archive for 80+ hospitals (approximately 60% of cohort without manual effort). This is a realistic first-pass target given the variation in hospital web infrastructure.

### Session 6 — Validation and gap-fill

Run `minutes_validate.R`. Produce:

- `minutes_coverage.csv`: one row per hospital showing status, document count, date range
- Prioritized list of gaps: hospitals with no minutes vs. hospitals needing manual URL provision

For the manual URL provision list: spend 30-45 minutes per session doing targeted lookups for the highest-value hospitals (Teaching hospitals first, then Community Large). Add confirmed URLs directly to the YAML registry.

---

## 6. Phase 2 — Build Sequence

Phase 2 begins once Phase 1 has reached approximately 80 hospitals. Phase 1 and Phase 2 can overlap toward the end of Phase 1 coverage expansion.

### Prompt design — the central challenge

Board minutes are the most unstructured text in the project. Unlike strategic plans (which have predictable section headers and direction statements), minutes vary enormously across hospitals:

- Formal verbatim minutes vs. summary-style action minutes
- Consistent agenda structure vs. ad hoc organization
- Varying terminology for board actions (moved / seconded / carried vs. resolved that / motion passed)
- In-camera items redacted to varying degrees
- Chair's report, CEO's report, committee reports, financial reports, and consent agendas all mixed in different orders

The extraction prompt must handle this variation. Design the prompt to extract:

- Meeting date, type (regular / special / annual), and quorum status
- Attendees (names and roles if listed; total count if not)
- Agenda items as a structured list with brief topic descriptions
- Motions and resolutions: mover, seconder (if listed), subject, outcome
- Flagged content: any explicit mention of strategic plan, strategic priorities, or strategy-aligned themes

The final field (flagged content) is the analytical payload — it enables the "operational vs. ceremonial" test on whether strategic priorities appear in board deliberations.

Prompt engineering will require 2-3 sessions of iteration. Start with 10-15 varied documents across hospital types and iterate until output quality is stable.

### Session 7 — Text extraction pipeline

Build `minutes_extract.R`. For each PDF in the archive:

1. Extract text using `pdftools::pdf_text()`
2. Concatenate pages with section markers
3. Pre-process: strip headers/footers, normalize whitespace, handle encoding issues
4. Pass to Claude API using the extraction prompt
5. Parse JSON response (strip markdown fences before `fromJSON()`)
6. Write structured output to staging CSV

Batch processing pattern from `extraction_workflow_v3_no_batching.R` applies here. Each hospital's minutes are processed sequentially. Session cost estimate: approximately $0.50-1.50 per hospital depending on volume of minutes (rough, based on strategy role costs).

### Session 8 — Prompt iteration and quality review

Run extraction on the 20-hospital test cohort. Review outputs for:

- Agenda item extraction quality (are items captured at the right level of granularity?)
- Motion capture accuracy (false positives on procedural motions; missed substantive resolutions)
- Strategic theme flagging precision (too broad catches everything; too narrow misses real references)
- In-camera item handling (redacted sections should produce a flag, not an error)

Revise prompt based on findings. Two or three iteration cycles are expected before output quality is acceptable for the full cohort.

### Session 9 — Full cohort Phase 2 extraction

Run `minutes_extract.R` on all Phase 1 hospitals. Monitor cost. Build `minutes_master.csv`, `minutes_topics.csv`, and `minutes_motions.csv` using `minutes_build.R`.

### Session 10 onward — Analysis scripts

Once the master CSV is available, analysis follows the same pattern as strategy analytics:

**Immediate questions:**
- Do hospitals that explicitly name strategic themes in board minutes have different performance outcomes than those that don't? (Joins to strategy_classified.csv and hit_master.csv)
- Which themes appear most frequently in board deliberations across all hospitals?
- Is there a measurable lag between strategic plan adoption and first appearance of themes in board minutes?

**The operational vs. ceremonial test:**
The core analytical question. Hospitals are scored on whether their board minutes contain explicit references to their stated strategic priorities. A hospital that lists WRK as a strategic direction but whose minutes contain no workforce references over two years is displaying ceremonial behavior; one whose minutes consistently flag it is displaying operational behavior.

This analysis requires joining `minutes_topics.csv` to `strategy_classified.csv` by FAC, then computing a concordance score per hospital per theme.

Analysis scripts will be designed once the data structure is confirmed.

---

## 7. Timeline

Assuming two working sessions per week (Monday morning + Tuesday morning, approximately 3 hours each = 6 productive hours per week on this role):

| Milestone | Target | Sessions required |
|---|---|---|
| Reconnaissance complete; config written | Week 1 | 1 |
| Discovery script built and tested | Week 2 | 2 |
| Downloader built and tested | Week 3 | 1 |
| Test cohort run complete | Week 4 | 1 |
| Full cohort Phase 1 run | Week 5 | 1-2 |
| Validation and manual gap-fill ongoing | Weeks 6-8 | 3 |
| Phase 2 prompt design and iteration | Weeks 7-9 | 3-4 |
| Full cohort Phase 2 extraction | Weeks 10-12 | 2-3 |
| Analysis scripts and first findings | Weeks 12-16 | ongoing |

**Phase 1 archive milestone: approximately 6-8 weeks from start**
**First analytical output: approximately 12-14 weeks from start**

These estimates assume an 80% automation success rate in Phase 1. If the manual gap-fill requirement is larger than expected, Phase 1 extends. Phase 2 is not blocked by 100% Phase 1 coverage — analysis can begin once 60-70 hospitals are in the archive.

---

## 8. Known Risks and Mitigations

| Risk | Likelihood | Mitigation |
|---|---|---|
| Robots-blocked hospitals | Moderate (15-25 hospitals estimated) | Defer; consider email outreach for high-priority hospitals; proceed with compliant subset |
| Document library sites (SharePoint, etc.) | Moderate | Requires custom extractor beyond standard rvest parsing; handle case by case |
| In-camera vs. public minutes confusion | Low-moderate | Extraction prompt explicitly flags in-camera markers; do not attempt to extract redacted content |
| Inconsistent date formats in filenames | High | Multiple parsing strategies in filename inference; fallback to UNKNOWN flag and manual review |
| Phase 2 prompt instability | Moderate | Budget 3 iteration sessions before committing to full cohort run |
| High Phase 2 API cost | Low-moderate | Cost cap enforced in config; run estimate before full cohort; adjust batch size if needed |

---

## 9. Registry YAML — Minutes Block Template

Add to each hospital's registry entry at session start:

```yaml
minutes:
  minutes_url: ''
  status: pending
  last_run_date: ''
  documents_downloaded: 0
  earliest_document_date: ''
  latest_document_date: ''
  robots_blocked: false
  notes: ''
```

Only `registry.R` writes this block. Scripts call `registry.R` functions to update status; they do not write YAML directly.

---

## 10. Carry-Forward Notes

- The `minutes_url` field does not yet exist in `hospital_registry.yaml`. It must be added in the first session before any discovery code is written.
- Phase 2 extraction is the most analytically ambitious task in the project. The "operational vs. ceremonial" finding, if confirmed, is likely the highest-value output HospitalIntelligenceR will produce.
- Robots-blocked hospitals are not failures — they are a dataset in themselves. A registry of which hospitals restrict automated access to their governance documents is itself a governance observation worth noting.
- The minutes role produces no figures for the initial analytical pass. Tables and narrative are the primary outputs; visualization comes after the concordance analysis is designed.

---

*Work plan prepared May 2026 — HospitalIntelligenceR*
*Board Minutes Role | Phase 1 + Phase 2 build sequence*
