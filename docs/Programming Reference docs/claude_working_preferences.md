# claude working preferences — HospitalIntelligenceR project

*Last Updated: June 10, 2026*
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

Before drafting any publication narrative, consult
`docs/writing_and_research/style_guide.md`. These are distinct documents —
a publication narrative is not a summary of the technical narrative.

---

## 2. Development Environment

- **Primary language:** R, using RStudio
- **Project root:** `E:/HospitalIntelligenceR/` — canonical full path (Windows, forward slashes in R)
- **User executes all code** in their own R/RStudio environment — Claude provides
  code snippets and guidance, not execution
- **Working directory** assumed to be the project root unless stated otherwise
- **API:** Claude API used for all content extraction roles

### Path Conventions — Critical

All `source()` calls and file path references in scripts use paths **relative to
the project root**, not relative to the script's own folder. Claude must always
write paths this way in any code provided.

- Correct: `source("core/registry.R")`
- Wrong: `source("../../core/registry.R")`

When specifying where a file lives or should be saved, always anchor to the full
canonical path for clarity — e.g. `E:/HospitalIntelligenceR/roles/minutes/` not
just `roles/minutes/`. Scripts in role subfolders (e.g. `roles/minutes/`) are
client-side files that Claude cannot edit directly; provide change instructions
or a downloadable file instead.

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
procedure in `docs/programming_reference/yaml_registry_reference.md` and close
the file in RStudio before running any patch script.

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
├── claude_working_preferences.md   # This file
├── core/           # Shared infrastructure — registry, crawler, fetcher, claude_api, logger
├── analysis/       # Strategy analytics layer — scripts, data, outputs
├── roles/
│   ├── strategy/   # Strategic plan extraction (annual)
│   ├── hit/        # HIT financial import (annual MOH download)
│   ├── foundational/ # Vision/Mission/Values (on change)
│   ├── executives/ # Executive team (monthly)
│   ├── board/      # Board of directors (6-month, post-September)
│   └── minutes/    # Board meeting minutes archive (monthly)
├── registry/       # hospital_registry.yaml — single source of truth (~137 hospitals)
├── reference/      # cihi_fac_crosswalk.csv and other external reference data
├── orchestrate/    # Built last — ties roles together
├── docs/
│   ├── programming_reference/   # Technical orientation documents
│   ├── writing_and_research/    # Narratives, style guide, writing aids
│   ├── prompts/                 # Tracked analytical prompt assets
│   └── session_summaries/       # Per-session markdown summaries
└── dev/            # Scratch/sandbox — gitignored
```

**Note:** `analysis/data/` is **tracked in git** as a curated analytical asset —
intermediate CSVs are committed as part of the analytical record. `analysis/outputs/`
is gitignored. Do not add `analysis/data/` to `.gitignore`.

**Build sequence:** `registry.R` and `fetcher.R` first (no dependencies), then
`crawler.R`, `claude_api.R`, `logger.R`, then role modules starting with
`strategy/`, then `orchestrate/` last. For the analytics execution order, see
`docs/programming_reference/StrategyPipelineReference.md`.

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

Each working session runs in a fresh thread. At the start of each session, Claude should:

1. Read this file
2. Read the most recent session summary in `docs/session_summaries/`
3. Within the summary, read the **"Next Session" block first** — this is the
   tactical handoff and takes priority over the session narrative
4. State the current priority, the first action to take, and any open
   carry-forward items before asking how to proceed
5. Note any "watch out for" items from the summary as active constraints
6. Pull any specific project files named in the summary (e.g. a script that
   was modified, a reference document for the next workstream) before generating
   any code or analysis
7. If registry work is on the agenda, note the current state of
   `registry/hospital_registry.yaml`
8. If pipeline work is on the agenda, confirm the relevant step in
   `docs/programming_reference/StrategyPipelineReference.md`

This orientation should happen unprompted — do not wait for the user to
reconstruct context.

### What a session summary contains

Session summaries are structured markdown files with the following sections:
- **Next Session — Start Here** (top of file): priority, first command, carry-forwards, watch-out items
- **Session Objectives**: what the session was trying to accomplish
- **Work Completed**: what was actually done, with bug/fix tables where relevant
- **Key Design Decisions**: durable choices that affect future sessions
- **Files Produced / Modified**: table of changed files with locations
- **Session End Checklist**: upload/commit tasks for the user

The "Next Session" block is always the most operationally important part.
Read it first; use the rest of the summary as supporting context.

---

## 11. Scope

This project covers **Ontario hospitals only** — currently ~137 hospitals in
the validated registry. No expansion to other provinces or health system entities
without explicit discussion.

---

## 12. Figure Conventions

All publication figures follow `docs/figure_standards.md`. Key conventions:

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
