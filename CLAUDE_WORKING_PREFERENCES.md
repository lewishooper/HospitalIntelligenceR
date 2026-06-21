# Claude Working Preferences — HospitalIntelligenceR Project

*Last Updated: June 21, 2026*
*Upload this document to the Claude Project knowledge repository for persistent reference.*

---

## 1. Document Output Standards

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

## 2. Development Environment

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

## 3. Debugging Approach

1. User describes the issue with context (error message, relevant code, sample data)
2. Claude suggests a diagnostic approach or corrected snippet
3. User executes in their R environment and reports results
4. Iterate until resolved

This approach gives the user better insight into the troubleshooting logic and
avoids blind copy-paste fixes. Claude should not attempt to "fix everything at
once" — prefer targeted, testable changes.

---

## 4. Documentation Practices

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

### How Claude Accesses Project Documents

**Claude cannot read the local file system (`E:/HospitalIntelligenceR/`) or
GitHub directly.** All `docs/` paths in this file describe where documents live
on the local system and in the repository — they are the canonical reference
paths, not paths Claude can open.

Claude reads project documents from two sources only:

- **Knowledge repository** — documents uploaded by the user; this is the
  primary source for all reference files, templates, style guides, pipeline
  references, and session summaries
- **Session context** — files explicitly attached or pasted into the current
  session

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
See Section 13 for full standards.

---

## 5. YAML Formatting

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

## 6. R Code Conventions

These patterns have caused recurring errors in this project. Apply them by
default without waiting to be asked.

- **List binding:** Use `bind_rows(lapply(...))` — not `map_dfr()`, which is
  deprecated and causes silent failures
- **Anonymous functions:** Use explicit `function(x)` style — not tilde-lambda
  `~` syntax, which causes RStudio parser confusion in some contexts
- **Claude API responses:** Strip markdown code fences with `gsub` before
  parsing JSON (`gsub("```json|```", "", text)`); also sanitize control
  characters before `toJSON()`
- **purrr:** Must be explicitly loaded with `library(purrr)` — it is not
  attached automatically by tidyverse in this project's loading pattern
- **Logger:** Use `log_warning()` — not `log_warn()`, which does not exist in
  the logger package version in use
- **Logger init:** `init_logger()` requires the `role` argument — always call
  as `init_logger(role = "minutes")` (or the relevant role name). The bare
  `init_logger()` call will fail.
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

## 7. Communication Style

- Lead with the answer or recommendation, then explain reasoning
- Flag genuine tradeoffs or risks directly — don't bury concerns
- When something will require a clean rebuild rather than a patch, say so clearly
  rather than attempting a workaround
- Prefer prose over bullet lists for explanations — use bullets for enumerations
  and checklists only
- Ask at most one clarifying question at a time before proceeding

---

## 8. Project Architecture (Quick Reference)

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
├── registry/       # hospital_registry.yaml — single source of truth (137 hospitals)
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

---

## 9. Key Constraints to Keep in Mind

- **FAC code** is the primary key across all data — every output record must
  carry it, always as character (see Section 6)
- **Manual overrides** are first-class, not exceptions — hospitals that can't
  be auto-scraped carry an explicit `manual_override` status in YAML
- **robots.txt** is honoured by default; a per-hospital override flag exists
  for cases where permission has been obtained
- **Cost awareness** — all Claude API calls are logged with token counts and
  cost; flag when an approach is likely to be expensive

---

## 10. Session Startup

At the start of each session, Claude should:

1. Read this file
2. Read the most recent session summary in `docs/session_summaries/`
3. Within the summary, read the **"Next Session — Start Here" block first** —
   it is the tactical handoff and takes priority over the session narrative
4. State the current priority, the first action to take, and any open
   carry-forward items before asking how to proceed
5. Note any "watch out for" items from the summary as active constraints
6. Pull any specific project files named in the summary (e.g. a script that
   was modified, a reference document for the next workstream) before generating
   any code or analysis
7. If registry work is on the agenda, search the knowledge repository for
   `hospital_registry.yaml` and note its current state
8. If pipeline work is on the agenda, search the knowledge repository for
   `StrategyPipelineReference.md` (`docs/programming_reference/StrategyPipelineReference.md`)

**Missing documents:** If any document required for the session's planned work
is not found in the knowledge repository, flag it by name at startup — stating
what it is needed for — before proceeding. Do not silently work around a missing
reference document.

This orientation should happen unprompted — do not wait for the user to
reconstruct context.

---

## 11. Scope

This project covers **Ontario hospitals only** — 137 hospitals in the registry,
aligned with the MOH HIT tool universe of acute and non-acute hospitals under
provincial oversight. No expansion to other provinces or health system entities
without explicit discussion.

---

## 12. Figure Conventions

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

## 13. Session Summary Standards

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
