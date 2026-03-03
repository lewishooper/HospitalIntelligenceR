# =============================================================================
# roles/strategy/extract.R  —  PHASE 1: Locate & Download
# HospitalIntelligenceR
#
# What this script does:
#   For each hospital that is due for a strategy refresh, crawl the hospital
#   website to find the strategic plan PDF, download it to the structured
#   output folder, and update the registry.
#
# What this script does NOT do:
#   Send anything to the Claude API. Content analysis (L1/L2 extraction)
#   is Phase 2 and lives in a separate script.
#
# Run modes (set TARGET_MODE before sourcing, or pass as argument):
#   "due"  — hospitals where strategy cadence has elapsed (default)
#   "all"  — all robots-allowed hospitals (useful for initial population)
#   "facs" — specific FAC codes only (set TARGET_FACS vector)
#
# Usage:
#   TARGET_MODE <- "due"
#   source("roles/strategy/extract.R")
#
#   # Or for specific hospitals:
#   TARGET_MODE <- "facs"
#   TARGET_FACS <- c("592", "644", "701")
#   source("roles/strategy/extract.R")
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(stringr)
  library(purrr)
})

# --- Source core modules ---
source("core/registry.R")
source("core/fetcher.R")
source("core/crawler.R")
source("core/logger.R")

# --- Source role config ---
source("roles/strategy/config.R")   # produces STRATEGY_CONFIG


# =============================================================================
# STEP 0: Validate run mode and initialise logger
# =============================================================================

if (!exists("TARGET_MODE")) TARGET_MODE <- "due"

valid_modes <- c("due", "all", "facs")
if (!TARGET_MODE %in% valid_modes) {
  stop(sprintf("Unknown TARGET_MODE '%s'. Must be one of: %s",
               TARGET_MODE, paste(valid_modes, collapse = ", ")))
}

if (TARGET_MODE == "facs" && !exists("TARGET_FACS")) {
  stop("TARGET_MODE is 'facs' but TARGET_FACS is not defined.")
}

run_id <- format(Sys.time(), "%Y%m%d_%H%M%S")

init_logger(
  role     = STRATEGY_CONFIG$role,
  log_root = "logs",
  echo     = TRUE
)

log_info(sprintf("Strategy Phase 1 — locate & download | mode: %s | run_id: %s",
                 TARGET_MODE, run_id))


# =============================================================================
# STEP 1: Load hospitals due for this role
# =============================================================================

log_info("STEP 1: Loading hospital list from registry")

all_hospitals <- switch(TARGET_MODE,
  due  = get_hospitals_due("strategy"),
  all  = get_hospitals_due("strategy", force_all = TRUE),
  facs = {
    keep <- map_lgl(load_registry(), ~ as.character(.x$FAC) %in% as.character(TARGET_FACS))
    load_registry()[keep]
  }
)

# Filter out robots-disallowed hospitals — they are not failures
robots_ok <- keep_lgl <- map_lgl(all_hospitals, function(h) {
  flag <- h$robots_allowed
  !(!is.null(flag) && (identical(flag, "no") || identical(flag, FALSE)))
})

robots_blocked <- all_hospitals[!robots_ok]
hospitals      <- all_hospitals[robots_ok]

if (length(robots_blocked) > 0) {
  blocked_facs <- map_chr(robots_blocked, ~ as.character(.x$FAC))
  log_info(sprintf("Excluded %d robots-disallowed hospitals: %s",
                   length(robots_blocked), paste(blocked_facs, collapse = ", ")))
  # Record as skipped — not failures
  walk(robots_blocked, function(h) {
    log_outcome(as.character(h$FAC), h$name, "skipped",
                context = "robots_allowed = no in registry")
  })
}

if (length(hospitals) == 0) {
  log_info("No hospitals to process. Exiting.")
  log_run_summary()
  stop("No eligible hospitals found — nothing to do.", call. = FALSE)
}

log_info(sprintf("Hospitals to process: %d", length(hospitals)))


# =============================================================================
# STEP 2: Helper functions
# =============================================================================

# Build the sanitised folder name for a hospital
.make_folder_name <- function(fac, hospital_name) {
  sanitised <- hospital_name |>
    toupper() |>
    str_replace_all("[^A-Z0-9]+", "_") |>
    str_remove("^_|_$")
  sprintf("%s_%s", fac, sanitised)
}

# Build the dated PDF filename
.make_pdf_filename <- function(fac) {
  sprintf("%s_%s.pdf", fac, format(Sys.Date(), "%Y%m%d"))
}

# Build the full local path for saving the PDF
.make_local_path <- function(fac, hospital_name) {
  folder_name <- .make_folder_name(fac, hospital_name)
  pdf_name    <- .make_pdf_filename(fac)
  file.path(STRATEGY_CONFIG$output_root, folder_name, pdf_name)
}

# Choose the seed URL: use base_url (crawler will find the plan from there)
# Note: strategy doesn't have a dedicated seed URL in the registry —
# the crawler starts from base_url and follows scored links.
.get_seed_url <- function(hospital) {
  hospital$base_url
}


# =============================================================================
# STEP 3: Main processing loop
# =============================================================================

log_info(sprintf("%s", strrep("=", 60)))
log_info("STEP 3: Beginning locate-and-download loop")
log_info(sprintf("%s", strrep("=", 60)))

for (i in seq_along(hospitals)) {
  hospital     <- hospitals[[i]]
  fac          <- as.character(hospital$FAC)
  hospital_name <- hospital$name
  seed_url     <- .get_seed_url(hospital)

  log_info(sprintf("--- Hospital %d/%d: FAC %s — %s ---",
                   i, length(hospitals), fac, hospital_name))

  # Update registry: record that a search was attempted today
  update_hospital_status(fac, "strategy", list(
    last_search_date = as.character(Sys.Date())
  ))

  # ------------------------------------------------------------------
  # STEP 3a: Crawl for candidate URLs
  # ------------------------------------------------------------------

  candidates <- tryCatch(
    crawl(
      fac            = fac,
      seed_url       = seed_url,
      hospital       = hospital,
      keywords_tier1 = STRATEGY_CONFIG$keywords_tier1,
      keywords_tier2 = STRATEGY_CONFIG$keywords_tier2,
      max_depth      = STRATEGY_CONFIG$max_depth,
      max_pages      = STRATEGY_CONFIG$max_pages,
      include_pdfs   = TRUE
    ),
    error = function(e) {
      log_warning(sprintf("FAC %s: crawl() threw an error — %s", fac, conditionMessage(e)))
      data.frame()
    }
  )

  if (nrow(candidates) == 0) {
    log_outcome(fac, hospital_name, "failure",
                failure_type  = "crawl_no_candidate",
                error_message = "Crawler returned no scored candidates",
                url           = seed_url)
    update_hospital_status(fac, "strategy", list(
      extraction_status = "crawl_failed",
      needs_review      = TRUE
    ))
    next
  }

  # Pick the best candidate, preferring PDFs
  best_url <- top_candidate(
    fac            = fac,
    seed_url       = seed_url,
    hospital       = hospital,
    keywords_tier1 = STRATEGY_CONFIG$keywords_tier1,
    keywords_tier2 = STRATEGY_CONFIG$keywords_tier2,
    prefer_pdf     = STRATEGY_CONFIG$prefer_pdf
  )

  if (is.null(best_url)) {
    log_outcome(fac, hospital_name, "failure",
                failure_type  = "crawl_no_candidate",
                error_message = "top_candidate() returned NULL",
                url           = seed_url)
    update_hospital_status(fac, "strategy", list(
      extraction_status = "crawl_failed",
      needs_review      = TRUE
    ))
    next
  }

  log_info(sprintf("FAC %s: best candidate — %s (score: %d, is_pdf: %s)",
                   fac, best_url,
                   candidates$score[candidates$url == best_url][1],
                   candidates$is_pdf[candidates$url == best_url][1]))

  # ------------------------------------------------------------------
  # STEP 3b: Determine content type and download
  # ------------------------------------------------------------------

  # Check whether the best candidate is a PDF or an HTML page
  # Use is_pdf flag from candidates first; fall back to HEAD request
  is_pdf_candidate <- isTRUE(
    candidates$is_pdf[candidates$url == best_url][1]
  )

  if (!is_pdf_candidate) {
    # The top candidate is an HTML page — probe to confirm content type
    detected_type <- detect_url_content_type(best_url)
    is_pdf_candidate <- (detected_type == "pdf")
  }

  if (!is_pdf_candidate) {
    # Top candidate is HTML — this is a fallback case.
    # For Phase 1 we record this and flag for manual review.
    # Phase 2 will add HTML handling when needed.
    log_warning(sprintf(
      "FAC %s: top candidate appears to be HTML, not a PDF — flagging for review: %s",
      fac, best_url
    ))
    log_outcome(fac, hospital_name, "failure",
                failure_type  = "no_pdf_found",
                error_message = "Top candidate is HTML; HTML extraction not yet implemented",
                url           = best_url)
    update_hospital_status(fac, "strategy", list(
      content_url       = best_url,
      content_type      = "html",
      extraction_status = "needs_review",
      needs_review      = TRUE
    ))
    next
  }

  # ------------------------------------------------------------------
  # STEP 3c: Download the PDF
  # ------------------------------------------------------------------

  local_path <- .make_local_path(fac, hospital_name)
  folder_name <- .make_folder_name(fac, hospital_name)
  pdf_name    <- .make_pdf_filename(fac)

  log_info(sprintf("FAC %s: downloading PDF to %s", fac, local_path))

  fetch_result <- fetch_pdf(
    fac          = fac,
    url          = best_url,
    hospital     = hospital,
    local_path   = local_path,
    extract_text = STRATEGY_CONFIG$extract_text_on_download
  )

  if (!fetch_result$success) {
    log_outcome(fac, hospital_name, "failure",
                failure_type  = "fetch_error",
                error_message = fetch_result$error_message %||% fetch_result$skip_reason,
                url           = best_url)
    update_hospital_status(fac, "strategy", list(
      content_url       = best_url,
      extraction_status = "download_failed",
      needs_review      = TRUE
    ))
    next
  }

  # ------------------------------------------------------------------
  # STEP 3d: Success — update registry and log outcome
  # ------------------------------------------------------------------

  file_size_kb <- round(fetch_result$metadata$file_size_bytes / 1024, 1)

  update_hospital_status(fac, "strategy", list(
    last_search_date  = as.character(Sys.Date()),
    content_url       = best_url,
    content_type      = "pdf",
    local_folder      = folder_name,
    local_filename    = pdf_name,
    extraction_status = "downloaded",
    manual_override   = FALSE,
    needs_review      = FALSE
  ))

  log_outcome(
    fac           = fac,
    hospital_name = hospital_name,
    outcome       = "success",
    context       = sprintf("%.1f KB — %s", file_size_kb, pdf_name)
  )
}


# =============================================================================
# STEP 4: Run summary
# =============================================================================

log_info(sprintf("%s", strrep("=", 60)))
log_info("STEP 4: Run complete")

summary <- log_run_summary()

# Quick sanity check against the 80% threshold
if (!is.na(summary$success_rate) && summary$success_rate < 80) {
  log_warning(sprintf(
    "Success rate %.1f%% is below the 80%% threshold — review failure log: %s",
    summary$success_rate, summary$failure_file
  ))
}
