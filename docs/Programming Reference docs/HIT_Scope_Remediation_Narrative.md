# HIT Scope and Registry Integrity Remediation
## HospitalIntelligenceR — Technical Narrative
**Date:** May 2, 2026  
**Author:** Skip  
**Status:** Pre-remediation documentation — pipeline re-run pending

---

## 1. How the Issue Was Found

During a post-reclassification sniff test of `hit_01_field_segmentation.R` output, approximately 10 rows with missing hospital names were identified in the trajectory data. Investigation revealed that `hit_master.csv` contains **149 FACs** while the hospital registry contains **137 FACs** — a gap of 12 entities (subsequently confirmed as 12 after reconciliation).

These 12 FACs — referred to throughout as `HIT_ONLY` — are present in Ministry of Health HIT source data but absent from the `hospital_registry.yaml`. Because `hit_01` does not filter to registry FACs before computing field medians and trajectories, these entities were flowing through the full analytical stack without names or type assignments, and were polluting the sector-wide median calculations used for field adjustment.

Manual investigation of all 12 `HIT_ONLY` FACs against the MOHLTC FIM website identified three distinct categories, and surfaced a separate but related registry integrity problem involving merged hospitals that were present on both sides of a merger in the registry simultaneously.

---

## 2. The HIT_ONLY Entities — Full Disposition

The following 12 FACs were investigated and assigned dispositions:

| FAC | Name | Type | Issue | Disposition |
|-----|------|------|-------|-------------|
| 600 | Atikokan General | Community Small | Has a strategy plan — was omitted from registry in error | **Reclaim** — separate workstream |
| 601 | Guelph | Specialty/Private | No plan, private institution | **Drop** |
| 605 | Toronto Infirmary | Chronic Rehab Private | No plan, no website, private | **Drop** |
| 613 | WestPark Healthcare | Chronic Rehab | Merged into UHN (FAC 947) April 2024 | **Drop** — pre-merger entity; UHN already in registry |
| 633 | Clinton Public Hospital | Community Small | Merged into HPHA (FAC 983) April 1, 2024 | **Drop** — pre-merger entity; 983 already in registry |
| 680 | Don Mills | Other/Private | Private institution | **Drop** |
| 687 | Sensenbrenner Kapuskasing | Community Small | No clear plan, no path to strategy linkage | **Drop** |
| 765 | Unknown | Unknown | No presence in MOH HIT data at all | **Drop** |
| 792 | St. Marys Memorial | Community Small | Merged into HPHA (FAC 983) April 1, 2024 | **Drop** — pre-merger entity; 983 already in registry |
| 801 | Seaforth Community | Community Small | Merged into HPHA (FAC 983) April 1, 2024 | **Drop** — pre-merger entity; 983 already in registry |
| 855 | Shouldice | Other/Private | Private institution | **Drop** |
| 908 | Bellwood Health Services | Other/Private | Private institution | **Drop** |

**Summary:** 10 entities dropped, 1 reclaimed (600), 1 ghost record dropped (765).

### Rationale for Dropping

The analytical purpose of HospitalIntelligenceR is to link hospital financial trajectories to strategic planning documents. Any entity without a strategy document has no path to the core linkage and cannot contribute meaningfully to the analysis. Private institutions and retired pre-merger FACs fall into this category by definition.

Retaining these entities in HIT calculations would distort the sector-wide field medians used for YoY adjustment in `hit_01_field_segmentation.R`, as they represent organizations operating outside the study population.

---

## 3. The Registry Integrity Problem — Merger Double-Counting

Investigation of the `HIT_ONLY` list surfaced a more significant issue: several hospitals that had merged into new consolidated entities were present in the registry **on both sides of the merger simultaneously** — both the retired pre-merger FAC and the new post-merger FAC carried active registry entries with full strategy extractions.

### Confirmed Double-Count Pairs

**Blanche River Health (FAC 982)**
- Formed from merger of Englehart & District (FAC 653) and Kirkland & District (FAC 696)
- HIT conversion date: **April 1, 2021** (fiscal year 2021/22)
- All three FACs — 653, 696, and 982 — were active in the registry with `extraction_quality = full`
- Effect: Community Small overcounted by 2; Blanche River's strategic directions double-represented

**Huron Perth Healthcare Alliance (FAC 983)**
- Formed from merger of Clinton (FAC 633, HIT_ONLY), St. Marys (FAC 792, HIT_ONLY), Seaforth (FAC 801, HIT_ONLY), and Stratford General (FAC 813)
- HIT conversion date: **April 1, 2024** (fiscal year 2024/25)
- FAC 813 (Stratford General) was active in the registry with `extraction_quality = full` alongside FAC 983
- FACs 633, 792, 801 were HIT_ONLY and not in the registry — caught in the initial sniff test
- Effect: Community Large overcounted by 1 (Stratford); HPHA's strategic directions double-represented via Stratford

### Downstream Impact

Both the strategy analytics pipeline and the HIT analytics pipeline were affected:

**Strategy pipeline:** Homogeneity scores (04a), Jaccard similarity, distinctive directions (04b), and all theme prevalence analyses (03b, 03c) were computed on a cohort that included retired pre-merger entities alongside their successor organizations. Hospital type group counts were incorrect — Community Small was overcounted by 2, Community Large by at least 1.

**HIT pipeline:** Field medians used for YoY adjustment included pre-merger entities that stopped reporting mid-window. For the two merger years (2021/22 for Blanche River, 2024/25 for HPHA), the receiving FACs showed artificial revenue and expense jumps as absorbed hospital financials were consolidated — these are amalgamation artifacts, not real performance changes.

---

## 4. Known Strategic Alliances — No Financial Merger

Two further cases were identified where hospitals operate under a common strategic plan but remain separate FACs with independent HIT reporting. These require no HIT treatment but are noted for strategy analytics context:

| FACs | Alliance Name | Treatment |
|------|--------------|-----------|
| 655, 663 | Huron Shores / Huron Health | Strategy attributed to both FACs independently; HIT stays separate |
| 684, 824 | Rural Roads | Strategy attributed to both FACs independently; HIT stays separate |

These entities have not merged financially and continue to report separately to MOH. Their shared plan is a strategic choice, not an amalgamation event.

---

## 5. Remediation Plan

### Step 1 — Registry YAML Updates (do before any pipeline re-run)

Mark the following FACs as retired in `hospital_registry.yaml`. Add a `merged_into` field and `merger_hit_year` field to each:

| FAC | Action | merged_into | merger_hit_year |
|-----|--------|-------------|-----------------|
| 653 | Set status retired | 982 | 2021/2022 |
| 696 | Set status retired | 982 | 2021/2022 |
| 813 | Set status retired | 983 | 2024/2025 |

Close YAML in RStudio before editing. Push to GitHub before proceeding.

### Step 2 — Strategy Pipeline Re-run (in order)

`00_prepare_data.R` → `01a` → `01b` → `03b` → `03c` → `04a` → `04b`

After re-run, all type group counts, homogeneity scores, and distinctive direction results will reflect the corrected cohort. Narrative documents (03b, 03c, 04a, 04b) require review and update.

### Step 3 — HIT Scope Filter

Add a Step 1b filter to `hit_01_field_segmentation.R` immediately after the coverage checks, filtering `hit_work` to registry FACs only. This simultaneously:
- Removes all 10 dropped HIT_ONLY entities
- Removes pre-merger retired FACs (653, 696, 813) from field median calculations

The filter uses the registry as the scope boundary — consistent with the principle that the registry defines the study population.

### Step 4 — Contaminated YoY Transition Flagging

For the two receiving FACs, flag the amalgamation-year YoY transition as an artifact:

| FAC | Hospital | Contaminated transition | Reason |
|-----|----------|------------------------|--------|
| 982 | Blanche River Health | 2020/2021 → 2021/2022 | Absorbed 653 and 696 |
| 983 | HPHA | 2023/2024 → 2024/2025 | Absorbed 813 (and 633, 792, 801 from HIT_ONLY) |

These transitions are excluded from cumulative trajectory scoring. Affected hospitals receive trajectories computed on their remaining clean transitions only.

### Step 5 — HIT Pipeline Re-run

`hit_01_field_segmentation.R` re-run after scope filter and contaminated transition flags are in place.

### Step 6 — Atikokan Reclaim (separate workstream)

FAC 600 (Atikokan General) has a confirmed strategy plan and should be onboarded to the registry as a Community Small hospital. This is a separate task — add to YAML, extract strategy document, re-run pipeline. Timing: next registry refresh pass.

### Step 7 — Narrative Updates

After all pipelines produce clean output, review and update:
- `03b_narrative.md` — type group counts
- `03c_narrative.md` — era × type interaction
- `04a_narrative.md` — homogeneity scores and Jaccard
- `04b_narrative.md` — distinctive directions
- `HitProjectGuidelines.md` — scope filter and merger flag documentation

---

## 6. What Was Not Changed

- **Rural Roads (684, 824) and Huron Health (655, 663)** — no change to registry or HIT; common plan noted in strategy context only
- **UHN (947) and WestPark (613)** — WestPark was HIT_ONLY and is dropped; UHN absorbs WestPark April 2024 but the 2024/25 transition for UHN is already within the study window and is a real amalgamation event; flag the 2023/2024 → 2024/2025 transition for UHN as potentially contaminated — confirm against UHN's HIT data before deciding on treatment

---

*Document produced prior to pipeline re-run. To be updated with confirmed output figures after remediation is complete.*
