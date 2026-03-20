# core/fetcher.R
# Handles all HTTP operations for HospitalIntelligenceR.
# Returns structured result objects consistently — callers always check result$success.
# This module never writes to the registry — it only retrieves content.

library(httr2)
library(rvest)
library(pdftools)
library(robotstxt)
library(stringr)

# --- Configuration defaults ---
# These can be overridden by role configs if needed

FETCHER_CONFIG <- list(
  rate_limit_seconds  = 2,      # Pause between requests
  max_retries         = 3,      # Retry attempts on failure
  retry_wait_seconds  = 5,      # Wait between retries
  timeout_seconds     = 30,     # Request timeout
  max_pdf_size_bytes  = 75e6,   # 50MB PDF size cap
  user_agent          = "HospitalIntelligenceR/1.0 (Research project; contact: your@email.com)"
)

# --- Internal helpers ---

# Structured result constructor — all fetch functions return this shape
.make_result <- function(success, fac, url, content = NULL, 
                         content_type = NULL, skip_reason = NULL, 
                         error_message = NULL, metadata = list()) {
  list(
    success       = success,
    fac           = fac,
    url           = url,
    content       = content,
    content_type  = content_type,   # "html", "pdf", "unknown"
    skip_reason   = skip_reason,    # populated when success = FALSE
    error_message = error_message,  # raw error text for logging
    metadata      = metadata,       # e.g. list(status_code = 200, file_size = 12345)
    fetched_at    = as.character(Sys.time())
  )
}

# Enforce rate limiting — call before every outbound request
.rate_limit <- function() {
  Sys.sleep(FETCHER_CONFIG$rate_limit_seconds)
}

# Check robots.txt for a given URL.
# Returns TRUE if allowed, FALSE if disallowed.
# Fails safe — if robots.txt cannot be retrieved, assumes allowed.
.robots_allowed <- function(url) {
  tryCatch({
    rt <- robotstxt(domain = httr2::url_parse(url)$hostname)
    rt$check(paths = httr2::url_parse(url)$path, bot = "*")
  }, error = function(e) {
    warning(sprintf("Could not retrieve robots.txt for %s — assuming allowed. Error: %s",
                    url, conditionMessage(e)))
    TRUE
  })
}

# Build a configured httr2 request object
.build_request <- function(url) {
  request(url) |>
    req_user_agent(FETCHER_CONFIG$user_agent) |>
    req_timeout(FETCHER_CONFIG$timeout_seconds) |>
    req_retry(
      max_tries    = FETCHER_CONFIG$max_retries,
      backoff      = \(attempt) FETCHER_CONFIG$retry_wait_seconds,
      is_transient = \(resp) resp_status(resp) %in% c(429, 500, 502, 503, 504)
    )
}

# Detect content type from response headers and URL
.detect_content_type <- function(resp, url) {
  ct_header <- tryCatch(resp_content_type(resp), error = function(e) "")
  if (str_detect(ct_header, "pdf")) return("pdf")
  if (str_detect(ct_header, "html")) return("html")
  if (str_detect(url, "\\.pdf(\\?|/|$)")) return("pdf")
  "unknown"
}

# --- Public functions ---

#' Check whether fetching is permitted for a hospital.
#' Consults registry robots_allowed field first; only hits the live robots.txt
#' if the registry says yes (or is missing the field).
#'
#' @param hospital  A hospital entry list from load_registry()
#' @param url       The specific URL to check (may differ from base_url)
#' @returns TRUE if allowed, FALSE if not
check_fetch_permitted <- function(hospital, url) {
  # Registry-level override takes precedence
  registry_flag <- hospital$robots_allowed
  if (!is.null(registry_flag) && 
      (identical(registry_flag, "no") || identical(registry_flag, FALSE))) {
    return(FALSE)
  }
  # Live robots.txt check for the specific URL
  .robots_allowed(url)
}

#' Fetch a URL as an rvest HTML object.
#'
#' @param fac       FAC code — carried through for logging
#' @param url       URL to fetch
#' @param hospital  Hospital entry from registry (used for robots check)
#' @returns Structured result list; content is an rvest html_document on success
fetch_html <- function(fac, url, hospital) {
  # Robots check
  if (!check_fetch_permitted(hospital, url)) {
    message(sprintf("[WARN] FAC %s: robots.txt disallows %s — skipping", fac, url))
    return(.make_result(FALSE, fac, url, skip_reason = "robots_disallowed"))
  }
  
  .rate_limit()
  
  tryCatch({
    resp <- .build_request(url) |> req_perform()
    
    status <- resp_status(resp)
    if (status != 200) {
      message(sprintf("[WARN] FAC %s: HTTP %d for %s", fac, status, url))
      return(.make_result(FALSE, fac, url,
                          skip_reason    = "http_error",
                          error_message  = sprintf("HTTP %d", status),
                          metadata       = list(status_code = status)))
    }
    
    content_type <- .detect_content_type(resp, url)
    html_content <- resp_body_string(resp) |> read_html()
    final_url    <- resp_url(resp) 
    
    message(sprintf("[INFO] FAC %s: HTML fetched from %s", fac, url))
    .make_result(TRUE, fac, url,
                 content      = html_content,
                 content_type = "html",
                 metadata     = list(
                   status_code = status,
                   final_url   = final_url))
    
  }, error = function(e) {
    message(sprintf("[ERROR] FAC %s: fetch_html failed for %s — %s", fac, url, conditionMessage(e)))
    .make_result(FALSE, fac, url,
                 skip_reason   = "request_error",
                 error_message = conditionMessage(e))
  })
}

#' Download a PDF to a local path and extract text.
#'
#' @param fac         FAC code
#' @param url         PDF URL
#' @param hospital    Hospital entry from registry
#' @param local_path  Full path where the PDF should be saved
#' @param extract_text  If TRUE, extract text via pdftools (default TRUE)
#' @returns Structured result; content is extracted text string if extract_text = TRUE,
#'          otherwise the local file path
fetch_pdf <- function(fac, url, hospital, local_path, extract_text = TRUE) {
  # Robots check
  if (!check_fetch_permitted(hospital, url)) {
    message(sprintf("[WARN] FAC %s: robots.txt disallows %s — skipping", fac, url))
    return(.make_result(FALSE, fac, url, skip_reason = "robots_disallowed"))
  }
  
  .rate_limit()
  
  tryCatch({
    # HEAD request first to check file size before downloading
    head_resp <- request(url) |>
      req_user_agent(FETCHER_CONFIG$user_agent) |>
      req_timeout(FETCHER_CONFIG$timeout_seconds) |>
      req_method("HEAD") |>
      req_perform()
    
    content_length <- as.numeric(
      resp_header(head_resp, "content-length") %||% "0"
    )
    if (content_length > FETCHER_CONFIG$max_pdf_size_bytes) {
      message(sprintf("[WARN] FAC %s: PDF at %s exceeds size limit (%.1f MB) — skipping",
                      fac, url, content_length / 1e6))
      return(.make_result(FALSE, fac, url,
                          skip_reason = "pdf_too_large",
                          metadata    = list(file_size_bytes = content_length)))
    }
    
    # Ensure output directory exists
    dir.create(dirname(local_path), recursive = TRUE, showWarnings = FALSE)
    
    # Download
    resp <- .build_request(url) |>
      req_perform(path = local_path)
    
    status <- resp_status(resp)
    if (status != 200) {
      message(sprintf("[WARN] FAC %s: HTTP %d downloading PDF from %s", fac, status, url))
      return(.make_result(FALSE, fac, url,
                          skip_reason   = "http_error",
                          error_message = sprintf("HTTP %d", status),
                          metadata      = list(status_code = status)))
    }
    
    file_size <- file.info(local_path)$size
    message(sprintf("[INFO] FAC %s: PDF downloaded to %s (%.1f KB)",
                    fac, local_path, file_size / 1024))
    
    # Optionally extract text
    content <- if (extract_text) {
      text <- tryCatch(
        paste(pdf_text(local_path), collapse = "\n"),
        error = function(e) {
          message(sprintf("[WARN] FAC %s: pdf_text extraction failed — %s", fac, conditionMessage(e)))
          NULL
        }
      )
      text
    } else {
      local_path
    }
    
    .make_result(TRUE, fac, url,
                 content      = content,
                 content_type = "pdf",
                 metadata     = list(
                   status_code     = status,
                   file_size_bytes = file_size,
                   local_path      = local_path
                 ))
    
  }, error = function(e) {
    message(sprintf("[ERROR] FAC %s: fetch_pdf failed for %s — %s", fac, url, conditionMessage(e)))
    .make_result(FALSE, fac, url,
                 skip_reason   = "request_error",
                 error_message = conditionMessage(e))
  })
}

#' Detect whether a URL points to a PDF or HTML page.
#' Uses a HEAD request — does not download content.
#'
#' @param url   URL to probe
#' @returns "pdf", "html", or "unknown"
detect_url_content_type <- function(url) {
  tryCatch({
    resp <- request(url) |>
      req_user_agent(FETCHER_CONFIG$user_agent) |>
      req_timeout(FETCHER_CONFIG$timeout_seconds) |>
      req_method("HEAD") |>
      req_perform()
    .detect_content_type(resp, url)
  }, error = function(e) {
    "unknown"
  })
}