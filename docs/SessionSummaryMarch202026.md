# HospitalIntelligenceR
## Session Summary & Development Roadmap

*Last Updated: March 20, 2026 | For Claude Project Knowledge Repository*

---

## 1. Context

This session picked up from the March 18 session summary. The goals were:

1. Confirm the four pending `strategy_url` fixes (FACs 624, 632, 674, 827)
2. Fix the Browse[1] debug environment issue that was causing TARGET_MODE to be ignored
3. Run a broader 20-hospital validation test
4. Run the full 133-hospital set to assess Phase 1 completeness
5. Begin Phase 2 design discussion

All four `strategy_url` confirmations eventually succeeded after fixing a code bug in `extract.R`. The debug environment issue was resolved. The 20-hospital test achieved 100%. The full run produced 91/137 = 66.4% raw but revealed a clear set of categorized failures. Phase 2 design was deferred pending one more targeted fix pass.

---

## 2. Code Changes Implemented This Session

### 2.1 HEAD-Based Content Type Check — `roles/strategy/extract.R` (Fix ✅)

The `strategy_url` bypass logic previously only set `skip_crawl = TRUE` when the URL contained a `.pdf` extension. FAC 624 (Campbellford) uses a CMS URL with no extension (`https://cmh.ca/document/cmh_strategic_plan`) — the old code treated it as a crawl seed, which then failed when the crawler tried to parse a PDF as HTML.

The fix adds a HEAD request fallback in the `else` branch: if the URL has no `.pdf` extension, call `detect_url_content_type()` before deciding. If the HEAD response confirms PDF, `skip_crawl` is set to `TRUE` and the file is downloaded directly. This handles any future extensionless PDF URLs.

Replaced lines 241–252 in `roles/strategy/extract.R`:

```r
if (!is.null(strategy_url) && nchar(trimws(strategy_url %||% "")) > 0) {
  if (str_detect(tolower(strategy_url), "\\.pdf(\\?|/|$)")) {
    log_info(sprintf("FAC %s: strategy_url is a direct PDF — bypassing crawl: %s",
                     fac, strategy_url))
    best_url    <- strategy_url
    best_is_pdf <- TRUE
    skip_crawl  <- TRUE
  } else {
    detected_type <- tryCatch(
      detect_url_content_type(strategy_url),
      error = function(e) "unknown"
    )
    if (detected_type == "pdf") {
      log_info(sprintf("FAC %s: strategy_url confirmed PDF via HEAD — bypassing crawl: %s",
                       fac, strategy_url))
      best_url    <- strategy_url
      best_is_pdf <- TRUE
      skip_crawl  <- TRUE
    } else {
      log_info(sprintf("FAC %s: using strategy_url as crawl seed: %s", fac, strategy_url))
      seed_url <- strategy_url
    }
  }
}
```

### 2.2 Version-Safe PDF Filename — `roles/strategy/extract.R` (Fix ✅)

`.make_local_path()` previously always generated the same filename (`<FAC>_<YYYYMMDD>.pdf`) regardless of whether that file already existed on disk. Re-running a hospital on the same day would silently overwrite the previous download.

Replaced `.make_local_path()` to check for file existence and append `_v2`, `_v3`, etc. if needed:

```r
.make_local_path <- function(fac, hospital_name) {
  folder_name <- .make_folder_name(fac, hospital_name)
  folder_path <- file.path(STRATEGY_CONFIG$output_root, folder_name)
  base_name   <- sprintf("%s_%s", fac, format(Sys.Date(), "%Y%m%d"))

  candidate <- file.path(folder_path, paste0(base_name, ".pdf"))
  version   <- 2L
  while (file.exists(candidate)) {
    candidate <- file.path(folder_path, sprintf("%s_v%d.pdf", base_name, version))
    version   <- version + 1L
  }
  candidate
}
```

---

## 3. Bugs Identified — Pending Fixes

### Bug 1 — URL Space Encoding (`core/fetcher.R`) — PRIORITY

Three hospitals (FAC 640 Collingwood, FAC 813 Stratford, FAC 959 Sudbury HSN) failed with "Malformed input to a URL function" because their PDF URLs contain literal space characters. Fix: add `URLencode(url, repeated = FALSE)` before `httr2` request construction in `fetch_pdf()` (and likely `fetch_html()`) in `core/fetcher.R`. One fix resolves all three.

### Bug 2 — robots_disallowed Surfacing as fetch_error (FACs 854, 977)

Two hospitals show `failure_type: fetch_error` with `error_message: robots_disallowed`. These should have been caught and skipped by the robots check at the top of the loop, not attempted and failed at the fetch stage. Likely their `robots_allowed` field is incorrectly set to `yes` in the registry, or the robots check is not applied to the `strategy_url` direct-download path. Needs investigation.

---

## 4. Registry Updates This Session

| FAC | Hospital | Change |
|---|---|---|
| 624 | Campbellford Memorial | `strategy_url` confirmed working after extract.R fix |

All other hospitals processed this session had their `last_search_date`, `content_url`, `local_folder`, `local_filename`, and `extraction_status` updated automatically by the pipeline.

---

## 5. Run Results — March 20, 2026

### Run 1 — FAC 624 only (confirming strategy_url fix)
**Result: 1/1 = 100%** after extract.R fix applied.

### Run 2 — FACs 632, 674, 827
**Result: 3/3 = 100%**

### Run 3 — 20-hospital validation set (previously untested hospitals)
FACs: 599, 611, 626, 646, 648, 651, 662, 665, 696, 709, 718, 726, 734, 802, 804, 928, 931, 935, 964, 965
**Result: 20/20 = 100%**

### Run 4 — Full 133-hospital set (TARGET_MODE = "all")
**Result: 91/137 = 66.4% (raw)**

Attempted count is 137 rather than 133 because some hospitals have duplicate FAC entries sharing a base URL (e.g. MICS Group hospitals, Blanche River hospitals, Rural Roads hospitals) and each FAC is processed independently.

---

## 6. Full Run Failure Analysis

41 failures categorized into five buckets:

### Bucket A — URL Space Encoding Bug (3 failures) — Code fix pending
FACs 640, 813, 959. All fail with "Malformed input to a URL function" — literal spaces in PDF URLs. Resolved by Bug 1 fix above.

### Bucket B — robots_disallowed as fetch_error (2 failures) — Investigate
FACs 854, 977. See Bug 2 above.

### Bucket C — PDF Too Large (1 failure)
FAC 968 HUNTSVILLE MUSKOKA ALGONQUIN. Exceeds the 75MB cap. Check actual file size and raise cap or set `strategy_url` directly.

### Bucket D — Stale/Broken Registry URL (2 failures)
FAC 950 HALTON HEALTHCARE — HTTP 404, old PDF URL gone. Needs new `strategy_url`.
FAC 826 KENORA — Double-slash URL construction bug (`lwdh.on.ca//lwdh.on.ca/...`). Crawler URL-joining error where base URL and href overlap. Needs `strategy_url` override.

### Bucket E — No PDF on Correct Landing Page (33 failures)
Crawler found the right page but no downloadable PDF. Sub-groups:

- **HTML-only plans** (619, 684, 800, 824, 932) — no PDF exists; manual override appropriate
- **strategy_url fixes available** — 30-second browser lookup should resolve most remaining (666, 686, 745, 763, 936, 940, 969, 972, 975, 980, etc.)
- **Non-standard download mechanisms** — will never work with static crawling:
  - FAC 768 BARRYS BAY — base64-encoded `download.php` URL
  - FAC 784 LITTLE CURRENT — Joomla file download link
- **Known overrides** — FAC 930 (plan not yet published), FAC 958 (robots blocked)

### Adjusted Success Rate
Removing clearly non-pipeline-resolvable hospitals from denominator (5 hospitals: 854, 930, 958, 768, 784):
**91 / 132 = 68.9%** — below 80% threshold, but recoverable.

---

## 7. Phase 1 Status Assessment

The 80% threshold is not yet met on the full set. However the failure profile is well-understood and fixable:

- Bug 1 (URL encoding) recovers 3 hospitals with one code change
- Targeted `strategy_url` entries for Bucket E recovers estimated 10–15 more
- Bucket B investigation may recover 2 more or correctly reclassify as robots-blocked

Projected post-fix rate: **~80–85%** of eligible hospitals.

Phase 2 is not cleared to begin until the threshold is confirmed on the full set.

---

## 8. Architecture Decision — GitHub & Logs

Settled this session:

- **`docs/` folder** stays in GitHub — markdown references, guidelines, session summaries are part of the codebase's institutional knowledge
- **Logs and outputs are gitignored** — CSV audit logs, failure logs, and downloaded PDFs are runtime operational data, not source artifacts

Recommended `.gitignore` additions:
```
roles/*/outputs/
logs/
*.log
```

The `hospital_registry.yaml` stays in git — it is configuration and source of truth, not output.

---

## 9. Action Plan — Next Session

### Priority 1 — URL Space Encoding Fix (`core/fetcher.R`)

Add `URLencode(url, repeated = FALSE)` before `httr2` request construction in `fetch_pdf()` and `fetch_html()`. Re-run FACs 640, 813, 959 to confirm.

### Priority 2 — Investigate Bucket B (FACs 854, 977)

Check `robots_allowed` field in registry for both hospitals. Check whether the robots check is applied to the `strategy_url` direct-download path in `extract.R`.

### Priority 3 — Targeted strategy_url Pass

Manual browser lookup for highest-confidence Bucket E failures. Estimated 10–15 hospitals. Re-run after entries added.

### Priority 4 — FAC 968 PDF Size Cap

Check actual size of `https://www.mahc.ca/media/oiwfxbfy/strategic-plan-2025-2030.pdf`. Raise cap or set `strategy_url` directly.

### Priority 5 — FAC 950 New strategy_url

Find current Halton Healthcare strategic plan PDF URL (old URL returns 404).

### Priority 6 — Re-run Full Set and Confirm ≥80%

Once above fixes are applied, re-run `TARGET_MODE = "all"` and confirm threshold before beginning Phase 2.

### Priority 7 — Begin Phase 2 (pending threshold confirmation)

Three design decisions to make at session start:
1. **Input method** — image-based (PDF pages as images) vs. `pdftools` raw text
2. **Output schema** — plan period dates, strategic directions/pillars, descriptive text, actions/initiatives
3. **Output format** — CSV, RDS, or JSON per hospital

---

## 10. Files Changed This Session

| File | Change |
|---|---|
| `roles/strategy/extract.R` | HEAD-based content type check for extensionless strategy_url; version-safe .make_local_path() |
| `registry/hospital_registry.yaml` | All processed hospitals updated with new last_search_date, content_url, extraction_status |
