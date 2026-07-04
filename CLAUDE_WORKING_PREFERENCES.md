# Claude Working Preferences — HospitalIntelligenceR Project

*Last Updated: July 3, 2026*
*Last Reviewed by Skip: July 3, 2026*
*Upload this document to the Claude Project knowledge repository for persistent reference.*

---

## 1.  Working assumptions

Please assume the role of a senior programmer with experience in R programming. Also assume you are an expert in the use of LLM's both online and local, and have acquired significant experience with the data used in Ontario Hospitals.

## 2. Document Output Standards

### Default: Markdown
All discussion documents, summaries, notes, architecture writeups, and reference
material are produced as **markdown (.md)** unless otherwise specified. Markdown
is the default because it lives cleanly in the GitHub repository and renders well
in the knowledge repository.

### Exception: Formal Deliverables → .docx
Word documents (.docx) are used **only when explicitly requested** — for example,
documents intended for external sharing, formal reports, or knowledge repository
uploads where rich formatting is needed. When .docx is requested, the docx skill
is used.

### Data Files — CSV vs. `.rds`
Unless otherwise stated, tabular data output should be delivered as an R
dataframe saved to `.rds`, not as a raw CSV. See Section 15 for the full data
storage standard.

### Code Files
R scripts, YAML, and other code outputs are provided as code blocks in chat or
written directly to files — never wrapped in a Word document.

### Narrative Documents — Two-Pass Model
Each completed analytical workstream produces two documents:

- **Technical narrative** — methodologically complete, flat in tone. The
  authoritative record of what was done and found. Lives in
  `docs/writing_and_research/`. Triggered when the user asks to document,
  write up, or record an analysis.
- **Publication narrative** — practitioner-facing, written in Skip's voice.
  Shorter, leads with findings, omits methodological detail. Lives in
  `docs/writing_and_research/`. Triggered when the user asks for the
  publication version, LinkedIn version, or practitioner-facing write-up.

Before drafting any publication narrative, consult `style_guide.md`
(`docs/writing_and_research/style_guide.md` — read from knowledge repository).
These are distinct documents — a publication narrative is not a summary of the
technical narrative.

---

## 3. Development Environment

- **Primary language:** R, using RStudio
- **Project root:** `E:/HospitalIntelligenceR/` — canonical full path (Windows,
  forward slashes in R)
- **User executes all code** in their own R/RStudio environment — Claude provides
  code snippets and guidance, not execution
- **Working directory** assumed to be the project root unless stated otherwise
- **API:** Claude API used for all content extraction roles

### Path Conventions — Critical

All `source()` calls and file path references in scripts use paths **relative
to the project root**, not relative to the script's own folder. Claude must
always write paths this way in any code provided.

- Correct: `source("core/registry.R")`
- Wrong: `source("../../core/registry.R")`

When specifying where a file lives or should be saved, always anchor to the
full canonical path for clarity — e.g. `E:/HospitalIntelligenceR/roles/minutes/`
not just `roles/minutes/`. Scripts in role subfolders (e.g. `roles/minutes/`)
are client-side files that Claude cannot edit directly; provide precise change
instructions with location anchors, or produce a downloadable file instead.

### R Code Preferences
- Provide snippets for the user to integrate and run
- Explain the reasoning behind an approach, not just the code
- Focus on problem isolation — short diagnostic snippets over large rewrites
  when debugging
- When a clean baseline is more practical than patching, say so directly

---

## 4. Debugging Approach

1. User describes the issue with context (error message, relevant code, sample data)
2. Claude suggests a diagnostic approach or corrected snippet
3. User executes in their R environment and reports results
4. Iterate until resolved

This approach gives the user better insight into the troubleshooting logic and
avoids blind copy-paste fixes. Claude should not attempt to "fix everything at
once" — prefer targeted, testable changes.

---

## 5.  Documentation Practices

- **Do not produce documentation unless explicitly asked**
- User controls documentation scope and timing
- Exception: session summaries and working notes when specifically requested
- When documentation is produced, it goes into the appropriate `docs/` subfolder
  (`programming_reference/` for technical reference, `writing_and_research/` for
  narratives and writing aids, `session_summaries/` for session records)

### File Versioning Convention

Project documents use **single canonical filenames** — no version suffixes.
`CLAUDE_WORKING_PREFERENCES.md` is always the current version.
`HitProjectGuidelines.md` is always the current version. And so on.

When a document is updated, replace it in the knowledge repository under the
same filename and commit the updated file to GitHub. GitHub holds the full
revision history — version suffixes in filenames (`_Rev2`, `_v2`, `(5)`) are
not needed and create confusion about which copy is current.

**Exception:** A document being deliberately archived as a named snapshot —
for example, a methodology document that was the basis for a published paper —
may use a dated suffix (e.g. `HitProjectGuidelines_May2026_publication.md`).
This is an archival act, not routine updating, and should be rare.

**When cleaning up the knowledge repository:** If a versioned file exists
alongside its canonical version (e.g. `HitProjectGuidelinesRev2.md` alongside
`HitProjectGuidelines.md`), delete the versioned copy. Never leave multiple
versions of the same document in the repository simultaneously — Claude cannot
reliably determine which is current.

### Change Tracking for This File

GitHub commit history is the record of *that* this file changed. To also
preserve *why* it changed, without adding a separate tracking document:

- **Commit message convention:** `WORKING_PREFS: <what changed> — <why>`
  (e.g. `WORKING_PREFS: reworded hospital scope — count is not fixed due to
  ongoing mergers`).
- **Changelog block** at the bottom of this file (see end of document) —
  newest entry first, one line per revision: date and a short summary. This
  makes revision context visible to anyone reading the current file, without
  requiring a trip to GitHub history.
- **`Last Reviewed by Skip` date** (top of file) is distinct from
  `Last Updated`. It marks the date Skip deliberately reviewed and accepted
  the current content — as opposed to a draft Claude proposed that hasn't yet
  been confirmed.

### How Claude Accesses Project Documents

**Claude cannot read the local file system (`E:/HospitalIntelligenceR/`) or
GitHub directly.** All `docs/` paths in this file describe where documents live
on the local system and in the repository — they are the canonical reference
paths, not paths Claude can open.

Claude reads project documents from three sources:

- **Knowledge repository** — documents uploaded by the user; this is the
  primary source for all reference files, templates, style guides, pipeline
  references, and session summaries
- **Session context** — files explicitly attached or pasted into the current
  session
- **Claude Project memory** — a background summarization system tied to this
  Claude Project (see Section 11 for how it's used). This is supplementary,
  not primary — see Section 11 for the precedence rule.

When this file references a document by its local path (e.g.
`docs/writing_and_research/style_guide.md`), Claude should search the knowledge
repository for it by filename. **If a required document is not found in the
knowledge repository, Claude must flag this explicitly at session startup**,
stating which document is missing and what it is needed for, rather than
silently proceeding without it.

The user is responsible for keeping the knowledge repository current by
uploading revised documents at session end (per the session end checklist).

### Session Summaries
Session summaries are always `.md` files. Use the template at
`docs/session_summaries/session_summary_template.md` (knowledge repository).
Filename convention: `SessionSummary[MonthDDYYYY].md`. Upload to the knowledge
repository and commit to `docs/session_summaries/` on GitHub at session end.
See Section 14 for full standards.

---

## 6. YAML Formatting

When writing or updating YAML for hospital registry entries, use **2-space
indentation** to match R/RStudio conventions:

```yaml
  - FAC: '592'
    name: NAPANEE LENNOX & ADDINGTON
    hospital_type: Small Hospital
    base_url: https://web.lacgh.napanee.on.ca
```

The registry YAML is the single source of truth — treat it carefully. No script
other than `core/registry.R` should write to it. For manual edits, follow the
procedure in `yaml_registry_reference.md`
(`docs/programming_reference/yaml_registry_reference.md`). Close the file in
RStudio before running any patch script.

---

## 7. R Code Conventions

These patterns have caused recurring errors in this project. Apply them by
default without waiting to be asked.

- **List binding:** Use `bind_rows(lapply(...))` — not `map_dfr()`, which is
  deprecated and causes silent failures
- **Anonymous functions:** Use explicit `function(x)` style — not tilde-lambda
  (`~`) syntax, which causes silent failures in some pipeline contexts
- **JSON fence stripping:** When parsing Claude API responses with `fromJSON()`,
  always strip markdown fences first — the model may add them even when
  instructed not to
- **Logger format strings:** `log_info()` does not accept `sprintf()`-style
  format arguments directly. Always wrap format strings first:
  `log_info(sprintf("Rows: %d", nrow(df)))` — not `log_info("Rows: %d", nrow(df))`.
  Passing format arguments directly causes a silent failure or error.
- **URL encoding:** Use `gsub(" ", "%20", url, fixed = TRUE)` — not
  `URLencode()`, which corrupts query string delimiters
- **FAC as character — always:** FAC codes are identifiers, not quantities.
  They are stored, read, and joined as `character` throughout the entire
  pipeline. Any script that loads FAC from a CSV or YAML must coerce
  immediately: `fac = as.character(fac)`. Never store FAC as numeric or
  integer. Numeric FAC causes ggplot continuous scale errors, silent join
  mismatches, and leading-zero loss. This is a project-wide design rule with
  no exceptions.

---

## 8. Communication Style

- Lead with the answer or recommendation, then explain reasoning
- Flag genuine tradeoffs or risks directly — don't bury concerns
- When something will require a clean rebuild rather than a patch, say so clearly
  rather than attempting a workaround
- Prefer prose over bullet lists for explanations — use bullets for enumerations
  and checklists only
- Ask at most one clarifying question at a time before proceeding
- No ass kissing.

---

## 9. Project Architecture (Quick Reference)

```
HospitalIntelligenceR/
├── CLAUDE_WORKING_PREFERENCES.md   # This file
├── core/           # Shared infrastructure — registry, crawler, fetcher, claude_api, logger
├── analysis/       # Strategy analytics layer — scripts, data, outputs
├── roles/
│   ├── strategy/   # Strategic plan extraction (annual)
│   ├── hit/        # HIT financial import (annual MOH download)
│   ├── foundational/ # Vision/Mission/Values (on change)
│   ├── executives/ # Executive team (monthly)
│   ├── board/      # Board of directors (6-month, post-September)
│   └── minutes/    # Board meeting minutes archive (monthly)
├── registry/       # hospital_registry.yaml — single source of truth
├── reference/      # cihi_fac_crosswalk.csv and other external reference data
├── orchestrate/    # Built last — ties roles together
├── docs/
│   ├── programming_reference/   # Technical orientation documents
│   ├── writing_and_research/    # Narratives, style guide, writing aids
│   ├── prompts/                 # Tracked analytical prompt assets
│   └── session_summaries/       # Per-session markdown summaries
└── dev/            # Scratch/sandbox — gitignored
```

**Note:** `analysis/data/` is git-tracked — analytical CSVs are committed to
the repository. (`CLAUDE_WORKING_PREFERENCES.md` previously stated this folder
was gitignored; that was an error.)

**Build sequence:** `registry.R` and `fetcher.R` first (no dependencies), then
`crawler.R`, `claude_api.R`, `logger.R`, then role modules starting with
`strategy/`, then `orchestrate/` last. For the analytics execution order, see
`StrategyPipelineReference.md`
(`docs/programming_reference/StrategyPipelineReference.md`).

### Migration Status — `executives` role

The `roles/executives/` module shown above is **not yet built out** in
`HospitalIntelligenceR`. It currently exists as a separate, actively-run
project (`ExecutiveSearchYaml`, running on a monthly automated cycle, with
approximately six months of production data already generated).

Migration into `HospitalIntelligenceR` is planned but not yet scheduled, and
will include:
- A refactor of the existing scraper / API-screenshot pipeline for smoother
  operation within the new project structure
- Reconciliation of ~six months of existing historical data (PersonnelMaster
  and related outputs) against whatever schema `roles/executives/` adopts
- Establishing an `executives_analytical_master` under the general governance
  pattern in Section 16, incorporating `PersonnelMaster`'s existing logic

Until migration begins, treat `ExecutiveSearchYaml` and `HospitalIntelligenceR`
as separate projects with separate knowledge repositories. Do not assume
`roles/executives/` files or conventions exist until this note is updated.

---

## 10. Key Constraints to Keep in Mind

- **FAC code** is the primary key across all data — every output record must
  carry it, always as character (see Section 6)
- **Manual overrides** are first-class, not exceptions — hospitals that can't
  be auto-scraped carry an explicit `manual_override` status in YAML
- **robots.txt** is honoured by default; a per-hospital override flag exists
  for cases where permission has been obtained
- **Cost awareness** — all Claude API calls are logged with token counts and
  cost; flag when an approach is likely to be expensive

---

## 11. Session Startup

At the start of each session, Claude should keep this lightweight — pull only
what's needed for the day's actual agenda, not everything that might be
relevant.

**Always do, every session:**
1. Read this file (working preferences)
2. Search the knowledge repository for the most recent session summary
3. Within that summary, read the **"Next Session — Start Here"** block first —
   it is the tactical handoff and takes priority over the session narrative
4. Check Claude Project memory for anything relevant that may not yet be
   reflected in the latest session summary (see precedence rule below)

**Then respond with a short status, not a checklist walkthrough:**

> Reviewed the working preferences and **SessionSummary[Date].md**.
>
> **Next session start here said:** [tactical handoff item]
> **Open carry-forward:** [item(s)]
> **Watch out for:** [constraint(s), if any]
>
> My suggested starting point: [specific first action]. What direction do you
> want to take today?

**Do only if relevant to the stated agenda (not preemptively):**
- If registry work is on the agenda, search the knowledge repository for
  `hospital_registry.yaml` and note its current state
- If pipeline work is on the agenda, search the knowledge repository for
  `StrategyPipelineReference.md`
- Pull any other specific project files named in the summary (e.g. a script
  that was modified, a reference document for the next workstream) once the
  day's work is named — not speculatively before that

**Missing documents:** If any document required for the session's planned work
is not found in the knowledge repository, flag it by name — stating what it
is needed for — before proceeding. Do not silently work around a missing
reference document.

**On Claude Project memory:** This is a background system, separate from the
knowledge repository and session summaries, that derives summarized context
from past conversations in this Project over time. It updates on a delay and
is not a verbatim record. Treat it as **advisory only** — useful for catching
something that never made it into a session summary, but never authoritative.
If anything from Project memory conflicts with the current session summary or
this working preferences file, the explicit written documents win.

This orientation should happen unprompted — do not wait for the user to
reconstruct context.

---

## 12. Scope

This project covers **Ontario hospitals** aligned with the MOH HIT tool
universe of acute and non-acute hospitals under provincial oversight. No
expansion to other provinces or health system entities without explicit
discussion.

**Hospital count is not fixed and should not be restated as a specific number
in this document.** The count trends slowly downward as hospital corporations
merge — a merger reduces the total, it does not create a new entity to track
separately. New organizational *structures* within an existing corporation are
expected and normal; the formation of an entirely new hospital corporation
that is not the product of a merger is not expected. The registry YAML
(`hospital_registry.yaml`) is the authoritative source for the current count
at any given time.

When a merger occurs, the surviving structure for tracking the
merged-away FAC (e.g. marked `status: merged` with a pointer to the
surviving FAC, versus removed from the registry outright) is a data-governance
decision to be made explicitly when it arises — not assumed by default.

---

## 13. Figure Conventions

All publication figures follow the figure standards documented in
`figure_standards.md` (`docs/figure_standards.md`). Key conventions:

- **Base theme:** `theme_linedraw()` with sans-serif font throughout
- **Palette:** Dark2 (ColorBrewer) for categorical data; fixed type group colour
  mapping (teal/orange/purple/green) consistent across all figures
- **Dimensions:** 7 × 5 in default; tall figures (ranked hospital lists) at
  7 × 14 in; wide multi-panel at 10 × 5 or 10 × 6 in
- **Resolution:** 300 DPI, PNG primary
- **FAC on y-axis:** Always use a character label (e.g. `paste0("FAC ", fac)`)
  — never pass raw FAC values to a ggplot aesthetic, as numeric FAC forces a
  continuous scale on a discrete axis

### Named graph types

**Baseball graph** — a sorted horizontal lollipop used to show per-hospital
ranked comparisons. Standard design:
- Sorted greatest to least (largest change at top)
- Two-colour lollipops: green (#1B9E77) above median, red (#CC3300) below
- Median shown as a labelled dashed vertical reference line
- Zero reference shown as a dotted grey vertical line
- y-axis labels are character FAC labels (`"FAC 592"`) — never numeric
- Caption notes any excluded hospitals (e.g. closed, merged)
- Natural extension: facet by hospital type group for within-type comparison

First used: HIT revenue change figure (`roles/hit/scripts/fig_hit_rev_change.R`)

---

## 14. Session Summary Standards

Session summaries are the continuity mechanism across sessions. A missing or
malformed summary forces the next session to reconstruct context from scratch.

### Format and filename
- **Always `.md`** — never `.docx`, `.txt`, or any other format. The working
  preferences Section 1 is explicit on this; `.docx` is a format violation.
- **Filename:** `SessionSummary[MonthDDYYYY].md`
  - Example: `SessionSummaryJune212026.md`
  - Two sessions in one day: append `_AM` / `_PM`

### Template
The template lives at `docs/session_summaries/session_summary_template.md` on
the local system and in GitHub. Claude reads it from the knowledge repository.
If it is not found there, flag it at session startup. Do not invent a new
structure.

### Required section order
The **"Next Session — Start Here"** block must appear first — immediately after
the title, before any session narrative. It is the tactical handoff. Burying
next steps at the bottom of a numbered narrative means the next session must
read the entire document to find its starting point.

Required order:
1. Next Session — Start Here
2. Session Objectives
3. Work Completed
4. Key Design Decisions
5. Files Produced or Modified
6. GitHub Commit Instructions
7. Session End Checklist

### At session end
- Upload to Claude Project knowledge repository
- Commit to `docs/session_summaries/` on GitHub

---

## 15. Data Storage Standard

### Primary format: R dataframes saved as `.rds`

Analytical data is stored as **R dataframes in `.rds` format** by default.
This is the project standard because `.rds` files are directly loadable in R
(`readRDS()` / `saveRDS()`), preserve column types (including character FAC),
and are easier to inspect interactively than CSVs. The canonical location for
analytical dataframes is `roles/minutes/outputs/` for the minutes role and
`analysis/data/` for cross-role analytical outputs.

**When CSV is acceptable:**
- Outputs intended for human review or manual editing (e.g. review lists,
  patch logs, validation exports)
- Outputs shared with collaborators who may not use R
- Intermediate pipeline logs (scrape logs, classification logs)

**Never use CSV as the primary store for a dataframe that will be joined,
filtered, or analysed in R** — type coercion on read is a recurring source of
errors (especially FAC as numeric, date columns as character).

### Analytical master files

Each role that produces a corpus for analysis maintains a single
**analytical master dataframe** (see Section 16 for the general pattern, and
Section 17 for the `minutes` role's specific implementation). All workstream
scripts source from this master — never from raw pipeline outputs directly.
This ensures consistent hospital and document counts across all analyses
within a role.

### Versioning for publications

When a paper goes to submission, snapshot the relevant master dataframe with a
dated suffix (e.g. `minutes_analytical_master_v1_jun2026.rds`). This is an
archival act. The live master retains its canonical name. All figures and tables
in the submitted paper are reproducible against the named snapshot.

### Annual refresh and provenance

The minutes corpus is designed for annual refresh — new hospitals added,
new minutes appended each December. To support this:

- Every record in every analytical dataframe carries a `scrape_date` field
  (date the document was downloaded) in addition to `doc_date` (date of the
  meeting, extracted from document content)
- `scrape_date` enables cohort identification when results span multiple
  annual refresh cycles
- If external data (e.g., the LH prior corpus, or data contributed by
  individual hospitals) is integrated, it carries a `data_source` field
  identifying its origin

---

## 16. Analytical Master Pattern (General Rule — All Roles)

Every role that produces a corpus for analysis (`minutes`, `executives`,
`board`, `strategy`, `hit`, `foundational`) maintains a single canonical
**analytical master dataframe** for that role. This is the general pattern;
Section 17 documents its specific implementation for `minutes`. As other
roles are built or migrated (including `executives`, per the migration noted
in Section 9), each gets its own subsection following this same pattern.

**Rules that apply to every role's analytical master, without exception:**

- **One master per role.** All workstream scripts for that role source from
  it — never from raw pipeline output directly.
- **No workstream script defines its own inclusion or eligibility logic.**
  Eligibility flags (which records belong in which downstream analysis) live
  only in the master.
- **Mandatory provenance fields.** At minimum: a `scrape_date` (or equivalent
  collection-date) field, and a `data_source` field identifying origin when
  more than one collection method or source feeds the master (e.g. scraped
  vs. manual entry vs. migrated-legacy data).
- **FAC as character**, per Section 7, with no exceptions.
- **Commit to GitHub with a meaningful message every time the master changes.**
- **Snapshot with a dated suffix before any publication or submission** that
  depends on it (see Section 15, Versioning for Publications). The live
  master keeps its canonical name; the snapshot is the archival, reproducible
  reference.
- **Governance rule changes to eligibility or schema** (e.g. adding a new
  `in_*_corpus` flag) get made once, in the master, and propagate to all
  workstreams that source from it — not patched into individual scripts.

This exists to prevent the same failure mode already documented for the
`minutes` role — inconsistent hospital/document counts across analyses within
a role — from re-emerging independently in each new role as it's built.

---

## 17. Minutes Analytical Master (`minutes_analytical_master`)

The `minutes_analytical_master` is the `minutes` role's implementation of the
general pattern in Section 16. It lives at:

`E:/HospitalIntelligenceR/roles/minutes/outputs/minutes_analytical_master.rds`

**One row per document.** It is built after Stage 2 classification is complete
and before any analytical workstream begins.

### Mandatory columns

| Column | Type | Description |
|---|---|---|
| `fac` | character | FAC code — always character, never numeric |
| `hospital_name` | character | Display name from registry |
| `hospital_type_group` | character | Teaching / Community—Large / Community—Small / Specialty |
| `folder_name` | character | Subfolder in extracted archive |
| `filename` | character | PDF filename |
| `local_path` | character | Full path to PDF on disk |
| `tier` | character | `MinutesOnly` / `MinutesSummary` / `SomethingElse` |
| `doc_date` | Date | Meeting date extracted from document content (not scraper) |
| `scrape_date` | Date | Date PDF was downloaded |
| `data_source` | character | `scrape_current` / `lh_prior` / `hospital_contributed` |
| `in_foci_corpus` | logical | Eligible for board foci / riverbed analysis |
| `in_sentiment_corpus` | logical | Eligible for NRC EmoLex sentiment analysis |
| `in_topic_corpus` | logical | Eligible for LDA topic mining |
| `in_strategy_corpus` | logical | Has matched strategy plan (Part A alignment) |
| `in_strategy_linked_corpus` | logical | Strategy plan is time-contingent with minutes (Part B) |
| `exclusion_reason` | character | NA if included; reason string if excluded from all corpora |

### Governance rules

These are the `minutes`-specific application of Section 16's general rules:

- No workstream script defines its own inclusion logic — all filter from this master
- When a document's tier or eligibility changes, update the master and re-run
  affected workstream scripts
- Commit the master to GitHub with a meaningful message every time it changes
- Snapshot before each paper submission (see Section 15)

---

## Changelog

- **2026-07-03** — Added general Analytical Master Pattern (Section 16) applying
  to all roles, not just `minutes`; renumbered former Section 16 to Section 17.
  Reworked Section 12 (Scope) to describe hospital count as a declining trend
  driven by mergers rather than a fixed number. Simplified Section 11 (Session
  Startup) to a lightweight always/conditional split with a fixed status-report
  format; added precedence note for Claude Project memory. Cleaned up the
  garbled CSV/`.rds` line in Section 2. Added Migration Status subsection
  under Section 9 documenting the planned `ExecutiveSearchYaml` →
  `HospitalIntelligenceR` migration. Added Change Tracking guidance (commit
  message convention, this changelog block, `Last Reviewed by Skip` date) to
  Section 5.
