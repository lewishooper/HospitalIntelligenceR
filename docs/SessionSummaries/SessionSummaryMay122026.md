# HospitalIntelligenceR
## Session Summary — HIT Dev Exploration: Trend Table and Basic Scatter
*May 12, 2026 | For Claude Project Knowledge Repository*

---

## 1. Session Overview

Informal dev exploration session focused on building intuition for the HIT
trajectory data ahead of the strategy-finance linkage work. Two deliverables
produced: a publication-quality summary statistics table and an exploratory
scatter plot of the revenue × expense trajectory space. Session conducted
remotely on a laptop (single screen). No new analytical scripts were added
to the main pipeline.

---

## 2. Trend Summary Table — `dev/tbl_hit_trend_summary.R`

### Scope decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Hospital scope | Acute only (Teaching, Community Large, Community Small) | Specialty hospitals lack reliable volume indicators; NA is analytically defensible |
| Outlier exclusions | FAC 854, 971, 701, 928 | Structural outliers confirmed from prior sessions |
| Indicators | Revenue Trend (pp), Expense Trend (pp), Patient Day Change (%), ER Visit Change (%) | Revenue/expense from trajectories file; volume pulled fresh from hit_master |
| Table organisation | Indicator outer sort, hospital type group inner sort | Allows Revenue and Expense to read as a pair; volume pair below |
| Summary row label | "All Acute Hospitals" | Distinct from prior "All Hospitals" to reflect scope |

### Key design choices

- Patient day and ER visit changes pulled directly from `hit_master.csv`
  using the same first-to-last fiscal year % change method as hit_01
  Section 3B. This keeps `hit_01_field_segmentation.R` stable and makes
  the table script self-contained.
- `flextable` with `std_flextable()` pattern from `figure_standards.md`.
- Row banding at indicator block level (4 rows per block: All Acute +
  3 type groups). All Acute rows bolded with darker grey (#E8E8E8).
- NA cells display as em-dash (—).
- Output: `roles/hit/outputs/figures/publication/tbl_hit_trend_summary.png`

### Volume data coverage (confirmed from console output)

Quartile distribution for patient days was clean:
- Q1 (fell most): 29 hospitals
- Q2/Q3 (middle): 57 hospitals
- Q4 (grew most): 29 hospitals
- No data: 2 hospitals

Coverage is strong for acute hospitals. The 2 no-data hospitals are expected
edge cases, not a data quality concern.

---

## 3. Clinical Framing — Volume Indicators

Important analytical framing established for all subsequent HIT work:

- **Weighted cases** (not available in HIT data) are the gold standard for
  measuring acuity and productivity. Higher average weight = higher acuity.
- **ER visits** are the best available proxy for demand pressure — not
  capacity-constrained, responsive to community need.
- **Acute patient days** are useful but upper-bounded by bed availability;
  interpret as utilization, not demand.
- **Specialty hospitals**: accept NA for both volume indicators; do not
  attempt imputation or substitution.
- This framing should be documented in the Interpretive Limits section of
  any HIT narrative.

---

## 4. Basic Scatter Plot — `roles/hit/scripts/fig_hit_01_basic_scatter.R`

A new, simplified scatter script was created alongside the existing
`fig_hit_01_scatter.R`. The basic scatter is an exploratory tool, not a
publication figure.

### Design

- X axis: `cum_adj_rev` (cumulative field-adjusted revenue, pp)
- Y axis: `cum_adj_exp` (cumulative field-adjusted expenses, pp) — **not reversed**
- Colour: volume change quartile (red / yellow / green / grey)
- No legend in figure — subtitle carries colour key in plain text
- No quadrant shading or threshold corridors in final version
- Acute hospitals only; four structural outliers excluded

### Outlier FAC list — confirmed this session

| FAC | Hospital | Reason |
|-----|----------|--------|
| 854 | SA Grace Toronto | COVID-era transitional care expansion |
| 971 | Sudbury St. Joseph's Continuing Care | COVID-era transitional care expansion |
| 701 | [Capital project] | Large construction onboarding |
| 938 | Dysart et al Haliburton Health Services | Amalgamation / MOHLTC review |

**FAC 928 (Perth and Smith Falls) is NOT an outlier — retained in analysis.**
Earlier confusion between 928 and 938 is now resolved.

### Iterations this session

| Version | Change |
|---------|--------|
| v1 | Basic scatter, all hospitals, no colour |
| v2 | Added quadrant shading and threshold corridors |
| v3 | Removed shading and corridors; unflipped y-axis; symmetric axis limits from data |
| v4 | Coloured by patient day quartile (ind45) |
| v5 | Switched colour to ED visit quartile (ind56) |
| v6 | Zoomed axes to −20pp / +30pp on both axes to expose dense cluster |
| v7 | Returned to patient day quartile on zoomed axes |

### Output

`roles/hit/outputs/figures/publication/fig_hit_01_basic_scatter.png`

---

## 5. Analytical Finding — Volume and Revenue Relationship

**No visually striking pattern emerged** between volume change quartile
(either patient days or ED visits) and revenue/expense trajectory position.

A slight concentration of Q4 hospitals (volume grew most) on the positive
revenue side was visible but weak. This is consistent with the Ontario
funding model:

- Global budgets and QBP funding mean revenue does not respond proportionally
  to volume the way a fee-for-service system would.
- The field-adjustment removes the common COVID recovery signal, leaving only
  relative performance — a hospital that grew visits at the sector rate sits
  at zero on the x-axis regardless of absolute volume.

**Conclusion:** Volume growth is not a reliable predictor of revenue
outperformance in this dataset. This is a finding in itself — not a data
quality problem — and should be noted in the HIT narrative as context for
the funding model discussion.

---

## 6. Next Steps — Strategy-Finance Linkage

The exploratory dev work has served its purpose. The trajectory data is
well-understood and the scatter space is interpretively grounded.

The primary analytical question driving the next phase is:

> **Do hospitals with specific strategic directions — particularly FIN
> (Financial Stewardship) or PAT/ACC (Patient Access) — cluster differently
> in the revenue × expense trajectory space compared to hospitals without
> those directions?**

### Planned approach

| Step | Script | Output |
|------|--------|--------|
| 1 | `hit_02_strategy_join.R` | Three-way join: `strategy_classified.csv` + `hit_01_field_trajectories.csv` + plan date bridge → `hit_strategy_analytical.csv` |
| 2 | Crosstab analysis | Quadrant × theme prevalence; headline finding for practitioner audience |
| 3 | Continuous score analysis | `cum_adj_rev` and `cum_adj_exp` by FIN flag; test whether degree of outperformance associates with strategic emphasis |
| 4 | Scatter with strategy colour | Return to basic scatter; colour by FIN or PAT/ACC presence rather than volume quartile |

### Key design constraints carried forward

- FAC as character throughout — no exceptions
- Temporal matching: strategy plans must meaningfully overlap 2018/19–2024/25
  HIT window to be included in pre/post analysis
- Causal caveat: frame all findings as association, not causation; use
  pre-plan HIT baseline as partial control for prior trajectory
- Acute hospitals only for primary analysis; Specialty handled separately
  if at all

---

## 7. Files Produced This Session

| File | Location | Status |
|------|----------|--------|
| `tbl_hit_trend_summary.R` | `dev/` | Complete — exploratory, not in main pipeline |
| `fig_hit_01_basic_scatter.R` | `roles/hit/scripts/` | Complete — exploratory figure |

---

## 8. Open Items Carried Forward

| Item | Priority |
|------|----------|
| Build `hit_02_strategy_join.R` | Next session Priority 1 |
| Cost pressure classification decision (split / redefine / relabel) | Before `fig_hit_01_scatter.R` narrative is written |
| FAC 701 and FAC 938 notes column — confirm explanations for outlier table | Before outlier table published |
| Skip's local title/subtitle edits to `fig_hit_01_scatter.R` labs() | Before figure finalized |
| Quadrant shading review (tied to Cost pressure resolution) | After Cost pressure resolved |

---

## 9. Session End Checklist

- [ ] Upload `SessionSummaryMay122026.md` to knowledge repository
- [ ] Upload `dev/tbl_hit_trend_summary.R` to knowledge repository
- [ ] Upload `roles/hit/scripts/fig_hit_01_basic_scatter.R` to knowledge repository
- [ ] Push all changes to GitHub
