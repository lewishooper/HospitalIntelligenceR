# HospitalIntelligenceR
## Session Summary & Development Roadmap

*Last Updated: March 26, 2026 | For Claude Project Knowledge Repository*

---

## 1. Context

This session was the Phase 2 build session for the strategy role. All design decisions were finalised, three new files were built, and a successful first test extraction was completed against FAC 592 (Napanee Lennox & Addington). Phase 2 is now functional and ready for broader testing.

---

## 2. Phase 2 Design Decisions — Finalised

All three decisions deferred from the previous session were resolved at the start of this session.

**Input method:** `pdftools::pdf_text()` for PDF files; `readLines()` for `.txt` and `.csv` files; `rvest` HTML fetch for `html_only` hospitals. All three paths produce a plain text string passed to the Claude API. Image-mode is explicitly deferred to the fine-tuning pass — hospitals where `pdftools` returns thin or empty text will be flagged via `extraction_quality = "thin"` in the output and addressed later.

**Output schema:** Long-format tidy CSV. One row per strategic direction per hospital. Plan-level fields (hospital name, plan period, vision, mission, purpose, values, extraction quality) repeat across all rows for the same hospital. Direction-level fields are direction_number, direction_name, direction_type, direction_description, and key_actions. The `key_actions` field is pipe-delimited (`action one | action two | action three`) to preserve the one-row-per-direction structure while capturing multiple actions; `tidyr::separate_rows()` can explode it when action-level analysis is needed.

**Output format:** CSV. Per-hospital files written to `roles/strategy/outputs/extractions/<FAC_FOLDER>/<FAC>_<YYYYMMDD>_extracted.csv`. A consolidated `strategy_master.csv` is assembled at the end of each run, merging with any existing master by removing old rows for reprocessed FACs before appending new ones.

**html_only hospitals:** FACs 850, 932, and 936 are included in the Phase 2 build. `rvest` fetches live HTML from `content_url` in the registry when `local_filename` is empty and `extraction_status` is `html_only`. This is an early test of the HTML path — if it fails cleanly it becomes a fine-tuning pass candidate; if it succeeds it is a genuine win.

---

## 3. Output Schema — Field Reference

| Field | Level | Notes |
|---|---|---|
| `fac` | plan | Primary key — repeats per row |
| `hospital_name_self_reported` | plan | Exact text from document |
| `plan_period_start` | plan | From document content, not metadata. Format: YYYY, YYYY-MM, or YYYY-MM-DD |
| `plan_period_end` | plan | As above |
| `vision` | plan | Exact text |
| `mission` | plan | Exact text |
| `purpose` | plan | Exact text — some hospitals include a purpose statement distinct from vision/mission |
| `values` | plan | Pipe-delimited names only, no descriptions |
| `extraction_quality` | plan | `full` / `partial` / `thin` |
| `extraction_notes` | plan | Free text — flags ambiguities for human review |
| `source_type` | plan | `pdf` / `txt` / `html` |
| `extraction_date` | plan | Date of this extraction run |
| `direction_number` | direction | Sequential integer, order as in document |
| `direction_name` | direction | Exact text |
| `direction_type` | direction | `direction` or `enabler` |
| `direction_description` | direction | Exact text |
| `key_actions` | direction | Pipe-delimited, exact text, full wording |

---

## 4. Files Built This Session

### `roles/strategy/prompts/strategy_l1.txt`
The system prompt for all Phase 2 Claude API calls. Key design decisions embedded in the prompt:

- **Exact text rule** stated explicitly at the top of Field Instructions — governs all fields.
- **Purpose field** added alongside vision/mission/values to capture hospitals that publish a distinct purpose statement.
- **Terminological guidance** for directions: Strategic Direction, Strategic Priority, Strategic Pillar, Strategic Theme, Strategic Goal, Focus Area, Priority Area, Key Priority, Objective — all treated as `direction_type = "direction"`.
- **Enabler terminology** restricted to confirmed observed language only: Enabler, Strategic Enabler, Enabling Priority. "Foundation", "Foundational Element", and "Cross-Cutting Priority" were considered and rejected as not yet observed in Ontario hospital documents.
- **Enabler prose definition**: "explicitly described as an enabler or enabling element that supports the strategic plan."
- **Fallback rule**: when in doubt, use `"direction"`.
- **Key actions**: full exact text, pipe-delimited, no condensing or paraphrasing.

### `core/claude_api.R`
Built from scratch for the new architecture. Key features:

- Single public function `call_claude()` with signature: `user_message`, `system_prompt`, `model`, `max_tokens`, `temperature`, `max_retries`, `role`, `fac`.
- Returns: `response_text`, `input_tokens`, `output_tokens`, `cost`, `error` (NULL on success).
- Uses `httr2` — consistent with the rest of the project. The legacy files used `httr` and were not ported.
- API key read from `ANTHROPIC_API_KEY` environment variable (set in `~/.Renviron`).
- Exponential backoff: 2s, 4s, 8s between retries. Retries on HTTP 429, 529, and 5xx. Does not retry on 4xx client errors.
- Cost table at top of file for Sonnet, Opus, and Haiku. Cost calculated per call and returned to caller.
- Audit log appended to `logs/api_audit.csv` — one row per call, columns: timestamp, role, fac, model, input_tokens, output_tokens, cost_usd, status.
- `read_audit_log()` convenience function for cost inspection between runs.
- `%||%` null-coalescing operator defined with existence guard.

### `roles/strategy/phase2_extract.R`
Main Phase 2 orchestration script. Structure mirrors Phase 1 `extract.R`. Key features:

- Run modes: `"all"` (default) and `"facs"` (specific FAC vector).
- Eligibility: hospital must have a non-empty `local_filename` OR `extraction_status == "html_only"`.
- Three content-reading paths in `.read_content()`: PDF via `pdftools`, TXT/CSV via `readLines()`, HTML via `rvest`.
- Thin text detection: warns and proceeds rather than skipping — Claude returns `extraction_quality = "thin"` and the hospital is flagged for review.
- `.build_rows()` converts parsed JSON to long-format data frame. Plan-level fields repeat; one row per direction.
- Per-hospital CSV written to `roles/strategy/outputs/extractions/`.
- `strategy_master.csv` assembled at end of run — merges with existing master, old rows for reprocessed FACs are replaced.
- Registry updated after each hospital: `phase2_status`, `phase2_date`, `phase2_quality`, `phase2_n_dirs`, `needs_review` (set TRUE when quality is `"thin"`).

---

## 5. Bug Found and Fixed — Registry Path

During the first test run, all hospitals failed eligibility with "No eligible hospitals found." Root cause: `phase2_extract.R` was referencing `hospital$strategy` and `h$strategy` in three locations, but `load_registry()` returns role data at `hospital$status$strategy` (consistent with how Phase 1 and `registry.R` access it).

**Three locations fixed:**
1. `is_eligible()` function: `h$strategy` → `h$status$strategy`
2. Hospital loop: `hospital$strategy` → `hospital$status$strategy`
3. `.read_content()` function: `hospital$strategy` → `hospital$status$strategy`

---

## 6. First Test Run — FAC 592

FAC 592 (Napanee Lennox & Addington) was run as the first Phase 2 test after the registry path fix. The run completed successfully. Output was reviewed and judged to look good. No further issues were identified in this session.

---

## 7. Action Plan — Next Session

### Priority 1 — Broader Test Run
Test all three input paths before opening to the full 118 hospitals:
- At least one clean PDF (592 confirmed working)
- One `.txt` file — FAC 900 (Fort Frances) or 684/824 (Rural Roads)
- One `html_only` — FAC 850, 932, or 936

Review output CSV quality for each: are directions correct, is exact text being preserved, is `extraction_quality` sensible, are `vision`/`mission`/`purpose`/`values` populating where expected?

### Priority 2 — Full Phase 2 Run
Once all three paths are validated:
```r
TARGET_MODE <- "all"
source("roles/strategy/phase2_extract.R")
```
Review `strategy_master.csv` and `logs/api_audit.csv` for cost and quality summary.

### Priority 3 — Review `extraction_quality = "thin"` Hospitals
After the full run, filter master for `extraction_quality == "thin"` and triage. Candidates for image-mode retry will be addressed in the fine-tuning pass.

---

## 8. Session End Checklist

- [ ] Upload this session summary to project knowledge repository
- [ ] Upload updated `core/claude_api.R` to project knowledge repository
- [ ] Upload updated `roles/strategy/phase2_extract.R` to project knowledge repository
- [ ] Upload `roles/strategy/prompts/strategy_l1.txt` to project knowledge repository
- [ ] Push all changes to GitHub
- [ ] Close YAML file in RStudio before next session begins

---

## 9. Files Changed This Session

| File | Change |
|---|---|
| `core/claude_api.R` | Created new |
| `roles/strategy/prompts/strategy_l1.txt` | Created new |
| `roles/strategy/phase2_extract.R` | Created new; registry path bug fixed (`hospital$strategy` → `hospital$status$strategy` in 3 locations) |
