# HospitalIntelligenceR
## Session Summary — 04a Homogeneity, 04b Unique Strategies, Narrative Writing
*April 9, 2026 | For Claude Project Knowledge Repository*

---

## 1. Session Overview

A full analytical session completing the two remaining strategy analytics workstreams
scoped in the April 8 session summary. Primary accomplishments:

- Built and ran `04a_homogeneity.R` — strategic homogeneity analysis (three lenses:
  breadth, core profile match, pairwise Jaccard similarity)
- Built and ran `04b_unique_strategies.R` — theme-level outlier identification (Part 1)
  and direction-level distinctiveness via Claude API (Part 2)
- Produced `docs/narratives/04a_narrative.md` and `docs/narratives/04b_narrative.md`
- Revised `04a_narrative.md` with four expansions requested mid-session
- Identified FAC 976 (Sinai Health) extracted wrong plan — research strategic plan
  captured instead of hospital strategic plan; re-extraction deferred to next session
- Identified open items: Kenora new plan, UHN dates pending, plan audit scan,
  teaching hospital context research, curated distinctive directions registry

---

## 2. 04a — Strategic Homogeneity Analysis

**Script:** `analysis/scripts/04a_homogeneity.R`

**Scope:** Full usable cohort (n=115) and Current era (n=62), run in parallel for
direct comparison. Three analytical lenses applied to binary theme presence vectors.

### Key findings

**Lens 1 — Theme breadth:**
- Full cohort mean: 4.3 themes per hospital (SD 1.30); Current era mean: 4.6 (SD 1.37)
- Narrow range across type groups (4.1–4.9 themes); hospital type does not meaningfully
  predict how many themes a hospital covers
- Breadth is effectively standardized across the sector — hospitals are not choosing
  to be comprehensive or selective in ways that distinguish them from peers

**Lens 2 — Core profiles (themes in ≥50% of type group):**

| Type | Full cohort core | Current era core |
|------|-----------------|-----------------|
| Teaching | RES, WRK, PAT, EDI | RES, WRK, PAT, PAR, EDI |
| Community — Large | WRK, PAT, PAR | WRK, PAT, PAR, INN |
| Community — Small | WRK, PAR, PAT, FIN | WRK, PAR, PAT, FIN |
| Specialty | WRK, PAT, RES, ACC | WRK, PAT, RES, FIN |

Notable changes full → current: INN entered Community — Large core; PAR entered
Teaching core; FIN replaced ACC in Specialty core. Community — Small is perfectly
stable across both scopes.

WRK and PAT are universal — present in every type group's core in both scopes.

**Lens 3 — Pairwise Jaccard similarity:**
- Mean within-type Jaccard: 0.35–0.49 (well above random expectation of ~0.25–0.30)
- Mean between-type Jaccard: 0.389 (full) / 0.395 (current) — stable; type boundaries
  not hardening
- Full vs. current delta: Community — Large converging (+0.019); Teaching diverging
  (-0.048); Community — Small diverging (-0.030); between-type stable (+0.006)
- Teaching divergence is the largest movement: 5-theme current core, only 12% full match

**Interpretation:** Ontario hospital strategic plans occupy a moderate homogeneity
band — more similar than chance, not interchangeable. The sector has genuine two-tier
structure within each type group: table-stakes core themes (WRK, PAT, and type-specific
additions) plus a peripheral tier where individual hospital choices diverge.

### 04a Narrative revisions

Four expansions made mid-session in response to review:

1. **Era framing caveat** — added to Overview: this is a cross-sectional dataset
   of currently posted plans, not longitudinal tracking. Era = the time period the
   currently posted plan was created.

2. **Directions vs. themes distinction** — added to Data and Method: directions are
   the hospital's own words; themes are this project's classifications. 04a operates
   entirely at the theme level; 04b operates at the direction level.

3. **Jaccard formula explanation** — expanded with plain-language walkthrough of
   numerator/denominator and a concrete numeric example (Hospital A = {WRK, PAT, PAR,
   FIN}, Hospital B = {WRK, PAT, INN, INF} → Jaccard = 2/6 = 0.33).

4. **Lens 1 interpretation** — expanded from one sentence to a full paragraph
   explaining why breadth standardization likely reflects Ontario's shared
   accountability framework (Ministry agreements, accreditation, QIP requirements).

5. **Lens 2 interpretation** — substantially expanded to cover: two-tier structure
   (table stakes vs. peripheral choices), what the peripheral tier is actually
   measuring, Teaching hospital mandate complexity, and the interpretive question
   the Community — Small stability raises but cannot answer.

---

## 3. 04b — Unique and Outlier Strategies

**Script:** `analysis/scripts/04b_unique_strategies.R`

**Two-part structure:**
- Part 1 (pure R): theme-level outlier flagging using 04a core profiles
- Part 2 (Claude API): direction-level distinctiveness, one call per theme × type
  cell with ≥5 directions

**Configuration flags:**
```r
PART1_ONLY <- FALSE         # set TRUE to skip API
PERIPHERAL_THRESHOLD <- 25  # themes in <25% of type group = peripheral
MIN_DIRECTIONS_FOR_API <- 5 # minimum directions per cell for API call
```

### Debugging resolved this session

**`hospital_name` not found in `strategy_classified`:** The `.build_theme_matrix()`
function called `distinct()` with `hospital_name` before the `spine_year` join had
brought it in. Fixed by removing `hospital_name` from the `distinct()` call and
joining from `spine_year` after the pivot.

**`hospital_name` not found in `direction_inventory` (Section 9):** Same root cause —
`select()` referenced `hospital_name` before the join. Fixed by dropping it from
the `select()` and appending a `left_join(spine_year)` immediately after.

**FAC prefix contamination in Part 2 output:** Claude returned `"FAC 606"` as the
fac field value (echoing the prompt format `"FAC 606 (Hospital Name): direction"`).
Fixed inline in Section 12 with `gsub("^FAC ", "", ...)` applied to the fac field
during tibble construction — absorbed into the script, no separate patch file needed.

**API 529 overload errors:** Two separate runs each had ~10 cells fail with HTTP 529
(API overloaded). Not a code problem — transient rate limit. Re-run resolved coverage.
Final run: 21 of 23 cells successful (Teaching × WRK and Community — Large × FIN/INF
failed; these were captured in the prior run). Working dataset: 89 distinctive
directions from 21 cells.

### Part 1 key findings

**Missing core themes:** Majority of hospitals in every type group are missing at
least one core theme (56–88% by type). This is high enough that missing one core
theme is not a meaningful outlier signal on its own.

**INN effect in Community — Large:** 7 of 12 Community — Large hospitals flagged
for missing core themes are missing INN only. INN only recently crossed the 50%
threshold; these hospitals are earlier in adoption of a newly emerging norm, not
genuine outliers.

**PAT missing-core pattern — plan architecture, not deprioritization:** 15 of 62
current era hospitals classified as missing PAT. Spot-check of FAC 813 (Stratford),
FAC 983 (Huron Perth), FAC 597/626 (Almonte/Carleton Place shared plan), FAC 905
(Oak Valley) confirmed that PAT content exists throughout these plans but is embedded
within other directions rather than named as a standalone pillar. This is a plan
architecture effect, not genuine deprioritization. Documented as a classification
boundary caveat in the narrative.

**Top theme-level outliers (current era, by composite score):**

| FAC | Hospital | Type | Score | Missing | Peripheral |
|-----|----------|------|-------|---------|------------|
| 976 | Toronto Sinai Health System | Teaching | 7 | WRK, PAT, PAR, EDI | — |
| 948 | Toronto Addiction & Mental Health (CAMH) | Specialty | 7 | WRK, PAT, FIN | EDI |
| 592 | Napanee Lennox & Addington | Comm — Small | 7 | WRK, PAR, FIN | EDI |
| 611 | Blind River North Shore HN | Comm — Small | 7 | WRK, PAT, PAR | EDI |
| 947 | Toronto UHN | Teaching | 6 | WRK, EDI | INF |
| 624 | Campbellford Memorial | Comm — Small | 6 | PAT, PAR, FIN | — |

**Note:** FAC 976 (Sinai) high score is an artefact — wrong plan extracted (research
strategic plan, not hospital strategic plan). Score will change materially once
correct plan is processed. See Section 6.

**Peripheral adopters:** EDI in Community — Small (4 hospitals, all with
Indigenous-serving or minority community context); ACC in Community — Large
(5 hospitals taking on regional access mandates); ORG in Community — Large (2
hospitals in apparent renewal/repositioning phases).

### Part 2 key findings

**89 distinctive directions identified across 21 cells at cost of $0.17 USD.**

**Generic direction archetypes (consistent across cells):** "Invest in our people,"
"Deliver exceptional patient-centred care," "Build strong partnerships," "Ensure
financial sustainability" — broadly true, universally applicable, analytically
interchangeable.

**Most notable distinctive findings:**

- **Sinai Health (FAC 976):** Four distinctive Teaching × RES directions including
  global scientific leadership, new research facility commitment, formal "Sinai Health
  Research" enterprise, and cultural transformation to embed research in organizational
  DNA. **Provisional — based on wrong plan; revise after re-extraction.**

- **SickKids (FAC 837):** "Advancing the era of Precision Child Health" — leading a
  named research paradigm, not just conducting research. "Project Horizon" linking
  innovation to capital redevelopment. "Care isn't just what we do — it's who we are"
  in PAT theme.

- **Barrie RVH (FAC 606):** Explicitly commits to becoming a "regional academic health
  sciences centre" and "full-scale teaching hospital and research institute" — most
  ambitious repositioning claim by any non-Teaching hospital in the dataset.

- **Southlake Regional (FAC 736):** "Data is the most important strategic asset we
  have after people" and "Digital health is health" — distinctive philosophical
  positioning in INN theme.

- **Shared-plan detection:** FAC 813 (Stratford) and FAC 983 (Huron Perth) both
  flagged for identical "Nothing for you, without you" language. These hospitals
  share a plan; the API identified this without being told.

- **Francophone directions:** FAC 978 (Kingston Health Sciences) has two directions
  written entirely in French, reflecting its francophone mandate.

- **Northern/Indigenous-serving hospitals:** Sioux Lookout (FAC 964) names "Mental
  Health & Addictions" as a standalone ACC direction; Manitoulin (FAC 784) explicitly
  names "culturally safe healthcare" in PAT theme. Both adopt INN and EDI peripherally
  in ways consistent with their community contexts.

- **Financial-environmental integration:** Three Community — Large hospitals (Southlake,
  Pembroke, Barrie RVH) explicitly link financial sustainability with environmental
  stewardship — nascent trend not captured in 03b/03c temporal analyses.

- **Blanche River Health (FAC 982):** "The system should work for people rather than
  people navigating the system" — flagged as high-value for white paper use.

### Cross-part synthesis

Hospitals distinctive in both Part 1 (theme level) and Part 2 (direction level):
- **Sinai Health:** Both lenses — provisional pending re-extraction
- **CAMH:** High outlier score + distinctive RES direction (patient/family in research)
- **SickKids:** Unremarkable at theme level; highly distinctive at direction level
- **Barrie RVH:** Unremarkable at theme level; highly distinctive at direction level
- **Northern/Indigenous-serving small hospitals:** Both lenses confirm distinctive
  community-context-driven strategies

**Revised framing agreed:** CAMH and Baycrest distinctiveness is structurally expected
given their specialized mandates — they *should* look different from general acute
hospitals. Teaching hospital "outlier" status partly reflects changing institutional
landscape (medical school affiliations, aspiring community hospitals) requiring
contextual research. See Section 5.

---

## 4. Narrative Voice and Style

`docs/style_guide.md` confirmed in repository (produced in prior session).
Both 04a and 04b narratives are technical narratives (precise, flat, complete)
consistent with established two-narrative model. Publication-facing narratives
for 04a and 04b are deferred — to be written when white paper work begins.

Both narratives include the standardized methodological framing established in
04a review:
- Era-as-cross-section caveat
- Directions vs. themes distinction
- Classification boundary caveats where relevant

---

## 5. Open Items Identified This Session

### Requiring action before 04a/04b finalization

**FAC 976 (Sinai Health) — wrong plan extracted:**
- Research strategic plan was captured, not the hospital strategic plan
- Correct plan has been placed in the folder by Skip
- YAML update to be done via `SOP_new_strategic_plan.md` before next session
- Re-extraction, CSV rebuild, and 04a/04b re-run required
- 04b narrative Sinai findings currently flagged as provisional

**FAC 826 (Kenora Lake of the Woods) — new plan received:**
- New plan received from hospital; YAML update via SOP before next session
- Re-extraction and CSV rebuild required

**FAC 947 (UHN) — plan period dates pending:**
- Email sent requesting confirmation of 2025–2030 assumption
- Dates expected; update registry when received
- Follow up if no response by April 15

### Research items for next session

**Teaching hospital context research:**
- Historical shift in Ontario medical school landscape: new schools established,
  community hospital affiliations created (NOSM ~2005, others)
- Which hospitals in the dataset are formal academic affiliates vs. self-designating
- Which Community — Large hospitals have formal or aspirational academic relationships
- Relevant to: Teaching × WRK/RES interpretation, Barrie RVH repositioning claim,
  Jaccard divergence in Teaching group
- Output: `ontario_teaching_hospital_context.md` in `docs/reference/`

**Plan audit scan:**
- FAC 976 confirms that wrong-document extraction is a real failure mode
- Visual review of downloaded PDFs for hospitals where plan name looks ambiguous
- Particularly: hospitals with research plans, annual reports, quality plans,
  or any document title not clearly "strategic plan"
- Estimated: 15–30 minute manual scan

### Deferred analytical items

**Curated distinctive directions registry:**
- `04b_distinctive_directions.csv` to be extended with curation columns:
  `keep_flag`, `quote_ready` (verbatim language), `white_paper_theme`
- Starter version with flagged candidates to be produced next session
- High-priority candidates already identified: Blanche River "system should work
  for people," Sinai research enterprise directions (pending re-extraction),
  SickKids precision child health, Barrie RVH academic repositioning, Southlake
  "Digital health is health," Manitoulin cultural safety, Sioux Lookout mental
  health specialization

**04a and 04b narrative revisions:**
- Revise Sinai findings in 04b once correct plan is re-extracted
- Revise CAMH/Baycrest cross-part synthesis framing (expected structural outliers,
  not strategic outliers)
- Incorporate teaching hospital context once research is complete
- Both narratives currently accurate but carry provisional flags where noted

---

## 6. Files Created or Changed This Session

| File | Change |
|------|--------|
| `analysis/scripts/04a_homogeneity.R` | New — three-lens homogeneity analysis |
| `analysis/scripts/04b_unique_strategies.R` | New — Part 1 outlier identification + Part 2 API distinctiveness |
| `docs/narratives/04a_narrative.md` | New — with four mid-session expansions |
| `docs/narratives/04b_narrative.md` | New |
| `analysis/outputs/tables/04a_breadth_summary.csv` | New |
| `analysis/outputs/tables/04a_core_profile_by_type.csv` | New |
| `analysis/outputs/tables/04a_modal_match_summary.csv` | New |
| `analysis/outputs/tables/04a_jaccard_summary.csv` | New |
| `analysis/outputs/tables/04a_jaccard_pairwise.csv` | New |
| `analysis/outputs/tables/04b_theme_outliers.csv` | New |
| `analysis/outputs/tables/04b_peripheral_adopters.csv` | New |
| `analysis/outputs/tables/04b_distinctive_directions.csv` | New (89 directions, 21 cells) |
| `analysis/outputs/figures/04a_breadth_distribution.png` | New |
| `analysis/outputs/figures/04a_jaccard_heatmap.png` | New |
| `analysis/outputs/figures/04a_jaccard_density.png` | New |
| `analysis/outputs/figures/04b_outlier_map.png` | New |
| `logs/04b_api_log.csv` | New |

---

## 7. Next Session — Priority Action Plan

### Priority 1 — Data corrections (do first, everything else depends on clean data)
- YAML updates for FAC 976 (Sinai) and FAC 826 (Kenora) via SOP_new_strategic_plan.md
- Re-extract both FACs (Phase 2)
- Rebuild `strategy_master_analytical.csv` and `strategy_classified.csv`
- Re-run `04a_homogeneity.R` and `04b_unique_strategies.R`
- Update registry with UHN dates when received

### Priority 2 — Teaching hospital context research
- Web search block (~30–45 min)
- Produce `docs/reference/ontario_teaching_hospital_context.md`

### Priority 3 — Narrative revisions
- Revise 04b Sinai findings based on correct plan results
- Revise CAMH/Baycrest framing in cross-part synthesis
- Incorporate teaching hospital context into both narratives

### Priority 4 — Curated distinctive directions registry
- Produce `analysis/outputs/tables/04b_curated_directions.csv` with curation columns
- Flag high-priority candidates for white paper use
- Skip reviews and marks keepers

### Priority 5 — Plan audit scan
- Visual scan of downloaded PDFs for ambiguous plan titles
- Flag any additional wrong-document captures for re-extraction

### Priority 6 — Session end checklist items
- Upload all files from this session to project knowledge repository
- Fundamental document refresh (ProjectStructure.md, Project_Outline, StrategyPipelineReference)
  — still deferred from April 8; schedule before foundational documents role begins

---

## 8. Session End Checklist

- [ ] Upload `SessionSummaryApril092026.md` to project knowledge repository
- [ ] Upload `analysis/scripts/04a_homogeneity.R`
- [ ] Upload `analysis/scripts/04b_unique_strategies.R`
- [ ] Upload `docs/narratives/04a_narrative.md`
- [ ] Upload `docs/narratives/04b_narrative.md`
- [ ] Upload `docs/style_guide.md` (if not already uploaded from prior session)
- [ ] Upload `analysis/outputs/tables/04a_breadth_summary.csv`
- [ ] Upload `analysis/outputs/tables/04a_core_profile_by_type.csv`
- [ ] Upload `analysis/outputs/tables/04a_modal_match_summary.csv`
- [ ] Upload `analysis/outputs/tables/04a_jaccard_summary.csv`
- [ ] Upload `analysis/outputs/tables/04b_theme_outliers.csv`
- [ ] Upload `analysis/outputs/tables/04b_peripheral_adopters.csv`
- [ ] Upload `analysis/outputs/tables/04b_distinctive_directions.csv`
- [ ] YAML updates for FAC 976 and FAC 826 via SOP before re-extraction
- [ ] Push all changes to GitHub
- [ ] Plan audit scan (visual review of ambiguous PDF titles)
- [ ] Follow up on FAC 947 (UHN) if no response by April 15
