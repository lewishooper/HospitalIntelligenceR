# HIT Import Workstream — Project Guidelines
## HospitalIntelligenceR
*roles/hit/HitProjectGuidelines.md | Established April 2026 | Updated April 14, 2026*

---

## 1. Purpose

This document governs the design, build, and maintenance of the HIT (Hospital
Information Tables) import workstream within HospitalIntelligenceR. HIT data
is sourced from the Ontario Ministry of Health and provides annual financial
and operational indicators for Ontario public hospitals. When joined to strategy
analytics outputs via FAC, it enables analysis of the relationship between
strategic orientation and financial/operational performance.

**Build status:** Complete. `hit_import.R` and `hit_validate.R` are built and
confirmed. `hit_master.csv` is the active analytical dataset.

---

## 2. Data Sources

### 2.1 HIT Global Download — Current

**Source:** Ontario Ministry of Health, manual download  
**Format:** Wide CSV  
**Frequency:** Annual release in May/June following fiscal year-end (April 1 –
March 31)  
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

**Key implementation note:** The lookup `ind` column is an integer (1, 2,
3...), not a padded string. The CSV indicator columns use zero-padded format
(`ind01`, `ind02`... `ind74`). The import script constructs the join key
using `sprintf("ind%02d", as.integer(ind))` before joining. Do not attempt
a direct string match — it will fail to join.

**Confirmed on build:** All 55 active indicator codes matched in lookup.
74 indicators exist in the lookup; 55 are present in the current dataset
(19 are structurally absent — read as logical/NA columns in the CSV).

**Future enrichment option:** The Ministry PDF manual (`HIT_Global Indicator
Manual_2425Q3_1_1.docx`) contains richer metadata including units, direction
of improvement, and category groupings. Parsing this via the Claude API would
enable composite indicator analysis. Deferred — not required for the current
analytical build. If pursued, the enriched lookup replaces the RDS in place.

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
- 149 unique FACs (137 matched to registry + 12 HIT-only — see Section 8)
- 7 fiscal years: 2018/2019 through 2024/2025
- 55 unique indicator codes
- ~88% completeness (non-NA fill rate) across all years — consistent,
  expected for sparse HIT data

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
`hit_coverage.csv` — not silently dropped.

### 4.8 Deduplication Rule

Current download takes precedence over historical for overlapping years.
Same `fac + accounting_period` in both sources → retain current row.

---

## 5. Script Architecture

```
roles/hit/
  scripts/
    hit_import.R         # Load, normalise, filter, bind, pivot, join lookup
    hit_validate.R       # FAC coverage, year coverage, completeness report
  source_data/
    FY2526Q3_GL HIT Hosp fac Level.csv   # Current download (primary)
    FY2223YE_GL HIT Hosp fac Level.csv   # Historical supplement
    GlobalIndicatorLkup.rds               # Indicator lookup (integer-keyed)
    HIT_Global Indicator Manual_2425Q3_1_1.docx  # PDF manual — not parsed yet
  outputs/
    hit_master.csv       # Long format: fac × fiscal_year × indicator (active)
    hit_quarterly.csv    # Quarterly rows — held separately, not used in analysis
    hit_coverage.csv     # FAC coverage and year coverage validation report
```

### Script sequence

`hit_import.R` → `hit_validate.R`

These scripts are standalone — they do not depend on the strategy analytics
pipeline and can be run independently. Their outputs join to strategy analytics
at the analysis layer via FAC.

---

## 6. Processing Sequence

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

## 7. Analytical Questions This Enables

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

## 8. Known Items and Open Questions

| Item | Detail | Status |
|------|--------|--------|
| 12 HIT-only FACs | FACs present in HIT but not in registry: 600, 601, 605, 613, 633, 680, 687, 765, 792, 801, 855, 908. Likely retired, amalgamated, or non-acute entities still reported by MOH. Present in `hit_master.csv` and `hit_coverage.csv` — not dropped. Investigate on next registry refresh. | Logged — no action required now |
| 19 absent indicators | ind20, ind24, ind30, ind34, ind60–ind74 read as all-NA in both source files. Likely indicators introduced after the current data window or applicable only to non-hospital entities. Present in lookup, absent from `hit_master.csv`. | Logged — expected behaviour |
| Indicator PDF manual | `HIT_Global Indicator Manual_2425Q3_1_1.docx` contains richer metadata (units, direction, category groupings). Parsing deferred. Option A (simple RDS lookup) confirmed sufficient for initial build. | Deferred |
| `FullGlobalHitMerged.rds` | Contains additional merged HIT data from prior research. Not used in current pipeline. May be useful for extending coverage or adding derived fields in future. | Deferred |
| Lookup enrichment | If PDF manual is parsed, enriched lookup replaces `GlobalIndicatorLkup.rds` in place. `indicator_code` construction logic in `hit_import.R` does not change. | Future option |
| Annual refresh | When new HIT download is released (May/June), current file becomes the new primary. Previous current file moves to historical role. Deduplication logic handles overlap automatically. | Documented — no action now |

---

## 9. Relationship to Strategy Analytics

HIT data joins to strategy analytics at the analysis layer only. The import
scripts are independent of the strategy pipeline. The join key is `fac`
(character) throughout. Strategy analytics outputs that are the primary join
targets:

- `strategy_master_analytical.csv` — for plan-period temporal alignment
- `strategy_classified.csv` — for theme-level joins (FIN, WRK, RES etc.)

Plan period dates from strategy data are required for meaningful temporal
alignment — a hospital's HIT performance during its active plan period is
more analytically meaningful than a simple cross-sectional join.

---

*Last updated: April 14, 2026*
