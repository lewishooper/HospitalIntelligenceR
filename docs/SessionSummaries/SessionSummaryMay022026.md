# Session Summary — May 2, 2026
## HospitalIntelligenceR

---

## 1. Session Focus

Post-reclassification sniff test of `hit_01_field_segmentation.R` output following the FAC 751/837 reclassification to Teaching. The sniff test surfaced two distinct but related problems: out-of-scope entities in HIT data, and a registry integrity problem involving merged hospitals represented on both sides of their merger simultaneously.

---

## 2. FAC 751/837 Reclassification Status

YAML edits, strategy pipeline re-run, and HIT pipeline re-run were completed prior to this session. Narrative updates for 03b, 03c, 04a, 04b were **not** completed — deferred to next session after remediation re-run, as the cohort counts will shift again once merger cleanup is applied.

---

## 3. HIT_ONLY Investigation — What We Found

`hit_master.csv` contains 149 FACs; registry contains 137. The 12 gap FACs (`HIT_ONLY`) were investigated manually via MOHLTC FIM website. Full disposition:

| FAC | Name | Disposition | Reason |
|-----|------|-------------|--------|
| 600 | Atikokan General | **Reclaim** | Has plan, omitted from registry in error |
| 601 | Guelph | Drop | Private |
| 605 | Toronto Infirmary | Drop | Private chronic/rehab |
| 613 | WestPark | Drop | Merged into UHN (947) April 2024 |
| 633 | Clinton | Drop | Merged into HPHA (983) April 2024 |
| 680 | Don Mills | Drop | Private |
| 687 | Sensenbrenner | Drop | No plan, no strategy linkage path |
| 765 | Unknown | Drop | No presence in HIT data at all |
| 792 | St. Marys Memorial | Drop | Merged into HPHA (983) April 2024 |
| 801 | Seaforth | Drop | Merged into HPHA (983) April 2024 |
| 855 | Shouldice | Drop | Private |
| 908 | Bellwood | Drop | Private |

---

## 4. Registry Integrity Problem — What We Found

Investigation surfaced that several merged hospitals are represented on both sides of their merger in the registry simultaneously — both the retired pre-merger FAC and the new post-merger FAC have active entries with full strategy extractions. This causes double-counting in all strategy analytics and polluted field medians in HIT.

**Confirmed double-count pairs:**

| Retired FAC(s) | Name(s) | Receiving FAC | Receiving Name | HIT Merger Year |
|----------------|---------|---------------|----------------|-----------------|
| 653, 696 | Englehart, Kirkland | 982 | Blanche River Health | 2021/2022 |
| 813 | Stratford General | 983 | HPHA | 2024/2025 |

**Known strategic alliances (common plan, not yet financially merged in HIT):**
- FACs 655, 663 — Huron Health
- FACs 684, 824 — Rural Roads

Note: MOH data mergers lag behind operational mergers. These alliances may appear as consolidated FACs in the 2025/26 HIT data when received. This is an ongoing monitoring item.

---

## 5. Remediation Plan (to execute next session, in order)

### Step 1 — YAML Registry Edits
Mark FACs 653, 696, 813 as retired. Add `merged_into` and `merger_hit_year` fields.
**Claude will produce exact YAML edit examples at session open tomorrow.**
Close YAML in RStudio before editing. Push to GitHub before proceeding.

### Step 2 — Strategy Pipeline Re-run
Run in order: `00_prepare_data.R` → `01a` → `01b` → `03b` → `03c` → `04a` → `04b`

### Step 3 — HIT Scope Filter
Add Step 1b filter to `hit_01_field_segmentation.R` filtering `hit_work` to registry FACs only.
This removes all dropped HIT_ONLY entities and retired pre-merger FACs from field median calculations.

### Step 4 — Contaminated YoY Transition Flagging
Flag amalgamation-year transitions as artifacts — exclude from cumulative trajectory scoring:

| FAC | Hospital | Contaminated Transition |
|-----|----------|------------------------|
| 982 | Blanche River Health | 2020/2021 → 2021/2022 |
| 983 | HPHA | 2023/2024 → 2024/2025 |
| 947 | UHN | 2023/2024 → 2024/2025 — confirm size of WestPark relative to UHN before deciding treatment |

### Step 5 — HIT Pipeline Re-run
Re-run `hit_01_field_segmentation.R` with scope filter and contaminated transition flags in place.

### Step 6 — Atikokan Reclaim (separate workstream, non-blocking)
FAC 600 to be onboarded to registry as Community Small. Separate task — does not block Steps 1–5.

### Step 7 — Narrative Updates (Claude-generated)
After Steps 1–6 complete and output reviewed by Skip:
- `03b_narrative.md`
- `03c_narrative.md`
- `04a_narrative.md`
- `04b_narrative.md`
- `HitProjectGuidelines.md`
- `HIT_Scope_Remediation_Narrative.md` — regenerate final version with confirmed output figures

---

## 6. Open Questions Carried Forward

| Question | Context |
|----------|---------|
| WestPark/UHN size check | Is the 2023/24 → 2024/25 transition for UHN (947) materially contaminated or negligible relative to UHN's scale? |
| Rural Roads / Huron Health monitoring | Watch for these alliances appearing as consolidated FACs in 2025/26 HIT data |
| Atikokan reclaim scope | Confirm plan URL and extraction approach before onboarding |

---

## 7. Scripts Modified This Session

None — all changes deferred to next session pending narrative sign-off and YAML example production.

---

## 8. Tomorrow's Session Opens With

1. Claude produces YAML edit examples for FACs 653, 696, 813
2. Skip reviews and approves YAML edits
3. Execute remediation Steps 1–7 in order
4. Regenerate technical narrative with confirmed figures
