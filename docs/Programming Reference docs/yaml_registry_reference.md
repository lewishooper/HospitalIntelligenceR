# Hospital Registry YAML — Reference Document
*HospitalIntelligenceR | docs/yaml_registry_reference.md*
*Created April 9, 2026*

---

## Purpose

This document is the authoritative reference for `registry/hospital_registry.yaml`.
It covers how the registry is used by each script, which fields are populated by
the user versus managed by scripts, field definitions, permitted values, and
safe editing procedures.

---

## 1. What the Registry Is

`hospital_registry.yaml` is the single source of truth for all hospital metadata
in HospitalIntelligenceR. Every script that touches a hospital reads from this
file. It contains one entry per Ontario public hospital, keyed by FAC code
(the provincial facility code used by MOHLTC and CIHI).

**Location:** `registry/hospital_registry.yaml`

**Primary key:** `FAC` — a string (quoted in YAML) matching the MOHLTC facility code.

**Loaded in R by:** `core/registry.R` via `load_registry()`. Returns a named list
indexed by FAC code. Access pattern: `registry[["739"]]$status$strategy`.

---

## 2. Top-Level Hospital Fields

These fields describe the hospital itself. They are set once when the hospital
is added to the registry and updated only when the underlying fact changes.

| Field | Type | Who sets it | Description |
|-------|------|-------------|-------------|
| `FAC` | string (quoted) | User | Provincial facility code. Primary key. Always quoted: `'739'` |
| `name` | string | User | Hospital name as it appears in MOHLTC records |
| `hospital_type` | string | User | One of: `Small Hospital`, `Large Community Hospital`, `Teaching Hospital`, `Specialty Hospital` |
| `base_url` | string | User | Hospital's primary website URL. Used as crawl seed in Phase 1. |
| `base_url_validated` | yes/no | User | Whether `base_url` has been confirmed to load correctly |
| `robots_allowed` | yes/no | Phase 1 script | Whether `robots.txt` permits crawling. Set by Phase 1; do not edit manually. |
| `last_validated` | date string | User/Phase 1 | Date `base_url` was last confirmed live |
| `leadership_url` | string | User | URL for the hospital's leadership/board page. Used by the executives and board roles. |
| `notes` | string | User | Free-text notes. Does not affect pipeline behaviour. |

---

## 3. The `status` Block

Each hospital has a `status` block containing sub-blocks for each data role.
Current roles: `strategy`, `foundational`, `executives`, `board`.

```yaml
status:
  strategy:
    ...
  foundational:
    ...
  executives:
    ...
  board:
    ...
```

Each role block is independent. A hospital can be fully extracted for `strategy`
while still `pending` for `executives`.

---

## 4. Strategy Role Fields

### 4a — Fields the User Sets

These fields require human judgment and must be set by the user. Scripts will
read them but will not overwrite them.

| Field | Type | Description |
|-------|------|-------------|
| `content_url` | string | URL where the strategic plan document was obtained. Always populated, even for manually downloaded files. For email-only documents, use the hospital's main website URL. |
| `content_type` | string | Format of the local file. One of: `pdf`, `txt`, `html`. |
| `local_folder` | string | Name of the folder inside `roles/strategy/outputs/pdfs/` where the file lives. Must match the actual folder name exactly, including case. Convention: `<FAC>_<HOSPITAL_NAME_UPPERCASE_UNDERSCORES>` |
| `local_filename` | string | Name of the file on disk. Must match exactly. Convention: `<FAC>_<YYYYMMDD>.pdf` |
| `manual_override` | yes/no | Set to `yes` whenever a human intervened in document acquisition (manual download, email, force-image, etc.). |
| `override_reason` | string | Free text explanation of why manual override was required. |
| `needs_review` | yes/no | Set to `yes` to flag this hospital for human review before or after Phase 2. Phase 2 will still process it. |
| `strategy_url` | string | Optional. If set, Phase 1 uses this URL directly as the crawl seed instead of `base_url`. Useful for hospitals where the strategy page is not reachable from the home page. |
| `force_image_mode` | yes/no | Optional. If `yes`, Phase 2 skips text extraction entirely and uses image-mode regardless of PDF text content. Use for PDFs with broken embedded fonts. |

### 4b — Fields Set by Phase 1 (Crawler)

Phase 1 (`roles/strategy/extract.R`) sets these fields after a successful crawl.
Do not edit them manually unless correcting a crawl error.

| Field | Type | Description |
|-------|------|-------------|
| `last_search_date` | date string | Date Phase 1 last ran for this hospital. |
| `extraction_status` | string | See status values table below. Phase 1 sets this to `downloaded` on success. |
| `robots_allowed` | yes/no | Set by Phase 1 based on `robots.txt` inspection. |

### 4c — Fields Set by Phase 2 (Extraction)

Phase 2 (`roles/strategy/phase2_extract.R`) sets these fields after API extraction.
Do not edit them manually. If Phase 2 needs to re-run for a hospital, clear these
fields to empty string (`''`) so Phase 2 knows to reprocess.

| Field | Type | Description |
|-------|------|-------------|
| `last_extraction_date` | date string | Date Phase 2 ran for this hospital. |
| `phase2_status` | string | Extraction outcome. See status values table. |
| `phase2_quality` | string | One of: `full`, `partial`, `thin`. Set by Phase 2 based on what the API returned. |
| `phase2_n_dirs` | integer | Number of strategic directions extracted. |
| `phase2_date` | date string | Date Phase 2 completed. |

---

## 5. Extraction Status Values

The `extraction_status` field tracks Phase 1 progress. The `phase2_status` field
tracks Phase 2 progress. They are independent.

### `extraction_status` (Phase 1)

| Value | Meaning |
|-------|---------|
| `pending` | Hospital not yet processed by Phase 1. |
| `downloaded` | File on disk and ready for Phase 2. Phase 2 looks for this value. |
| `complete` | Legacy value used in some early entries; equivalent to `downloaded`. |
| `html_only` | No downloadable PDF found; HTML page saved as text. Phase 2 will use the TXT file. |
| `download_failed` | Phase 1 found a URL but could not download the file. |
| `robots_blocked` | `robots.txt` disallows crawling. Hospital excluded from Phase 1 runs. |
| `not_found` | Phase 1 crawl completed but no strategic plan document found. |
| `manual_override` | Human intervention set this hospital's file; Phase 1 will not touch it. |

### `phase2_status`

| Value | Meaning |
|-------|---------|
| *(empty string)* | Not yet processed by Phase 2. This is what Phase 2 looks for. |
| `extracted` | Phase 2 completed successfully. |
| `api_failed` | Claude API call failed. `needs_review` will also be set to `yes`. |
| `parse_failed` | API response could not be parsed as JSON. |
| `file_not_found` | Phase 2 could not locate the file at the registered path. |

---

## 6. Clearing Fields for Re-Extraction

When a hospital's document is replaced (new plan downloaded, wrong document
corrected), Phase 2 fields must be cleared so Phase 2 knows to reprocess the
hospital. Clear these fields to empty string:

```yaml
last_extraction_date: ''
extraction_status: downloaded
phase2_status: ''
phase2_quality: ''
phase2_n_dirs: ''
phase2_date: ''
```

Also set `manual_override: yes` and populate `override_reason` to explain what
changed. See `SOP_new_strategic_plan.md` for the full procedure.

---

## 7. Non-Strategy Role Fields

The `foundational`, `executives`, and `board` role blocks follow the same pattern
as the strategy block. Their specific fields will be documented when those roles
are built. For now, all non-strategy blocks should contain at minimum:

```yaml
foundational:
  last_extraction_date: ''
  extraction_status: pending
  manual_override: no
  override_reason: ''
  needs_review: no
```

---

## 8. Safe Editing Procedures

### RStudio Caching Warning — Critical

RStudio holds YAML files in memory. If you edit the YAML externally (in a text
editor, or via a script) while RStudio also has the file open, RStudio will
prompt "File changed on disk — reload?" If you click **No**, RStudio will
overwrite your external changes with its in-memory version the next time it
saves.

**Rule:** Always close `hospital_registry.yaml` in RStudio before editing it
externally or running any script that modifies it. After a script run, reopen
the file in RStudio from disk to pick up changes.

### Indentation

The YAML parser is sensitive to indentation. The correct indentation hierarchy is:

```
hospitals:                    # 0 spaces
- FAC: '739'                  # 0 spaces (list item marker)
  name: ...                   # 2 spaces
  status:                     # 2 spaces
    strategy:                 # 4 spaces
      content_url: ...        # 6 spaces
```

When editing blocks, always inspect the surrounding lines before inserting new
content to confirm the correct indentation level.

### Key Naming

YAML keys are case-sensitive. Use lowercase with underscores throughout.
`local_filename` not `LocalFilename` or `local-filename`.

### FAC Codes

FAC codes must always be quoted strings in YAML: `FAC: '739'` not `FAC: 739`.
Unquoted integers behave differently under some YAML parsers and will cause
registry lookup failures in R.

### Duplicate Keys

YAML parsers silently accept duplicate keys within the same block, taking the
last value. Duplicate keys will not cause an error but will leave the registry
in an inconsistent state. Always scan the full strategy block for a given FAC
before saving to confirm no keys appear twice.

---

## 9. Bulk Inspection

For bulk verification of registry contents, Python-based inspection is more
reliable than R-based reads (bypasses RStudio caching):

```bash
python3 -c "
import yaml
with open('registry/hospital_registry.yaml') as f:
    reg = yaml.safe_load(f)
for h in reg['hospitals']:
    fac = h.get('FAC','')
    s = h.get('status',{}).get('strategy',{})
    print(fac, s.get('phase2_status',''), s.get('phase2_quality',''))
"
```

---

## 10. Adding a New Hospital

1. Obtain the FAC code from the MOHLTC hospital list.
2. Add a new entry to `hospital_registry.yaml` following the structure of an
   existing entry of the same hospital type.
3. Set all `phase2_*` fields to empty string.
4. Set `extraction_status: pending` for all roles.
5. Verify the `base_url` loads correctly and set `base_url_validated: yes`.
6. Push the registry to GitHub before running any Phase 1 or Phase 2 batch.

---

*Last updated: April 9, 2026*
