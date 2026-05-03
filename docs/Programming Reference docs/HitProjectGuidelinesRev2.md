# HIT Import and Analytics Workstream — Project Guidelines
## HospitalIntelligenceR
*roles/hit/HitProjectGuidelines.md | Established April 2026 | Updated May 2026*

---

## 1. Purpose

This document governs the design, build, and maintenance of the HIT (Hospital
Information Tables) import and analytics workstream within HospitalIntelligenceR.
HIT data is sourced from the Ontario Ministry of Health and provides annual financial
and operational indicators for Ontario public hospitals. When joined to strategy
analytics outputs via FAC, it enables analysis of the relationship between strategic
orientation and financial/operational performance.

**Build status:** Import pipeline complete. `hit_import.R` and `hit_validate.R` are
built and confirmed. `hit_master.csv` is the active analytical dataset. Analytics
pipeline in progress: `hit_01_field_segmentation.R` built and executed. Further
analytical scripts pending.

---

## 2. Data Sources

### 2.1 HIT Global Download — Current

**Source:** Ontario Ministry of Health, manual download  
**Format:** Wide CSV  
**Frequency:** Annual release in May/June following fiscal year-end (April 1 – March 31)  
**Coverage:** Rolling 5-year window  
**Granularity:** Global level — one row per hospital per reporting period  
**Key identifier:** `fac_rollup` — the MOH term for the provincial FAC code.
Renamed to `fac` (character) throughout the pipeline on load.

**Confirmed on build (April 2026):**
- Current source file: `FY2526Q3_GL HIT Hosp fac Level.csv`
- 717 rows, 77 columns
- All column names are **lowercase** in the current download
- `report_mapping_id == 4` for all 717 rows — filter is defensive only
- 7 accounting periods present (mix of YE and quarterly)

**Important — column name casing:** The MOH CSV uses lowercase column names
in the current download format (`accounting_period`, `fac_rollup`, `ind01`
etc.). Earlier files used uppercase (`ACCOUNTING_PERIOD`, `FAC_ROLLUP`).
The import script applies `tolower()` to all column names on load to normalise
both sources before any processing.

### 2.2 HIT Global Download — Historical

**Source:** Prior research download  
**Format:** CSV (same structure as current)  
**Coverage:** Provides 2018/2019 through 2022/2023 — extends the current
rolling window by approximately two years  
**Confirmed on build (April 2026):**
- Historical source file: `FY2223YE_GL HIT Hosp fac Level.csv`
- 729 rows, 77 columns
- Column names are uppercase — normalised to lowercase on load
- No overlap with current file after deduplication (current takes precedence)

**Column alignment:** `bind_rows()` handles mismatched indicator columns
natively — columns present in one source but not the other fill with NA.
No manual alignment is required.

**Note on other RDS files:** `FullGlobalHitMerged.rds` and `GlobalHit.rds`
exist in the source data folder from prior research. These are not used in
this workstream's import pipeline. `FullGlobalHitMerged.rds` contains
additional merged data that may be incorporated in a future enrichment pass.

### 2.3 Indicator Lookup Table

**Source:** `GlobalIndicatorLkup.rds` — researcher-created from prior work  
**Format:** R dataframe, 74 rows × 4 columns  
**Location:** `roles/hit/source_data/GlobalIndicatorLkup.rds`

**Confirmed column structure:**

| Column | Type | Description |
|--------|------|-------------|
| `ind` | integer | Indicator number (1–74) |
| `FullName` | character | Full indicator description |
| `ShortName` | character | Short label for display |
| `PageNumber` | numeric | Page reference in Ministry PDF manual |

**Key implementation note:** The lookup `ind` column is an integer (1, 2, 3...),
not a padded string. The CSV indicator columns use zero-padded format (`ind01`,
`ind02`... `ind74`). The import script constructs the join key using
`sprintf("ind%02d", as.integer(ind))` before joining. Do not attempt a direct
string match — it will fail to join.

**Confirmed on build:** All 55 active indicator codes matched in lookup.
74 indicators exist in the lookup; 55 are present in the current dataset
(19 are structurally absent — read as logical/NA columns in the CSV).

---

## 3. Data Structure

### 3.1 Raw Format

Wide CSV. All column names are lowercase after normalisation on load.

| Column | Description |
|--------|-------------|
| `accounting_period` | Fiscal year and frequency flag. Format: `YYYY/YYYYperiod` where period is `YE` (year-end) or `Q1`–`Q4`. Example: `2022/2023YE`, `2023/2024Q2` |
| `report_mapping_id` | Entity type. 4 = hospital global (confirmed). Current global download is all-4. |
| `fac_rollup` | MOH term for provincial FAC code. Renamed to `fac` (character) on load. |
| `ind01`–`ind74` | Indicator values. Wide format, one column per indicator. Sparse — ~88% fill rate across all years. |

### 3.2 Analytical Format — hit_master.csv

Long format after processing. One row per FAC × fiscal year × indicator
(NA values dropped).

| Column | Description |
|--------|-------------|
| `fac` | Provincial FAC code (character, matches registry) |
| `fiscal_year` | Extracted from `accounting_period` — e.g. `2022/2023` |
| `indicator_code` | Zero-padded indicator code — e.g. `ind01` |
| `FullName` | Full indicator description (from lookup) |
| `ShortName` | Short indicator label (from lookup) |
| `PageNumber` | Page reference in Ministry PDF manual (from lookup) |
| `value` | Numeric indicator value |
| `accounting_period` | Original period string retained for reference |
| `report_mapping_id` | Retained for reference |

**Confirmed dimensions (April 2026 build):**
- 48,991 rows
- 149 unique FACs in raw source (137 registry-matched + 12 HIT-only — see Section 8)
- 7 fiscal years: 2018/2019 through 2024/2025
- 55 unique indicator codes
- ~88% completeness (non-NA fill rate) across all years

---

## 4. Processing Rules

### 4.1 Column Normalisation

Applied immediately on load before any other processing:

```r
names(df) <- tolower(names(df))
df <- rename(df, fac = fac_rollup)
df$fac <- as.character(df$fac)
```

### 4.2 Frequency Filter

Retain only rows where `accounting_period` ends in `YE`. Quarterly rows are
written to `hit_quarterly.csv` and not used in analysis. Retained in case
quarterly data is needed in future.

```r
hit_ye <- hit_raw %>% filter(str_ends(accounting_period, "YE"))
hit_q  <- hit_raw %>% filter(!str_ends(accounting_period, "YE"))
```

### 4.3 Entity Filter

Retain only `report_mapping_id == 4`. Defensive — current global download
is confirmed all-4, but filter is applied and any exceptions are logged.

### 4.4 Historical Data Binding

1. Load both CSVs. Apply normalisation (Section 4.1) to each.
2. Identify overlapping `fac + accounting_period` combinations.
3. Remove overlapping rows from historical (`anti_join`). Current takes
   precedence on all overlaps.
4. `bind_rows()` — mismatched indicator columns fill with NA automatically.

### 4.5 Pivot to Long Format

After binding, pivot all `ind##` columns to long format. Drop NA rows —
`hit_master.csv` contains only non-NA values. Extract `fiscal_year` by
stripping `YE` suffix from `accounting_period`.

### 4.6 Indicator Lookup Join

Construct join key from lookup's integer `ind` column:

```r
lookup <- lookup_raw %>%
  mutate(indicator_code = sprintf("ind%02d", as.integer(ind))) %>%
  select(indicator_code, everything(), -ind)
```

Left join to long-format data on `indicator_code`. Unmatched codes are
flagged in the import log and in `hit_validate.R`.

### 4.7 FAC Standardisation

`fac_rollup` renamed to `fac` and coerced to character on load.
FACs present in HIT but not in the registry are documented in
`hit_coverage.csv` — not silently dropped at import stage.

### 4.8 Deduplication Rule

Current download takes precedence over historical for overlapping years.
Same `fac + accounting_period` in both sources → retain current row.

---

## 5. Scope Filter — Analytics Layer

**Added May 2026. Applied in `hit_01_field_segmentation.R` only — not in import.**

All HIT analytics scripts filter `hit_master` to registry FACs before computing
field medians or trajectories. This is implemented as Step 1b immediately after
the initial data load in each analytics script:

```r
registry_facs <- read_csv("analysis/data/hospital_spine.csv",
                           col_types = cols(.default = col_character()),
                           show_col_types = FALSE) %>%
  pull(fac)

hit_work <- hit_master %>%
  filter(fac %in% registry_facs)
```

**Why this is necessary:** `hit_master.csv` contains 149 FACs; the registry
contains 134 active hospitals (after retirement of FACs 653, 696, 813 in May
2026). The 12 HIT-only entities (see Section 8) and 3 retired pre-merger FACs
are present in `hit_master.csv` but absent from the registry. Without this
filter they flow through field median calculations, distorting the sector-wide
adjustments used for YoY field segmentation. The registry is the authoritative
scope boundary — it defines the study population. `hit_master.csv` is never
modified; the filter is applied at the analytics layer only.

**Retired FAC handling:** FACs 653, 696, and 813 are marked `retired: true` in
`hospital_registry.yaml`. `00_prepare_data.R` excludes them from `hospital_spine.csv`
on build. The scope filter above therefore excludes them from all HIT analytics
automatically, without requiring separate handling in each analytics script.

---

## 6. Amalgamation Year Transition Flags

**Added May 2026. Applied in `hit_01_field_segmentation.R`.**

Two receiving FACs absorbed predecessor hospitals during the study window.
Their amalgamation-year YoY transitions are artefacts — the receiving FAC's
financials jumped discontinuously as absorbed hospitals' reporting was
consolidated — not genuine performance changes. These transitions are excluded
from cumulative trajectory scoring.

| FAC | Hospital | Contaminated transition | Absorbed |
|-----|----------|------------------------|---------|
| 982 | Blanche River Health | 2020/2021 → 2021/2022 | FAC 653 (Englehart), FAC 696 (Kirkland) |
| 983 | HPHA | 2023/2024 → 2024/2025 | FAC 813 (Stratford General) + FAC 633, 792, 801 (HIT-only) |

**UHN (FAC 947) — monitoring item:** WestPark Healthcare (FAC 613, HIT-only)
merged into UHN in April 2024. WestPark is dropped from HIT analytics via the
scope filter. The 2023/2024 → 2024/2025 transition for UHN may be partially
contaminated depending on WestPark's scale relative to UHN. This transition
should be reviewed in the UHN trajectory narrative before final reporting.

**Implementation pattern in analytics scripts:**

```r
amalgamation_flags <- tribble(
  ~fac,   ~contaminated_from,  ~contaminated_to,
  "982",  "2020/2021",         "2021/2022",
  "983",  "2023/2024",         "2024/2025"
)
```

Contaminated transitions are excluded from cumulative delta calculations.
Affected hospitals receive trajectories computed on their remaining clean
transitions only, and are flagged in output tables.

---

## 7. Script Architecture

```
roles/hit/
  scripts/
    hit_import.R                # Load, normalise, filter, bind, pivot, join lookup
    hit_validate.R              # FAC coverage, year coverage, completeness report
    hit_01_field_segmentation.R # Field-adjusted YoY trajectories; scope filter applied
  source_data/
    FY2526Q3_GL HIT Hosp fac Level.csv   # Current download (primary)
    FY2223YE_GL HIT Hosp fac Level.csv   # Historical supplement
    GlobalIndicatorLkup.rds               # Indicator lookup (integer-keyed)
    HIT_Global Indicator Manual_2425Q3_1_1.docx  # PDF manual — not parsed yet
  outputs/
    hit_master.csv              # Long format: fac × fiscal_year × indicator (active)
    hit_quarterly.csv           # Quarterly rows — held separately, not used in analysis
    hit_coverage.csv            # FAC coverage and year coverage validation report
    hit_01_*.csv                # Field segmentation outputs (trajectories, quadrants)
```

### Script sequence

**Import layer:** `hit_import.R` → `hit_validate.R`

**Analytics layer:** `hit_01_field_segmentation.R` (additional scripts to follow)

Import scripts are standalone and do not depend on the strategy analytics pipeline.
Analytics scripts depend on `hit_master.csv` (from import) and `hospital_spine.csv`
(from `00_prepare_data.R`). When the registry changes (e.g., retirements, additions),
`00_prepare_data.R` must be re-run before any HIT analytics script is re-run.

**Re-run sequence after any registry change:**
1. Edit `hospital_registry.yaml`
2. Run `00_prepare_data.R` (rebuilds `hospital_spine.csv`)
3. Run HIT analytics scripts in order

---

## 8. Processing Sequence

**Step 1 — Load and normalise**
Load both CSVs. Apply `tolower()` to all column names. Rename `fac_rollup`
→ `fac`. Print `report_mapping_id` and `accounting_period` tables for both
files before any filtering.

**Step 2 — Filter**
Apply entity filter (`report_mapping_id == 4`) and frequency filter (`YE`
only). Write quarterly rows to `hit_quarterly.csv`.

**Step 3 — Bind and deduplicate**
Identify overlapping `fac + accounting_period` combinations. Remove from
historical. `bind_rows()` — column alignment handled automatically.

**Step 4 — Pivot to long format**
`pivot_longer()` on all `ind##` columns. Drop NA rows. Extract `fiscal_year`.

**Step 5 — Join indicator lookup**
Construct `indicator_code` from integer `ind` using `sprintf("ind%02d", ...)`.
Left join. Flag unmatched codes.

**Step 6 — FAC validation**
Compare HIT FACs against registry. Document non-matching FACs in
`hit_coverage.csv`.

**Step 7 — Write outputs**
Write `hit_master.csv` and `hit_coverage.csv`.

---

## 9. Analytical Questions This Enables

Once `hit_master.csv` is joined to strategy analytics outputs via FAC:

- Do hospitals with explicit FIN theme directions show stronger financial
  sustainability indicators?
- Do WRK-heavy strategies correlate with FTE ratios or staff cost patterns?
- Do Teaching hospitals show systematically different financial profiles from
  Community hospitals — and does the strategic divergence finding from 04a
  track with financial divergence?
- Is there a temporal relationship between plan period and financial performance
  trajectory — do hospitals in active plan periods show different performance
  trends?
- Do the theme-level outliers identified in 04b show distinctive financial
  profiles?

---

## 10. Known Items and Open Questions

| Item | Detail | Status |
|------|--------|--------|
| HIT-only FAC disposition | 12 FACs present in `hit_master.csv` but absent from registry were investigated in May 2026. Full disposition documented in `HIT_Scope_Remediation_Narrative.md`. | **Resolved May 2026** |
| FAC 600 Atikokan General | Has a strategy plan; was omitted from registry in error. Confirmed as Community Small. Onboarding deferred — does not block current analytics. | Pending — separate workstream |
| Retired FACs 653, 696, 813 | Marked `retired: true` in YAML. Excluded from `hospital_spine.csv` and therefore from all HIT analytics via scope filter. | **Resolved May 2026** |
| Contaminated transitions 982, 983 | Flagged in `hit_01_field_segmentation.R`. Excluded from cumulative trajectory scoring. | **Resolved May 2026** |
| UHN (947) WestPark contamination | 2023/2024 → 2024/2025 transition may be partially contaminated. WestPark (FAC 613) is excluded from analytics via scope filter. UHN transition size relative to UHN's scale should be reviewed before finalising UHN narrative. | Open — monitoring |
| Rural Roads / Huron Health alliances | FACs 655/663 (Huron Health) and 684/824 (Rural Roads) share strategic plans but remain separate HIT FACs. No HIT treatment required. Monitor 2025/26 data for potential consolidation. | Open — monitoring |
| 19 absent indicators | ind20, ind24, ind30, ind34, ind60–ind74 read as all-NA in both source files. Likely indicators introduced after the current data window or applicable only to non-hospital entities. | Logged — expected |
| Indicator PDF manual | `HIT_Global Indicator Manual_2425Q3_1_1.docx` contains richer metadata (units, direction, category groupings). Parsing deferred. | Deferred |
| `FullGlobalHitMerged.rds` | Contains additional merged HIT data from prior research. Not used in current pipeline. | Deferred |
| Annual refresh | When new HIT download is released (May/June), current file becomes primary. Previous current moves to historical role. Deduplication logic handles overlap automatically. | Documented — no action now |

---

## 11. Relationship to Strategy Analytics

HIT data joins to strategy analytics at the analysis layer only. The import
scripts are independent of the strategy pipeline. The join key is `fac`
(character) throughout. Strategy analytics outputs that are the primary join
targets:

- `strategy_master_analytical.csv` — for plan-period temporal alignment
- `strategy_classified.csv` — for theme-level joins (FIN, WRK, RES etc.)
- `hospital_spine.csv` — authoritative FAC list and type group assignments;
  defines the scope boundary for HIT analytics (see Section 5)

Plan period dates from strategy data are required for meaningful temporal
alignment — a hospital's HIT performance during its active plan period is
more analytically meaningful than a simple cross-sectional join.

---

*Last updated: May 2026*
