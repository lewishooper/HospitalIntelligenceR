# roles/minutes/minutes_scrape.R
# Session 1 — Static scraper for board minutes PDFs
#
# Reads Master_Board_Minutes_062026.rds as input (minutes_url is the key field).
# For each hospital with minutes_found == "Y", fetches the minutes page via rvest,
# extracts all PDF href links (including CSS-hidden accordion/tab sections),
# filters to likely minutes documents, downloads each PDF, and writes minutes_index.csv.
#
# Hospitals where the page loads but yields zero PDFs are flagged js_required
# for Session 3 handling.
#
# Run from project root: E:/HospitalIntelligenceR
# source("roles/minutes/minutes_scrape.R")

library(httr2)
library(rvest)
library(robotstxt)
library(dplyr)
library(stringr)
library(purrr)
library(lubridate)
library(yaml)

# ── Source core infrastructure ─────────────────────────────────────────────────
source("core/fetcher.R")
source("core/logger.R")

# ── Config ─────────────────────────────────────────────────────────────────────
MINUTES_CONFIG <- list(
  yaml_path      = "registry/hospital_registry.yaml",
  extract_dir    = "roles/minutes/outputs/extracted",
  index_file     = "roles/minutes/outputs/minutes_index.csv",
  log_file       = "roles/minutes/outputs/logs/minutes_scrape_log.csv",
  rate_limit_pdf = 1,     # seconds between PDF downloads within a hospital
  max_pdfs       = 100,   # hard cap per hospital — flag if exceeded
  
  # PDF links whose href contains any of these strings are candidates
  include_keywords = c(
    "minute", "board-meeting", "board_meeting", "open.session",
    "open-session", "public.session", "public-session", "bod-"
  ),
  
  # PDF links whose href OR link text contains any of these are excluded
  # Applied AFTER include filter — these override
  exclude_keywords = c(
    "agenda", "annual.report", "annual-report", "financial", "statement",
    "presentation", "slide", "budget", "audit", "committee", "schedule",
    "notice", "policy", "bylaw", "by-law", "newsletter", "accreditation"
  )
)

# ── Logging helpers ────────────────────────────────────────────────────────────
# Minimal inline logger so this script runs without logger.R dependency issues
LOG_LINES <- character(0)

log_info <- function(fmt, ...) {
  body <- if (...length() == 0) fmt else sprintf(fmt, ...)
  msg  <- paste0("[INFO  ", format(Sys.time(), "%H:%M:%S"), "] ", body)
  message(msg)
  LOG_LINES <<- c(LOG_LINES, msg)
}

log_warn <- function(fmt, ...) {
  body <- if (...length() == 0) fmt else sprintf(fmt, ...)
  msg  <- paste0("[WARN  ", format(Sys.time(), "%H:%M:%S"), "] ", body)
  message(msg)
  LOG_LINES <<- c(LOG_LINES, msg)
}

log_error <- function(fmt, ...) {
  body <- if (...length() == 0) fmt else sprintf(fmt, ...)
  msg  <- paste0("[ERROR ", format(Sys.time(), "%H:%M:%S"), "] ", body)
  message(msg)
  LOG_LINES <<- c(LOG_LINES, msg)
}

# ── PDF link extraction ────────────────────────────────────────────────────────
# Extracts all <a href> pointing to PDFs from raw HTML.
# rvest reads the full DOM including CSS-hidden accordion/tab content,
# so no special handling is needed for collapsed sections.

extract_pdf_links <- function(html_content, base_url) {
  # Extract all anchor nodes once — capture href, title attr, and link text together
  # to avoid row-count mismatches from multiple html_elements() calls
  nodes <- html_content |> html_elements("a[href]")
  if (length(nodes) == 0) return(tibble())
  
  all_links <- tibble(
    href       = html_attr(nodes, "href"),
    title_attr = html_attr(nodes, "title"),   # present on Drupal canonical links
    link_text  = str_squish(html_text(nodes))
  )
  
  if (nrow(all_links) == 0) return(tibble())
  
  all_links <- all_links |>
    filter(!is.na(href), str_trim(href) != "") |>
    mutate(
      # Resolve relative URLs
      href_full = case_when(
        str_starts(href, "http")  ~ href,
        str_starts(href, "//")    ~ paste0("https:", href),
        str_starts(href, "/")     ~ paste0(str_extract(base_url, "https?://[^/]+"), href),
        TRUE                      ~ paste0(str_extract(base_url, "https?://[^/]+/.*?(?=/[^/]*$)|https?://[^/]+"), "/", href)
      ),
      href_full = gsub(" ", "%20", href_full, fixed = TRUE),
      # PDF detection:
      # (1) .pdf in href URL
      # (2) .pdf in link title attribute (Drupal canonical links: /documents/document/...)
      # (3) Drupal /documents/document/ path pattern regardless of extension
      is_pdf_href   = str_detect(str_to_lower(href_full), "\\.pdf(\\?|/|$)"),
      is_pdf_title  = !is.na(title_attr) & str_detect(str_to_lower(title_attr), "\\.pdf"),
      is_drupal_doc = str_detect(href_full, "/documents/document/")
    ) |>
    filter(is_pdf_href | is_pdf_title | is_drupal_doc) |>
    select(-is_pdf_href, -is_pdf_title, -is_drupal_doc)
  # title_attr is retained — used downstream for date inference on Drupal links
  
  all_links
}

# ── Keyword filtering ──────────────────────────────────────────────────────────
# Returns TRUE for links that look like minutes (not agendas, reports, etc.)
# Logic: a link passes if it either matches an include keyword OR has no strong
# signal at all (neutral — include by default), AND does not match an exclude keyword.

classify_link <- function(href, link_text) {
  href_lower <- str_to_lower(href)
  text_lower <- str_to_lower(link_text)
  combined   <- paste(href_lower, text_lower)
  
  has_include <- any(str_detect(combined, MINUTES_CONFIG$include_keywords))
  has_exclude <- any(str_detect(combined, MINUTES_CONFIG$exclude_keywords))
  
  if (has_exclude) return(FALSE)
  # If no include signal but also no exclude, pass it through (neutral — be inclusive)
  TRUE
}

# ── Date inference ─────────────────────────────────────────────────────────────
# Attempts to extract a date from: (1) href, (2) link text
# Tries patterns in descending specificity — stops at first match.
# Returns YYYY-MM-DD string or NA.

infer_date <- function(href, link_text, title_attr = NA_character_) {
  # title_attr carries Drupal <a title="Summary of Month DD YYYY Board Meeting.pdf"> strings
  candidates <- c(href, link_text, if (!is.na(title_attr)) title_attr else NULL)
  
  MONTHS_FULL  <- "january|february|march|april|may|june|july|august|september|october|november|december"
  MONTHS_ABBR  <- "jan\\.?|feb\\.?|mar\\.?|apr\\.?|may\\.?|jun\\.?|jul\\.?|aug\\.?|sep\\.?|oct\\.?|nov\\.?|dec\\.?"
  MONTHS_ANY   <- paste0("(?:", MONTHS_FULL, "|", MONTHS_ABBR, ")")
  
  for (src in candidates) {
    s <- str_to_lower(src)
    
    # P1: ISO / numeric: YYYY-MM-DD or YYYY_MM_DD
    m <- str_extract(s, "\\d{4}[-_]\\d{2}[-_]\\d{2}")
    if (!is.na(m)) {
      d <- tryCatch(as.Date(str_replace_all(m, "_", "-")), error = function(e) NA)
      if (!is.na(d) && d >= as.Date("2000-01-01") && d <= Sys.Date() + 365)
        return(format(d, "%Y-%m-%d"))
    }
    
    # P2: DD Month YYYY  e.g. "26 October 2024", "26 Oct. 2024"
    m <- str_extract(s, paste0("(\\d{1,2})[\\s_-](", MONTHS_ANY, ")[\\s_.,/-]*(20[12]\\d)"))
    if (!is.na(m)) {
      m_clean <- str_replace_all(m, "\\.", "")
      d <- tryCatch(parse_date_time(m_clean, orders = c("dmY", "dBY"), quiet = TRUE),
                    error = function(e) NA)
      if (!is.na(d)) return(format(as.Date(d), "%Y-%m-%d"))
    }
    
    # P3: Month DD, YYYY  e.g. "October 26, 2024", "Oct. 26, 2024"
    m <- str_extract(s, paste0("(", MONTHS_ANY, ")[\\s_]+(\\d{1,2})[,\\s]+(20[12]\\d)"))
    if (!is.na(m)) {
      m_clean <- str_replace_all(m, "\\.", "")
      d <- tryCatch(parse_date_time(m_clean, orders = c("Bdy", "bdY", "bdy"), quiet = TRUE),
                    error = function(e) NA)
      if (!is.na(d)) return(format(as.Date(d), "%Y-%m-%d"))
    }
    
    # P4: Month YYYY  e.g. "January 2024", "Jan 2024", "Oct. 2024"
    m <- str_extract(s, paste0("(", MONTHS_ANY, ")[\\s_-]+(20[12]\\d)"))
    if (!is.na(m)) {
      m_clean <- str_replace_all(m, "\\.", "")
      d <- tryCatch(parse_date_time(m_clean, orders = c("BY", "bY"), quiet = TRUE),
                    error = function(e) NA)
      if (!is.na(d)) return(format(as.Date(d), "%Y-%m-%01"))
    }
    
    # P5: YYYY-MM in URL path  e.g. /2024-09/
    m <- str_extract(s, "20[12]\\d[-_](0[1-9]|1[0-2])(?![-_]\\d{2})")
    if (!is.na(m)) {
      d <- tryCatch(as.Date(paste0(str_replace(m, "[-_]", "-"), "-01")),
                    error = function(e) NA)
      if (!is.na(d)) return(format(d, "%Y-%m-%01"))
    }
  }
  
  # P6: YYYY alone — last resort, href only (not link text to avoid false positives)
  m <- str_extract(str_to_lower(href), "(?<![0-9])20[12][0-9](?![0-9])")
  if (!is.na(m)) return(paste0(m, "-01-01"))
  
  NA_character_
}

# ── Build output filename ──────────────────────────────────────────────────────
make_filename <- function(date_str, seq_n, href) {
  ext <- if (str_detect(href, "\\.pdf", negate = FALSE)) ".pdf" else ".pdf"
  if (!is.na(date_str) && !str_detect(date_str, "^\\d{4}-01-01$")) {
    sprintf("%s_board_minutes%s", date_str, ext)
  } else if (!is.na(date_str)) {
    sprintf("%s_board_minutes_yearonly%s", date_str, ext)
  } else {
    sprintf("UNKNOWN_DATE_%03d_board_minutes%s", seq_n, ext)
  }
}

# Deduplicate filenames within a hospital by appending _v2, _v3, ...
deduplicate_filename <- function(filename, used_names) {
  if (!filename %in% used_names) return(filename)
  base  <- str_remove(filename, "\\.pdf$")
  n     <- 2L
  while (TRUE) {
    candidate <- sprintf("%s_v%d.pdf", base, n)
    if (!candidate %in% used_names) return(candidate)
    n <- n + 1L
  }
}

# ── Stub hospital object for fetcher.R robots check ───────────────────────────
# fetcher.R's check_fetch_permitted() needs a hospital list with $robots_allowed.
# Since we're not using the YAML registry here, we create a minimal stub.
make_hospital_stub <- function(robots_allowed = "yes") {
  list(robots_allowed = robots_allowed)
}

# ── Main scrape loop ───────────────────────────────────────────────────────────
run_minutes_scrape <- function(fac_filter = NULL) {
  
  # Load registry from YAML
  registry  <- read_yaml(MINUTES_CONFIG$yaml_path)
  hospitals <- registry$hospitals
  log_info("Loaded YAML registry: %d hospitals", length(hospitals))
  
  # Flatten to dataframe — pull board minutes fields only
  master <- bind_rows(lapply(hospitals, function(h) {
    board <- h$status$board
    data.frame(
      fac           = as.character(h$FAC),
      hospital_name = as.character(h$name),
      hospital_group = as.character(h$hospital_type %||% ""),
      base_url      = as.character(h$base_url %||% ""),
      minutes_found = str_to_upper(as.character(board$minutes_found %||% "")),
      minutes_url   = str_trim(as.character(board$minutes_url %||% "")),
      stringsAsFactors = FALSE
    )
  }))
  
  # Build folder_name (matches init script convention: FAC_HOSPITALNAME)
  master <- master |>
    mutate(
      # uppercase first, THEN strip non-alphanumeric — order matters in R since [A-Z] is uppercase only
      folder_name = paste0(
        fac, "_",
        str_replace_all(str_replace_all(str_to_upper(hospital_name), "[^A-Z0-9 ]", ""), "\\s+", "_")
      )
    )
  
  # Subset to hospitals with confirmed minutes URLs
  targets <- master |>
    filter(
      minutes_found == "Y",
      !is.na(minutes_url),
      str_trim(minutes_url) != "",
      str_starts(minutes_url, "http")
    )
  
  if (!is.null(fac_filter)) {
    targets <- targets |> filter(fac %in% as.character(fac_filter))
  }
  
  log_info("Hospitals to scrape: %d", nrow(targets))
  
  # Ensure output dirs exist
  dir.create(file.path(MINUTES_CONFIG$extract_dir), recursive = TRUE, showWarnings = FALSE)
  dir.create(dirname(MINUTES_CONFIG$index_file),    recursive = TRUE, showWarnings = FALSE)
  dir.create(dirname(MINUTES_CONFIG$log_file),      recursive = TRUE, showWarnings = FALSE)
  
  # Load existing index if present (enables re-run / incremental)
  if (file.exists(MINUTES_CONFIG$index_file)) {
    index_existing <- read.csv(MINUTES_CONFIG$index_file, stringsAsFactors = FALSE)
    index_existing$fac           <- as.character(index_existing$fac)
    index_existing$download_date  <- as.character(index_existing$download_date)   # NA reads as logical without this
    index_existing$file_size_kb   <- as.numeric(index_existing$file_size_kb)
    log_info("Existing index loaded: %d rows", nrow(index_existing))
  } else {
    index_existing <- NULL
  }
  
  # Accumulate results
  index_rows   <- list()
  hospital_log <- list()
  
  for (i in seq_len(nrow(targets))) {
    row  <- targets[i, ]
    fac  <- as.character(row$fac)
    name <- as.character(row$hospital_name)
    url  <- as.character(row$minutes_url)
    
    log_info("--- FAC %s | %s", fac, name)
    
    # Hospital output folder
    folder_name <- as.character(row$folder_name)
    out_dir     <- file.path(MINUTES_CONFIG$extract_dir, folder_name)
    dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
    
    # ── Step 1: Fetch the minutes page ──────────────────────────────────────
    hospital_stub <- make_hospital_stub()
    url <- str_trim(gsub("%20", "", url, fixed = TRUE))  # strip encoded trailing spaces
    fetch_result  <- fetch_html(fac, url, hospital_stub)
    
    if (!fetch_result$success) {
      log_warn("FAC %s: page fetch failed (%s) — %s",
               fac, fetch_result$skip_reason, fetch_result$error_message %||% "")
      hospital_log[[i]] <- list(
        fac           = fac,
        hospital_name = name,
        minutes_url   = url,
        status        = fetch_result$skip_reason,
        n_pdfs_found  = 0,
        n_downloaded  = 0,
        notes         = fetch_result$error_message %||% ""
      )
      next
    }
    
    # ── Step 2: Extract all PDF links (including hidden accordion content) ──
    pdf_links <- extract_pdf_links(fetch_result$content, url)
    log_info("FAC %s: %d raw PDF links found on page", fac, nrow(pdf_links))
    
    # ── Step 3: Keyword filter ───────────────────────────────────────────────
    if (nrow(pdf_links) > 0) {
      pdf_links <- pdf_links |>
        rowwise() |>
        mutate(keep = classify_link(href_full, link_text)) |>
        ungroup() |>
        filter(keep) |>
        select(-keep) |>
        distinct(href_full, .keep_all = TRUE)  # deduplicate same URL
    }
    
    n_candidates <- nrow(pdf_links)
    log_info("FAC %s: %d PDF candidates after keyword filter", fac, n_candidates)
    
    # ── Step 4: Classify outcome if zero candidates ──────────────────────────
    if (n_candidates == 0) {
      # Distinguish: did the page have ANY pdf links at all?
      all_pdfs_raw <- extract_pdf_links(fetch_result$content, url)
      status_code  <- if (nrow(all_pdfs_raw) > 0) "js_required" else "zero_pdfs"
      log_warn("FAC %s: status = %s", fac, status_code)
      hospital_log[[i]] <- list(
        fac           = fac,
        hospital_name = name,
        minutes_url   = url,
        status        = status_code,
        n_pdfs_found  = 0,
        n_downloaded  = 0,
        notes         = sprintf("Page fetched OK; %d raw PDF hrefs on page (all excluded by filter or none present)",
                                nrow(all_pdfs_raw))
      )
      next
    }
    
    # Cap at max_pdfs
    if (n_candidates > MINUTES_CONFIG$max_pdfs) {
      log_warn("FAC %s: %d candidates exceeds cap of %d — truncating and flagging",
               fac, n_candidates, MINUTES_CONFIG$max_pdfs)
      pdf_links   <- pdf_links[seq_len(MINUTES_CONFIG$max_pdfs), ]
      cap_exceeded <- TRUE
    } else {
      cap_exceeded <- FALSE
    }
    
    # ── Step 5: Download each PDF ────────────────────────────────────────────
    used_filenames <- character(0)
    n_downloaded   <- 0L
    unknown_seq    <- 0L
    
    for (j in seq_len(nrow(pdf_links))) {
      pdf_href   <- pdf_links$href_full[j]
      pdf_text   <- pdf_links$link_text[j]
      pdf_title  <- if ("title_attr" %in% names(pdf_links)) pdf_links$title_attr[j] else NA_character_
      
      # Infer date and build filename — title_attr carries Drupal meeting date strings
      date_str  <- infer_date(pdf_href, pdf_text, pdf_title)
      if (is.na(date_str)) unknown_seq <- unknown_seq + 1L
      raw_fname <- make_filename(date_str, unknown_seq, pdf_href)
      fname     <- deduplicate_filename(raw_fname, used_filenames)
      used_filenames <- c(used_filenames, fname)
      
      local_path <- file.path(out_dir, fname)
      
      # Skip if already downloaded
      if (file.exists(local_path)) {
        log_info("FAC %s: already exists — skipping %s", fac, fname)
        n_downloaded <- n_downloaded + 1L
        index_rows[[length(index_rows) + 1]] <- list(
          fac           = fac,
          hospital_name = name,
          folder_name   = folder_name,
          filename      = fname,
          doc_date      = date_str %||% NA_character_,
          source_url    = pdf_href,
          download_date = NA_character_,
          file_size_kb  = round(file.info(local_path)$size / 1024, 1),
          status        = "already_exists"
        )
        next
      }
      
      # Download via fetcher.R (handles rate limiting, robots, size check)
      Sys.sleep(MINUTES_CONFIG$rate_limit_pdf)
      dl <- fetch_pdf(fac, pdf_href, hospital_stub, local_path, extract_text = FALSE)
      
      if (dl$success) {
        n_downloaded <- n_downloaded + 1L
        log_info("FAC %s: downloaded %s", fac, fname)
        index_rows[[length(index_rows) + 1]] <- list(
          fac           = fac,
          hospital_name = name,
          folder_name   = folder_name,
          filename      = fname,
          doc_date      = date_str %||% NA_character_,
          source_url    = pdf_href,
          download_date = as.character(Sys.Date()),
          file_size_kb  = round(dl$metadata$file_size_bytes / 1024, 1),
          status        = "downloaded"
        )
      } else {
        log_warn("FAC %s: download failed for %s — %s",
                 fac, pdf_href, dl$skip_reason %||% "unknown")
        index_rows[[length(index_rows) + 1]] <- list(
          fac           = fac,
          hospital_name = name,
          folder_name   = folder_name,
          filename      = fname,
          doc_date      = date_str %||% NA_character_,
          source_url    = pdf_href,
          download_date = NA_character_,
          file_size_kb  = NA_real_,
          status        = paste0("failed_", dl$skip_reason %||% "unknown")
        )
      }
    }
    
    hosp_status <- if (cap_exceeded) "success_capped" else if (n_downloaded == 0) "zero_downloaded" else "success"
    log_info("FAC %s: %d/%d PDFs downloaded — status: %s",
             fac, n_downloaded, n_candidates, hosp_status)
    
    hospital_log[[i]] <- list(
      fac           = fac,
      hospital_name = name,
      minutes_url   = url,
      status        = hosp_status,
      n_pdfs_found  = n_candidates,
      n_downloaded  = n_downloaded,
      notes         = if (cap_exceeded) sprintf("Capped at %d", MINUTES_CONFIG$max_pdfs) else ""
    )
  }
  
  # ── Write minutes_index.csv ────────────────────────────────────────────────
  if (length(index_rows) > 0) {
    index_new <- bind_rows(lapply(index_rows, as.data.frame, stringsAsFactors = FALSE))
    # Ensure character types throughout — CSV round-trip can coerce fac/file_size_kb
    index_new <- index_new |>
      mutate(fac = as.character(fac), file_size_kb = as.numeric(file_size_kb))
    
    if (!is.null(index_existing)) {
      # Coerce existing index to match — prevents bind_rows type conflicts
      index_existing <- index_existing |>
        mutate(
          fac           = as.character(fac),
          download_date = as.character(download_date),
          file_size_kb  = as.numeric(file_size_kb)
        )
      # Merge: keep existing rows for hospitals not re-run; replace rows for re-run hospitals
      run_facs      <- unique(targets$fac)
      index_kept    <- index_existing |> filter(!fac %in% run_facs)
      index_final   <- bind_rows(index_kept, index_new)
    } else {
      index_final <- index_new
    }
    
    write.csv(index_final, MINUTES_CONFIG$index_file, row.names = FALSE)
    log_info("minutes_index.csv written: %d rows", nrow(index_final))
  } else {
    log_warn("No index rows generated — check that minutes_found == 'Y' rows have valid URLs")
  }
  
  # ── Write hospital-level log ───────────────────────────────────────────────
  hosp_log_df <- bind_rows(lapply(hospital_log, function(x) {
    as.data.frame(x, stringsAsFactors = FALSE)
  }))
  write.csv(hosp_log_df, MINUTES_CONFIG$log_file, row.names = FALSE)
  
  # ── Console summary ────────────────────────────────────────────────────────
  cat("\n=== SCRAPE SUMMARY ===\n")
  if (nrow(hosp_log_df) > 0) {
    status_tbl <- table(hosp_log_df$status)
    print(status_tbl)
    cat(sprintf("\nTotal PDFs downloaded: %d\n", sum(hosp_log_df$n_downloaded, na.rm = TRUE)))
    cat(sprintf("Total hospitals attempted: %d\n", nrow(hosp_log_df)))
    
    # Flag hospitals needing Session 3 attention
    js_cases <- hosp_log_df |> filter(status == "js_required")
    if (nrow(js_cases) > 0) {
      cat(sprintf("\n--- JS_REQUIRED (%d hospitals — Session 3 candidates) ---\n", nrow(js_cases)))
      print(js_cases |> select(fac, hospital_name, minutes_url))
    }
    
    zero_cases <- hosp_log_df |> filter(status == "zero_pdfs")
    if (nrow(zero_cases) > 0) {
      cat(sprintf("\n--- ZERO_PDFS (%d hospitals — confirm manually) ---\n", nrow(zero_cases)))
      print(zero_cases |> select(fac, hospital_name, minutes_url))
    }
  }
  
  invisible(list(index = if (exists("index_final")) index_final else NULL,
                 log   = hosp_log_df))
}

# ── Entry point ────────────────────────────────────────────────────────────────
# To run all hospitals with confirmed URLs:
#   results <- run_minutes_scrape()
#
# To run a test cohort first (recommended):
#   results <- run_minutes_scrape(fac_filter = c("644", "736", "826", "858", "941"))
#
# fac_filter accepts any character or numeric vector of FAC codes.


MINUTES_CONFIG$max_pdfs <- 150
results <- run_minutes_scrape(fac_filter = c("661", "939"))
