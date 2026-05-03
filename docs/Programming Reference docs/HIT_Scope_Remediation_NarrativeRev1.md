# HIT Scope and Registry Integrity Remediation
## HospitalIntelligenceR — Technical Narrative
**Date:** May 2026
**Author:** Skip
**Status:** Partially complete — HIT pipeline re-run pending

---

## 1. How the Issue Was Found

During a post-reclassification sniff test of `hit_01_field_segmentation.R` output,
approximately 10 rows with missing hospital names were identified in the trajectory
data. Investigation revealed that `hit_master.csv` contains **149 FACs** while the
hospital registry contains **137 active FACs at the time of discovery** — a gap of
12 entities.

These 12 FACs — referred to throughout as `HIT_ONLY` — are present in Ministry of
Health HIT source data but absent from `hospital_registry.yaml`. Because `hit_01`
does not filter to registry FACs before computing field medians and trajectories,
these entities were flowing through the full analytical stack without names or type
assignments, and were polluting the sector-wide median calculations used for field
adjustment.

Manual investigation of all 12 `HIT_ONLY` FACs against the MOHLTC FIM website
identified three distinct categories, and surfaced a separate but related registry
integrity problem involving merged hospitals present on both sides of a merger
simultaneously.

---

## 2. The HIT_ONLY Entities — Full Disposition

| FAC | Name | Type | Issue | Disposition |
|-----|------|------|-------|-------------|
| 600 | Atikokan General | Community Small | Has strategy plan — omitted from registry in error | **Reclaim** — separate workstream |
| 601 | Guelph | Specialty/Private | Private institution | **Drop** |
| 605 | Toronto Infirmary | Chronic Rehab Private | Private institution | **Drop** |
| 613 | WestPark Healthcare | Chronic Rehab | Merged into UHN (FAC 947) April 2024 | **Drop** — pre-merger entity |
| 633 | Clinton Public Hospital | Community Small | Merged into HPHA (FAC 983) April 1, 2024 | **Drop** — pre-merger entity |
| 680 | Don Mills | Other/Private | Private institution | **Drop** |
| 687 | Sensenbrenner | Community Small | No plan, no strategy linkage path | **Drop** |
| 765 | Unknown | Unknown | No presence in MOH HIT data at all | **Drop** — ghost record |
| 792 | St. Marys Memorial | Community Small | Merged into HPHA (FAC 983) April 1, 2024 | **Drop** — pre-merger entity |
| 801 | Seaforth Community | Community Small | Merged into HPHA (FAC 983) April 1, 2024 | **Drop** — pre-merger entity |
| 855 | Shouldice | Other/Private | Private institution | **Drop** |
| 908 | Bellwood Health Services | Other/Private | Private institution | **Drop** |

**Summary:** 10 entities dropped, 1 reclaimed (FAC 600 Atikokan, pending), 1 ghost
record dropped (FAC 765).

### Rationale for Dropping

The analytical purpose of HospitalIntelligenceR is to link hospital financial
trajectories to strategic planning documents. Any entity without a strategy document
has no path to the core linkage and cannot contribute meaningfully to the analysis.
Private institutions and retired pre-merger FACs fall into this category by definition.

Retaining these entities in HIT field median calculations distorts the sector-wide
adjustments used for YoY field segmentation, as they represent organizations operating
outside the study population.

---

## 3. The Registry Integrity Problem — Merger Double-Counting

Investigation surfaced that several hospitals which had merged into new consolidated
entities were present in the registry **on both sides of the merger simultaneously**
— both the retired pre-merger FAC and the new post-merger FAC carried active registry
entries with full strategy extractions. This caused double-counting in all strategy
analytics and polluted field medians in HIT.

### Confirmed Double-Count Pairs

**Blanche River Health (FAC 982)**
- Formed from merger of Englehart & District (FAC 653) and Kirkland & District (FAC 696)
- HIT conversion date: **April 1, 2021** (fiscal year 2021/22)
- All three FACs — 653, 696, and 982 — were active in the registry with `phase2_status: extracted`
- Effect: Community — Small overcounted by 2; Blanche River's strategic directions
  double-represented in all strategy analytics

**Huron Perth Healthcare Alliance (FAC 983)**
- Formed from merger of Clinton (FAC 633, HIT-only), St. Marys (FAC 792, HIT-only),
  Seaforth (FAC 801, HIT-only), and Stratford General (FAC 813)
- HIT conversion date: **April 1, 2024** (fiscal year 2024/25)
- FAC 813 (Stratford General) was active in the registry with `phase2_status: extracted`
  alongside FAC 983
- FACs 633, 792, 801 were HIT-only and not in the registry — caught in the initial sniff test
- Effect: Community — Large overcounted by 1; HPHA's strategic directions
  double-represented via Stratford

### Downstream Impact

**Strategy pipeline:** Homogeneity scores (04a), Jaccard similarity, distinctive
directions (04b), and all theme prevalence analyses (03b, 03c) were computed on a
cohort that included retired pre-merger entities alongside their successor
organizations. Hospital type group counts were incorrect — Community — Small was
overcounted by 2, Community — Large by 1.

**HIT pipeline:** Field medians used for YoY adjustment included pre-merger entities
that stopped reporting mid-window. For the two amalgamation years (2021/22 for Blanche
River, 2024/25 for HPHA), the receiving FACs showed artificial revenue and expense
jumps as absorbed hospital financials were consolidated — these are amalgamation
artifacts, not real performance changes.

---

## 4. Known Strategic Alliances — No Financial Merger

Two further cases were identified where hospitals operate under a common strategic
plan but remain separate FACs with independent HIT reporting:

| FACs | Alliance Name | Treatment |
|------|--------------|-----------|
| 655, 663 | Huron Shores / Huron Health | Strategy attributed to both FACs independently; HIT stays separate |
| 684, 824 | Rural Roads | Strategy attributed to both FACs independently; HIT stays separate |

These entities have not merged financially and continue to report separately to MOH.
Their shared plan is a strategic choice, not an amalgamation event. Monitor 2025/26
HIT data for potential consolidation of these pairs.

---

## 5. Remediation Plan — Status

### Step 1 — Registry YAML Edits ✓ COMPLETE (May 2026)

FACs 653, 696, and 813 marked `retired: true` in `hospital_registry.yaml`.
`merged_into` and `merger_hit_year` fields added to each:

| FAC | merged_into | merger_hit_year |
|-----|-------------|-----------------|
| 653 | 982 | 2021/2022 |
| 696 | 982 | 2021/2022 |
| 813 | 983 | 2024/2025 |

`hospital_registry.yaml` pushed to GitHub. `00_prepare_data.R` updated to skip
retired entries during spine build (`if (isTRUE(h$retired)) return(NULL)`).
Registry now contains **134 active hospitals**.

### Step 2 — Strategy Pipeline Re-run ✓ COMPLETE (May 2026)

`00_prepare_data.R` → `00c_build_strategy_classified.R` → `01a` → `01b` →
`03b` → `03c` → `04a` → `04b` run in order with corrected cohort.

**Post-remediation strategy cohort:**

| Type group | n hospitals |
|------------|-------------|
| Teaching | 17 |
| Community — Large | 43 |
| Community — Small | 48 |
| Specialty | 11 |
| **Total** | **119** |

Current era (2024–2026): 65 hospitals. All analytics downstream confirmed clean —
FACs 653, 696, 813 absent throughout; CHEO (751) and SickKids (837) correctly
classified as Teaching in all outputs.

### Step 3 — HIT Scope Filter ⏳ PENDING

A Step 1b filter is to be added to `hit_01_field_segmentation.R` immediately
after the initial data load, filtering `hit_work` to registry FACs only:

```r
registry_facs <- read_csv("analysis/data/hospital_spine.csv",
                           col_types = cols(.default = col_character()),
                           show_col_types = FALSE) %>%
  pull(fac)

hit_work <- hit_work %>%
  filter(fac %in% registry_facs)
```

This simultaneously removes all 10 dropped HIT-only entities and all 3 retired
pre-merger FACs (653, 696, 813) from field median calculations. The registry
(`hospital_spine.csv`) is the authoritative scope boundary.

### Step 4 — Contaminated YoY Transition Flagging ⏳ PENDING

The following amalgamation-year transitions are to be flagged in
`hit_01_field_segmentation.R` and excluded from cumulative trajectory scoring:

| FAC | Hospital | Contaminated transition | Absorbed |
|-----|----------|------------------------|---------|
| 982 | Blanche River Health | 2020/2021 → 2021/2022 | FACs 653, 696 |
| 983 | HPHA | 2023/2024 → 2024/2025 | FAC 813 + FACs 633, 792, 801 |

Affected hospitals receive trajectories computed on their remaining clean
transitions only. UHN (947) 2023/24 → 2024/25 transition is a monitoring item —
WestPark's scale relative to UHN should be checked before deciding on treatment.

### Step 5 — HIT Pipeline Re-run ⏳ PENDING

`hit_01_field_segmentation.R` to be re-run after Steps 3 and 4 are implemented.
Output figures in this narrative will be updated with confirmed post-remediation
results once the re-run is complete.

### Step 6 — Atikokan Reclaim ⏳ PENDING (non-blocking)

FAC 600 (Atikokan General) has a confirmed strategy plan and should be onboarded
as a Community — Small hospital. Separate workstream — does not block Steps 3–5.

### Step 7 — Narrative Updates ✓ COMPLETE (May 2026)

All strategy narrative documents updated with corrected cohort figures:
- `03b_narrative.md` — era breakdown and theme prevalence updated
- `03c_narrative.md` — type group counts and WRK/RES interaction tables updated
- `04a_narrative.md` — all three lenses updated with corrected cohort
- `04b_narrative.md` — outlier figures, distinctive directions count, and
  key outlier hospitals updated; Sinai Health references removed following
  April 2026 data correction
- `HitProjectGuidelines.md` — scope filter, amalgamation flags, and resolved
  known items documented

---

## 6. Pre-Remediation Anchor Data

The following figures were recorded before any registry or pipeline changes, to
enable assessment of the remediation impact once the HIT re-run is complete.

**Strategy cohort (pre-remediation):**

| Type group | n |
|------------|---|
| Teaching | 15 (CHEO and SickKids misclassified as Specialty) |
| Community — Large | 44 |
| Community — Small | 50 (includes FACs 653, 696) |
| Specialty | 13 (includes CHEO, SickKids; includes FAC 813) |
| Total | 122 |

**HIT trajectory output (pre-remediation, April 30 run):**

At the time of the April 30 run, `hit_01_field_segmentation.R` processed all 149
FACs without a scope filter. Post-remediation the scope will contract to the 134
active registry hospitals, removing:
- 10 dropped HIT-only entities (private, merged into registry FACs, or ghost records)
- 3 retired pre-merger FACs (653, 696, 813)

The pre-remediation trajectory figures and quadrant distributions are retained in
the April 30 session summary (`SessionSummaryApril302026.md`) and will serve as
the reference baseline for assessing the impact of the scope filter.

---

## 7. Open Questions

| Question | Context |
|----------|---------|
| WestPark / UHN size | Is the 2023/24 → 2024/25 transition for UHN (947) materially contaminated or negligible relative to UHN's scale? Check ptdays and revenue of FAC 613 vs FAC 947 in `hit_master.csv`. |
| Rural Roads / Huron Health monitoring | Watch for FACs 655/663 and 684/824 appearing as consolidated entities in 2025/26 HIT data |
| Atikokan reclaim scope | Confirm plan URL and extraction approach before onboarding FAC 600 |

---

*Document will be updated with confirmed post-remediation HIT output figures
after Steps 3–5 are complete.*
