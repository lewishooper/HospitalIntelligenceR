# HospitalIntelligenceR
## Session Summary — [Month DD, YYYY]
## [Workstream / Role — Brief Descriptor]
*For Claude Project Knowledge Repository*

---

<!--
════════════════════════════════════════════════════════════════
  FORMAT RULES — READ BEFORE WRITING
════════════════════════════════════════════════════════════════

FILE FORMAT
  - Always .md (Markdown). Never .docx, .txt, or any other format.
  - Working preferences Section 1 is explicit: markdown is the default
    for all summaries, notes, and reference material.
  - Saving as .docx is a format violation even if the content is correct.

FILENAME CONVENTION
  - SessionSummary[MonthDDYYYY].md
  - Examples: SessionSummaryJune212026.md
              SessionSummaryJuly012026.md
  - If two sessions occur in one day, append AM / PM:
    SessionSummaryJune212026_AM.md / SessionSummaryJune212026_PM.md

WHERE TO SAVE
  - Upload to Claude Project knowledge repository (required for continuity)
  - Commit to docs/session_summaries/ on GitHub

SECTION ORDER — DO NOT REARRANGE
  The "Next Session — Start Here" block MUST be first, immediately after
  the title. It is the tactical handoff to the next session. Burying it
  at the bottom (as a "Next Steps" section) means the next session has
  to reconstruct priority from narrative — which defeats its purpose.

  Required section order:
    1. Next Session — Start Here      ← always first; always present
    2. Session Objectives
    3. Work Completed
    4. Key Design Decisions
    5. Files Produced or Modified
    6. GitHub Commit Instructions
    7. Session End Checklist

ANTI-PATTERN TO AVOID (June 20, 2026 summary)
  The June 20 summary was saved as .docx and used a numbered narrative
  structure (1. What Was Accomplished / 2. Output Review / 3. Special Cases /
  4. Next Steps / 5. Carry Forward). Next Steps appeared at position 4,
  after three pages of narrative. The next session had to hunt for priority.
  That structure is not this template.

DELETE THIS COMMENT BLOCK BEFORE SAVING THE COMPLETED SUMMARY.
════════════════════════════════════════════════════════════════
-->

---

## Next Session — Start Here

**Current priority:** [One sentence. What is the single most important thing
to do at the start of the next session?]

**First action:** [Specific and concrete — name the script, command, or step.
Example: "Source `load_extraction_design.R` and paste keyword counts to console
before writing any new code."]

**Watch out for:**
- [Active constraint, known landmine, or fragile assumption relevant to the
  next session. Delete this bullet if nothing applies.]

### Carry-Forward Items

| Item | Status | Notes |
|---|---|---|
| [Item description] | READY TO EXECUTE | [Any detail needed to act on it] |
| [Item description] | IN PROGRESS | [Where it was left off] |
| [Item description] | FUTURE WORKSTREAM | [Why deferred] |
| [Item description] | LOW URGENCY | [What triggers execution] |

---

## Session Objectives

[2–4 sentences. What was this session trying to accomplish? State the goal,
not the method. Example: "Build and validate the load_extraction_design.R
loader against the extract_minutes_design.xlsx design file. Confirm the
begin_keywords and end_keywords vectors are correct before writing
extract_minutes.R."]

---

## Work Completed

[Narrative. Use subsections (###) for distinct workstreams within the session.
Lead each subsection with what was accomplished, then add detail. Include
diagnostic findings, test results, and confirmed outputs. Bug/fix tables
go here when applicable.]

### [Subsection title — e.g., "1. Script name or workstream"]

[Description of what was done and what was found.]

**Bugs fixed:**

| Bug | Fix Applied |
|---|---|
| [Description of the problem] | [What was changed and where] |

[Delete the bug table if no bugs were fixed this session.]

### [Additional subsections as needed]

---

## Key Design Decisions

[Durable choices made this session that affect future sessions, future scripts,
or the analytical record. If a decision has a rationale worth preserving — an
alternative that was considered and rejected, a constraint that drove the
choice — put it here. Omit trivial implementation choices.]

| Decision | Rationale |
|---|---|
| [What was decided] | [Why — include rejected alternative if relevant] |

[Delete this section if no durable design decisions were made.]

---

## Files Produced or Modified

| File | Location | Change |
|---|---|---|
| `[filename.ext]` | `E:/HospitalIntelligenceR/[path]/` | Created / Modified / Deleted — [one-line description] |
| `SessionSummary[Date].md` | Upload to knowledge repository | This file |

---

## GitHub Commit Instructions

```
[path/to/file1]    — created
[path/to/file2]    — modified
```

**Commit message:** `[tag]: [short description]`

Tags in use: `T1` (Tier 1 audit/classification), `T2` (Tier 2 analysis),
`fix` (bug fix), `docs` (documentation only), `registry` (YAML changes),
`analysis` (strategy/HIT analytics scripts)

**Description** (include when commit covers multiple files or non-obvious changes):
```
[Optional multi-line description]
```

[Delete commit instructions if nothing is being committed this session.]

---

## Session End Checklist

- [ ] Delete the format-rules comment block from this file
- [ ] Save as `SessionSummary[Date].md` — confirm `.md` extension before closing
- [ ] Upload to Claude Project knowledge repository
- [ ] Commit to `docs/session_summaries/` on GitHub
- [ ] [Any session-specific items — e.g., "Execute FAC 644 corpus exclusion patch"]
- [ ] [Delete any checklist items that do not apply]
