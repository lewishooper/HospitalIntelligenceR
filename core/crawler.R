# core/crawler.R
# Crawls hospital websites starting from a seed URL, extracts and scores links
# against role-specific keywords, and returns a ranked candidate list.
#
# Design principles:
# - Role-agnostic: accepts any seed URL, keywords supplied by the role module
# - Does not decide which candidate is correct — returns a ranked list only
# - Does not write to the registry — callers handle that
# - PDF links are recorded as candidates but not followed further
# - Visited URL tracking prevents loops within a crawl session

library(rvest)
library(httr2)
library(purrr)
library(stringr)
library(dplyr)

# Assumes fetcher.R is already sourced — crawler delegates all HTTP work to it

# --- Configuration ---

CRAWLER_CONFIG <- list(
  max_pages       = 20,    # Maximum pages to successfully visit per crawl session
  max_depth       = 2,     # Maximum link-follow depth from seed URL
  min_score       = 1,     # Minimum score for a candidate to be returned
  score_tier1     = 2,     # Points awarded for a tier-1 keyword match
  score_tier2     = 1,
  early_exit_score = 4 
)

# --- Internal helpers ---

# Normalise a URL: resolve relative paths, strip fragments and trailing slashes.
.normalise_url <- function(href, base_url) {
  tryCatch({
    if (is.null(href) || is.na(href) || nchar(trimws(href)) == 0) return(NULL)
    if (str_detect(href, "^#")) return(NULL)
    if (str_detect(href, "^mailto:|^tel:")) return(NULL)
    
    if (str_detect(href, "^https?://")) {
      url <- str_remove(href, "#.*$")       # strip fragment
      return(str_remove(url, "/$"))          # strip trailing slash
    }
    
    base_parsed <- httr2::url_parse(base_url)
    base_root   <- sprintf("%s://%s", base_parsed$scheme, base_parsed$hostname)
    
    if (str_starts(href, "/")) {
      url <- paste0(base_root, href)
      return(str_remove(url, "/$"))
    }
    
    base_dir <- str_remove(base_url, "[^/]+$")
    url <- paste0(base_dir, href)
    return(str_remove(url, "/$"))
    
  }, error = function(e) NULL)
}

# Score a single URL + link text combination against tier-1 and tier-2 keywords.
.score_link <- function(url, link_text, keywords_tier1, keywords_tier2) {
  haystack <- tolower(paste(url, link_text, sep = " "))
  
  score_t1 <- sum(map_int(keywords_tier1, function(kw) {
    if (str_detect(haystack, fixed(tolower(kw)))) CRAWLER_CONFIG$score_tier1 else 0L
  }))
  
  score_t2 <- sum(map_int(keywords_tier2, function(kw) {
    if (str_detect(haystack, fixed(tolower(kw)))) CRAWLER_CONFIG$score_tier2 else 0L
  }))
  
  score_t1 + score_t2
}

# Extract all links from an rvest html_document.
# Returns a data frame with columns: url, link_text, is_pdf
.extract_links <- function(html_content, page_url) {
  nodes <- html_content |> html_elements("a[href]")
  if (length(nodes) == 0) return(data.frame())
  
  hrefs      <- html_attr(nodes, "href")
  link_texts <- html_text2(nodes)
  
  urls <- map_chr(hrefs, ~ {
    norm <- .normalise_url(.x, page_url)
    if (is.null(norm)) NA_character_ else norm
  })
  
  df <- data.frame(
    url       = urls,
    link_text = trimws(link_texts),
    stringsAsFactors = FALSE
  )
  
  df <- df[!is.na(df$url), ]
  df$is_pdf <- str_detect(tolower(df$url), "\\.pdf(\\?|$)")
  df
}

# --- Public functions ---

#' Crawl a website from a seed URL and return a ranked list of candidate URLs.
#'
#' @param fac             FAC code — carried through for logging
#' @param seed_url        Starting URL for the crawl
#' @param hospital        Hospital entry from registry (passed to fetcher for robots check)
#' @param keywords_tier1  Character vector of high-value keywords (score 2 each)
#' @param keywords_tier2  Character vector of supporting keywords (score 1 each)
#' @param max_depth       Override default crawl depth (optional)
#' @param max_pages       Override default page cap (optional)
#' @param include_pdfs    Whether to include PDF links as candidates (default TRUE)
#'
#' @returns A data frame of candidates, sorted by score descending, with columns:
#'   url, link_text, score, is_pdf, found_on_page, depth
#'   Returns an empty data frame if nothing scoring above min_score is found.

crawl <- function(fac,
                  seed_url,
                  hospital,
                  keywords_tier1,
                  keywords_tier2  = character(0),
                  max_depth       = CRAWLER_CONFIG$max_depth,
                  max_pages       = CRAWLER_CONFIG$max_pages,
                  include_pdfs    = TRUE) {
  
  # Normalise seed URL once up front
  seed_url <- str_remove(seed_url, "/$")
  
  visited       <- character(0)
  candidates    <- list()
  pages_visited <- 0L
  
  .crawl_page <- function(url, depth) {
    if (depth > max_depth) return(invisible(NULL))
    if (pages_visited >= max_pages) return(invisible(NULL))
    if (url %in% visited) return(invisible(NULL))
    
    # Mark as visited immediately to prevent re-entry
    visited <<- c(visited, url)
    
    message(sprintf("[INFO] FAC %s: crawling depth %d — %s", fac, depth, url))
    
    result <- fetch_html(fac, url, hospital)
    if (!result$success) return(invisible(NULL))
    
    # Also mark the final resolved URL after any redirect
    final_url <- str_remove(result$metadata$final_url %||% "", "/$")
    if (nchar(final_url) > 0 && !final_url %in% visited) {
      visited <<- c(visited, final_url)
      
    }
   
    # Only count successful fetches against the budget
    pages_visited <<- pages_visited + 1L
    
    links <- .extract_links(result$content, url)
    if (nrow(links) == 0) return(invisible(NULL))
    
    # Filter to same domain only
    seed_host   <- httr2::url_parse(seed_url)$hostname
    same_domain <- str_detect(links$url, fixed(seed_host))
    links <- links[same_domain, ]
    if (nrow(links) == 0) return(invisible(NULL))
    
    # Score all links on this page
    links$score <- map_int(seq_len(nrow(links)), function(i) {
      .score_link(links$url[i], links$link_text[i], keywords_tier1, keywords_tier2)
    })
    links$found_on_page <- url
    links$depth         <- depth
    
    # Accumulate candidates above minimum score
    keepers <- links[links$score >= CRAWLER_CONFIG$min_score, ]
    if (!include_pdfs) keepers <- keepers[!keepers$is_pdf, ]
    if (nrow(keepers) > 0) candidates <<- c(candidates, list(keepers))
    # Early exit: stop crawling if we already have a high-confidence candidate
    if (nrow(keepers) > 0 && max(keepers$score) >= CRAWLER_CONFIG$early_exit_score) {
      message(sprintf("[INFO] FAC %s: early exit — found candidate scoring %d at depth %d",
                      fac, max(keepers$score), depth))
      pages_visited <<- max_pages
      return(invisible(NULL))
    }
    
    # Follow non-PDF links at next depth:
    # - exclude already-visited URLs
    # - deduplicate by URL before iterating (prevents double-visiting from
    #   duplicate nav links that appear multiple times in the page DOM)
    # - prioritise highest-scoring first
    followable <- links[!links$is_pdf & !links$url %in% visited, ]
    followable <- followable[!duplicated(followable$url), ]
    followable <- followable[order(-followable$score), ]
    
    for (i in seq_len(nrow(followable))) {
      if (pages_visited >= max_pages) break
      .crawl_page(followable$url[i], depth + 1L)
    }
  }
  
  .crawl_page(seed_url, depth = 1L)
  
  if (length(candidates) == 0) {
    message(sprintf("[INFO] FAC %s: crawl found no scored candidates from %s", fac, seed_url))
    return(data.frame(
      url           = character(0),
      link_text     = character(0),
      score         = integer(0),
      is_pdf        = logical(0),
      found_on_page = character(0),
      depth         = integer(0)
    ))
  }
  
  result_df <- bind_rows(candidates)
  
  # Where the same URL appears multiple times, keep the highest score instance
  result_df <- result_df |>
    group_by(url) |>
    slice_max(score, n = 1, with_ties = FALSE) |>
    ungroup() |>
    arrange(desc(score))
  
  message(sprintf("[INFO] FAC %s: crawl complete — %d candidates found, %d pages visited",
                  fac, nrow(result_df), pages_visited))
  
  result_df
}

#' Convenience wrapper: crawl and return the single top-scoring candidate URL.
#' Returns NULL if no candidates are found.
#'
#' @param prefer_pdf  If TRUE, the top-scoring PDF candidate is preferred over
#'                    an HTML candidate of equal score (default TRUE)
top_candidate <- function(fac, seed_url, hospital,
                          keywords_tier1, keywords_tier2 = character(0),
                          prefer_pdf = TRUE, ...) {
  candidates <- crawl(fac, seed_url, hospital,
                      keywords_tier1, keywords_tier2, ...)
  
  if (nrow(candidates) == 0) return(NULL)
  
  top_score <- candidates$score[1]
  top_tier  <- candidates[candidates$score == top_score, ]
  
  # Tiebreaker 1: prefer URLs where any individual word from a tier-1 keyword
  # appears in the URL path. Split "strategic plan" -> ["strategic", "plan"]
  # so that "strategic-plan" in a URL matches correctly.
  keyword_words <- tolower(unique(unlist(str_split(keywords_tier1, "\\s+"))))
  url_matches <- map_lgl(top_tier$url, function(u) {
    any(str_detect(tolower(u), fixed(keyword_words)))
  })
  if (any(url_matches)) top_tier <- top_tier[url_matches, ]
  
  # Tiebreaker 2: prefer PDFs if requested
  if (prefer_pdf && any(top_tier$is_pdf)) {
    top_tier <- top_tier[top_tier$is_pdf, ]
  }
  
  top_tier$url[1]
}