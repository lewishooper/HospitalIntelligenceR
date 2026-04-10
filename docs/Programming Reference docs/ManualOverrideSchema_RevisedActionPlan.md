# HospitalIntelligenceR — Manual Override Schema & Revised Action Plan

*Drafted: March 17, 2026 | For Claude Project Knowledge Repository*

---

## 1. Manual Override Registry Schema

### 1.1 Override Reason Taxonomy

Every `manual_override: true` entry must carry an `override_reason` drawn from this controlled vocabulary. The reason type determines the default review behaviour.

| Reason Code | Description | Review Cadence |
|---|---|---|
| `email_only` | Plan/content available by email request only | Role default (annual for strategy) |
| `no_pdf_exists` | Content exists but only as HTML image or JPEG — no PDF | Role default |
| `plan_not_yet_published` | Hospital has not yet released a plan for the current cycle | Explicit `review_date` required |
| `robots_blocked_pending` | robots.txt disallows; permission outreach in progress | Explicit `review_date` required (short cycle — weeks) |
| `robots_blocked_not_pursuing` | robots.txt disallows; no permission sought at this time | Role default |
| `js_rendered_no_workaround` | Content behind JavaScript rendering; no static URL available | Role default |

The distinction between `robots_blocked_pending` and `robots_blocked_not_pursuing` matters: only the former carries a short-cycle review date. The latter sits quietly until the annual strategy review cycle.

---

### 1.2 Role-Level Review Cadence Defaults

Review dates align to fixed calendar dates per role, not rolling dates from when the override was set. This concentrates review work at predictable points and keeps the registry clean.

| Role | Default Review Date | Notes |
|---|---|---|
| `strategy` | January 1 each year | Aligns with typical strategic plan publishing cycle |
| `foundational` | January 1 each year | Matches strategy cadence (VMV rarely changes faster) |
| `executives` | First of each month | Monthly role — overrides reviewed monthly |
| `board` | October 1 each year | Post-September election cycle |
| `minutes` | January 1 each year | Annual review of archive availability |

When `registry.R` sets a new override and no explicit `review_date` is provided, it computes the next occurrence of the role's default review date from today and populates it automatically.

---

### 1.3 Full Schema — Standard Manual Override

Used for: `email_only`, `no_pdf_exists`, `robots_blocked_not_pursuing`, `js_rendered_no_workaround`

```yaml
strategy:
  status: manual_override
  override_reason: email_only          # controlled vocabulary — see 1.1
  override_notes: "Plan available by emailing communications@hospital.ca"
  override_set_date: "2026-03-17"
  review_date: "2027-01-01"            # auto-set from role cadence if not provided
  manual_data:                         # populated when content is obtained manually
    source: "Email from Jane Smith, Communications — 2026-03-17"
    local_path: "roles/strategy/outputs/pdfs/724_Mattawa/724_manual_20260317.pdf"
    content_date: "2024-09-01"         # date of the plan itself, not acquisition date
    obtained_by: "Skip"
```

`manual_data` is optional at the time the override is set — it is populated later when content is obtained. When `manual_data.local_path` is present and the file exists, Phase 2 (Claude API analysis) runs normally on that file. The hospital does not become a hole in the dataset.

---

### 1.4 Full Schema — Plan Not Yet Published

```yaml
strategy:
  status: manual_override
  override_reason: plan_not_yet_published
  override_notes: "First strategic plan under development; expected 2027"
  override_set_date: "2026-03-17"
  review_date: "2027-01-01"            # explicit — does not default to role cadence
```

---

### 1.5 Full Schema — Robots Blocked (Permission Pending)

```yaml
strategy:
  status: manual_override
  override_reason: robots_blocked_pending
  override_notes: "robots.txt disallows PDF download. Outreach sent 2026-03-17."
  override_set_date: "2026-03-17"
  review_date: "2026-04-07"            # explicit short-cycle — ~3 weeks
  robots_status: permission_pending    # three values: blocked / permission_pending / permission_granted
  robots_outreach:
    contact_name: "Communications Department"
    contact_email: "info@torontograce.org"
    outreach_date: "2026-03-17"
    method: "Email"
```

---

### 1.6 Full Schema — Robots Blocked (Permission Granted)

When permission is received, `robots_status` advances to `permission_granted`, the `robots_permission` block is populated, and `status` is changed back to `pending` so the hospital re-enters the normal extraction queue. The override block is retained as a record but no longer controls behaviour.

```yaml
strategy:
  status: pending                      # returned to queue — fetcher will now bypass robots.txt
  override_reason: robots_blocked_pending   # retained for audit trail
  override_notes: "Permission granted 2026-03-20. See docs/permissions/."
  override_set_date: "2026-03-17"
  robots_status: permission_granted
  robots_outreach:
    contact_name: "Jane Smith"
    contact_email: "jsmith@torontograce.org"
    outreach_date: "2026-03-17"
    method: "Email"
  robots_permission:
    granted_by: "Jane Smith, Communications Manager"
    date: "2026-03-20"
    method: "Email reply"
    notes: "Permission granted for non-commercial research use only"
    document_path: "docs/permissions/854_TorontoGrace_permission_20260320.pdf"  # saved copy
```

The `docs/permissions/` folder is tracked in git. Permission documents (forwarded emails saved as PDF, or scanned letters) live here, named by FAC and date.

---

### 1.7 Fetcher Behaviour

`fetcher.R` bypasses robots.txt **only** when `robots_status == "permission_granted"`. The other two states (`blocked`, `permission_pending`) do not change fetcher behaviour — robots.txt is honoured. The status field is purely informational for those two states.

---

## 2. Pipeline Support for Targeted Runs

The main extraction loop must accept a `fac` parameter accepting a single FAC code or a character vector of FAC codes. When provided, the "what's due" logic is bypassed entirely and only the specified hospitals are processed.

```r
# Examples
run_strategy_role()                          # normal — all hospitals due
run_strategy_role(fac = "592")               # single straggler
run_strategy_role(fac = c("592", "905", "979"))  # small targeted set
```

This is the primary mechanism for acting on review-date-triggered stragglers and for post-fix retries without rerunning the full hospital set.

---

## 3. Review Date Workflow in registry.R

`registry.R` exposes a second query function alongside `get_hospitals_due()`:

```r
get_hospitals_for_review(role, as_of_date = Sys.Date())
```

This returns all hospitals for the given role where:
- `status == "manual_override"`, AND
- `review_date <= as_of_date`

At session startup (or at the top of a run script), calling this function produces a pre-run notice listing hospitals whose overrides are due for human review. The function does not change any data — it is read-only and advisory. The operator decides whether to act, update the review date, remove the override, or carry it forward.

---

## 4. Revised Action Plan — Next Session

The Priority 1–5 items from the March 5 session summary remain valid and are retained in order. A new Priority 0 is inserted before any code or YAML work begins.

---

### Priority 0 — Formalise the schema in the project (20 minutes)

Before touching the registry YAML or any code:

1. Add this document to the project knowledge repository.
2. Update `CLAUDE_WORKING_PREFERENCES.md` Section 8 (Key Constraints) to reference the manual override schema and the controlled reason vocabulary.
3. Create `docs/permissions/` folder in the project (a `.gitkeep` is sufficient to establish it).
4. Confirm the fixed review date for each role (table in Section 1.2 above) — update if any role cadence differs from what is listed.

---

### Priority 1 — Three-file regex fix (unchanged, ~10 minutes)

Update `\\.pdf(\\?|$)` to `\\.pdf(\\?|/|$)` in:
- `crawler.R` — `.extract_links()`, `is_pdf` line
- `fetcher.R` — `.detect_content_type()`, URL pattern line
- `extract.R` — `.find_pdfs_on_page()`, Pass 1 `is_pdf` line

---

### Priority 2 — Registry updates using the new schema (~30 minutes, YAML only)

Apply the full structured blocks from Section 1 above to the five hospitals flagged in the March 5 session. Specific entries:

| FAC | Hospital | Override Reason | Schema Section | Notes |
|---|---|---|---|---|
| 724 | Mattawa | `email_only` | 1.3 | `manual_data` block left empty until content obtained |
| 824 | Rural Roads | `no_pdf_exists` | 1.3 | JPEG image plan — no PDF |
| 900 | Fort Frances | `no_pdf_exists` | 1.3 | JPEG embedded in HTML |
| 930 | Grand River (WRHN) | `plan_not_yet_published` | 1.4 | `review_date: "2027-01-01"` |
| 854 | Toronto Grace | `robots_blocked_pending` | 1.5 | `review_date: "2026-04-07"` — initiate outreach |

Also update `base_url` for FAC 592 and add `strategy_url` fields for FAC 592, 905, and 979 (unchanged from March 5 plan).

---

### Priority 3 — `strategy_url` support in `extract.R` (~15 minutes)

At the top of the hospital loop, check `hospital$strategy$strategy_url`. If populated:
- If the URL itself ends in `.pdf` — skip crawl, go directly to download.
- Otherwise — use it as the crawl seed instead of `base_url`.

This is a clean conditional at the entry point of the loop, no structural changes required.

---

### Priority 4 — PDF size limit for FAC 907 Timmins

Assess the Timmins PDF against Claude API input limits. Decision: raise `max_pdf_size_bytes` globally to 75MB in `FETCHER_CONFIG`, or introduce a `max_pdf_size_override_bytes` field at the hospital-role level. The per-hospital field is marginally cleaner if this is an isolated case; global raise is simpler if the 50MB cap is generally too conservative.

---

### Priority 5 — `get_hospitals_for_review()` in registry.R (~20 minutes)

Implement the review query function described in Section 3. This is a small addition to `registry.R` — read-only, no write path. Add a call to it at the top of `extract.R`'s run function so overrides due for review surface automatically before each run.

---

### Priority 6 — Targeted run parameter in extract.R (~15 minutes)

Add the `fac` parameter to `run_strategy_role()` as described in Section 2. Simple filter applied immediately after `get_hospitals_due()` — if `fac` is not NULL, subset the hospital list to only those FACs before entering the loop.

---

### Priority 7 — Rerun and assess 80% threshold (unchanged)

Rerun the same 21-hospital set. Adjusted denominator: 16 hospitals (5 manual overrides excluded). Expected successes from this session's fixes: FAC 958 (regex), FAC 592 / 905 / 979 (strategy_url), FAC 907 (size limit) — potentially 5 additional successes pushing the rate to 17/16 adjusted, well above 80%. If yes, proceed to Phase 2. If not, one more targeted fix cycle.

---

## 5. Fields Not Yet Implemented in Code

The following schema fields require code support that does not yet exist. They are tracked here to ensure implementation is not forgotten:

| Field | Where implemented | Priority |
|---|---|---|
| `manual_data.local_path` — feed to Phase 2 | `roles/strategy/extract.R` | Phase 2 build |
| `robots_status` — fetcher bypass logic | `core/fetcher.R` | Priority 2 (this session) |
| `review_date` — auto-set on override creation | `core/registry.R` | Priority 5 (this session) |
| `get_hospitals_for_review()` | `core/registry.R` | Priority 5 (this session) |
| `fac` parameter on run function | `roles/strategy/extract.R` | Priority 6 (this session) |

The `robots_status` fetcher bypass is the only item from this list that affects Priority 1–4 correctness. It should be confirmed present in `fetcher.R` before the Priority 7 rerun.
