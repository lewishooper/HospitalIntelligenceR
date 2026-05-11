# HospitalIntelligenceR
## Session Summary — HIT Scatter Plot and Strategy-Finance Linkage Design
*May 10, 2026 | For Claude Project Knowledge Repository*

---

## 1. Session Overview

This session had two threads: finalizing the HIT quadrant scatter plot figure
and companion outlier table, and scoping the analytical approach for linking
hospital financial trajectories to strategic directions. No new analytical
scripts were built. The session produced a polished version of
`fig_hit_01_scatter.R` and established the design framework for the
strategy-finance linkage analysis.

---

## 2. HIT Quadrant Scatter Plot — Changes Applied

### Figure (`fig_hit_01_scatter.png`)

| Item | Decision |
|------|----------|
| Excluded hospitals | Hardcoded FACs 854, 971 (structural outliers), 701 (capital project), 938 (amalgamation/MOHLTC review) — plot-only exclusion |
| Axis units | Changed from pp to % throughout (`label_percent(scale = 1, accuracy = 1)`) |
| Threshold labels | Updated to +5% / −5% |
| Y-axis inversion | Retained — expense improvement reads upward |
| Legend labels | Revenue-led → *Revenue gains*; Expense-led → *Expense cuts*; Cost pressure retained |
| Structural outlier in legend | Removed via `drop = TRUE` in `scale_colour_manual()` |
| Source line | Shortened to `HospitalIntelligenceR` (dropped `HIT extraction`) |
| Title | Two-line: `"How Ontario hospitals dealt with financial pressures,\n 2018/19–2024/25"` |
| Subtitle | `\n` inserted between "sector" and "median, 2018/19–2024/25" |
| Caption | Excluded hospitals not named — `Excluded outliers shown separately` |
| Quadrant shading | On hold pending Cost pressure classification review |
| labs() wording | Skip's exact wording carried verbatim — further title tweaks deferred to Skip's local edit |

### Companion Outlier Table (`tbl_hit_01_outliers.png`)

| Item | Decision |
|------|----------|
| FAC column | Dropped — hospital name only |
| Footer text colour | White (was grey50) |
| Footer background | Dark grey (#333333) so white text is legible |
| Row height | Increased via `height(height = 0.40)` + `hrule(rule = "exact")` to prevent wrapped text collision |
| Columns | Hospital, Type, Revenue (%), Expenses (%), Note (blank for manual annotation) |

---

## 3. Quadrant Definitions — Completed

All five quadrant definitions written in technical register, matching the
style established for the strategy analytical narratives:

- **Revenue gains** (`cum_adj_rev > +5pp`): Top-line outperformance vs field
- **Expense cuts** (`cum_adj_exp < −5pp`): Costs held below field pace
- **Both** (intersection of above two): Dual mechanism
- **Neither** (both within ±5pp): Field-tracking
- **Cost pressure** (`cum_adj_exp > +5pp` OR `cum_adj_rev < −5pp`): See open
  item below

### Open Item — Cost Pressure Classification Logic

The current `case_when` fires Cost pressure on **either** expense worsening
OR revenue decline. This creates interpretive ambiguity — some red dots on
the plot have negative cum_adj_exp (expense improvement) but are classified
Cost pressure because revenue fell below field. Three options identified:

| Option | Description | Status |
|--------|-------------|--------|
| A | Split into two quadrants: expense-driven vs revenue-driven | Adds sixth populated quadrant |
| B | Expense-only definition; revenue-declining hospitals fall to Neither | Cleaner but loses visibility |
| C | Keep logic, clarify label (e.g. *Under pressure* / *Deteriorating*) | Low-code-change |

**Not yet decided** — review the live plot output and revisit.

---

## 4. Conceptual Clarification — Field Adjustment

Confirmed and documented for narrative use:

> Each axis shows cumulative deviation from the **sector-wide** field median
> (all hospitals together, not by type). The purpose is to remove year-level
> effects that hit all hospitals simultaneously — MOH funding rounds, COVID
> revenue spikes — so what remains is each hospital's **relative** trajectory
> compared to the full peer group.

This is distinct from a type-stratified adjustment. "Deviation from the
sector median" is the correct and precise label.

---

## 5. Strategy-Finance Linkage — Design Framework

### Core analytical question
Do hospitals with FIN-themed strategic directions outperform (or underperform)
peers on cumulative field-adjusted financial trajectories?

### Causal identification caveat
The data cannot distinguish direction of causality:
- **Horn 1**: Strategic focus on finance drives better outcomes (strategy → performance)
- **Horn 2**: Poor financial performance prompts embedding a FIN direction (performance → strategy)

**Posture adopted**: Frame all findings as association, not causation. Use
pre-plan HIT trajectory as a covariate to partially control for prior
performance. Causal caveat documented as Interpretive Limits, not as a fatal
flaw.

### Analytical design (agreed)

| Layer | Approach | Purpose |
|-------|----------|---------|
| Primary | Quadrant × theme prevalence crosstab | Readable headline finding for practitioner audience |
| Secondary | Continuous score (cum_adj_rev, cum_adj_exp) regression with FIN flag | Tests whether degree of outperformance associates with strategic emphasis |
| Control | Pre-plan HIT baseline scores | Partial control for prior trajectory |
| Join key | FAC (character throughout) | Links strategy_classified.csv to hit_01_field_trajectories.csv |

### Temporal matching rule (agreed)
Strategy plans must meaningfully overlap the HIT window (2018/19–2024/25)
to be included in the linkage analysis. Hospitals with no usable plan dates
are excluded from the pre/post analysis but eligible for cross-sectional
comparison if HIT data is present.

### Next analytical script
`hit_02_strategy_join.R` — three-way join of strategy_classified.csv,
hit_master.csv, and the fiscal-year bridge. Produces
`hit_strategy_analytical.csv` as the master analytical dataset for
Steps 4–7 of the HIT Analytics Project Plan.

---

## 6. Exploratory Dev Work — Next

Before building `hit_02_strategy_join.R`, Skip will do exploratory data
work in a dev context to ground himself in the HIT trajectory data.
This work is **informal and does not require written documentation** but
will involve Claude assistance as it develops. No specific scripts have
been scoped; the work will be driven by what the data surfaces.

---

## 7. Files Changed This Session

| File | Change |
|------|--------|
| `roles/hit/scripts/fig_hit_01_scatter.R` | Full rewrite — exclusions hardcoded, % axes, legend relabelled, companion table updated |

---

## 8. Open Items Carried Forward

| Item | Priority |
|------|----------|
| Cost pressure classification decision (split / redefine / relabel) | Before narrative is written |
| Skip's local title/subtitle edits to `labs()` — pass final wording back | Before figure is finalized |
| FAC 701 and FAC 938 notes column — confirm explanations for outlier table | Before table is published |
| Explore HIT trajectory data (dev, informal) | Next |
| Build `hit_02_strategy_join.R` | After dev exploration |
| Quadrant shading review (tied to Cost pressure resolution) | After Cost pressure resolved |

---

## 9. Session End Checklist

- [ ] Upload `SessionSummaryMay102026.md` to knowledge repository
- [ ] Upload `roles/hit/scripts/fig_hit_01_scatter.R` to knowledge repository
- [ ] Push all changes to GitHub
