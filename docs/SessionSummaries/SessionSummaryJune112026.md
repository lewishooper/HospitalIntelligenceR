# Session Summary — June 11, 2026
## Board Minutes Role — Phase 2 Planning: Tier Framework and Work Plan

---

## Next Session — Start Here

**Current priority:** Begin Tier 1 build — T1-S1 hand-labelling session.

**First action:** Pull a stratified sample of 50 PDFs from the archive for hand-labelling.
The sample should be stratified, not random — include confirmed minutes, agendas,
mixed packages, thin specials, and reports, and ensure representation across hospital
types. Work through classification decisions together before any code is written.
The labelling session calibrates the structural classifier and confirms which regex
patterns are needed.

**Reference document:** `BoardMinutes_Phase2_AnalysisWorkPlan.md` — uploaded to
knowledge repository this session. This is the governing work plan for all Phase 2
work. It is a living document; detail is added at the end of each tier.

**Carry-forwards:**
- FAC 927 has 4 files with `yearonly` dates — actual meeting dates recovered from
  document content in Tier 1 Step 3, not before.
- Gap classification deferred from Phase 1 is completed in Tier 1 Step 4 (coverage map).
- JS-required hospitals (7 FACs) remain outstanding; Tiers 1–3 proceed with the
  57-hospital corpus and JS hospitals are added if a RSelenium session is completed.

**Watch out for:**
- The structural classifier is the primary classification logic; deliberation term
  density is a secondary confirmation signal only. Do not let term counts override
  clear structural evidence.
- Special meetings can be as short as one page. Length is not a disqualifier if
  the structural pattern is intact.
- Consent agenda detection is an analytical variable, not just a QA flag. Track it
  carefully from T1-S1 onward.

---

## Session Objectives

This was a design and planning session, not a build session. No code was written.
The objective was to produce a fully designed Phase 2 work plan covering all three tiers.

---

## Work Completed

### 1. Tier Framework Established

Three analytically distinct tiers agreed:

| Tier | Name | Core question | Method |
|---|---|---|---|
| 1 | Audit and Classification | What do we actually have? | Structural heuristics + NLP |
| 2 | Board Foci and Sentiment | Where do boards focus, and what is the tone? | NLP dictionary scoring + NRC EmoLex |
| 3 | Concordance | Do boards deliberate in alignment with strategic plans and stated values? | Language matching |

Key design decision: tiers are sequential and the plan is a living document.
A planning session at the end of each tier adds detail to the next tier before
build begins.

### 2. Tier 1 Design — Audit and Classification

Four-step process agreed:

**Step 1 — Text extraction:** `pdftools::pdf_text()` on all 2,431 PDFs. Word count
and encoding success as immediate quality signals. Image-based PDFs flagged
`needs_ocr` and deferred — not blocking.

**Step 2 — Document classification:** Primary classifier is structural, based on the
canonical minutes pattern: header block → attendance block → deliberation body →
close. All four present = confirmed minutes. Deliberation term density (moved,
seconded, carried, resolved, approved) is a secondary confirmation signal only.

Document typology: `minutes`, `mixed_minutes_lead`, `mixed_report_lead`, `agenda`,
`report`, `needs_ocr`, `other`.

Special meetings: length is not a disqualifier. A one-page special meeting with a
complete structural pattern is a valid and complete document.

**Step 3 — Metadata extraction:** Meeting date from document content (not filename),
cross-validated against filename date. Discrepancies > 30 days flagged. Meeting type
by keyword match: regular / special / annual / unknown.

**Step 4 — Temporal coverage mapping:** Coverage map by hospital and year. Thin
coverage = fewer than 3 confirmed meetings per year for an active hospital. Gap
classification completed here (deferred from Phase 1).

**Consent agenda as a standalone analytical thread:** Detected and flagged separately
(`has_consent_agenda`, `consent_agenda_pct`). Not folded into PROC. A high consent
agenda proportion may indicate efficient governance or may hide deliberation that is
invisible to the foci analysis. Tracked as an analytical variable throughout.

**Output schemas confirmed:**
- `minutes_corpus_audit.csv` — one row per PDF; all classification decisions
- `minutes_master.csv` — one row per confirmed meeting; `corpus_include = TRUE` only
- `minutes_coverage.csv` — one row per hospital per year

**Tier 1 estimated sessions: 5**

### 3. Tier 2 Design — Board Foci and Sentiment

**Foci taxonomy:** Adopted from Hooper (2020) — 16 focus areas derived from 700+
Ontario hospital board meetings. This is the validated baseline. The strategy taxonomy
(WRK, PAT, FIN, etc.) is not used for Tier 2 — it was designed for strategic planning
language, not governance deliberation, and does not cover governance-specific foci
(compliance, medical staff, consent agenda, in-camera).

**15 substantive focus areas confirmed:**
FIN, QUAL, STR, COMP, POL, MVV, MGT, MED, GOV, COM, HIS, EXEC, CA (consent agenda),
INC (in-camera volume only), PROC (excluded from substantive denominator).

**Measurement method:** Dictionary-based scoring, not TF-IDF. LDA was used in
Hooper (2020) to develop the lexicon terms; it is not the operational measurement
method here. `tidytext::unnest_tokens()` + join to custom lexicon, grouped by focus
area. Auditable: which terms fired is traceable for any meeting.

**AI validation:** After NLP baseline, a 15–20% random held-out sample is run through
the Claude API. Where systematic divergence appears (> 15pp on any focus area for
> 20% of sampled meetings), the lexicon is adjusted. Output rows labelled with
`method` field.

**Sentiment:** NRC EmoLex (NRC Canada, 2016) with healthcare domain modification —
same tool and modification approach as Hooper (2020). Three dimensions: trust,
positive, negative. Scoring per 1,000 words; three-meeting rolling average for
trend analysis. Pandemic era (2020–2022) is an analytical extension not covered
by prior work.

**Primary analytical outputs:** Riverbed graphic (replicates and extends Hooper
(2020) Figure 1); individual hospital overlays; temporal foci trends; consent
agenda trend; sentiment trends including pandemic signal.

**Tier 2 estimated sessions: 6**

### 4. Tier 3 Design — Concordance

**Key design decision: language matching, not taxonomic approach.**

Tier 3 does not use a taxonomy or a crosswalk between the Hooper (2020) foci and
the strategy taxonomy codes. It uses direct language matching: does the actual
language of the hospital's strategic plan appear in the board's deliberations?

This is more direct and more analytically honest than cosine similarity of theme
vectors. It is hospital-specific and plan-specific.

**Three concordance dimensions:**

- **Tier 3a — Strategy concordance:** Per-hospital strategic term extraction from
  `strategy_classified.csv`. 20–50 distinctive terms per hospital, weighted by
  specificity. Score = occurrences per 1,000 words of meeting text, aggregated
  annually. Dependency: `strategy_classified.csv` — already available.

- **Tier 3b — MVV concordance:** Same approach applied to Mission, Vision, and
  Values statements. Dependency: foundational documents role — not yet built.
  Tier 3b deferred until MVV data available; Tier 3a proceeds independently.

- **Tier 3c — Replication of Hooper (2021) null result:** Hooper (2021, unpublished)
  found no significant beneficial relationship between board focus on finance or
  quality and measurable outcomes in 36 hospitals. Current dataset (57 hospitals,
  post-pandemic) enables direct replication. HIT data available for finance dimension;
  CIHI quality data availability assessed at Tier 2 planning session.

**Tier 3 build sequence:** Detailed at Tier 2 planning session.
**Tier 3 estimated sessions: 5–8**

### 5. Literature Review Completed

Two papers reviewed and incorporated into the work plan:

**Hooper, L. (2020). Measuring Boards Using Quantitative Tools from Natural Language
Processing. Healthcare Quarterly 23(3).**
- Direct methodological predecessor
- Establishes foci taxonomy (16 areas), NRC EmoLex approach, riverbed graphic
- 22 Ontario hospitals, 700+ meetings
- LDA used to develop lexicon terms; dictionary scoring is operational method
- NRC EmoLex healthcare modification documented and replicable

**Hooper, L. (2021, unpublished). Measuring Board Impact on Hospital Finance and
Quality.**
- 36 hospitals, 1,500 meetings, 39 regression tests
- Predominantly null result: increased board focus on finance or quality does not
  significantly improve outcomes for all hospitals as a group
- Small hospitals showed two beneficial finance effects; large community one
  beneficial quality effect
- Overall conclusion: boards should reconsider how their limited time is allocated
- Key finding to replicate and extend with current dataset

### 6. Work Plan Produced

`BoardMinutes_Phase2_AnalysisWorkPlan.md` — complete three-tier plan including:
- Tier 1: full build sequence, output schemas, 5-session estimate
- Tier 2: foci taxonomy, measurement approach, sentiment framework, 6-session estimate
- Tier 3: concordance design intent, dependencies, placeholder build sequence
- Two planning checkpoints (end of Tier 1, end of Tier 2)
- Known risks and mitigations
- Prior literature references

---

## Key Design Decisions Made This Session

| Decision | Rationale |
|---|---|
| Tiers are sequential; plan is a living document | Shape of actual data must inform Tier 2 and 3 design before build begins |
| Primary classifier is structural (header/attendance/body/close pattern) | More reliable and auditable than weighted term counts for this corpus |
| Length is not a disqualifier for specials | A complete one-page special meeting is a valid document |
| Consent agenda tracked as analytical variable, not just QA flag | Governance signal in its own right; Hooper (2020) flagged as a known limitation |
| Hooper (2020) foci taxonomy adopted for Tier 2; not strategy taxonomy | Validated from Ontario hospital corpus; strategy taxonomy is wrong register |
| Dictionary scoring for foci, not TF-IDF or LDA | Auditable, interpretable, consistent with Hooper (2020) operational method |
| NRC EmoLex with healthcare domain modification for sentiment | Validated tool and modification approach from prior published work |
| Language matching (not taxonomy) for Tier 3 concordance | More direct test of genuine uptake; hospital-specific rather than sector-average |
| Tier 3 taxonomic crosswalk not required | Language matching makes it unnecessary; adds complexity without analytical gain |

---

## Files Produced This Session

| File | Location | Notes |
|---|---|---|
| `BoardMinutes_Phase2_AnalysisWorkPlan.md` | Upload to knowledge repository | Living document; governing plan for all Phase 2 work |
| `SessionSummaryJune112026.md` | Upload to knowledge repository | This file |

---

## Session End Checklist

- [ ] Upload `BoardMinutes_Phase2_AnalysisWorkPlan.md` to knowledge repository
- [ ] Upload `SessionSummaryJune112026.md` to knowledge repository
- [ ] No code changes this session — no GitHub commit required
