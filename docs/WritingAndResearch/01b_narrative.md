# Direction 1b — Thematic Composition of Strategic Plans by Hospital Type
*HospitalIntelligenceR Analytical Layer | April 2026*

---

## Finding Summary

The thematic composition of Ontario hospital strategic plans varies substantially by hospital type — but not uniformly across all themes. Three structural patterns dominate: a near-universal workforce theme that is consistent across all groups; a research and academic mission that is exclusive to Teaching and Specialty hospitals; and a partnerships orientation that is strongest precisely where hospitals are least self-sufficient. Financial and equity themes show more modest but directionally meaningful variation.

---

## Analytical Cohort

543 strategic directions across 115 hospitals. Cohort restricted to full and partial extractions from robots-allowed hospitals. Thin extractions (n=11) and robots-blocked hospitals (n=7) excluded. Hospital type groups: Teaching (77 directions, 14 hospitals), Community — Large (205 directions, 43 hospitals), Community — Small (198 directions, 45 hospitals), Specialty (63 directions, 13 hospitals).

---

## Key Findings

### 1. Workforce is a universal priority — not a small-hospital signal

WRK (Workforce & Culture) is the most common theme across all four hospital type groups, ranging from 14% of Teaching directions to 22% of Community — Large directions. The spread is only 8 percentage points and does not breach statistical significance. The hypothesis that small community hospitals would disproportionately over-index on workforce is **not confirmed** — workforce pressure appears to be a sector-wide condition, not a size-differentiated one.

This is itself a meaningful finding. It suggests that the workforce crisis facing Ontario hospitals in the post-pandemic period has penetrated strategic plans uniformly regardless of organizational scale or complexity. Every hospital type, from academic health sciences centres to rural community hospitals, has placed people at or near the top of its strategic agenda.

### 2. Research is the sharpest structural dividing line

RES (Research & Academic Mission) produces the largest differential in the dataset at 32 percentage points — the highest of any theme. Teaching hospitals allocate 32.5% of their strategic directions to research, education, and academic programs. Community — Small hospitals allocate 0%. Community — Large and Specialty hospitals sit in between (4.9% and 14.3% respectively).

This is the taxonomy working as designed. Research and academic mission is a mandate difference, not a strategic preference — it is structurally encoded in the teaching hospital designation and largely absent from community hospital plans. The Specialty hospital figure (14.3%) reflects rehabilitation and mental health hospitals with affiliated academic programs.

The practical implication for downstream analysis: RES directions should be excluded or controlled for when comparing strategic *choices* across groups. They reflect designation, not strategy.

### 3. Partnerships orient toward dependency, not ambition

PAR (Partnerships & Integration) is the second-largest differential at 15 percentage points and runs in the opposite direction to RES. Community — Small hospitals allocate 21% of directions to partnerships and system integration — the highest of any group. Teaching hospitals allocate only 6.5%.

This is consistent with the structural logic of Ontario's health system. A small community hospital cannot deliver comprehensive care independently. Integration with home care, long-term care, primary care networks, and regional referral centres is operationally necessary in a way it is not for a Teaching hospital that controls its own clinical ecosystem. The PAR over-representation in small community hospitals reflects interdependence, not strategic sophistication.

Teaching hospitals' low PAR allocation may reflect the inverse: they are the referral destination, not the referring organization, and their partnerships (research networks, university affiliations, specialist training programs) are more likely to be captured under RES.

### 4. Patient experience leads at Specialty hospitals

PAT (Patient Experience & Quality) shows a 10 percentage point differential, with Specialty hospitals highest at 22% and Teaching hospitals lowest at 12%. Chronic care, rehabilitation, and mental health hospitals have patient-centred care and quality outcomes as the definitional core of their organizational identity — these are not competing with research or systems leadership for strategic space. Teaching hospitals' lower PAT allocation likely reflects distribution across RES and EDI directions that carry overlapping content.

### 5. Financial sustainability shows a modest small-hospital lean

FIN (Financial Sustainability) shows a moderate differential: Community — Small hospitals allocate 13% of directions to financial themes, compared to 8% for Teaching, Community — Large, and Specialty groups. This does not breach the 8 percentage point threshold but is directionally consistent with the hypothesis. Small community hospitals operating on thin margins with limited endowment and capital reserves are more likely to make financial sustainability an explicit strategic priority rather than treating it as an operational given.

### 6. Equity directions concentrate in the academic sector

EDI (Equity, Diversity & Inclusion) shows a 7 percentage point gap — just below the threshold — with Teaching hospitals at 10.4% compared to 3–5% for other groups. This likely reflects the explicit equity and anti-racism commitments embedded in academic health sciences centre strategies following 2020–2021 policy pressure, as well as the Indigenous health equity requirements tied to research funding and academic accreditation. Community hospitals show EDI directions but at lower frequency.

---

## What Does Not Vary

Three themes show minimal cross-group variation and can be treated as universal strategic components of Ontario hospital plans:

- **WRK** — 14–22% across all groups. Universal.
- **INF** (Infrastructure & Operations) — 1–8%. Low and consistent.
- **ORG** (Organizational Culture) — 1–4%. Residual category, consistent.

ACC (Access & Care Delivery) and INN (Innovation & Digital Health) show moderate variation but no clear directional pattern across groups.

---

## Implications for Downstream Analysis

**For Direction 1c (standard directions):** The core + riders model is confirmed. WRK, PAT, and FIN form the near-universal core. RES is a Teaching/Specialty rider. PAR is a Small Community rider. EDI is an emerging Teaching rider.

**For Direction 2 (unique strategies):** RES directions should be excluded from the uniqueness analysis for Teaching hospitals — high RES prevalence is mandated, not distinctive. Uniqueness is more analytically interesting within the community hospital groups.

**For Direction 3 (temporal analysis):** EDI and INN are the themes most likely to show temporal signal — both have plausible post-2020 inflection points driven by policy environment changes.

**Controlling for type in all downstream analysis:** Hospital type group should be included as a covariate in any multivariate analysis given the structural RES and PAR differentials confirmed here.

---

## Limitations

The cross-tabulation reflects primary theme assignments only. Secondary themes (present in approximately 30% of directions) are not included in these percentages — a direction classified PAT/WRK is counted only as PAT. Full dual-theme analysis would require a different aggregation approach and is reserved for a later analytical pass.

Extraction quality bias remains a consideration for Community — Small hospitals, which have the highest concentration of thin extractions. Direction counts for that group are likely understated, and any systematic bias in what content survives thin extraction (e.g., headlines but not descriptions) could affect theme distributions.

---

*Analysis: HospitalIntelligenceR `01b_direction_types.R` | Classification: claude-sonnet-4-5, temperature=0 | n=543 directions, 115 hospitals*
