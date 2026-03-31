# How to Use the Strategic Planning Documents — Analytical Review
## Response to Skip's Proposed Directions
*Draft for Discussion — March 2026*

---

## Prefatory Note

Skip's six analytical directions form a coherent and well-sequenced research agenda — moving from descriptive comparison (what do plans look like?) through identification of distinctiveness (what's different?) to trend analysis (what's changing?) and finally to impact analysis (does strategy actually matter?). The progression from descriptive to causal is exactly right, and the later stages depend on the earlier ones being done well.

The literature review is relevant context here. Denis, Langley & Lozeau's (1991, 1995) core finding — that Ontario hospital strategic plans tend to be ambiguous, consensus-driven, and politically shaped — is both a caution and an opportunity. It's a caution because it means we should not assume that stated directions reflect genuine organizational distinctiveness. It's an opportunity because systematic analysis across 129 hospitals may reveal patterns that no single-institution study ever could.

---

## Direction 1 — Comparative Analysis Between Hospital Types

### 1a. Plan volume vs. hospital size

**Pros:**
- Highly tractable analytically — we have character counts and direction counts already in the master CSV, and hospital type/size data is publicly available from CIHI and the MOH
- Likely to produce a clean, publishable descriptive finding; the observation that smaller hospitals produce thinner plans is consistent with Denis et al. and with our own Phase 2 data (several small hospitals returned `thin` or minimal extractions)
- Sets a credible methodological foundation for everything that follows — if plan volume correlates with size, we need to control for that in all downstream comparisons
- Low analytical risk — even a null finding (no correlation) is informative

**Cons:**
- Page/character count is a proxy for quality, not quality itself — a 3-page plan with sharp, well-differentiated directions may be more strategically meaningful than a 30-page document full of boilerplate
- Some of our thin results may reflect extraction failures (image PDFs) rather than genuinely thin plans — we need to resolve the fine-tuning pass before treating `thin` as a reliable signal of plan brevity
- Hospital "size" is multidimensional in Ontario (beds, volumes, budget, rurality, designation) — need to agree on which dimension to use as the primary comparator

**Recommendation:** Do this first. Direction count per hospital is a clean, already-available variable. Consider beds or CIHI peer group as the size proxy — both are publicly available.

---

### 1b. Direction types by hospital size/type

**Pros:**
- The hypothesis is well-grounded and testable: that small hospitals over-index on workforce retention and financial sustainability relative to larger hospitals. This is consistent with the literature on rural and small hospital governance pressures in Canada
- If confirmed, this finding has genuine policy relevance — it suggests that small hospitals are in a structurally different strategic position, not just a scaled-down version of the large hospital experience
- Our `direction_type` field (direction vs. enabler) and `direction_name` field give us the raw material; thematic coding of direction names is the analytical step required
- Teaching hospital academic directions should be easy to isolate — they're lexically distinct ("education," "research," "academic," "teaching") and rare outside that group

**Cons:**
- Requires a thematic coding scheme for direction names — this is the hardest analytical step in the whole project. Direction names across 129 hospitals use highly variable language for what may be the same underlying theme ("People & Culture," "Our People," "Workforce Excellence," "Talented Teams" are all the same theme). Claude can help with this classification, but it will require careful prompt design and human review
- The `direction_name` field captures the label, not always the substance — two hospitals with the same label ("Quality & Safety") may have very different underlying content. The `direction_description` and `key_actions` fields will be needed to validate theme assignments
- Risk of confirmation bias: the small-hospital workforce/finance hypothesis feels right, but it needs to be tested, not assumed

**Recommendation:** This is the core comparative analysis and worth doing rigorously. Propose building a thematic taxonomy of ~8–12 direction themes as a first step, then classifying all directions into that taxonomy using Claude API. That classification then becomes the basis for all comparisons.

---

### 1c. Standard set of directions across all hospitals

**Pros:**
- A "canonical Ontario hospital strategy" finding — if it exists — would be a strong and practically useful output. It would tell funders, boards, and policymakers what the consensus strategic agenda looks like
- The literature predicts this will exist: Denis et al. noted plans are politically shaped and consensus-driven; Ontario's accountability framework (QIP, Ontario Health agreements) creates convergence pressure
- Could be structured as a core set + riders model, which is a genuinely novel analytical contribution

**Cons:**
- The convergence predicted by the literature may make the "standard directions" finding unsurprising — the interesting finding may actually be in the deviations (Direction 2)
- Need to be careful not to confuse terminological convergence (everyone says "Patient Experience") with substantive convergence (everyone actually means the same thing by it) — the description and actions fields will be needed to validate
- The "riders" for different groups requires the hospital classification system to be well-defined first (academic, community large, community small, rural, specialty, rehabilitation, etc.)

**Recommendation:** Frame this as the synthesis output from 1b rather than a standalone analysis. Once thematic classification is done, the standard + riders structure falls out naturally.

---

## Direction 2 — Identification of Truly Unique Strategies

**Pros:**
- This is potentially the most intellectually interesting output — the outliers, not the consensus, are where strategic distinctiveness lives
- Practically useful for benchmarking: hospital boards and executives can see whether their strategic choices are genuinely differentiated or just restatements of sector-wide consensus
- With 129 hospitals, there's enough volume to make "unusual" statistically meaningful — a direction theme appearing in fewer than 5% of hospitals is genuinely rare
- The `direction_description` and `key_actions` fields give us the content to distinguish genuine distinctiveness from mere labelling differences

**Cons:**
- Lexical uniqueness ≠ strategic uniqueness. The hardest analytical challenge here is distinguishing a hospital that's doing something genuinely different from a hospital that's just using different words for the same thing. This requires reading descriptions and actions, not just direction names
- Genuinely unique strategies may reflect local context (a hospital serving a First Nations community, a hospital in a resource industry town) rather than strategic innovation — both are interesting but for different reasons
- Some apparent uniqueness may be artefacts of our extraction — if a hospital's plan was poorly structured or partially extracted, unusual direction names may reflect extraction noise rather than genuine strategy

**Recommendation:** High priority, but should follow the thematic classification work in Direction 1. Uniqueness is only identifiable against a background of what's normal. Consider flagging for human review rather than fully automated classification.

---

## Direction 3 — Trend Analysis Over Time

### 3a. Volume of plans over time

**Pros:**
- Completely tractable with current data — `plan_period_start` and `plan_period_end` are already in the master CSV
- Will quickly reveal whether we have enough temporal spread for meaningful trend analysis
- Sets realistic expectations for Directions 3b and 3c before significant analytical effort is invested

**Cons:**
- Our collection reflects plans *current as of 2025–2026*, not a true longitudinal panel. Many hospitals will have one plan in our data; some with legacy files may have earlier plans. The temporal spread may be narrow (most plans will be 2021–2026 vintage, reflecting post-COVID planning cycles)
- The 20260101 placeholder dates on legacy files will create noise in any temporal analysis — those need to be cleaned or flagged before time-based analysis

**Recommendation:** Do this early as a feasibility check. A simple frequency table of plan_period_start years will tell us within minutes whether we have enough spread for trend analysis. My expectation is that we are predominantly looking at one planning generation (2020–2025), which limits but does not eliminate trend analysis.

---

### 3b–3c. Emerging/disappearing strategies and specific theme trends

**Pros:**
- If temporal spread is sufficient, this is the highest-impact analytical direction — trend findings (e.g., "equity directions have increased significantly since 2020") have direct policy relevance and strong publication potential
- Specific hypotheses about recruitment, quality, finance, and equity are well-grounded: the COVID-19 pandemic created documented shifts in hospital strategic priorities, and Ontario's explicit equity requirements under the ECFA and subsequent policy frameworks should be traceable in plan content
- The `key_actions` field gives finer-grained temporal signal than direction names alone — an equity direction with actions focused on Indigenous cultural safety is a different signal than one focused on staff diversity training

**Cons:**
- The fundamental limitation is cross-sectional vs. longitudinal data. We are comparing different hospitals' plans from different years, not tracking the same hospital's strategy over time. This is an ecological trend analysis, not a panel study — the conclusions need to be framed accordingly
- Confounding: plan year correlates with hospital size (larger hospitals update plans more regularly) and with external shocks (COVID disrupted many planning cycles). These confounders need to be acknowledged
- The Ontario Health/LHIN system reorganization in 2019 may itself have driven a strategic planning refresh across the sector — this could create an artificial "trend" that is really just a planning cycle artifact

**Recommendation:** Proceed with appropriate epistemic humility about what cross-sectional temporal comparison can and cannot establish. Frame as "changing emphasis" rather than "causal trend." Still worthwhile and likely publishable with proper framing.

---

## Direction 4 — Board Minutes: Do Boards Actually Use Their Strategic Plans?

**Pros:**
- This is the most theoretically important direction in the entire agenda. The Denis et al. (1991, 1995) literature predicts that plans are often symbolic rather than operative — testing this directly with board minutes data would be a genuine contribution to the Canadian health governance literature
- The hypothesis is sharp and falsifiable: do the words and concepts from the strategic plan appear in board minutes? Do boards reference their plan when making decisions? This can be operationalized
- If a positive finding emerges (boards do actively engage with strategy), it validates the entire analytical enterprise. If a negative finding emerges (plans sit on the shelf), it's equally important and publishable

**Cons:**
- This is entirely dependent on the board minutes role being built and producing usable data — it's the most ambitious of the five roles in terms of document acquisition and content extraction
- Board minutes are the least standardized document type in the project. Unlike strategic plans (which follow recognizable conventions), minutes vary enormously in format, detail, and availability
- The linkage analysis (plan → minutes) requires matching terminology across documents, which is a non-trivial NLP problem — "our strategic priority around patient experience" in minutes refers to the same thing as "Exceptional Patient Experiences" in the plan, but algorithmically connecting them requires careful work
- Availability: some hospitals publish detailed minutes; many publish only brief summaries or nothing at all

**Recommendation:** Flag as a high-priority research question, but acknowledge it is dependent on the board minutes role and will likely be feasible for only a subset of hospitals. Consider a case study approach (10–15 hospitals with good minutes availability) rather than a full-sector analysis.

---

## Direction 5 — CIHI Data: Does Quality Strategy Predict Quality Performance?

**Pros:**
- This is the most rigorous causal test in the agenda and potentially the most impactful finding. If hospitals with explicit quality-focused directions show measurably different CIHI performance trajectories, that's evidence that strategy has operational bite — directly contradicting the "shelf of dreams" hypothesis
- CIHI data is publicly available, well-standardized, and already used extensively in Ontario hospital benchmarking — the linkage to FAC codes is straightforward
- The `key_actions` field may provide a finer-grained predictor than direction names alone: hospitals with specific, measurable actions around quality may show different performance than hospitals with vague directional language

**Cons:**
- Causality is almost impossible to establish cleanly. Hospitals with better CIHI performance may also be better-resourced organizations that produce better strategic plans — the plan may be a symptom of organizational capacity, not a cause of quality improvement
- Time lag: strategic plans typically take 2–3 years to show operational impact. Without knowing when the plan was implemented and when CIHI performance was measured, any correlation is temporally ambiguous
- Selection bias: hospitals under performance pressure may be more likely to adopt explicit quality strategies — this would create a negative correlation between quality strategy and current performance (not because strategy hurts quality, but because it's reactive)
- The CIHI composite indicators mask a lot of variation — which indicators to use, and how to aggregate them, will significantly affect findings

**Recommendation:** Treat as a long-term research direction rather than an immediate deliverable. Frame as correlational, not causal. Requires careful indicator selection and a clear temporal logic (plan dates vs. CIHI measurement periods). Consider a restricted analysis using only hospitals where we have solid plan content (full or partial quality, not thin) and CIHI data for the plan period.

---

## Direction 6 — HIT Tool Data: Financial Strategy and Financial Performance

**Pros / Cons:** The same logic as Direction 5 applies here, with one additional consideration. Financial strategy in Ontario hospital plans is partly endogenous to the funding environment — all hospitals face the same Ministry-set funding constraints and the same HSAA balanced-budget requirements. A hospital with an explicit financial sustainability direction may simply be one that is already under financial stress, making correlation with HIT performance potentially tautological.

That said, there may be genuine signal in the *specificity* of financial actions (hospitals that name specific efficiency initiatives vs. hospitals with vague "financial sustainability" language) — this is worth exploring once Direction 1 thematic analysis is complete.

**Recommendation:** Lower priority than Directions 1–4. Revisit after the thematic classification work reveals how widespread and how specific financial directions actually are across the sector.

---

## Overall Sequencing Recommendation

| Phase | Directions | Prerequisite |
|-------|-----------|-------------|
| **Phase A** | 1a, 3a | Current data — can start now |
| **Phase B** | 1b, 1c, 2 | Thematic classification scheme built and applied |
| **Phase C** | 3b, 3c | Phase A temporal feasibility confirmed |
| **Phase D** | 5, 6 | External data linkage (CIHI, HIT) |
| **Phase E** | 4 | Board minutes role complete |

The thematic classification scheme — building a taxonomy of ~8–12 Ontario hospital strategic direction themes and coding all 540+ direction rows against it — is the critical path item that unlocks Phase B and C work. This is a natural Claude API task and should be designed carefully as a Phase 3 deliverable for the strategy role.

---

## Note on Three Additional Data Sources

Skip has flagged three potential additional roles or data collections for separate discussion:
1. Quality Improvement Plans (QIPs) — publicly available
2. Accountability Agreements — availability uncertain
3. A third source not yet specified

These warrant a dedicated planning conversation before any build decisions are made. QIPs in particular are highly relevant to Directions 4 and 5 above — they are the operational layer between strategy and performance and may be the most analytically productive linkage dataset in the project.
