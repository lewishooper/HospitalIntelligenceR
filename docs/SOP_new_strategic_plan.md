# Adding a New or Updated Strategic Plan — Step by Step
*HospitalIntelligenceR | docs/SOP_new_strategic_plan.md*

---

## When to use this document

Use this procedure when you have received or located a new or updated strategic
plan PDF for a hospital that is already in the registry. This covers:

- A hospital that has published a new plan replacing an existing one
- A hospital where you previously had no plan and have now obtained one manually
- An updated plan received directly from a hospital (e.g. by email)

---

## Part 1 — Save the File

**1. Name the file using the standard convention:**

```
<FAC>_<YYYYMMDD>.pdf
```

Where `YYYYMMDD` is today's date (date you received or downloaded it).

Example for Lake of the Woods (FAC 826), received April 8 2026:
```
826_20260408.pdf
```

If a file for this FAC already exists in the folder (older plan), do NOT
delete it. The version-safe naming convention preserves older plans for
longitudinal analysis. The new file sits alongside the old one.

**2. Save the file to the hospital's outputs folder:**

```
roles/strategy/outputs/pdfs/<FAC>_<HOSPITAL_FOLDER_NAME>/
```

For FAC 826:
```
roles/strategy/outputs/pdfs/826_LAKE_OF_THE_WOODS/
```

If the folder does not exist yet, create it now with that naming pattern.

---

## Part 2 — Update the YAML Registry

Open `registry/hospital_registry.yaml` and locate the entry for this FAC.
**Close the file in RStudio before editing** — if RStudio has it open and
you save externally, RStudio may overwrite your changes.

Update the following fields under `status: strategy:`:

```yaml
status:
  strategy:
    last_search_date: '2026-04-08'        # today's date
    content_url: 'https://...'            # URL where you obtained the PDF
                                          # if received by email, use the
                                          # hospital's main website URL
    content_type: pdf
    local_folder: 826_LAKE_OF_THE_WOODS   # must match the folder name exactly
    local_filename: 826_20260408.pdf      # must match the filename exactly
    last_extraction_date: ''              # clear this — Phase 2 will fill it
    extraction_status: downloaded         # reset to downloaded
    manual_override: yes                  # yes — this was a manual acquisition
    override_reason: 'Received directly / Downloaded manually'
    needs_review: no
    phase2_status: ''                     # clear these — Phase 2 will fill them
    phase2_quality: ''
    phase2_n_dirs: ''
    phase2_date: ''
```

**Key rules:**
- `local_folder` and `local_filename` must match the actual folder and file
  names on disk exactly — including case
- `content_url` is always recorded, even for manually obtained files; use the
  hospital's public website URL if no direct document URL is available
- Clear all `phase2_*` fields so Phase 2 knows to re-process this hospital
- Set `extraction_status: downloaded` — this is the signal Phase 2 looks for

Save and close the YAML.

---

## Part 3 — Run Phase 2 for This Hospital

Open RStudio. Run in this order:

```r
# Step 1 — Set targeted mode for this FAC only
TARGET_MODE <- "facs"
TARGET_FACS <- c("826")        # add multiple FACs if you have several new plans

# Step 2 — Run Phase 2 extraction
source("roles/strategy/phase2_extract.R")
```

Review the console output:
- `extraction_quality` should be `full` or `partial`
- `n_dirs` should be a plausible number (typically 3–6)
- If you see `thin` quality, the PDF may need `force_image_mode: yes` in the
  YAML (see note below)

**If extraction quality is thin:**
Add `force_image_mode: yes` to the strategy block in the YAML, then re-run.
This forces the API to read the PDF as rendered images rather than raw text,
which resolves broken-font PDFs.

---

## Part 4 — Rebuild the Analytical Dataset

After Phase 2 completes successfully, rebuild the analytical spine:

```r
source("analysis/scripts/00_prepare_data.R")
source("analysis/scripts/00c_build_strategy_classified.R")
```

`00_prepare_data.R` rebuilds `hospital_spine.csv` and `strategy_master_analytical.csv`
from the upstream `strategy_master.csv`. `00c` joins the thematic classifications.

**Note:** The new hospital's directions will NOT have thematic classifications yet.
See Part 5.

---

## Part 5 — Classify New Directions (when you have accumulated several)

Thematic classification via the Claude API is the step with a cost. It is not
worth running for a single new hospital. The recommended threshold is **3 or more
new hospitals** before running classification.

When ready:

```r
# Classify only unclassified directions (script handles this automatically)
source("analysis/scripts/02_thematic_classify.R")
```

The classification script processes only rows where `primary_theme` is NA,
so it will not re-classify previously classified hospitals. Review the
console output for cost and any classification errors.

After classification, rebuild the classified dataset:

```r
source("analysis/scripts/00c_build_strategy_classified.R")
```

---

## Part 6 — Re-run Analytics (when classification is complete)

Only re-run these if you want updated figures and tables. For one or two new
hospitals, the impact on aggregate results will be minimal. Re-run when you
have a meaningful batch (5+ new hospitals) or before producing a new publication.

```r
source("analysis/scripts/00_prepare_data.R")
source("analysis/scripts/00c_build_strategy_classified.R")
source("analysis/scripts/03a_explore_plan_years.R")    # era assignment check
source("analysis/scripts/03b_theme_trends.R")          # temporal analysis
source("analysis/scripts/03c_theme_by_era_type.R")     # era × type interaction
```

Run in that order. Each script depends on the outputs of the one before it.

---

## Quick Reference — File Locations

| What | Where |
|------|-------|
| PDF files | `roles/strategy/outputs/pdfs/<FAC>_<NAME>/` |
| Registry | `registry/hospital_registry.yaml` |
| Extraction master | `roles/strategy/outputs/extractions/strategy_master.csv` |
| Analytical data | `analysis/data/` |
| Classification script | `analysis/scripts/02_thematic_classify.R` |
| Analytics scripts | `analysis/scripts/03a`, `03b`, `03c` |

---

## Notes on Specific Hospitals

**FAC 826 — Lake of the Woods (Kenora)**
Previously had a double-slash URL construction bug in Phase 1. Now handled as a
manual override. Save new plan to `826_LAKE_OF_THE_WOODS/` and update YAML as above.

**FAC 947 — UHN**
Plan dates (2025–2030) are currently an assumption pending email confirmation.
If confirmed or corrected when the new plan arrives, update `plan_period_start`
and `plan_period_end` in the YAML strategy block in addition to the steps above.
Re-run `00_prepare_data.R` after any date correction to rebuild the spine.
