# Publication Narrative Style Guide
## HospitalIntelligenceR — Skip's Voice
*docs/style_guide.md | Calibrated April 2026*

---

## Purpose

This guide governs the tone, structure, and voice of publication-facing narratives
produced by HospitalIntelligenceR. It is distinct from technical narratives, which
prioritize methodological completeness. Publication narratives are intended for
practitioners, policy audiences, and LinkedIn-style professional publication.

This guide was calibrated from two writing samples provided by Skip Hooper
(LinkedIn paper excerpts, board minutes series). It should be referenced whenever
a publication-facing document is being drafted.

---

## Voice Characteristics

### 1. Direct and declarative — no throat-clearing

Open with the subject and its significance immediately. Do not warm up with
generalizations or scope statements. The reader should know what the paper is
about within the first two sentences.

**Like this:**
> Hospital boards in Ontario have significant responsibility for oversight of
> Ontario Hospitals. This paper uses text analytics to measure board performance
> and benchmark it against peers.

**Not like this:**
> This paper presents an analysis of strategic planning data collected from a
> sample of Ontario public hospitals with the goal of examining thematic patterns
> across planning eras and hospital type groups.

---

### 2. Practitioner voice, not academic voice

Write for people who work in the sector. Use sector terminology confidently
without over-defining it. Do not write for journal reviewers. Avoid passive
constructions, nominalization, and hedged phrasing that reads as academic caution.

**Like this:**
> Some hospitals have inculcated the hospital strategy as a part of their
> decision making while others have not.

**Not like this:**
> Variation was observed across institutions with respect to the degree to which
> strategic plan content was reflected in board deliberations.

---

### 3. Caveats inline, not parenthetical

Qualifications belong in the sentence, not in footnotes or parenthetical asides.
State the finding and its limit in the same breath.

**Like this:**
> The board's impact on quality was at best very small.
> There was no tangible link between financial performance and the board's
> discussions of finance.

**Not like this:**
> The board's impact on quality showed limited statistical significance
> (see methodological notes, Section 4).

---

### 4. Bring the reader along in the reasoning

Use "we" and anticipatory framing. Share the logic, not just the conclusion.
The reader should feel like they arrived at the finding with you.

**Like this:**
> Given that these hospitals exist in the same jurisdiction, share a common
> purpose, and face very similar constraints, we would anticipate significant
> similarity between their plans.

**Not like this:**
> High inter-hospital similarity was expected given shared jurisdictional context.

---

### 5. Concrete before abstract

Ground findings in numbers before making interpretive claims. Specific figures
build credibility and anchor the interpretation that follows.

**Like this:**
> There is an 86 to 94% similarity between the grouped minutes of the hospitals
> in the database. Identical documents score 100%; completely dissimilar documents
> score 0.

**Not like this:**
> Document similarity analysis revealed a high degree of overlap across institutions.

---

### 6. Strong statements — don't hedge findings to death

Be willing to state conclusions directly. The caveats have already been noted
where they belong. The conclusion section is not the place to re-hedge everything.

**Like this:**
> Based on this analysis, an increased board focus on finance or quality has
> little if any positive impact on a variety of outcome measures.
> All boards should be looking at how to maximize the use of their limited time.

**Not like this:**
> These findings suggest that there may be limited evidence to support the
> hypothesis that increased board focus is consistently associated with improved
> outcomes across all measure types examined.

---

### 7. Implications are practitioner-facing

The "so what" points at boards, CEOs, and board chairs — not at researchers.
Recommendations are direct and operational, not calls for further study.

**Like this:**
> This analysis indicates that boards should carefully consider how their
> limited time is used.
> The high focus on finance should be a particular concern for CEOs and Board Chairs.

**Not like this:**
> Future research should examine the mechanisms by which board focus translates
> into operational outcomes across different hospital types.

---

### 8. Short sentences carry the conclusions

Setup and background can run longer. Findings and implications land in short,
clean sentences. The rhythm shifts when you get to the point.

**Like this:**
> A board's time is limited to a few hours a month. The productive use of that
> time should be a critical consideration for all boards.

---

## Structure Conventions

**Opening:** State subject and significance immediately. Two to three sentences
maximum before the first substantive claim.

**Background:** Longer, context-building paragraphs are acceptable here. This
is where you establish the problem and why it matters.

**Findings:** Short to medium paragraphs. Each paragraph makes one claim,
supports it with a number, and states the implication. Caveats inline.

**Conclusions:** Short sentences. Direct recommendations. Named audience
(boards, CEOs, board chairs, policy makers). No re-hedging.

---

## What to Avoid

| Avoid | Because |
|-------|---------|
| Passive constructions ("was observed," "were identified") | Weakens the finding; sounds academic |
| Nominalization ("the examination of," "an analysis of") | Adds words, removes clarity |
| Footnoted caveats | Caveats belong in the sentence or not at all |
| "Future research should..." conclusions | This is practitioner writing, not academic |
| Re-hedging findings in the conclusion | You've already stated the limits; conclude cleanly |
| More than one main claim per paragraph | Dilutes impact |
| Opening with scope or methodology | Lead with significance, not process |

---

## Relationship to Technical Narratives

Technical narratives (e.g., `03b_narrative.md`, `03c_narrative.md`) are complete,
methodologically precise documents. They are the authoritative record of what was
done and found. They are intentionally flat in tone.

Publication narratives draw from technical narratives but:
- Lead with the finding, not the method
- Omit or compress methodological detail
- Use Skip's voice throughout
- Target a practitioner audience
- Are shorter — typically 600–1200 words for a single analysis

Publication narratives live in `docs/publications/`. Technical narratives live
in `docs/narratives/`. They are different documents serving different purposes.
A publication narrative is not a summary of the technical narrative — it is a
different piece of writing that happens to cover the same analysis.

---

## Calibration Note

This style guide was derived from two excerpts:
1. Opening and background section — board minutes / strategy focus paper (LinkedIn)
2. Conclusions section — board focus on finance and quality outcomes paper

The voice is consistent across both excerpts. The primary distinguishing features
are the directness of claims, the practitioner audience orientation, and the
willingness to name implications for specific roles (CEO, Board Chair). These
are the features to preserve in all publication-facing writing produced for
HospitalIntelligenceR.
