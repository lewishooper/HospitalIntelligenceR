# GitHub Cleanup Work Plan
## HospitalIntelligenceR
*May 2026 — Prepared at session close*

---

## Overview

This plan covers three categories of work: R scripts that have been corrected
or created since the last push and need to be committed, documentation that is
now stale and needs to reflect current project state, and project knowledge
repository uploads that are outstanding. The plan is sequenced so each group
can be completed in a single sitting.

Estimated effort: 1.5–2 hours total across all three groups.

---

## Group 1 — R Scripts to Commit

These are scripts that exist locally but either have not been pushed or have
been corrected since the last push. Verify each file on disk matches the
session-confirmed version before committing.

### 1a. Strategy pipeline — fixed script

| File | Location | Issue | Verification check |
|------|----------|-------|--------------------|
| `02_thematic_classify.R` | `analysis/scripts/` | Three bug fixes applied (facs mode filter, output path logic, merge logic) but not pushed | Open the file — confirm `facs_mode` filter is present and output path uses `CLASSIFIED_DIR` not a hardcoded path |

This has been outstanding since the April sessions. It is the highest-priority
commit in this group.

### 1b. HIT analytics — corrected and new scripts

| File | Location | Issue | Verification check |
|------|----------|-------|--------------------|
| `hit_03_plan_comparison.R` | `roles/hit/scripts/` | Date fix (Bug 1 May 15) — `format(min(...), "%Y")` must be present; Section 9 FIN decomposition added | Search for `format(min(plan_period_start` — must return a match |
| `fig_hit03_plan_tables.R` | `roles/hit/scripts/` | Sections c/d (FIN tables) added this session | Confirm `tbl_hit03_c_fin_revenue.png` and `tbl_hit03_d_fin_expense.png` appear in `save_as_image()` calls |
| `fig_hit03_dendrite.R` | `roles/hit/scripts/` | New script — does not yet exist in repo | New file; confirm `N_SPINE_MIN <- 10L` and hollow-point `scale_shape_manual` are present |

### 1c. Commit message suggestion

```
Fix 02_thematic_classify.R bugs; add hit_03 plan comparison, FIN tables, dendrite graph

- 02_thematic_classify.R: fix facs mode filter, output path, merge logic
- hit_03_plan_comparison.R: fix date parsing bug (format %Y); add Section 9 FIN decomposition
- fig_hit03_plan_tables.R: add FIN vs non-FIN tables (sections c/d)
- fig_hit03_dendrite.R: new — plan-anchored trajectory graph with hollow spine points (n<10)
```

---

## Group 2 — Documentation to Update

Two project documents are now materially out of date and should be revised
before the project is less actively maintained.

### 2a. Project_Outline_Hospital_Intelligence.md

**Location:** `docs/programming_reference/`

**Stale section:** Section 5.1 Strategy Analytics status table. The HIT
financial performance correlation row currently reads "Not started — requires
HIT import." It is now substantially complete. Replace that row with:

| Workstream | Scripts | Status |
|---|---|---|
| HIT financial performance correlation | `roles/hit/scripts/hit_03_plan_comparison.R`, `fig_hit03_plan_tables.R`, `fig_hit03_dendrite.R` | Active — plan vs. no-plan and FIN decomposition complete; dendrite visualization complete; vintage cohort analysis deferred |

**Also update:** The build sequence table in Section 6. "HIT import script"
is listed as "Not started" — it is complete. Change to:

| Priority | Workstream | Status |
|---|---|---|
| Complete | HIT import and field segmentation | Complete — `hit_import.R`, `hit_validate.R`, `hit_01_field_segmentation.R` |
| Complete | HIT strategy-finance linkage | Substantially complete — plan comparison and FIN decomposition done |
| Next | Foundational documents role (Phase 1 + Phase 2) | Not started |
| Deferred | Plan vintage cohort analysis | Scoped — deferred pending capacity |
| Later | Executives role | Not started |
| Later | Board role | Not started |
| Last | Board minutes role | Not started |
| Last | QIPs (pending feasibility) | Deferred |

### 2b. StrategyPipelineReference.md

**Location:** `docs/programming_reference/`

**Stale section:** HIT Pipeline Reference at the bottom of the file. The
known items bullet for "12 HIT-only FACs" and the script sequence should
reflect the full current script list. Add the following scripts to the
sequence block:

```r
source("roles/hit/scripts/hit_01_field_segmentation.R")
source("roles/hit/scripts/hit_03_plan_comparison.R")
source("roles/hit/scripts/fig_hit03_plan_tables.R")
source("roles/hit/scripts/fig_hit03_dendrite.R")
```

And add to the key outputs table:

| File | Contents |
|------|----------|
| `roles/hit/outputs/hit_03_year_level.csv` | FAC × fiscal_year, field-adjusted YoY revenue and expense |
| `roles/hit/outputs/hit_03_hospital_level.csv` | Hospital-level cumulative scores, plan group, fin_flag |
| `roles/hit/outputs/hit_03_plan_comparison.csv` | Two-row plan vs. no-plan summary |
| `roles/hit/outputs/hit_03_fin_comparison.csv` | FIN vs. non-FIN decomposition within with-plan group |

### 2c. Add new documents to repository

Two new documents produced in the current sessions should be committed to
`docs/writing_and_research/`:

| File | Source | Location |
|------|--------|----------|
| `hit_03_publication_narrative.md` | Revised docx — convert back to .md after final edits | `docs/writing_and_research/` |
| `HospitalIntelligenceR_Methods_Overview.md` | Produced this session | `docs/writing_and_research/` |

The publication narrative should not be committed until the final docx pass
is complete. The Methods Overview can be committed now.

---

## Group 3 — Project Knowledge Repository Uploads

These files need to be uploaded to the Claude project knowledge repository
(separate from GitHub) so they are available for future sessions.

### Outstanding session summaries

Check which summaries are already in the repository and upload any that are missing:

| File | Status |
|------|--------|
| `SessionSummaryMay102026.md` | Likely uploaded — confirm |
| `SessionSummaryMay122026.md` | Likely uploaded — confirm |
| `HIT_Session_Summary_May15_2026.md` | Likely uploaded — confirm |
| Session summary for today (May 16, 2026) | Not yet written — produce at session close |

### New documents to upload

| File | Notes |
|------|-------|
| `HospitalIntelligenceR_Methods_Overview.md` | Produced this session — upload now |
| `hit_03_publication_narrative.md` | Upload after final docx pass is complete |

---

## Sequence Recommendation

Do these in order to minimize risk of committing stale files:

1. **Verify scripts on disk** (Group 1 verification checks) before opening GitHub Desktop or running `git add`
2. **Commit scripts** (Group 1) with the suggested commit message
3. **Edit the two documentation files** (Group 2a and 2b) in RStudio, then commit in a second commit
4. **Commit Methods Overview** (Group 2c) — hold publication narrative until after final pass
5. **Upload to knowledge repository** (Group 3) — session summary last, after the session summary is written

---

## One Standing Caution

Close `hospital_registry.yaml` in RStudio before pushing. If the file is open
when GitHub Desktop reads it, RStudio may prompt to overwrite disk changes when
it detects the git pull — and silently win. This has caused registry corruption
before. Close the file, push, reopen.

---

*Work plan prepared May 16, 2026 — HospitalIntelligenceR GitHub Cleanup*
