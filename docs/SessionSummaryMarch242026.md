# HospitalIntelligenceR
## Session Summary & Development Roadmap

*Last Updated: March 24, 2026 | For Claude Project Knowledge Repository*

---

## 1. Context

This session picked up from the March 22 summary. The primary goals were:

1. Confirm the correct registry was uploaded and recount Phase 1 status
2. Work through all 15 remaining Phase 1 failures systematically as a teaching exercise
3. Confirm Phase 1 threshold status and readiness for Phase 2

All 15 remaining failures were resolved or formally classified. The 80% threshold was confirmed at **88.5%** (115/130 eligible hospitals). Phase 2 is unlocked.

---

## 2. Registry & Infrastructure Fixes

### 2.1 Repository Discipline — Single File Rule
Older versions of `hospital_registry.yaml` were removed from the project knowledge repository. Going forward only the current version is uploaded. Old versions belong in git history only. Multiple versions cause Claude to read stale data and generate false findings.

### 2.2 Duplicate Key False Alarm
A Python YAML scanner incorrectly flagged duplicate keys across virtually every hospital entry. Investigation confirmed the file was structurally clean — the scanner was treating same-named keys in different role sub-blocks (strategy/foundational/executives/board) as duplicates at the same indent level. No registry corruption existed.

### 2.3 `extraction_status: complete` vs `downloaded` — Critical Distinction
`get_hospitals_due()` in `registry.R` only skips a hospital on future runs when `manual_override == TRUE` AND `extraction_status == "complete"`. Hospitals marked `downloaded` will be re-attempted and overwritten on the next run. 

**Rule going forward:** any hospital where automated download is structurally blocked (403 on base URL, JS-rendered navigation, size cap exceeded) must be set to `extraction_status: complete` + `manual_override: yes` to protect manual work from being overwritten.

### 2.4 `content_url` vs `strategy_url` — Confirmed Definitions
- `strategy_url` is an **input** field — provided manually to guide the pipeline when the crawler cannot find the plan. Cleared after successful automated download unless it is needed for future runs (e.g. subdomain cases).
- `content_url` is an **output** field — written by the pipeline recording where content was actually fetched from.

---

## 3. Extraction Status Vocabulary — Confirmed Full Set

| Status | Meaning |
|--------|---------|
| `downloaded` | Pipeline successfully downloaded — will re-run on cadence |
| `complete` | Manually obtained or site structurally blocks automation — do not re-run |
| `html_only` | No PDF exists — plan is HTML only |
| `not_yet_published` | Plan actively under development, expected date known |
| `not_published` | Plan exists (referenced internally) but not publicly available — outreach in progress |
| `no_plan` | Confirmed via direct contact — organisation does not have a strategic plan |
| `robots_blocked` | robots.txt disallows crawling — excluded from denominator |

---

## 4. Registry Changes This Session

| FAC | Hospital | Resolution | Status Set |
|-----|----------|------------|------------|
| 763 | PEMBROKE REGIONAL | `strategy_url` added with `.ashx` document handler URL — spaces handled by existing encoding fix | `downloaded` |
| 850 | TORONTO RUNNYMEDE | HTML/image only plan — no PDF exists | `html_only` |
| 930 | GRAND RIVER WRHN | Plan not yet published, under development; expected 2027 | `not_yet_published` |
| 936 | LONDON HEALTH SCIENCES | Confirmed HTML only — already correctly set, no change needed | `html_only` |
| 958 | OTTAWA THE OTTAWA HOSPITAL | HTTP 403 blocks automated download — PDF downloaded manually via browser | `complete` |
| 968 | HUNTSVILLE MAHC | PDF exceeded 75MB cap (92MB) — downloaded and compressed manually to 12MB | `complete` |
| 771 | PETERBOROUGH REGIONAL | Site returns 403 on base URL blocking crawler — PDF downloaded manually | `complete` |
| 950 | HALTON HEALTHCARE | Crawler found stale link; PDF hosted on subdomain `stratplan.haltonhealthcare.com` — `strategy_url` set to correct subdomain URL | `downloaded` |
| 975 | TRILLIUM HEALTH PARTNERS | `strategy_url` restored — pipeline downloaded successfully | `downloaded` |
| 699 | WRHN-KITCHENER ST MARY'S | Now partnered with Grand River (930) — no plan yet, same YAML pattern applied | `not_yet_published` |
| 627 | CHAPLEAU SSCHS | JS dropdown hides links from static crawler — `strategy_url` set to direct PDF; plan period 2020-2024 is expired, check for update | `downloaded` |
| 719 | MANITOUWADGE | Plan referenced in board minutes but not publicly posted — email request sent 2026-03-24 | `not_published` |
| 724 | MATTAWA GENERAL | No public PDF — obtained via email request to hospital | `complete` |
| 824 | TILLSONBURG DISTRICT MEMORIAL | Integrated into Rural Roads Health Services (see FAC 684) — plan is HTML only at shared site | `html_only` |
| 910 | TORONTO CASEY HOUSE | Confirmed via direct contact — organisation does not have a strategic plan | `no_plan` |
| 932 | ELIZABETH BRUYERE | Plan published as HTML only — no PDF available on site | `html_only` |

---

## 5. Key Learnings This Session

### 5.1 PDF Size Cap
The 75MB cap caused one failure (FAC 968, 92MB). Decision: revisit cap only if another case surfaces. No config change made.

### 5.2 French-Language / JS Crawling Limitations
Chapleau confirmed that JS-rendered dropdown menus hide links from the static HTML crawler regardless of keyword matching. "general" was considered as a keyword addition and rejected — too many false positives across hospital names and URLs. These cases are best handled via `strategy_url` overrides and noted for the fine-tuning pass.

### 5.3 Subdomain PDF Hosting
Halton confirmed a case where the PDF is hosted on a dedicated subdomain (`stratplan.haltonhealthcare.com`) rather than the main hospital domain. The crawler correctly found the plan page but constructed the wrong PDF URL. Fix: `strategy_url` pointing to the correct subdomain URL. Future runs will succeed automatically.

### 5.4 Hospital Mergers and Alliances
FAC 824 (Tillsonburg) confirmed as integrated into Rural Roads Health Services alongside FAC 684 (Ingersoll/Alexandria). Both FACs correctly retain independent registry entries pointing to the shared Rural Roads site. FAC 699 (St. Mary's Kitchener) confirmed as partnered with FAC 930 (Grand River) — same `not_yet_published` status applied to both.

### 5.5 Direct Contact as a Resolution Strategy
FACs 719 (Manitouwadge), 724 (Mattawa), and 910 (Casey House) were resolved through direct contact with the hospital. This is a legitimate and necessary resolution path — not every hospital publishes its strategic plan online. The `not_published` and `no_plan` statuses exist to document these outcomes cleanly.

### 5.6 `.ashx` Document Handler URLs
FAC 763 (Pembroke) confirmed that `.ashx` handler URLs with spaces work correctly once the `gsub(" ", "%20")` encoding fix is in place. The URL must be quoted in YAML to protect the `&` character.

---

## 6. Final Phase 1 Status

| Metric | Value |
|--------|-------|
| Total hospitals in registry | 137 |
| Robots blocked (excluded from denominator) | 7 |
| Eligible hospitals (denominator) | 130 |
| Confirmed captured | 115 |
| **Phase 1 success rate** | **88.5%** |
| 80% threshold | ✅ Cleared |

---

## 7. Action Plan — Next Session (Phase 2)

### Priority 1 — Final Re-run
Run `TARGET_MODE = "all"` to confirm clean run with all registry fixes in place. Verify the run summary reflects the true success rate with no false failures from manually-completed hospitals.

### Priority 2 — Phase 2 Design Decisions
Three decisions to make before building:

1. **Input method** — image-based (PDF pages rendered as images, passed to Claude API) vs `pdftools` raw text extraction. Image-based is more robust for heavily designed PDFs; text extraction is cheaper and faster.
2. **Output schema** — fields to extract: plan period dates, strategic directions/pillars, descriptive text per direction, key actions/initiatives, and foundational elements (vision/mission/values if present in the PDF).
3. **Output format** — CSV, RDS, or JSON per hospital. CSV is simplest for downstream analysis; JSON preserves nested structure better.

### Priority 3 — HTML-Only Plan Handling
Decide whether Phase 2 will attempt extraction from `html_only` hospitals or defer them. There are a small number (836, 850, 900, 932, etc.) — worth a design decision before building.

---

## 8. Files Changed This Session

| File | Change |
|------|--------|
| `registry/hospital_registry.yaml` | FACs 627, 684, 699, 719, 724, 763, 771, 824, 850, 910, 930, 932, 936, 950, 958, 968, 975 updated |
