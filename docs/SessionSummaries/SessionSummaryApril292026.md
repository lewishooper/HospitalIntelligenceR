# HospitalIntelligenceR
## Session Summary — HIT Analytics Design
*April 29, 2026 | For Claude Project Knowledge Repository*

---

## 1. Session Overview

This session was a planning and design session — no code was written. The work
covered four areas: project priority stack review, HIT analytics program design,
indicator classification, and the treatment variable and fiscal year bridge
definitions for the strategy-finance linkage. The session produced a complete
project plan document and locked all design decisions through Step 2 of the
analytical sequence.

**Primary accomplishments:**
- Project priority stack revised and agreed
- HIT Analytics Project Plan written and saved
  (`docs/programming_reference/HIT_Analytics_Project_Plan.md`)
- All 74 HIT indicators reviewed and classified
- PSC terminology clarified; ind05 selected as lead margin indicator
- FIN treatment variable defined
- Fiscal year bridge rule defined
- Step 3 (`hit_01_field_segmentation.R`) fully scoped including service volume
  dimension — ready to build next session

---

## 2. Revised Project Priority Stack

| Priority | Item | Notes |
|----------|------|-------|
| 1 | HIT analytics — strategy-finance linkage | Active |
| 2 | Project Outline update | HIT now complete — outline still shows "Not started" |
| 3 | Foundational documents role | Held — value vs board minutes still an open question |
| Last | 04a/04b publication narratives | No deadline pressure |
| Closed | FAC 947 (UHN) / FAC 862 (Women's College) | Terminal status — Skip assigns dates and documents decisions |

---

## 3. HIT Analytics Program Design

The full analytical program is documented in
`docs/programming_reference/HIT_Analytics_Project_Plan.md`. The analytical
sequence agreed this session:

| Step | Script | Description |
|------|--------|-------------|
| 1 | — | Indicator review and classification (complete this session) |
| 2 | — | FIN treatment variable and fiscal year bridge (complete this session) |
| 3 | `hit_01_field_segmentation.R` | Field-level financial performance segmentation — standalone deliverable |
| 4 | `hit_02_strategy_join.R` | Strategy-HIT analytical join |
| 5 | `hit_03_fin_crosssection.R` | Cross-sectional FIN vs non-FIN |
| 6 | `hit_04_fin_prepost.R` | Pre/post with field adjustment |
| 7 | `hit_05_decomposition.R` | Expense vs revenue decomposition |

Step 3 is a standalone deliverable — strategy-agnostic, publishable on its
own. It is also the reference frame that makes the strategy-linked analysis
in Steps 5–7 interpretable.

---

## 4. Indicator Classification — Agreed Set

All 74 indicators reviewed. 19 absent indicators confirmed as LTCH and
Community service indicators — not applicable to the acute hospital registry.
55 active indicators classified.

### Primary analytical variables

| ind | ShortName | Role |
|-----|-----------|------|
| 01 | TotRev | Total revenue — top line |
| 02 | TotExp | Total expenses |
| 05 | TotMarginHospital | Lead performance indicator — hospital PSC 1 only |
| 06 | PctNonMOHRev | MOH revenue backout — derived field |

### Supporting / decomposition

| ind | ShortName | Role |
|-----|-----------|------|
| 03 | OpMargin | Cross-check on ind05 |
| 04 | TotMargPSC | Monitor gap vs ind05 — flags multi-program operators |
| 07 | CurrentRatio | Liquidity context |
| 08 | WorkingCap | Liquidity in dollar terms |
| 12 | pctUPPMOSComp | Labour cost share — primary expense decomposition |
| 13 | pctMDNPStaffComp | Labour cost share — physician/NP component |
| 18 | PctContractedOut | Outsourcing as cost lever |
| 35 | TotFTE | Workforce size |

### Service volume (new addition this session)

| ind | ShortName | Role |
|-----|-----------|------|
| 45 | AcutePtDays | Primary volume denominator — service proxy |
| 54 | TotSurgCases | Secondary service check |

### Derived fields (computed in scripts)

| Field | Formula | Purpose |
|-------|---------|---------|
| `moh_rev` | `TotRev × (1 − PctNonMOHRev / 100)` | MOH-sourced revenue in dollars |
| `non_moh_rev` | `TotRev × (PctNonMOHRev / 100)` | Non-MOH revenue in dollars |
| `cost_per_pt_day` | `TotExp / AcutePtDays` | Efficiency metric — critical for interpreting expense changes |

**Note on MOH revenue:** There is no direct MOH revenue indicator in HIT.
MOH revenue is backed out from ind01 (TotRev) and ind06 (PctNonMOHRev).
The derived value carries the measurement error of two indicators — documented
as a limitation in the technical narrative.

**Note on PSC:** PSC = Program Service Category — the Ministry's classification
of hospital services into reporting buckets. PSC 1 is core acute care. Many
hospitals operate multiple PSCs (community programs, LTC, mental health etc.).
ind05 (TotMarginHospital) covers PSC 1 only, making it the cleanest comparator
across the acute hospital population. ind04 is retained to monitor the gap —
a large ind04 vs ind05 difference flags a multi-program operator.

---

## 5. Step 2 Design Decisions — Locked

### FIN Treatment Variable

- Treatment = `primary_theme == "FIN"` for at least one direction per hospital
- Secondary theme excluded from treatment definition
- Hospital-level flag: `any(primary_theme == "FIN", na.rm = TRUE)` after
  grouping by FAC
- Sensitivity check (primary OR secondary) available as a future option —
  not part of primary analysis

### Fiscal Year Bridge Rule

- `plan_start_year = Y` → first treatment year = `"Y/Y+1"`
- `"Y-1/Y"` dropped as transition year — excluded from both pre and post windows
- Pre-treatment: all HIT fiscal years before `"Y-1/Y"`
- Treatment window: `"Y/Y+1"` through `"plan_end_year/plan_end_year+1"`
- **Documented assumption:** Month-level plan launch dates are unavailable for
  most hospitals. The conservative rule errs toward not crediting pre-plan
  financial movement as a treatment effect. This is noted in the technical
  narrative.

---

## 6. Step 3 Design — `hit_01_field_segmentation.R`

Full scope agreed. Key design elements:

### Analytical approach

For each hospital and each fiscal year, compute year-over-year change in
TotRev and TotExp. Subtract the field median YoY change for that year to
produce field-adjusted change scores. This removes the sector-wide MOH
transfer effect — critical for 2020/2021 through 2022/2023 when COVID-era
transfers inflated revenue across the board.

Cumulate field-adjusted YoY changes over the full window to produce a single
revenue trajectory score and expense trajectory score per hospital.

### Service volume dimension (added this session)

Expense trajectory must be interpreted alongside service volume. A hospital
that reduced expenses by doing less is a qualitatively different finding from
one that reduced expenses while maintaining volume. The derived metric
`cost_per_pt_day = TotExp / AcutePtDays` is the primary efficiency indicator.

**Expense trajectory sub-classification:**
- **Efficiency-led** — expenses grew slower than field AND cost per patient
  day improved or held
- **Volume-driven contraction** — expenses fell but patient days also fell;
  cost per patient day flat or worsening — this is contraction, not efficiency
- **Scaling** — expense growth with volume growth — potentially appropriate
- **Cost pressure** — expense growth without volume growth — concerning

### Segmentation quadrants

Each hospital classified on two primary dimensions:

| Quadrant | Revenue | Expense | Interpretation |
|----------|---------|---------|----------------|
| Revenue-led improvement | ↑ | flat/↑ | Top-line growth drove the result |
| Expense-led improvement | flat | ↓ (efficiency) | Cost control was the lever |
| Both | ↑ | ↓ (efficiency) | Dual mechanism — compute proportional split |
| Volume contraction | ↓ or flat | ↓ (volume-driven) | Doing less, not more efficient |
| Cost pressure | flat/↓ | ↑ | Expenses growing faster than field |

For hospitals in the "Both" quadrant, proportional decomposition:
`revenue_share = Δrevenue_contribution / (Δrevenue + Δcost_savings)`

### Key framing hypothesis (Skip's)

Hospital operating expenses are structurally sticky — labour contracts, fixed
facility costs, and mandated service volumes constrain rapid adjustment.
Meaningful field-adjusted expense improvement is therefore a stronger signal
of deliberate management action than revenue growth, which can reflect external
MOH allocation decisions as much as hospital behaviour. Small but consistent
improvements are analytically meaningful even if modest in absolute terms.

### Analysis window

2018/2019 through 2024/2025 — seven fiscal years, six YoY changes.
The 2024/2025 year is included despite ~4 hospitals having missing data
(expected — most recent year not yet complete for all reporters).

**Important:** The analysis window is derived dynamically from the data —
the year range is not hardcoded. When the 2025/2026 download is released
(expected before end of July 2026), re-running the script will pick it up
automatically with no code changes required.

### Standalone deliverable

This step produces two narrative outputs:
- Technical narrative — methodologically complete, flat tone
- Publication narrative — LinkedIn post: "Here is how Ontario hospitals
  managed their finances over the last seven years — and which lever they
  pulled." Segmentation finding is the story; proportional decomposition
  for "both" hospitals adds texture.

---

## 7. Open Items Carried Forward

| Item | Detail | Priority |
|------|--------|----------|
| Build `hit_01_field_segmentation.R` | Full scope agreed — ready to start. Build in sections, Skip runs each section as produced. First section: load and filter indicator set from `hit_master.csv`. | Next session Priority 1 |
| Project Outline update | Section 4 (HIT status), Section 6 (build sequence) need updating to reflect HIT import complete | Priority 2 |
| FAC 947 / FAC 862 disposition | Terminal status — Skip assigns dates, documents decision | Before next registry refresh |
| Number of FIN-treated hospitals | Unknown — will surface naturally when `hit_02_strategy_join.R` is built. If fewer than ~20, pre/post analysis has limited power — note at that time. | Step 4 |
| 2025/2026 HIT data | Expected before end of July 2026. Scripts are designed to pick it up automatically on re-run. No action required now. | July 2026 |

---

## 8. Session End Checklist

- [ ] Upload `SessionSummaryApril292026.md` to knowledge repository
- [ ] Upload `HIT_Analytics_Project_Plan.md` to knowledge repository
  (`docs/programming_reference/`)
- [ ] Upload `HitGlobalIndicators.csv` to knowledge repository
  (`roles/hit/source_data/`) — confirmed present in uploads this session
- [ ] Push all changes to GitHub
