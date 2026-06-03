# minutes_recon_helper.R
# Automated reconnaissance for a single hospital's board minutes page.
# Run interactively for each hospital in your sample.
# Fills in what it can; flags what needs manual review.
#
# Usage:
#   source("minutes_recon_helper.R")
#   recon_hospital(
#     fac          = "953",
#     hospital     = "Sunnybrook Hospital",
#     type_group   = "Teaching",
#     base_url     = "https://sunnybrook.ca",
#     minutes_url  = "https://sunnybrook.ca/about-sunnybrook/governance-leadership/"
#   )

library(httr2)
library(rvest)
library(stringr)
library(robotstxt)

# ── Configuration ─────────────────────────────────────────────────────────────

RATE_LIMIT_SECONDS <- 3
USER_AGENT         <- "HospitalIntelligenceR/1.0 (research; contact: [lewishooper@gmail.com])"

# Month names for date parsing
MONTH_NAMES <- c(
  "january|jan", "february|feb", "march|mar", "april|apr",
  "may", "june|jun", "july|jul", "august|aug",
  "september|sep|sept", "october|oct", "november|nov", "december|dec"
)

# Keywords that signal in-camera content
INCAMERA_KEYWORDS <- c(
  "in-camera", "in camera", "closed session", "private session",
  "confidential", "in-cam", "incam"
)

# Keywords that suggest a non-minutes PDF (to flag as noise)
SKIP_KEYWORDS <- c(
  "agenda", "notice of meeting", "annual report", "financial statement",
  "presentation", "slide", "budget", "bylaw", "policy"
)


# ── Helpers ───────────────────────────────────────────────────────────────────

safe_fetch <- function(url, timeout = 15) {
  Sys.sleep(RATE_LIMIT_SECONDS)
  tryCatch({
    resp <- request(url) |>
      req_user_agent(USER_AGENT) |>
      req_timeout(timeout) |>
      req_perform()
    list(success = TRUE, status = resp_status(resp), body = resp_body_string(resp), url = url)
  }, error = function(e) {
    list(success = FALSE, status = NA, body = NULL, url = url, error = e$message)
  })
}

check_robots <- function(base_url, minutes_url) {
  tryCatch({
    rt <- robotstxt::robotstxt(domain = base_url)
    allowed <- rt$check(paths = sub(base_url, "", minutes_url, fixed = TRUE),
                        bot   = "*")
    if (isTRUE(allowed)) "yes" else "no"
  }, error = function(e) "unknown")
}

detect_page_structure <- function(html_body, url) {
  # SharePoint - URL or body signals
  if (str_detect(url, "sharepoint\\.com|/sites/|/_layouts/")) return("sharepoint")
  if (str_detect(html_body, "SharePoint|spPageContextInfo|ms-site-body")) return("sharepoint")
  
  # iFrame - minutes content loaded from another domain
  iframes <- str_extract_all(html_body, '<iframe[^>]+src=["\']([^"\']+)["\']')[[1]]
  if (length(iframes) > 0) return("iframe")
  
  # Document library - JS-rendered widgets common in CMS platforms
  dl_signals <- c(
    "document-library", "documentlibrary", "file-manager",
    "kentico", "sitefinity", "umbraco",
    "data-document", "data-file", "vue-app",
    # Angular / React apps that render file lists
    "ng-app", "ng-controller", "__NEXT_DATA__", "window\\.__reactFiber"
  )
  if (any(str_detect(html_body, dl_signals))) return("document-library")
  
  # Standard HTML — PDF links visible in raw source
  pdf_links <- str_extract_all(html_body, 'href=["\'][^"\']*\\.pdf[^"\']*["\']')[[1]]
  if (length(pdf_links) > 0) return("standard-html")
  
  # No PDF links found but page loaded — could be JS-rendered
  "unknown"
}

detect_link_format <- function(html_body, base_url, sample_n = 3) {
  # Extract all PDF hrefs
  hrefs <- str_extract_all(html_body, 'href=["\']([^"\']*\\.pdf[^"\']*)["\']')[[1]]
  hrefs <- str_replace_all(hrefs, 'href=["\']|["\']$', "")
  
  if (length(hrefs) == 0) return(list(format = "unknown", sample_urls = character(0)))
  
  # Resolve relative URLs
  hrefs <- ifelse(str_starts(hrefs, "http"), hrefs,
                  paste0(str_remove(base_url, "/$"), "/", str_remove(hrefs, "^/")))
  
  # Check a sample: does HEAD return PDF content-type directly?
  sample_urls <- head(hrefs, sample_n)
  formats <- vapply(sample_urls, function(u) {
    Sys.sleep(1)
    tryCatch({
      resp <- request(u) |>
        req_user_agent(USER_AGENT) |>
        req_timeout(10) |>
        req_method("HEAD") |>
        req_perform()
      ct <- resp_headers(resp)[["content-type"]] %||% ""
      if (str_detect(ct, "pdf")) "direct-pdf" else "redirect-landing"
    }, error = function(e) "unknown")
  }, character(1))
  
  format_summary <- if (length(unique(formats)) == 1) unique(formats) else "mixed"
  list(format = format_summary, sample_urls = sample_urls)
}

classify_pdf_name_pattern <- function(filename) {
  fn <- str_to_lower(filename)
  
  # Numeric date prefix: YYYY-MM-DD or YYYYMMDD at start
  if (str_detect(fn, "^\\d{4}[-_]\\d{2}[-_]\\d{2}")) return("date-prefix")
  if (str_detect(fn, "^\\d{8}"))                       return("date-prefix")
  
  # Month-name + year at start
  month_pat <- paste(MONTH_NAMES, collapse = "|")
  if (str_detect(fn, paste0("^(", month_pat, ")[-_. ]"))) return("date-prefix")
  
  # Numeric date suffix before .pdf
  if (str_detect(fn, "\\d{4}[-_]\\d{2}[-_]\\d{2}\\.pdf$")) return("date-suffix")
  if (str_detect(fn, "\\d{8}\\.pdf$"))                       return("date-suffix")
  
  # Month-name suffix
  if (str_detect(fn, paste0("(", month_pat, ")[-_. ]?\\d{4}\\.pdf$"))) return("date-suffix")
  
  # Any date-like pattern anywhere
  if (str_detect(fn, "\\d{4}") && str_detect(fn, month_pat)) return("date-suffix")
  
  "no-date"
}

extract_year_from_name <- function(filename) {
  years <- str_extract_all(filename, "20[1-3][0-9]")[[1]]
  if (length(years) == 0) return(NA_integer_)
  as.integer(years)
}

estimate_backlog <- function(all_filenames, link_texts) {
  # Pull years from filenames and link anchor text
  all_text <- c(all_filenames, link_texts)
  years     <- unlist(lapply(all_text, extract_year_from_name))
  years     <- years[!is.na(years) & years >= 2010 & years <= as.integer(format(Sys.Date(), "%Y"))]
  
  if (length(years) == 0) return(list(depth = "unknown", oldest = NA, newest = NA))
  
  oldest <- min(years)
  newest <- max(years)
  span   <- as.integer(format(Sys.Date(), "%Y")) - oldest
  
  depth <- dplyr::case_when(
    span < 1  ~ "< 1 yr",
    span <= 2 ~ "1-2 yrs",
    span <= 5 ~ "3-5 yrs",
    TRUE      ~ "5+ yrs"
  )
  list(depth = depth, oldest = oldest, newest = newest)
}

detect_incamera <- function(link_texts, all_filenames) {
  combined <- str_to_lower(paste(c(link_texts, all_filenames), collapse = " "))
  hits      <- INCAMERA_KEYWORDS[str_detect(combined, INCAMERA_KEYWORDS)]
  
  if (length(hits) == 0) return(list(signal = "not-published", keywords_found = character(0)))
  
  # Check if in-camera appears as separate links vs inline
  separate_signals <- c("in-camera", "in camera", "closed session", "private session")
  if (any(str_detect(combined, paste(separate_signals, collapse = "|")))) {
    return(list(signal = "separate-doc (verify)", keywords_found = hits))
  }
  list(signal = "redacted-inline (verify)", keywords_found = hits)
}

detect_login_wall <- function(fetch_result) {
  if (!fetch_result$success) return("unknown — fetch failed")
  if (fetch_result$status %in% c(401, 403)) return("yes")
  
  login_signals <- c(
    "login", "sign in", "sign-in", "password", "username",
    "staff portal", "employee portal", "authentication required"
  )
  body_lower <- str_to_lower(fetch_result$body %||% "")
  if (any(str_detect(body_lower, login_signals))) return("yes — verify manually")
  "no"
}

flag_noise_pdfs <- function(link_texts) {
  hits <- vapply(link_texts, function(lt) {
    any(str_detect(str_to_lower(lt), SKIP_KEYWORDS))
  }, logical(1))
  link_texts[hits]
}


# ── Main recon function ───────────────────────────────────────────────────────

recon_hospital <- function(fac, hospital, type_group, base_url, minutes_url) {
  
  cat("\n", strrep("=", 60), "\n")
  cat("MINUTES RECON:", hospital, "(FAC:", fac, ")\n")
  cat(strrep("=", 60), "\n\n")
  
  # 1. Robots
  cat("Checking robots.txt...\n")
  robots <- check_robots(base_url, minutes_url)
  cat("  Robots allowed:", robots, "\n\n")
  
  if (robots == "no") {
    cat("  !! STOP: robots.txt blocks this domain. Flag as robots_blocked.\n")
    cat("  No further automated checks will be run.\n\n")
    print_summary(fac, hospital, type_group, minutes_url,
                  robots = "no",
                  login = "not checked",
                  structure = "not checked",
                  link_format = "not checked",
                  backlog = list(depth = "not checked", oldest = NA, newest = NA),
                  naming = "not checked",
                  incamera = list(signal = "not checked", keywords_found = character(0)),
                  pdf_count = 0, noise_count = 0, sample_pdfs = character(0),
                  notes = "ROBOTS BLOCKED — defer")
    return(invisible(NULL))
  }
  
  # 2. Fetch minutes page
  cat("Fetching minutes page...\n")
  result <- safe_fetch(minutes_url)
  
  # 3. Login wall
  login <- detect_login_wall(result)
  cat("  Login required:", login, "\n\n")
  
  if (!result$success || str_starts(login, "yes")) {
    cat("  !! Page not accessible. Check manually.\n\n")
    print_summary(fac, hospital, type_group, minutes_url,
                  robots = robots, login = login,
                  structure = "unknown — not accessible",
                  link_format = "unknown", naming = "unknown",
                  backlog = list(depth = "unknown", oldest = NA, newest = NA),
                  incamera = list(signal = "unknown", keywords_found = character(0)),
                  pdf_count = 0, noise_count = 0, sample_pdfs = character(0),
                  notes = paste("Fetch failed:", result$error %||% "login wall"))
    return(invisible(NULL))
  }
  
  html_body  <- result$body
  page       <- tryCatch(read_html(html_body), error = function(e) NULL)
  
  # 4. Page structure
  cat("Detecting page structure...\n")
  structure <- detect_page_structure(html_body, minutes_url)
  cat("  Page structure:", structure, "\n")
  
  if (structure %in% c("sharepoint", "document-library", "iframe")) {
    cat("  !! JS-rendered or embedded content — PDF links may not be in raw HTML.\n")
    cat("  !! Manual inspection required for link format and PDF list.\n\n")
  }
  
  # 5. PDF links from raw HTML
  pdf_hrefs  <- character(0)
  link_texts <- character(0)
  
  if (!is.null(page)) {
    links      <- html_nodes(page, "a")
    all_hrefs  <- html_attr(links, "href") %||% character(0)
    all_texts  <- html_text(links, trim = TRUE)
    
    pdf_idx    <- str_detect(all_hrefs %||% "", "\\.pdf") & !is.na(all_hrefs)
    pdf_hrefs  <- all_hrefs[pdf_idx]
    link_texts <- all_texts[pdf_idx]
  }
  
  pdf_count  <- length(pdf_hrefs)
  cat("  PDF links found in raw HTML:", pdf_count, "\n\n")
  
  # 6. Link format
  cat("Checking link format (sampling up to 3 PDFs)...\n")
  if (pdf_count > 0) {
    lf <- detect_link_format(html_body, base_url)
    cat("  Link format:", lf$format, "\n")
    cat("  Sampled URLs:\n")
    for (u in lf$sample_urls) cat("   ", u, "\n")
  } else {
    lf <- list(format = "unknown — no PDFs in raw HTML", sample_urls = character(0))
    cat("  Link format: unknown (no raw PDF links found)\n")
  }
  cat("\n")
  
  # 7. Naming pattern
  filenames <- basename(pdf_hrefs)
  patterns  <- if (length(filenames) > 0) vapply(filenames, classify_pdf_name_pattern, character(1)) else character(0)
  naming    <- if (length(patterns) == 0) "unknown" else
    if (length(unique(patterns)) == 1) unique(patterns) else "inconsistent"
  
  cat("PDF naming pattern:", naming, "\n")
  if (length(filenames) > 0) {
    cat("  Sample filenames:\n")
    for (f in head(filenames, 4)) cat("   ", f, "\n")
  }
  cat("\n")
  
  # 8. Backlog depth
  cat("Estimating backlog depth...\n")
  backlog <- estimate_backlog(filenames, link_texts)
  cat("  Depth:", backlog$depth,
      "| Oldest year seen:", backlog$oldest %||% "N/A",
      "| Newest year seen:", backlog$newest %||% "N/A", "\n\n")
  
  # 9. In-camera signals
  cat("Checking for in-camera signals...\n")
  incamera <- detect_incamera(link_texts, filenames)
  cat("  In-camera signal:", incamera$signal, "\n")
  if (length(incamera$keywords_found) > 0)
    cat("  Keywords found:", paste(incamera$keywords_found, collapse = ", "), "\n")
  cat("\n")
  
  # 10. Noise PDFs (agendas, reports, etc.)
  noise    <- flag_noise_pdfs(link_texts)
  noise_ct <- length(noise)
  if (noise_ct > 0) {
    cat("  Non-minutes PDFs flagged as noise (", noise_ct, "):\n", sep = "")
    for (n in head(noise, 4)) cat("   ", n, "\n")
    cat("\n")
  }
  
  # Summary
  print_summary(fac, hospital, type_group, minutes_url,
                robots       = robots,
                login        = login,
                structure    = structure,
                link_format  = lf$format,
                backlog      = backlog,
                naming       = naming,
                incamera     = incamera,
                pdf_count    = pdf_count,
                noise_count  = noise_ct,
                sample_pdfs  = head(filenames, 3),
                notes        = "")
}


# ── Summary printer ───────────────────────────────────────────────────────────

print_summary <- function(fac, hospital, type_group, minutes_url,
                          robots, login, structure, link_format,
                          backlog, naming, incamera,
                          pdf_count, noise_count, sample_pdfs, notes) {
  cat(strrep("-", 60), "\n")
  cat("SUMMARY — copy to Reconnaissance Checklist\n")
  cat(strrep("-", 60), "\n")
  cat(sprintf("  FAC:               %s\n", fac))
  cat(sprintf("  Hospital:          %s\n", hospital))
  cat(sprintf("  Type group:        %s\n", type_group))
  cat(sprintf("  Minutes URL:       %s\n", minutes_url))
  cat(sprintf("  Robots allowed:    %s\n", robots))
  cat(sprintf("  Login required:    %s\n", login))
  cat(sprintf("  Page structure:    %s\n", structure))
  cat(sprintf("  Link format:       %s\n", link_format))
  cat(sprintf("  Backlog depth:     %s  (oldest: %s, newest: %s)\n",
              backlog$depth, backlog$oldest %||% "N/A", backlog$newest %||% "N/A"))
  cat(sprintf("  PDF naming:        %s\n", naming))
  cat(sprintf("  In-camera signal:  %s\n", incamera$signal))
  cat(sprintf("  PDFs in raw HTML:  %d  (non-minutes noise: %d)\n", pdf_count, noise_count))
  if (length(sample_pdfs) > 0) {
    cat("  Sample filenames:\n")
    for (f in sample_pdfs) cat("   ", f, "\n")
  }
  if (nchar(notes) > 0) cat(sprintf("  Notes:             %s\n", notes))
  
  # Flags for manual follow-up
  flags <- character(0)
  if (structure %in% c("sharepoint", "document-library", "iframe"))
    flags <- c(flags, "JS-rendered content: PDF list may be incomplete")
  if (str_detect(link_format, "redirect"))
    flags <- c(flags, "redirect-landing: scraper needs two-hop logic")
  if (naming == "inconsistent")
    flags <- c(flags, "Inconsistent naming: date parser needs robust fallback")
  if (str_detect(incamera$signal, "verify"))
    flags <- c(flags, "In-camera: open a document to confirm handling")
  if (pdf_count == 0 && structure == "standard-html")
    flags <- c(flags, "No PDFs in raw HTML despite standard-html — check manually")
  if (noise_count > 0)
    flags <- c(flags, paste0(noise_count, " non-minutes PDFs found: tighten skip_keywords"))
  
  if (length(flags) > 0) {
    cat("\n  !! FOLLOW-UP FLAGS:\n")
    for (f in flags) cat("     - ", f, "\n")
  }
  cat(strrep("=", 60), "\n\n")
}

# ── Null coalescing ───────────────────────────────────────────────────────────
`%||%` <- function(a, b) if (!is.null(a) && length(a) > 0 && !is.na(a[1])) a else b

cat("minutes_recon_helper.R loaded.\n")
cat("Usage: recon_hospital(fac, hospital, type_group, base_url, minutes_url)\n\n")
cat("Example:\n")
cat('  recon_hospital(\n')
cat('    fac        = "953",\n')
cat('    hospital   = "Sunnybrook Hospital",\n')
cat('    type_group = "Teaching",\n')
cat('    base_url   = "https://sunnybrook.ca",\n')
cat('    minutes_url = "https://sunnybrook.ca/about-sunnybrook/governance-leadership/"\n')
cat('  )\n')