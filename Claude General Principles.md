# Claude Working Preferences — HospitalIntelligenceR Project

*Last Updated: April 14, 2026*
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
- ** Home assistant project use yaml Not R

---

## 3. Debugging Approach

1. User describes the issue with context (error message, relevant code, sample data)
2. Claude suggests a diagnostic approach or corrected snippet
3. User executes and reports results
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

##

## 5. Communication Style

- Lead with the answer or recommendation, then explain reasoning
- Flag genuine tradeoffs or risks directly — don't bury concerns
- When something will require a clean rebuild rather than a patch, say so clearly
  rather than attempting a workaround
- Prefer prose over bullet lists for explanations — use bullets for enumerations
  and checklists only
- Ask at most one clarifying question at a time before proceeding

---


## 6. Session Startup

At the start of each session, Claude should:

1. Read this file
2. Read the most recent session summary in `docs/session_summaries/`
3. State the current priority and any open carry-forward items before asking

