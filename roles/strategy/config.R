# =============================================================================
# roles/strategy/config.R
# HospitalIntelligenceR — Strategy Role Configuration
#
# This file defines all role-specific behaviour for the strategy extraction
# role. It does not contain executable logic — it is sourced by extract.R
# and produces a single config list object: STRATEGY_CONFIG.
#
# To change keywords, cadence, output paths, or crawl behaviour for the
# strategy role, edit only this file. No other module needs to change.
# =============================================================================


STRATEGY_CONFIG <- list(

  # ---------------------------------------------------------------------------
  # Role identity
  # ---------------------------------------------------------------------------
  role       = "strategy",
  cadence_days = 365L,          # How often to re-check each hospital

  # ---------------------------------------------------------------------------
  # Output paths
  # Phase 1 (locate + download) writes here.
  # Phase 2 (analysis) reads from here.
  # ---------------------------------------------------------------------------
  output_root = "roles/strategy/outputs/pdfs",

  # PDF filename template: <FAC>_<YYYYMMDD>.pdf
  # Built at runtime — this documents the convention only.
  # Example: 592_20260302.pdf
  pdf_filename_template = "{fac}_{date}.pdf",

  # Folder name template: <FAC>_<SanitisedHospitalName>
  # Example: 592_NAPANEE_LENNOX_ADDINGTON
  # Sanitisation: uppercase, spaces → underscores, strip non-alphanumeric except underscores
  folder_name_template = "{fac}_{name_sanitised}",

  # ---------------------------------------------------------------------------
  # Crawler keywords
  #
  # Tier 1 (score 2 each): strong indicators the link leads to a strategic plan
  # Tier 2 (score 1 each): supporting context words — raise confidence but
  #                         not sufficient alone
  #
  # Keep tier 1 tight. False positives here waste a download attempt.
  # ---------------------------------------------------------------------------
  keywords_tier1 = c(
    "strategic plan",
    "strategic direction",
    "strategic priorities",
    "our strategy",
    "hospital strategy",
    "corporate plan",
    "multi-year plan",
    "strategic framework"
  ),

  keywords_tier2 = c(
    "strategy",
    "strategic",
    "plan",
    "vision",
    "mission",
    "priorities",
    "goals",
    "future",
    "direction",
    "annual report",
    "accountability",
    "about us",
    "about"
  ),

  # ---------------------------------------------------------------------------
  # Crawl behaviour overrides
  # These override the defaults in CRAWLER_CONFIG (crawler.R) for this role.
  # ---------------------------------------------------------------------------
  max_depth  = 2L,    # Strategic plans are rarely more than 2 clicks from home
  max_pages  = 25L,   # Allow a bit more than the crawler default for complex sites
  prefer_pdf = TRUE,  # Strategic plans are almost always PDFs — prefer them

  # ---------------------------------------------------------------------------
  # Download behaviour
  # ---------------------------------------------------------------------------
  extract_text_on_download = FALSE,
  # FALSE: fetch_pdf() saves the file and returns the local path only.
  # Phase 2 will handle text extraction / image conversion when it needs it.
  # Setting TRUE here would extract raw pdftools text on every download,
  # which is wasteful for Phase 1 and may not even be the extraction method
  # Phase 2 ends up using (image-based API calls don't use raw text).

  # ---------------------------------------------------------------------------
  # Registry fields written on a successful Phase 1 download
  # Documents what update_hospital_status() will receive — for reference.
  # ---------------------------------------------------------------------------
  # update_hospital_status(fac, "strategy", list(
  #   last_search_date  = <today>,
  #   content_url       = <url where PDF was found>,
  #   content_type      = "pdf",
  #   local_folder      = <folder name>,
  #   local_filename    = <file name>,
  #   extraction_status = "downloaded",    # distinct from "complete" (Phase 2)
  #   manual_override   = FALSE,
  #   needs_review      = FALSE
  # ))
  #
  # On crawl failure (no candidate found):
  # update_hospital_status(fac, "strategy", list(
  #   last_search_date  = <today>,
  #   extraction_status = "crawl_failed",
  #   needs_review      = TRUE
  # ))

  # ---------------------------------------------------------------------------
  # Run modes
  # Controlled by the caller (extract.R) at invocation time — not stored here.
  # Documented for reference:
  #   "due"      — process only hospitals where strategy is due (default)
  #   "all"      — process all robots-allowed hospitals (force_all = TRUE)
  #   "facs"     — process a specific vector of FAC codes
  # ---------------------------------------------------------------------------

  # ---------------------------------------------------------------------------
  # Phase 2 placeholders (not used by Phase 1 extract.R)
  # Filled in when the analysis layer is built.
  # ---------------------------------------------------------------------------
  prompt_file  = "roles/strategy/prompts/strategy_l1.txt",
  max_tokens   = 16000L,
  temperature  = 0
)
