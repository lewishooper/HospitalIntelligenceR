# Claude Working Preferences — HospitalIntelligenceR Project

*Last Updated: February 2026*
*Upload this document to the Claude Project knowledge repository for persistent reference.*

---

## 1. Document Output Standards

### Default: Markdown
All discussion documents, summaries, notes, architecture writeups, and reference material are produced as **markdown (.md)** unless otherwise specified. Markdown is the default because it lives cleanly in the GitHub repository and renders well in the knowledge repository.

### Exception: Formal Deliverables → .docx
Word documents (.docx) are used **only when explicitly requested** — for example, documents intended for external sharing, formal reports, or knowledge repository uploads where rich formatting is needed. When .docx is requested, the docx skill is used.

### Code Files
R scripts, YAML, and other code outputs are provided as code blocks in chat or written directly to files — never wrapped in a Word document.

---

## 2. Development Environment

- **Primary language:** R, using RStudio
- **Project root:** `HospitalIntelligenceR/` (single R Project, single GitHub repo)
- **User executes all code** in their own R/RStudio environment — Claude provides code snippets and guidance, not execution
- **Working directory** assumed to be the project root unless stated otherwise
- **API:** Claude API used for all content extraction roles

### R Code Preferences
- Provide snippets for the user to integrate and run
- Explain the reasoning behind an approach, not just the code
- Focus on problem isolation — short diagnostic snippets over large rewrites when debugging
- When a clean baseline is more practical than patching, say so directly

---

## 3. Debugging Approach

1. User describes the issue with context (error message, relevant code, sample data)
2. Claude suggests a diagnostic approach or corrected snippet
3. User executes in their R environment and reports results
4. Iterate until resolved

This approach gives the user better insight into the troubleshooting logic and avoids blind copy-paste fixes. Claude should not attempt to "fix everything at once" — prefer targeted, testable changes.

---

## 4. Documentation Practices

- **Do not produce documentation unless explicitly asked**
- User controls documentation scope and timing
- Exception: session summaries and working notes when specifically requested (as in this session)
- When documentation is produced, it goes into `docs/` in the project structure unless directed elsewhere

---

## 5. YAML Formatting

When writing or updating YAML for hospital registry entries, use **2-space indentation** to match R/RStudio conventions:

```yaml
  - FAC: '592'
    name: NAPANEE LENNOX & ADDINGTON
    hospital_type: Small Hospital
    base_url: https://web.lacgh.napanee.on.ca
```

The registry YAML files are the single source of truth — treat them carefully. No script other than `core/registry.R` should write to them.

---

## 6. Communication Style

- Lead with the answer or recommendation, then explain reasoning
- Flag genuine tradeoffs or risks directly — don't bury concerns
- When something will require a clean rebuild rather than a patch, say so clearly rather than attempting a workaround
- Prefer prose over bullet lists for explanations — use bullets for enumerations and checklists only
- Ask at most one clarifying question at a time before proceeding

---

## 7. Project Architecture (Quick Reference)

```
HospitalIntelligenceR/
├── core/           # Shared infrastructure — registry, crawler, fetcher, claude_api, logger
├── roles/
│   ├── strategy/   # Strategic plan extraction (annual)
│   ├── foundational/ # Vision/Mission/Values (on change)
│   ├── executives/ # Executive team (monthly)
│   └── board/      # Board of directors (6-month, post-September)
├── registry/       # base_hospitals_validated.yaml — master hospital list (133 Ontario hospitals)
├── orchestrate/    # Built last — ties roles together
├── docs/           # Protocols, guidelines, this file
└── dev/            # Scratch/sandbox — gitignored
```

**Build sequence:** `registry.R` and `fetcher.R` first (no dependencies), then `crawler.R`, `claude_api.R`, `logger.R`, then role modules starting with `strategy/`, then `orchestrate/` last.

---

## 8. Key Constraints to Keep in Mind

- **FAC code** is the primary key across all data — every output record must carry it
- **Manual overrides** are first-class, not exceptions — hospitals that can't be auto-scraped carry an explicit `manual_override` status in YAML
- **robots.txt** is honoured by default; a per-hospital override flag exists for cases where permission has been obtained
- **Cost awareness** — all Claude API calls are logged with token counts and cost; flag when an approach is likely to be expensive

---

## 9. Session Startup Checklist

For new sessions, reference the following to get up to speed quickly:

- Review this file
- Review `HospitalIntelligenceR_SessionSummary.md` (or .docx) for architecture decisions and build sequence
- Check `registry/base_hospitals_validated.yaml` for current hospital status
- Confirm which core module is currently being built or tested

---

## 10. Scope

This project covers **Ontario hospitals only** — currently 133 hospitals in the validated registry. No expansion to other provinces or health system entities without explicit discussion.
