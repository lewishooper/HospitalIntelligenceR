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
  library(rvest)
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
robots_ok <- map_lgl(all_hospitals, function(h) {
  flag <- h$robots_allowed
  !(!is.null(flag) && (identical(flag, "no") || identical(flag, FALSE)))
})

robots_blocked <- all_hospitals[!robots_ok]
hospitals      <- all_hospitals[robots_ok]

if (length(robots_blocked) > 0) {
  blocked_facs <- map_chr(robots_blocked, ~ as.character(.x$FAC))
  log_info(sprintf("Excluded %d robots-disallowed hospitals: %s",
                   length(robots_blocked), paste(blocked_facs, collapse = ", ")))
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

.make_folder_name <- function(fac, hospital_name) {
  sanitised <- hospital_name |>
    toupper() |>
    str_replace_all("[^A-Z0-9]+", "_") |>
    str_remove("^_|_$")
  sprintf("%s_%s", fac, sanitised)
}

.make_pdf_filename <- function(fac) {
  sprintf("%s_%s.pdf", fac, format(Sys.Date(), "%Y%m%d"))
}

.make_local_path <- function(fac, hospital_name) {
  folder_name <- .make_folder_name(fac, hospital_name)
  pdf_name    <- .make_pdf_filename(fac)
  file.path(STRATEGY_CONFIG$output_root, folder_name, pdf_name)
}

# Scan an already-fetched HTML page for PDF links.
# Scores each PDF link against role keywords and returns them sorted
# best-first. Returns character(0) if no PDF links are found.
.find_pdfs_on_page <- function(html_content, page_url, hospital, fac) {
  tryCatch({
    nodes  <- html_content |> html_elements("a[href]")
    hrefs  <- html_attr(nodes, "href")
    labels <- html_text2(nodes)
    if (length(hrefs) == 0) return(character(0))
    
    urls <- map_chr(seq_along(hrefs), function(i) {
      href <- hrefs[i]
      if (is.na(href) || nchar(trimws(href)) == 0)   return(NA_character_)
      if (str_detect(href, "^#|^mailto:|^tel:"))      return(NA_character_)
      if (str_detect(href, "^https?://"))             return(href)
      parsed    <- httr2::url_parse(page_url)
      base_root <- sprintf("%s://%s", parsed$scheme, parsed$hostname)
      if (str_starts(href, "/")) return(paste0(base_root, href))
      base_dir <- str_remove(page_url, "[^/]+$")
      paste0(base_dir, href)
    })
    
    valid  <- !is.na(urls)
    urls   <- urls[valid]
    labels <- labels[valid]
    
    # --- Pass 1: direct .pdf links (fast, no HTTP) ---
  
    is_pdf   <- str_detect(tolower(urls), "\\.pdf(\\?|/|$)") & !is.na(urls)
    pdf_urls <- urls[is_pdf]
    pdf_lbls <- labels[is_pdf]
    
    if (length(pdf_urls) > 0) {
      scores <- map_int(seq_along(pdf_urls), function(i) {
        haystack <- tolower(paste(pdf_urls[i], pdf_lbls[i], sep = " "))
        t1 <- sum(map_int(STRATEGY_CONFIG$keywords_tier1, function(kw) {
          if (str_detect(haystack, fixed(tolower(kw)))) 2L else 0L
        }))
        t2 <- sum(map_int(STRATEGY_CONFIG$keywords_tier2, function(kw) {
          if (str_detect(haystack, fixed(tolower(kw)))) 1L else 0L
        }))
        t1 + t2
      })
      return(pdf_urls[order(-scores)])
    }
    
    # --- Pass 2: no direct PDF links — follow promising hrefs via HEAD ---
    scores_all <- map_int(seq_along(urls), function(i) {
      haystack <- tolower(paste(urls[i], labels[i], sep = " "))
      t1 <- sum(map_int(STRATEGY_CONFIG$keywords_tier1, function(kw) {
        if (str_detect(haystack, fixed(tolower(kw)))) 2L else 0L
      }))
      t2 <- sum(map_int(STRATEGY_CONFIG$keywords_tier2, function(kw) {
        if (str_detect(haystack, fixed(tolower(kw)))) 1L else 0L
      }))
      t1 + t2
    })
    
    promising_idx <- which(scores_all >= 1)
    promising_idx <- promising_idx[order(-scores_all[promising_idx])]
    promising_idx <- head(promising_idx, 6)
    
    if (length(promising_idx) == 0) return(character(0))
    
    message(sprintf("[INFO] FAC %s: no direct PDF links — following %d promising link(s) via HEAD",
                    fac, length(promising_idx)))
    
    resolved_pdfs <- map_chr(promising_idx, function(i) {
      ct <- tryCatch(detect_url_content_type(urls[i]), error = function(e) "unknown")
      if (ct == "pdf") {
        message(sprintf("[INFO] FAC %s: redirect resolves to PDF — %s", fac, urls[i]))
        urls[i]
      } else {
        NA_character_
      }
    })
    
    resolved_pdfs <- resolved_pdfs[!is.na(resolved_pdfs)]
    if (length(resolved_pdfs) > 0) resolved_pdfs else character(0)
    
  }, error = function(e) character(0))
}


# =============================================================================
# STEP 3: Main processing loop
# =============================================================================

log_info(sprintf("%s", strrep("=", 60)))
log_info("STEP 3: Beginning locate-and-download loop")
log_info(sprintf("%s", strrep("=", 60)))

for (i in seq_along(hospitals)) {
  hospital      <- hospitals[[i]]
  fac           <- as.character(hospital$FAC)
  hospital_name <- hospital$name
  seed_url      <- hospital$base_url
  strategy_url  <- hospital$status$strategy$strategy_url
  skip_crawl    <- FALSE
  best_url      <- NULL
  best_is_pdf   <- FALSE
  
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
  log_info(sprintf("--- Hospital %d/%d: FAC %s — %s ---",
                   i, length(hospitals), fac, hospital_name))

  # Record that a search was attempted today
  update_hospital_status(fac, "strategy", list(
    last_search_date = as.character(Sys.Date())
  ))

  # ------------------------------------------------------------------
  # STEP 3a: Single crawl — results used for all downstream decisions.
  # top_candidate() is NOT called; it would re-run the crawl internally.
  # ------------------------------------------------------------------
  # ------------------------------------------------------------------
  # STEP 3a: Single crawl — results used for all downstream decisions.
  # Skipped when strategy_url is a direct PDF (skip_crawl == TRUE).
  # ------------------------------------------------------------------
  
  if (!skip_crawl) {
    
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
    
    # ------------------------------------------------------------------
    # STEP 3b: Select best candidate from crawl results.
    # Prefer the highest-scoring PDF; fall back to highest-scoring HTML
    # page (likely a landing page with an embedded PDF download link).
    # ------------------------------------------------------------------
    
    top_score <- candidates$score[1]
    top_tier  <- candidates[candidates$score == top_score, ]
    
    # Tiebreaker: prefer URLs where a tier-1 keyword word appears in the path
    keyword_words <- tolower(unique(unlist(str_split(STRATEGY_CONFIG$keywords_tier1, "\\s+"))))
    url_matches   <- map_lgl(top_tier$url, function(u) {
      any(str_detect(tolower(u), fixed(keyword_words)))
    })
    if (any(url_matches)) top_tier <- top_tier[url_matches, ]
    
    # Among remaining candidates, prefer PDF over HTML
    if (any(top_tier$is_pdf)) {
      best_row <- top_tier[top_tier$is_pdf, ][1, ]
    } else {
      best_row <- top_tier[1, ]
    }
    
    best_url    <- best_row$url
    best_is_pdf <- isTRUE(best_row$is_pdf)
    
    log_info(sprintf("FAC %s: best candidate — %s (score: %d, is_pdf: %s)",
                     fac, best_url, best_row$score, best_is_pdf))
    
  } # end if (!skip_crawl)
  # ------------------------------------------------------------------
  # STEP 3c: Resolve the final PDF URL.
  #
  # Case A — best candidate is already a PDF → use it directly.
  # Case B — best candidate is an HTML page → fetch that page and
  #           look for embedded PDF links. This handles the very common
  #           pattern where the hospital's "Strategic Plan" page is a
  #           content page containing a "Download PDF" link.
  # ------------------------------------------------------------------

  pdf_url <- NULL

  if (best_is_pdf) {

    pdf_url <- best_url

  } else {

    log_info(sprintf(
      "FAC %s: top candidate is an HTML landing page — scanning for embedded PDF links: %s",
      fac, best_url
    ))

    landing_result <- fetch_html(fac, best_url, hospital)

    if (landing_result$success) {
      pdf_candidates <- .find_pdfs_on_page(landing_result$content, best_url, hospital, fac)
      if (length(pdf_candidates) > 0) {
        pdf_url <- pdf_candidates[1]
        log_info(sprintf(
          "FAC %s: found %d PDF link(s) on landing page — using top: %s",
          fac, length(pdf_candidates), pdf_url
        ))
      } else {
        log_warning(sprintf(
          "FAC %s: landing page fetched but contains no PDF links: %s",
          fac, best_url
        ))
      }

    } else {
      log_warning(sprintf(
        "FAC %s: could not fetch landing page — %s",
        fac, landing_result$error_message %||% landing_result$skip_reason
      ))
    }
  }

  if (is.null(pdf_url)) {
    log_outcome(fac, hospital_name, "failure",
                failure_type  = "no_pdf_found",
                error_message = "No PDF located on top candidate page or in crawl results",
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
  # STEP 3d: Download the PDF
  # ------------------------------------------------------------------

  local_path  <- .make_local_path(fac, hospital_name)
  folder_name <- .make_folder_name(fac, hospital_name)
  pdf_name    <- .make_pdf_filename(fac)

  log_info(sprintf("FAC %s: downloading PDF to %s", fac, local_path))

  fetch_result <- fetch_pdf(
    fac          = fac,
    url          = pdf_url,
    hospital     = hospital,
    local_path   = local_path,
    extract_text = STRATEGY_CONFIG$extract_text_on_download
  )

  if (!fetch_result$success) {
    log_outcome(fac, hospital_name, "failure",
                failure_type  = "fetch_error",
                error_message = fetch_result$error_message %||% fetch_result$skip_reason,
                url           = pdf_url)
    update_hospital_status(fac, "strategy", list(
      content_url       = pdf_url,
      extraction_status = "download_failed",
      needs_review      = TRUE
    ))
    next
  }

  # ------------------------------------------------------------------
  # STEP 3e: Success — update registry and log outcome
  # ------------------------------------------------------------------

  file_size_kb <- round(fetch_result$metadata$file_size_bytes / 1024, 1)

  update_hospital_status(fac, "strategy", list(
    last_search_date  = as.character(Sys.Date()),
    content_url       = pdf_url,
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

if (!is.na(summary$success_rate) && summary$success_rate < 80) {
  log_warning(sprintf(
    "Success rate %.1f%% is below the 80%% threshold — review failure log: %s",
    summary$success_rate, summary$failure_file
  ))
}
